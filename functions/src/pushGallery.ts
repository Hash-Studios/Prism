import {createHash} from "node:crypto";
import type * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {matchesMood, MOODS} from "./wallMoods";
import {isWotdEligible} from "./wallOfTheDay";
import {R2Storage, r2Env} from "./r2Storage";

/** A wall that passed the gate: its logical id, its public thumbnail, and its tags. */
export interface GalleryWall {
  id: string;
  thumb: string;
  tags: string[];
}

/**
 * One rendered gallery. `strip` shows the walls in sorted id order for iOS, and `thumbIndex` is the slot of the lead
 * wall in it. `hero` is the Android image: the lead wall in the centre square, so the collapsed crop is one wall.
 */
export interface PushGallery {
  wallIds: string[];
  stripUrl: string;
  heroUrl: string;
  count: number;
  thumbIndex: number;
  tags: string[];
}

export type GalleryLayout = "strip" | "hero";
export interface Rect {x: number; y: number; w: number; h: number}

export const GALLERY_VERSION = "v1";
export const GALLERY_WIDTH = 1200;
export const GALLERY_HEIGHT = 545;
export const GALLERY_MAX_BYTES = 200 * 1024;
const PAD = 16;
const GAP = 12;
const STRIP_TILE_WIDTH = 283;
const RADIUS = 20;
const MAX_WALLS = 4;
const MIN_WALLS = 2;
const MAX_THUMB_BYTES = 8 * 1024 * 1024;
const WALL_ID = /^[A-Za-z0-9_-]{1,200}$/;

/**
 * True when a wall may be shown in a push image. A drop teaser passes its week key and may show only that drop's
 * walls, as the drop push and the Drops page show them today. Every other gallery shows only free, listed walls.
 */
export function isGalleryWall(wall: admin.firestore.DocumentData, premium: string[], dropWeek?: string): boolean {
  if (wall.is_streak_exclusive === true || wall.dropReserved === true) return false;
  if (dropWeek !== undefined) return wall.dropWeek === dropWeek;
  return wall.review === true && isWotdEligible(wall, premium);
}

const MOOD_TAGS: Record<string, string> = {
  dreamy: "Dreamy",
  dark_quiet: "Dark and quiet",
  bright_bold: "Bright and bold",
  minimal: "Minimal",
};
const SKIPPED_TAGS = new Set(["community", "general", "art", "font", "rectangle", "pattern", "visual arts"]);

function sentenceCase(tag: string): string {
  const clean = tag.trim().replace(/\s+/g, " ").toLowerCase();
  return clean.charAt(0).toUpperCase() + clean.slice(1);
}

/** The tags of one wall: its moods, then its vision labels and collections. */
export function wallTags(wall: admin.firestore.DocumentData): string[] {
  const moods = MOODS.filter((rule) => MOOD_TAGS[rule.id] && matchesMood(rule, wall)).map((rule) => MOOD_TAGS[rule.id]);
  const strings = (value: unknown) => Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
  const raw = [...moods, ...strings(wall.visionLabels), ...strings(wall.collections)];
  const seen = new Set<string>();
  const tags: string[] = [];
  for (const tag of raw) {
    const key = tag.trim().toLowerCase();
    if (!key || key.length > 18 || SKIPPED_TAGS.has(key) || seen.has(key)) continue;
    seen.add(key);
    tags.push(sentenceCase(tag));
  }
  return tags;
}

/** The three tags the most walls share, first seen first on a tie. */
export function galleryTags(walls: Array<{tags: string[]}>, limit = 3): string[] {
  const counts = new Map<string, {tag: string; count: number; order: number}>();
  walls.forEach((wall) => wall.tags.forEach((tag) => {
    const key = tag.toLowerCase();
    const entry = counts.get(key);
    if (entry) entry.count += 1;
    else counts.set(key, {tag, count: 1, order: counts.size});
  }));
  return [...counts.values()].sort((a, b) => b.count - a.count || a.order - b.order).slice(0, limit).map((e) => e.tag);
}

export const tagsLine = (tags: string[]): string => tags.join(" · ");

/** The gated wall for a document, or null when it must not appear in a push image. */
export function galleryWall(
  doc: {id: string; data: admin.firestore.DocumentData},
  premium: string[],
  dropWeek?: string,
): GalleryWall | null {
  const id = typeof doc.data.id === "string" && WALL_ID.test(doc.data.id) ? doc.data.id : doc.id;
  const thumb = typeof doc.data.wallpaper_thumb === "string" ? doc.data.wallpaper_thumb : "";
  if (!WALL_ID.test(id) || !isPreviewUrl(thumb) || !isGalleryWall(doc.data, premium, dropWeek)) return null;
  return {id, thumb, tags: wallTags(doc.data)};
}

/** Lead wall first, no repeats, at most four. Fewer than two walls is no gallery. */
export function pickGalleryWalls(walls: GalleryWall[]): GalleryWall[] | null {
  const seen = new Set<string>();
  const picked = walls.filter((wall) => !seen.has(wall.id) && seen.add(wall.id)).slice(0, MAX_WALLS);
  return picked.length >= MIN_WALLS ? picked : null;
}

/**
 * Tile rects for a layout. `strip`: equal portrait tiles in one centred row. `hero` (three walls): the lead wall fills
 * the centre square, which is the square Android crops for the collapsed icon, and the side walls stay outside it.
 */
export function galleryRects(layout: GalleryLayout, count: number): Rect[] {
  const h = GALLERY_HEIGHT - 2 * PAD;
  if (layout === "hero") {
    return [{x: 344, y: PAD, w: 512, h}, {x: PAD, y: PAD, w: 310, h}, {x: 874, y: PAD, w: 310, h}];
  }
  const row = count * STRIP_TILE_WIDTH + (count - 1) * GAP;
  const x0 = (GALLERY_WIDTH - row) / 2;
  return Array.from({length: count}, (_, i) => ({x: x0 + i * (STRIP_TILE_WIDTH + GAP), y: PAD, w: STRIP_TILE_WIDTH, h}));
}

/** Image order per layout. The strip is sorted, so one set of walls makes one image whatever the lead wall. */
export function galleryOrder(layout: GalleryLayout, ids: string[]): string[] {
  const sorted = (xs: string[]) => [...xs].sort();
  return layout === "strip" ? sorted(ids) : [ids[0], ...sorted(ids.slice(1, 3))];
}

/** R2 key: the hash of the layout, the version and the ordered ids. */
export function galleryObjectKey(layout: GalleryLayout, ids: string[]): string {
  const hash = createHash("sha256").update(`${GALLERY_VERSION}|${layout}|${galleryOrder(layout, ids).join(",")}`)
    .digest("hex");
  return `push-gallery/${GALLERY_VERSION}/${hash}.jpg`;
}

function previewBase(): string {
  const base = r2Env("R2_PREVIEW_BASE_URL");
  if (!base) throw new Error("R2 preview endpoint is not configured");
  return base.replace(/\/$/, "");
}

/** Only public preview derivatives on our own domain are fetched. Originals live in the private bucket. */
export function isPreviewUrl(url: string): boolean {
  let base: string;
  try {
    base = previewBase();
    const expectedBase = new URL(base);
    const candidate = new URL(url);
    const previewPath = `${expectedBase.pathname.replace(/\/$/, "")}/previews/`;
    return expectedBase.protocol === "https:" && !expectedBase.username && !expectedBase.password &&
      candidate.origin === expectedBase.origin && !candidate.username && !candidate.password &&
      !candidate.search && !candidate.hash && candidate.pathname.startsWith(previewPath) &&
      !/%(?:2f|5c)/i.test(candidate.pathname);
  } catch {
    return false;
  }
}

async function fetchThumb(url: string, request: typeof fetch): Promise<Buffer> {
  if (!isPreviewUrl(url)) throw new Error("Thumbnail is not a preview derivative");
  const response = await request(url, {signal: AbortSignal.timeout(8000), redirect: "error"});
  if (!response.ok) throw new Error(`Thumbnail fetch failed (${response.status})`);
  const reader = response.body?.getReader();
  if (!reader) throw new Error("Thumbnail body is missing");
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_THUMB_BYTES) {
      await reader.cancel();
      throw new Error("Thumbnail size is invalid");
    }
    chunks.push(value);
  }
  if (size < 1) throw new Error("Thumbnail size is invalid");
  return Buffer.concat(chunks, size);
}

/** Draws the tiles on a dark canvas with rounded corners and keeps the JPEG under GALLERY_MAX_BYTES. */
export async function renderGallery(thumbs: Buffer[], rects: Rect[]): Promise<Buffer> {
  const {default: sharp} = await import("sharp");
  const tiles = await Promise.all(rects.map(async (rect, i) => {
    const w = Math.round(rect.w);
    const mask = Buffer.from(`<svg width="${w}" height="${rect.h}"><rect width="${w}" height="${rect.h}" ` +
      `rx="${RADIUS}" ry="${RADIUS}"/></svg>`);
    const input = await sharp(thumbs[i], {limitInputPixels: 40000000, animated: false}).rotate()
      .resize(w, rect.h, {fit: "cover"}).composite([{input: mask, blend: "dest-in"}]).png().toBuffer();
    return {input, left: Math.round(rect.x), top: rect.y};
  }));
  const canvas = sharp({create: {width: GALLERY_WIDTH, height: GALLERY_HEIGHT, channels: 3,
    background: {r: 14, g: 14, b: 16}}}).composite(tiles);
  const flat = await canvas.png().toBuffer();
  for (let quality = 82; ; quality -= 10) {
    const jpeg = await sharp(flat).jpeg({quality, mozjpeg: true}).toBuffer();
    if (jpeg.length <= GALLERY_MAX_BYTES || quality <= 42) return jpeg;
  }
}

export interface GalleryDeps {
  storage?: Pick<R2Storage, "head" | "put">;
  request?: typeof fetch;
}

/** Renders and stores one layout once. A second call for the same walls finds the object and only returns its URL. */
async function ensureImage(layout: GalleryLayout, walls: GalleryWall[], storage: Pick<R2Storage, "head" | "put">,
  request: typeof fetch): Promise<string> {
  const ids = walls.map((wall) => wall.id);
  const key = galleryObjectKey(layout, ids);
  const url = `${previewBase()}/${key}`;
  if (await storage.head("preview", key)) return url;
  const byId = new Map(walls.map((wall) => [wall.id, wall]));
  const ordered = galleryOrder(layout, ids).map((id) => byId.get(id) as GalleryWall);
  const thumbs = await Promise.all(ordered.map((wall) => fetchThumb(wall.thumb, request)));
  const bytes = await renderGallery(thumbs, galleryRects(layout, ordered.length));
  const stored = await storage.put("preview", key, bytes,
    {sha256: createHash("sha256").update(bytes).digest("hex")}, "image/jpeg");
  if (!stored && !(await storage.head("preview", key))) throw new Error("Gallery image store conflict without object");
  return url;
}

/**
 * The gallery for gated walls, lead wall first, or null when fewer than two walls are left or the image cannot be made.
 * Android gets the hero image for three or more walls, and the lead thumbnail for two.
 */
export async function buildPushGallery(walls: GalleryWall[], deps: GalleryDeps = {}): Promise<PushGallery | null> {
  const picked = pickGalleryWalls(walls);
  if (!picked) return null;
  try {
    const storage = deps.storage ?? new R2Storage();
    const request = deps.request ?? fetch;
    const [stripUrl, heroUrl] = await Promise.all([
      ensureImage("strip", picked, storage, request),
      picked.length >= 3 ? ensureImage("hero", picked, storage, request) : Promise.resolve(picked[0].thumb),
    ]);
    const ids = picked.map((wall) => wall.id);
    return {
      wallIds: ids,
      stripUrl,
      heroUrl,
      count: picked.length,
      thumbIndex: galleryOrder("strip", ids).indexOf(ids[0]),
      tags: galleryTags(picked),
    };
  } catch (error) {
    logger.warn("pushGallery: no gallery image; the push keeps its single image.", {error: String(error)});
    return null;
  }
}

/**
 * Up to `limit` doc ids of gated walls that share the most moods or tags with the pick, newest first on a tie.
 * A wall that shares nothing is never picked.
 */
export function similarWallIds(
  pick: {id: string; data: admin.firestore.DocumentData},
  candidates: Array<{id: string; data: admin.firestore.DocumentData}>,
  premium: string[],
  limit = 3,
): string[] {
  const wanted = new Set(wallTags(pick.data).map((tag) => tag.toLowerCase()));
  const created = (data: admin.firestore.DocumentData): number => data.createdAt?.toMillis?.() ?? 0;
  return candidates
    .filter((c) => c.id !== pick.id && c.data.id !== pick.data.id && galleryWall(c, premium) !== null)
    .map((c) => ({c, score: wallTags(c.data).filter((tag) => wanted.has(tag.toLowerCase())).length}))
    .filter(({score}) => score > 0)
    .sort((a, b) => b.score - a.score || created(b.c.data) - created(a.c.data) || (a.c.id < b.c.id ? -1 : 1))
    .slice(0, limit)
    .map(({c}) => c.id);
}
