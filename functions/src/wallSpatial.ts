import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {checkedImageUrl} from "./wallColors";
import {type DepthImage, falKey} from "./wallDepth";
import {R2Storage, r2Env} from "./r2Storage";

export const SPATIAL_VERSION = 1;
export type SpatialTier = "great" | "ok" | "none";
export interface WallSpatial {
  tier: SpatialTier;
  /** Public R2 URL of a grey 8-bit depth PNG, 512 px on the long side. Bright is near. */
  map: string;
  v: number;
}

/** How clearly the depth map splits into a near part and a far part. */
export interface SpatialScore {
  /** Otsu's between-class variance over the total variance, 0 to 1. A flat gradient gives 0.75. */
  split: number;
  /** Mean brightness of the near part minus the far part, 0 to 1. */
  gap: number;
  /** Share of pixels in the near part, 0 to 1. */
  near: number;
}

export const SPATIAL_MAP_SIZE = 512;
export const SPATIAL_MAP_PREFIX = "spatial/v1";

// ponytail: first-guess thresholds from a 10-wall sample. Tune them against real iPhone Spatial Scene results.
const SPATIAL_TIERS: ReadonlyArray<{tier: Exclude<SpatialTier, "none">; split: number; gap: number; near: [number, number]}> = [
  {tier: "great", split: 0.85, gap: 0.4, near: [0.08, 0.65]},
  {tier: "ok", split: 0.78, gap: 0.28, near: [0.04, 0.8]},
];

const FAL_DEPTH_URL = "https://fal.run/fal-ai/image-preprocessors/depth-anything/v2";
const FAL_TIMEOUT_MS = 60_000;
const MAX_MAP_BYTES = 10 * 1024 * 1024;
const WALL_ID = /^[A-Za-z0-9_-]{1,200}$/;

export type SpatialFetch = (url: string, init: RequestInit) => Promise<Response>;
/** Saves a map PNG under `object` and returns its public URL. */
export type SpatialStore = (object: string, png: Buffer) => Promise<string>;

export interface WallSpatialDeps {
  fetch: SpatialFetch;
  /** Read at call time, because a secret has a value only while the function runs. */
  key: () => string;
  store: SpatialStore;
  /** R2 folder of the map. Tests and the proof run use their own. */
  prefix?: string;
}

/** Otsu split of 8-bit depth values, where bright is near. */
export function spatialScore(pixels: Uint8Array): SpatialScore {
  const total = pixels.length;
  if (total === 0) return {split: 0, gap: 0, near: 0};
  const histogram = new Array<number>(256).fill(0);
  for (const value of pixels) histogram[value]++;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * histogram[i];
  const mean = sum / total;
  let variance = 0;
  for (let i = 0; i < 256; i++) variance += histogram[i] * (i - mean) ** 2;
  variance /= total;
  if (variance === 0) return {split: 0, gap: 0, near: 0};

  let best = {between: -1, gap: 0, near: 0};
  let farCount = 0;
  let farSum = 0;
  for (let t = 0; t < 255; t++) {
    farCount += histogram[t];
    farSum += t * histogram[t];
    const nearCount = total - farCount;
    if (farCount === 0 || nearCount === 0) continue;
    const farMean = farSum / farCount;
    const nearMean = (sum - farSum) / nearCount;
    const between = farCount * nearCount * (nearMean - farMean) ** 2 / (total * total);
    if (between > best.between) best = {between, gap: (nearMean - farMean) / 255, near: nearCount / total};
  }
  const round = (value: number) => Math.round(value * 1000) / 1000;
  return {split: round(best.between / variance), gap: round(best.gap), near: round(best.near)};
}

export function spatialTierFor(score: SpatialScore): SpatialTier {
  const match = SPATIAL_TIERS.find((rule) => score.split >= rule.split && score.gap >= rule.gap &&
    score.near >= rule.near[0] && score.near <= rule.near[1]);
  return match?.tier ?? "none";
}

/** The map as stored (grey PNG, long side SPATIAL_MAP_SIZE, stretched to the full range) and its pixels. */
export async function spatialMap(depth: Buffer): Promise<{png: Buffer; pixels: Uint8Array}> {
  const sharp = (await import("sharp")).default;
  const grey = sharp(depth, {limitInputPixels: 40_000_000})
    .resize(SPATIAL_MAP_SIZE, SPATIAL_MAP_SIZE, {fit: "inside"})
    .flatten({background: "#000000"})
    .toColourspace("b-w")
    .normalise();
  const {data} = await grey.clone().raw().toBuffer({resolveWithObject: true});
  const png = await grey.png({compressionLevel: 9}).toBuffer();
  return {png, pixels: data};
}

/** The Depth Anything v2 map of an image URL or data URI. fal answers with a URL on its own CDN. */
async function falDepth(imageUrl: string, key: string, fetchImpl: SpatialFetch): Promise<Buffer> {
  if (key.trim() === "") throw new Error("FAL_API_KEY is empty");
  const signal = AbortSignal.timeout(FAL_TIMEOUT_MS);
  const response = await fetchImpl(FAL_DEPTH_URL, {
    method: "POST",
    headers: {"Authorization": `Key ${key}`, "content-type": "application/json"},
    body: JSON.stringify({image_url: imageUrl}),
    signal,
  });
  if (!response.ok) throw new Error(`fal request failed with ${response.status}`);
  const body = (await response.json()) as {image?: {url?: unknown}} | null;
  const mapUrl = typeof body?.image?.url === "string" ? new URL(body.image.url) : null;
  if (!mapUrl || mapUrl.protocol !== "https:" || !(mapUrl.hostname === "fal.media" ||
    mapUrl.hostname.endsWith(".fal.media"))) {
    throw new Error("fal depth map is not on fal.media");
  }
  const map = await fetchImpl(mapUrl.href, {signal, redirect: "error"});
  if (!map.ok) throw new Error(`fal depth map download failed with ${map.status}`);
  const bytes = Buffer.from(await map.arrayBuffer());
  if (bytes.length === 0 || bytes.length > MAX_MAP_BYTES) throw new Error("fal depth map size is invalid");
  return bytes;
}

/** Puts the map in the public R2 preview bucket, next to the wall previews. An existing object is kept. */
export const storeSpatialMap: SpatialStore = async (object, png) => {
  const base = r2Env("R2_PREVIEW_BASE_URL");
  if (!base) throw new Error("R2_PREVIEW_BASE_URL is not set");
  await new R2Storage().put("preview", object, png,
    {sha256: createHash("sha256").update(png).digest("hex")}, "image/png");
  return `${base.replace(/\/$/, "")}/${object}`;
};

/**
 * The Spatial Scene tier and depth map of a wall image: an allowed https URL, or JPEG bytes. Never throws: a failure
 * is logged and gives undefined, so the wall keeps no `spatial` field and a backfill can try again.
 */
export async function wallSpatialFor(
  wallId: string,
  image: DepthImage,
  deps: WallSpatialDeps = {fetch: (url, init) => fetch(url, init), key: () => falKey.value(), store: storeSpatialMap},
): Promise<WallSpatial | undefined> {
  try {
    if (!WALL_ID.test(wallId)) throw new Error("wall id is not valid");
    const imageUrl = "url" in image ? checkedImageUrl(image.url).href :
      `data:image/jpeg;base64,${image.jpeg.toString("base64")}`;
    const {png, pixels} = await spatialMap(await falDepth(imageUrl, deps.key(), deps.fetch));
    const score = spatialScore(pixels);
    const tier = spatialTierFor(score);
    logger.info("wallSpatial: scored", {wallId, tier, ...score});
    const map = await deps.store(`${deps.prefix ?? SPATIAL_MAP_PREFIX}/${wallId}.png`, png);
    return {tier, map, v: SPATIAL_VERSION};
  } catch (error) {
    logger.warn("wallSpatial: could not check the Spatial Scene", {
      wallId,
      error: error instanceof Error ? error.message : String(error),
    });
    return undefined;
  }
}
