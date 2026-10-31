import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";
import {isDeepStrictEqual} from "node:util";
import {db} from "./common";
import {digest} from "./wallEditingCommon";
import {exactKeys} from "./wallMetadataValidation";
import {verifyGithubUpload} from "./githubContent";
import {ownedThumbnailUrl, PermanentOwnedAssetError, stored, verifyStoredUpload} from "./ownedAssetDelivery";
import {R2Storage} from "./r2Storage";

export type FileReference = {path: string; sha: string; sourceKind: "github" | "owned"};
export function parseFileReference(raw: unknown): FileReference {
  const input = exactKeys(raw, ["path", "sha", "sourceKind"]);
  if (typeof input.path !== "string" || !input.path || input.path.length > 900 || /[/\\\p{C}]/u.test(input.path) ||
    input.path === "." || input.path === ".." || typeof input.sha !== "string" || !/^[a-f0-9]{40}$/.test(input.sha) ||
    (input.sourceKind !== "github" && input.sourceKind !== "owned")) {
    throw new HttpsError("invalid-argument", "Invalid file reference.");
  }
  return input as FileReference;
}
export const uploadFileKey = (repo: string, file: FileReference): string =>
  `${file.sourceKind === "owned" ? "owned_" : ""}file_${digest(`${repo}\0${file.path}\0${file.sha}`)}`;
export const uploadPathKey = (repo: string, file: FileReference): string =>
  `${file.sourceKind === "owned" ? "owned_" : ""}path_${digest(`${repo}\0${file.path}`)}`;

/** Exact completed records plus live storage. The caller's transaction also fences deletion and generations. */
export async function proveCompletedWallUpload(tx: admin.firestore.Transaction, uid: string, file: FileReference,
  role: "original" | "thumbnail", after: admin.firestore.Timestamp) {
  const repo = process.env.GH_REPO_WALLS?.trim();
  const owner = process.env.GH_USERNAME?.trim();
  if (!repo || !owner) throw new HttpsError("failed-precondition", "Upload storage is not configured.");
  const fileKey = uploadFileKey(repo, file);
  const [receipt, intentSnap, tombstone] = await Promise.all([
    tx.get(db.collection("githubUploads").doc(fileKey)),
    tx.get(db.collection("githubUploadIntents").doc(uploadPathKey(repo, file))),
    tx.get(db.collection("ownedUploadDeletions").doc(fileKey)),
  ]);
  const record = receipt.data();
  const intent = intentSnap.data();
  if (!record || record.uid !== uid || record.repo !== repo || record.path !== file.path || record.sha !== file.sha ||
    record.sourceKind !== file.sourceKind || typeof record.generation !== "string" || !record.generation ||
    !intent || intent.uid !== uid || intent.repo !== repo || intent.path !== file.path || intent.sha !== file.sha ||
    intent.blobSha !== file.sha || intent.sourceKind !== file.sourceKind || intent.status !== "complete" ||
    intent.generation !== undefined && intent.generation !== record.generation || typeof intent.uploadId !== "string" ||
    record.weeklyQuotaCharged !== intent.weeklyQuotaCharged || record.uploadWeek !== intent.uploadWeek ||
    intent.response?.sourceKind !== file.sourceKind || intent.response?.content?.path !== file.path ||
    intent.response?.content?.sha !== file.sha || typeof intent.response?.content?.download_url !== "string" ||
    tombstone.exists || !(record.createdAt instanceof admin.firestore.Timestamp) ||
    record.createdAt.seconds < after.seconds || record.createdAt.seconds === after.seconds && record.createdAt.nanoseconds <= after.nanoseconds) {
    throw new HttpsError("failed-precondition", "Fresh completed upload proof is unavailable.");
  }
  const url: string = intent.response.content.download_url;
  const retained = record.retainedAsset;
  if (file.sourceKind === "owned" || retained !== undefined) {
    if (!stored(retained) || !isDeepStrictEqual(retained, intent.retainedAsset) || retained.uid !== uid ||
      retained.repo !== repo || retained.path !== file.path || retained.sha !== file.sha || retained.uploadId !== intent.uploadId ||
      (retained.sourceKind === "owned") !== (file.sourceKind === "owned") ||
      (role === "thumbnail" ? retained.previewObjectId !== retained.objectId : retained.previewObjectId !== undefined)) {
      throw new HttpsError("failed-precondition", "Retained upload identity or role is invalid.");
    }
    try {
      await verifyStoredUpload(retained, undefined, true, tx);
    } catch (error) {
      if (error instanceof PermanentOwnedAssetError) throw new HttpsError("failed-precondition", "Retained upload is unavailable or changed.");
      throw error;
    }
    if (role === "thumbnail") {
      const client = new R2Storage();
      const preview = await client.head("preview", `previews/${retained.objectId}.img`);
      if (!preview || preview.objectId !== retained.objectId || preview.sha256 !== retained.sha256 ||
        digest(await client.get("preview", `previews/${retained.objectId}.img`)) !== retained.sha256) {
        throw new HttpsError("failed-precondition", "Preview is unavailable.");
      }
    }
    if (file.sourceKind === "owned" && url !== (role === "original" ? "" : ownedThumbnailUrl(retained))) {
      throw new HttpsError("failed-precondition", "Owned upload URL does not match its role.");
    }
  }
  if (file.sourceKind === "github") {
    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      throw new HttpsError("failed-precondition", "Invalid stored upload URL.");
    }
    const parts = parsed.pathname.split("/").slice(1).map(decodeURIComponent);
    if (parsed.protocol !== "https:" || parsed.hostname !== "raw.githubusercontent.com" || parsed.username || parsed.password ||
      parsed.port || parsed.search || parsed.hash || parts.length !== 4 || parts[0].toLowerCase() !== owner.toLowerCase() ||
      parts[1] !== repo || parts[3] !== file.path) throw new HttpsError("failed-precondition", "Invalid stored upload URL.");
    await verifyGithubUpload(repo, file.path, file.sha);
  }
  return {url, fileKey, generation: record.generation as string};
}
