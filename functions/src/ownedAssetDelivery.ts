import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onRequest} from "firebase-functions/v2/https";
import {db, REGION} from "./common";

const hash = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");
const validId = (value: unknown): value is string => typeof value === "string" &&
  /^[A-Za-z0-9_-]{1,200}$/.test(value);
export const ownedAssetStorageEnabled = (): boolean => !!process.env.OWNED_ASSET_BUCKET;
function bucket() {
  if (!process.env.OWNED_ASSET_BUCKET) throw new Error("Owned asset storage is not configured");
  return admin.storage().bucket(process.env.OWNED_ASSET_BUCKET);
}
type UploadIdentity = {repo: string; path: string; sha: string};
export type StoredUpload = UploadIdentity & {
  bucket: string; object: string; generation: string; sha256: string; uid: string;
};
function objectName(input: UploadIdentity): string {
  if (!input.repo || ![process.env.GH_REPO_WALLS, process.env.GH_REPO_SETUPS].includes(input.repo) || !/^[a-f0-9]{40}$/.test(input.sha) ||
    !input.path || input.path.length > 1024 || input.path.startsWith("/") || input.path.includes("\\") ||
    input.path.split("/").some((part) => !part || part === "." || part === "..")) throw new Error("Invalid upload identity");
  return `retained/${hash(`${input.repo}\0${input.path}\0${input.sha}`)}`;
}
export async function retainUpload(input: UploadIdentity & {uid: string; bytes: Buffer}): Promise<StoredUpload> {
  if (!validId(input.uid) || !input.bytes.length) throw new Error("Invalid retained upload");
  const blobSha = createHash("sha1").update(`blob ${input.bytes.length}\0`).update(input.bytes).digest("hex");
  if (blobSha !== input.sha) throw new Error("Upload bytes do not match Git blob SHA");
  const target = bucket();
  const object = objectName(input);
  const file = target.file(object);
  const digest = hash(input.bytes);
  try {
    await file.save(input.bytes, {resumable: false, validation: "crc32c", preconditionOpts: {ifGenerationMatch: 0},
      metadata: {contentType: input.bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ?
        "image/png" : input.bytes.subarray(8, 12).toString() === "WEBP" ? "image/webp" :
          /^GIF8[79]a$/.test(input.bytes.subarray(0, 6).toString()) ? "image/gif" : "image/jpeg",
      cacheControl: "private, no-store", metadata: {sha256: digest, uid: input.uid}}});
  } catch (error) {
    if (!error || typeof error !== "object" || !("code" in error) || Number(error.code) !== 412) throw error;
  }
  const [metadata] = await file.getMetadata();
  if (!metadata.generation || metadata.metadata?.sha256 !== digest || metadata.metadata?.uid !== input.uid ||
    Number(metadata.size) !== input.bytes.length || metadata.metadata?.firebaseStorageDownloadTokens) {
    throw new Error("Retained upload mismatch");
  }
  return {repo: input.repo, path: input.path, sha: input.sha, uid: input.uid,
    bucket: target.name, object, generation: String(metadata.generation), sha256: digest};
}
export async function deleteRetainedUpload(input: UploadIdentity): Promise<void> {
  const file = bucket().file(objectName(input));
  try {
    const [metadata] = await file.getMetadata();
    for (const field of ["original.object", "thumb.object"]) {
      const manifests = await db.collection("ownedAssets").where(field, "==", file.name).get();
      for (const manifest of manifests.docs) {
        await db.runTransaction(async (tx) => {
          const current = (await tx.get(manifest.ref)).data();
          const asset = field === "original.object" ? current?.original : current?.thumb;
          if (current?.status === "ready" && asset?.object === file.name && asset.generation === String(metadata.generation)) {
            tx.update(manifest.ref, {status: "deleted"});
          }
        });
      }
    }
    await file.delete({ifGenerationMatch: metadata.generation});
  } catch (error) {
    if (!error || typeof error !== "object" || !("code" in error) || Number(error.code) !== 404) throw error;
  }
}
function stored(value: unknown): value is StoredUpload {
  if (!value || typeof value !== "object") return false;
  return "bucket" in value && value.bucket === process.env.OWNED_ASSET_BUCKET &&
    "object" in value && typeof value.object === "string" && /^retained\/[a-f0-9]{64}$/.test(value.object) &&
    "generation" in value && typeof value.generation === "string" && /^\d+$/.test(value.generation) &&
    "sha256" in value && typeof value.sha256 === "string" && /^[a-f0-9]{64}$/.test(value.sha256) &&
    "uid" in value && validId(value.uid) && "repo" in value && typeof value.repo === "string" &&
    "path" in value && typeof value.path === "string" && "sha" in value && typeof value.sha === "string";
}
export function ownedThumbnailUrl(id: string): string {
  const project = process.env.GCLOUD_PROJECT;
  const base = process.env.OWNED_THUMBNAIL_BASE_URL ??
    (project ? `https://${REGION}-${project}.cloudfunctions.net/ownedThumbnail` : undefined);
  if (!base) throw new Error("Owned thumbnail endpoint is not configured");
  const parsed = new URL(base);
  if (parsed.protocol !== "https:" || parsed.username || parsed.password || parsed.port || parsed.search || parsed.hash) {
    throw new Error("Invalid owned thumbnail endpoint");
  }
  return `${parsed.href.replace(/\/$/, "")}/${encodeURIComponent(id)}`;
}
async function proveAsset(data: admin.firestore.DocumentData, prefix: "wallpaper" | "thumb",
  tx: admin.firestore.Transaction): Promise<{upload: StoredUpload; url: string; kind: "owned" | "github"} | null> {
  const repo = process.env.GH_REPO_WALLS;
  const owner = process.env.GH_USERNAME;
  const path = data[`${prefix}_path`];
  const sha = data[`${prefix}_sha`];
  if (!repo || !owner || typeof path !== "string" || typeof sha !== "string") return null;
  try {
    objectName({repo, path, sha});
  } catch {
    return null;
  }
  const raw = data[prefix === "thumb" ? "wallpaper_thumb" : "wallpaper_url"];
  if (typeof raw !== "string") return null;
  try {
    if (raw !== "" || prefix !== "wallpaper") {
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
  const rows = await tx.get(db.collection("githubUploads").where("path", "==", path).limit(8));
  if (rows.size >= 8) return null;
  const records = rows.docs.filter((doc) => doc.data().repo === repo);
  const receipt = records.find((doc) => doc.id === `file_${hash(`${repo}\0${path}\0${sha}`)}`)?.data();
  const intent = (await tx.get(db.collection("githubUploadIntents").doc(`path_${hash(`${repo}\0${path}`)}`))).data();
  if (!receipt || !validId(receipt.uid) || records.some((doc) => doc.data().uid !== receipt.uid) ||
    receipt.sha !== sha || intent?.status !== "complete" || intent.uid !== receipt.uid || intent.repo !== repo ||
    intent.path !== path || intent.blobSha !== sha || intent.response?.content?.path !== path ||
    intent.response?.content?.sha !== sha || intent.response?.content?.download_url !== raw) return null;
  const retained = receipt.retainedAsset;
  const intentAsset = intent.retainedAsset;
  const privateOriginal = raw === "" && prefix === "wallpaper";
  if (privateOriginal && (receipt.sourceKind !== "owned" || intent.sourceKind !== "owned" ||
    !stored(intentAsset) || !stored(retained) ||
    (["repo", "path", "sha", "uid", "bucket", "object", "generation", "sha256"] as const)
      .some((field) => intentAsset[field] !== retained[field]))) return null;
  if (!privateOriginal && (receipt.sourceKind === "owned" || intent.sourceKind === "owned")) return null;
  if (!stored(retained) || retained.uid !== receipt.uid || retained.repo !== repo || retained.path !== path || retained.sha !== sha ||
    retained.object !== objectName({repo, path, sha})) return null;
  const [metadata] = await bucket().file(retained.object, {generation: retained.generation}).getMetadata();
  if (String(metadata.generation) !== retained.generation || metadata.metadata?.sha256 !== retained.sha256 ||
    metadata.metadata?.firebaseStorageDownloadTokens) throw new Error("Retained object is not durable");
  return {upload: retained, url: raw, kind: privateOriginal ? "owned" : "github"};
}

export async function bindOwnedWall(wallId: string): Promise<void> {
  if (!validId(wallId) || !ownedAssetStorageEnabled()) return;
  await db.runTransaction(async (tx) => {
    const rows = await tx.get(db.collection("walls").where("id", "==", wallId).limit(2));
    if (rows.size !== 1) return;
    const wall = rows.docs[0];
    const data = wall.data();
    const ref = db.collection("ownedAssets").doc(wallId);
    const existing = (await tx.get(ref)).data();
    if (!wall.createTime || existing?.status === "deleted") return;
    const incarnation = wall.createTime.toMillis();
    if (existing?.status === "ready") return;
    const original = await proveAsset(data, "wallpaper", tx);
    const thumb = await proveAsset(data, "thumb", tx);
    if (!original || !thumb || original.upload.uid !== thumb.upload.uid) return;
    if (original.upload.path === thumb.upload.path || original.upload.object === thumb.upload.object ||
      !thumb.upload.path.split("/").pop()?.startsWith("thumb_")) return;
    const author = await admin.auth().getUser(original.upload.uid);
    if (author.disabled || !author.email || author.email !== data.email) return;
    const thumbUrl = ownedThumbnailUrl(wallId);
    tx.set(ref, {status: "ready", canonicalPath: wall.ref.path, incarnation,
      incarnationNanos: wall.createTime.nanoseconds, original: original.upload,
      thumb: thumb.upload, originalUrl: original.url, thumbUrl: thumb.url,
      provenance: {kind: original.kind, uid: original.upload.uid}});
    tx.update(wall.ref, {wallpaper_url: "", wallpaper_thumb: thumbUrl, originalProtected: true,
      originalGeneration: original.upload.generation});
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
    wall.data().originalGeneration !== manifest.original.generation || wall.data().wallpaper_url !== "" ||
    wall.data().wallpaper_path !== manifest.original.path || wall.data().wallpaper_sha !== manifest.original.sha ||
    wall.data().thumb_path !== manifest.thumb.path || wall.data().thumb_sha !== manifest.thumb.sha ||
    wall.data().wallpaper_thumb !== ownedThumbnailUrl(wallId)) throw new Error("Owned wall unavailable");
  return {original: manifest.original, thumb: manifest.thumb, originalUrl: manifest.originalUrl,
    thumbUrl: manifest.thumbUrl, provenance: manifest.provenance};
}
export const getOwnedWallDelivery = delivery;
export async function bindLegacyOwnedWall(input: {wallId: string; canonicalPath: string; incarnation: number;
  incarnationNanos: number;
  originalUrl: string; thumbUrl: string; original: StoredUpload; thumb: StoredUpload}): Promise<void> {
  if (!validId(input.wallId) || !stored(input.original) || !stored(input.thumb)) throw new Error("Invalid legacy binding");
  for (const [asset, raw] of [[input.original, input.originalUrl], [input.thumb, input.thumbUrl]] as const) {
    const url = new URL(raw);
    const parts = url.pathname.split("/").slice(1).map(decodeURIComponent);
    if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || url.username || url.password ||
      url.search || url.hash || url.port || parts[0].toLowerCase() !== process.env.GH_USERNAME?.toLowerCase() ||
      parts[1] !== process.env.GH_REPO_WALLS || parts.slice(-asset.path.split("/").length).join("/") !== asset.path ||
      asset.object !== objectName(asset)) throw new Error("Invalid legacy origin");
    const [metadata] = await bucket().file(asset.object, {generation: asset.generation}).getMetadata();
    if (String(metadata.generation) !== asset.generation || metadata.metadata?.sha256 !== asset.sha256 ||
      metadata.metadata?.firebaseStorageDownloadTokens) throw new Error("Legacy copy is not durable");
  }
  await db.runTransaction(async (tx) => {
    const rows = await tx.get(db.collection("walls").where("id", "==", input.wallId).limit(2));
    const ref = db.collection("ownedAssets").doc(input.wallId);
    const existing = await tx.get(ref);
    const wall = rows.docs[0];
    if (rows.size !== 1 || !wall || wall.ref.path !== input.canonicalPath ||
      wall.createTime?.toMillis() !== input.incarnation || wall.createTime.nanoseconds !== input.incarnationNanos || wall.data().review !== true ||
      wall.data().wallpaper_url !== input.originalUrl || wall.data().wallpaper_thumb !== input.thumbUrl || existing.exists) {
      throw new Error("Legacy wall changed or already bound");
    }
    tx.create(ref, {...input, incarnationNanos: wall.createTime.nanoseconds, status: "ready", provenance: {kind: "legacy"}});
    tx.update(wall.ref, {wallpaper_url: "", wallpaper_thumb: ownedThumbnailUrl(input.wallId),
      wallpaper_path: input.original.path, wallpaper_sha: input.original.sha,
      thumb_path: input.thumb.path, thumb_sha: input.thumb.sha,
      originalProtected: true, originalGeneration: input.original.generation});
  });
}
export async function signOriginalDelivery(wallId: string): Promise<{url: string; expiresAt: number; generation: string}> {
  const {original} = await delivery(wallId);
  const file = bucket().file(original.object, {generation: original.generation});
  const [metadata] = await file.getMetadata();
  if (String(metadata.generation) !== original.generation || metadata.metadata?.sha256 !== original.sha256 ||
    metadata.metadata?.firebaseStorageDownloadTokens) throw new Error("Owned original unavailable");
  const expiresAt = Date.now() + 120000;
  const [url] = await file.getSignedUrl({
    version: "v4", action: "read", expires: expiresAt, queryParams: {generation: original.generation},
  });
  return {url, expiresAt, generation: original.generation};
}
export const ownedThumbnail = onRequest({region: REGION}, async (request, response) => {
  try {
    const id = request.path.split("/").filter(Boolean).pop() ?? "";
    const {thumb} = await delivery(id);
    const file = bucket().file(thumb.object, {generation: thumb.generation});
    const [[bytes], [metadata]] = await Promise.all([file.download(), file.getMetadata()]);
    const type = metadata.contentType;
    response.set("Cache-Control", "public, max-age=60")
      .type(type === "image/jpeg" || type === "image/png" || type === "image/webp" || type === "image/gif" ?
        type : "application/octet-stream").send(bytes);
  } catch {
    response.status(404).send("Not found");
  }
});
export const onOwnedWallWritten = onDocumentWritten({document: "walls/{wallId}", region: REGION, retry: true}, async (event) => {
  const after = event.data?.after;
  const before = event.data?.before;
  if (after?.exists) {
    const id = after.data()?.id;
    if (validId(id)) await bindOwnedWall(id);
  } else if (before?.exists && validId(before.data()?.id)) {
    const id: string = before.data()?.id;
    const ref = db.collection("ownedAssets").doc(id);
    await db.runTransaction(async (tx) => {
      const manifest = (await tx.get(ref)).data();
      if (manifest?.canonicalPath === before.ref.path && manifest.incarnation === before.createTime?.toMillis() &&
        manifest.incarnationNanos === before.createTime?.nanoseconds) {
        tx.update(ref, {status: "deleted"});
      }
    });
  }
});
