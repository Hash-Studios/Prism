import * as admin from "firebase-admin";
import {str} from "./common";
import {localDateKeyFromUtc, storedTimezoneOffset} from "./streak";
import {DEFAULT_CATEGORY} from "./wallCategory";
import {PALETTE} from "./wallColors";
import {isPrismFavourite} from "./wallStats";

export const WRAPPED_YEAR = 2026;
export const WRAPPED_VERSION = 1;
export const WRAPPED_COLLECTION = "wrapped";
export const wrappedDocPath = (uid: string, year = WRAPPED_YEAR) => `${WRAPPED_COLLECTION}/${uid}/years/${year}`;

/**
 * Saves, AI walls, folders made, challenges entered and tips sent in the year. Ten is the smallest count that can fill
 * the colour and category cards with three or more walls each and still leave saves to count; fewer reads as a recap
 * of zeros.
 */
export const MIN_ACTIONS = 10;
/** Intro + four stats + summary is the shortest recap, six cards. */
export const MIN_STAT_CARDS = 4;
/** Intro + seven stats + summary is the longest recap, nine cards. */
export const MAX_STAT_CARDS = 7;

export type StatCardId =
  "saves" | "colours" | "creator" | "streak" | "ai" | "category" | "folders" | "onScreen" | "challenges" | "tips";

/**
 * Every stat card, in story order. `start` is the first day its data exists: a later start than the year start makes
 * the card carry `since`, so the copy never claims the whole year. `min` is the weakest value worth a card.
 */
export const SIGNALS: ReadonlyArray<{id: StatCardId; start: string; min: number}> = [
  {id: "saves", start: "2026-01-01", min: 3},
  {id: "colours", start: "2026-01-01", min: 3},
  {id: "creator", start: "2026-01-01", min: 2},
  {id: "streak", start: "2026-03-02", min: 3},
  {id: "ai", start: "2026-02-19", min: 1},
  {id: "category", start: "2026-01-01", min: 3},
  {id: "folders", start: "2026-10-27", min: 1},
  {id: "onScreen", start: "2026-10-30", min: 2},
  {id: "challenges", start: "2026-10-30", min: 1},
  {id: "tips", start: "2026-11-01", min: 1},
];

export type WrappedWindow = {startMs: number; endMs: number};

export function wrappedWindow(now: Date, year = WRAPPED_YEAR): WrappedWindow {
  const startMs = Date.UTC(year, 0, 1);
  return {startMs, endMs: Math.max(startMs, Math.min(now.getTime(), Date.UTC(year + 1, 0, 1)))};
}

export type SavedWall = {wallId: string; prism: boolean; thumb: string; savedAt: number; category: string};
export type WallInfo = {colors: string[]; creatorUid: string; category: string; thumb: string};
export type CreatorProfile = {uid: string; username: string};

export type WrappedSignals = {
  uid: string;
  /** Saves inside the window. */
  saves: SavedWall[];
  /** Prism walls by normalized id. */
  walls: ReadonlyMap<string, WallInfo>;
  /** Local day keys (YYYY-MM-DD) with a daily claim. */
  claimDays: string[];
  ai: {count: number; image: string};
  folders: {count: number; cover: string};
  challenges: {count: number; wallId: string};
  tips: {count: number; coins: number};
  /** Counted sets and downloads by normalized wall id. */
  uses: ReadonlyMap<string, number>;
};

export type Hero = {url: string; wallId?: string};
export type WrappedCard = {id: "intro" | "summary" | StatCardId; hero: Hero; since?: string} & Record<string, unknown>;
export type WrappedDoc = {
  uid: string;
  year: number;
  version: number;
  through: admin.firestore.Timestamp;
  builtAt: admin.firestore.Timestamp;
  actions: number;
  accents: string[];
  cards: WrappedCard[];
};

const PALETTE_ORDER = new Map(PALETTE.map((color, index) => [color.id, index]));
const compareKeys = (a: string, b: string) => a < b ? -1 : a > b ? 1 : 0;
const SIGNAL_PAGE_SIZE = 500;

export function normalizeWallId(raw: string): string {
  return raw.trim().toUpperCase();
}

/** Highest count first, then the most recent save, then the key, so equal tallies always pick the same winner. */
function rank<K extends string>(tally: Map<K, {count: number; last: number}>, compareKeys: (a: K, b: K) => number) {
  return [...tally.entries()].sort(([ka, a], [kb, b]) => b.count - a.count || b.last - a.last || compareKeys(ka, kb));
}

function tallyBy(saves: SavedWall[], keyOf: (save: SavedWall) => string) {
  const tally = new Map<string, {count: number; last: number}>();
  for (const save of saves) {
    const key = keyOf(save);
    if (!key) continue;
    const entry = tally.get(key) ?? {count: 0, last: 0};
    tally.set(key, {count: entry.count + 1, last: Math.max(entry.last, save.savedAt)});
  }
  return tally;
}

export function topCreator(signals: Pick<WrappedSignals, "uid" | "saves" | "walls">): {uid: string; count: number} | null {
  const tally = tallyBy(signals.saves, (save) => {
    const creator = save.prism ? signals.walls.get(normalizeWallId(save.wallId))?.creatorUid ?? "" : "";
    return creator === signals.uid ? "" : creator;
  });
  const [top] = rank(tally, compareKeys);
  return top ? {uid: top[0], count: top[1].count} : null;
}

/** Each wall scores its colours by dominance (3, 2, 1). Ties fall back to the palette order. */
export function topColours(saves: SavedWall[], walls: ReadonlyMap<string, WallInfo>): {ids: string[]; walls: number} {
  const score = new Map<string, number>();
  let coloured = 0;
  for (const save of saves) {
    const colors = save.prism ? walls.get(normalizeWallId(save.wallId))?.colors ?? [] : [];
    const known = colors.filter((id) => PALETTE_ORDER.has(id)).slice(0, 3);
    if (known.length === 0) continue;
    coloured += 1;
    known.forEach((id, index) => score.set(id, (score.get(id) ?? 0) + 3 - index));
  }
  const ids = [...score.entries()]
    .sort(([a, sa], [b, sb]) => sb - sa || (PALETTE_ORDER.get(a) ?? 0) - (PALETTE_ORDER.get(b) ?? 0))
    .slice(0, 3)
    .map(([id]) => id);
  return {ids, walls: coloured};
}

function categoryOf(save: SavedWall, walls: ReadonlyMap<string, WallInfo>): string {
  const category = (save.prism ? walls.get(normalizeWallId(save.wallId))?.category : "") || save.category;
  return category.trim() === DEFAULT_CATEGORY ? "" : category.trim();
}

export function longestRun(dayKeys: string[]): number {
  const days = [...new Set(dayKeys)].map((key) => Date.parse(`${key}T00:00:00Z`)).filter(Number.isFinite).sort((a, b) => a - b);
  let best = 0;
  let run = 0;
  for (let i = 0; i < days.length; i++) {
    run = i > 0 && days[i] - days[i - 1] === 86400000 ? run + 1 : 1;
    best = Math.max(best, run);
  }
  return best;
}

/** Builds the doc, or null when the year is too thin for a recap. Pure: the reader gathers every input. */
export function buildWrapped(
  signals: WrappedSignals,
  creator: CreatorProfile | null,
  window: WrappedWindow,
  builtAt: Date,
): WrappedDoc | null {
  const saves = [...signals.saves].sort((a, b) => b.savedAt - a.savedAt || compareKeys(a.wallId, b.wallId));
  const thumbOf = (wallId: string) => {
    const id = normalizeWallId(wallId);
    return saves.find((save) => normalizeWallId(save.wallId) === id)?.thumb || signals.walls.get(id)?.thumb || "";
  };
  const used = new Set<string>();
  /** The first unused hero among the candidates, so cards in a row rarely repeat a wall. */
  const hero = (...candidates: Array<Hero | undefined>): Hero => {
    const real = candidates.filter((c): c is Hero => Boolean(c?.url));
    const pick = real.find((c) => !used.has(c.url)) ?? real[0] ?? {url: ""};
    used.add(pick.url);
    return pick;
  };
  const saveHero = (save: SavedWall | undefined): Hero | undefined =>
    save?.thumb ? {url: save.thumb, wallId: save.wallId} : undefined;
  const anySave = () => saves.map(saveHero);

  const colours = topColours(saves, signals.walls);
  const creatorTop = topCreator({...signals, saves});
  const [category] = rank(tallyBy(saves, (save) => categoryOf(save, signals.walls)), compareKeys);
  const streak = longestRun(signals.claimDays);
  const savedIds = new Set(saves.filter((save) => save.prism).map((save) => normalizeWallId(save.wallId)));
  const lastSavedAt = new Map<string, number>();
  for (const save of saves) {
    const id = normalizeWallId(save.wallId);
    lastSavedAt.set(id, Math.max(lastSavedAt.get(id) ?? 0, save.savedAt));
  }
  const [onScreen] = [...signals.uses.entries()]
    .filter(([id]) => savedIds.has(id))
    .sort(([a, ua], [b, ub]) => ub - ua || (lastSavedAt.get(b) ?? 0) - (lastSavedAt.get(a) ?? 0) || compareKeys(a, b));
  const onScreenThumb = onScreen ? thumbOf(onScreen[0]) : "";

  const values: Record<StatCardId, number> = {
    saves: saves.length,
    colours: colours.ids.length === 3 ? colours.walls : 0,
    creator: creator && creatorTop?.uid === creator.uid ? creatorTop.count : 0,
    streak,
    ai: signals.ai.count,
    category: category?.[1].count ?? 0,
    folders: signals.folders.count,
    onScreen: onScreen?.[1] ?? 0,
    challenges: signals.challenges.count,
    tips: signals.tips.count,
  };
  const actions = saves.length + signals.ai.count + signals.folders.count + signals.challenges.count + signals.tips.count;
  const strong = SIGNALS.filter((signal) => values[signal.id] >= signal.min &&
    (signal.id !== "onScreen" || Boolean(onScreenThumb))).slice(0, MAX_STAT_CARDS);
  if (actions < MIN_ACTIONS || strong.length < MIN_STAT_CARDS) return null;
  if (strong.some((signal) => signal.id === "onScreen")) used.add(onScreenThumb);

  const ownSignalHeroes = [
    {url: signals.ai.image},
    {url: signals.folders.cover},
    {url: thumbOf(signals.challenges.wallId), wallId: signals.challenges.wallId},
  ];
  const intro: WrappedCard = {id: "intro", hero: hero(...anySave(), ...ownSignalHeroes)};
  const stats = strong.map((signal): WrappedCard => {
    const since = Date.parse(`${signal.start}T00:00:00Z`) > window.startMs ? {since: signal.start} : {};
    switch (signal.id) {
    case "saves":
      return {id: "saves", value: values.saves, hero: hero(saveHero(saves[saves.length - 1]), ...anySave(), ...ownSignalHeroes)};
    case "colours":
      return {id: "colours", colours: colours.ids, value: values.colours, hero: hero(...saves
        .filter((save) => save.prism && signals.walls.get(normalizeWallId(save.wallId))?.colors[0] === colours.ids[0])
        .map(saveHero), ...anySave(), ...ownSignalHeroes)};
    case "creator":
      return {id: "creator", value: values.creator, creator: {username: creator!.username}, hero: hero(...saves
        .filter((save) => save.prism && signals.walls.get(normalizeWallId(save.wallId))?.creatorUid === creator?.uid)
        .map(saveHero), ...anySave(), ...ownSignalHeroes)};
    case "streak":
      return {id: "streak", value: streak, ...since, hero: hero(...anySave(), ...ownSignalHeroes)};
    case "ai":
      return {id: "ai", value: signals.ai.count, ...since,
        hero: hero({url: signals.ai.image}, ...anySave(), ...ownSignalHeroes)};
    case "category":
      return {id: "category", value: values.category, category: category[0], hero: hero(...saves
        .filter((save) => categoryOf(save, signals.walls) === category[0]).map(saveHero), ...anySave(), ...ownSignalHeroes)};
    case "folders":
      return {id: "folders", value: signals.folders.count, ...since,
        hero: hero({url: signals.folders.cover}, ...anySave(), ...ownSignalHeroes)};
    case "onScreen":
      return {id: "onScreen", value: values.onScreen, ...since,
        hero: {url: onScreenThumb, wallId: onScreen[0]}};
    case "challenges":
      return {id: "challenges", value: signals.challenges.count, ...since,
        hero: hero({url: thumbOf(signals.challenges.wallId), wallId: signals.challenges.wallId}, ...anySave(), ...ownSignalHeroes)};
    case "tips":
      return {id: "tips", value: signals.tips.count, coins: signals.tips.coins, ...since,
        hero: hero(...anySave(), ...ownSignalHeroes)};
    }
  });
  const thumbs = [...new Set([intro, ...stats].map((card) => card.hero.url).filter(Boolean))].slice(0, 4);
  return {
    uid: signals.uid,
    year: WRAPPED_YEAR,
    version: WRAPPED_VERSION,
    through: admin.firestore.Timestamp.fromMillis(window.endMs),
    builtAt: admin.firestore.Timestamp.fromDate(builtAt),
    actions,
    accents: values.colours > 0 ? colours.ids : [],
    cards: [intro, ...stats, {id: "summary", hero: {url: thumbs[0] ?? ownSignalHeroes.find((item) => item.url)?.url ?? ""}, thumbs}],
  };
}

export function toMillis(value: unknown): number | null {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const ms = Date.parse(value);
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}

const inWindow = (ms: number | null, window: WrappedWindow): ms is number =>
  ms !== null && ms >= window.startMs && ms < window.endMs;

/** Every Prism wall, read once per run so per-user lookups cost nothing. */
export async function loadWallIndex(db: admin.firestore.Firestore): Promise<Map<string, WallInfo>> {
  const walls = new Map<string, WallInfo>();
  const pageSize = 500;
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let query = db.collection("walls").select("id", "colors", "creatorUid", "category", "wallpaper_thumb")
      .orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    for (const doc of snap.docs) {
      const data = doc.data();
      const logical = str(data.id) || doc.id;
      const id = normalizeWallId(logical);
      // After a dedupe the doc whose id matches its own id field is the canonical one.
      if (walls.has(id) && logical !== doc.id) continue;
      walls.set(id, {
        colors: Array.isArray(data.colors) ? data.colors.filter((c: unknown): c is string => typeof c === "string") : [],
        creatorUid: str(data.creatorUid),
        category: str(data.category),
        thumb: str(data.wallpaper_thumb),
      });
    }
    if (snap.size < pageSize) return walls;
    cursor = snap.docs[snap.docs.length - 1];
  }
}

/**
 * Reads one user's signals. A save counts on `favouritedAt`, or on `createdAt` for saves made before 8 Oct 2026. For a
 * 2026 build, that older `createdAt` upload date cannot count a save from a later year. A post-year restart can.
 */
export async function readWrappedSignals(
  db: admin.firestore.Firestore,
  uid: string,
  user: admin.firestore.DocumentData,
  walls: ReadonlyMap<string, WallInfo>,
  window: WrappedWindow,
): Promise<WrappedSignals> {
  const start = admin.firestore.Timestamp.fromMillis(window.startMs);
  const end = admin.firestore.Timestamp.fromMillis(window.endMs);
  const images = db.collection(`usersv2/${uid}/images`);
  const [byFavourited, byCreated, aiCount, aiLatest, folders, entries, receipts] = await Promise.all([
    images.where("favouritedAt", ">=", start).where("favouritedAt", "<", end).get(),
    images.where("createdAt", ">=", start).where("createdAt", "<", end).get(),
    db.collection("aiGenerations").where("userId", "==", uid)
      .where("createdAt", ">=", start).where("createdAt", "<", end).count().get(),
    db.collection("aiGenerations").where("userId", "==", uid)
      .where("createdAt", ">=", start).where("createdAt", "<", end).orderBy("createdAt", "desc").limit(1).get(),
    db.collection("folders").where("ownerId", "==", uid).get(),
    db.collectionGroup("entries").where("creatorUid", "==", uid).get(),
    db.collection(`usersv2/${uid}/wallActionReceipts`)
      .where("acceptedAt", ">=", window.startMs).where("acceptedAt", "<", window.endMs).get(),
  ]);

  const saves = new Map<string, SavedWall>();
  for (const doc of [...byFavourited.docs, ...byCreated.docs]) {
    const data = doc.data();
    const savedAt = toMillis(data.favouritedAt) ?? toMillis(data.createdAt);
    if (!inWindow(savedAt, window)) continue;
    saves.set(doc.id, {
      wallId: str(data.id) || doc.id,
      prism: isPrismFavourite(doc.id, data),
      thumb: str(data.thumb),
      savedAt,
      category: str(data.category),
    });
  }

  const offset = storedTimezoneOffset(user.coinState) ?? 0;
  const claimDays = new Set<string>();
  const tips = {count: 0, coins: 0};
  const coinQuery = db.collection("coinTransactions").where("userId", "==", uid)
    .where("createdAt", ">=", start).where("createdAt", "<", end);
  let coinCursor: admin.firestore.QueryDocumentSnapshot | undefined;
  while (true) {
    let pageQuery = coinQuery.orderBy("createdAt").limit(SIGNAL_PAGE_SIZE);
    if (coinCursor) pageQuery = pageQuery.startAfter(coinCursor);
    const page = await pageQuery.get();
    for (const doc of page.docs) {
      const data = doc.data();
      const at = toMillis(data.createdAt);
      if (!inWindow(at, window)) continue;
      if (data.action === "dailyLogin") claimDays.add(localDateKeyFromUtc(new Date(at), offset));
      if (data.action === "tipSent" && typeof data.delta === "number" && data.delta < 0) {
        tips.count += 1;
        tips.coins += -data.delta;
      }
    }
    if (page.size < SIGNAL_PAGE_SIZE) break;
    coinCursor = page.docs[page.docs.length - 1];
  }

  const ai = aiLatest.docs[0]?.data();
  const made = folders.docs.map((doc) => doc.data()).filter((data) => inWindow(toMillis(data.createdAt), window))
    .sort((a, b) => (toMillis(b.createdAt) ?? 0) - (toMillis(a.createdAt) ?? 0));
  const approved = entries.docs.map((doc) => doc.data())
    .filter((data) => data.state === "approved" && inWindow(toMillis(data.createTime), window));

  const uses = new Map<string, number>();
  for (const doc of receipts.docs) {
    const data = doc.data();
    if (data.counted !== true || typeof data.wallId !== "string" || !data.wallId.trim()) continue;
    const id = normalizeWallId(data.wallId);
    uses.set(id, (uses.get(id) ?? 0) + 1);
  }

  return {
    uid,
    saves: [...saves.values()],
    walls,
    claimDays: [...claimDays],
    ai: {count: aiCount.data().count, image: str(ai?.watermarkedImageUrl) || str(ai?.imageUrl)},
    folders: {
      count: made.length,
      cover: made.flatMap((data) => (Array.isArray(data.covers) ? data.covers : [])).find((c) => typeof c === "string") ?? "",
    },
    challenges: {
      count: new Set(approved.map((data) => str(data.challengeId))).size,
      wallId: str(approved[0]?.wallLogicalId),
    },
    tips,
    uses,
  };
}

export async function readCreatorProfile(db: admin.firestore.Firestore, uid: string): Promise<CreatorProfile | null> {
  const [profile, account] = await Promise.all([db.doc(`profiles/${uid}`).get(), db.doc(`usersv2/${uid}`).get()]);
  const data = profile.data();
  const username = str(data?.username).trim();
  if (!data || !username || !account.exists || account.data()?.deleted === true) return null;
  return {uid, username};
}
