import * as admin from "firebase-admin";
import {createHash, randomUUID} from "node:crypto";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {db, readDailyCount, CALLABLE_REGIONS, utcDateString} from "./common";
import {deleteRetainedUpload, ownedAssetStorageEnabled, ownedThumbnailUrl, retainUpload, stored,
  type StoredUpload} from "./ownedAssetDelivery";
import {r2Secrets} from "./r2Storage";

const UPLOADS = "githubUploads";
const UPLOAD_STATS = "githubUploadStats";
const UPLOAD_INTENTS = "githubUploadIntents";
const OWNED_DELETIONS = "ownedUploadDeletions";
const ISO_BMFF_IMAGE_BRANDS = new Set(["heic", "heix", "hevc", "heim", "heis", "mif1", "msf1", "avif"]);
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;
const MAX_UPLOADS_PER_DAY = 30;
const INTENT_LEASE_MS = 120_000;
const GITHUB_REQUEST_TIMEOUT_MS = 30_000;
// Mirrors UploadQuota.freeUploadsPerWeek in lib/core/purchases/upload_quota.dart.
const FREE_WALLS_PER_WEEK = 3;
// Wall submission previews use "thumb_" in the walls repo.
const WALL_THUMB_PREFIX = "thumb_";
const CALLABLE_OPTIONS = {region: CALLABLE_REGIONS, cors: true, maxInstances: 10};
const githubToken = defineSecret("GH_TOKEN");

type GithubContentData = {
  repo?: unknown;
  path?: unknown;
  contentBase64?: unknown;
  message?: unknown;
  sha?: unknown;
  purpose?: unknown;
  sourceKind?: unknown;
  wallId?: unknown;
  originalObjectId?: unknown;
  assetRole?: unknown;
};

type GithubEnv = {
  GH_USERNAME?: string;
  GH_REPO_WALLS?: string;
  GH_REPO_SETUPS?: string;
};

export function isAllowedRepo(repo: unknown, env: GithubEnv = process.env): repo is string {
  if (typeof repo !== "string") return false;
  const value = repo.trim();
  return value.length > 0 && [env.GH_REPO_WALLS, env.GH_REPO_SETUPS].some((allowed) => value === allowed?.trim());
}

export function isValidGithubPath(filePath: unknown): filePath is string {
  if (typeof filePath !== "string") return false;
  const value = filePath.trim();
  return (
    value.length > 0 &&
    value.length <= 1024 &&
    !value.startsWith("/") &&
    !value.endsWith("/") &&
    !value.includes("\\") &&
    !value.includes("//") &&
    !value.split("/").some((part) => part === "" || part === "." || part === "..")
  );
}

/** True when the first bytes of the base64 payload are a JPEG, PNG, GIF, WebP, HEIC/HEIF or AVIF header. */
export function isAllowedImageContent(contentBase64: string): boolean {
  // 44 base64 chars decode to 33 bytes: enough for every signature below.
  const b = Buffer.from(contentBase64.slice(0, 44), "base64");
  const ascii = (from: number, to: number) => b.subarray(from, to).toString("latin1");
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return true;
  if (b.length >= 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return true;
  if (b.length >= 6 && ["GIF87a", "GIF89a"].includes(ascii(0, 6))) return true;
  if (b.length >= 12 && ascii(0, 4) === "RIFF" && ascii(8, 12) === "WEBP") return true;
  return b.length >= 12 && ascii(4, 8) === "ftyp" && ISO_BMFF_IMAGE_BRANDS.has(ascii(8, 12));
}

export function isValidBase64(value: string): boolean {
  return Buffer.from(value, "base64").toString("base64") === value;
}

/** Decoded byte size of a base64 string, without decoding it. */
export function base64DecodedBytes(value: string): number {
  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return Math.max(0, Math.floor((value.length * 3) / 4) - padding);
}

/** UTC date (YYYY-MM-DD) of the Monday that starts the week of `nowMs`. */
export function weekStartUtc(nowMs: number): string {
  const d = new Date(nowMs);
  const sinceMonday = (d.getUTCDay() + 6) % 7;
  return utcDateString(new Date(nowMs - sinceMonday * 86_400_000));
}

export function isWallSubmissionUpload(repo: string, filePath: string, env: GithubEnv = process.env): boolean {
  const name = filePath.split("/").pop() ?? "";
  return repo === env.GH_REPO_WALLS?.trim() && name.startsWith(WALL_THUMB_PREFIX);
}

/**
 * Counts this upload against the caller's daily cap and, for a free user's wall preview, the weekly wall quota.
 * Throws resource-exhausted over a limit. Returns whether the weekly quota was counted.
 */
export async function reserveUploadSlot(callerUid: string, countsAsWall: boolean, nowMs: number): Promise<boolean> {
  const today = utcDateString(new Date(nowMs));
  const week = weekStartUtc(nowMs);
  const statsRef = db.collection(UPLOAD_STATS).doc(callerUid);
  const userRef = db.collection("usersv2").doc(callerUid);
  return db.runTransaction(async (tx) => {
    const statsSnap = await tx.get(statsRef);
    const userSnap = countsAsWall ? await tx.get(userRef) : null;
    const daily = readDailyCount(statsSnap, today);
    if (daily >= MAX_UPLOADS_PER_DAY) throw new HttpsError("resource-exhausted", "Daily upload limit reached.");
    const stats = statsSnap.data() ?? {};
    const weekly = stats.week === week && typeof stats.weekCount === "number" ? stats.weekCount : 0;
    const countWeekly = countsAsWall && userSnap?.data()?.premium !== true;
    if (countWeekly && weekly >= FREE_WALLS_PER_WEEK) {
      throw new HttpsError("resource-exhausted", "Free weekly wallpaper upload limit reached.");
    }
    tx.set(statsRef, {day: today, count: daily + 1, week, weekCount: weekly + (countWeekly ? 1 : 0)});
    return countWeekly;
  });
}

function uploadIntentId(repo: string, filePath: string, sourceKind?: unknown): string {
  return `${sourceKind === "owned" ? "owned_" : ""}path_${createHash("sha256").update(repo + "\0" + filePath).digest("hex")}`;
}

function gitBlobSha(contentBase64: string): string {
  const bytes = Buffer.from(contentBase64, "base64");
  return createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
}

type UploadIntent = Record<string, unknown>;

async function claimUploadIntent(
  callerUid: string,
  repo: string,
  filePath: string,
  blobSha: string,
  nowMs: number,
  sourceKind: "owned" | "github",
): Promise<{intent: UploadIntent; attemptId: string; completedResponse?: Record<string, unknown>; newlyClaimed?: boolean}> {
  const week = weekStartUtc(nowMs);
  const statsRef = db.collection(UPLOAD_STATS).doc(callerUid);
  const userRef = db.collection("usersv2").doc(callerUid);
  const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, filePath, sourceKind));
  const attemptId = randomUUID();
  return db.runTransaction(async (tx) => {
    const statsSnap = await tx.get(statsRef);
    const userSnap = isWallSubmissionUpload(repo, filePath) ? await tx.get(userRef) : null;
    const intentSnap = await tx.get(intentRef);
    const stats = statsSnap.data() ?? {};
    const intent = (intentSnap.data() ?? {}) as UploadIntent;
    if (intentSnap.exists) {
      if (intent.uid !== callerUid) throw new HttpsError("permission-denied", "This upload path is already claimed.");
      if (intent.repo !== repo || intent.path !== filePath || intent.blobSha !== blobSha) {
        throw new HttpsError("failed-precondition", "This path is already reserved for a different upload.");
      }
      if (intent.status === "complete") {
        return {intent, attemptId, completedResponse: intent.response as Record<string, unknown>};
      }
      if (intent.status !== "pending") throw new HttpsError("failed-precondition", "Upload state is invalid.");
      if (typeof intent.attemptExpiresAt === "number" && intent.attemptExpiresAt > nowMs) {
        throw new HttpsError("resource-exhausted", "Upload is already in progress.");
      }
      tx.update(intentRef, {attemptId, attemptExpiresAt: nowMs + INTENT_LEASE_MS});
      return {intent, attemptId};
    }

    const weekCount = stats.week === week && typeof stats.weekCount === "number" ? stats.weekCount : 0;
    const weekly = isWallSubmissionUpload(repo, filePath) && userSnap?.data()?.premium !== true;
    if (weekly && weekCount >= FREE_WALLS_PER_WEEK) {
      throw new HttpsError("resource-exhausted", "Free weekly wallpaper upload limit reached.");
    }
    tx.set(statsRef, {
      ...stats,
      week,
      weekCount: weekCount + (weekly ? 1 : 0),
    });
    const intentData: UploadIntent = {
      uid: callerUid,
      repo,
      path: filePath,
      blobSha,
      sourceKind,
      uploadId: randomUUID(),
      status: "pending",
      weeklyQuotaCharged: weekly,
      uploadWeek: week,
      attemptId,
      attemptExpiresAt: nowMs + INTENT_LEASE_MS,
    };
    tx.set(intentRef, intentData);
    return {intent: intentData, attemptId, newlyClaimed: true};
  });
}

async function releaseUploadAttempt(
  repo: string,
  filePath: string,
  intent: UploadIntent,
  attemptId: string,
  callerUid: string,
  nowMs: number,
  discard = false,
): Promise<void> {
  const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, filePath, intent.sourceKind));
  const statsRef = db.collection(UPLOAD_STATS).doc(callerUid);
  await db.runTransaction(async (tx) => {
    const intentSnap = await tx.get(intentRef);
    const current = intentSnap.data() as UploadIntent | undefined;
    if (!current || current.attemptId !== attemptId || current.status !== "pending") return;
    if (!discard) {
      tx.update(intentRef, {attemptId: "", attemptExpiresAt: 0});
      return;
    }
    const statsSnap = await tx.get(statsRef);
    const stats = statsSnap.data();
    if (
      intent.weeklyQuotaCharged === true && intent.uploadWeek === weekStartUtc(nowMs) &&
      stats?.week === intent.uploadWeek && typeof stats.weekCount === "number" && stats.weekCount > 0
    ) {
      tx.update(statsRef, {weekCount: stats.weekCount - 1});
    }
    tx.delete(intentRef);
  });
}

async function reserveRetryWallSlot(
  callerUid: string,
  repo: string,
  filePath: string,
  attemptId: string,
  nowMs: number,
): Promise<UploadIntent> {
  const week = weekStartUtc(nowMs);
  const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, filePath));
  const statsRef = db.collection(UPLOAD_STATS).doc(callerUid);
  const userRef = db.collection("usersv2").doc(callerUid);
  return db.runTransaction(async (tx) => {
    const intent = (await tx.get(intentRef)).data() as UploadIntent | undefined;
    if (!intent || intent.uid !== callerUid || intent.status !== "pending" || intent.attemptId !== attemptId) {
      throw new HttpsError("failed-precondition", "Upload reservation changed.");
    }
    if (intent.uploadWeek === week && intent.weeklyQuotaCharged === true) return intent;
    const stats = (await tx.get(statsRef)).data() ?? {};
    const user = (await tx.get(userRef)).data();
    const weekly = user?.premium !== true;
    const weekCount = stats.week === week && typeof stats.weekCount === "number" ? stats.weekCount : 0;
    if (weekly && weekCount >= FREE_WALLS_PER_WEEK) {
      throw new HttpsError("resource-exhausted", "Free weekly wallpaper upload limit reached.");
    }
    if (weekly) tx.set(statsRef, {...stats, week, weekCount: weekCount + 1});
    tx.update(intentRef, {uploadWeek: week, weeklyQuotaCharged: weekly});
    return {...intent, uploadWeek: week, weeklyQuotaCharged: weekly};
  });
}

async function completeUploadIntent(
  callerUid: string,
  repo: string,
  filePath: string,
  intent: UploadIntent,
  attemptId: string,
  response: Record<string, unknown>,
  retainedAsset?: StoredUpload,
): Promise<void> {
  const content = response.content as Record<string, unknown> | undefined;
  const sha = content?.sha;
  if (
    typeof sha !== "string" || sha.length === 0 || sha !== intent.blobSha ||
    content?.path !== filePath || typeof content.download_url !== "string" ||
    (content.download_url === "" && (intent.sourceKind !== "owned" || !retainedAsset))
  ) {
    throw new HttpsError("internal", "GitHub upload returned incomplete file details.");
  }
  const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, filePath, intent.sourceKind));
  const uploadRef = db.collection(UPLOADS).doc(uploadRecordId(repo, filePath, sha, intent.sourceKind));
  await db.runTransaction(async (tx) => {
    const currentSnap = await tx.get(intentRef);
    const current = currentSnap.data() as UploadIntent | undefined;
    if (!current || current.uid !== callerUid || current.blobSha !== intent.blobSha) {
      throw new HttpsError("failed-precondition", "Upload reservation changed.");
    }
    if (current.status === "complete") {
      if (retainedAsset) {
        tx.update(uploadRef, {retainedAsset});
        tx.update(intentRef, {retainedAsset});
      }
      return;
    }
    if (current.status !== "pending") throw new HttpsError("failed-precondition", "Upload state changed.");
    if (current.attemptId !== attemptId) throw new HttpsError("failed-precondition", "Upload attempt expired.");
    const savedResponse = {content: {path: content.path, sha, download_url: content.download_url},
      sourceKind: intent.sourceKind === "owned" ? "owned" : "github"};
    tx.set(uploadRef, {
      uid: callerUid,
      repo,
      path: filePath,
      sha,
      sourceKind: intent.sourceKind === "owned" ? "owned" : "github",
      ...(retainedAsset ? {retainedAsset} : {}),
      generation: randomUUID(),
      weeklyQuotaCharged: intent.weeklyQuotaCharged === true,
      uploadWeek: intent.uploadWeek,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(intentRef, {status: "complete", sha, response: savedResponse, attemptId: "", attemptExpiresAt: 0,
      ...(retainedAsset ? {retainedAsset} : {})});
  });
}

async function claimDeleteIntent(
  callerUid: string,
  repo: string,
  filePath: string,
  sha: string,
  uploadRef: FirebaseFirestore.DocumentReference,
  record: GithubUploadRecord | undefined,
  isAdmin: boolean,
  nowMs: number,
  manifestProof?: ManifestDeleteProof,
): Promise<{attemptId: string; generation: string}> {
  const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, filePath, record?.sourceKind));
  const attemptId = randomUUID();
  return db.runTransaction(async (tx) => {
    if (manifestProof) await readManifestDeleteProof(tx, callerUid, isAdmin, manifestProof);
    const uploadSnap = await tx.get(uploadRef);
    const intentSnap = await tx.get(intentRef);
    const currentRecord = uploadSnap.exists ? uploadSnap.data() as GithubUploadRecord : undefined;
    if (manifestProof && (!currentRecord || !sameStoredUpload(currentRecord.retainedAsset, manifestProof.asset))) {
      throw new HttpsError("failed-precondition", "Retained upload changed before deletion.");
    }
    if (record && (!currentRecord || currentRecord.generation !== record.generation ||
      !canDeleteUpload(currentRecord, callerUid, repo, filePath, isAdmin))) {
      throw new HttpsError("failed-precondition", "Upload changed before deletion.");
    }
    if (!record && uploadSnap.exists && !isAdmin) {
      throw new HttpsError("permission-denied", "You cannot delete this file.");
    }
    const currentIntent = intentSnap.data() as UploadIntent | undefined;
    if (currentIntent?.status === "deleting") {
      if (currentIntent.deleteSha !== sha || typeof currentIntent.deleteExpiresAt !== "number" ||
        currentIntent.deleteExpiresAt > nowMs) {
        throw new HttpsError("resource-exhausted", "Deletion is already in progress.");
      }
    } else if (currentIntent && (currentIntent.status !== "complete" || currentIntent.uid !== record?.uid ||
      currentIntent.sha !== sha)) {
      throw new HttpsError("resource-exhausted", "Upload is already in progress.");
    }
    const generation = typeof currentRecord?.generation === "string" ? currentRecord.generation : randomUUID();
    if (uploadSnap.exists && currentRecord?.generation !== generation) tx.update(uploadRef, {generation});
    tx.set(intentRef, {
      ...(currentIntent ?? {}),
      uid: currentRecord?.uid ?? callerUid,
      repo,
      path: filePath,
      sha,
      status: "deleting",
      deleteSha: sha,
      deleteAttemptId: attemptId,
      deleteExpiresAt: nowMs + INTENT_LEASE_MS,
      deletingGeneration: generation,
    });
    return {attemptId, generation};
  });
}

async function finishDeleteIntent(
  callerUid: string,
  repo: string,
  filePath: string,
  sha: string,
  uploadRef: FirebaseFirestore.DocumentReference,
  isAdmin: boolean,
  attemptId: string,
  generation: string,
  nowMs: number,
  failed = false,
  sourceKind?: unknown,
): Promise<void> {
  const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, filePath, sourceKind));
  const statsRef = db.collection(UPLOAD_STATS).doc(callerUid);
  await db.runTransaction(async (tx) => {
    const uploadSnap = await tx.get(uploadRef);
    const intentSnap = await tx.get(intentRef);
    const intent = intentSnap.data() as UploadIntent | undefined;
    if (intent?.status !== "deleting" || intent.deleteAttemptId !== attemptId || intent.deletingGeneration !== generation) return;
    if (failed) {
      if (typeof intent.blobSha === "string") {
        tx.update(intentRef, {status: "complete", deleteSha: "", deleteAttemptId: "", deleteExpiresAt: 0,
          deletingGeneration: ""});
      } else {
        tx.delete(intentRef);
      }
      return;
    }
    const record = uploadSnap.exists ? uploadSnap.data() as GithubUploadRecord : undefined;
    if (record && (record.generation !== generation || !canDeleteUpload(record, callerUid, repo, filePath, isAdmin))) {
      throw new HttpsError("failed-precondition", "Upload changed during deletion.");
    }
    const shouldReleaseWeekly = !isAdmin && record && isWallSubmissionUpload(repo, filePath) &&
      record.weeklyQuotaCharged === true && record.uploadWeek === weekStartUtc(nowMs);
    const statsSnap = shouldReleaseWeekly ? await tx.get(statsRef) : null;
    const stats = statsSnap?.data();
    if (record) tx.delete(uploadRef);
    if (sourceKind === "owned") {
      tx.set(db.collection(OWNED_DELETIONS).doc(uploadRecordId(repo, filePath, sha, "owned")),
        {uid: record?.uid ?? callerUid, repo, path: filePath, sha, sourceKind, status: "deleted"});
    }
    tx.delete(intentRef);
    if (shouldReleaseWeekly && record && stats && stats.week === record.uploadWeek && typeof stats.weekCount === "number" &&
      stats.weekCount > 0) {
      tx.update(statsRef, {weekCount: stats.weekCount - 1});
    }
  });
}

function requiredString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${name} is required.`);
  }
  return value.trim();
}

type ManifestDeleteProof = {
  wallId: string; originalObjectId: string; assetRole: "wallpaper" | "thumb";
  asset?: StoredUpload; canonicalPath?: unknown; incarnation?: unknown; incarnationNanos?: unknown;
};

function sameStoredUpload(left: unknown, right: unknown): boolean {
  if (!stored(left) || !stored(right)) return false;
  return left.bucket === right.bucket && left.objectId === right.objectId && left.object === right.object &&
    left.repo === right.repo && left.path === right.path && left.sha === right.sha && left.sha256 === right.sha256 &&
    left.uid === right.uid && left.sourceKind === right.sourceKind && left.uploadId === right.uploadId;
}

async function readManifestDeleteProof(
  tx: FirebaseFirestore.Transaction, callerUid: string, isAdmin: boolean, proof: ManifestDeleteProof,
): Promise<ManifestDeleteProof & {asset: StoredUpload}> {
  const manifest = (await tx.get(db.collection("ownedAssets").doc(proof.wallId))).data();
  const asset = proof.assetRole === "wallpaper" ? manifest?.original : manifest?.thumb;
  if (!manifest || !["ready", "deleted"].includes(manifest.status) || !stored(manifest.original) || !stored(asset) ||
    manifest.original.objectId !== proof.originalObjectId || typeof manifest.canonicalPath !== "string" ||
    !/^walls\/[^/]+$/.test(manifest.canonicalPath)) {
    throw new HttpsError("failed-precondition", "Owned wall cleanup identity is unavailable.");
  }
  if (!isAdmin && (asset.uid !== callerUid || manifest.original.uid !== callerUid || manifest.provenance?.uid !== callerUid)) {
    throw new HttpsError("permission-denied", "You cannot delete this wall's files.");
  }
  if (asset.uid === "legacy-migration" && (manifest.provenance?.kind !== "legacy" ||
    manifest.original.uid !== "legacy-migration")) {
    throw new HttpsError("failed-precondition", "Legacy migration identity is unavailable.");
  }
  if (proof.asset && (!sameStoredUpload(proof.asset, asset) || manifest.canonicalPath !== proof.canonicalPath ||
    manifest.incarnation !== proof.incarnation || manifest.incarnationNanos !== proof.incarnationNanos)) {
    throw new HttpsError("failed-precondition", "Owned wall changed before deletion.");
  }
  const rows = await tx.get(db.collection("walls").where("id", "==", proof.wallId).limit(2));
  const canonical = await tx.get(db.collection("walls").doc(manifest.canonicalPath.slice("walls/".length)));
  if (rows.size > 1 || (rows.size === 1 && rows.docs[0].ref.path !== manifest.canonicalPath)) {
    throw new HttpsError("failed-precondition", "Wall identity is ambiguous.");
  }
  if (canonical.exists) {
    const wall = canonical.data();
    if (!canonical.createTime || wall?.id !== proof.wallId ||
      canonical.createTime.toMillis() !== manifest.incarnation || canonical.createTime.nanoseconds !== manifest.incarnationNanos ||
      wall.originalProtected !== true || wall.originalObjectId !== proof.originalObjectId ||
      (!isAdmin && wall.review !== false)) {
      throw new HttpsError("failed-precondition", "Wall is no longer the pending upload.");
    }
  }
  return {...proof, asset, canonicalPath: manifest.canonicalPath,
    incarnation: manifest.incarnation, incarnationNanos: manifest.incarnationNanos};
}

function validateCommon(data: GithubContentData): {repo: string; path: string; message: string} {
  const repo = requiredString(data.repo, "repo");
  const filePath = requiredString(data.path, "path");
  const message = requiredString(data.message, "message");
  if (!isAllowedRepo(repo)) throw new HttpsError("permission-denied", "Repository is not allowed.");
  if (!isValidGithubPath(filePath)) throw new HttpsError("invalid-argument", "Invalid file path.");
  return {repo, path: filePath, message};
}

export interface GithubUploadRecord {
  sourceKind?: unknown;
  uid?: unknown;
  repo?: unknown;
  path?: unknown;
  sha?: unknown;
  generation?: unknown;
  weeklyQuotaCharged?: unknown;
  uploadWeek?: unknown;
  retainedAsset?: unknown;
}

/** True when `record` proves `callerUid` owns this repo+path, or the caller is an admin. */
export function canDeleteUpload(
  record: GithubUploadRecord | undefined,
  callerUid: string,
  repo: string,
  path: string,
  isAdmin: boolean,
): boolean {
  if (isAdmin) return true;
  if (!record) return false;
  return record.uid === callerUid && record.repo === repo && record.path === path;
}

function githubUrl(repo: string, filePath: string): string {
  const owner = requiredString(process.env.GH_USERNAME, "GH_USERNAME");
  const encodedPath = filePath.split("/").map(encodeURIComponent).join("/");
  return `https://api.github.com/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/contents/${encodedPath}`;
}

function uploadRecordId(repo: string, filePath: string, sha: string, sourceKind?: unknown): string {
  return `${sourceKind === "owned" ? "owned_" : ""}file_${createHash("sha256").update(`${repo}\0${filePath}\0${sha}`).digest("hex")}`;
}

async function githubRequest(url: string, init: RequestInit): Promise<Record<string, unknown>>;
async function githubRequest(url: string, init: RequestInit, notFoundIsNull: true): Promise<Record<string, unknown> | null>;
async function githubRequest(
  url: string,
  init: RequestInit,
  notFoundIsNull = false,
): Promise<Record<string, unknown> | null> {
  try {
    const response = await fetch(url, {
      ...init,
      signal: init.signal ?? AbortSignal.timeout(GITHUB_REQUEST_TIMEOUT_MS),
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": `Bearer ${githubToken.value()}`,
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        ...init.headers,
      },
    });
    const body = await response.json() as Record<string, unknown>;
    if (notFoundIsNull && response.status === 404) return null;
    if (!response.ok) {
      throw new HttpsError("internal", `GitHub request failed (${response.status}).`, {httpStatus: response.status});
    }
    return body;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "GitHub request failed.");
  }
}

function githubHttpStatus(error: unknown): number | undefined {
  if (!(error instanceof HttpsError) || !error.details || typeof error.details !== "object") return undefined;
  const status = (error.details as {httpStatus?: unknown}).httpStatus;
  return typeof status === "number" ? status : undefined;
}

export const githubPutFile = onCall(
  {...CALLABLE_OPTIONS, secrets: [githubToken, ...r2Secrets], timeoutSeconds: 60},
  async (request: CallableRequest<GithubContentData>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to upload files.");
    const rawSha = request.data?.sha;
    if (rawSha != null) throw new HttpsError("invalid-argument", "Overwrites are not allowed.");
    const {repo, path, message} = validateCommon(request.data ?? {});
    const purpose = request.data?.purpose;
    if (purpose != null && purpose !== "wallpaper" && purpose !== "profile") {
      throw new HttpsError("invalid-argument", "purpose must be wallpaper or profile.");
    }
    const contentBase64 = requiredString(request.data?.contentBase64, "contentBase64");
    if (base64DecodedBytes(contentBase64) > MAX_UPLOAD_BYTES) throw new HttpsError("invalid-argument", "File is too large.");
    if (!isValidBase64(contentBase64)) throw new HttpsError("invalid-argument", "contentBase64 must be valid base64.");
    if (!isAllowedImageContent(contentBase64)) throw new HttpsError("invalid-argument", "Only image files are allowed.");

    const nowMs = Date.now();
    await reserveUploadSlot(callerUid, false, nowMs);
    const blobSha = gitBlobSha(contentBase64);
    const ownedUpload = purpose === "wallpaper" && ownedAssetStorageEnabled() && repo === process.env.GH_REPO_WALLS?.trim();
    const sourceKind = ownedUpload ? "owned" : "github";
    const intentRef = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, path, sourceKind));
    const priorIntent = await intentRef.get();
    if (ownedUpload) {
      const legacyIntent = await db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, path)).get();
      if (legacyIntent.exists && (legacyIntent.data()?.status === "pending" || legacyIntent.data()?.sourceKind === "owned")) {
        throw new HttpsError("failed-precondition", "Legacy original upload requires reconciliation before retry.");
      }
    }
    if (!priorIntent.exists && !ownedUpload) {
      const existing = await githubRequest(githubUrl(repo, path), {method: "GET"}, true);
      if (existing) throw new HttpsError("already-exists", "File already exists.");
    }
    const claim = await claimUploadIntent(callerUid, repo, path, blobSha, nowMs, sourceKind);
    let intent = claim.intent;
    const withSourceKind = (response: Record<string, unknown>) => ({
      ...response, sourceKind: intent.sourceKind === "owned" ? "owned" : "github",
    });
    const complete = async (response: Record<string, unknown>) => {
      const content = response.content as Record<string, unknown> | undefined;
      if (content?.sha !== blobSha || typeof content.path !== "string" ||
        !ownedUpload && typeof content.download_url !== "string") {
        throw new HttpsError("internal", "Upload returned incomplete file details.");
      }
      const retainedAsset = ownedUpload ? await retainUpload({
        repo, path, sha: blobSha, uid: callerUid, bytes: Buffer.from(contentBase64, "base64"),
        ...(intent.sourceKind === "owned" ? {sourceKind: "owned" as const} : {}),
        ...(typeof intent.uploadId === "string" ? {uploadId: intent.uploadId} : {}),
      }) : undefined;
      const completedResponse = ownedUpload ? {content: {path, sha: blobSha,
        download_url: path.split("/").pop()?.startsWith("thumb_") && retainedAsset ? ownedThumbnailUrl(retainedAsset) : ""}} : response;
      await completeUploadIntent(callerUid, repo, path, intent, claim.attemptId, completedResponse, retainedAsset);
      return completedResponse;
    };
    if (claim.completedResponse) {
      if (ownedUpload && !claim.intent.retainedAsset) {
        const completed = await complete(claim.completedResponse);
        return withSourceKind(completed);
      }
      return withSourceKind(claim.completedResponse);
    }
    const attemptId = claim.attemptId;

    if (intent.sourceKind === "owned") {
      const result = {content: {path, sha: blobSha, download_url: ""}};
      try {
        const completed = await complete(result);
        return withSourceKind(completed);
      } catch (error) {
        await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs).catch(() => undefined);
        throw error;
      }
    }

    if (!claim.newlyClaimed) {
      try {
        const existing = await githubRequest(githubUrl(repo, path), {method: "GET"}, true);
        if (existing) {
          if (existing.sha !== blobSha) {
            await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs, true).catch(() => undefined);
            throw new HttpsError("already-exists", "File already exists.");
          }
          const recovered = {content: {path: existing.path, sha: existing.sha, download_url: existing.download_url}};
          await complete(recovered);
          return withSourceKind(recovered);
        }
        if (isWallSubmissionUpload(repo, path)) {
          intent = await reserveRetryWallSlot(callerUid, repo, path, attemptId, nowMs);
        }
      } catch (error) {
        await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs).catch(() => undefined);
        throw error;
      }
    }

    let result: Record<string, unknown>;
    try {
      result = await githubRequest(githubUrl(repo, path), {
        method: "PUT",
        body: JSON.stringify({message, content: contentBase64}),
      });
    } catch (error) {
      const status = githubHttpStatus(error);
      if (typeof status === "number" && status >= 400 && status < 500) {
        try {
          const existing = await githubRequest(githubUrl(repo, path), {method: "GET"}, true);
          if (existing?.sha === blobSha) {
            const recovered = {content: {path: existing.path, sha: existing.sha, download_url: existing.download_url}};
            await complete(recovered);
            return withSourceKind(recovered);
          }
          await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs, true);
        } catch {
          await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs).catch(() => undefined);
        }
      } else {
        await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs).catch(() => undefined);
      }
      throw error;
    }
    await complete(result).catch(async (error) => {
      await releaseUploadAttempt(repo, path, intent, attemptId, callerUid, nowMs).catch(() => undefined);
      throw error;
    });
    return withSourceKind(result);
  },
);

export const githubDeleteFile = onCall(
  {...CALLABLE_OPTIONS, secrets: [githubToken, ...r2Secrets], timeoutSeconds: 60},
  async (request: CallableRequest<GithubContentData>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to delete files.");
    const isAdmin = await isAdminCaller(request.auth);
    const data = request.data ?? {};
    const identityMode = data.wallId !== undefined || data.originalObjectId !== undefined || data.assetRole !== undefined;
    let manifestProof: ManifestDeleteProof | undefined;
    if (identityMode) {
      if ([data.repo, data.path, data.sha, data.message, data.sourceKind].some((value) => value !== undefined)) {
        throw new HttpsError("invalid-argument", "Wall identity and file identity cannot be combined.");
      }
      const wallId = requiredString(data.wallId, "wallId");
      const originalObjectId = requiredString(data.originalObjectId, "originalObjectId");
      if (!/^[A-Za-z0-9_-]{1,200}$/.test(wallId) || !/^[a-f0-9]{64}$/.test(originalObjectId) ||
        (data.assetRole !== "wallpaper" && data.assetRole !== "thumb")) {
        throw new HttpsError("invalid-argument", "Invalid wall cleanup identity.");
      }
      const assetRole = data.assetRole;
      manifestProof = await db.runTransaction((tx) => readManifestDeleteProof(tx, callerUid, isAdmin,
        {wallId, originalObjectId, assetRole}));
    }
    const resolvedAsset = manifestProof?.asset;
    const {repo, path, message} = validateCommon(resolvedAsset ? {
      repo: resolvedAsset.repo, path: resolvedAsset.path, message: resolvedAsset.path,
    } : data);
    const sha = requiredString(resolvedAsset?.sha ?? data.sha, "sha");
    if (sha.includes("/") || sha === "." || sha === "..") throw new HttpsError("invalid-argument", "Invalid SHA.");
    const requestedKind = resolvedAsset ? resolvedAsset.sourceKind === "owned" ? "owned" : "github" : data.sourceKind;
    if (requestedKind !== undefined && requestedKind !== "owned" && requestedKind !== "github") {
      throw new HttpsError("invalid-argument", "Invalid upload source kind.");
    }

    const uploadCollection = db.collection(UPLOADS);
    const ownedRef = uploadCollection.doc(uploadRecordId(repo, path, sha, "owned"));
    const ownedSnap = await ownedRef.get();
    const tombstone = (await db.collection(OWNED_DELETIONS).doc(uploadRecordId(repo, path, sha, "owned")).get()).data();
    let uploadRef = uploadCollection.doc(uploadRecordId(repo, path, sha));
    let uploadSnap = await uploadRef.get();
    if (!uploadSnap.exists) {
      uploadRef = uploadCollection.doc(sha);
      uploadSnap = await uploadRef.get();
    }
    const canDeleteOwned = ownedSnap.exists && canDeleteUpload(ownedSnap.data() as GithubUploadRecord, callerUid, repo, path, isAdmin);
    const canDeleteGithub = uploadSnap.exists && canDeleteUpload(uploadSnap.data() as GithubUploadRecord, callerUid, repo, path, isAdmin);
    if (manifestProof && !(requestedKind === "owned" ? ownedSnap.exists : uploadSnap.exists)) {
      if (isAdmin && manifestProof.asset?.uid === "legacy-migration") {
        const proof = manifestProof;
        await deleteRetainedUpload({...proof.asset!, expected: proof.asset!, authorize: async (tx) => {
          await readManifestDeleteProof(tx, callerUid, isAdmin, proof);
        }});
      }
      return {ok: true};
    }
    if (!ownedSnap.exists && requestedKind !== "github" && tombstone?.status === "deleted" && tombstone.sha === sha &&
      (tombstone.uid === callerUid || isAdmin)) {
      if (requestedKind === undefined && canDeleteGithub) {
        throw new HttpsError("failed-precondition", "Upload source is ambiguous. Select a source kind.");
      }
      return {ok: true};
    }
    if (requestedKind === undefined && canDeleteOwned && canDeleteGithub) {
      throw new HttpsError("failed-precondition", "Upload source is ambiguous. Select a source kind.");
    }
    if (requestedKind === "owned" || (requestedKind === undefined && canDeleteOwned)) {
      if (!ownedSnap.exists) throw new HttpsError("permission-denied", "You cannot delete this file.");
      uploadRef = ownedRef;
      uploadSnap = ownedSnap;
    }
    const record = uploadSnap.exists ? (uploadSnap.data() as GithubUploadRecord) : undefined;
    if (manifestProof && !sameStoredUpload(record?.retainedAsset, manifestProof.asset)) {
      throw new HttpsError("failed-precondition", "Retained upload no longer matches this wall.");
    }
    if (record?.sourceKind === "owned" && uploadRef.path !== ownedRef.path) {
      throw new HttpsError("failed-precondition", "Legacy original upload requires reconciliation before deletion.");
    }
    if (!canDeleteUpload(record, callerUid, repo, path, isAdmin)) {
      throw new HttpsError("permission-denied", "You cannot delete this file.");
    }
    if ((record?.sourceKind === "owned" || record?.retainedAsset !== undefined) && !stored(record?.retainedAsset)) {
      throw new HttpsError("failed-precondition", "Retained upload identity is unavailable.");
    }

    const deletion = await claimDeleteIntent(callerUid, repo, path, sha, uploadRef, record, isAdmin, Date.now(), manifestProof);
    const nowMs = Date.now();
    try {
      if (record?.sourceKind !== "owned") {
        await githubRequest(githubUrl(repo, path), {
          method: "DELETE",
          body: JSON.stringify({message, sha}),
        });
      }
    } catch (error) {
      const status = githubHttpStatus(error);
      if (status !== 404) {
        if (typeof status === "number" && status < 500) {
          await finishDeleteIntent(callerUid, repo, path, sha, uploadRef, isAdmin, deletion.attemptId,
            deletion.generation, nowMs, true, record?.sourceKind);
        }
        throw error;
      }
    }
    if (record?.sourceKind === "owned" || record?.retainedAsset !== undefined) {
      try {
        await deleteRetainedUpload({repo, path, sha, ...(record?.sourceKind === "owned" ? {sourceKind: "owned" as const} : {}),
          expected: record!.retainedAsset as StoredUpload});
      } catch (error) {
        // Keep ownership and the deleting state so a retry can finish cleanup after GitHub's 404.
        await db.runTransaction(async (tx) => {
          const ref = db.collection(UPLOAD_INTENTS).doc(uploadIntentId(repo, path, record?.sourceKind));
          const intent = (await tx.get(ref)).data();
          if (intent?.deleteAttemptId === deletion.attemptId) tx.update(ref, {deleteExpiresAt: 0});
        });
        throw error;
      }
    }
    await finishDeleteIntent(callerUid, repo, path, sha, uploadRef, isAdmin, deletion.attemptId,
      deletion.generation, nowMs, false, record?.sourceKind);
    return {ok: true};
  },
);
