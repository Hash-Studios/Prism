import * as admin from "firebase-admin";
import {getRemoteConfig} from "firebase-admin/remote-config";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {db, REGION, str} from "./common";
import {isPreviewUrl} from "./pushGallery";
import {isSectionId, publicFolderName, publicFolderSections, type PublicSection} from "./publicFolders";
import {DISCOVER_WEB_PAGE, FOLDER_TRENDING, FOLDER_TRENDING_DOC} from "./folderSignals";
import {hasBlockedWord} from "./textSafety";
import {r2Secrets} from "./r2Storage";
import {parseDesktopVariant, readyDesktopCompanion} from "./studio/desktop";
import {PALETTE} from "./wallColors";
import {isWotdEligible, parseCollectionList} from "./wallEligibility";

/**
 * The public web catalogue on prismwalls.com. Crawlers read these collections through the links Worker, with no
 * sign-in, so every field here is public by construction: no uid, email, original URL, storage path or moderation
 * data is ever copied in. `webWalls/{shareId}` follows each wall at once, so a takedown leaves the web in minutes.
 * `webPages/{key}` holds every list page, built on a schedule so one page view costs one document read.
 */
export const WEB_WALLS = "webWalls";
export const WEB_PAGES = "webPages";
const STATE = "webCatalogState";
export const PAGE_SIZE = 24;
const FOLDER_WALLS = 60;
const CREATOR_FOLDERS = 12;
// Keep serialized sitemap pages below Firestore's 1 MiB document limit, including worst-case URL lengths.
const SITEMAP_SIZE = 3000;
const WRITE_CHUNK = 100;
// Walls projected at once in a rebuild. Each one can fetch and blur a thumbnail, so keep it below WRITE_CHUNK.
const WALL_CHUNK = 40;
const SHARE_ID = /^[A-Za-z0-9_-]{1,200}$/;
const USERNAME = /^[A-Za-z0-9._-]{1,40}$/;
const HIDDEN_TEXT = /[\p{Cc}\p{Cf}\p{Co}\p{Cn}\p{Zl}\p{Zp}]/gu;
const PALETTE_HEX = new Map(PALETTE.map(({id, hex}) => [id, `#${hex}`]));
const RELEVANT_FIELDS = ["id", "review", "originalProtected", "is_streak_exclusive", "dropReserved", "dropWeek",
  "collections", "wallpaper_thumb", "title", "desc", "tags", "category", "colors", "resolution", "by", "creatorUid",
  "createdAt", "desktopVariant"];

type Doc = admin.firestore.DocumentData;

/** live: indexable with its image. gated: premium or exclusive, blurred. hidden: 404. gone: deleted, 410. */
export type WebWallState = "live" | "gated" | "hidden" | "gone";

export interface WebCreator {username: string; name: string}

export interface WebWall {
  state: WebWallState;
  updatedAt: string;
  title?: string;
  description?: string;
  category?: string;
  categorySlug?: string;
  tags?: string[];
  colors?: Array<{name: string; hex: string}>;
  width?: number;
  height?: number;
  createdAt?: string;
  creatorName?: string;
  creator?: WebCreator | null;
  thumb?: string;
  blur?: string;
  blurKey?: string;
  /** Live walls only: the desktop companion's public thumbnail and version. */
  desktop?: WebDesktop;
}

export interface WebDesktop {v: string; thumb: string; width: number; height: number}

export interface WebCard {id: string; title: string; thumb: string; width: number; height: number}
export interface WebDesktopCard extends WebCard {desktop: string}

interface PublicProfile {username: string; name: string; bio: string; photo: string}

/** Seams for tests: Remote Config and image fetches are outside the fake database. */
export const webCatalogDeps: {
  premium: () => Promise<string[]>;
  blur: (thumb: string) => Promise<string>;
  now: () => Date;
} = {
  premium: async () => {
    const template = await getRemoteConfig().getTemplate();
    const value = (template.parameters?.premiumCollections?.defaultValue as {value?: string} | undefined)?.value;
    if (typeof value !== "string" || !value.trim()) throw new Error("premiumCollections is empty or missing");
    const raw = value.trim();
    if (raw.startsWith("[")) {
      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        throw new Error("premiumCollections is invalid");
      }
      if (!Array.isArray(parsed) || parsed.length === 0 ||
        parsed.some((item) => typeof item !== "string" || item.trim() === "")) {
        throw new Error("premiumCollections is invalid");
      }
      return parsed.map((item: string) => item.trim());
    }
    if (["[", "]", "{", "}", "\""].some((character) => raw.includes(character))) {
      throw new Error("premiumCollections is invalid");
    }
    const parsed = parseCollectionList(raw);
    if (parsed.length === 0 || parsed.some((item) => item.trim() === "")) throw new Error("premiumCollections is invalid");
    return parsed;
  },
  blur: blurPreview,
  now: () => new Date(),
};

/** A tiny blurred JPEG data URL. It shows the mood of a gated wall and is too small to use as a wallpaper. */
async function blurPreview(thumb: string): Promise<string> {
  const response = await fetch(thumb, {signal: AbortSignal.timeout(10_000)});
  if (!response.ok) throw new Error(`thumb ${response.status}`);
  const {default: sharp} = await import("sharp");
  const bytes = await sharp(Buffer.from(await response.arrayBuffer()), {limitInputPixels: 50_000_000})
    .resize({width: 24}).blur(1.2).jpeg({quality: 45}).toBuffer();
  return `data:image/jpeg;base64,${bytes.toString("base64")}`;
}

export function cleanText(value: unknown, max: number): string {
  const text = str(value).replace(HIDDEN_TEXT, " ").replace(/\s+/g, " ").trim();
  return text.length <= max ? text : `${text.slice(0, max - 1).trimEnd()}…`;
}

export function categorySlug(category: string): string {
  return category.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "general";
}

function isoOf(value: unknown): string {
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value.toISOString();
  return "";
}

function dimensions(resolution: unknown): {width: number; height: number} {
  const match = /^\s*(\d{2,5})\s*[x×*]\s*(\d{2,5})\s*$/i.exec(str(resolution));
  return match ? {width: Number(match[1]), height: Number(match[2])} : {width: 0, height: 0};
}

function publicProfile(data: Doc | undefined): PublicProfile | null {
  const username = str(data?.username).trim();
  if (!isCreatorUsername(username)) return null;
  return {
    username,
    name: cleanText(data?.name, 60) || username,
    bio: cleanText(data?.bio, 300),
    photo: isProfilePhotoUrl(str(data?.profilePhoto)) ? str(data?.profilePhoto) : "",
  };
}

function isCreatorUsername(username: string): boolean {
  return USERNAME.test(username) && username !== "." && username !== "..";
}

// Users control profilePhoto, so public embeds stay on hosts used by Prism's profile flows.
const PROFILE_PHOTO_HOSTS = ["raw.githubusercontent.com", "firebasestorage.googleapis.com"];

function isProfilePhotoUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password && !url.port &&
      (PROFILE_PHOTO_HOSTS.includes(url.hostname) || url.hostname.endsWith(".googleusercontent.com"));
  } catch {
    return false;
  }
}

function isBlurDataUrl(value: string | undefined): value is string {
  return value !== undefined && /^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(value);
}

/**
 * The public copy of one wall. `wall` is the only approved wall doc with this share id, or undefined when there is
 * none. A gated wall keeps its text, so its page can say what it is, but never its image.
 */
export async function projectWall(
  wall: Doc | undefined, premium: string[], profile: PublicProfile | null, previous: WebWall | undefined, now: Date,
  tx?: admin.firestore.Transaction,
): Promise<WebWall> {
  const updatedAt = now.toISOString();
  if (!wall) return {state: "gone", updatedAt};
  if (wall.review !== true) return {state: "hidden", updatedAt};
  const thumb = str(wall.wallpaper_thumb);
  const live = isWotdEligible(wall, premium) && isPreviewUrl(thumb);
  const category = cleanText(wall.category, 40) || "General";
  const projected: WebWall = {
    state: live ? "live" : "gated",
    updatedAt,
    title: cleanText(wall.title, 90),
    description: cleanText(wall.desc, 300),
    category,
    categorySlug: categorySlug(category),
    tags: (Array.isArray(wall.tags) ? wall.tags : []).map((tag) => cleanText(tag, 32)).filter(Boolean).slice(0, 12),
    colors: (Array.isArray(wall.colors) ? wall.colors : []).map(str)
      .filter((name) => PALETTE_HEX.has(name)).map((name) => ({name, hex: PALETTE_HEX.get(name) as string})),
    ...dimensions(wall.resolution),
    createdAt: isoOf(wall.createdAt),
    creatorName: profile?.name || cleanText(wall.by, 60),
    creator: profile ? {username: profile.username, name: profile.name} : null,
  };
  if (live) {
    let desktop = parseDesktopVariant(wall.desktopVariant);
    if (desktop) {
      try {
        desktop = (await readyDesktopCompanion(str(wall.id), wall, tx)).variant;
      } catch {
        desktop = null;
      }
    }
    return {...projected, thumb,
      ...(desktop ? {desktop: {v: desktop.v, thumb: desktop.thumb, width: desktop.width, height: desktop.height}} : {})};
  }
  if (!isPreviewUrl(thumb)) return projected;
  const blurKey = createHash("sha256").update(thumb).digest("hex").slice(0, 16);
  if (previous?.blurKey === blurKey && isBlurDataUrl(previous.blur)) return {...projected, blur: previous.blur, blurKey};
  try {
    return {...projected, blur: await webCatalogDeps.blur(thumb), blurKey};
  } catch (error) {
    logger.warn("webCatalog: no blurred preview for a gated wall.", {error: String(error)});
    return projected;
  }
}

function stableJson(value: unknown): string {
  return JSON.stringify(value, (_, v) => v && typeof v === "object" && !Array.isArray(v) ?
    Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}

/** The same wall, ignoring the time it was written. Unchanged walls keep their old updatedAt, so lastmod is honest. */
function sameWall(a: WebWall | undefined, b: WebWall): boolean {
  return a !== undefined && stableJson({...a, updatedAt: ""}) === stableJson({...b, updatedAt: ""});
}

async function profilesOf(uids: string[]): Promise<Map<string, PublicProfile>> {
  const found = new Map<string, PublicProfile>();
  const unique = [...new Set(uids.filter((uid) => uid && !uid.includes("/")))];
  for (let i = 0; i < unique.length; i += WRITE_CHUNK) {
    await Promise.all(unique.slice(i, i + WRITE_CHUNK).map(async (uid) => {
      const profile = publicProfile((await db.collection("profiles").doc(uid).get()).data());
      if (profile) found.set(uid, profile);
    }));
  }
  return found;
}

/**
 * Re-projects one share id from the current walls, not from the event, so retried or late events converge. Two
 * walls with one share id are hidden: the page could not tell which one a link meant.
 */
export async function syncWebWall(shareId: string): Promise<void> {
  if (!SHARE_ID.test(shareId)) return;
  let premium: string[] = [];
  let premiumError: unknown;
  try {
    premium = await webCatalogDeps.premium();
  } catch (error) {
    premiumError = error;
  }
  const ref = db.collection(WEB_WALLS).doc(shareId);
  await db.runTransaction(async (tx) => {
    const [rows, previousSnap] = await Promise.all([
      tx.get(db.collection("walls").where("id", "==", shareId).limit(2)), tx.get(ref),
    ]);
    const previous = previousSnap.data() as WebWall | undefined;
    if (rows.size === 0 && !previous) return;
    const wall = rows.size === 1 ? rows.docs[0].data() : undefined;
    if (wall?.review === true && premiumError) throw premiumError;
    const uid = str(wall?.creatorUid);
    const profile = uid && !uid.includes("/") ?
      publicProfile((await tx.get(db.collection("profiles").doc(uid))).data()) : null;
    const next = rows.size > 1 ?
      {state: "hidden" as const, updatedAt: webCatalogDeps.now().toISOString()} :
      await projectWall(wall, premium, profile, previous, webCatalogDeps.now(), tx);
    if (!sameWall(previous, next)) tx.set(ref, next);
  });
}

/** Walls take frequent counter writes. Only a change to a field the page shows, or to its gate, re-projects. */
export function isCatalogChange(before: Doc | undefined, after: Doc | undefined): boolean {
  if (!before || !after) return true;
  return RELEVANT_FIELDS.some((field) => stableJson(before[field]) !== stableJson(after[field]));
}

export const onWallWebCatalog = onDocumentWritten(
  {document: "walls/{wallId}", region: REGION, retry: true, memory: "512MiB", secrets: r2Secrets},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!isCatalogChange(before, after)) return;
    const ids = new Set([str(before?.id), str(after?.id)].filter(Boolean));
    for (const id of ids) await syncWebWall(id);
  },
);

interface PageDoc {kind: string; [key: string]: unknown}

function cardOf(id: string, wall: WebWall): WebCard {
  return {id, title: wall.title ?? "", thumb: wall.thumb ?? "", width: wall.width ?? 0, height: wall.height ?? 0};
}

function chunks<T>(values: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < values.length; i += size) out.push(values.slice(i, i + size));
  return out.length > 0 ? out : [[]];
}

function paged(prefix: string, base: PageDoc, cards: WebCard[]): Array<[string, PageDoc]> {
  const pages = chunks(cards, PAGE_SIZE);
  return pages.map((items, index) => [`${prefix}~${index + 1}`,
    {...base, page: index + 1, pages: pages.length, total: cards.length, items}]);
}

function newest(a: [string, WebWall], b: [string, WebWall]): number {
  return (b[1].createdAt ?? "").localeCompare(a[1].createdAt ?? "") || a[0].localeCompare(b[0]);
}

function maxDate(values: string[]): string {
  return values.reduce((best, value) => value > best ? value : best, "");
}

function sitemap(name: string, entries: Array<[string, string]>): Array<[string, PageDoc]> {
  return chunks(entries, SITEMAP_SIZE).map((part, index) => [`sitemap~${name}-${index + 1}`, {
    kind: "sitemap",
    lastmod: maxDate(part.map(([, lastmod]) => lastmod)),
    entries: part.map(([path, lastmod]) => `${path}\t${lastmod}`).join("\n"),
  }]);
}

/**
 * Every list page, from the public wall copies alone, plus public folders and profiles. Pure apart from its inputs,
 * so a test can check the whole catalogue from a seed.
 */
export function buildPages(
  walls: Map<string, WebWall>, popularIds: string[], folders: Array<{id: string; name: string; owner: PublicProfile | null;
    wallIds: string[]; updatedAt: string; total?: number; sections?: PublicSection[];
    sectionOf?: Record<string, string>; discoveryHidden?: boolean; discoveryEligible?: boolean}>, creators: Map<string, PublicProfile>,
  discover: {trending: string[]; new: string[]} = {trending: [], new: []},
): Map<string, PageDoc> {
  const live = [...walls].filter(([, wall]) => wall.state === "live").sort(newest);
  // Popular ids and folder items carry the share id in upper case, the way wallpaper_stats keys it.
  const liveById = new Map(live.map((entry): [string, [string, WebWall]] => [entry[0].toUpperCase(), entry]));
  const profileByName = new Map([...creators.values()].filter((p) => isCreatorUsername(p.username))
    .map((p) => [p.username.toLowerCase(), p]));
  const cards = (entries: Array<[string, WebWall]>) => entries.map(([id, wall]) => cardOf(id, wall));
  const byCategory = new Map<string, Array<[string, WebWall]>>();
  const byCreator = new Map<string, Array<[string, WebWall]>>();
  for (const entry of live) {
    const slug = entry[1].categorySlug ?? "general";
    byCategory.set(slug, [...(byCategory.get(slug) ?? []), entry]);
    const username = entry[1].creator?.username.toLowerCase();
    if (username) byCreator.set(username, [...(byCreator.get(username) ?? []), entry]);
  }
  const hasCreatorPage = (username: string) => byCreator.has(username.toLowerCase()) &&
    profileByName.has(username.toLowerCase());
  const categories = [...byCategory].map(([slug, entries]) => ({
    slug, name: entries[0][1].category ?? "General", count: entries.length, cover: entries[0][1].thumb ?? "",
  })).sort((a, b) => b.count - a.count || a.slug.localeCompare(b.slug));
  const pages = new Map<string, PageDoc>();
  const add = (list: Array<[string, PageDoc]>) => list.forEach(([key, doc]) => pages.set(key, doc));

  add(paged("latest", {kind: "latest", categories}, cards(live)));
  const popular = [...new Set(popularIds.map((id) => id.toUpperCase()))]
    .flatMap((id) => {
      const entry = liveById.get(id);
      return entry ? [entry] : [];
    });
  add(paged("popular", {kind: "popular", categories}, cards(popular)));
  for (const [slug, entries] of byCategory) {
    add(paged(`category~${slug}`, {kind: "category", slug, name: entries[0][1].category, categories}, cards(entries)));
  }
  // One list serves both /desktop-wallpapers and /matching-sets: the same walls, shown as desktops or as pairs.
  const desktops = live.filter(([, wall]) => wall.desktop);
  add(paged("desktop", {kind: "desktop"}, desktops.map(([id, wall]): WebDesktopCard =>
    ({...cardOf(id, wall), desktop: wall.desktop?.thumb ?? ""}))));

  const publicFolders = folders.map((folder) => {
    const shown = folder.wallIds.flatMap((id) => {
      const entry = liveById.get(id.toUpperCase());
      return entry ? [{card: cardOf(...entry), sectionId: folder.sectionOf?.[id]}] : [];
    }).slice(0, FOLDER_WALLS);
    const {items, groups} = sectionGroups(shown, folder.sections ?? []);
    return {...folder, items, groups};
  });
  for (const folder of publicFolders) {
    pages.set(`folder~${folder.id}`, {
      kind: "folder", id: folder.id, name: folder.name, updatedAt: folder.updatedAt,
      owner: folder.owner ? {
        username: folder.owner.username, name: folder.owner.name, hasPage: hasCreatorPage(folder.owner.username),
      } : null,
      total: folder.total ?? folder.wallIds.length, items: folder.items,
      ...(folder.groups.length ? {groups: folder.groups} : {}),
    });
  }

  // The /folders page lists the discover folders that are still public, not hidden and have a live wall.
  const discoverable = new Map(publicFolders.filter((f) => f.discoveryHidden !== true && f.discoveryEligible !== false &&
    f.items.length > 0)
    .map((f) => [f.id, f]));
  const discoverCards = (ids: string[]) => ids.flatMap((id) => {
    const folder = discoverable.get(id);
    return folder ? [{
      id, name: folder.name, total: folder.total ?? folder.wallIds.length, covers: folder.items.slice(0, 4).map((c) => c.thumb),
      owner: folder.owner ? {username: folder.owner.username, name: folder.owner.name,
        hasPage: hasCreatorPage(folder.owner.username)} : null,
    }] : [];
  });
  const discoverPage = {kind: DISCOVER_WEB_PAGE, trending: discoverCards(discover.trending), new: discoverCards(discover.new)};
  if (discoverPage.trending.length || discoverPage.new.length) pages.set(DISCOVER_WEB_PAGE, discoverPage);

  const creatorPages: Array<[string, string]> = [];
  for (const [username, entries] of byCreator) {
    const profile = profileByName.get(username);
    if (!profile) continue;
    const owned = publicFolders.filter((f) => f.owner?.username.toLowerCase() === username && f.items.length > 0)
      .slice(0, CREATOR_FOLDERS).map((f) => ({id: f.id, name: f.name, total: f.total ?? f.wallIds.length, cover: f.items[0].thumb}));
    add(paged(`creator~${username}`, {kind: "creator", creator: profile, folders: owned}, cards(entries)));
    creatorPages.push([`/creator/${encodeURIComponent(profile.username)}`, maxDate(entries.map(([, w]) => w.updatedAt))]);
  }

  const wallEntries = live.map(([id, wall]): [string, string] => [`/wallpaper/${id}`, wall.updatedAt]);
  const hubEntries: Array<[string, string]> = [
    ["/wallpapers", maxDate(live.map(([, w]) => w.updatedAt))],
    ["/wallpapers/popular", maxDate(popular.map(([, w]) => w.updatedAt))],
    ...[...byCategory].map(([slug, entries]): [string, string] =>
      [`/wallpapers/${slug}`, maxDate(entries.map(([, w]) => w.updatedAt))]),
    ...(desktops.length ? ["/desktop-wallpapers", "/matching-sets"].map((path): [string, string] =>
      [path, maxDate(desktops.map(([, w]) => w.updatedAt))]) : []),
    ...(pages.has(DISCOVER_WEB_PAGE) ? [["/folders", maxDate([...discoverable.values()].map((f) => f.updatedAt))] as [string, string]] : []),
  ];
  const folderEntries = publicFolders.filter((f) => f.items.length > 0)
    .map((f): [string, string] => [`/folder/${f.id}`, f.updatedAt]);
  const sitemaps = [
    ...sitemap("walls", wallEntries), ...sitemap("categories", hubEntries),
    ...sitemap("folders", folderEntries), ...sitemap("creators", creatorPages),
  ].filter(([, doc]) => (doc.entries as string).length > 0);
  add(sitemaps);
  pages.set("sitemap~index", {
    kind: "sitemap-index",
    sitemaps: sitemaps.map(([key, doc]) => ({name: key.slice("sitemap~".length), lastmod: doc.lastmod})),
  });
  return pages;
}

const hashOf = (doc: PageDoc) => createHash("sha256").update(stableJson(doc)).digest("hex").slice(0, 20);

async function inChunks<T>(values: T[], run: (value: T) => Promise<unknown>, size = WRITE_CHUNK): Promise<void> {
  for (let i = 0; i < values.length; i += size) await Promise.all(values.slice(i, i + size).map(run));
}

/**
 * Orders a folder page's walls as the app shows them: Unsorted first, then each section in order, each newest first.
 * `groups` names each run of `items`; "" is Unsorted. It is empty when no shown wall is in a section, so a folder
 * without sections keeps its old page.
 */
export function sectionGroups(shown: Array<{card: WebCard; sectionId?: string}>, sections: PublicSection[]):
  {items: WebCard[]; groups: Array<{name: string; count: number}>} {
  const known = new Set(sections.map((section) => section.id));
  const unsorted = shown.filter((wall) => !wall.sectionId || !known.has(wall.sectionId)).map((wall) => wall.card);
  const named = sections.map((section) => ({
    name: section.name, cards: shown.filter((wall) => wall.sectionId === section.id).map((wall) => wall.card),
  })).filter((group) => group.cards.length > 0);
  if (named.length === 0) return {items: shown.map((wall) => wall.card), groups: []};
  return {
    items: [...unsorted, ...named.flatMap((group) => group.cards)],
    groups: [...(unsorted.length ? [{name: "", count: unsorted.length}] : []),
      ...named.map((group) => ({name: group.name, count: group.cards.length}))],
  };
}

/**
 * Rebuilds the whole catalogue. It re-projects every wall too, so a missed trigger or a renamed creator heals here.
 * Docs are written only when they change, and a page that no longer exists is deleted.
 */
export async function rebuildWebCatalog(): Promise<{walls: number; pages: number; written: number}> {
  const now = webCatalogDeps.now();
  const premium = await webCatalogDeps.premium();
  const [approved, existing, popularDoc, folderDocs, manifestDoc, discoverDoc] = await Promise.all([
    db.collection("walls").get(),
    db.collection(WEB_WALLS).get(),
    db.collection("popular").doc("current").get(),
    db.collection("publicFolders").get(),
    db.collection(STATE).doc("pages").get(),
    db.collection(FOLDER_TRENDING).doc(FOLDER_TRENDING_DOC).get(),
  ]);
  const previous = new Map(existing.docs.map((doc) => [doc.id, doc.data() as WebWall]));
  const byId = new Map<string, Doc[]>();
  for (const doc of approved.docs) {
    const id = str(doc.data().id);
    if (SHARE_ID.test(id)) byId.set(id, [...(byId.get(id) ?? []), doc.data()]);
  }
  const ownerIds = folderDocs.docs.map((doc) => str(doc.data().ownerId));
  const profiles = await profilesOf([...[...byId.values()].flat().map((wall) => str(wall.creatorUid)), ...ownerIds]);

  let written = 0;
  const ids = [...new Set([...byId.keys(), ...previous.keys()])];
  const projected = new Map<string, WebWall>();
  // One wall at a time could not finish a cold build of ~3,300 walls inside the timeout, so walls run in chunks.
  await inChunks(ids, async (id) => {
    const rows = byId.get(id) ?? [];
    const wall = rows.length === 1 ? rows[0] : undefined;
    const candidate = rows.length > 1 ? {state: "hidden" as const, updatedAt: now.toISOString()} :
      rows.length === 0 ? {state: "gone" as const, updatedAt: now.toISOString()} :
        await projectWall(wall, premium, profiles.get(str(wall?.creatorUid)) ?? null, previous.get(id), now);
    const old = previous.get(id);
    if (sameWall(old, candidate)) {
      projected.set(id, old as WebWall);
      return;
    }
    const ref = db.collection(WEB_WALLS).doc(id);
    const current = await db.runTransaction(async (tx) => {
      const [latestRows, previousSnap] = await Promise.all([
        tx.get(db.collection("walls").where("id", "==", id).limit(2)), tx.get(ref),
      ]);
      const currentPrevious = previousSnap.data() as WebWall | undefined;
      const latestWall = latestRows.size === 1 ? latestRows.docs[0].data() : undefined;
      const uid = str(latestWall?.creatorUid);
      const profile = uid && !uid.includes("/") ?
        publicProfile((await tx.get(db.collection("profiles").doc(uid))).data()) : null;
      const next = latestRows.size > 1 ? {state: "hidden" as const, updatedAt: now.toISOString()} :
        latestRows.size === 0 ? {state: "gone" as const, updatedAt: now.toISOString()} :
          // The blur from the first projection is reused when the thumbnail is unchanged, so it is fetched once.
          await projectWall(latestWall, premium, profile, candidate.blur ? candidate : currentPrevious, now, tx);
      if (sameWall(currentPrevious, next)) return {wall: currentPrevious as WebWall, written: false};
      tx.set(ref, next);
      return {wall: next, written: true};
    });
    projected.set(id, current.wall);
    if (current.written) written++;
  }, WALL_CHUNK);
  // Pages keep the same wall order on every run, so their hashes only change when the walls do.
  const walls = new Map(ids.map((id) => [id, projected.get(id) as WebWall]));

  const folders = await Promise.all(folderDocs.docs.map(async (doc) => {
    const data = doc.data();
    const items = await doc.ref.collection("items").orderBy("addedAt", "desc").limit(FOLDER_WALLS).get();
    return {
      id: doc.id,
      name: cleanText(data.name, 50),
      owner: profiles.get(str(data.ownerId)) ?? null,
      wallIds: items.docs.map((item) => str(item.data().id)).filter((id) => SHARE_ID.test(id)),
      sections: publicFolderSections(data.sections),
      sectionOf: Object.fromEntries(items.docs.filter((item) => isSectionId(item.data().sectionId))
        .map((item) => [str(item.data().id), str(item.data().sectionId)])),
      total: typeof data.itemCount === "number" && Number.isFinite(data.itemCount) ? data.itemCount : items.size,
      updatedAt: isoOf(data.updatedAt) || isoOf(doc.createTime) || now.toISOString(),
      discoveryHidden: data.discoveryHidden === true,
      discoveryEligible: publicFolderName(data.name) !== null && !hasBlockedWord(str(data.name)) &&
        Number(data.itemCount) >= 8,
    };
  }));
  const popularIds = Array.isArray(popularDoc.data()?.wallIds) ? (popularDoc.data()?.wallIds as unknown[]).map(str) : [];
  const discoverIds = (list: unknown) => Array.isArray(list) ? list.map((entry) => str(entry?.id)).filter(Boolean) : [];
  const discover = {
    trending: discoverIds(discoverDoc.data()?.trending), new: discoverIds(discoverDoc.data()?.new),
  };
  const pages = buildPages(walls, popularIds, folders.filter((f) => f.name), profiles, discover);
  const discoveryHeaders = new Map(folderDocs.docs.map((doc) => {
    const data = doc.data();
    return [doc.id, {generation: data.generation, name: data.name, itemCount: data.itemCount,
      discoveryHidden: data.discoveryHidden === true}] as const;
  }));
  const discoverySnapshotCurrent = async (tx: admin.firestore.Transaction): Promise<boolean> => {
    const latest = (await tx.get(db.collection(FOLDER_TRENDING).doc(FOLDER_TRENDING_DOC))).data();
    const latestIds = (list: unknown) => Array.isArray(list) ? list.map((entry) => str(entry?.id)).filter(Boolean) : [];
    if (stableJson({trending: latestIds(latest?.trending), new: latestIds(latest?.new)}) !== stableJson(discover)) return false;
    const ids = [...new Set([...discover.trending, ...discover.new])];
    const headers = await Promise.all(ids.map((id) => tx.get(db.collection("publicFolders").doc(id))));
    return headers.every((header, index) => {
      const expected = discoveryHeaders.get(ids[index]);
      if (!expected) return !header.exists;
      const data = header.data();
      return header.exists && data?.generation === expected.generation && data?.name === expected.name &&
        data?.itemCount === expected.itemCount && (data?.discoveryHidden === true) === expected.discoveryHidden;
    });
  };

  const oldHashes = (manifestDoc.data()?.hashes ?? {}) as Record<string, string>;
  const hashes: Record<string, string> = {};
  const writes: Array<[string, PageDoc]> = [];
  for (const [key, doc] of pages) {
    hashes[key] = hashOf(doc);
    // Incremental hide operations patch webPages/folders without touching this manifest. Compare that page
    // against the desired document on every build so a later unhide can restore identical content.
    if (oldHashes[key] !== hashes[key] || key === DISCOVER_WEB_PAGE) writes.push([key, doc]);
  }
  await inChunks(writes, async ([key, doc]) => {
    const ref = db.collection(WEB_PAGES).doc(key);
    if (key === DISCOVER_WEB_PAGE) {
      await db.runTransaction(async (tx) => {
        if (!(await discoverySnapshotCurrent(tx))) return;
        const current = await tx.get(ref);
        if (current.exists && stableJson({...current.data(), updatedAt: ""}) === stableJson({...doc, updatedAt: ""})) return;
        tx.set(ref, {...doc, updatedAt: now.toISOString()});
        written++;
      });
      return;
    }
    const current = (await ref.get()).data();
    if (current && stableJson({...current, updatedAt: ""}) === stableJson({...doc, updatedAt: ""})) return;
    await ref.set({...doc, updatedAt: now.toISOString()});
    written++;
  });
  // A prior build may have removed this key from the manifest after its deletion guard saw a racing snapshot.
  // Keep retrying the concrete /folders document until a stable snapshot can safely delete it.
  await inChunks([...new Set([...Object.keys(oldHashes).filter((key) => !(key in hashes)),
    ...(!pages.has(DISCOVER_WEB_PAGE) ? [DISCOVER_WEB_PAGE] : [])])], async (key) => {
    const ref = db.collection(WEB_PAGES).doc(key);
    if (key === DISCOVER_WEB_PAGE) {
      await db.runTransaction(async (tx) => {
        if (!(await discoverySnapshotCurrent(tx))) return;
        const current = await tx.get(ref);
        if (!current.exists) return;
        tx.delete(ref);
        written++;
      });
      return;
    }
    if (!(await ref.get()).exists) return;
    await ref.delete();
    written++;
  });
  if (stableJson(oldHashes) !== stableJson(hashes)) {
    await db.collection(STATE).doc("pages").set({hashes, builtAt: now.toISOString()});
  }
  logger.info("webCatalog: rebuilt.", {walls: walls.size, pages: pages.size, written});
  return {walls: walls.size, pages: pages.size, written};
}

export const buildWebCatalog = onSchedule(
  {schedule: "20 */2 * * *", timeZone: "UTC", region: REGION, retryCount: 1, memory: "1GiB", timeoutSeconds: 1800,
    secrets: r2Secrets},
  async () => {
    await rebuildWebCatalog();
  },
);
