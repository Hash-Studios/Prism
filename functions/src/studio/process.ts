import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {db, int, REGION, str} from "../common";
import {loadStudioConfig, type StudioIdentity} from "./config";
import {annotateWithVision, type KnownHash, runGates, type VisionAnnotate} from "./gates";
import {randomWallId, type Rng} from "./ids";
import {STUDIO_SERIES} from "./series";

export const studioSecret = defineSecret("STUDIO_SECRET");

/** A candidate is claimed at most this many times; the next claim marks it failed. */
export const STUDIO_MAX_ATTEMPTS = 3;
/** A "generating" claim older than this belongs to a run that died (the function timeout is 300 s). */
export const STUDIO_STALE_CLAIM_MS = 6 * 60_000;
export const STUDIO_WALL_JPEG_QUALITY = 90;
/** The app makes upload thumbnails with FlutterImageCompress: minWidth 400, default minHeight 1080, quality 85. */
export const STUDIO_THUMB_MIN_WIDTH = 400;
export const STUDIO_THUMB_MIN_HEIGHT = 1080;
export const STUDIO_THUMB_QUALITY = 85;

const DEFAULT_WORKER_BASE = "https://prismwalls.com";
const PUBLIC_ASSET_BASE = "https://prismwalls.com/api/ai/assets";
const GENERATE_TIMEOUT_MS = 150_000;
const TRANSFER_TIMEOUT_MS = 60_000;
const RAW_ASSET_KEY = /^ai\/studio\/(raw\/)?[A-Za-z0-9_-]+\.(jpg|webp|png)$/;
const PUBLISH_TRIES = 5;
const DOC_ID = /^[A-Za-z0-9_-]{1,64}$/;

export type CandidateStatus = "queued" | "generating" | "rejected" | "failed" | "pending_review";

export interface StudioProcessDeps {
  worker: {base: string; secret: string};
  annotate: VisionAnnotate;
  rng: Rng;
  nowMs: () => number;
}

/** The candidate can try again: network error, timeout, worker 409, 429 other than budget_exhausted, 5xx. */
class TransientError extends Error {}

/** The candidate cannot succeed; it is marked failed with `code`. */
class PermanentError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

/** The provider refused to return the image (worker 502 unsafe_output); the candidate is rejected with `code`. */
class RejectedError extends PermanentError {}

interface WorkerImage {
  imageUrl: string;
  key: string;
  width: number | null;
  height: number | null;
  contentType: string;
  bytes: number | null;
  model: string;
  provider: string;
  seed: number | null;
  costUsd: number | null;
}

const num = (value: unknown): number | null => typeof value === "number" && Number.isFinite(value) ? value : null;
const message = (err: unknown): string => (err instanceof Error ? err.message : String(err)).slice(0, 500);

/** The thumbnail size the app makes for an upload of `width` x `height`. */
export function thumbSize(width: number, height: number): {width: number; height: number} {
  const scale = Math.max(1, Math.min(width / STUDIO_THUMB_MIN_WIDTH, height / STUDIO_THUMB_MIN_HEIGHT));
  return {width: Math.round(width / scale), height: Math.round(height / scale)};
}

/** The `size` text the app writes for an upload, for example "2.10MB". */
export function humanSize(bytes: number): string {
  return `${(bytes / 1024 / 1024).toFixed(2)}MB`;
}

export function workerBaseUrl(): string {
  return (process.env.STUDIO_WORKER_BASE_URL ?? "").trim().replace(/\/+$/, "") || DEFAULT_WORKER_BASE;
}

async function workerFetch(
  deps: StudioProcessDeps, what: string, path: string, init: RequestInit, timeoutMs: number,
): Promise<Response> {
  try {
    return await fetch(`${deps.worker.base}${path}`, {
      ...init,
      headers: {...(init.headers as Record<string, string> | undefined), "x-studio-secret": deps.worker.secret},
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (err) {
    throw new TransientError(`${what}: ${message(err)}`);
  }
}

/**
 * Maps a worker error answer `{error: code, message}`: budget_exhausted and other 4xx fail the candidate, 502
 * unsafe_output rejects it, and 409, other 429s and 5xx are transient.
 */
async function workerError(response: Response, what: string): Promise<Error> {
  let code = "";
  try {
    const error = ((await response.json()) as {error?: unknown} | null)?.error;
    if (typeof error === "string") code = error.slice(0, 40);
  } catch {
    // Not JSON: the status decides.
  }
  const text = `${what}: worker ${response.status}${code ? ` ${code}` : ""}`;
  if (code === "budget_exhausted") return new PermanentError("budget_exhausted", text);
  if (code === "unsafe_output") return new RejectedError("unsafe_output", text);
  if (response.status === 409 || response.status === 429 || response.status >= 500) return new TransientError(text);
  return new PermanentError(code || `http_${response.status}`, text);
}

async function generate(deps: StudioProcessDeps, candidateId: string, c: admin.firestore.DocumentData) {
  const response = await workerFetch(deps, "generate", "/api/ai/studio/generations", {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({id: candidateId, prompt: c.prompt, model: c.model, width: c.width, height: c.height,
      ...(typeof c.seed === "number" ? {seed: c.seed} : {})}),
  }, GENERATE_TIMEOUT_MS);
  if (!response.ok) throw await workerError(response, "generate");
  const body = (await response.json().catch(() => null)) as Record<string, unknown> | null;
  const imageUrl = str(body?.imageUrl);
  if (!imageUrl.startsWith("https://")) throw new TransientError("generate: the worker answer has no imageUrl.");
  return {
    imageUrl,
    key: str(body?.key),
    width: num(body?.width),
    height: num(body?.height),
    contentType: str(body?.contentType),
    bytes: num(body?.bytes),
    model: str(body?.model),
    provider: str(body?.provider),
    seed: num(body?.seed),
    costUsd: num(body?.costUsd),
  } satisfies WorkerImage;
}

async function download(url: string): Promise<Buffer> {
  let response: Response;
  try {
    response = await fetch(url, {signal: AbortSignal.timeout(TRANSFER_TIMEOUT_MS)});
  } catch (err) {
    throw new TransientError(`download: ${message(err)}`);
  }
  if (!response.ok) throw new TransientError(`download: ${response.status}`);
  return Buffer.from(await response.arrayBuffer());
}

/** Uploads a JPEG to the worker and returns its public URL. */
async function putAsset(deps: StudioProcessDeps, key: string, bytes: Buffer): Promise<string> {
  const response = await workerFetch(deps, "upload", `/api/ai/studio/assets/${key}`, {
    method: "PUT",
    headers: {"content-type": "image/jpeg"},
    body: new Uint8Array(bytes),
  }, TRANSFER_TIMEOUT_MS);
  if (!response.ok) throw await workerError(response, "upload");
  const url = str(((await response.json().catch(() => null)) as {url?: unknown} | null)?.url);
  return url.startsWith("https://") ? url : `${PUBLIC_ASSET_BASE}/${key}`;
}

/** Best effort: a raw image that stays behind costs storage, nothing else. */
async function deleteAsset(deps: StudioProcessDeps, key: string): Promise<void> {
  if (!RAW_ASSET_KEY.test(key)) {
    logger.warn("studio: not deleting an asset with an unexpected key.", {key});
    return;
  }
  try {
    const response = await workerFetch(deps, "delete", `/api/ai/studio/assets/${key}`, {method: "DELETE"},
      TRANSFER_TIMEOUT_MS);
    if (!response.ok) logger.warn("studio: could not delete a rejected image.", {key, status: response.status});
  } catch (err) {
    logger.warn("studio: could not delete a rejected image.", {key, err: message(err)});
  }
}

/** The final wallpaper (same size, mozjpeg, no metadata) and the thumbnail the app would make. */
export async function renderWallpaper(bytes: Buffer): Promise<{wall: Buffer; thumb: Buffer; width: number; height: number}> {
  const {data: wall, info} = await sharp(bytes).jpeg({quality: STUDIO_WALL_JPEG_QUALITY, mozjpeg: true})
    .toBuffer({resolveWithObject: true});
  const size = thumbSize(info.width, info.height);
  const thumb = await sharp(bytes).resize(size.width, size.height, {fit: "fill"})
    .jpeg({quality: STUDIO_THUMB_QUALITY}).toBuffer();
  return {wall, thumb, width: info.width, height: info.height};
}

async function loadKnownHashes(): Promise<KnownHash[]> {
  const snap = await db.collection("studioHashes").select("hash", "wallId").get();
  return snap.docs.map((d) => ({hash: str(d.data().hash), wallId: str(d.data().wallId)}));
}

/**
 * Moves a queued candidate to generating and counts the attempt. Null when there is nothing to do: the doc is gone,
 * it is terminal, or this claim is one too many (then it is marked failed). Throws while another attempt holds a
 * fresh claim, so the event comes back after that attempt ends or dies.
 */
async function claimCandidate(ref: admin.firestore.DocumentReference, nowMs: number) {
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (!data) return null;
    if (data.status === "generating") {
      const claimedAt = data.claimedAt instanceof admin.firestore.Timestamp ? data.claimedAt.toMillis() : 0;
      if (nowMs - claimedAt < STUDIO_STALE_CLAIM_MS) {
        throw new Error("studio: another attempt is processing this candidate; retry later.");
      }
    } else if (data.status !== "queued") {
      return null;
    }
    const attempts = int(data.attempts) + 1;
    const updatedAt = admin.firestore.FieldValue.serverTimestamp();
    if (attempts > STUDIO_MAX_ATTEMPTS) {
      tx.update(ref, {status: "failed", error: "max_attempts", updatedAt});
      return null;
    }
    tx.update(ref, {status: "generating", attempts, claimedAt: admin.firestore.Timestamp.fromMillis(nowMs), updatedAt});
    return {data, attempts};
  });
}

/**
 * Creates the pending wall, its hash doc and the candidate's pending_review state in one transaction. Null when the
 * candidate is no longer held by this attempt.
 */
async function publishWall(params: {
  ref: admin.firestore.DocumentReference;
  attempts: number;
  wall: admin.firestore.DocumentData;
  hash: string;
  candidateUpdate: admin.firestore.DocumentData;
  rng: Rng;
}): Promise<string | null> {
  const {ref, attempts, wall, hash, rng} = params;
  for (let i = 0; i < PUBLISH_TRIES; i++) {
    const wallId = randomWallId(rng);
    const wallRef = db.collection("walls").doc(wallId);
    const outcome = await db.runTransaction(async (tx) => {
      const current = (await tx.get(ref)).data();
      if (current?.status !== "generating" || current.attempts !== attempts) return "lost";
      if ((await tx.get(wallRef)).exists) return "taken";
      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.create(wallRef, {...wall, id: wallId});
      tx.create(db.collection("studioHashes").doc(ref.id), {hash, wallId, candidateId: ref.id, createdAt: now});
      tx.update(ref, {...params.candidateUpdate, status: "pending_review", wallId, updatedAt: now,
        lastError: admin.firestore.FieldValue.delete()});
      return "published";
    });
    if (outcome === "published") return wallId;
    if (outcome === "lost") return null;
  }
  throw new TransientError(`publish: no free wall id after ${PUBLISH_TRIES} tries.`);
}

function wallRecord(params: {
  identity: StudioIdentity;
  candidate: admin.firestore.DocumentData;
  runId: string;
  candidateId: string;
  image: WorkerImage;
  wallUrl: string;
  thumbUrl: string;
  rendered: {wall: Buffer; width: number; height: number};
  hash: string;
}): admin.firestore.DocumentData {
  const {identity, candidate, image, rendered} = params;
  const series = STUDIO_SERIES.find((s) => s.id === candidate.seriesId);
  // The fields of the app's createRecord (publishWall adds `id`), then the Studio fields.
  return {
    by: identity.by,
    email: identity.email,
    userPhoto: identity.userPhoto,
    wallpaper_provider: "Prism",
    wallpaper_thumb: params.thumbUrl,
    wallpaper_url: params.wallUrl,
    resolution: `${rendered.width}x${rendered.height}`,
    size: humanSize(rendered.wall.length),
    title: str(candidate.title),
    category: str(candidate.category),
    desc: `${series?.name ?? "Prism Studio"} by Prism Studio`,
    review: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    collections: ["community"],
    tags: Array.isArray(candidate.tags) ? candidate.tags.map(String) : [],
    isAiGenerated: true,
    aiProvider: "fal",
    aiModel: image.model || str(candidate.model),
    aiPrompt: str(candidate.prompt),
    origin: "studio",
    seriesId: str(candidate.seriesId),
    studioCandidateId: params.candidateId,
    studioRunId: params.runId,
    pHash: params.hash,
  };
}

/**
 * True for a wall that processStudioCandidate made: origin "studio" and a candidate doc that points back at it.
 * A client can write `origin` on its own wall, but it cannot write studioRuns.
 */
export async function isStudioWall(wallId: string, data: admin.firestore.DocumentData): Promise<boolean> {
  if (data.origin !== "studio") return false;
  const runId = str(data.studioRunId);
  const candidateId = str(data.studioCandidateId);
  if (!DOC_ID.test(runId) || !DOC_ID.test(candidateId)) return false;
  try {
    const candidate = await db.collection("studioRuns").doc(runId).collection("candidates").doc(candidateId).get();
    return candidate.data()?.wallId === wallId;
  } catch (err) {
    logger.warn("studio: could not check the wall's candidate.", {wallId, err: message(err)});
    return false;
  }
}

/**
 * One candidate from queued to pending_review, rejected or failed. Transient errors put it back to queued and throw,
 * so the event retries; STUDIO_MAX_ATTEMPTS bounds the retries.
 */
export async function processCandidate(runId: string, candidateId: string, deps: StudioProcessDeps): Promise<void> {
  const ref = db.collection("studioRuns").doc(runId).collection("candidates").doc(candidateId);
  const claim = await claimCandidate(ref, deps.nowMs());
  if (claim === null) return;
  const {data: candidate, attempts} = claim;
  let image: WorkerImage | null = null;
  try {
    const config = await loadStudioConfig();
    if (!config.generationEnabled || config.identity === null) {
      throw new PermanentError("disabled", "Studio generation is off in studioConfig/current.");
    }
    image = await generate(deps, candidateId, candidate);
    const bytes = await download(image.imageUrl);
    const gates = await runGates(bytes, {annotate: deps.annotate, knownHashes: loadKnownHashes});
    if (!gates.passed) {
      await ref.update({
        status: "rejected",
        reasons: gates.reasons,
        gates: {passed: false, reasons: gates.reasons, details: gates.details},
        worker: image,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await deleteAsset(deps, image.key);
      logger.info("studio: candidate rejected.", {runId, candidateId, reasons: gates.reasons});
      return;
    }
    const rendered = await renderWallpaper(bytes);
    const wallUrl = await putAsset(deps, `ai/studio/${candidateId}.jpg`, rendered.wall);
    const thumbUrl = await putAsset(deps, `ai/studio/thumb_${candidateId}.jpg`, rendered.thumb);
    const wallId = await publishWall({
      ref,
      attempts,
      wall: wallRecord({
        identity: config.identity, candidate, runId, candidateId, image, wallUrl, thumbUrl, rendered, hash: gates.hash,
      }),
      hash: gates.hash,
      candidateUpdate: {gates: {passed: true, reasons: [], details: gates.details}, worker: image},
      rng: deps.rng,
    });
    if (wallId === null) {
      logger.warn("studio: another attempt took this candidate over; not publishing.", {runId, candidateId});
      return;
    }
    logger.info("studio: candidate is pending review.", {runId, candidateId, wallId});
  } catch (err) {
    const updatedAt = admin.firestore.FieldValue.serverTimestamp();
    if (err instanceof RejectedError) {
      await ref.update({status: "rejected", reasons: [err.code], lastError: err.message, updatedAt});
      logger.info("studio: candidate rejected.", {runId, candidateId, reasons: [err.code]});
      return;
    }
    if (err instanceof PermanentError) {
      await ref.update({status: "failed", error: err.code, lastError: err.message, ...(image ? {worker: image} : {}),
        updatedAt});
      logger.warn("studio: candidate failed.", {runId, candidateId, error: err.code});
      return;
    }
    await ref.update({status: "queued", lastError: message(err), updatedAt});
    logger.warn("studio: candidate will retry.", {runId, candidateId, attempts, err: message(err)});
    throw err;
  }
}

export const processStudioCandidate = onDocumentCreated(
  {
    document: "studioRuns/{runId}/candidates/{candidateId}",
    region: REGION,
    timeoutSeconds: 300,
    memory: "1GiB",
    secrets: [studioSecret],
    retry: true,
    maxInstances: 5,
  },
  async (event) => {
    await processCandidate(event.params.runId, event.params.candidateId, {
      worker: {base: workerBaseUrl(), secret: studioSecret.value()},
      annotate: annotateWithVision,
      rng: Math.random,
      nowMs: Date.now,
    });
  },
);
