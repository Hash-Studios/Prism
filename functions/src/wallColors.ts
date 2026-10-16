import sharp from "sharp";
import {logger} from "firebase-functions/v2";

export type PaletteColor = {id: string; hex: string};

/** The twelve Prism colours. Keep in sync with lib/core/color/prism_palette.dart. */
export const PALETTE: readonly PaletteColor[] = [
  {id: "red", hex: "cc0000"},
  {id: "orange", hex: "ff6600"},
  {id: "yellow", hex: "ffcc33"},
  {id: "green", hex: "669900"},
  {id: "teal", hex: "66cccc"},
  {id: "blue", hex: "0066cc"},
  {id: "purple", hex: "663399"},
  {id: "pink", hex: "ea4c88"},
  {id: "brown", hex: "663300"},
  {id: "black", hex: "000000"},
  {id: "grey", hex: "999999"},
  {id: "white", hex: "ffffff"},
];

/** True when the value is a non-empty list of palette ids, so the wall already has usable colours. */
export function hasPaletteColors(value: unknown): boolean {
  return Array.isArray(value) && value.length > 0 && value.every((id) => PALETTE.some((color) => color.id === id));
}

export const MIN_COLOR_SHARE = 0.12;
export const MAX_WALL_COLORS = 3;
const SAMPLE_SIZE = 48;
const FETCH_TIMEOUT_MS = 15000;
const MAX_IMAGE_BYTES = 15 * 1024 * 1024;

type Lab = [number, number, number];

function srgbToLinear(channel: number): number {
  const c = channel / 255;
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function labF(t: number): number {
  return t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116;
}

/** sRGB (0 to 255 per channel) to CIE Lab, D65 white point. */
export function rgbToLab(r: number, g: number, b: number): Lab {
  const lr = srgbToLinear(r);
  const lg = srgbToLinear(g);
  const lb = srgbToLinear(b);
  const x = (0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb) / 0.95047;
  const y = 0.2126729 * lr + 0.7151522 * lg + 0.072175 * lb;
  const z = (0.0193339 * lr + 0.119192 * lg + 0.9503041 * lb) / 1.08883;
  const fx = labF(x);
  const fy = labF(y);
  const fz = labF(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

const PALETTE_LAB: readonly Lab[] = PALETTE.map(({hex}) => rgbToLab(
  parseInt(hex.slice(0, 2), 16),
  parseInt(hex.slice(2, 4), 16),
  parseInt(hex.slice(4, 6), 16),
));

/** Index into PALETTE of the colour closest to the pixel by CIE76 distance. */
export function nearestPaletteIndex(r: number, g: number, b: number): number {
  const [l, a, bb] = rgbToLab(r, g, b);
  let best = 0;
  let bestDistance = Infinity;
  for (let i = 0; i < PALETTE_LAB.length; i++) {
    const [pl, pa, pb] = PALETTE_LAB[i];
    const distance = (l - pl) ** 2 + (a - pa) ** 2 + (bb - pb) ** 2;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = i;
    }
  }
  return best;
}

/**
 * Palette ids that cover at least 12% of the image, most dominant first, at most 3.
 * Always holds the top colour. Throws when sharp cannot decode the buffer.
 */
export async function dominantPaletteColors(imageBuffer: Buffer): Promise<string[]> {
  const {data, info} = await sharp(imageBuffer)
    .resize(SAMPLE_SIZE, SAMPLE_SIZE, {fit: "inside"})
    .flatten({background: "#ffffff"})
    .toColourspace("srgb")
    .removeAlpha()
    .raw()
    .toBuffer({resolveWithObject: true});

  const counts = new Array<number>(PALETTE.length).fill(0);
  const pixels = info.width * info.height;
  for (let i = 0; i < pixels; i++) {
    const offset = i * info.channels;
    counts[nearestPaletteIndex(data[offset], data[offset + 1], data[offset + 2])] += 1;
  }

  const ranked = counts
    .map((count, index) => ({id: PALETTE[index].id, share: count / pixels, index}))
    .filter((entry) => entry.share > 0)
    .sort((a, b) => b.share - a.share || a.index - b.index);
  if (ranked.length === 0) {
    return [];
  }
  const picked = ranked.filter((entry) => entry.share >= MIN_COLOR_SHARE).slice(0, MAX_WALL_COLORS);
  return (picked.length > 0 ? picked : ranked.slice(0, 1)).map((entry) => entry.id);
}

export type ColorFetch = (url: string, init: {signal: AbortSignal; redirect?: "manual"}) => Promise<Response>;

/** Hosts that serve wall images: GitHub raw (app uploads) and prismwalls.com (Studio assets). */
export const ALLOWED_IMAGE_HOSTS: readonly string[] = ["raw.githubusercontent.com", "prismwalls.com"];

const MAX_REDIRECTS = 3;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

function checkedImageUrl(value: string): URL {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("image url is not valid");
  }
  if (url.protocol !== "https:") {
    throw new Error("image url must use https");
  }
  if (url.username || url.password || url.port) {
    throw new Error("image url must not have credentials or a port");
  }
  if (!ALLOWED_IMAGE_HOSTS.includes(url.hostname)) {
    throw new Error("image host is not allowed");
  }
  return url;
}

/**
 * Downloads an image from an allowed https host. Redirects are followed by hand, at most 3, and every target passes
 * the same check. Fails on a slow host, a non-image reply or a body over the size cap.
 */
export async function fetchImageBuffer(
  url: string,
  fetchImpl: ColorFetch = fetch,
  maxBytes: number = MAX_IMAGE_BYTES,
  timeoutMs: number = FETCH_TIMEOUT_MS,
): Promise<Buffer> {
  let target = checkedImageUrl(url);
  const signal = AbortSignal.timeout(timeoutMs);
  let response = await fetchImpl(target.href, {signal, redirect: "manual"});
  for (let hops = 0; REDIRECT_STATUSES.has(response.status); hops++) {
    await response.body?.cancel().catch(() => undefined);
    if (hops >= MAX_REDIRECTS) {
      throw new Error("image redirected too many times");
    }
    const location = response.headers.get("location");
    if (!location) {
      throw new Error("image redirect has no location");
    }
    target = checkedImageUrl(new URL(location, target).href);
    response = await fetchImpl(target.href, {signal, redirect: "manual"});
  }
  if (!response.ok || !response.body) {
    throw new Error(`image request failed with ${response.status}`);
  }
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw new Error("image is too large");
  }
  const chunks: Uint8Array[] = [];
  let total = 0;
  const reader = response.body.getReader();
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        throw new Error("image is too large");
      }
      chunks.push(value);
    }
  } finally {
    await reader.cancel().catch(() => undefined);
  }
  return Buffer.concat(chunks);
}

export type WallImageUrls = {wallpaper_url?: unknown; wallpaper_thumb?: unknown};

/**
 * Colours for a wall, read from its thumbnail when it has one (smaller download, same colours), then from the full
 * image when the thumbnail cannot be read. Never throws: a failure is logged and gives undefined, so it cannot fail
 * categorization.
 */
export async function wallColorsFor(
  wallId: string,
  wall: WallImageUrls,
  fetchImpl: ColorFetch = fetch,
): Promise<string[] | undefined> {
  const urls = [wall.wallpaper_thumb, wall.wallpaper_url]
    .map((value) => (typeof value === "string" ? value.trim() : ""))
    .filter((value, index, all) => value.length > 0 && all.indexOf(value) === index);
  for (const url of urls) {
    try {
      const colors = await dominantPaletteColors(await fetchImageBuffer(url, fetchImpl));
      if (colors.length > 0) {
        return colors;
      }
    } catch (error) {
      logger.warn("wallColors: could not read colours", {
        wallId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
  return undefined;
}
