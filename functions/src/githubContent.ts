import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";

const REGION = "asia-south1";
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

function validateData(data: GithubContentData, requireSha: boolean): {repo: string; path: string; message: string; contentBase64?: string; sha?: string} {
  const repo = requiredString(data.repo, "repo");
  const filePath = requiredString(data.path, "path");
  const message = requiredString(data.message, "message");
  if (!isAllowedRepo(repo)) throw new HttpsError("permission-denied", "Repository is not allowed.");
  if (!isValidGithubPath(filePath)) throw new HttpsError("invalid-argument", "Invalid file path.");

  const sha = data.sha == null ? undefined : requiredString(data.sha, "sha");
  if (requireSha && !sha) throw new HttpsError("invalid-argument", "sha is required.");
  if (requireSha) return {repo, path: filePath, message, sha};

  const contentBase64 = requiredString(data.contentBase64, "contentBase64");
  return {repo, path: filePath, message, contentBase64, sha};
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
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to upload files.");
    const data = validateData(request.data ?? {}, false);
    return githubRequest(githubUrl(data.repo, data.path), {
      method: "PUT",
      body: JSON.stringify({message: data.message, content: data.contentBase64, ...(data.sha ? {sha: data.sha} : {})}),
    });
  },
);

export const githubDeleteFile = onCall(
  {region: REGION, cors: true, secrets: [githubToken]},
  async (request: CallableRequest<GithubContentData>) => {
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in to delete files.");
    const data = validateData(request.data ?? {}, true);
    await githubRequest(githubUrl(data.repo, data.path), {
      method: "DELETE",
      body: JSON.stringify({message: data.message, sha: data.sha}),
    });
    return {ok: true};
  },
);
