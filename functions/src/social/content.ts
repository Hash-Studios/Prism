import * as admin from "firebase-admin";
import {db, str} from "../common";
import {R2Storage} from "../r2Storage";
import {DESKTOP_COMPANIONS, DESKTOP_SIZE} from "../studio/desktop";
import {annotateWithVision, likelihoodRank, type VisionAnnotate} from "../studio/gates";
import {STUDIO_SERIES} from "../studio/series";
import {studioImageUrl, studioPostCaption} from "../studio/telegram";
import {xWeightedLength} from "./x";

// The content of each pipeline: which walls, the rendered images, the text. No posting here.

export type Pipeline = "grid" | "panorama" | "still";

export interface SocialMedia {jpeg: Buffer; alt: string; sensitive: boolean}
export interface SocialContent {
  pipeline: Pipeline;
  source: {kind: "prism" | "wallhaven"; ids: string[]; tags?: string[]};
  media: SocialMedia[];
  text: string;
  replyText: string;
}

/**
 * No link reply. X bills a post with a URL at about 13 times a plain post, so links live in the bio and a pinned
 * post. An empty `replyText` makes the publisher skip the reply.
 */
const NO_REPLY = "";

/** Rotates by day, so one line comes back only after `lines.length` days. Lists hold 14 lines for a 14-day gap. */
export function rotate(lines: readonly string[], day: string, salt = 0): string {
  const index = Math.floor(Date.parse(`${day}T00:00:00Z`) / 86_400_000) + salt;
  return lines[((index % lines.length) + lines.length) % lines.length];
}

export const GRID_LINES = [
  "Wallpapers I found today 🤩", "Fresh walls for your lock screen", "3 walls, pick one", "Today's finds",
  "Your next wallpaper is here", "Saved these for you", "Lock screen upgrade", "Which one are you taking?",
  "Walls worth a swipe", "Found these today", "New walls, no notes", "Pick your favourite", "Today's wallpaper drop",
  "Three for your phone",
] as const;

export const PANORAMA_LINES = [
  "swipe →", "one view, three screens", "swipe for the full view", "one wall, three panels", "keep swiping →",
  "the whole scene, in three", "swipe across", "one picture, three phones", "panorama →", "three panels, one view",
  "swipe to see it all", "split in three", "the full picture →", "scroll the view →",
] as const;

// ---------- P1 panorama ----------

export const PANORAMA_PANELS = 3;
/** Luma standard deviation under which a panel counts as flat. ponytail: guessed; calibrate on After Dark walls. */
export const FLAT_PANEL_STDEV = 6;

/** Cuts a wide image into equal tall panels. The last panel takes the leftover pixels. */
export async function panoramaPanels(wide: Buffer, panels = PANORAMA_PANELS): Promise<{jpegs: Buffer[]; flat: number}> {
  const {default: sharp} = await import("sharp");
  const meta = await sharp(wide).metadata();
  const width = meta.width ?? 0;
  const height = meta.height ?? 0;
  if (width < panels || height < 1) throw new Error("Panorama source has no size.");
  const step = Math.floor(width / panels);
  const jpegs: Buffer[] = [];
  let flat = 0;
  for (let i = 0; i < panels; i++) {
    const left = i * step;
    const panelWidth = i === panels - 1 ? width - left : step;
    const panel = sharp(wide).extract({left, top: 0, width: panelWidth, height});
    const stats = await panel.clone().greyscale().stats();
    if ((stats.channels[0]?.stdev ?? 0) < FLAT_PANEL_STDEV) flat++;
    jpegs.push(await panel.jpeg({quality: 92, mozjpeg: true}).toBuffer());
  }
  return {jpegs, flat};
}

const sceneOf = (wall: admin.firestore.DocumentData) => studioPostCaption(wall).split("\n\n")[0].replace(/\.$/, "");

/** A Studio wall with a ready companion, in random order. Skips walls in `exclude`. */
export async function panoramaContent(day: string, exclude: Set<string>, storage = new R2Storage()):
  Promise<SocialContent | null> {
  const ready = await db.collection(DESKTOP_COMPANIONS).where("status", "==", "ready").limit(500).get();
  const candidates = ready.docs
    .map((doc) => ({shareId: doc.id, manifest: doc.data()}))
    .filter(({shareId, manifest}) => !exclude.has(shareId) && str(manifest.original?.object) !== "" &&
      manifest.original?.width === DESKTOP_SIZE.width && manifest.original?.height === DESKTOP_SIZE.height);
  // ponytail: random among unseen; rank by series or favourites when the metrics show which walls do best.
  const shuffled = candidates.sort(() => Math.random() - 0.5);
  for (const {shareId, manifest} of shuffled.slice(0, 8)) {
    const wallPath = str(manifest.wallPath) || `walls/${shareId}`;
    const wall = (await db.doc(wallPath).get()).data();
    if (!wall || wall.review !== true || wall.origin !== "studio") continue;
    const {jpegs, flat} = await panoramaPanels(await storage.get("private", str(manifest.original.object)));
    if (flat >= 2) continue;
    const scene = sceneOf(wall);
    const series = STUDIO_SERIES.find((s) => s.id === wall.seriesId)?.name;
    return {
      pipeline: "panorama",
      source: {kind: "prism", ids: [shareId]},
      media: jpegs.map((jpeg, i) => ({jpeg, sensitive: false,
        alt: `Panel ${i + 1} of ${jpegs.length}. ${scene}.${series ? ` ${series} by Prism Studio.` : " By Prism Studio."}`})),
      text: rotate(PANORAMA_LINES, day),
      replyText: NO_REPLY,
    };
  }
  return null;
}

// ---------- P5 still ----------

async function downloadJpeg(url: string, longEdge = 4096): Promise<Buffer> {
  const res = await fetch(url, {signal: AbortSignal.timeout(60_000)});
  if (!res.ok) throw new Error(`Image download failed: ${res.status}`);
  const {default: sharp} = await import("sharp");
  return sharp(Buffer.from(await res.arrayBuffer())).rotate()
    .resize(longEdge, longEdge, {fit: "inside", withoutEnlargement: true})
    .jpeg({quality: 90, mozjpeg: true}).toBuffer();
}

/** X refuses photos over 5 MB. Steps quality down until the JPEG fits. */
export async function fitFiveMb(jpeg: Buffer): Promise<Buffer> {
  const {default: sharp} = await import("sharp");
  let out = jpeg;
  for (const quality of [85, 78, 70]) {
    if (out.length <= 5 * 1024 * 1024) return out;
    out = await sharp(jpeg).jpeg({quality, mozjpeg: true}).toBuffer();
  }
  if (out.length > 5 * 1024 * 1024) throw new Error("Image stays over 5 MB.");
  return out;
}

/**
 * One approved Studio wall, full size, After Dark first (the best brand post was one). With `wotd`, today's Wall of
 * the Day when it is set.
 */
export async function stillContent(day: string, exclude: Set<string>, options: {wotd: boolean; salt: number}):
  Promise<SocialContent | null> {
  let picked: {id: string; wall: admin.firestore.DocumentData; wotd: boolean} | null = null;
  if (options.wotd) {
    const current = (await db.collection("wall_of_the_day").doc("current").get()).data();
    const wallId = str(current?.wallId);
    const date = current?.date instanceof admin.firestore.Timestamp ? current.date.toDate().toISOString().slice(0, 10) : "";
    const wall = wallId && date === day ? (await db.collection("walls").doc(wallId).get()).data() : undefined;
    if (wall && wall.review === true && !exclude.has(wallId)) picked = {id: wallId, wall, wotd: true};
  }
  if (!picked) {
    const studio = await db.collection("walls").where("origin", "==", "studio").where("review", "==", true).limit(1000).get();
    const fresh = studio.docs.filter((doc) => !exclude.has(doc.id))
      .sort((a, b) => (b.createTime?.toMillis() ?? 0) - (a.createTime?.toMillis() ?? 0));
    const dark = fresh.filter((doc) => doc.data().seriesId === "after-dark");
    const pool = (dark.length > 0 ? dark : fresh).slice(0, 10);
    const doc = pool[(options.salt % Math.max(pool.length, 1))];
    if (doc) picked = {id: doc.id, wall: doc.data(), wotd: false};
  }
  if (!picked) return null;
  const jpeg = await fitFiveMb(await downloadJpeg(await studioImageUrl(picked.id, picked.wall)));
  const scene = picked.wall.origin === "studio" ? sceneOf(picked.wall) : str(picked.wall.title) || "Wall of the Day";
  return {
    pipeline: "still",
    source: {kind: "prism", ids: [picked.id]},
    media: [{jpeg, sensitive: false, alt: `${scene}. Phone wallpaper from Prism.`}],
    text: picked.wotd ? "Wall of the Day. Which one is going on your phone this week?" : `${scene}.`,
    replyText: NO_REPLY,
  };
}

// ---------- P2 Wallhaven grid ----------

/** Youth-coded tags. A backup guard: the owner approves every grid, because tags cannot prove age. */
export const YOUTH_TAG = /\b(lolis?|lolicon|shota|shotacon|child(?:ren)?|kids?|(?:pre)?teen(?:s|age|agers?)?|adolescents?|toddlers?|infants?|bab(?:y|ies)|school[\s_-]*(?:girls?|boys?|uniforms?)|students?|underage|minors?|(?:little|young)[\s_-]+(?:girls?|boys?)|preschool|kindergarten|elementary)\b/i;

export interface WallhavenWall {id: string; purity: string; path: string; tags: string[]}

/** Grid rules on Vision SafeSearch. Never nudity; a very racy image gets X's sensitive flag. */
export function gridVisionDecision(safe: Record<string, unknown> | null | undefined):
  {ok: false; reason: string} | {ok: true; sensitive: boolean} {
  if (!safe) return {ok: false, reason: "no_safe_search"};
  const rank = (key: string) => likelihoodRank(safe[key]);
  if ([rank("adult"), rank("racy"), rank("violence"), rank("medical")].some((r) => r === 0)) {
    return {ok: false, reason: "unknown_safe_search"};
  }
  if (rank("adult") >= 3) return {ok: false, reason: "adult"}; // POSSIBLE or higher
  if (rank("violence") >= 4 || rank("medical") >= 4) return {ok: false, reason: "violence_or_medical"}; // LIKELY+
  return {ok: true, sensitive: rank("racy") >= 5}; // VERY_LIKELY
}

const WALLHAVEN = "https://wallhaven.cc/api/v1";

async function wallhavenJson(path: string): Promise<any> {
  const res = await fetch(`${WALLHAVEN}${path}`, {signal: AbortSignal.timeout(20_000),
    headers: {"User-Agent": "PrismWallpapers/1.0"}});
  if (!res.ok) throw new Error(`Wallhaven ${path.split("?")[0]} failed: ${res.status}`);
  return res.json();
}

/** Toplist of the last 3 days, then the last week. Portrait, phone-size, SFW + sketchy. Never NSFW. */
export async function wallhavenCandidates(): Promise<Array<{id: string; purity: string}>> {
  const seen = new Set<string>();
  const out: Array<{id: string; purity: string}> = [];
  // Two pages per range: page 1 alone is about 24 walls, mostly sketchy, so the same top walls would win every day.
  for (const [topRange, page] of [["3d", "1"], ["3d", "2"], ["1w", "1"], ["1w", "2"]]) {
    const query = new URLSearchParams({categories: "111", purity: "110", sorting: "toplist", topRange,
      ratios: "portrait", atleast: "1080x1920", page});
    const data = (await wallhavenJson(`/search?${query}`))?.data;
    for (const item of Array.isArray(data) ? data : []) {
      const id = str(item?.id);
      if (/^[a-z0-9]{1,16}$/.test(id) && !seen.has(id) && ["sfw", "sketchy"].includes(str(item?.purity))) {
        seen.add(id);
        out.push({id, purity: str(item.purity)});
      }
    }
  }
  return out;
}

export async function gridContent(day: string, exclude: Set<string>, config: {sketchyPerPost: number; blockedTags: string[]},
  deps: {annotate: VisionAnnotate; candidates: typeof wallhavenCandidates; details: (id: string) => Promise<WallhavenWall>;
    download: (url: string) => Promise<Buffer>} = {annotate: annotateWithVision, candidates: wallhavenCandidates,
    details: wallhavenDetails, download: (url) => downloadJpeg(url, 2400)}): Promise<SocialContent | null> {
  const picked: Array<{wall: WallhavenWall; jpeg: Buffer; sensitive: boolean}> = [];
  let sketchy = 0;
  let checked = 0;
  const blocked = config.blockedTags.map((t) => t.toLowerCase());
  for (const candidate of await deps.candidates()) {
    if (picked.length === 3 || checked >= 15) break;
    if (exclude.has(candidate.id) || (candidate.purity === "sketchy" && sketchy >= config.sketchyPerPost)) continue;
    checked++;
    const wall = await deps.details(candidate.id);
    if (wall.purity !== candidate.purity || !["sfw", "sketchy"].includes(wall.purity)) continue;
    if (wall.tags.some((tag) => YOUTH_TAG.test(tag) || blocked.includes(tag.toLowerCase()))) continue;
    if (!/^https:\/\/w\.wallhaven\.cc\//.test(wall.path)) continue;
    const jpeg = await fitFiveMb(await deps.download(wall.path));
    const decision = gridVisionDecision((await deps.annotate(jpeg)).safeSearchAnnotation as Record<string, unknown>);
    if (!decision.ok) continue;
    if (wall.purity === "sketchy") sketchy++;
    picked.push({wall, jpeg, sensitive: decision.sensitive});
  }
  if (picked.length < 3) return null;
  return {
    pipeline: "grid",
    source: {kind: "wallhaven", ids: picked.map((p) => p.wall.id), tags: picked.flatMap((p) => p.wall.tags)},
    media: picked.map((p, i) => ({jpeg: p.jpeg, sensitive: p.sensitive,
      alt: `Phone wallpaper ${i + 1} of 3${p.wall.tags.length ? `: ${p.wall.tags.slice(0, 4).join(", ")}` : ""}.`})),
    text: rotate(GRID_LINES, day),
    replyText: NO_REPLY,
  };
}

export async function wallhavenDetails(id: string): Promise<WallhavenWall> {
  const data = (await wallhavenJson(`/w/${encodeURIComponent(id)}`))?.data;
  return {id, purity: str(data?.purity), path: str(data?.path),
    tags: Array.isArray(data?.tags) ? data.tags.map((t: any) => str(t?.name)).filter(Boolean) : []};
}

/** Every post and reply must fit X's 280 weighted characters. */
export function assertFits(content: SocialContent): void {
  if (xWeightedLength(content.text) > 280 || xWeightedLength(content.replyText) > 280) {
    throw new Error(`${content.pipeline} text is over 280 weighted characters.`);
  }
}
