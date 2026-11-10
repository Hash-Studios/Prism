import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {isDeepStrictEqual} from "node:util";
import {logger} from "firebase-functions/v2";
import {db} from "./common";
import {uploadFileKey} from "./completedWallUpload";
import {inspectLiveVideo, isLiveFramePath, isLiveVideoPath, LIVE_FRAME_COUNT, type LiveVideoError} from "./liveVideo";
import {ownedThumbnailUrl, stored, type StoredUpload} from "./ownedAssetDelivery";
import {R2Storage, r2Env} from "./r2Storage";

/** A file the client uploaded through githubPutFile and names on the wall. */
export type LiveFile = {url: string; path: string; sha: string};
/** The `live` map a client may write when it creates a live wall. */
export type ClientLive = {video: string; videoPath: string; videoSha: string; frames: LiveFile[]};

export type LiveProofError = LiveVideoError | "bad_fields" | "no_owner" | "unproven_file";

const CLIENT_KEYS = ["frames", "video", "videoPath", "videoSha"];
const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");
const blobSha = (bytes: Buffer) => createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
const isText = (value: unknown, max = 1024): value is string => typeof value === "string" && value.length > 0 &&
  value.length <= max;

export const isLiveWall = (data: admin.firestore.DocumentData | undefined): boolean => data?.kind === "live";

/** The client half of `walls.live`, or null when its shape is wrong. */
export function parseClientLive(raw: unknown): ClientLive | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const value = raw as Record<string, unknown>;
  if (!isDeepStrictEqual(Object.keys(value).sort(), CLIENT_KEYS)) return null;
  const file = (url: unknown, path: unknown, sha: unknown): LiveFile | null =>
    isText(url) && isText(path) && typeof sha === "string" && /^[a-f0-9]{40}$/.test(sha) ? {url, path, sha} : null;
  const video = file(value.video, value.videoPath, value.videoSha);
  if (!video || !isLiveVideoPath(video.path) || !Array.isArray(value.frames) ||
    value.frames.length !== LIVE_FRAME_COUNT) return null;
  const frames: LiveFile[] = [];
  for (const raw of value.frames) {
    if (!raw || typeof raw !== "object" || !isDeepStrictEqual(Object.keys(raw).sort(), ["path", "sha", "url"])) return null;
    const frame = file((raw as LiveFile).url, (raw as LiveFile).path, (raw as LiveFile).sha);
    if (!frame || !isLiveFramePath(frame.path)) return null;
    frames.push(frame);
  }
  if (new Set([video.path, ...frames.map((f) => f.path)]).size !== LIVE_FRAME_COUNT + 1) return null;
  return {video: video.url, videoPath: video.path, videoSha: video.sha, frames};
}

/** Frame URLs the image moderation may fetch: only public previews on the R2 preview host. */
export function liveModerationFrameUrls(data: admin.firestore.DocumentData): string[] {
  if (!isLiveWall(data)) return [];
  const frames = (data.live as {frames?: unknown} | undefined)?.frames;
  const base = r2Env("R2_PREVIEW_BASE_URL")?.replace(/\/$/, "");
  if (!base || !Array.isArray(frames)) return [];
  const pattern = new RegExp(`^${base.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/previews/[a-f0-9]{64}\\.img$`);
  return frames.map((frame) => (frame as {url?: unknown})?.url).filter((url): url is string =>
    typeof url === "string" && pattern.test(url)).slice(0, LIVE_FRAME_COUNT);
}

export interface LiveProofDeps {
  readPrivate: (asset: StoredUpload) => Promise<Buffer>;
  previewMatches: (asset: StoredUpload) => Promise<boolean>;
}

const defaultDeps = (): LiveProofDeps => {
  const client = new R2Storage();
  return {
    readPrivate: (asset) => client.get("private", asset.object),
    previewMatches: async (asset) => {
      const head = await client.head("preview", `previews/${asset.previewObjectId}.img`);
      return !!head && head.objectId === asset.objectId && head.sha256 === asset.sha256;
    },
  };
};

/** Proves that [uid] completed [file] through githubPutFile into owned storage. Returns the stored bytes. */
async function proveFile(uid: string, file: LiveFile, deps: LiveProofDeps): Promise<Buffer | null> {
  const repo = process.env.GH_REPO_WALLS?.trim();
  if (!repo) return null;
  const ref = {path: file.path, sha: file.sha, sourceKind: "owned" as const};
  const key = uploadFileKey(repo, ref);
  const [receipt, tombstone] = await Promise.all([db.collection("githubUploads").doc(key).get(),
    db.collection("ownedUploadDeletions").doc(key).get()]);
  const record = receipt.data();
  const asset = record?.retainedAsset;
  if (!record || tombstone.exists || record.uid !== uid || record.repo !== repo || record.path !== file.path ||
    record.sha !== file.sha || record.sourceKind !== "owned" || !stored(asset) || asset.uid !== uid ||
    !asset.previewObjectId || file.url !== ownedThumbnailUrl(asset) || !await deps.previewMatches(asset)) return null;
  const bytes = await deps.readPrivate(asset);
  return sha256(bytes) === asset.sha256 && blobSha(bytes) === file.sha ? bytes : null;
}

/** Checks a live wall's files from storage. The video facts come from its MP4 headers, never from the client. */
export async function proveLiveSubmission(uid: string | null, raw: unknown, deps: LiveProofDeps = defaultDeps()):
  Promise<{ok: true; live: Record<string, unknown>} | {ok: false; error: LiveProofError}> {
  const live = parseClientLive(raw);
  if (!live) return {ok: false, error: "bad_fields"};
  if (!uid) return {ok: false, error: "no_owner"};
  const video = await proveFile(uid, {url: live.video, path: live.videoPath, sha: live.videoSha}, deps);
  if (!video) return {ok: false, error: "unproven_file"};
  const check = inspectLiveVideo(video);
  if (!check.ok) return {ok: false, error: check.error};
  for (const frame of live.frames) {
    if (!await proveFile(uid, frame, deps)) return {ok: false, error: "unproven_file"};
  }
  const {durationMs, width, height, codec, bytes} = check.info;
  return {ok: true, live: {...live, durationMs, width, height, codec, bytes, loop: true, verified: true}};
}

/**
 * Replaces the client `live` map of a new live wall with the server facts, or marks it unverified. Review then needs
 * `live.verified == true` (firestore.rules). Runs from onWallSubmitted, so it adds no Cloud Function.
 */
export async function verifyLiveWall(snapshot: admin.firestore.DocumentSnapshot, uid: string | null,
  deps?: LiveProofDeps): Promise<void> {
  const data = snapshot.data();
  if (!isLiveWall(data)) return;
  const result = await proveLiveSubmission(uid, data?.live, deps);
  const client = parseClientLive(data?.live);
  const next = result.ok ? result.live : {...(client ?? {}), verified: false, error: result.error};
  if (!result.ok) logger.warn("onWallSubmitted: live wall failed its file check.", {wallId: snapshot.id, error: result.error});
  await db.runTransaction(async (tx) => {
    const current = await tx.get(snapshot.ref);
    if (!current.exists || !isDeepStrictEqual(current.data()?.live, data?.live)) return;
    tx.update(snapshot.ref, {live: next});
  });
}

/** Marks the R2 objects of a deleted approved live wall for the tombstone sweep. Photos use cleanupDeletedOwnedWall. */
export async function tombstoneLiveAssets(before: admin.firestore.DocumentData | undefined, nowMs = Date.now()):
  Promise<number> {
  if (!isLiveWall(before) || before?.review !== true || before.live?.verified !== true) return 0;
  const repo = process.env.GH_REPO_WALLS?.trim();
  const live = parseClientLive(Object.fromEntries(CLIENT_KEYS.map((key) => [key, before.live[key]])));
  if (!repo || !live) return 0;
  const files = [{path: live.videoPath, sha: live.videoSha}, ...live.frames];
  let marked = 0;
  for (const file of files) {
    const receipt = (await db.collection("githubUploads")
      .doc(uploadFileKey(repo, {path: file.path, sha: file.sha, sourceKind: "owned"})).get()).data();
    const asset = receipt?.retainedAsset;
    if (!stored(asset)) continue;
    const registry = db.collection("r2ObjectRegistry").doc(asset.objectId);
    marked += await db.runTransaction(async (tx) => {
      const row = (await tx.get(registry)).data();
      if (row?.status !== "active" || row.object !== asset.object || row.sha256 !== asset.sha256 || row.path !== file.path) {
        return 0;
      }
      tx.update(registry, {status: "tombstoned", cleanupNotBeforeMs: nowMs + 5 * 60_000,
        deletedAt: admin.firestore.FieldValue.serverTimestamp()});
      return 1;
    });
  }
  return marked;
}
