import type {ImageAnnotatorClient} from "@google-cloud/vision";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {checkedImageUrl} from "./wallColors";

export const DEPTH_VERSION = 1;
export type DepthTier = "auto" | "menu" | "none";
export type DepthKind = "person" | "pet" | "sky";
export interface WallDepth {
  tier: DepthTier;
  /** Subject class the detector matched, in iOS order person > pet > sky. Null when none matched. */
  kind: DepthKind | null;
  /** Mean mask value over the top 75% of the clock box, 3 decimals. Null when no mask was made. */
  top: number | null;
  v: number;
  by: "detector" | "admin";
}

export const falKey = defineSecret("FAL_KEY");

/** iPhone 15 Pro lock screen in points. The wall is an aspect-fill centre crop to this shape. */
const DEPTH_SCREEN = {width: 393, height: 852};
const DEPTH_CLOCK = {left: 27.5, right: 365.5, top: 190, bottom: 260};
/** iOS limits the mask only over this top share of the clock box. The band below it can be full. */
const CLOCK_TOP_SHARE = 0.75;
const CLOCK_WIDTH = DEPTH_CLOCK.right - DEPTH_CLOCK.left;
const CLOCK_HEIGHT = DEPTH_CLOCK.bottom - DEPTH_CLOCK.top;
/** Highest top coverage at which iOS turns the Depth Effect on by itself. */
export const DEPTH_T_AUTO = 0.2 * CLOCK_HEIGHT / CLOCK_WIDTH;
/** Highest top coverage at which the user can turn it on in the menu. */
export const DEPTH_T_MENU = DEPTH_T_AUTO + 0.25 * (1 - DEPTH_T_AUTO);
const SUBJECT_LEVEL = Math.round(0.6 * 255);
const MIN_SUBJECT_SHARE = 0.02;
const MIN_CLOCK_TOUCH = 0.002;

const DEPTH_MIN_OBJECT_SCORE = 0.5;
const DEPTH_MIN_LABEL_SCORE = 0.7;
/** In iOS order: the first kind that matches wins. */
const KIND_RULES: ReadonlyArray<{kind: DepthKind; objects: readonly string[]; labels: readonly string[]}> = [
  {kind: "person", objects: ["person", "man", "woman", "boy", "girl", "baby", "toddler"], labels: []},
  {kind: "pet", objects: ["dog", "cat"], labels: ["dog", "cat"]},
  {kind: "sky", objects: [], labels: ["sky", "cloud", "horizon", "skyline"]},
];

const FAL_BIREFNET_URL = "https://fal.run/fal-ai/birefnet";
const FAL_TIMEOUT_MS = 60_000;
const DATA_URI = /^data:[\w.+/-]*;base64,([A-Za-z0-9+/]+={0,2})$/;

/** The part of a Vision annotateImage response that depthKindFrom reads. */
export interface DepthVision {
  labelAnnotations?: Array<{description?: string | null; score?: number | null}> | null;
  localizedObjectAnnotations?: Array<{name?: string | null; score?: number | null}> | null;
}

export type DepthImage = {url: string} | {jpeg: Buffer};
/** Labels and objects of an image. Throws when the call fails. */
export type DepthAnnotate = (image: DepthImage) => Promise<DepthVision>;
export type DepthFetch = (url: string, init: RequestInit) => Promise<Response>;

export interface WallDepthDeps {
  annotate: DepthAnnotate;
  fetch: DepthFetch;
  /** Read at call time, because a secret has a value only while the function runs. */
  key: () => string;
}

function namesAtLeast(items: Array<{name?: string | null; score?: number | null}>, minScore: number): string[] {
  return items.filter((item) => typeof item.score === "number" && item.score >= minScore)
    .map((item) => (item.name ?? "").toLowerCase());
}

/** The subject class iOS would segment, or null when the image has no person, pet or sky. */
export function depthKindFrom(vision: DepthVision): DepthKind | null {
  const objects = namesAtLeast(vision.localizedObjectAnnotations ?? [], DEPTH_MIN_OBJECT_SCORE);
  const labels = namesAtLeast((vision.labelAnnotations ?? []).map((l) => ({name: l.description, score: l.score})),
    DEPTH_MIN_LABEL_SCORE);
  const rule = KIND_RULES.find((r) => r.objects.some((n) => objects.includes(n)) || r.labels.some((n) => labels.includes(n)));
  return rule?.kind ?? null;
}

/** Pixel rows or columns whose centres fall in [from, to). */
function pixelSpan(from: number, to: number): [number, number] {
  return [Math.ceil(from - 0.5), Math.ceil(to - 0.5)];
}

/** The tier of a mask that is already DEPTH_SCREEN sized, one 8-bit grey value per pixel. */
export function depthFromMaskPixels(pixels: Uint8Array, kind: DepthKind | null): WallDepth {
  const {width, height} = DEPTH_SCREEN;
  if (pixels.length !== width * height) throw new Error(`mask must be ${width}x${height}`);
  let subject = 0;
  for (const value of pixels) {
    if (value >= SUBJECT_LEVEL) subject++;
  }
  const [x0, x1] = pixelSpan(DEPTH_CLOCK.left, DEPTH_CLOCK.right);
  const [y0, y1] = pixelSpan(DEPTH_CLOCK.top, DEPTH_CLOCK.bottom);
  const [, yTop] = pixelSpan(DEPTH_CLOCK.top, DEPTH_CLOCK.top + CLOCK_TOP_SHARE * CLOCK_HEIGHT);
  const meanDownTo = (rowEnd: number): number => {
    let sum = 0;
    for (let y = y0; y < rowEnd; y++) {
      for (let x = x0; x < x1; x++) sum += pixels[y * width + x];
    }
    return sum / ((rowEnd - y0) * (x1 - x0) * 255);
  };
  const top = meanDownTo(yTop);
  let tier: DepthTier = "none";
  if (kind !== null && subject / pixels.length > MIN_SUBJECT_SHARE && meanDownTo(y1) > MIN_CLOCK_TOUCH) {
    if (top <= DEPTH_T_AUTO) tier = "auto";
    else if (top <= DEPTH_T_MENU) tier = "menu";
  }
  return {tier, kind, top: Math.round(top * 1000) / 1000, v: DEPTH_VERSION, by: "detector"};
}

/** The mask as iOS would place it: aspect-fill centre crop to DEPTH_SCREEN, one grey byte per pixel. */
export async function maskPixels(mask: Buffer): Promise<Uint8Array> {
  const sharp = (await import("sharp")).default;
  const {data} = await sharp(mask)
    .resize(DEPTH_SCREEN.width, DEPTH_SCREEN.height, {fit: "cover", position: "centre"})
    .flatten({background: "#000000"})
    .toColourspace("b-w")
    .raw()
    .toBuffer({resolveWithObject: true});
  return data;
}

/** Scores a mask image (PNG or WebP) for a subject of `kind`. Throws when sharp cannot decode it. */
export async function scoreDepth(mask: Buffer, kind: DepthKind | null): Promise<WallDepth> {
  return depthFromMaskPixels(await maskPixels(mask), kind);
}

let visionClient: ImageAnnotatorClient | undefined;

export const annotateForDepth: DepthAnnotate = async (image) => {
  const {ImageAnnotatorClient} = await import("@google-cloud/vision");
  visionClient ??= new ImageAnnotatorClient();
  const [result] = await visionClient.annotateImage({
    image: "url" in image ? {source: {imageUri: image.url}} : {content: image.jpeg},
    features: [{type: "LABEL_DETECTION", maxResults: 20}, {type: "OBJECT_LOCALIZATION", maxResults: 10}],
  });
  if (result.error?.code) throw new Error(`Vision error ${result.error.code}: ${result.error.message ?? ""}`);
  return result;
};

/** The BiRefNet subject mask of an image URL or data URI, decoded from the data URI that sync mode returns. */
async function falMask(imageUrl: string, key: string, fetchImpl: DepthFetch): Promise<Buffer> {
  if (key.trim() === "") throw new Error("FAL_KEY is empty");
  const response = await fetchImpl(FAL_BIREFNET_URL, {
    method: "POST",
    headers: {"Authorization": `Key ${key}`, "content-type": "application/json"},
    body: JSON.stringify({
      image_url: imageUrl,
      model: "General Use (Light)",
      operating_resolution: "1024x1024",
      output_mask: true,
      refine_foreground: false,
      sync_mode: true,
      output_format: "png",
    }),
    signal: AbortSignal.timeout(FAL_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`fal request failed with ${response.status}`);
  const body = (await response.json()) as {mask_image?: {url?: unknown}} | null;
  const url = body?.mask_image?.url;
  const match = typeof url === "string" ? DATA_URI.exec(url) : null;
  if (!match) throw new Error("fal mask is not a base64 data URI");
  return Buffer.from(match[1], "base64");
}

/**
 * The Depth Effect tier of a wall image: an allowed https URL, or JPEG bytes. Vision runs first, and an image with no
 * person, pet or sky gets tier "none" without a mask call. Never throws: a failure is logged and gives undefined, so
 * the wall keeps no `depth` field and a backfill can try again.
 */
export async function wallDepthFor(
  wallId: string,
  image: DepthImage,
  deps: WallDepthDeps = {annotate: annotateForDepth, fetch: (url, init) => fetch(url, init), key: () => falKey.value()},
): Promise<WallDepth | undefined> {
  try {
    const source: DepthImage = "url" in image ? {url: checkedImageUrl(image.url).href} : image;
    const kind = depthKindFrom(await deps.annotate(source));
    if (kind === null) return {tier: "none", kind: null, top: null, v: DEPTH_VERSION, by: "detector"};
    const imageUrl = "url" in source ? source.url : `data:image/jpeg;base64,${source.jpeg.toString("base64")}`;
    return await scoreDepth(await falMask(imageUrl, deps.key(), deps.fetch), kind);
  } catch (error) {
    logger.warn("wallDepth: could not check the Depth Effect", {
      wallId,
      error: error instanceof Error ? error.message : String(error),
    });
    return undefined;
  }
}
