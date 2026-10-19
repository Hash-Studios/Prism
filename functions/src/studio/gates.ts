import type {ImageAnnotatorClient} from "@google-cloud/vision";
import {str} from "../common";
import type {WallDepth} from "../wallDepth";

export const STUDIO_MIN_SHORT_EDGE = 1400;
export const STUDIO_MIN_LONG_EDGE = 3000;
/** Height / width. */
export const STUDIO_MIN_ASPECT = 2.0;
export const STUDIO_MAX_ASPECT = 2.4;
/** An image at least this similar to a Studio wall (correlation of the grey thumbnails) is a duplicate. */
export const STUDIO_DUPLICATE_MIN_SIMILARITY = 0.93;
/** The grey thumbnail behind a signature. 16x36 keeps the shape of a 1440x3200 wallpaper. */
export const STUDIO_SIGNATURE_WIDTH = 16;
export const STUDIO_SIGNATURE_HEIGHT = 36;
/** A safe search category at this likelihood or above rejects the image. */
export const STUDIO_SAFE_SEARCH_REJECT_AT = "POSSIBLE";
export const STUDIO_SAFE_SEARCH_CATEGORIES = ["adult", "racy", "violence", "medical"] as const;
/** A detected word with this many letters or digits rejects the image. */
export const STUDIO_TEXT_MIN_CHARS = 3;
export const STUDIO_LOGO_MIN_SCORE = 0.5;
/** Long edge of the copy sent to Vision. */
export const STUDIO_VISION_LONG_EDGE = 1600;

const LIKELIHOODS = ["UNKNOWN", "VERY_UNLIKELY", "UNLIKELY", "POSSIBLE", "LIKELY", "VERY_LIKELY"];
const SIGNATURE_BYTES = STUDIO_SIGNATURE_WIDTH * STUDIO_SIGNATURE_HEIGHT;
const SIGNATURE_BASE64_LENGTH = Math.ceil(SIGNATURE_BYTES / 3) * 4;
const LETTER_OR_DIGIT = new RegExp("[\\p{L}\\p{N}]", "gu");

export interface GateResult {
  passed: boolean;
  reasons: string[];
  details: Record<string, unknown>;
  /** Signature of the image, empty when it does not decode. */
  signature: string;
  /** The Depth Effect result when the series asked for a depth check and it gave one. */
  depth?: WallDepth;
}

export interface KnownSignature {
  signature: string;
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

/** The Depth Effect check of a JPEG. Throws when the check cannot run, so the candidate tries again. */
export type DepthCheck = (jpeg: Buffer) => Promise<WallDepth>;

/** Rank of a Vision likelihood that arrives as an enum name or number. Anything else is UNKNOWN (0). */
export function likelihoodRank(value: unknown): number {
  if (typeof value === "number") return Number.isInteger(value) && value >= 0 && value < LIKELIHOODS.length ? value : 0;
  return Math.max(0, LIKELIHOODS.indexOf(String(value)));
}

function decodeSignature(signature: string): Buffer | null {
  if (!new RegExp(`^[A-Za-z0-9+/]{${SIGNATURE_BASE64_LENGTH}}$`).test(signature)) return null;
  const bytes = Buffer.from(signature, "base64");
  return bytes.length === SIGNATURE_BYTES && bytes.toString("base64") === signature ? bytes : null;
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

/**
 * The signature of an image: a 16x36 grey thumbnail as base64. A 64-bit dHash called different AMOLED walls the same,
 * because their black areas give the same bits. Correlation of thumbnails looks only at how the image varies.
 */
export async function imageSignature(bytes: Buffer): Promise<string> {
  const sharp = (await import("sharp")).default;
  const {data, info} = await sharp(bytes).flatten().resize(STUDIO_SIGNATURE_WIDTH, STUDIO_SIGNATURE_HEIGHT, {fit: "fill"})
    .grayscale().raw().toBuffer({resolveWithObject: true});
  const grey = Buffer.alloc(SIGNATURE_BYTES);
  for (let i = 0; i < SIGNATURE_BYTES; i++) grey[i] = data[i * info.channels];
  return grey.toString("base64");
}

/** Pearson correlation of two signatures, from -1 to 1. Equal flat signatures score 1; other flat pairs score 0. */
export function signatureSimilarity(a: string, b: string): number {
  const x = decodeSignature(a);
  const y = decodeSignature(b);
  if (x === null || y === null) return 0;
  const meanX = x.reduce((sum, v) => sum + v, 0) / SIGNATURE_BYTES;
  const meanY = y.reduce((sum, v) => sum + v, 0) / SIGNATURE_BYTES;
  let cov = 0;
  let varX = 0;
  let varY = 0;
  for (let i = 0; i < SIGNATURE_BYTES; i++) {
    const dx = x[i] - meanX;
    const dy = y[i] - meanY;
    cov += dx * dy;
    varX += dx * dx;
    varY += dy * dy;
  }
  return varX === 0 || varY === 0 ? (x.equals(y) ? 1 : 0) : cov / Math.sqrt(varX * varY);
}

export function duplicateCheck(
  signature: string, known: KnownSignature[],
): {reasons: string[]; details: Record<string, unknown>} {
  if (decodeSignature(signature) === null) {
    return {reasons: ["invalid_signature"], details: {nearestSimilarity: null, nearestWallId: null}};
  }
  let nearest: {similarity: number; wallId: string} | null = null;
  let invalidKnownSignatures = 0;
  for (const other of known) {
    if (decodeSignature(other.signature) === null) {
      invalidKnownSignatures++;
      continue;
    }
    const similarity = signatureSimilarity(signature, other.signature);
    if (nearest === null || similarity > nearest.similarity) nearest = {similarity, wallId: other.wallId};
  }
  const reasons = [];
  if (invalidKnownSignatures > 0) reasons.push("invalid_known_signature");
  if (nearest !== null && nearest.similarity >= STUDIO_DUPLICATE_MIN_SIMILARITY) reasons.push("duplicate");
  return {
    reasons,
    details: {
      nearestSimilarity: nearest === null ? null : Math.round(nearest.similarity * 1000) / 1000,
      nearestWallId: nearest?.wallId ?? null,
      ...(invalidKnownSignatures > 0 ? {invalidKnownSignatures} : {}),
    },
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
      if (rank === 0) reasons.push(`safe_search_unknown_${category}`);
      else if (rank >= rejectAt) reasons.push(`unsafe_${category}`);
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

export function depthCheck(depth: WallDepth): {reasons: string[]; details: Record<string, unknown>} {
  return {
    reasons: depth.tier === "none" ? ["depth"] : [],
    details: {tier: depth.tier, kind: depth.kind, top: depth.top},
  };
}

let visionClient: ImageAnnotatorClient | undefined;

/** Safe search, text and logo detection in one Vision call. */
export const annotateWithVision: VisionAnnotate = async (jpeg) => {
  const {ImageAnnotatorClient} = await import("@google-cloud/vision");
  visionClient ??= new ImageAnnotatorClient();
  const [result] = await visionClient.annotateImage({
    image: {content: jpeg},
    features: [{type: "SAFE_SEARCH_DETECTION"}, {type: "TEXT_DETECTION"}, {type: "LOGO_DETECTION", maxResults: 5}],
  });
  if (result.error?.code) throw new Error(`Vision error ${result.error.code}: ${result.error.message ?? ""}`);
  return result;
};

/**
 * Size, duplicate and Vision checks of one generated image, and the Depth Effect check when `depth` is given. Every
 * check runs, so the details hold all values for calibration. An image that does not decode is rejected with
 * "undecodable". Vision and signature lookup errors throw.
 */
export async function runGates(
  bytes: Buffer,
  deps: {annotate: VisionAnnotate; knownSignatures: () => Promise<KnownSignature[]>; depth?: DepthCheck},
): Promise<GateResult> {
  const sharp = (await import("sharp")).default;
  let width = 0;
  let height = 0;
  let signature = "";
  try {
    const meta = await sharp(bytes).metadata();
    width = meta.width ?? 0;
    height = meta.height ?? 0;
    signature = await imageSignature(bytes);
  } catch {
    // The reasons below say it.
  }
  if (!width || !height || signature === "") {
    return {passed: false, reasons: ["undecodable"], details: {}, signature: ""};
  }

  const size = sizeCheck(width, height);
  const duplicate = duplicateCheck(signature, await deps.knownSignatures());
  const visionJpeg = await sharp(bytes)
    .resize({width: STUDIO_VISION_LONG_EDGE, height: STUDIO_VISION_LONG_EDGE, fit: "inside", withoutEnlargement: true})
    .jpeg({quality: 85})
    .toBuffer();
  const [annotation, depthResult] = await Promise.all([deps.annotate(visionJpeg), deps.depth?.(visionJpeg)]);
  const vision = visionCheck(annotation);
  const depth = depthResult ? depthCheck(depthResult) : undefined;
  const reasons = [...size.reasons, ...duplicate.reasons, ...vision.reasons, ...(depth?.reasons ?? [])];
  return {
    passed: reasons.length === 0,
    reasons,
    details: {size: size.details, duplicate: duplicate.details, vision: vision.details,
      ...(depth ? {depth: depth.details} : {})},
    signature,
    ...(depthResult ? {depth: depthResult} : {}),
  };
}
