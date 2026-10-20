import type * as admin from "firebase-admin";
import {STUDIO_ACCOUNT} from "./studio/account";
import {STUDIO_ASSET_BASE} from "./studio/assetSource";

/** Storage "repo" of user AI community walls: their source is the Worker image bucket, not a GitHub repository. */
export const AI_STORAGE_REPO = "prism-ai";
/** The reserved R2 owner of an AI wall whose server-owned generation record has expired. It claims no user. */
export const AI_LEGACY_UID = "ai-legacy-migration";
/** The Worker keeps `ai:gen:{id}` for 90 days. An absent record of a younger generation is not an expiry. */
export const AI_RECORD_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const RECORD_EXPIRY_MARGIN_MS = 24 * 60 * 60 * 1000;
const DEFAULT_WORKER_BASE = "https://prismwalls.com";
// The Worker makes ids as `gen_{Date.now() base 36}_{16 hex}` (createId in infra/cloudflare/worker/src/ai.ts).
const GENERATION_ID = /^gen_([a-z0-9]{6,10})_[a-f0-9]{16}$/;

/** A missing secret or a malformed record: a retry cannot fix it. */
export class AiRecordError extends Error {}

export type AiSource = {generationId: string; originalKey: string; thumbKey: string; originalUrl: string; thumbUrl: string};
export type AiGenerationRecord = {generationId: string; userId: string; width: number; height: number;
  imageUrl: string; watermarkedImageUrl: string};

/** Port of `aiCommunityId` in lib/features/ai_wallpaper/views/ai_wallpaper_helpers.dart. */
export function aiCommunityId(generationId: string): string {
  const sanitized = generationId.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
  return `AI${sanitized ? sanitized.slice(0, 10) : "GEN"}`;
}

/** The generation time that the Worker put in the id, in ms. */
export function generationTimeMs(generationId: string): number {
  const match = GENERATION_ID.exec(generationId);
  return match ? parseInt(match[1], 36) : NaN;
}

/** True when a Worker record made at the id's time has passed its TTL, with one day of margin. */
export function aiRecordExpired(generationId: string, nowMs = Date.now()): boolean {
  const madeAt = generationTimeMs(generationId);
  return Number.isFinite(madeAt) && nowMs - madeAt > AI_RECORD_TTL_MS + RECORD_EXPIRY_MARGIN_MS;
}

/**
 * The exact Worker URL pair of an unconverted user AI wall, or null. The thumb is the watermarked public image. The
 * original is the unwatermarked image or the same public image, as the wall recorded it. Both keys are written only by
 * the Worker generation path, and the wall id must be the id the app derives from the generation.
 */
export function parseAiSource(data: admin.firestore.DocumentData): AiSource | null {
  if (data.isAiGenerated !== true || data.origin === "studio" || data.email === STUDIO_ACCOUNT.email) return null;
  const generationId = data.aiGenerationId;
  if (typeof generationId !== "string" || !GENERATION_ID.test(generationId) || data.id !== aiCommunityId(generationId)) {
    return null;
  }
  const thumbKey = `ai/public/${generationId}.png`;
  const thumbUrl = `${STUDIO_ASSET_BASE}/${thumbKey}`;
  const originalKey = [`ai/original/${generationId}.png`, thumbKey]
    .find((key) => data.wallpaper_url === `${STUDIO_ASSET_BASE}/${key}`);
  if (!originalKey || data.wallpaper_thumb !== thumbUrl) return null;
  return {generationId, originalKey, thumbKey, originalUrl: `${STUDIO_ASSET_BASE}/${originalKey}`, thumbUrl};
}

/** The R2 upload id of each role. The original and thumb can share one Worker key, so the role keeps them apart. */
export const aiUploadId = (generationId: string, role: "original" | "thumb") =>
  role === "thumb" ? `thumb_${generationId}` : generationId;

/** True for the thumb role of an AI wall: the public image key and its role upload id. */
export function isAiPreview(path: string, uploadId: string | undefined): boolean {
  const match = /^ai\/public\/(gen_[a-z0-9_]+)\.png$/.exec(path);
  return !!match && uploadId === aiUploadId(match[1], "thumb");
}

/**
 * Reads the server-owned Worker record `ai:gen:{id}` through the secret Studio route. Returns null when the Worker
 * has no record (expired or never made). Throws `AiRecordError` for a missing secret or a bad record, and a plain error
 * when the Worker is unavailable.
 */
export async function readAiGenerationRecord(generationId: string): Promise<AiGenerationRecord | null> {
  const secret = process.env.STUDIO_SECRET ?? "";
  if (!secret) throw new AiRecordError("STUDIO_SECRET is required to read AI generation records");
  const base = (process.env.STUDIO_WORKER_BASE_URL ?? "").trim().replace(/\/+$/, "") || DEFAULT_WORKER_BASE;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(`${base}/api/ai/studio/generation-records/${encodeURIComponent(generationId)}`,
      {redirect: "manual", signal: controller.signal, headers: {"x-studio-secret": secret}});
    if (response.status === 404) return null;
    if (!response.ok) {
      const error = `AI generation record read failed: ${response.status}`;
      // A bad secret or a redirect is configuration; timeouts, rate limits and server failures can recover.
      throw response.status >= 300 && response.status < 500 && ![408, 429].includes(response.status) ?
        new AiRecordError(error) : new Error(error);
    }
    const record = await response.json() as Partial<AiGenerationRecord>;
    if (record.generationId !== generationId || typeof record.userId !== "string" ||
      !Number.isSafeInteger(record.width) || !Number.isSafeInteger(record.height) ||
      typeof record.imageUrl !== "string" || typeof record.watermarkedImageUrl !== "string") {
      throw new AiRecordError("AI generation record is invalid");
    }
    return record as AiGenerationRecord;
  } finally {
    clearTimeout(timer);
  }
}
