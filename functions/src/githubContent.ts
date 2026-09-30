import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, readDailyCount, REGION, utcDateString} from "./common";

const UPLOADS = "githubUploads";
const UPLOAD_STATS = "githubUploadStats";
const ALLOWED_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".webp"]);
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;
const MAX_UPLOADS_PER_DAY = 30;
// Mirrors UploadQuota.freeUploadsPerWeek in lib/core/purchases/upload_quota.dart.
const FREE_WALLS_PER_WEEK = 3;
// A wall submission always uploads a "thumb_" preview next to the file. Profile photos never do.
const WALL_THUMB_PREFIX = "thumb_";
const CALLABLE_OPTIONS = {region: REGION, cors: true, maxInstances: 10};
const githubToken = defineSecret("GH_TOKEN");

type GithubContentData = {
  repo?: unknown;
  path?: unknown;
  contentBase64?: unknown;
  message?: unknown;
  sha?: unknown;
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

export function hasAllowedImageExtension(filePath: string): boolean {
  const name = filePath.split("/").pop() ?? "";
  const dot = name.lastIndexOf(".");
  return dot > 0 && ALLOWED_EXTENSIONS.has(name.slice(dot).toLowerCase());
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

/** Gives back a slot taken by [reserveUploadSlot] when the upload did not happen or was removed. */
export async function releaseUploadSlot(callerUid: string, weekly: boolean, nowMs: number): Promise<void> {
  const week = weekStartUtc(nowMs);
  await db.runTransaction(async (tx) => {
    const ref = db.collection(UPLOAD_STATS).doc(callerUid);
    const snap = await tx.get(ref);
    const stats = snap.data();
    if (!stats || stats.week !== week || typeof stats.weekCount !== "number") return;
    if (weekly && stats.weekCount > 0) tx.update(ref, {weekCount: stats.weekCount - 1});
  });
}

function requiredString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${name} is required.`);
  }
  return value.trim();
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
  uid?: unknown;
  repo?: unknown;
  path?: unknown;
}

/** True when `record` (a githubUploads/{sha} doc) proves `callerUid` owns this repo+path, or the caller is an admin. */
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

async function githubRequest(url: string, init: RequestInit): Promise<Record<string, unknown>> {
  try {
    const response = await fetch(url, {
      ...init,
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": `Bearer ${githubToken.value()}`,
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        ...init.headers,
      },
    });
    const body = await response.json() as Record<string, unknown>;
    if (!response.ok) {
      throw new HttpsError("internal", `GitHub request failed (${response.status}).`);
    }
    return body;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "GitHub request failed.");
  }
}

export const githubPutFile = onCall(
  {...CALLABLE_OPTIONS, secrets: [githubToken]},
  async (request: CallableRequest<GithubContentData>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to upload files.");
    const rawSha = request.data?.sha;
    if (rawSha != null) throw new HttpsError("invalid-argument", "Overwrites are not allowed.");
    const {repo, path, message} = validateCommon(request.data ?? {});
    const contentBase64 = requiredString(request.data?.contentBase64, "contentBase64");
    if (!hasAllowedImageExtension(path)) throw new HttpsError("invalid-argument", "Only jpg, png and webp files are allowed.");
    if (base64DecodedBytes(contentBase64) > MAX_UPLOAD_BYTES) throw new HttpsError("invalid-argument", "File is too large.");

    const nowMs = Date.now();
    const weekly = await reserveUploadSlot(callerUid, isWallSubmissionUpload(repo, path), nowMs);
    let result: Record<string, unknown>;
    try {
      result = await githubRequest(githubUrl(repo, path), {
        method: "PUT",
        body: JSON.stringify({message, content: contentBase64}),
      });
    } catch (error) {
      await releaseUploadSlot(callerUid, weekly, nowMs).catch(() => undefined);
      throw error;
    }

    const contentSha = (result.content as Record<string, unknown> | undefined)?.sha;
    if (typeof contentSha === "string" && contentSha) {
      await db.collection(UPLOADS).doc(contentSha).set({
        uid: callerUid,
        repo,
        path,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return result;
  },
);

export const githubDeleteFile = onCall(
  {...CALLABLE_OPTIONS, secrets: [githubToken]},
  async (request: CallableRequest<GithubContentData>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to delete files.");
    const {repo, path, message} = validateCommon(request.data ?? {});
    const sha = requiredString(request.data?.sha, "sha");
    const isAdmin = request.auth?.token?.admin === true;

    const uploadRef = db.collection(UPLOADS).doc(sha);
    const uploadSnap = await uploadRef.get();
    const record = uploadSnap.exists ? (uploadSnap.data() as GithubUploadRecord) : undefined;
    if (!canDeleteUpload(record, callerUid, repo, path, isAdmin)) {
      throw new HttpsError("permission-denied", "You cannot delete this file.");
    }

    await githubRequest(githubUrl(repo, path), {
      method: "DELETE",
      body: JSON.stringify({message, sha}),
    });
    await uploadRef.delete();
    if (!isAdmin && record && isWallSubmissionUpload(repo, path)) {
      await releaseUploadSlot(callerUid, true, Date.now()).catch(() => undefined);
    }
    return {ok: true};
  },
);
