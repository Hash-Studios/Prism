import {ImageAnnotatorClient} from "@google-cloud/vision";
import sharp from "sharp";
import {str} from "../common";

export const STUDIO_MIN_SHORT_EDGE = 1400;
export const STUDIO_MIN_LONG_EDGE = 3000;
/** Height / width. */
export const STUDIO_MIN_ASPECT = 2.0;
export const STUDIO_MAX_ASPECT = 2.4;
/** Two dHashes this close or closer are the same picture. */
export const STUDIO_DUPLICATE_MAX_DISTANCE = 6;
/** A safe search category at this likelihood or above rejects the image. */
export const STUDIO_SAFE_SEARCH_REJECT_AT = "POSSIBLE";
export const STUDIO_SAFE_SEARCH_CATEGORIES = ["adult", "racy", "violence", "medical"] as const;
/** A detected word with this many letters or digits rejects the image. */
export const STUDIO_TEXT_MIN_CHARS = 3;
export const STUDIO_LOGO_MIN_SCORE = 0.5;
/** Long edge of the copy sent to Vision. */
export const STUDIO_VISION_LONG_EDGE = 1600;

const LIKELIHOODS = ["UNKNOWN", "VERY_UNLIKELY", "UNLIKELY", "POSSIBLE", "LIKELY", "VERY_LIKELY"];
const HASH = /^[0-9a-f]{16}$/;
const LETTER_OR_DIGIT = new RegExp("[\\p{L}\\p{N}]", "gu");

export interface GateResult {
  passed: boolean;
  reasons: string[];
  details: Record<string, unknown>;
  /** dHash of the image, empty when it does not decode. */
  hash: string;
}

export interface KnownHash {
  hash: string;
  wallId: string;
}

type SafeSearch = Partial<Record<(typeof STUDIO_SAFE_SEARCH_CATEGORIES)[number], unknown>>;

/** The part of a Vision annotateImage response that the gates read. */
export interface VisionResult {
  safeSearchAnnotation?: SafeSearch | null;
  textAnnotations?: Array<{description?: string | null}> | null;
  logoAnnotations?: Array<{description?: string | null; score?: number | null}> | null;
}

/** Sends a JPEG to Vision. Throws when the call fails, so the candidate tries again. */
export type VisionAnnotate = (jpeg: Buffer) => Promise<VisionResult>;

/** Rank of a Vision likelihood that arrives as an enum name or number. Anything else is UNKNOWN (0). */
export function likelihoodRank(value: unknown): number {
  if (typeof value === "number") return Number.isInteger(value) && value >= 0 && value < LIKELIHOODS.length ? value : 0;
  return Math.max(0, LIKELIHOODS.indexOf(String(value)));
}

export function sizeCheck(width: number, height: number): {reasons: string[]; details: Record<string, unknown>} {
  const reasons: string[] = [];
  const aspect = height / width;
  if (height <= width) reasons.push("not_portrait");
  if (Math.min(width, height) < STUDIO_MIN_SHORT_EDGE || Math.max(width, height) < STUDIO_MIN_LONG_EDGE) {
    reasons.push("too_small");
  }
  if (!(aspect >= STUDIO_MIN_ASPECT && aspect <= STUDIO_MAX_ASPECT)) reasons.push("aspect");
  return {reasons, details: {width, height, aspect: Math.round(aspect * 1000) / 1000}};
}

/** 64-bit difference hash as 16 hex characters: each bit says whether a pixel is brighter than its right neighbour. */
export async function dHash(bytes: Buffer): Promise<string> {
  const {data, info} = await sharp(bytes).resize(9, 8, {fit: "fill"}).grayscale().raw()
    .toBuffer({resolveWithObject: true});
  let hex = "";
  for (let y = 0; y < 8; y++) {
    let row = 0;
    for (let x = 0; x < 8; x++) {
      const at = (y * 9 + x) * info.channels;
      row = (row << 1) | (data[at] > data[at + info.channels] ? 1 : 0);
    }
    hex += row.toString(16).padStart(2, "0");
  }
  return hex;
}

/** Bits that differ between two 16-character hex hashes. */
export function hammingDistance(a: string, b: string): number {
  if (!HASH.test(a) || !HASH.test(b)) throw new Error("hammingDistance: hashes must be 16 hex characters.");
  let distance = 0;
  for (let i = 0; i < a.length; i++) {
    let x = parseInt(a[i], 16) ^ parseInt(b[i], 16);
    for (; x > 0; x >>= 1) distance += x & 1;
  }
  return distance;
}

export function duplicateCheck(hash: string, known: KnownHash[]): {reasons: string[]; details: Record<string, unknown>} {
  let nearest: {distance: number; wallId: string} | null = null;
  for (const other of known) {
    if (!HASH.test(other.hash)) continue;
    const distance = hammingDistance(hash, other.hash);
    if (nearest === null || distance < nearest.distance) nearest = {distance, wallId: other.wallId};
  }
  return {
    reasons: nearest !== null && nearest.distance <= STUDIO_DUPLICATE_MAX_DISTANCE ? ["duplicate"] : [],
    details: {hash, nearestDistance: nearest?.distance ?? null, nearestWallId: nearest?.wallId ?? null},
  };
}

export function visionCheck(result: VisionResult): {reasons: string[]; details: Record<string, unknown>} {
  const reasons: string[] = [];
  const safe = result.safeSearchAnnotation;
  const safeSearch: Record<string, string> = {};
  if (!safe) {
    reasons.push("safe_search_missing");
  } else {
    const rejectAt = LIKELIHOODS.indexOf(STUDIO_SAFE_SEARCH_REJECT_AT);
    for (const category of STUDIO_SAFE_SEARCH_CATEGORIES) {
      const rank = likelihoodRank(safe[category]);
      safeSearch[category] = LIKELIHOODS[rank];
      if (rank >= rejectAt) reasons.push(`unsafe_${category}`);
    }
  }
  // The first text annotation is the whole block; the rest are single words.
  const words = (result.textAnnotations ?? []).slice(1).map((a) => str(a.description)).filter((w) => w !== "");
  if (words.some((w) => (w.match(LETTER_OR_DIGIT) ?? []).length >= STUDIO_TEXT_MIN_CHARS)) reasons.push("text");
  const logos = (result.logoAnnotations ?? []).map((l) => ({
    description: str(l.description),
    score: typeof l.score === "number" ? Math.round(l.score * 1000) / 1000 : 0,
  }));
  if (logos.some((l) => l.score >= STUDIO_LOGO_MIN_SCORE)) reasons.push("logo");
  return {reasons, details: {safeSearch, words: words.slice(0, 20), logos: logos.slice(0, 10)}};
}

let visionClient: ImageAnnotatorClient | undefined;

/** Safe search, text and logo detection in one Vision call. */
export const annotateWithVision: VisionAnnotate = async (jpeg) => {
  visionClient ??= new ImageAnnotatorClient();
  const [result] = await visionClient.annotateImage({
    image: {content: jpeg},
    features: [{type: "SAFE_SEARCH_DETECTION"}, {type: "TEXT_DETECTION"}, {type: "LOGO_DETECTION", maxResults: 5}],
  });
  if (result.error?.code) throw new Error(`Vision error ${result.error.code}: ${result.error.message ?? ""}`);
  return result;
};

/**
 * Size, duplicate and Vision checks of one generated image. Every check runs, so the details hold all values for
 * calibration. An image that does not decode is rejected with "undecodable". Vision and hash lookup errors throw.
 */
export async function runGates(
  bytes: Buffer,
  deps: {annotate: VisionAnnotate; knownHashes: () => Promise<KnownHash[]>},
): Promise<GateResult> {
  let width = 0;
  let height = 0;
  let hash = "";
  try {
    const meta = await sharp(bytes).metadata();
    width = meta.width ?? 0;
    height = meta.height ?? 0;
    hash = await dHash(bytes);
  } catch {
    // The reasons below say it.
  }
  if (!width || !height || hash === "") return {passed: false, reasons: ["undecodable"], details: {}, hash: ""};

  const size = sizeCheck(width, height);
  const duplicate = duplicateCheck(hash, await deps.knownHashes());
  const visionJpeg = await sharp(bytes)
    .resize({width: STUDIO_VISION_LONG_EDGE, height: STUDIO_VISION_LONG_EDGE, fit: "inside", withoutEnlargement: true})
    .jpeg({quality: 85})
    .toBuffer();
  const vision = visionCheck(await deps.annotate(visionJpeg));
  const reasons = [...size.reasons, ...duplicate.reasons, ...vision.reasons];
  return {
    passed: reasons.length === 0,
    reasons,
    details: {size: size.details, duplicate: duplicate.details, vision: vision.details},
    hash,
  };
}
