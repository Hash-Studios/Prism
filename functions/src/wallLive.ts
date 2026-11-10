import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {isDeepStrictEqual} from "node:util";
import {logger} from "firebase-functions/v2";
import {db, REGION} from "./common";
import {uploadFileKey, uploadPathKey} from "./completedWallUpload";
import {inspectLiveVideo, isLiveFramePath, isLiveVideoPath, LIVE_FRAME_COUNT, type LiveVideoError} from "./liveVideo";
import {ownedAssetStorageEnabled, ownedThumbnailUrl, PermanentOwnedAssetError, stored, verifyStoredUploadRegistry,
  type StoredUpload} from "./ownedAssetDelivery";
import {R2Storage, r2Env, r2Secrets} from "./r2Storage";
import {sameTimestamp} from "./wallEditingCommon";
import {verifiedUidForEmail} from "./authoredContentUid";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";

/** A file the client uploaded through githubPutFile and names on the wall. */
export type LiveFile = {url: string; path: string; sha: string};
/** The `live` map a client may write when it creates a live wall. */
export type ClientLive = {video: string; videoPath: string; videoSha: string; frames: LiveFile[]};

export type LiveProofError = LiveVideoError | "bad_fields" | "no_owner" | "unproven_file" | "unproven_poster";

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
  if (!base || !Array.isArray(frames) || frames.length !== LIVE_FRAME_COUNT) return [];
  const pattern = new RegExp(`^${base.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/previews/[a-f0-9]{64}\\.img$`);
  const urls = frames.map((frame) => (frame as {url?: unknown})?.url);
  return urls.every((url) => typeof url === "string" && pattern.test(url)) && new Set(urls).size === LIVE_FRAME_COUNT ?
    urls as string[] : [];
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

type FileProof = {file: LiveFile; asset: StoredUpload; preview: boolean};

async function readFileProof(tx: admin.firestore.Transaction, uid: string, file: LiveFile,
  preview = true): Promise<FileProof | null> {
  const repo = process.env.GH_REPO_WALLS?.trim();
  if (!repo) return null;
  const ref = {path: file.path, sha: file.sha, sourceKind: "owned" as const};
  const key = uploadFileKey(repo, ref);
  const [receipt, intentSnap, tombstone] = await Promise.all([tx.get(db.collection("githubUploads").doc(key)),
    tx.get(db.collection("githubUploadIntents").doc(uploadPathKey(repo, ref))),
    tx.get(db.collection("ownedUploadDeletions").doc(key))]);
  const record = receipt.data();
  const intent = intentSnap.data();
  const asset = record?.retainedAsset;
  if (!record || tombstone.exists || record.uid !== uid || record.repo !== repo || record.path !== file.path ||
    record.sha !== file.sha || record.sourceKind !== "owned" || !stored(asset) || asset.uid !== uid ||
    asset.repo !== repo || asset.path !== file.path || asset.sha !== file.sha || asset.sourceKind !== "owned" ||
    !intent || intent.status !== "complete" || intent.uid !== uid || intent.repo !== repo || intent.path !== file.path ||
    intent.sha !== file.sha || intent.blobSha !== file.sha || intent.sourceKind !== "owned" ||
    typeof record.generation !== "string" || !record.generation || intent.generation !== record.generation ||
    !isDeepStrictEqual(asset, intent.retainedAsset) || asset.uploadId !== intent.uploadId ||
    intent.response?.sourceKind !== "owned" || intent.response?.content?.path !== file.path ||
    intent.response?.content?.sha !== file.sha || intent.response?.content?.download_url !== file.url ||
    (preview ? !asset.previewObjectId || file.url !== ownedThumbnailUrl(asset) : !!asset.previewObjectId || file.url !== "")) return null;
  try {
    await verifyStoredUploadRegistry(asset, tx);
  } catch (error) {
    if (error instanceof PermanentOwnedAssetError) return null;
    throw error;
  }
  return {file, asset, preview};
}

async function fileBytes(proof: FileProof, deps: LiveProofDeps): Promise<Buffer | null> {
  if (proof.preview && !await deps.previewMatches(proof.asset)) return null;
  const bytes = await deps.readPrivate(proof.asset);
  return sha256(bytes) === proof.asset.sha256 && blobSha(bytes) === proof.file.sha ? bytes : null;
}

type ProofResult = {ok: true; live: Record<string, unknown>; files: FileProof[]} | {ok: false; error: LiveProofError};

/** Checks a live wall's files from storage. The video facts come from its MP4 headers, never from the client. */
export async function proveLiveSubmission(uid: string | null, raw: unknown, injected?: LiveProofDeps):
  Promise<{ok: true; live: Record<string, unknown>} | {ok: false; error: LiveProofError}> {
  const result = await proveLiveFiles(uid, raw, injected);
  return result.ok ? {ok: true, live: result.live} : result;
}

async function proveLiveFiles(uid: string | null, raw: unknown, injected?: LiveProofDeps): Promise<ProofResult> {
  const live = parseClientLive(raw);
  if (!live) return {ok: false, error: "bad_fields"};
  if (!uid) return {ok: false, error: "no_owner"};
  const deps = injected ?? defaultDeps();
  const files = [{url: live.video, path: live.videoPath, sha: live.videoSha}, ...live.frames];
  const proofs = await db.runTransaction(async (tx) => Promise.all(files.map((file) => readFileProof(tx, uid, file))));
  if (proofs.some((proof) => !proof)) return {ok: false, error: "unproven_file"};
  const proven = proofs as FileProof[];
  const video = await fileBytes(proven[0], deps);
  if (!video) return {ok: false, error: "unproven_file"};
  const check = inspectLiveVideo(video);
  if (!check.ok) return {ok: false, error: check.error};
  for (const proof of proven.slice(1)) {
    if (!await fileBytes(proof, deps)) return {ok: false, error: "unproven_file"};
  }
  const {durationMs, width, height, codec, bytes} = check.info;
  return {ok: true, live: {...live, durationMs, width, height, codec, bytes, loop: true, verified: true}, files: proven};
}

const posterKeys = ["wallpaper_url", "wallpaper_thumb", "wallpaper_path", "wallpaper_sha", "thumb_path", "thumb_sha",
  "wallpaper_source_kind", "thumb_source_kind", "originalProtected", "originalObjectId"];

const clientPart = (raw: unknown): unknown => raw && typeof raw === "object" && !Array.isArray(raw) ?
  Object.fromEntries(CLIENT_KEYS.map((key) => [key, (raw as Record<string, unknown>)[key]])) : raw;

function sameSubmission(current: admin.firestore.DocumentSnapshot, snapshot: admin.firestore.DocumentSnapshot): boolean {
  return current.exists && sameTimestamp(current.createTime, snapshot.createTime) && isLiveWall(current.data()) &&
    current.data()?.email === snapshot.data()?.email && isDeepStrictEqual(current.data()?.live, snapshot.data()?.live);
}

/** A protected live rejection can continue only while all original completed file identities remain active. */
export async function liveArchiveAssetsActive(tx: admin.firestore.Transaction, data: admin.firestore.DocumentData,
  uid: string): Promise<boolean> {
  const live = parseClientLive(clientPart(data.live));
  if (!live) return false;
  const files = [{url: live.video, path: live.videoPath, sha: live.videoSha}, ...live.frames];
  return (await Promise.all(files.map((file) => readFileProof(tx, uid, file)))).every(Boolean);
}

async function posterFiles(tx: admin.firestore.Transaction, snapshot: admin.firestore.DocumentSnapshot,
  uid: string): Promise<FileProof[] | null> {
  const data = snapshot.data()!;
  if (data.originalProtected === true) {
    const manifest = (await tx.get(db.collection("ownedAssets").doc(data.id))).data();
    if (!manifest || manifest.status !== "ready" || manifest.canonicalPath !== snapshot.ref.path ||
      manifest.incarnation !== snapshot.createTime?.toMillis() || manifest.incarnationNanos !== snapshot.createTime?.nanoseconds ||
      !stored(manifest.original) || !stored(manifest.thumb) || data.originalObjectId !== manifest.original.objectId ||
      data.wallpaper_url !== "" || data.wallpaper_thumb !== ownedThumbnailUrl(manifest.thumb) ||
      ["wallpaper_path", "wallpaper_sha", "thumb_path", "thumb_sha"].some((key) => data[key] !== "")) return null;
    const files = await Promise.all([readFileProof(tx, uid, {url: "", path: manifest.original.path,
      sha: manifest.original.sha}, false), readFileProof(tx, uid, {url: ownedThumbnailUrl(manifest.thumb),
      path: manifest.thumb.path, sha: manifest.thumb.sha})]);
    return files.every(Boolean) ? files as FileProof[] : null;
  }
  if (data.wallpaper_source_kind !== "owned" || data.thumb_source_kind !== "owned" ||
    typeof data.wallpaper_path !== "string" || !data.wallpaper_path || data.thumb_path !== `thumb_${data.wallpaper_path}` ||
    typeof data.wallpaper_sha !== "string" || typeof data.thumb_sha !== "string" ||
    isLiveVideoPath(data.wallpaper_path) || isLiveFramePath(data.wallpaper_path)) return null;
  const files = await Promise.all([readFileProof(tx, uid, {url: data.wallpaper_url, path: data.wallpaper_path,
    sha: data.wallpaper_sha}, false), readFileProof(tx, uid, {url: data.wallpaper_thumb, path: data.thumb_path, sha: data.thumb_sha})]);
  return files.every(Boolean) ? files as FileProof[] : null;
}

async function provePoster(snapshot: admin.firestore.DocumentSnapshot, uid: string, deps: LiveProofDeps): Promise<FileProof[] | null> {
  const files = await db.runTransaction((tx) => posterFiles(tx, snapshot, uid));
  if (!files) return null;
  const sharp = (await import("sharp")).default;
  for (const proof of files) {
    const bytes = await fileBytes(proof, deps);
    if (!bytes) return null;
    try {
      const image = await sharp(bytes, {limitInputPixels: 40_000_000}).metadata();
      if (!image.width || !image.height || !["jpeg", "png", "webp"].includes(image.format ?? "")) return null;
      await sharp(bytes, {limitInputPixels: 40_000_000}).resize({width: 1, height: 1, fit: "inside"}).raw().toBuffer();
    } catch {
      return null;
    }
  }
  return files;
}

/**
 * Replaces the client `live` map of a new live wall with the server facts, or marks it unverified. Review then needs
 * `live.verified == true` (firestore.rules). Runs from onWallSubmitted, so it adds no Cloud Function.
 */
export async function verifyLiveWall(snapshot: admin.firestore.DocumentSnapshot, uid: string | null,
  deps?: LiveProofDeps): Promise<void> {
  const data = snapshot.data();
  if (!isLiveWall(data)) return;
  // External failures propagate so the retryable create trigger can finish its original pending submission.
  let result = await proveLiveFiles(uid, clientPart(data?.live), deps);
  let poster: FileProof[] | null = null;
  // Undo recreates a server-enriched map. Discard all stored facts and prove its client references again.
  if (result.ok && uid) {
    poster = await provePoster(snapshot, uid, deps ?? defaultDeps());
    if (!poster) result = {ok: false, error: "unproven_poster"};
  }
  const client = parseClientLive(clientPart(data?.live));
  if (!result.ok) logger.warn("onWallSubmitted: live wall failed its file check.", {wallId: snapshot.id, error: result.error});
  await db.runTransaction(async (tx) => {
    const current = await tx.get(snapshot.ref);
    if (!sameSubmission(current, snapshot)) return;
    let error: LiveProofError | undefined = result.ok ? undefined : result.error;
    if (result.ok && uid) {
      const [user, barrier] = await Promise.all([tx.get(db.collection("usersv2").doc(uid)),
        tx.get(db.collection("creatorDeletionState").doc(uid))]);
      const retained = await Promise.all(result.files.map((proof) => readFileProof(tx, uid, proof.file, proof.preview)));
      const currentPoster = await posterFiles(tx, current, uid);
      if (!user.exists || user.data()?.deleted === true || barrier.data()?.closed === true ||
        current.data()?.creatorUid !== undefined && current.data()?.creatorUid !== uid) error = "no_owner";
      else if (!isDeepStrictEqual(retained, result.files)) error = "unproven_file";
      else if (!isDeepStrictEqual(currentPoster, poster)) error = "unproven_poster";
      else if (current.data()?.originalProtected !== true &&
        posterKeys.some((key) => !isDeepStrictEqual(current.data()?.[key], data?.[key]))) error = "unproven_poster";
    }
    tx.update(snapshot.ref, {live: error ? {...(client ?? {}), verified: false, error} : (result as {ok: true; live: unknown}).live,
      ...(error && current.data()?.review === true ? {review: false} : {})});
  });
}

/** All extant walls count, including pending walls and a recreated wall from a delayed delete event. */
export async function liveAssetReferenced(tx: admin.firestore.Transaction, asset: StoredUpload): Promise<boolean> {
  if (asset.sourceKind !== "owned" || !asset.previewObjectId) return false;
  if (isLiveVideoPath(asset.path)) {
    const queries = await Promise.all(["walls", "rejectedWalls"].map((collection) =>
      tx.get(db.collection(collection).where("live.videoPath", "==", asset.path))));
    for (const walls of queries) {
      for (const wall of walls.docs) {
        const data = wall.data();
        if (isLiveWall(data) && data.live?.videoSha === asset.sha && data.live?.video === ownedThumbnailUrl(asset) &&
          await ownsReference(tx, data, asset.uid)) return true;
      }
    }
    return false;
  }
  if (!isLiveFramePath(asset.path)) return false;
  const frame = {url: ownedThumbnailUrl(asset), path: asset.path, sha: asset.sha};
  const queries = await Promise.all(["walls", "rejectedWalls"].map((collection) =>
    tx.get(db.collection(collection).where("live.frames", "array-contains", frame))));
  for (const walls of queries) {
    for (const wall of walls.docs) {
      if (isLiveWall(wall.data()) && await ownsReference(tx, wall.data(), asset.uid)) return true;
    }
  }
  return false;
}

async function ownsReference(tx: admin.firestore.Transaction, wall: admin.firestore.DocumentData, uid: string): Promise<boolean> {
  // Verification already proved the owner, and approved walls may be anonymized after account deletion.
  if (wall.live?.verified === true) return true;
  if (wall.creatorUid !== undefined) return wall.creatorUid === uid;
  const email = typeof wall.email === "string" ? wall.email.trim() : "";
  return !!email && !email.includes("/") && await verifiedUidForEmail(email, tx) === uid;
}

async function rawPosterReferenced(tx: admin.firestore.Transaction, asset: StoredUpload): Promise<boolean> {
  const role = asset.previewObjectId ? "thumb" : "wallpaper";
  const queries = await Promise.all(["walls", "rejectedWalls"].map((collection) =>
    tx.get(db.collection(collection).where(`${role}_path`, "==", asset.path))));
  for (const rows of queries) {
    for (const row of rows.docs) {
      if (row.data()[`${role}_sha`] === asset.sha && await ownsReference(tx, row.data(), asset.uid)) return true;
    }
  }
  const manifests = await Promise.all(["original", "thumb"].map((role) =>
    tx.get(db.collection("ownedAssets").where(`${role}.objectId`, "==", asset.objectId))));
  return manifests.some((rows) => rows.docs.some((row) => row.data().status === "ready"));
}

/** A live wall rejected before binding still carries its raw owned poster receipts, not an ownedAssets manifest. */
async function tombstoneRawLivePosters(before: admin.firestore.DocumentData, ownerUid: string | null,
  nowMs: number): Promise<number> {
  if (before.originalProtected === true || before.wallpaper_source_kind !== "owned" || before.thumb_source_kind !== "owned" ||
    typeof before.wallpaper_path !== "string" || !before.wallpaper_path || before.thumb_path !== `thumb_${before.wallpaper_path}` ||
    isLiveVideoPath(before.wallpaper_path) || isLiveFramePath(before.wallpaper_path)) return 0;
  const repo = process.env.GH_REPO_WALLS?.trim();
  if (!repo) return 0;
  let marked = 0;
  for (const role of ["wallpaper", "thumb"]) {
    const path = before[`${role}_path`];
    const sha = before[`${role}_sha`];
    if (typeof sha !== "string" || !/^[a-f0-9]{40}$/.test(sha)) continue;
    marked += await db.runTransaction(async (tx) => {
      const receipt = (await tx.get(db.collection("githubUploads").doc(uploadFileKey(repo, {path, sha, sourceKind: "owned"})))).data();
      const candidates = receipt ? [receipt.retainedAsset] : (await tx.get(db.collection("r2ObjectRegistry")
        .where("path", "==", path))).docs.map((row) => row.data());
      const assets = candidates.filter((asset): asset is StoredUpload => stored(asset) && asset.sourceKind === "owned" &&
        asset.repo === repo && asset.path === path && asset.sha === sha && (!ownerUid || asset.uid === ownerUid) &&
        (!receipt || receipt.uid === asset.uid) && (role === "thumb" ? !!asset.previewObjectId &&
          before.wallpaper_thumb === ownedThumbnailUrl(asset) : !asset.previewObjectId && before.wallpaper_url === ""));
      if (assets.length !== 1) return 0;
      const asset = assets[0];
      try {
        await verifyStoredUploadRegistry(asset, tx);
      } catch (error) {
        if (error instanceof PermanentOwnedAssetError) return 0;
        throw error;
      }
      if (await rawPosterReferenced(tx, asset)) return 0;
      tx.update(db.collection("r2ObjectRegistry").doc(asset.objectId), {status: "tombstoned",
        cleanupNotBeforeMs: nowMs + 5 * 60_000, deletedAt: admin.firestore.FieldValue.serverTimestamp()});
      return 1;
    });
  }
  return marked;
}

/** Marks unreferenced files of a deleted live submission. Rejected archives retain their files for undo. */
export async function tombstoneLiveAssets(before: admin.firestore.DocumentData | undefined, nowMs = Date.now()):
  Promise<number> {
  if (!isLiveWall(before) || !before) return 0;
  let ownerUid: string | null = null;
  if (before.live?.verified !== true) {
    const email = typeof before.email === "string" ? before.email.trim() : "";
    ownerUid = typeof before.creatorUid === "string" && before.creatorUid ? before.creatorUid :
      email && !email.includes("/") ? await verifiedUidForEmail(email) : null;
    if (!ownerUid) return 0;
  }
  const repo = process.env.GH_REPO_WALLS?.trim();
  const live = parseClientLive(clientPart(before.live));
  if (!repo || !live) return 0;
  const files = [{path: live.videoPath, sha: live.videoSha, url: live.video}, ...live.frames];
  let marked = 0;
  for (const file of files) {
    marked += await db.runTransaction(async (tx) => {
      const receipt = (await tx.get(db.collection("githubUploads")
        .doc(uploadFileKey(repo, {path: file.path, sha: file.sha, sourceKind: "owned"})))).data();
      // Account deletion removes upload receipts but keeps approved walls. The registry still proves the exact URL.
      const candidates = receipt ? [receipt.retainedAsset] : (await tx.get(db.collection("r2ObjectRegistry")
        .where("path", "==", file.path))).docs.map((row) => row.data());
      const matching = candidates.filter((asset): asset is StoredUpload => stored(asset) &&
        (!receipt || receipt.uid === asset.uid) && (!ownerUid || asset.uid === ownerUid) &&
        asset.repo === repo && asset.path === file.path && asset.sha === file.sha &&
        asset.sourceKind === "owned" && !!asset.previewObjectId && ownedThumbnailUrl(asset) === file.url);
      if (matching.length !== 1) return 0;
      const asset = matching[0];
      try {
        await verifyStoredUploadRegistry(asset, tx);
      } catch (error) {
        if (error instanceof PermanentOwnedAssetError) return 0;
        throw error;
      }
      if (await liveAssetReferenced(tx, asset)) return 0;
      const registry = db.collection("r2ObjectRegistry").doc(asset.objectId);
      const row = (await tx.get(registry)).data();
      if (row?.status !== "active" || row.object !== asset.object || row.sha256 !== asset.sha256 || row.path !== file.path) {
        return 0;
      }
      tx.update(registry, {status: "tombstoned", cleanupNotBeforeMs: nowMs + 5 * 60_000,
        deletedAt: admin.firestore.FieldValue.serverTimestamp()});
      return 1;
    });
  }
  return marked + await tombstoneRawLivePosters(before, ownerUid, nowMs);
}

/** Rejections retain their files for undo, until the creator explicitly removes that history or deletes the account. */
export const onRejectedLiveWallDeleted = onDocumentDeleted({document: "rejectedWalls/{wallId}", region: REGION,
  retry: true, secrets: r2Secrets, concurrency: 1, timeoutSeconds: 120, cpu: "gcf_gen1"}, async (event) => {
  const data = event.data?.data();
  if (!isLiveWall(data) || !data) return;
  await tombstoneLiveAssets(data);
  if (typeof data.id !== "string" || !/^[A-Za-z0-9_-]{1,200}$/.test(data.id) ||
    !(data.sourceWallCreateTime instanceof admin.firestore.Timestamp)) return;
  await (await import("./ownedAssetDelivery.js")).cleanupDeletedOwnedWall({wallId: data.id,
    canonicalPath: `walls/${event.params.wallId}`, incarnation: data.sourceWallCreateTime.toMillis(),
    incarnationNanos: data.sourceWallCreateTime.nanoseconds});
});

/** Account closure also owns uploads that never reached a wall document. Retained walls and archives keep theirs. */
export async function tombstoneUnreferencedLiveUploads(uid: string, nowMs = Date.now()): Promise<number> {
  if (!ownedAssetStorageEnabled()) return 0;
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  let marked = 0;
  for (;;) {
    let query = db.collection("r2ObjectRegistry").where("uid", "==", uid)
      .orderBy(admin.firestore.FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const rows = await query.get();
    for (const row of rows.docs) {
      const asset = row.data();
      if (!stored(asset) || asset.sourceKind !== "owned" ||
        !(isLiveVideoPath(asset.path) || isLiveFramePath(asset.path))) continue;
      marked += await db.runTransaction(async (tx) => {
        const current = (await tx.get(row.ref)).data();
        if (!current || current.status !== "active" || current.uid !== uid || !stored(current) ||
          current.objectId !== asset.objectId) return 0;
        try {
          await verifyStoredUploadRegistry(current, tx);
        } catch (error) {
          if (error instanceof PermanentOwnedAssetError) return 0;
          throw error;
        }
        if (await liveAssetReferenced(tx, current)) return 0;
        tx.update(row.ref, {status: "tombstoned", cleanupNotBeforeMs: nowMs + 5 * 60_000,
          deletedAt: admin.firestore.FieldValue.serverTimestamp()});
        return 1;
      });
    }
    if (rows.size < 100) return marked;
    cursor = rows.docs[rows.docs.length - 1];
  }
}
