import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, int, REGION, str} from "../common";
import {isPreviewUrl} from "../pushGallery";
import {R2Storage, r2Env, r2Secrets} from "../r2Storage";
import {loadStudioConfig} from "./config";
import {annotateWithVision, STUDIO_VISION_LONG_EDGE, type VisionAnnotate, visionCheck} from "./gates";
import {isStudioWall} from "./isStudioWall";
import {
  deleteAsset, download, generate, PermanentError, RejectedError, STUDIO_MAX_ATTEMPTS, STUDIO_STALE_CLAIM_MS,
  studioSecret, TransientError, workerBaseUrl,
} from "./process";
import {STUDIO_COMPOSITION, STUDIO_DEPTH_COMPOSITION} from "./series";

/**
 * Desktop companions: a wide version of an approved Studio wall, made from the same prompt and model. The originals
 * stay in the private bucket; only a small thumbnail is public. `desktopCompanions/{shareId}` is server-only, and the
 * wall's `desktopVariant` field is written only here.
 */
export const DESKTOP_COMPANIONS = "desktopCompanions";
export const DESKTOP_SIZE = {width: 2560, height: 1600} as const;
export const DESKTOP_WIDE_SIZE = {width: 2560, height: 1440} as const;
export const DESKTOP_THUMB_SIZE = {width: 960, height: 600} as const;
export const DESKTOP_JPEG_QUALITY = 90;
export const DESKTOP_THUMB_QUALITY = 80;
/** What the Worker reserves from the Studio budget per image (FAL_MODELS in infra/cloudflare/worker/src/ai.ts). */
export const DESKTOP_MODEL_COST_USD: Readonly<Record<string, number>> = {
  "openai/gpt-image-2.5/sunburst/text-to-image": 0.07,
  "fal-ai/bytedance/seedream/v4.5/text-to-image": 0.04,
  "fal-ai/bytedance/seedream/v5/lite/text-to-image": 0.04,
};
/** Cloud Vision safe search, text and logo detection: 3 units at $1.50 per 1,000. */
export const DESKTOP_VISION_COST_USD = 0.0045;

export const DESKTOP_COMPOSITION =
  "Wide 16:10 desktop wallpaper, full bleed, landscape. Spread the scene across the width. The main subject sits in " +
  "the left or right third, not the centre. The centre, the top tenth and the bottom tenth are calm and low in " +
  "detail, so desktop icons, a menu bar and a dock stay readable and a 16:9 crop loses nothing important. Crisp, " +
  "clean detail, no clutter.";

const SHARE_ID = /^[A-Za-z0-9_-]{1,200}$/;

export type DesktopSkip = "not_approved" | "not_studio" | "duo" | "model" | "prompt" | "exists";

export interface DesktopObject {object: string; sha256: string; width: number; height: number; bytes: number}

/** The public part, on the wall doc. `v` names the version, so caches of an old companion are never served. */
export interface DesktopVariant {v: string; width: number; height: number; wideHeight: number; thumb: string}

export interface DesktopDeps {
  worker: {base: string; secret: string};
  annotate: VisionAnnotate;
  nowMs: () => number;
}

export type DesktopOutcome = "ready" | "skipped" | "busy" | "deferred" | "rejected" | "failed";

/**
 * The wall prompt with its phone composition swapped for the desktop one. The scene, palette and series style stay
 * word for word, and so do the exclusions of the phone composition. Null when the prompt has no known composition.
 */
export function desktopPrompt(aiPrompt: string): string | null {
  for (const composition of [STUDIO_COMPOSITION, STUDIO_DEPTH_COMPOSITION]) {
    if (!aiPrompt.endsWith(composition)) continue;
    const scene = aiPrompt.slice(0, -composition.length).trim();
    if (!scene) return null;
    const exclusions = composition.slice(composition.indexOf("The image contains"));
    const prompt = `${scene} ${DESKTOP_COMPOSITION} ${exclusions}`;
    return prompt.length <= 2000 ? prompt : null;
  }
  return null;
}

/** What one wall would cost: one generation at the wall's model plus the Vision check. */
export function desktopCostUsd(model: string): number {
  return Math.round(((DESKTOP_MODEL_COST_USD[model] ?? 0) + DESKTOP_VISION_COST_USD) * 10000) / 10000;
}

/** The prompt and model of a wall that can get a companion, or why it cannot. Studio provenance is checked apart. */
export function desktopEligibility(wall: admin.firestore.DocumentData | undefined):
  {prompt: string; model: string} | {skip: DesktopSkip} {
  if (wall?.review !== true) return {skip: "not_approved"};
  if (wall.origin !== "studio" || !SHARE_ID.test(str(wall.id))) return {skip: "not_studio"};
  const tags = Array.isArray(wall.tags) ? wall.tags.map(String) : [];
  if (wall.duoPresetId || tags.includes("duo") || tags.includes("duo-reveal")) return {skip: "duo"};
  if (parseDesktopVariant(wall.desktopVariant)) return {skip: "exists"};
  const model = str(wall.aiModel);
  if (!Object.prototype.hasOwnProperty.call(DESKTOP_MODEL_COST_USD, model)) return {skip: "model"};
  const prompt = desktopPrompt(str(wall.aiPrompt));
  return prompt ? {prompt, model} : {skip: "prompt"};
}

export function parseDesktopVariant(value: unknown): DesktopVariant | null {
  if (!value || typeof value !== "object") return null;
  const data = value as Record<string, unknown>;
  if (typeof data.v !== "string" || !/^[a-f0-9]{16}$/.test(data.v) || data.width !== DESKTOP_SIZE.width ||
    data.height !== DESKTOP_SIZE.height || data.wideHeight !== DESKTOP_WIDE_SIZE.height ||
    typeof data.thumb !== "string" || !isPreviewUrl(data.thumb)) return null;
  return {v: data.v, width: data.width, height: data.height, wideHeight: data.wideHeight, thumb: data.thumb};
}

const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");
export const desktopVersion = (originalSha256: string) => originalSha256.slice(0, 16);
/** Worker generation id: stable per wall and attempt, inside the Worker's 8 to 64 character id rule. */
export const desktopGenerationId = (shareId: string, attempt: number) =>
  `desk_${createHash("sha256").update(shareId).digest("hex").slice(0, 32)}_${attempt}`;

/** The 16:10 original, its centred 16:9 crop and the public thumbnail. Smaller output is refused, never enlarged. */
export async function renderDesktop(bytes: Buffer): Promise<{original: Buffer; wide: Buffer; thumb: Buffer}> {
  const {default: sharp} = await import("sharp");
  const meta = await sharp(bytes).metadata();
  if ((meta.width ?? 0) < DESKTOP_SIZE.width || (meta.height ?? 0) < DESKTOP_SIZE.height) {
    throw new PermanentError("desktop_size", `Desktop output is ${meta.width}x${meta.height}, below 2560x1600.`);
  }
  const cover = await sharp(bytes).resize(DESKTOP_SIZE.width, DESKTOP_SIZE.height, {fit: "cover"}).toBuffer();
  const original = await sharp(cover).jpeg({quality: DESKTOP_JPEG_QUALITY, mozjpeg: true}).toBuffer();
  const wide = await sharp(cover).extract({left: 0, top: (DESKTOP_SIZE.height - DESKTOP_WIDE_SIZE.height) / 2,
    width: DESKTOP_WIDE_SIZE.width, height: DESKTOP_WIDE_SIZE.height}).jpeg({quality: DESKTOP_JPEG_QUALITY, mozjpeg: true})
    .toBuffer();
  const thumb = await sharp(cover).resize(DESKTOP_THUMB_SIZE.width, DESKTOP_THUMB_SIZE.height)
    .jpeg({quality: DESKTOP_THUMB_QUALITY, mozjpeg: true}).toBuffer();
  return {original, wide, thumb};
}

export const desktopObjectName = (shareId: string, sha: string) => `desktop-originals/${shareId}/${sha}.jpg`;
export const desktopThumbObject = (sha: string) => `previews/desktop-${sha}.jpg`;

function desktopThumbUrl(sha: string): string {
  const base = r2Env("R2_PREVIEW_BASE_URL");
  if (!base) throw new PermanentError("desktop_storage", "R2_PREVIEW_BASE_URL is not configured.");
  return `${base.replace(/\/$/, "")}/${desktopThumbObject(sha)}`;
}

type Claim = {attempts: number} | Exclude<DesktopOutcome, "ready" | "rejected" | "deferred">;

async function claim(ref: admin.firestore.DocumentReference, wallPath: string, nowMs: number): Promise<Claim> {
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (data?.status === "ready" || data?.status === "rejected") return "skipped";
    if (data?.status === "failed") return "failed";
    if (data?.status === "generating") {
      const claimedAt = data.claimedAt instanceof admin.firestore.Timestamp ? data.claimedAt.toMillis() : 0;
      if (nowMs - claimedAt < STUDIO_STALE_CLAIM_MS) return "busy";
    }
    const attempts = int(data?.attempts) + 1;
    const updatedAt = admin.firestore.FieldValue.serverTimestamp();
    if (attempts > STUDIO_MAX_ATTEMPTS) {
      tx.set(ref, {status: "failed", error: "max_attempts", updatedAt}, {merge: true});
      return "failed";
    }
    tx.set(ref, {status: "generating", attempts, wallPath, claimedAt: admin.firestore.Timestamp.fromMillis(nowMs),
      updatedAt}, {merge: true});
    return {attempts};
  });
}

async function release(ref: admin.firestore.DocumentReference, attempts: number, update: admin.firestore.DocumentData) {
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (data?.status !== "generating" || data.attempts !== attempts) return;
    tx.set(ref, {...update, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
  });
}

async function seedOf(wall: admin.firestore.DocumentData): Promise<number | undefined> {
  const runId = str(wall.studioRunId);
  const candidateId = str(wall.studioCandidateId);
  if (!runId || !candidateId) return undefined;
  const seed = (await db.collection("studioRuns").doc(runId).collection("candidates").doc(candidateId).get())
    .data()?.seed;
  return typeof seed === "number" && Number.isInteger(seed) ? seed : undefined;
}

async function deleteObjects(objects: Array<{kind: "private" | "preview"; object: string}>): Promise<void> {
  const storage = new R2Storage();
  for (const {kind, object} of objects) {
    await storage.delete(kind, object).catch((error) =>
      logger.warn("desktop: could not delete an object.", {object, error: String(error)}));
  }
}

/**
 * Makes the companion of one approved Studio wall, at most once. A second call after "ready" does nothing, a crash
 * mid-way is retried by the next call, and STUDIO_MAX_ATTEMPTS bounds the spend. A Studio budget refusal leaves the
 * wall "deferred" without using an attempt. Transient errors throw after the claim is given back.
 */
export async function makeDesktopCompanion(wallPath: string, deps: DesktopDeps): Promise<DesktopOutcome> {
  const wallRef = db.doc(wallPath);
  const wall = (await wallRef.get()).data();
  const eligible = desktopEligibility(wall);
  if ("skip" in eligible || !wall || !(await isStudioWall(wallRef.id, wall))) return "skipped";
  const shareId = str(wall.id);
  const ref = db.collection(DESKTOP_COMPANIONS).doc(shareId);
  const claimed = await claim(ref, wallPath, deps.nowMs());
  if (typeof claimed === "string") return claimed;
  const {attempts} = claimed;
  const stored: Array<{kind: "private" | "preview"; object: string}> = [];
  let workerKey = "";
  try {
    const seed = await seedOf(wall);
    const image = await generate(deps, desktopGenerationId(shareId, attempts), {prompt: eligible.prompt,
      model: eligible.model, width: DESKTOP_SIZE.width, height: DESKTOP_SIZE.height, ...(seed === undefined ? {} : {seed})});
    workerKey = image.key;
    const bytes = await download(image.imageUrl);
    const rendered = await renderDesktop(bytes);
    const {default: sharp} = await import("sharp");
    const visionJpeg = await sharp(rendered.original).resize({width: STUDIO_VISION_LONG_EDGE,
      height: STUDIO_VISION_LONG_EDGE, fit: "inside"}).jpeg({quality: 85}).toBuffer();
    const vision = visionCheck(await deps.annotate(visionJpeg));
    if (vision.reasons.length > 0) {
      await release(ref, attempts, {status: "rejected", reasons: vision.reasons, model: eligible.model,
        costUsd: desktopCostUsd(eligible.model)});
      logger.info("desktop: companion rejected.", {shareId, reasons: vision.reasons});
      return "rejected";
    }
    const originalSha = sha256(rendered.original);
    const wideSha = sha256(rendered.wide);
    const thumbSha = sha256(rendered.thumb);
    const original: DesktopObject = {object: desktopObjectName(shareId, originalSha), sha256: originalSha,
      ...DESKTOP_SIZE, bytes: rendered.original.length};
    const wide: DesktopObject = {object: desktopObjectName(shareId, wideSha), sha256: wideSha, ...DESKTOP_WIDE_SIZE,
      bytes: rendered.wide.length};
    const thumbUrl = desktopThumbUrl(thumbSha);
    if (!isPreviewUrl(thumbUrl)) throw new PermanentError("desktop_storage", "The desktop thumbnail URL is not public.");
    const storage = new R2Storage();
    for (const [kind, object, body] of [["private", original.object, rendered.original],
      ["private", wide.object, rendered.wide], ["preview", desktopThumbObject(thumbSha), rendered.thumb]] as const) {
      await storage.put(kind, object, body, {sha256: sha256(body)}, "image/jpeg");
      stored.push({kind, object});
    }
    const variant: DesktopVariant = {v: desktopVersion(originalSha), ...DESKTOP_SIZE,
      wideHeight: DESKTOP_WIDE_SIZE.height, thumb: thumbUrl};
    const linked = await db.runTransaction(async (tx) => {
      const [latestWall, manifest] = await Promise.all([tx.get(wallRef), tx.get(ref)]);
      if (manifest.data()?.status !== "generating" || manifest.data()?.attempts !== attempts) return "lost" as const;
      const latest = latestWall.data();
      const now = admin.firestore.FieldValue.serverTimestamp();
      if (latest?.review !== true || str(latest.id) !== shareId || latest.aiPrompt !== wall.aiPrompt) {
        tx.set(ref, {status: "failed", error: "wall_changed", updatedAt: now}, {merge: true});
        return "changed" as const;
      }
      tx.set(ref, {status: "ready", wallPath, model: eligible.model, prompt: eligible.prompt,
        ...(seed === undefined ? {} : {seed}), costUsd: desktopCostUsd(eligible.model), original, wide,
        thumb: {object: desktopThumbObject(thumbSha), sha256: thumbSha, url: thumbUrl, ...DESKTOP_THUMB_SIZE},
        variant, error: admin.firestore.FieldValue.delete(), updatedAt: now}, {merge: true});
      tx.update(wallRef, {desktopVariant: variant});
      return "linked" as const;
    });
    if (linked !== "linked") {
      await deleteObjects(stored);
      return linked === "lost" ? "busy" : "failed";
    }
    logger.info("desktop: companion ready.", {shareId, v: variant.v});
    return "ready";
  } catch (error) {
    if (stored.length > 0) await deleteObjects(stored);
    const message = (error instanceof Error ? error.message : String(error)).slice(0, 500);
    if (error instanceof PermanentError && error.code === "budget_exhausted") {
      await release(ref, attempts, {status: "deferred", attempts: attempts - 1, lastError: message});
      return "deferred";
    }
    if (error instanceof RejectedError) {
      await release(ref, attempts, {status: "rejected", reasons: [error.code], lastError: message});
      return "rejected";
    }
    if (error instanceof PermanentError) {
      await release(ref, attempts, {status: "failed", error: error.code, lastError: message});
      logger.warn("desktop: companion failed.", {shareId, error: error.code});
      return "failed";
    }
    await release(ref, attempts, {status: "queued", lastError: message});
    if (error instanceof TransientError) logger.warn("desktop: companion will retry.", {shareId, attempts, message});
    throw error;
  } finally {
    if (workerKey) await deleteAsset(deps, workerKey).catch(() => undefined);
  }
}

/** The ready companion of a wall, checked against the version its wall doc names. */
export async function readyDesktopCompanion(shareId: string, wall: admin.firestore.DocumentData | undefined,
  tx?: admin.firestore.Transaction): Promise<{original: DesktopObject; wide: DesktopObject; variant: DesktopVariant}> {
  const variant = parseDesktopVariant(wall?.desktopVariant);
  const ref = db.collection(DESKTOP_COMPANIONS).doc(shareId);
  const manifest = (tx ? await tx.get(ref) : await ref.get()).data();
  const valid = (value: unknown, size: {width: number; height: number}): value is DesktopObject => {
    const item = value as Partial<DesktopObject> | undefined;
    return typeof item?.sha256 === "string" && /^[a-f0-9]{64}$/.test(item.sha256) &&
      item.object === desktopObjectName(shareId, item.sha256) && item.width === size.width && item.height === size.height;
  };
  if (!variant || !SHARE_ID.test(shareId) || manifest?.status !== "ready" || !valid(manifest.original, DESKTOP_SIZE) ||
    !valid(manifest.wide, DESKTOP_WIDE_SIZE) || desktopVersion(manifest.original.sha256) !== variant.v) {
    throw new Error("Desktop companion unavailable");
  }
  return {original: manifest.original, wide: manifest.wide, variant};
}

/** Removes the objects and the manifest of a deleted wall's companion. */
export async function removeDesktopCompanion(shareId: string): Promise<void> {
  if (!SHARE_ID.test(shareId)) return;
  const ref = db.collection(DESKTOP_COMPANIONS).doc(shareId);
  const manifest = (await ref.get()).data();
  if (!manifest) return;
  const objects: Array<{kind: "private" | "preview"; object: string}> = [];
  for (const key of ["original", "wide"]) {
    const object = str(manifest[key]?.object);
    if (object.startsWith(`desktop-originals/${shareId}/`)) objects.push({kind: "private", object});
  }
  const thumb = str(manifest.thumb?.object);
  if (/^previews\/desktop-[a-f0-9]{64}\.jpg$/.test(thumb)) objects.push({kind: "preview", object: thumb});
  await deleteObjects(objects);
  await ref.delete();
}

export const onStudioWallDesktop = onDocumentWritten({document: "walls/{wallId}", region: REGION, retry: true,
  memory: "1GiB", timeoutSeconds: 300, maxInstances: 2, secrets: [studioSecret, ...r2Secrets]}, async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) {
    if (before?.desktopVariant) await removeDesktopCompanion(str(before.id));
    return;
  }
  // Only the approval itself starts a companion; the backfill script covers walls approved before.
  if (after.review !== true || before?.review === true || after.origin !== "studio" || after.desktopVariant) return;
  if (!(await loadStudioConfig()).desktopCompanions) return;
  await makeDesktopCompanion(event.document, {worker: {base: workerBaseUrl(), secret: studioSecret.value()},
    annotate: annotateWithVision, nowMs: Date.now});
});
