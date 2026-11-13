import * as admin from "firebase-admin";
import {db, str} from "../common";
import {R2Storage} from "../r2Storage";
import {DESKTOP_COMPANIONS, DESKTOP_SIZE} from "../studio/desktop";
import {annotateWithVision, likelihoodRank, type VisionAnnotate} from "../studio/gates";
import {STUDIO_SERIES} from "../studio/series";
import {studioImageUrl, studioPostCaption} from "../studio/telegram";
import {xWeightedLength} from "./x";

// The content of each pipeline: which walls, the rendered images, the text. No posting here.

export type Pipeline = "grid" | "panorama" | "still" | "set";

export interface SocialMedia {jpeg: Buffer; alt: string; sensitive: boolean; /** Vision thinks it needs the flag. */ suggestFlag?: boolean}
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
export function rotate<T>(lines: readonly T[], day: string, salt = 0): T {
  const index = Math.floor(Date.parse(`${day}T00:00:00Z`) / 86_400_000) + salt;
  return lines[((index % lines.length) + lines.length) % lines.length];
}

// Captions follow the research: the picture does the work, the words stay short. Hashtags are light or absent, and
// the only sales line is "available in prism". Each list holds 14 lines, so a line comes back only after 14 days.

/** Curator voice, like @Papers_app ("Epic Wallpapers I found Today 🤩"): casual, at most one emoji. */
export const GRID_LINES = [
  "Wallpapers I found today 🤩", "Fresh wallpapers for you ✨", "Cool wallpapers I found today",
  "Today's wallpaper finds 🔥", "Pick one for your lock screen 👀", "New walls just dropped",
  "Wallpapers you didn't know you needed", "Your next lock screen is here", "Found these, had to share 🤩",
  "Wallpaper dump 📱", "Which one are you taking? 👇", "3 walls, 0 regrets", "Fresh finds for your home screen ✨",
  "Saved all three. No notes",
] as const;

/** Two quiet lowercase lines, like the panorama reference ("no wasted emotions / just composition"). */
export const PANORAMA_LINES = [
  "one view\nthree screens", "slow down\nlet it breathe", "nothing loud\njust light", "keep swiping\nit keeps going",
  "less noise\nmore horizon", "quiet frame\nquiet mind", "one picture\nsplit three ways", "stay a while\nswipe slow",
  "no clutter\njust space", "the view\ndoesn't end here →", "long nights\nsoft light", "calm\nthen calmer",
  "made to be swiped", "every screen\na piece of it",
] as const;

/** Second line under a still's title. Empty lines keep some posts to the title alone. */
export const STILL_TAILS = [
  "", "lock screen or home screen?", "available in prism", "", "save it for later", "#wallpaper", "",
  "which phone is this going on?", "new in prism", "", "set it and forget it", "#wallpaper", "", "made to be looked at",
] as const;
/** The same idea for After Dark walls, where true black and AMOLED tags fit. */
export const DARK_STILL_TAILS = [
  "", "#amoled #wallpaper", "true black, made for oled", "", "available in prism", "lock screen or home screen?", "",
  "#amoled", "dark mode, but make it a wallpaper", "", "save it for tonight", "#wallpaper #amoled", "",
  "easy on the eyes",
] as const;

/** "Deep Lure · Jade" over a tail line, all lowercase like the reference posts. */
export function stillCaption(title: string, day: string, salt: number, dark: boolean): string {
  const tail = rotate(dark ? DARK_STILL_TAILS : STILL_TAILS, day, salt);
  return captionWithTitle(title, "", tail ? `\n${tail}` : "");
}

/** Still tails that make no Prism claim, for Wallhaven walls that are not Prism uploads. */
const NEUTRAL_STILL_TAILS = STILL_TAILS.filter((tail) => !tail.includes("prism"));
/** "sunsets" over a tail line, like a Studio still. */
export function themedStillCaption(theme: string, day: string, salt: number): string {
  const tail = rotate(NEUTRAL_STILL_TAILS, day, salt);
  return captionWithTitle(theme, "", tail ? `\n${tail}` : "");
}

/** Wall of the Day can be a creator wall with an unbounded legacy title. Keep the fixed caption lines intact. */
function captionWithTitle(title: string, prefix: string, suffix: string): string {
  const lower = title.toLowerCase();
  if (xWeightedLength(`${prefix}${lower}${suffix}`) <= 280) return `${prefix}${lower}${suffix}`;
  const chars = Array.from(lower).slice(0, 280);
  while (chars.length > 0 && xWeightedLength(`${prefix}${chars.join("")}…${suffix}`) > 280) chars.pop();
  return `${prefix}${chars.join("")}…${suffix}`;
}

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
  const wallTitle = typeof picked.wall.title === "string" ? picked.wall.title.trim() : "";
  const scene = picked.wall.origin === "studio" ? sceneOf(picked.wall) : wallTitle || "Wall of the Day";
  const title = wallTitle || scene;
  return {
    pipeline: "still",
    source: {kind: "prism", ids: [picked.id]},
    media: [{jpeg, sensitive: false, alt: `${scene}. Phone wallpaper from Prism.`}],
    text: picked.wotd ? captionWithTitle(title, "wall of the day ✨\n", "\nlock screen or home screen?") :
      stillCaption(title, day, options.salt, picked.wall.seriesId === "after-dark"),
    replyText: NO_REPLY,
  };
}

// ---------- P2 Wallhaven grid ----------

/** Youth-coded tags. A backup guard: the owner approves every grid, because tags cannot prove age. */
export const YOUTH_TAG = /\b(lolis?|lolicon|shota|shotacon|child(?:ren)?|kids?|(?:pre)?teen(?:s|age|agers?)?|adolescents?|toddlers?|infants?|bab(?:y|ies)|school[\s_-]*(?:girls?|boys?|uniforms?)|students?|underage|minors?|(?:little|young)[\s_-]+(?:girls?|boys?)|preschool|kindergarten|elementary)\b/i;

export interface WallhavenWall {id: string; purity: string; path: string; tags: string[]; category?: string}

/**
 * Grid rules on Vision SafeSearch. Wallhaven's sketchy level already excludes nudity, yet Vision rates almost every
 * sketchy wall adult POSSIBLE or higher. So only adult VERY_LIKELY, the closest to nudity, rejects. `sensitive` (adult
 * POSSIBLE or LIKELY, or racy VERY_LIKELY) is only a hint: the owner decides the flag in Telegram, because a flag
 * makes X hide the post.
 */
export function gridVisionDecision(safe: Record<string, unknown> | null | undefined):
  {ok: false; reason: string} | {ok: true; sensitive: boolean} {
  if (!safe) return {ok: false, reason: "no_safe_search"};
  const rank = (key: string) => likelihoodRank(safe[key]);
  if ([rank("adult"), rank("racy"), rank("violence"), rank("medical")].some((r) => r === 0)) {
    return {ok: false, reason: "unknown_safe_search"};
  }
  if (rank("adult") >= 5) return {ok: false, reason: "adult"}; // VERY_LIKELY
  if (rank("violence") >= 4 || rank("medical") >= 4) return {ok: false, reason: "violence_or_medical"}; // LIKELY+
  return {ok: true, sensitive: rank("adult") >= 3 || rank("racy") >= 5}; // adult POSSIBLE+, racy VERY_LIKELY
}

const WALLHAVEN = "https://wallhaven.cc/api/v1";
/**
 * Candidates checked per grid. At 15, a pool of mostly rejected sketchy walls left no grid at all.
 * The shared limiter counts searches and details across all slots.
 */
export const GRID_DETAIL_BUDGET = 30;
/** Time to pick grid walls, so socialPrepare (540 s) keeps time to record the grid and build the other slots. */
export const GRID_DEADLINE_MS = 180_000;

export function wallhavenLimiter(now = Date.now,
  sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))): (deadline?: number) => Promise<void> {
  const starts: number[] = [];
  let queue = Promise.resolve();
  return (deadline = Infinity) => {
    const next = queue.then(async () => {
      while (starts.length && now() - starts[0] >= 60_001) starts.shift();
      if (starts.length >= 45) await sleep(Math.min(60_001 - (now() - starts[0]), Math.max(0, deadline - now())));
      if (now() >= deadline) throw new Error("Wallhaven deadline exceeded.");
      while (starts.length && now() - starts[0] >= 60_001) starts.shift();
      starts.push(now());
    });
    queue = next.catch(() => undefined);
    return next;
  };
}
const waitForWallhaven = wallhavenLimiter();

async function wallhavenJson(path: string, deadline = Infinity): Promise<any> {
  await waitForWallhaven(deadline);
  const timeout = Math.max(1, Math.min(20_000, Math.floor(deadline - Date.now())));
  const res = await fetch(`${WALLHAVEN}${path}`, {signal: AbortSignal.timeout(timeout),
    headers: {"User-Agent": "PrismWallpapers/1.0"}});
  if (!res.ok) throw new Error(`Wallhaven ${path.split("?")[0]} failed: ${res.status}`);
  return res.json();
}

export type WallhavenCandidate = {id: string; purity: string};

/** Runs the searches in order and keeps each id once. A failed page 2 only narrows the pool; a failed page 1 throws. */
async function wallhavenSearch(searches: Array<Record<string, string>>, deadline: number,
  enough: (out: WallhavenCandidate[], pageSize: number) => boolean = () => false): Promise<WallhavenCandidate[]> {
  const seen = new Set<string>();
  const out: WallhavenCandidate[] = [];
  for (const search of searches) {
    let data: unknown;
    try {
      data = (await wallhavenJson(`/search?${new URLSearchParams(search)}`, deadline))?.data;
    } catch (err) {
      // Page 2 only widens the pool. Its failure (a 429, a timeout) keeps the page-1 walls already collected.
      if (search.page === "1") throw err;
      continue;
    }
    const items = Array.isArray(data) ? data : [];
    for (const item of items) {
      const id = str(item?.id);
      if (/^[a-z0-9]{1,16}$/.test(id) && !seen.has(id) && ["sfw", "sketchy"].includes(str(item?.purity))) {
        seen.add(id);
        out.push({id, purity: str(item.purity)});
      }
    }
    if (enough(out, items.length)) break;
  }
  return out;
}

/** Toplist of the last 3 days, then the last week. Portrait, phone-size, SFW + sketchy. Never NSFW. */
export async function wallhavenCandidates(deadline = Infinity): Promise<WallhavenCandidate[]> {
  // Two pages per range: page 1 alone is about 24 walls, mostly sketchy, so the same top walls would win every day.
  // Keep both original page-1 pools first so page 2 cannot exhaust the detail budget before the weekly fallback.
  return wallhavenSearch([["3d", "1"], ["1w", "1"], ["3d", "2"], ["1w", "2"]].map(([topRange, page]) => ({
    categories: "111", purity: "110", sorting: "toplist", topRange, ratios: "portrait", atleast: "1080x1920", page})), deadline);
}

/**
 * Themes for the daily set and the Wallhaven stills, landscapes and subjects in turn so neighbouring days differ. Each
 * was checked by eye on its top walls (2026-11-13). Landscapes search general and anime ("110"), which keeps the
 * painted anime-style skies; subjects search general only ("100"), where anime is mostly portraits. "-women" and
 * PORTRAIT_TAGS keep out pin-ups. Dropped: minimalism, city, night (mixed), cars (neon cities, not cars).
 */
export const THEMES: ReadonlyArray<{name: string; query: string; categories: string}> = [
  {name: "sunsets", query: "sunset -women", categories: "110"},
  {name: "batman", query: "Batman -women", categories: "100"},
  {name: "mountains", query: "mountains -women -anime", categories: "110"},
  {name: "japan", query: "Japan -women", categories: "100"},
  {name: "pixel art", query: "pixel art -women", categories: "110"},
  {name: "spider-man", query: "Spider-Man -women", categories: "100"},
  {name: "snow", query: "snow -women -anime", categories: "110"},
  {name: "cats", query: "cats -women", categories: "100"},
  {name: "forests", query: "forest -women -anime", categories: "110"},
  {name: "samurai", query: "samurai -women", categories: "100"},
  {name: "space", query: "space -women -anime", categories: "110"},
  {name: "dragons", query: "dragon -women", categories: "100"},
  {name: "landscapes", query: "landscape -women -anime", categories: "110"},
  {name: "star wars", query: "Star Wars -women", categories: "100"},
  {name: "studio ghibli", query: "Studio Ghibli", categories: "110"},
  {name: "flowers", query: "+flowers +photography", categories: "100"},
];
export type Theme = (typeof THEMES)[number];

/** Search pages read per theme at most. 24 walls a page, so a daily set can go months deep into a theme. */
export const THEME_PAGES = 8;

/**
 * A theme's SFW walls, the most favourited of all time first: the community's best picks, not this week's. Reads pages
 * until `want` walls are not in `exclude`, or the theme ends (a page under 24 walls).
 */
export async function wallhavenThemeCandidates(query: string, deadline = Infinity, exclude: Set<string> = new Set(),
  want = 24, categories = "110"): Promise<WallhavenCandidate[]> {
  return wallhavenSearch(Array.from({length: THEME_PAGES}, (_, i) => ({q: query, categories, purity: "100",
    sorting: "favorites", ratios: "portrait", atleast: "1080x1920", page: String(i + 1)})), deadline,
  (out, pageSize) => pageSize < 24 || out.filter((c) => !exclude.has(c.id)).length >= want);
}

/**
 * The medium of a wall from its Wallhaven tags, first match wins: comic walls are also tagged "artwork", so the more
 * specific styles come first. Null when no tag names a medium, so unknown walls never join a set.
 */
const ART_STYLES: Array<[string, string[]]> = [
  ["pixel art", ["pixel art"]],
  ["anime", ["anime", "anime girls", "anime boys", "manga"]],
  ["comic art", ["comic art", "comics", "comic books"]],
  ["minimal", ["minimalism"]],
  ["photography", ["photography", "photo"]],
  ["3d", ["cgi", "3d", "render", "digital render", "blender"]],
  ["digital art", ["digital art", "artwork", "fantasy art", "illustration", "painting", "concept art", "drawing",
    "artstation", "fan art", "digital painting"]],
];
const GENERIC_STYLE = "digital art";
export function artStyle(wall: Pick<WallhavenWall, "tags" | "category">): string | null {
  if (wall.category === "anime") return "anime";
  const tags = new Set(wall.tags.map((tag) => tag.toLowerCase()));
  return ART_STYLES.find(([, names]) => names.some((name) => tags.has(name)))?.[0] ?? null;
}

/** 64-bit difference hash as 64 "0"/"1" characters. Wallhaven holds re-uploads of one image under new ids. */
export async function dHash(jpeg: Buffer): Promise<string> {
  const {default: sharp} = await import("sharp");
  const px = await sharp(jpeg).greyscale().resize(9, 8, {fit: "fill"}).raw().toBuffer();
  let hash = "";
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 8; x++) hash += px[y * 9 + x] > px[y * 9 + x + 1] ? "1" : "0";
  }
  return hash;
}
const NEAR_DUPLICATE_BITS = 8;
/**
 * Tags of portrait and pin-up art. Sets and stills skip them: in subject themes (Spider-Man, Star Wars) most top walls
 * were pin-ups that "-women" alone missed, which broke the set's look.
 */
const MAX_SET_TAGS = 30;
export const PORTRAIT_TAGS = new Set(["women", "fantasy girl", "anime girls", "looking at viewer", "cleavage", "blonde",
  "brunette", "redhead", "long hair", "short hair", "model", "portrait", "face", "girls", "cosplay", "bodysuit", "thighs",
  "boobs", "legs", "lingerie", "bikini", "stockings", "pantyhose", "gwen stacy"]);
const bitsApart = (a: string, b: string) => [...a].filter((bit, i) => bit !== b[i]).length;

export interface WallhavenDeps {
  annotate: VisionAnnotate;
  details: (id: string, deadline?: number) => Promise<WallhavenWall>;
  download: (url: string) => Promise<Buffer>;
  deadlineMs?: number;
}
const wallhavenDeps: WallhavenDeps = {annotate: annotateWithVision, details: (id, deadline) => wallhavenDetails(id, deadline),
  download: (url) => downloadJpeg(url, 2400)};

interface Picked {wall: WallhavenWall; jpeg: Buffer; sensitive: boolean; style?: string}

/**
 * Checks candidates in order until `count` pass, the detail budget is spent, or the deadline passes. `strict` (sets and
 * stills) takes SFW walls with no flag hint only, and drops near-duplicates. Null when fewer than `min` pass.
 * `oneStyle` first reads details only, groups the walls by `artStyle`, then downloads the largest group alone, so a
 * set never mixes comic art with photos or anime.
 */
async function pickWallhaven(candidates: (deadline: number) => Promise<WallhavenCandidate[]>, exclude: Set<string>,
  opts: {count: number; min: number; budget: number; deadlineMs: number; sketchyPerPost: number; blockedTags: string[];
    strict: boolean; oneStyle?: boolean; deadline?: number}, deps: WallhavenDeps): Promise<Picked[] | null> {
  const picked: Picked[] = [];
  const hashes: string[] = [];
  let sketchy = 0;
  let checked = 0;
  const blocked = opts.blockedTags.map((t) => t.toLowerCase());
  const deadline = opts.deadline ?? Date.now() + (deps.deadlineMs ?? opts.deadlineMs);
  // The checks on Wallhaven's details alone: null when the wall cannot pass.
  const detailsOk = async (candidate: WallhavenCandidate) => {
    const wall = await deps.details(candidate.id, deadline);
    if (Date.now() >= deadline) return null;
    if (wall.purity !== candidate.purity || !(opts.strict ? ["sfw"] : ["sfw", "sketchy"]).includes(wall.purity)) return null;
    if (wall.tags.some((tag) => YOUTH_TAG.test(tag) || blocked.includes(tag.toLowerCase()))) return null;
    if (opts.strict && wall.tags.some((tag) => PORTRAIT_TAGS.has(tag.toLowerCase()))) return null;
    // A wall tagged with dozens of franchises is a collage poster, not one subject.
    if (opts.strict && wall.tags.length > MAX_SET_TAGS) return null;
    if (!/^https:\/\/w\.wallhaven\.cc\//.test(wall.path)) return null;
    return wall;
  };
  // One candidate: null when it does not pass.
  const check = async (candidate: WallhavenCandidate) => {
    const wall = await detailsOk(candidate);
    return wall ? imageOk(wall) : null;
  };
  const imageOk = async (wall: WallhavenWall) => {
    if (Date.now() >= deadline) return null;
    const jpeg = await fitFiveMb(await deps.download(wall.path));
    if (Date.now() >= deadline) return null;
    const decision = gridVisionDecision((await deps.annotate(jpeg)).safeSearchAnnotation as Record<string, unknown>);
    if (Date.now() >= deadline) return null;
    if (!decision.ok || (opts.strict && decision.sensitive)) return null;
    const hash = opts.strict ? await dHash(jpeg) : "";
    if (opts.strict && hashes.some((h) => bitsApart(h, hash) <= NEAR_DUPLICATE_BITS)) return null;
    return {wall, jpeg, sensitive: decision.sensitive, hash};
  };
  const bounded = async <T>(work: Promise<T>): Promise<T | "timeout"> => {
    let timer: NodeJS.Timeout | undefined;
    const timedOut = new Promise<"timeout">((resolve) => {
      timer = setTimeout(() => resolve("timeout"), Math.max(0, deadline - Date.now()));
    });
    const result = await Promise.race([work, timedOut]).finally(() => clearTimeout(timer));
    return Date.now() >= deadline ? "timeout" : result;
  };
  const pool = await bounded(candidates(deadline));
  if (pool === "timeout") return null;
  if (opts.oneStyle) {
    // Phase 1: details only, grouped by medium. Stops early once one group has enough to spare for image rejects.
    const groups = new Map<string, WallhavenWall[]>();
    for (const candidate of pool) {
      if (checked >= opts.budget || Date.now() >= deadline) break;
      if (exclude.has(candidate.id)) continue;
      checked++;
      const wall = await bounded(detailsOk(candidate).catch(() => null));
      if (wall === "timeout") break;
      const style = wall ? artStyle(wall) : null;
      if (!wall || !style) continue;
      groups.set(style, [...(groups.get(style) ?? []), wall]);
      // "digital art" is the catch-all, so only a specific style may end the scan early.
      if (style !== GENERIC_STYLE && (groups.get(style)?.length ?? 0) >= opts.count + 4) break;
    }
    // Phase 2: specific styles before the catch-all, then the largest; a group whose images fail falls to the next.
    const ranked = [...groups].filter(([, walls]) => walls.length >= opts.min).sort((a, b) =>
      Number(a[0] === GENERIC_STYLE) - Number(b[0] === GENERIC_STYLE) || b[1].length - a[1].length);
    for (const [style, walls] of ranked) {
      picked.length = 0;
      hashes.length = 0;
      for (const wall of walls) {
        if (picked.length === opts.count || Date.now() >= deadline) break;
        const result = await bounded(imageOk(wall).catch(() => null));
        if (result === "timeout") break;
        if (!result) continue;
        hashes.push(result.hash);
        picked.push({...result, style});
      }
      if (picked.length >= opts.min) return picked;
    }
    return null;
  }
  for (const candidate of pool) {
    if (picked.length === opts.count || checked >= opts.budget || Date.now() >= deadline) break;
    if (exclude.has(candidate.id) || (candidate.purity === "sketchy" && sketchy >= opts.sketchyPerPost)) continue;
    checked++;
    // The deadline also bounds a check in flight, so a slow download cannot use up the run. One wall's failure (a 404,
    // a failed download) skips that wall and keeps the walls already picked.
    const result = await bounded(check(candidate).catch(() => null));
    if (result === "timeout") break;
    if (!result) continue;
    if (result.wall.purity === "sketchy") sketchy++;
    hashes.push(result.hash);
    picked.push(result);
  }
  return picked.length >= opts.min ? picked : null;
}

export async function gridContent(day: string, exclude: Set<string>, config: {sketchyPerPost: number; blockedTags: string[]},
  deps: WallhavenDeps & {candidates: typeof wallhavenCandidates} = {...wallhavenDeps, candidates: wallhavenCandidates}):
  Promise<SocialContent | null> {
  const picked = await pickWallhaven((deadline) => deps.candidates(deadline), exclude, {count: 3, min: 3,
    budget: GRID_DETAIL_BUDGET,
    deadlineMs: GRID_DEADLINE_MS, sketchyPerPost: config.sketchyPerPost, blockedTags: config.blockedTags, strict: false},
  deps);
  if (!picked) return null;
  return {
    pipeline: "grid",
    source: {kind: "wallhaven", ids: picked.map((p) => p.wall.id), tags: picked.flatMap((p) => p.wall.tags)},
    media: picked.map((p, i) => ({jpeg: p.jpeg, sensitive: false, suggestFlag: p.sensitive,
      alt: `Phone wallpaper ${i + 1} of 3${p.wall.tags.length ? `: ${p.wall.tags.slice(0, 4).join(", ")}` : ""}.`})),
    text: rotate(GRID_LINES, day),
    replyText: NO_REPLY,
  };
}

// ---------- P7 daily themed set ----------

/** Walls in a set. X takes up to 20 photos in one post; 12 keeps the carousel tight. */
export const SET_SIZE = 12;
export const SET_MIN = 8;
/**
 * Details read per set. A subject theme (Batman) spreads its top walls over several styles; its comic art group held
 * 13 of the top 40. Searches and details share the 45-a-minute limiter.
 */
export const SET_DETAIL_BUDGET = 40;
export const SET_DEADLINE_MS = 120_000;

/**
 * Up to 12 SFW walls of one theme and one medium, like a curated thread. Themes rotate daily. When the day's theme has
 * no style group of 8 left, the next theme takes the rest of the time.
 */
export async function setContent(day: string, exclude: Set<string>, config: {blockedTags: string[]},
  deps: WallhavenDeps & {candidates: typeof wallhavenThemeCandidates} =
  {...wallhavenDeps, candidates: wallhavenThemeCandidates}): Promise<SocialContent | null> {
  const end = Date.now() + (deps.deadlineMs ?? SET_DEADLINE_MS);
  let theme: Theme = rotate(THEMES, day);
  let picked: Picked[] | null = null;
  for (const offset of [0, 1]) {
    if (Date.now() >= end) break;
    theme = rotate(THEMES, day, offset);
    const query = theme.query;
    const categories = theme.categories;
    // Each theme gets the full detail budget: a thin theme can use most of it and still fail. The shared limiter and
    // deadline bound the requests.
    const budget = SET_DETAIL_BUDGET;
    picked = await pickWallhaven((deadline) => deps.candidates(query, deadline, exclude, budget, categories),
      exclude,
      {count: SET_SIZE, min: SET_MIN, budget, deadlineMs: SET_DEADLINE_MS, deadline: end, sketchyPerPost: 0,
        blockedTags: config.blockedTags, strict: true, oneStyle: true}, deps)
      .catch(() => null);
    if (picked) break;
  }
  if (!picked) return null;
  const style = picked[0].style ?? "";
  const medium = style && !theme.name.includes(style) ? `, all ${style}` : "";
  return {
    pipeline: "set",
    source: {kind: "wallhaven", ids: picked.map((p) => p.wall.id), tags: picked.flatMap((p) => p.wall.tags)},
    media: picked.map((p, i) => ({jpeg: p.jpeg, sensitive: false,
      alt: `${theme.name} phone wallpaper ${i + 1} of ${picked.length}${p.wall.tags.length ?
        `: ${p.wall.tags.slice(0, 4).join(", ")}` : ""}.`})),
    text: `${picked.length} ${theme.name} wallpapers${medium}\nwhich one is yours? 👇`,
    replyText: NO_REPLY,
  };
}

/** Checks per themed still. The first walls of a theme are its best, so few checks are needed. */
export const THEMED_STILL_BUDGET = 8;
export const THEMED_STILL_DEADLINE_MS = 45_000;

/**
 * The most favourited SFW wall of a theme not posted yet. Eve and night use different themes (offsets 3 and 5), and
 * both differ from the day's set theme (offset 0, or 1 when that theme runs dry).
 */
export async function themedStillContent(day: string, exclude: Set<string>, config: {blockedTags: string[]}, salt: number,
  deps: WallhavenDeps & {candidates: typeof wallhavenThemeCandidates} =
  {...wallhavenDeps, candidates: wallhavenThemeCandidates}): Promise<SocialContent | null> {
  const theme = rotate(THEMES, day, salt === 0 ? 3 : 5);
  const picked = await pickWallhaven((deadline) => deps.candidates(theme.query, deadline, exclude, THEMED_STILL_BUDGET,
    theme.categories),
  exclude, {count: 1, min: 1,
    budget: THEMED_STILL_BUDGET, deadlineMs: THEMED_STILL_DEADLINE_MS, sketchyPerPost: 0, blockedTags: config.blockedTags,
    strict: true}, deps);
  if (!picked) return null;
  const [{wall, jpeg}] = picked;
  return {
    pipeline: "still",
    source: {kind: "wallhaven", ids: [wall.id], tags: wall.tags},
    media: [{jpeg, sensitive: false,
      alt: `${theme.name} phone wallpaper${wall.tags.length ? `: ${wall.tags.slice(0, 4).join(", ")}` : ""}.`}],
    text: themedStillCaption(theme.name, day, salt),
    replyText: NO_REPLY,
  };
}

export async function wallhavenDetails(id: string, deadline = Infinity): Promise<WallhavenWall> {
  const data = (await wallhavenJson(`/w/${encodeURIComponent(id)}`, deadline))?.data;
  return {id, purity: str(data?.purity), path: str(data?.path), category: str(data?.category),
    tags: Array.isArray(data?.tags) ? data.tags.map((t: any) => str(t?.name)).filter(Boolean) : []};
}

/** Every post and reply must fit X's 280 weighted characters. */
export function assertFits(content: SocialContent): void {
  if (xWeightedLength(content.text) > 280 || xWeightedLength(content.replyText) > 280) {
    throw new Error(`${content.pipeline} text is over 280 weighted characters.`);
  }
}
