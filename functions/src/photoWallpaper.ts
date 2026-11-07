import {randomBytes} from "node:crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import type {OutputInfo} from "sharp";
import {isValidRequestId} from "./coinsCallables";
import {CALLABLE_REGIONS, coinTransactionDoc, db, readDailyCount, REGION, utcDateString} from "./common";
import {loadEconomy, proPrice} from "./economy";
import {R2Storage, r2Env, r2Secrets} from "./r2Storage";
import {likelihoodRank} from "./studio/gates";
import {falKey} from "./wallDepth";

export type PhotoJobMode = "extend" | "upscale";
export type PhotoJobTarget = "phone" | "desktop";
export type PhotoJobFailure = "unsafe_input" | "unsafe_output" | "provider_error" | "storage_error" | "timeout";
type Size = {width: number; height: number};
type Placement = {left: number; top: number; width: number; height: number};

/** One photo job, as stored in `photoJobs/{jobId}`. The input photo is never stored. */
export interface PhotoJob {
  userId: string;
  requestId: string;
  mode: PhotoJobMode;
  target: PhotoJobTarget;
  model: string;
  cost: number;
  chargeTxId: string;
  /** "closed": a lookup found no job, so a create that arrives later must not charge. */
  state: "running" | "succeeded" | "failed" | "closed";
  startedAt: admin.firestore.Timestamp;
  width: number;
  height: number;
  imageUrl?: string;
  watermarked?: boolean;
  reason?: PhotoJobFailure;
  refunded?: boolean;
  resultKey?: string;
  cleanupPending?: boolean;
  falRequestId?: string;
  falCleanupPending?: boolean;
}

export type PhotoJobResult =
  | {jobId: string; state: "succeeded"; mode: PhotoJobMode; target: PhotoJobTarget; cost: number; imageUrl: string;
    width: number; height: number; watermarked: boolean}
  | {jobId: string; state: "failed"; mode: PhotoJobMode; target: PhotoJobTarget; cost: number; reason: PhotoJobFailure;
    refunded: boolean};

export const PHOTO_JOBS = "photoJobs";
export const PHOTO_JOB_DAILY = "photoJobDaily";
/** Per-account daily count of request ids a lookup closed. Bounds the closed records one account can create. */
export const PHOTO_JOB_CLOSURES = "photoJobClosures";
export const MAX_PHOTO_JOB_CLOSURES_PER_DAY = 20;
export const PHOTO_JOB_BUDGET = "photoJobBudget";
/** fal payload deletes left over after account deletion. Holds only the fal request id, never the user. */
export const PHOTO_FAL_CLEANUP = "photoFalCleanup";
export const MAX_PHOTO_JOBS_PER_USER_PER_DAY = 10;
export const MAX_PHOTO_JOBS_PER_DAY = 400;
export const MAX_PHOTO_INPUT_BYTES = 6 * 1024 * 1024;
export const PHOTO_MODELS: Record<PhotoJobMode, string> = {
  extend: "fal-ai/bria/expand",
  upscale: "fal-ai/seedvr/upscale/image",
};
export const DESKTOP_SIZE: Size = {width: 2560, height: 1600};
/** A shape further than this from the target shape needs Extend. The app planner uses the same value. */
export const ASPECT_TOLERANCE = 0.05;
export const STALE_RUNNING_MS = 10 * 60 * 1000;
const INPUT_MIN_EDGE = 256;
const INPUT_MAX_EDGE = 4096;
const MAX_UPSCALE_FACTOR = 4;
const MIN_PLACEMENT_SHARE = 0.1;
const FAL_TIMEOUT_MS = 100_000;
const PHOTO_CALL_TIMEOUT_MS = 180_000;
const MAX_RESULT_BYTES = 30 * 1024 * 1024;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
const DATA_URI = /^data:image\/[\w.+-]+;base64,([A-Za-z0-9+/]+={0,2})$/;
const ACTION = "photoWallpaper";
const DAY_MS = 86_400_000;
const CLEANUP_BATCH_SIZE = 10;
const CLEANUP_QUEUE_BUDGET_MS = 20_000;

export interface PhotoDeps {
  /** SafeSearch of a JPEG. Throws when Vision fails. */
  safeSearch(jpeg: Buffer): Promise<Record<string, unknown> | null | undefined>;
  fetch(url: string, init: RequestInit): Promise<Response>;
  falKey(): string;
  /** Stores a public, immutable JPEG under an unguessable key and returns its URL. */
  store(jpeg: Buffer, key: string): Promise<{url: string; key: string}>;
  remove(key: string): Promise<void>;
}

export const photoDeps: PhotoDeps = {
  async safeSearch(jpeg) {
    const {ImageAnnotatorClient} = await import("@google-cloud/vision");
    const [result] = await new ImageAnnotatorClient().annotateImage({
      image: {content: jpeg},
      features: [{type: "SAFE_SEARCH_DETECTION"}],
    });
    if (result.error?.code) throw new Error(`Vision error ${result.error.code}`);
    return result.safeSearchAnnotation as Record<string, unknown> | null | undefined;
  },
  fetch: (url, init) => fetch(url, init),
  falKey: () => falKey.value(),
  async store(jpeg, key) {
    const base = r2Env("R2_PREVIEW_BASE_URL");
    if (!base) throw new Error("R2 preview base URL is not set");
    await new R2Storage().put("preview", key, jpeg, {}, "image/jpeg");
    return {url: `${base.replace(/\/+$/, "")}/${key}`, key};
  },
  async remove(key) {
    await new R2Storage().delete("preview", key);
  },
};

/** The shape and size checks the app makes before it offers a job. The app planner must give the same answer. */
export function planPhotoJob(photo: Size, target: Size): PhotoJobMode | "fits" {
  const off = Math.abs((photo.width / photo.height) / (target.width / target.height) - 1) > ASPECT_TOLERANCE;
  if (off) return "extend";
  return Math.min(photo.width, photo.height) < Math.min(target.width, target.height) ? "upscale" : "fits";
}

/** Adult or violence at LIKELY or more, or racy at VERY_LIKELY, blocks the image. A missing result blocks it too. */
export function isPhotoSafe(annotation: Record<string, unknown> | null | undefined): boolean {
  if (!annotation) return false;
  const adult = likelihoodRank(annotation.adult);
  const violence = likelihoodRank(annotation.violence);
  const racy = likelihoodRank(annotation.racy);
  if (adult === 0 || violence === 0 || racy === 0) return false;
  return adult < 4 && violence < 4 && racy < 5;
}

function intIn(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;
}

function bad(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

export function parseTarget(data: Record<string, unknown>): {target: PhotoJobTarget; size: Size} {
  if (data.target === "desktop") return {target: "desktop", size: DESKTOP_SIZE};
  if (data.target !== "phone") throw bad("target must be phone or desktop.");
  const {targetWidth: width, targetHeight: height} = data;
  if (!intIn(width, 720, 1600) || !intIn(height, 720, 4000) || height / width < 1.6 || height / width > 2.4) {
    throw bad("targetWidth and targetHeight must be a phone screen in portrait.");
  }
  return {target: "phone", size: {width, height}};
}

/** Where the photo sits in the canvas: inside it, with the photo's shape, and at least a tenth of its area. */
export function parsePlacement(raw: unknown, photo: Size, canvas: Size): Placement {
  if (raw === undefined || raw === null) {
    const scale = Math.min(canvas.width / photo.width, canvas.height / photo.height);
    const width = Math.round(photo.width * scale);
    const height = Math.round(photo.height * scale);
    raw = {left: Math.floor((canvas.width - width) / 2), top: Math.floor((canvas.height - height) / 2), width, height};
  }
  if (typeof raw !== "object" || Array.isArray(raw)) throw bad("placement is invalid.");
  const {left, top, width, height} = raw as Record<string, unknown>;
  if (!intIn(width, 1, canvas.width) || !intIn(height, 1, canvas.height) ||
    !intIn(left, 0, canvas.width - width) || !intIn(top, 0, canvas.height - height)) {
    throw bad("placement must be inside the canvas.");
  }
  if (Math.abs((width / height) / (photo.width / photo.height) - 1) > 0.02) throw bad("placement must keep the photo shape.");
  if (width * height < MIN_PLACEMENT_SHARE * canvas.width * canvas.height) throw bad("placement is too small.");
  return {left, top, width, height};
}

/** Decodes the photo, turns it upright and writes a new JPEG. The new JPEG has no EXIF, GPS or other metadata. */
export async function normalizePhoto(raw: unknown): Promise<{jpeg: Buffer; size: Size}> {
  if (typeof raw !== "string" || raw.length === 0 || raw.length % 4 !== 0 || !BASE64.test(raw)) {
    throw bad("image must be a base64 JPEG or PNG.");
  }
  if (raw.length > Math.ceil(MAX_PHOTO_INPUT_BYTES / 3) * 4) throw bad("image is too large.");
  const bytes = Buffer.from(raw, "base64");
  const sharp = (await import("sharp")).default;
  let jpeg: Buffer;
  let info: OutputInfo;
  try {
    const meta = await sharp(bytes, {limitInputPixels: INPUT_MAX_EDGE * INPUT_MAX_EDGE}).metadata();
    if (meta.format !== "jpeg" && meta.format !== "png" && meta.format !== "webp") throw new Error("format");
    ({data: jpeg, info} = await sharp(bytes, {limitInputPixels: INPUT_MAX_EDGE * INPUT_MAX_EDGE}).rotate()
      .jpeg({quality: 92}).toBuffer({resolveWithObject: true}));
  } catch {
    throw bad("image could not be decoded.");
  }
  if (Math.min(info.width, info.height) < INPUT_MIN_EDGE || Math.max(info.width, info.height) > INPUT_MAX_EDGE) {
    throw bad(`image sides must be ${INPUT_MIN_EDGE} to ${INPUT_MAX_EDGE} px.`);
  }
  return {jpeg, size: {width: info.width, height: info.height}};
}

function falBody(mode: PhotoJobMode, input: string, photo: Size, size: Size, placement: Placement | null) {
  if (mode === "extend") {
    if (!placement) throw new Error("extend needs a placement");
    return {
      image_url: input,
      canvas_size: [size.width, size.height],
      original_image_size: [placement.width, placement.height],
      original_image_location: [placement.left, placement.top],
      prompt: "",
      sync_mode: true,
    };
  }
  const cover = Math.max(size.width / photo.width, size.height / photo.height);
  return {
    image_url: input,
    upscale_mode: "factor",
    upscale_factor: Math.min(MAX_UPSCALE_FACTOR, Math.ceil(cover * 10) / 10),
    output_format: "jpg",
    enable_safety_checker: true,
    sync_mode: true,
  };
}

/**
 * Runs the model with the photo inline as a data URI. `X-Fal-Store-IO: 0` asks fal not to store the request and
 * result, `sync_mode` requests the result inline, and failed payload deletes remain pending for the sweeper.
 */
async function runFal(jobId: string, mode: PhotoJobMode, jpeg: Buffer, photo: Size, size: Size, placement: Placement | null,
  deps: PhotoDeps): Promise<Buffer> {
  const key = deps.falKey().trim();
  if (key === "") throw new Error("FAL_API_KEY is empty");
  const body = falBody(mode, `data:image/jpeg;base64,${jpeg.toString("base64")}`, photo, size, placement);
  let requestId: string | null = null;
  try {
    const response = await deps.fetch(`https://fal.run/${PHOTO_MODELS[mode]}`, {
      method: "POST",
      headers: {"Authorization": `Key ${key}`, "content-type": "application/json", "X-Fal-Store-IO": "0"},
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(FAL_TIMEOUT_MS),
    });
    requestId = response.headers.get("x-fal-request-id");
    if (requestId && /^[A-Za-z0-9-]{8,64}$/.test(requestId)) {
      await db.collection(PHOTO_JOBS).doc(jobId).update({falRequestId: requestId, falCleanupPending: true});
    }
    if (!response.ok) throw new Error(`fal request failed with ${response.status}`);
    const payload = (await response.json()) as {image?: {url?: unknown}} | null;
    const url = payload?.image?.url;
    const inline = typeof url === "string" ? DATA_URI.exec(url) : null;
    if (inline) {
      if (inline[1].length > Math.ceil(MAX_RESULT_BYTES / 3) * 4) throw new Error("fal image is too large");
      const bytes = Buffer.from(inline[1], "base64");
      if (bytes.length > MAX_RESULT_BYTES) throw new Error("fal image is too large");
      return bytes;
    }
    if (typeof url !== "string" || !url.startsWith("https://")) throw new Error("fal result has no image");
    const image = await deps.fetch(url, {signal: AbortSignal.timeout(30_000)});
    if (!image.ok) throw new Error(`fal image fetch failed with ${image.status}`);
    const bytes = Buffer.from(await image.arrayBuffer());
    if (bytes.length > MAX_RESULT_BYTES) throw new Error("fal image is too large");
    return bytes;
  } finally {
    if (requestId && /^[A-Za-z0-9-]{8,64}$/.test(requestId)) {
      await cleanupFalPayload(jobId, requestId, deps);
    }
  }
}

/** Asks fal to delete one request's stored data. True only when fal confirms every file was deleted. */
async function deleteFalPayload(requestId: string, deps: PhotoDeps): Promise<boolean> {
  try {
    const deleted = await deps.fetch(`https://api.fal.ai/v1/models/requests/${requestId}/payloads`, {
      method: "DELETE",
      headers: {"Authorization": `Key ${deps.falKey().trim()}`},
      signal: AbortSignal.timeout(10_000),
    });
    if (!deleted.ok) return false;
    const body = await deleted.json() as {cdn_delete_results?: Array<{exception?: unknown}>};
    return Array.isArray(body.cdn_delete_results) && body.cdn_delete_results.every((r) => r.exception == null);
  } catch {
    return false;
  }
}

async function cleanupFalPayload(jobId: string, requestId: string, deps: PhotoDeps): Promise<void> {
  if (!(await deleteFalPayload(requestId, deps))) {
    logger.warn("photoWallpaper: fal payload delete failed.", {requestId});
    return;
  }
  try {
    await db.collection(PHOTO_JOBS).doc(jobId).update({falCleanupPending: false});
  } catch {
    logger.warn("photoWallpaper: fal cleanup flag update failed.", {jobId});
  }
}

/** The "Made with Prism AI" pill. The label is measured as rendered, so the pill fits any server font. */
async function watermarkLayers(width: number, height: number): Promise<{input: Buffer; left: number; top: number}[]> {
  const sharp = (await import("sharp")).default;
  const edge = Math.min(width, height);
  const font = Math.max(14, Math.round(edge * 0.032));
  const padX = Math.max(12, Math.round(edge * 0.018));
  const padY = Math.max(8, Math.round(edge * 0.012));
  const margin = Math.max(10, Math.round(edge * 0.018));
  const {data: label, info} = await sharp({text: {
    text: "<span foreground=\"white\" alpha=\"92%\"><b>Made with Prism AI</b></span>",
    font: "sans", dpi: Math.round(font * 72 / 12 * 0.75), rgba: true,
  }}).png().toBuffer({resolveWithObject: true});
  const badgeW = Math.min(width - 2 * margin, info.width + padX * 2);
  const badgeH = info.height + padY * 2;
  const left = width - badgeW - margin;
  const top = height - badgeH - margin;
  const pill = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${badgeW}" height="${badgeH}">` +
    `<rect width="${badgeW}" height="${badgeH}" rx="${Math.round(badgeH / 2)}" fill="rgba(9,12,18,0.52)"/></svg>`);
  return [{input: pill, left, top}, {input: label, left: left + padX, top: top + padY}];
}

/** The result at the exact target size as a JPEG with no metadata, with the badge for free members. */
export async function finishImage(bytes: Buffer, size: Size, watermark: boolean): Promise<Buffer> {
  const sharp = (await import("sharp")).default;
  const exact = await sharp(bytes, {limitInputPixels: 8192 * 8192}).rotate()
    .resize(size.width, size.height, {fit: "cover", position: "centre"}).toBuffer();
  const image = sharp(exact);
  if (watermark) image.composite(await watermarkLayers(size.width, size.height));
  return image.jpeg({quality: 92}).toBuffer();
}

function jobResult(jobId: string, job: PhotoJob): PhotoJobResult {
  if (job.state === "succeeded" && job.imageUrl) {
    return {jobId, state: "succeeded", mode: job.mode, target: job.target, cost: job.cost, imageUrl: job.imageUrl,
      width: job.width, height: job.height, watermarked: job.watermarked === true};
  }
  return {jobId, state: "failed", mode: job.mode, target: job.target, cost: job.cost,
    reason: job.reason ?? "provider_error", refunded: job.refunded === true};
}

/**
 * Ends a running job as failed and returns its coins in the same transaction. Only the claim that started the job
 * (same `startedAt`) can end it, so a sweeper and a late finish never both act. A second call does nothing.
 */
export async function failPhotoJob(jobId: string, startedAtMs: number, reason: PhotoJobFailure): Promise<PhotoJob | null> {
  const jobRef = db.collection(PHOTO_JOBS).doc(jobId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(jobRef);
    const job = snap.data() as PhotoJob | undefined;
    if (!job || job.state !== "running" || job.startedAt.toMillis() !== startedAtMs) return job ?? null;
    const userRef = db.collection("usersv2").doc(job.userId);
    const refundRef = db.collection("coinTransactions").doc(`ctx_photoWallpaperRefund_${job.userId}_${job.requestId}`);
    const deletionRef = db.collection("creatorDeletionState").doc(job.userId);
    const [user, refund, deletion] = await tx.getAll(userRef, refundRef, deletionRef);
    const mayRefund = deletion.data()?.closed !== true && user.data()?.deleted !== true;
    const failed: PhotoJob = {...job, state: "failed", reason, refunded: mayRefund && (refund.exists || user.exists)};
    if (mayRefund && !refund.exists && user.exists) {
      const balance = Math.trunc(Number(user.data()?.coins) || 0);
      tx.update(userRef, {coins: balance + job.cost});
      tx.set(refundRef, coinTransactionDoc({
        id: refundRef.id, userId: job.userId, at: admin.firestore.Timestamp.now(), delta: job.cost,
        balanceBefore: balance, action: "refund", description: "Photo wallpaper refund",
        sourceTag: "photo_wallpaper.refund", reason: `photo_job_${reason}`,
      }));
    }
    tx.update(jobRef, {state: "failed", reason, refunded: failed.refunded, finishedAt: admin.firestore.Timestamp.now()});
    return failed;
  });
}

async function cleanupFailedPhotoJob(jobId: string, job: PhotoJob, deps: PhotoDeps): Promise<void> {
  if (job.state !== "failed" || !job.resultKey) return;
  try {
    if (job.cleanupPending !== true) await db.collection(PHOTO_JOBS).doc(jobId).update({cleanupPending: true});
    await deps.remove(job.resultKey);
    await db.collection(PHOTO_JOBS).doc(jobId).update({cleanupPending: false});
  } catch {
    logger.warn("photoWallpaper: orphan result delete failed.", {jobId});
  }
}

async function claimJob(uid: string, requestId: string, mode: PhotoJobMode, target: PhotoJobTarget, size: Size):
  Promise<{replay: PhotoJob} | {job: PhotoJob; isPro: boolean}> {
  const jobRef = db.collection(PHOTO_JOBS).doc(`pj_${uid}_${requestId}`);
  const economy = await loadEconomy();
  return db.runTransaction(async (tx) => {
    const day = utcDateString();
    const userRef = db.collection("usersv2").doc(uid);
    const dailyRef = db.collection(PHOTO_JOB_DAILY).doc(uid);
    const budgetRef = db.collection(PHOTO_JOB_BUDGET).doc(day);
    const deletionRef = db.collection("creatorDeletionState").doc(uid);
    const chargeRef = db.collection("coinTransactions").doc(`ctx_photoWallpaper_${uid}_${requestId}`);
    const [jobSnap, user, daily, budget, deletion] = await tx.getAll(jobRef, userRef, dailyRef, budgetRef, deletionRef);
    if (deletion.data()?.closed === true || user.data()?.deleted === true) {
      throw new HttpsError("failed-precondition", "Account deletion is in progress.");
    }
    if (jobSnap.exists) {
      const job = jobSnap.data() as PhotoJob;
      if (job.userId !== uid) throw new HttpsError("permission-denied", "This job belongs to another account.");
      if (job.state === "closed") throw new HttpsError("failed-precondition", "request_closed");
      if (job.state === "running" && Date.now() - job.startedAt.toMillis() < STALE_RUNNING_MS) {
        throw new HttpsError("aborted", "in_progress");
      }
      return {replay: job};
    }
    const usedToday = readDailyCount(daily, day);
    if (usedToday >= MAX_PHOTO_JOBS_PER_USER_PER_DAY) {
      throw new HttpsError("resource-exhausted", "daily_limit", {limit: MAX_PHOTO_JOBS_PER_USER_PER_DAY});
    }
    if (readDailyCount(budget, day) >= MAX_PHOTO_JOBS_PER_DAY) throw new HttpsError("resource-exhausted", "busy");
    if (!user.exists) throw new HttpsError("not-found", "User profile was not found.");
    const data = user.data() ?? {};
    const isPro = data.premium === true;
    const base = mode === "extend" ? economy.spend.photoExtend : economy.spend.photoUpscale;
    const cost = proPrice(base, isPro && economy.proDiscountActions.includes(ACTION));
    const balance = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    if (balance < cost) throw new HttpsError("failed-precondition", "insufficient_coins", {cost, balance});
    const now = admin.firestore.Timestamp.now();
    const job: PhotoJob = {userId: uid, requestId, mode, target, model: PHOTO_MODELS[mode], cost,
      chargeTxId: chargeRef.id, state: "running", startedAt: now, width: size.width, height: size.height,
      resultKey: `photo-walls/${randomBytes(16).toString("hex")}.jpg`, cleanupPending: true};
    tx.update(userRef, {coins: balance - cost});
    tx.set(chargeRef, coinTransactionDoc({
      id: chargeRef.id, userId: uid, at: now, delta: -cost, balanceBefore: balance, action: ACTION,
      description: mode === "extend" ? "Photo wallpaper: extend" : "Photo wallpaper: upscale",
      sourceTag: "photo_wallpaper.charge", reason: `photo_job_${mode}`,
    }));
    tx.set(jobRef, job);
    const expireAt = admin.firestore.Timestamp.fromMillis(Date.now() + 2 * DAY_MS);
    tx.set(dailyRef, {day, count: usedToday + 1, expireAt});
    tx.set(budgetRef, {day, count: readDailyCount(budget, day) + 1, expireAt});
    return {job, isPro};
  });
}

export async function runPhotoJob(jobId: string, job: PhotoJob, jpeg: Buffer, photo: Size, placement: Placement | null,
  isPro: boolean, deps: PhotoDeps = photoDeps): Promise<PhotoJobResult> {
  const startedAtMs = job.startedAt.toMillis();
  const size = {width: job.width, height: job.height};
  const jobRef = db.collection(PHOTO_JOBS).doc(jobId);
  const withActiveJob = async <T>(start: () => Promise<T>): Promise<T | null> => {
    const [currentSnap, deletion] = await Promise.all([
      jobRef.get(), db.collection("creatorDeletionState").doc(job.userId).get(),
    ]);
    const current = currentSnap.data() as PhotoJob | undefined;
    if (!current || current.state !== "running" || current.startedAt.toMillis() !== startedAtMs ||
      deletion.data()?.closed === true || Date.now() - startedAtMs >= PHOTO_CALL_TIMEOUT_MS) return null;
    return start();
  };
  const fail = async (reason: PhotoJobFailure): Promise<PhotoJobResult> => {
    try {
      const failed = await failPhotoJob(jobId, startedAtMs, reason);
      if (failed) await cleanupFailedPhotoJob(jobId, failed, deps);
      return jobResult(jobId, failed ?? {...job, state: "failed", reason, refunded: false});
    } catch {
      logger.error("photoWallpaper: refund failed. The sweeper retries it.", {jobId});
      return jobResult(jobId, {...job, state: "failed", reason, refunded: false});
    }
  };
  // Vision and fal errors can echo request details. Never log error-derived data for photo jobs.
  try {
    if (!isPhotoSafe(await deps.safeSearch(jpeg))) return fail("unsafe_input");
  } catch {
    logger.warn("photoWallpaper: input check failed.", {jobId});
    return fail("provider_error");
  }
  let output: Buffer;
  try {
    const generated = await withActiveJob(() => runFal(jobId, job.mode, jpeg, photo, size, placement, deps));
    if (!generated) return fail("timeout");
    output = await finishImage(generated, size, !isPro);
  } catch (error) {
    logger.warn("photoWallpaper: model run failed.", {jobId, timeout: (error as Error)?.name === "TimeoutError"});
    return fail((error as Error)?.name === "TimeoutError" ? "timeout" : "provider_error");
  }
  try {
    if (!isPhotoSafe(await deps.safeSearch(output))) return fail("unsafe_output");
  } catch {
    logger.warn("photoWallpaper: output check failed.", {jobId});
    return fail("provider_error");
  }
  let stored: {url: string; key: string};
  const resultKey = job.resultKey;
  if (!resultKey) return fail("storage_error");
  try {
    const storedResult = await withActiveJob(() => deps.store(output, resultKey));
    if (!storedResult) return fail("timeout");
    stored = storedResult;
  } catch {
    logger.warn("photoWallpaper: storage stage failed.", {jobId});
    return fail("storage_error");
  }
  let done: PhotoJob | null = null;
  try {
    done = await db.runTransaction(async (tx) => {
      const [currentSnap, deletion] = await tx.getAll(jobRef, db.collection("creatorDeletionState").doc(job.userId));
      const current = currentSnap.data() as PhotoJob | undefined;
      if (deletion.data()?.closed === true) return null;
      if (!current || current.state !== "running" || current.startedAt.toMillis() !== startedAtMs) return null;
      const update = {state: "succeeded" as const, imageUrl: stored.url, watermarked: !isPro,
        finishedAt: admin.firestore.Timestamp.now(), cleanupPending: false};
      tx.update(jobRef, update);
      return {...current, ...update};
    });
  } catch {
    logger.warn("photoWallpaper: finish failed.", {jobId});
  }
  if (done) return jobResult(jobId, done);
  // A finish that threw can still have committed. Keep the stored image when the job points at it.
  let current: PhotoJob | undefined;
  try {
    current = (await jobRef.get()).data() as PhotoJob | undefined;
  } catch {
    logger.warn("photoWallpaper: job read after finish failed.", {jobId});
    return fail("storage_error");
  }
  if (current?.state === "succeeded" && current.imageUrl === stored.url) return jobResult(jobId, current);
  if (current?.state === "failed") {
    await cleanupFailedPhotoJob(jobId, {...current, resultKey: stored.key}, deps);
    return jobResult(jobId, current);
  }
  try {
    await deps.remove(stored.key);
  } catch {
    logger.warn("photoWallpaper: orphan result delete failed.", {jobId, key: stored.key});
  }
  return current && current.state !== "running" ? jobResult(jobId, current) : fail("storage_error");
}

/** [result] with the user's coin balance, so the app shows the server's number instead of a cached one. */
async function withBalance<T extends object>(uid: string, result: T): Promise<T & {balance?: number}> {
  try {
    const coins = (await db.collection("usersv2").doc(uid).get()).data()?.coins;
    return typeof coins === "number" ? {...result, balance: Math.trunc(coins)} : result;
  } catch {
    return result;
  }
}

/**
 * Photo to wallpaper. Charges the coins, runs Extend or Upscale on the photo, checks the photo and the result with
 * SafeSearch, and stores the result. Most failures after the charge return the coins. The same requestId replays the
 * stored outcome while the account is active and never charges twice. The photo is held only in memory and sent to
 * fal inline. Account deletion closes the UID barrier; jobs that fail after that point do not refund.
 */
export const createPhotoWallpaper = onCall({
  region: CALLABLE_REGIONS,
  timeoutSeconds: 180,
  memory: "1GiB",
  maxInstances: 10,
  secrets: [falKey, ...r2Secrets],
}, async (request): Promise<PhotoJobResult & {balance?: number}> => {
  const uid = request.auth?.uid;
  if (!uid || request.auth?.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "Sign in to make a wallpaper from a photo.");
  }
  const data = (request.data ?? {}) as Record<string, unknown>;
  if (!isValidRequestId(data.requestId)) throw bad("requestId is invalid.");
  if (data.mode !== "extend" && data.mode !== "upscale") throw bad("mode must be extend or upscale.");
  const mode: PhotoJobMode = data.mode;
  const {target, size} = parseTarget(data);
  if (mode === "upscale" && data.placement !== undefined) throw bad("upscale takes no placement.");
  const {jpeg, size: photo} = await normalizePhoto(data.image);
  const plan = planPhotoJob(photo, size);
  if (plan !== mode) throw new HttpsError("failed-precondition", "plan_mismatch", {plan});
  const placement = mode === "extend" ? parsePlacement(data.placement, photo, size) : null;

  const jobId = `pj_${uid}_${data.requestId}`;
  const claim = await claimJob(uid, data.requestId, mode, target, size);
  if ("replay" in claim) {
    const job = claim.replay;
    if (job.state !== "running") return withBalance(uid, jobResult(jobId, job));
    return withBalance(uid, jobResult(jobId, (await failPhotoJob(jobId, job.startedAt.toMillis(), "timeout")) ?? job));
  }
  return withBalance(uid, await runPhotoJob(jobId, claim.job, jpeg, photo, placement, claim.isPro));
});

async function sweepCleanupQueue(field: "cleanupPending" | "falCleanupPending", nowMs: number): Promise<void> {
  const progress = db.collection(PHOTO_JOB_BUDGET).doc("cleanup");
  const cursor = (await progress.get()).data()?.[field];
  const query = db.collection(PHOTO_JOBS).where(field, "==", true).orderBy(admin.firestore.FieldPath.documentId());
  const started = Date.now();
  const page = await (typeof cursor === "string" ? query.startAfter(db.collection(PHOTO_JOBS).doc(cursor)) : query)
    .limit(CLEANUP_BATCH_SIZE).get();
  let processed = 0;
  for (const doc of page.docs) {
    if (Date.now() - started >= CLEANUP_QUEUE_BUDGET_MS) break;
    const job = doc.data() as PhotoJob;
    if (field === "cleanupPending") await cleanupFailedPhotoJob(doc.id, job, photoDeps);
    else if (job.falRequestId && (job.state !== "running" || nowMs - job.startedAt.toMillis() >= STALE_RUNNING_MS)) {
      await cleanupFalPayload(doc.id, job.falRequestId, photoDeps);
    }
    await progress.set({[field]: doc.id}, {merge: true});
    processed++;
  }
  if (processed === page.size && page.size < CLEANUP_BATCH_SIZE) await progress.set({[field]: null}, {merge: true});
}

/**
 * The state of one of the caller's jobs, for an app that restarted while it ran. Never charges or runs anything. A job
 * that stopped while it ran is ended and refunded, the same as a replay of its requestId.
 */
export const getPhotoWallpaper = onCall({region: CALLABLE_REGIONS, timeoutSeconds: 30},
  async (request): Promise<(PhotoJobResult & {balance?: number}) | {jobId: string; state: "running"; balance?: number} |
    {state: "unknown"}> => {
    const uid = request.auth?.uid;
    if (!uid || request.auth?.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to see your photo wallpaper.");
    }
    const requestId = (request.data as Record<string, unknown> | undefined)?.requestId;
    if (!isValidRequestId(requestId)) throw bad("requestId is invalid.");
    const jobId = `pj_${uid}_${requestId}`;
    const jobRef = db.collection(PHOTO_JOBS).doc(jobId);
    const deletionRef = db.collection("creatorDeletionState").doc(uid);
    // No job yet: close the request id in a transaction, so "unknown" is final. A create still on its way then finds
    // the closed record at its claim and charges nothing.
    const closuresRef = db.collection(PHOTO_JOB_CLOSURES).doc(uid);
    const job = await db.runTransaction(async (tx) => {
      const [snap, deletion, closures] = await tx.getAll(jobRef, deletionRef, closuresRef);
      if (snap.exists) return snap.data() as PhotoJob;
      if (deletion.data()?.closed === true) return null;
      const day = utcDateString();
      const closedToday = readDailyCount(closures, day);
      if (closedToday >= MAX_PHOTO_JOB_CLOSURES_PER_DAY) {
        // Without a tombstone, a delayed create may still charge. Keep recovery pending instead of saying unknown.
        throw new HttpsError("resource-exhausted", "lookup_closure_limit");
      }
      tx.set(jobRef, {userId: uid, requestId, state: "closed", closedAt: admin.firestore.Timestamp.now()});
      tx.set(closuresRef, {day, count: closedToday + 1,
        expireAt: admin.firestore.Timestamp.fromMillis(Date.now() + 2 * DAY_MS)});
      return null;
    });
    if (!job || job.userId !== uid || job.state === "closed") return {state: "unknown"};
    if (job.state !== "running") return withBalance(uid, jobResult(jobId, job));
    if (Date.now() - job.startedAt.toMillis() < STALE_RUNNING_MS) {
      return withBalance(uid, {jobId, state: "running" as const});
    }
    return withBalance(uid, jobResult(jobId, (await failPhotoJob(jobId, job.startedAt.toMillis(), "timeout")) ?? job));
  });

/** Refunds jobs that stopped while they ran, for example when the instance died. */
export async function sweepStalePhotoJobsOnce(nowMs = Date.now()): Promise<number> {
  let refunded = 0;
  const query = db.collection(PHOTO_JOBS).where("state", "==", "running").orderBy(admin.firestore.FieldPath.documentId());
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  do {
    const page = await (cursor ? query.startAfter(cursor) : query).limit(200).get();
    for (const doc of page.docs) {
      const job = doc.data() as PhotoJob;
      if (nowMs - job.startedAt.toMillis() < STALE_RUNNING_MS) continue;
      const failed = await failPhotoJob(doc.id, job.startedAt.toMillis(), "timeout");
      if (failed?.refunded) refunded++;
    }
    cursor = page.size === 200 ? page.docs[page.docs.length - 1] : undefined;
  } while (cursor);
  for (const field of ["cleanupPending", "falCleanupPending"] as const) {
    await sweepCleanupQueue(field, nowMs);
  }
  const orphanProgress = db.collection(PHOTO_JOB_BUDGET).doc("cleanup");
  const orphanQuery = db.collection(PHOTO_FAL_CLEANUP).orderBy(admin.firestore.FieldPath.documentId());
  const orphanCursor = (await orphanProgress.get()).data()?.falOrphans;
  const orphans = await (typeof orphanCursor === "string" ? orphanQuery.startAfter(db.collection(PHOTO_FAL_CLEANUP).doc(orphanCursor)) : orphanQuery)
    .limit(CLEANUP_BATCH_SIZE).get();
  const orphanSweepStarted = Date.now();
  for (const doc of orphans.docs) {
    if (Date.now() - orphanSweepStarted >= CLEANUP_QUEUE_BUDGET_MS) break;
    const requestId = doc.data().falRequestId;
    if (typeof requestId === "string" && await deleteFalPayload(requestId, photoDeps)) await doc.ref.delete();
    await orphanProgress.set({falOrphans: doc.id}, {merge: true});
  }
  if (orphans.size < CLEANUP_BATCH_SIZE && Date.now() - orphanSweepStarted < CLEANUP_QUEUE_BUDGET_MS) {
    await orphanProgress.set({falOrphans: null}, {merge: true});
  }
  return refunded;
}

export const sweepStalePhotoJobs = onSchedule({
  schedule: "every 15 minutes", region: REGION, timeoutSeconds: 180, retryCount: 1, secrets: [falKey, ...r2Secrets],
}, async () => {
  const refunded = await sweepStalePhotoJobsOnce();
  if (refunded > 0) logger.info("photoWallpaper: refunded stale jobs.", {refunded});
});

/**
 * Account deletion: removes every stored result of the user's photo jobs, then the job records. A result that fails
 * to delete stops the run, so the job record that names it stays for a retry. A fal payload delete that fails does
 * not stop it: it moves to `photoFalCleanup` without the user id. The daily count is in `UID_KEYED`.
 */
export async function removePhotoJobsForAccount(uid: string, deps: PhotoDeps = photoDeps): Promise<void> {
  const jobs = await db.collection(PHOTO_JOBS).where("userId", "==", uid).get();
  const falCleanupStarted = Date.now();
  for (const doc of jobs.docs) {
    let job = doc.data() as PhotoJob;
    if (job.state === "running") {
      if (Date.now() - job.startedAt.toMillis() < STALE_RUNNING_MS) {
        throw new HttpsError("internal", "A photo job is still running. Retry account deletion.");
      }
      job = (await failPhotoJob(doc.id, job.startedAt.toMillis(), "timeout")) ?? job;
      if (job.state === "running") throw new HttpsError("internal", "Could not stop a photo job. Retry account deletion.");
    }
    const key = job.resultKey;
    if (key) await deps.remove(key);
    if (job.falCleanupPending && job.falRequestId) {
      const falDeleted = Date.now() - falCleanupStarted < CLEANUP_QUEUE_BUDGET_MS &&
        await deleteFalPayload(job.falRequestId, deps);
      if (!falDeleted) {
        await db.collection(PHOTO_FAL_CLEANUP).doc(job.falRequestId).set({
          falRequestId: job.falRequestId, at: admin.firestore.Timestamp.now(),
        });
      }
    }
    await doc.ref.delete();
  }
}
