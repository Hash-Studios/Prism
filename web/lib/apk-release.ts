import { GITHUB_URL } from "@/lib/site-config";

export const RELEASES_API = "https://api.github.com/repos/Hash-Studios/Prism/releases?per_page=10";
export const RELEASES_URL = `${GITHUB_URL}/releases`;
export const LATEST_RELEASE_URL = `${GITHUB_URL}/releases/latest`;
export const CACHE_KEY = "prism.apkRelease.v1";
// GitHub allows 60 unauthenticated API requests an hour per IP. One per browser per hour stays far below it.
export const CACHE_TTL_MS = 60 * 60 * 1000;

export type ApkRelease = {
  version: string;
  code: number;
  size: number;
  url: string;
  sha256: string | null;
  shaFileUrl: string | null;
  releaseUrl: string;
};

export type CachedRelease = {
  fetchedAt: number;
  status: "ready" | "missing" | "failed";
  release: ApkRelease | null;
};

const APK_NAME = /^prism-(\d+\.\d+\.\d+)-(\d+)\.apk$/;
const SHA256 = /^[0-9a-f]{64}$/;

function record(value: unknown): Record<string, unknown> | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  return Object.fromEntries(Object.entries(value));
}

function githubPath(value: unknown, allowed: "download" | "release" | "releases"): string | null {
  if (typeof value !== "string" || /[\u0000-\u0020\\]/.test(value)) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.hostname !== "github.com" || url.port || url.username || url.password
      || url.search || url.hash || url.origin !== "https://github.com") return null;
    const segments = url.pathname.split("/");
    if (segments[1] !== "Hash-Studios" || segments[2] !== "Prism" || segments[3] !== "releases") return null;
    if (allowed === "releases") return segments.length === 4 && url.pathname === "/Hash-Studios/Prism/releases" ? value : null;
    if (allowed === "release") {
      return segments.length === 6 && segments[4] === "tag" && validPathSegment(segments[5]) ? value : null;
    }
    return segments.length === 7 && segments[4] === "download" && validPathSegment(segments[5])
      && validPathSegment(segments[6]) ? value : null;
  } catch {
    return null;
  }
}

function validPathSegment(value: string): boolean {
  if (!value || value === "." || value === ".." || /%2f|%5c/i.test(value)) return false;
  try {
    const decoded = decodeURIComponent(value);
    return decoded !== "." && decoded !== ".." && !/[\\/\u0000-\u001f\u007f]/.test(decoded);
  } catch {
    return false;
  }
}

function downloadUrl(value: unknown): string | null {
  return githubPath(value, "download");
}

function releaseUrl(value: unknown): string | null {
  return githubPath(value, "release") ?? githubPath(value, "releases");
}

/** The newest published release that carries a Prism APK, from the GitHub releases list. */
export function pickApkRelease(payload: unknown): ApkRelease | null {
  if (!Array.isArray(payload)) return null;
  for (const item of payload) {
    const release = record(item);
    if (!release || release.draft !== false || release.prerelease !== false || !Array.isArray(release.assets)) continue;
    const assets = release.assets.map(record).filter((asset): asset is Record<string, unknown> => asset !== null);
    for (const asset of assets) {
      const match = typeof asset.name === "string" ? APK_NAME.exec(asset.name) : null;
      const url = downloadUrl(asset.browser_download_url);
      if (!match || !url || typeof asset.size !== "number" || !Number.isSafeInteger(asset.size) || asset.size <= 0) continue;
      const code = Number(match[2]);
      if (!Number.isSafeInteger(code) || code <= 0) continue;
      const digest = typeof asset.digest === "string" ? /^sha256:([0-9a-f]{64})$/.exec(asset.digest) : null;
      const shaFile = assets.find((candidate) => candidate.name === `${asset.name}.sha256`);
      return {
        version: match[1],
        code,
        size: asset.size,
        url,
        sha256: digest ? digest[1] : null,
        shaFileUrl: shaFile ? downloadUrl(shaFile.browser_download_url) : null,
        releaseUrl: releaseUrl(release.html_url) ?? RELEASES_URL,
      };
    }
  }
  return null;
}

export function formatSize(bytes: number): string {
  return `${(bytes / 1048576).toFixed(1)} MB`;
}

function isApkRelease(value: unknown): value is ApkRelease {
  const candidate = record(value);
  return candidate !== null
    && typeof candidate.version === "string" && /^\d+\.\d+\.\d+$/.test(candidate.version)
    && typeof candidate.code === "number" && Number.isSafeInteger(candidate.code) && candidate.code > 0
    && typeof candidate.size === "number" && Number.isSafeInteger(candidate.size) && candidate.size > 0
    && downloadUrl(candidate.url) !== null
    && (candidate.sha256 === null || (typeof candidate.sha256 === "string" && SHA256.test(candidate.sha256)))
    && (candidate.shaFileUrl === null || downloadUrl(candidate.shaFileUrl) !== null)
    && typeof candidate.releaseUrl === "string" && releaseUrl(candidate.releaseUrl) !== null;
}

function parseCache(value: unknown): CachedRelease | null {
  const cached = record(value);
  if (!cached || typeof cached.fetchedAt !== "number" || !Number.isFinite(cached.fetchedAt)
    || cached.fetchedAt <= 0) return null;
  if (cached.status === "ready") {
    return isApkRelease(cached.release)
      ? { fetchedAt: cached.fetchedAt, status: "ready", release: cached.release }
      : null;
  }
  if (cached.status === "missing") {
    return cached.release === null ? { fetchedAt: cached.fetchedAt, status: "missing", release: null } : null;
  }
  if (cached.status === "failed") {
    return cached.release === null || isApkRelease(cached.release)
      ? { fetchedAt: cached.fetchedAt, status: "failed", release: cached.release }
      : null;
  }
  return null;
}

export function readCache(): CachedRelease | null {
  try {
    return parseCache(JSON.parse(localStorage.getItem(CACHE_KEY) ?? "null"));
  } catch {
    return null;
  }
}

function writeCache(entry: CachedRelease): void {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(entry));
  } catch {}
}

function fresh(entry: CachedRelease, now: number): boolean {
  return entry.fetchedAt <= now && now - entry.fetchedAt < CACHE_TTL_MS;
}

async function refresh(): Promise<CachedRelease> {
  const cached = readCache();
  const now = Date.now();
  if (cached && fresh(cached, now)) return cached;

  // Saved before the request, so a failed or interrupted request still uses up this browser's hour.
  const attempt: CachedRelease = { fetchedAt: now, status: "failed", release: cached?.release ?? null };
  writeCache(attempt);
  try {
    const response = await fetch(RELEASES_API, { headers: { Accept: "application/vnd.github+json" } });
    if (!response.ok) return attempt;
    const release = pickApkRelease(await response.json());
    const result: CachedRelease = { fetchedAt: now, status: release ? "ready" : "missing", release };
    writeCache(result);
    return result;
  } catch {
    return attempt;
  }
}

let pageLoad: Promise<CachedRelease> | null = null;

/** At most one GitHub request per browser per hour. Without storage, at most one per page load. */
export function getApkRelease(): Promise<CachedRelease> {
  pageLoad ??= refresh();
  return pageLoad;
}
