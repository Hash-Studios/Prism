import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {db, REGION} from "./common";

const UPLOADS = "githubUploads";
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
  {region: REGION, cors: true, secrets: [githubToken]},
  async (request: CallableRequest<GithubContentData>) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in to upload files.");
    const rawSha = request.data?.sha;
    if (rawSha != null) throw new HttpsError("invalid-argument", "Overwrites are not allowed.");
    const {repo, path, message} = validateCommon(request.data ?? {});
    const contentBase64 = requiredString(request.data?.contentBase64, "contentBase64");

    const result = await githubRequest(githubUrl(repo, path), {
      method: "PUT",
      body: JSON.stringify({message, content: contentBase64}),
    });

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
  {region: REGION, cors: true, secrets: [githubToken]},
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
    return {ok: true};
  },
);
