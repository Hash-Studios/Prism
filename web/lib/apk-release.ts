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

type CachedRelease = { fetchedAt: number; release: ApkRelease };

const APK_NAME = /^prism-(\d+\.\d+\.\d+)-(\d+)\.apk$/;
const GITHUB_DOWNLOAD = /^https:\/\/github\.com\/Hash-Studios\/Prism\/releases\/download\//;

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function downloadUrl(value: unknown): string | null {
  return typeof value === "string" && GITHUB_DOWNLOAD.test(value) ? value : null;
}

/** The newest published release that carries a Prism APK, from the GitHub releases list. */
export function pickApkRelease(payload: unknown): ApkRelease | null {
  if (!Array.isArray(payload)) return null;
  for (const item of payload) {
    const release = record(item);
    if (!release || release.draft !== false || release.prerelease !== false || !Array.isArray(release.assets)) continue;
    const assets = release.assets.map(record).filter((a): a is Record<string, unknown> => a !== null);
    for (const asset of assets) {
      const match = typeof asset.name === "string" ? APK_NAME.exec(asset.name) : null;
      const url = downloadUrl(asset.browser_download_url);
      if (!match || !url || typeof asset.size !== "number" || asset.size <= 0) continue;
      const digest = typeof asset.digest === "string" ? /^sha256:([0-9a-f]{64})$/.exec(asset.digest) : null;
      const shaFile = assets.find((a) => a.name === `${asset.name}.sha256`);
      return {
        version: match[1],
        code: Number(match[2]),
        size: asset.size,
        url,
        sha256: digest ? digest[1] : null,
        shaFileUrl: shaFile ? downloadUrl(shaFile.browser_download_url) : null,
        releaseUrl: typeof release.html_url === "string" && release.html_url.startsWith(`${GITHUB_URL}/`)
          ? release.html_url
          : RELEASES_URL,
      };
    }
  }
  return null;
}

export function formatSize(bytes: number): string {
  return `${(bytes / 1048576).toFixed(1)} MB`;
}

function isApkRelease(value: unknown): value is ApkRelease {
  const r = record(value);
  return !!r && typeof r.version === "string" && typeof r.code === "number" && typeof r.size === "number"
    && downloadUrl(r.url) !== null && (r.sha256 === null || typeof r.sha256 === "string")
    && (r.shaFileUrl === null || downloadUrl(r.shaFileUrl) !== null) && typeof r.releaseUrl === "string";
}

export function readCache(): CachedRelease | null {
  try {
    const parsed = record(JSON.parse(localStorage.getItem(CACHE_KEY) ?? "null"));
    if (!parsed || typeof parsed.fetchedAt !== "number" || !isApkRelease(parsed.release)) return null;
    return { fetchedAt: parsed.fetchedAt, release: parsed.release };
  } catch {
    return null;
  }
}

export function writeCache(release: ApkRelease, now: number): void {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({ fetchedAt: now, release } satisfies CachedRelease));
  } catch {}
}

export async function fetchApkRelease(): Promise<ApkRelease | null> {
  const response = await fetch(RELEASES_API, { headers: { Accept: "application/vnd.github+json" } });
  if (!response.ok) throw new Error(`GitHub API answered ${response.status}`);
  return pickApkRelease(await response.json());
}
