import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION} from "./common";
import {R2Storage, r2ObjectId, r2Secrets} from "./r2Storage";
import {STUDIO_ACCOUNT} from "./studio/account";
import {STUDIO_ASSET_BASE, verifiedStudioSource} from "./studio/assetSource";

const hash = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");
const validId = (value: unknown): value is string => typeof value === "string" &&
  /^[A-Za-z0-9_-]{1,200}$/.test(value);
export const ownedAssetStorageEnabled = (): boolean => ["R2_ACCOUNT_ID", "R2_PRIVATE_BUCKET", "R2_PREVIEW_BUCKET",
  "R2_PREVIEW_BASE_URL"].some((key) => !!process.env[key]);
export class PermanentOwnedAssetError extends Error {}
class R2IntegrityError extends PermanentOwnedAssetError {}
/** Storage "repo" of Prism Studio walls: their source is the worker bucket, not a GitHub repository. */
export const STUDIO_STORAGE_REPO = "prism-studio";
export type UploadIdentity = {repo: string; path: string; sha: string; uid?: string; sourceKind?: "owned" | "studio";
  uploadId?: string};
const objectPrefix = (kind?: "owned" | "studio") => kind === "owned" ? "private-originals" :
  kind === "studio" ? "studio-originals" : "retained";
export type StoredUpload = UploadIdentity & {
  bucket: string; object: string; objectId: string; sha256: string; uid: string; previewObjectId?: string; uploadId?: string;
};
function objectName(input: UploadIdentity & {uid: string; digest?: string}): string {
  const repos = input.sourceKind === "studio" ? [STUDIO_STORAGE_REPO] : [process.env.GH_REPO_WALLS, process.env.GH_REPO_SETUPS];
  if (!input.repo || !repos.includes(input.repo) || !/^[a-f0-9]{40}$/.test(input.sha) ||
    !input.path || input.path.length > 1024 || input.path.startsWith("/") || input.path.includes("\\") ||
    input.path.split("/").some((part) => !part || part === "." || part === "..")) throw new Error("Invalid upload identity");
  if (!validId(input.uid)) throw new Error("Invalid upload identity");
  const digest = input.digest ?? "";
  const objectId = r2ObjectId(input, digest);
  return `${objectPrefix(input.sourceKind)}/${objectId}`;
}
export async function retainUpload(input: UploadIdentity & {uid: string; bytes: Buffer}): Promise<StoredUpload> {
  if (!validId(input.uid) || !input.bytes.length) throw new Error("Invalid retained upload");
  const blobSha = createHash("sha1").update(`blob ${input.bytes.length}\0`).update(input.bytes).digest("hex");
  if (blobSha !== input.sha) throw new Error("Upload bytes do not match Git blob SHA");
  const client = new R2Storage();
  const digest = hash(input.bytes);
  const objectId = r2ObjectId(input, digest);
  const object = objectName({...input, digest});
  const bucket = process.env.R2_PRIVATE_BUCKET;
  if (!bucket) throw new Error("R2 private bucket is not configured");
  const registry = db.collection("r2ObjectRegistry").doc(objectId);
  const registryData = await db.runTransaction(async (tx) => {
    const current = await tx.get(registry);
    if (current.exists && current.data()?.status === "tombstoned") throw new PermanentOwnedAssetError("Retained object was deleted");
    if (current.exists && (current.data()?.object !== object || current.data()?.uid !== input.uid ||
      current.data()?.sha256 !== digest)) throw new PermanentOwnedAssetError("Retained object identity conflict");
    if (!current.exists) {
      tx.create(registry, {status: "writing", bucket, object, objectId, sha256: digest, uid: input.uid,
        repo: input.repo, path: input.path, sha: input.sha, sourceKind: input.sourceKind ?? "github", uploadId: input.uploadId ?? "imported",
        ...(previewId(input) ? {previewObjectId: objectId} : {})});
    }
    return current.data();
  });
  if (registryData?.status === "tombstoned") throw new PermanentOwnedAssetError("Retained object was deleted");
  const type = contentType(input.bytes);
  await client.put("private", object, input.bytes, {sha256: digest, uid: input.uid, objectid: objectId,
    repo64: Buffer.from(input.repo).toString("base64url"), path64: Buffer.from(input.path).toString("base64url"),
    gitsha: input.sha, uploadid: input.uploadId ?? "imported"}, type);
  const privateHead = await client.head("private", object);
  if (!privateHead || privateHead.objectId !== objectId || privateHead.sha256 !== digest || privateHead.uid !== input.uid ||
    privateHead.repo !== input.repo || privateHead.path !== input.path || privateHead.gitSha !== input.sha ||
    privateHead.size !== input.bytes.length || privateHead.uploadId !== (input.uploadId ?? "imported") ||
    hash(await client.get("private", object)) !== digest) {
    throw new PermanentOwnedAssetError("Retained upload mismatch");
  }
  let previewObjectId: string | undefined;
  if (previewId(input)) {
    previewObjectId = objectId;
    await client.put("preview", `previews/${objectId}.img`, input.bytes,
      {sha256: digest, objectid: objectId}, type);
    const preview = await client.head("preview", `previews/${objectId}.img`);
    if (!preview || preview.sha256 !== digest || preview.objectId !== objectId || preview.size !== input.bytes.length ||
      hash(await client.get("preview", `previews/${objectId}.img`)) !== digest) throw new PermanentOwnedAssetError("Retained preview mismatch");
  }
  const active = await db.runTransaction(async (tx) => {
    const current = await tx.get(registry);
    const data = current.data();
    if (!data || data.status === "tombstoned" || data.object !== object || data.sha256 !== digest) return false;
    if (data.status === "writing") tx.update(registry, {status: "active"});
    return true;
  });
  if (!active) {
    await client.delete("private", object);
    if (previewObjectId) await client.delete("preview", `previews/${previewObjectId}.img`);
    throw new PermanentOwnedAssetError("Retained object was deleted during upload");
  }
  return {repo: input.repo, path: input.path, sha: input.sha, uid: input.uid,
    ...(input.sourceKind ? {sourceKind: input.sourceKind} : {}),
    bucket, object, objectId, sha256: digest, ...(input.uploadId ? {uploadId: input.uploadId} : {}),
    ...(previewObjectId ? {previewObjectId} : {})};
}
export async function verifyStoredUploadRegistry(asset: StoredUpload, tx?: FirebaseFirestore.Transaction): Promise<void> {
  if (!stored(asset)) throw new R2IntegrityError("Retained upload identity is invalid");
  const registryRef = db.collection("r2ObjectRegistry").doc(asset.objectId);
  const registry = (tx ? (await tx.get(registryRef)).data() : (await registryRef.get()).data());
  if (!registry || registry.status !== "active" || registry.bucket !== asset.bucket || registry.object !== asset.object ||
    registry.objectId !== asset.objectId || registry.sha256 !== asset.sha256 ||
    registry.uid !== asset.uid || registry.repo !== asset.repo || registry.path !== asset.path || registry.sha !== asset.sha ||
    registry.sourceKind !== (asset.sourceKind ?? "github") || registry.uploadId !== (asset.uploadId ?? "imported") ||
    registry.previewObjectId !== asset.previewObjectId) throw new R2IntegrityError("Retained upload registry mismatch");
}
export async function verifyStoredUpload(asset: StoredUpload, expectedSize?: number, verifyBytes = false,
  tx?: FirebaseFirestore.Transaction): Promise<void> {
  await verifyStoredUploadRegistry(asset, tx);
  const metadata = await new R2Storage().head("private", asset.object);
  if (!metadata || metadata.objectId !== asset.objectId || metadata.sha256 !== asset.sha256 || metadata.uid !== asset.uid ||
    metadata.repo !== asset.repo || metadata.path !== asset.path || metadata.gitSha !== asset.sha ||
    metadata.uploadId !== (asset.uploadId ?? "imported") ||
    expectedSize !== undefined && metadata.size !== expectedSize) throw new R2IntegrityError("Retained upload mismatch");
  if (verifyBytes && hash(await new R2Storage().get("private", asset.object)) !== asset.sha256) {
    throw new R2IntegrityError("Retained upload content mismatch");
  }
}
export async function deleteRetainedUpload(input: UploadIdentity & {expected?: StoredUpload;
  authorize?: (tx: FirebaseFirestore.Transaction) => Promise<void>}): Promise<void> {
  if (!input.expected) throw new Error("Expected retained upload identity is required");
  const expected = input.expected;
  if (!stored(expected)) throw new Error("Expected retained upload identity is invalid");
  if (expected.repo !== input.repo || expected.path !== input.path || expected.sha !== input.sha ||
    (expected.sourceKind === "owned") !== (input.sourceKind === "owned")) throw new Error("Retained upload identity mismatch");
  const registry = db.collection("r2ObjectRegistry").doc(expected.objectId);
  const authorized = await db.runTransaction(async (tx) => {
    await input.authorize?.(tx);
    const current = await tx.get(registry);
    const data = current.data();
    if (!data || data.object !== expected.object || data.sha256 !== expected.sha256 || data.uid !== expected.uid ||
    data.bucket !== expected.bucket || data.objectId !== expected.objectId || data.repo !== expected.repo ||
    data.path !== expected.path || data.sha !== expected.sha || data.sourceKind !== (expected.sourceKind ?? "github") ||
    data.uploadId !== (expected.uploadId ?? "imported") || data.previewObjectId !== expected.previewObjectId) return false;
    if (data.status !== "tombstoned") {
      tx.update(registry, {status: "tombstoned",
        cleanupNotBeforeMs: Date.now() + 5 * 60_000, deletedAt: admin.firestore.FieldValue.serverTimestamp()});
    }
    return true;
  });
  if (!authorized) throw new Error("Retained upload registry mismatch");
  // Tombstone first: binders read this registry in their transaction, so their writes conflict with deletion.
  for (const field of ["original.object", "thumb.object"]) {
    const manifests = await db.collection("ownedAssets").where(field, "==", expected.object).get();
    for (const manifest of manifests.docs) {
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(manifest.ref)).data();
        const asset = field === "original.object" ? current?.original : current?.thumb;
        if (current?.status === "ready" && asset?.objectId === expected.objectId) tx.update(manifest.ref, {status: "deleted"});
      });
    }
  }
  const client = new R2Storage();
  await client.delete("private", expected.object);
  if (expected.previewObjectId) await client.delete("preview", `previews/${expected.previewObjectId}.img`);
}
function previewId(input: UploadIdentity) {
  return (input.sourceKind === "studio" ? input.repo === STUDIO_STORAGE_REPO : input.repo === process.env.GH_REPO_WALLS) &&
    input.path.split("/").pop()?.startsWith("thumb_");
}
export function stored(value: unknown): value is StoredUpload {
  if (!value || typeof value !== "object") return false;
  const asset = value as Partial<StoredUpload>;
  const kind = asset.sourceKind === "owned" || asset.sourceKind === "studio" ? asset.sourceKind : undefined;
  const prefix = objectPrefix(kind);
  let expectedObject: string;
  try {
    expectedObject = objectName({repo: asset.repo as string, path: asset.path as string, sha: asset.sha as string,
      uid: asset.uid as string, ...(kind ? {sourceKind: kind} : {}),
      ...(asset.uploadId ? {uploadId: asset.uploadId} : {}), digest: asset.sha256 as string});
  } catch {
    return false;
  }
  return "bucket" in value && value.bucket === process.env.R2_PRIVATE_BUCKET &&
    "object" in value && typeof value.object === "string" &&
    ((kind !== undefined && asset.sourceKind === kind && new RegExp(`^${prefix}/[a-f0-9]{64}$`).test(value.object)) ||
      (!("sourceKind" in value) && /^retained\/[a-f0-9]{64}$/.test(value.object))) &&
    "objectId" in value && typeof value.objectId === "string" && /^[a-f0-9]{64}$/.test(value.objectId) &&
    "sha256" in value && typeof value.sha256 === "string" && /^[a-f0-9]{64}$/.test(value.sha256) &&
    "uid" in value && validId(value.uid) && "repo" in value && typeof value.repo === "string" &&
    "path" in value && typeof value.path === "string" && "sha" in value && typeof value.sha === "string" &&
    value.objectId === r2ObjectId({uid: value.uid as string, repo: value.repo as string, path: value.path as string,
      sha: value.sha as string, ...(kind ? {sourceKind: kind} : {}),
      ...(asset.uploadId ? {uploadId: asset.uploadId} : {})}, value.sha256 as string) &&
    value.object === `${prefix}/${value.objectId}` && value.object === expectedObject &&
    (!asset.uploadId || (typeof asset.uploadId === "string" && /^[A-Za-z0-9_-]{1,80}$/.test(asset.uploadId))) &&
    (!("previewObjectId" in value) || (value.previewObjectId === value.objectId && typeof asset.path === "string" &&
      previewId({repo: asset.repo as string, path: asset.path, sha: asset.sha as string, ...(kind ? {sourceKind: kind} : {})}) === true));
}
function contentType(bytes: Buffer): string {
  return bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ? "image/png" :
    bytes.subarray(8, 12).toString() === "WEBP" ? "image/webp" : /^GIF8[79]a$/.test(bytes.subarray(0, 6).toString()) ?
      "image/gif" : "image/jpeg";
}
export function ownedThumbnailUrl(asset: StoredUpload): string {
  if (!stored(asset) || !asset.previewObjectId) throw new Error("Owned preview is not available");
  const base = process.env.R2_PREVIEW_BASE_URL;
  if (!base) throw new Error("Owned thumbnail endpoint is not configured");
  const parsed = new URL(base);
  if (parsed.protocol !== "https:" || parsed.username || parsed.password || parsed.port || parsed.search || parsed.hash) {
    throw new Error("Invalid owned thumbnail endpoint");
  }
  return `${parsed.href.replace(/\/$/, "")}/previews/${asset.previewObjectId}.img`;
}
async function proveAsset(data: admin.firestore.DocumentData, prefix: "wallpaper" | "thumb",
  tx: admin.firestore.Transaction): Promise<{upload: StoredUpload; url: string; kind: "owned" | "github"} | null> {
  const repo = process.env.GH_REPO_WALLS;
  const owner = process.env.GH_USERNAME;
  const path = data[`${prefix}_path`];
  const sha = data[`${prefix}_sha`];
  if (!repo || !owner || typeof path !== "string" || typeof sha !== "string") return null;
  try {
    if (![process.env.GH_REPO_WALLS, process.env.GH_REPO_SETUPS].includes(repo) || !/^[a-f0-9]{40}$/.test(sha) ||
      path.length > 1024 || path.startsWith("/") || path.includes("\\") ||
      path.split("/").some((part) => !part || part === "." || part === "..")) return null;
  } catch {
    return null;
  }
  const raw = data[prefix === "thumb" ? "wallpaper_thumb" : "wallpaper_url"];
  if (typeof raw !== "string") return null;
  const privateOriginal = raw === "" && prefix === "wallpaper";
  const previewBase = process.env.R2_PREVIEW_BASE_URL?.replace(/\/$/, "");
  const privateThumb = prefix === "thumb" && !!previewBase && raw.startsWith(`${previewBase}/previews/`);
  const privateAsset = privateOriginal || privateThumb;
  const keyPrefix = privateAsset ? "owned_" : "";
  try {
    if (privateThumb) {
      const url = new URL(raw);
      const endpoint = new URL(previewBase!);
      const prefix = `${endpoint.pathname.replace(/\/$/, "")}/previews/`;
      const objectId = url.pathname.startsWith(prefix) ? url.pathname.slice(prefix.length).replace(/\.img$/, "") : "";
      if (url.protocol !== "https:" || url.hostname !== endpoint.hostname || url.port || url.search || url.hash ||
        url.username || url.password || !/^[a-f0-9]{64}$/.test(objectId) ||
        url.href !== `${endpoint.href.replace(/\/$/, "")}/previews/${objectId}.img`) {
        return null;
      }
    } else if (raw !== "" || prefix !== "wallpaper") {
      const url = new URL(raw);
      const parts = url.pathname.split("/").slice(1).map(decodeURIComponent);
      if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.search || url.hash ||
      url.username || url.password || url.port || parts[0].toLowerCase() !== owner.toLowerCase() ||
      parts[1] !== repo || parts.length <= path.split("/").length + 2 ||
      parts.slice(-path.split("/").length).join("/") !== path) return null;
    }
  } catch {
    return null;
  }
  let query = db.collection("githubUploads").where("path", "==", path).orderBy(admin.firestore.FieldPath.documentId()).limit(8);
  const records: admin.firestore.QueryDocumentSnapshot[] = [];
  while (true) {
    const rows = await tx.get(query);
    records.push(...rows.docs.filter((doc) => doc.data().repo === repo &&
      (privateAsset ? doc.data().sourceKind === "owned" : doc.data().sourceKind !== "owned")));
    if (records.length >= 8) return null;
    if (rows.size < 8) break;
    query = query.startAfter(rows.docs[rows.docs.length - 1]);
  }
  const receipt = records.find((doc) => doc.id === `${keyPrefix}file_${hash(`${repo}\0${path}\0${sha}`)}`)?.data();
  const intent = (await tx.get(db.collection("githubUploadIntents").doc(`${keyPrefix}path_${hash(`${repo}\0${path}`)}`))).data();
  if (!receipt || !validId(receipt.uid) || records.some((doc) => doc.data().uid !== receipt.uid) ||
    receipt.sha !== sha || intent?.status !== "complete" || intent.uid !== receipt.uid || intent.repo !== repo ||
    intent.path !== path || intent.blobSha !== sha || intent.response?.content?.path !== path ||
    intent.response?.content?.sha !== sha || intent.response?.content?.download_url !== raw) return null;
  const retained = receipt.retainedAsset;
  const intentAsset = intent.retainedAsset;
  if (privateAsset && (receipt.sourceKind !== "owned" || intent.sourceKind !== "owned" ||
    !stored(intentAsset) || !stored(retained) ||
    (["repo", "path", "sha", "uid", "bucket", "object", "objectId", "sha256", "sourceKind"] as const)
      .some((field) => intentAsset[field] !== retained[field]))) return null;
  if (!privateAsset && (receipt.sourceKind === "owned" || intent.sourceKind === "owned")) return null;
  if (!stored(retained) || retained.uid !== receipt.uid || retained.repo !== repo || retained.path !== path || retained.sha !== sha ||
    (retained.sourceKind === "owned") !== privateAsset ||
    retained.object !== objectName({...retained, digest: retained.sha256})) return null;
  if (privateThumb && raw !== ownedThumbnailUrl(retained)) return null;
  try {
    await verifyStoredUpload(retained, undefined, false, tx);
  } catch (error) {
    if (error instanceof R2IntegrityError) return null;
    throw error;
  }
  return {upload: retained, url: raw, kind: privateAsset ? "owned" : "github"};
}

export type WallBindingExpectation = {canonicalPath: string; incarnation: number; incarnationNanos: number;
  originalUrl: string; thumbUrl: string; originalPath: string; thumbPath: string; originalSha: string; thumbSha: string;
  recordedSource?: {originalPath: unknown; thumbPath: unknown; originalSha: unknown; thumbSha: unknown};
  studio?: {runId: string; candidateId: string; resolution: string}};

function matchesExpectedWall(wall: FirebaseFirestore.QueryDocumentSnapshot, expected: WallBindingExpectation): boolean {
  const data = wall.data();
  return wall.ref.path === expected.canonicalPath && wall.createTime.toMillis() === expected.incarnation &&
    wall.createTime.nanoseconds === expected.incarnationNanos && data.review === true &&
    data.wallpaper_url === expected.originalUrl && data.wallpaper_thumb === expected.thumbUrl &&
    [[data.wallpaper_path, expected.originalPath], [data.thumb_path, expected.thumbPath],
      [data.wallpaper_sha, expected.originalSha], [data.thumb_sha, expected.thumbSha]]
      .every(([actual, value]) => actual === undefined || actual === "" || actual === value) &&
    (!expected.recordedSource || data.wallpaper_path === expected.recordedSource.originalPath &&
      data.thumb_path === expected.recordedSource.thumbPath && data.wallpaper_sha === expected.recordedSource.originalSha &&
      data.thumb_sha === expected.recordedSource.thumbSha) &&
    (!expected.studio || data.origin === "studio" && data.email === STUDIO_ACCOUNT.email &&
      data.studioRunId === expected.studio.runId && data.studioCandidateId === expected.studio.candidateId &&
      data.resolution === expected.studio.resolution);
}

export async function dropAllowsBinding(data: FirebaseFirestore.DocumentData, tx?: FirebaseFirestore.Transaction,
  firestore: FirebaseFirestore.Firestore = db): Promise<boolean> {
  if (data.dropReserved === true) return false;
  if (!data.dropWeek) return true;
  if (typeof data.dropWeek !== "string" || !/^[A-Za-z0-9_-]{1,200}$/.test(data.dropWeek)) return false;
  const ref = firestore.collection("drops").doc(data.dropWeek);
  return (tx ? await tx.get(ref) : await ref.get()).data()?.released === true;
}

function releasedDropMarkers(data: FirebaseFirestore.DocumentData): FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData> {
  return Object.fromEntries(["dropWeek", "dropReserved"].filter((key) => data[key] !== undefined)
    .map((key) => [key, admin.firestore.FieldValue.delete()]));
}

export async function bindOwnedWall(wallId: string, expected?: WallBindingExpectation): Promise<void> {
  if (!validId(wallId) || !ownedAssetStorageEnabled()) return;
  await db.runTransaction(async (tx) => {
    const rows = await tx.get(db.collection("walls").where("id", "==", wallId).limit(2));
    if (rows.size !== 1) return;
    const wall = rows.docs[0];
    const data = wall.data();
    const ref = db.collection("ownedAssets").doc(wallId);
    const existing = (await tx.get(ref)).data();
    if (!wall.createTime || existing?.status === "deleted") return;
    if ((expected && !matchesExpectedWall(wall, expected)) || !await dropAllowsBinding(data, tx)) return;
    const incarnation = wall.createTime.toMillis();
    if (existing?.status === "ready") return;
    const proofData = expected ? {...data, wallpaper_path: expected.originalPath, thumb_path: expected.thumbPath,
      wallpaper_sha: expected.originalSha, thumb_sha: expected.thumbSha} : data;
    const original = await proveAsset(proofData, "wallpaper", tx);
    const thumb = await proveAsset(proofData, "thumb", tx);
    if (!original || !thumb || original.upload.uid !== thumb.upload.uid || original.kind !== thumb.kind) return;
    if (original.upload.previewObjectId || original.upload.path.split("/").pop()?.startsWith("thumb_") ||
      original.upload.path === thumb.upload.path || original.upload.object === thumb.upload.object || !thumb.upload.previewObjectId ||
      !thumb.upload.path.split("/").pop()?.startsWith("thumb_")) return;
    let author: admin.auth.UserRecord;
    try {
      author = await admin.auth().getUser(original.upload.uid);
    } catch (error) {
      if (typeof error === "object" && error !== null && "code" in error && error.code === "auth/user-not-found") return;
      throw error;
    }
    if (author.disabled || !author.email || author.email !== data.email) return;
    const thumbUrl = ownedThumbnailUrl(thumb.upload);
    tx.set(ref, {status: "ready", canonicalPath: wall.ref.path, incarnation,
      incarnationNanos: wall.createTime.nanoseconds, original: original.upload,
      thumb: thumb.upload, originalUrl: original.url, thumbUrl: thumb.url,
      provenance: {kind: original.kind, uid: original.upload.uid}});
    tx.update(wall.ref, {wallpaper_url: "", wallpaper_thumb: thumbUrl, originalProtected: true,
      wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: "",
      originalObjectId: original.upload.objectId, ...releasedDropMarkers(data)});
  });
}
async function delivery(wallId: string) {
  if (!validId(wallId)) throw new Error("Invalid wall identity");
  const rows = await db.collection("walls").where("id", "==", wallId).limit(2).get();
  const manifest = (await db.collection("ownedAssets").doc(wallId).get()).data();
  const wall = rows.docs[0];
  if (rows.size !== 1 || !wall?.createTime || manifest?.status !== "ready" ||
    manifest.canonicalPath !== wall.ref.path || manifest.incarnation !== wall.createTime.toMillis() ||
    manifest.incarnationNanos !== wall.createTime.nanoseconds ||
    !stored(manifest.original) || !stored(manifest.thumb) || wall.data().originalProtected !== true ||
    wall.data().originalObjectId !== manifest.original.objectId || wall.data().wallpaper_url !== "" ||
    wall.data().wallpaper_path !== "" || wall.data().wallpaper_sha !== "" ||
    wall.data().thumb_path !== "" || wall.data().thumb_sha !== "" ||
    wall.data().wallpaper_thumb !== ownedThumbnailUrl(manifest.thumb)) throw new Error("Owned wall unavailable");
  return {original: manifest.original, thumb: manifest.thumb, originalUrl: manifest.originalUrl,
    thumbUrl: manifest.thumbUrl, provenance: manifest.provenance};
}
export const getOwnedWallDelivery = delivery;
export type StudioBinding = {kind: "studio"; runId: string; candidateId: string};
/**
 * Binds a reviewed wall whose source has no upload receipts: a legacy GitHub wall, or a Prism Studio wall when `source`
 * is set. Studio is checked against the server-owned candidate backlink and never gets a GitHub receipt or creator credit.
 */
export async function bindLegacyOwnedWall(input: {wallId: string; canonicalPath: string; incarnation: number;
  incarnationNanos: number;
  originalUrl: string; thumbUrl: string; original: StoredUpload; thumb: StoredUpload; source?: StudioBinding;
  expected?: WallBindingExpectation}): Promise<void> {
  const {source, expected, ...binding} = input;
  const kind = source ? "studio" : undefined;
  if (!validId(input.wallId) || !stored(input.original) || !stored(input.thumb) ||
    input.original.sourceKind !== kind || input.thumb.sourceKind !== kind) throw new Error("Invalid legacy binding");
  if (source) {
    const keys = [`ai/studio/${source.candidateId}.jpg`, `ai/studio/thumb_${source.candidateId}.jpg`];
    const urls = [input.originalUrl, input.thumbUrl];
    [input.original, input.thumb].forEach((asset, index) => {
      if (asset.repo !== STUDIO_STORAGE_REPO || asset.path !== keys[index] || asset.uid !== STUDIO_ACCOUNT.id ||
        asset.uploadId !== source.candidateId || urls[index] !== `${STUDIO_ASSET_BASE}/${keys[index]}`) {
        throw new Error("Invalid Studio origin");
      }
    });
    await Promise.all([verifyStoredUpload(input.original), verifyStoredUpload(input.thumb)]);
  } else {
    for (const [asset, raw] of [[input.original, input.originalUrl], [input.thumb, input.thumbUrl]] as const) {
      const url = new URL(raw);
      const parts = url.pathname.split("/").slice(1).map(decodeURIComponent);
      if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.username || url.password ||
        url.search || url.hash || url.port || parts[0].toLowerCase() !== process.env.GH_USERNAME?.toLowerCase() ||
        parts[1] !== process.env.GH_REPO_WALLS || parts.slice(-asset.path.split("/").length).join("/") !== asset.path ||
        asset.object !== objectName({...asset, digest: asset.sha256})) throw new Error("Invalid legacy origin");
      await verifyStoredUpload(asset);
    }
  }
  await db.runTransaction(async (tx) => {
    const rows = await tx.get(db.collection("walls").where("id", "==", input.wallId).limit(2));
    const ref = db.collection("ownedAssets").doc(input.wallId);
    const existing = await tx.get(ref);
    const wall = rows.docs[0];
    if (rows.size !== 1 || !wall || wall.ref.path !== input.canonicalPath ||
      wall.createTime?.toMillis() !== input.incarnation || wall.createTime.nanoseconds !== input.incarnationNanos || wall.data().review !== true ||
      wall.data().wallpaper_url !== input.originalUrl || wall.data().wallpaper_thumb !== input.thumbUrl || existing.exists ||
      (expected && !matchesExpectedWall(wall, expected)) || !await dropAllowsBinding(wall.data(), tx)) {
      throw new PermanentOwnedAssetError("Legacy wall changed or already bound");
    }
    if (source) {
      const verified = await verifiedStudioSource(input.wallId, wall.data(), tx);
      if (verified?.runId !== source.runId || verified.candidateId !== source.candidateId) {
        throw new PermanentOwnedAssetError("Studio wall changed or is not a Studio wall");
      }
    }
    await verifyStoredUploadRegistry(input.original, tx);
    await verifyStoredUploadRegistry(input.thumb, tx);
    if (input.original.previewObjectId || !input.thumb.previewObjectId ||
      input.original.path.split("/").pop()?.startsWith("thumb_") ||
      !input.thumb.path.split("/").pop()?.startsWith("thumb_") || input.original.object === input.thumb.object) {
      throw new Error("Legacy wall asset roles are invalid");
    }
    tx.create(ref, {...binding, incarnationNanos: wall.createTime.nanoseconds, status: "ready",
      provenance: source ?? {kind: "legacy"}});
    tx.update(wall.ref, {wallpaper_url: "", wallpaper_thumb: ownedThumbnailUrl(input.thumb),
      wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: "",
      originalProtected: true, originalObjectId: input.original.objectId, ...releasedDropMarkers(wall.data())});
  });
}
export async function signOriginalDelivery(wallId: string): Promise<{url: string; expiresAt: number; objectId: string}> {
  const {original} = await delivery(wallId);
  await verifyStoredUpload(original);
  const expiresAt = Date.now() + 120000;
  const url = new R2Storage().presignGet(original.object, new Date(expiresAt));
  return {url, expiresAt, objectId: original.objectId};
}
export const onOwnedWallWritten = onDocumentWritten({document: "walls/{wallId}", region: REGION, retry: true,
  secrets: r2Secrets, memory: "512MiB", timeoutSeconds: 120}, async (event) => {
  const after = event.data?.after;
  const before = event.data?.before;
  if (after?.exists) {
    const data = after.data();
    const id = data?.id;
    if (validId(id)) {
      await bindOwnedWall(id);
      // Approval (admin, Studio, Drop release, old clients) is the moment an unprotected wall must be converted.
      // A protected wall returns here, so the redacting write that conversion makes does not loop.
      if (data?.review === true && data.originalProtected !== true) {
        await (await import("./ownedWallConversion.js")).convertApprovedWall(id);
      }
    }
  } else if (before?.exists && validId(before.data()?.id)) {
    const id: string = before.data()?.id;
    await cleanupDeletedOwnedWall({wallId: id, canonicalPath: before.ref.path,
      incarnation: before.createTime?.toMillis(), incarnationNanos: before.createTime?.nanoseconds});
  }
});

export async function cleanupDeletedOwnedWall(input: {wallId: string; canonicalPath: string;
  incarnation?: number; incarnationNanos?: number}): Promise<void> {
  if (!validId(input.wallId) || input.incarnation === undefined || input.incarnationNanos === undefined) return;
  const ref = db.collection("ownedAssets").doc(input.wallId);
  const previewObjectId = await db.runTransaction(async (tx) => {
    const manifest = (await tx.get(ref)).data();
    if (manifest?.canonicalPath !== input.canonicalPath || manifest.incarnation !== input.incarnation ||
      manifest.incarnationNanos !== input.incarnationNanos) return undefined;
    if (manifest.status !== "ready" && manifest.status !== "deleted") return undefined;
    const original = manifest.original;
    const thumb = manifest.thumb;
    if (!stored(original) || !stored(thumb) || !thumb.previewObjectId) return undefined;
    const assets = [original, thumb];
    const sharedRows = await Promise.all(assets.map((asset) => Promise.all([
      tx.get(db.collection("ownedAssets").where("original.objectId", "==", asset.objectId)),
      tx.get(db.collection("ownedAssets").where("thumb.objectId", "==", asset.objectId)),
    ])));
    const refs = sharedRows.map((queries, index) => queries.flatMap((rows) => rows.docs).some((doc) => {
      const data = doc.data();
      return doc.id !== input.wallId && data.status === "ready" &&
        [(data.original as StoredUpload | undefined)?.objectId, (data.thumb as StoredUpload | undefined)?.objectId]
          .includes(assets[index].objectId);
    }));
    const registryRefs = assets.map((asset) => db.collection("r2ObjectRegistry").doc(asset.objectId));
    const registries = await Promise.all(registryRefs.map((registryRef) => tx.get(registryRef)));
    if (registries.some((snapshot, index) => {
      const asset = assets[index];
      const registry = snapshot.data();
      return !registry || !["active", "tombstoned"].includes(registry.status) ||
        registry.objectId !== asset.objectId || registry.object !== asset.object || registry.sha256 !== asset.sha256 ||
        registry.uid !== asset.uid || registry.repo !== asset.repo || registry.path !== asset.path ||
        registry.sha !== asset.sha || registry.bucket !== asset.bucket ||
        registry.sourceKind !== (asset.sourceKind ?? "github") || registry.uploadId !== (asset.uploadId ?? "imported") ||
        registry.previewObjectId !== asset.previewObjectId;
    })) return undefined;
    if (manifest.status === "ready") tx.update(ref, {status: "deleted"});
    for (let index = 0; index < assets.length; index++) {
      const registry = registries[index].data()!;
      if (!refs[index] && registry.status === "active") {
        tx.update(registryRefs[index], {status: "tombstoned",
          cleanupNotBeforeMs: Date.now() + 5 * 60_000, deletedAt: admin.firestore.FieldValue.serverTimestamp()});
      }
    }
    return !refs[1] ? thumb.previewObjectId : undefined;
  });
  if (previewObjectId) await new R2Storage().delete("preview", `previews/${previewObjectId}.img`);
}

/** Reconciles tombstoned keys after the delete grace period, including a PUT that completed before a crash. */
export async function sweepR2Tombstones(nowMs = Date.now()): Promise<number> {
  if (!ownedAssetStorageEnabled()) return 0;
  const collection = db.collection("r2ObjectRegistry");
  const stateRef = db.collection("r2ObjectRegistryState").doc("tombstoneSweep");
  const state = (await stateRef.get()).data();
  const cursorId = typeof state?.cursorId === "string" ? state.cursorId : "";
  let query = collection.where("status", "==", "tombstoned")
    .orderBy(admin.firestore.FieldPath.documentId()).limit(100);
  if (cursorId) {
    const cursor = await collection.doc(cursorId).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }
  const rows = await query.get();
  const client = new R2Storage();
  let cleaned = 0;
  for (const row of rows.docs) {
    const value = row.data();
    if (typeof value.cleanupNotBeforeMs === "number" && value.cleanupNotBeforeMs > nowMs) {
      await stateRef.set({cursorId: row.id}, {merge: true});
      continue;
    }
    const sourceKind = value.sourceKind === "owned" || value.sourceKind === "studio" ? value.sourceKind :
      value.sourceKind === "github" ? undefined : null;
    if (sourceKind === null || typeof value.objectId !== "string" || !/^[a-f0-9]{64}$/.test(value.objectId) ||
      typeof value.uid !== "string" || !validId(value.uid) || typeof value.repo !== "string" ||
      typeof value.path !== "string" || typeof value.sha !== "string" || !/^[a-f0-9]{40}$/.test(value.sha) ||
      typeof value.sha256 !== "string" || !/^[a-f0-9]{64}$/.test(value.sha256) ||
      value.bucket !== process.env.R2_PRIVATE_BUCKET ||
      value.object !== `${objectPrefix(sourceKind)}/${value.objectId}` ||
      value.objectId !== r2ObjectId({uid: value.uid, repo: value.repo, path: value.path, sha: value.sha,
        ...(sourceKind ? {sourceKind} : {}),
        ...(typeof value.uploadId === "string" && value.uploadId !== "imported" ? {uploadId: value.uploadId} : {})}, value.sha256)) {
      console.warn("Skipping invalid R2 tombstone identity", {registryId: row.id});
      await stateRef.set({cursorId: row.id}, {merge: true});
      continue;
    }
    const preview = value.previewObjectId;
    if (preview !== undefined && (preview !== value.objectId || !previewId({repo: value.repo, path: value.path,
      sha: value.sha, ...(sourceKind ? {sourceKind} : {})}))) {
      console.warn("Skipping invalid R2 preview tombstone", {registryId: row.id});
      await stateRef.set({cursorId: row.id}, {merge: true});
      continue;
    }
    await client.delete("private", value.object);
    if (preview) await client.delete("preview", `previews/${preview}.img`);
    await db.runTransaction(async (tx) => {
      const current = await tx.get(row.ref);
      if (current.data()?.status === "tombstoned" && current.data()?.objectId === value.objectId) {
        tx.update(row.ref, {lastCleanupAt: admin.firestore.FieldValue.serverTimestamp()});
      }
    });
    await stateRef.set({cursorId: row.id}, {merge: true});
    cleaned++;
  }
  if (rows.size < 100) await stateRef.set({cursorId: ""}, {merge: true});
  return cleaned;
}
export const onR2TombstoneCleanup = onSchedule({schedule: "every 24 hours", region: REGION, maxInstances: 1, secrets: r2Secrets},
  async () => {
    await sweepR2Tombstones();
  });
