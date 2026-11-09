import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {isAdminCaller} from "./adminConfig";
import {db, CALLABLE_REGIONS, REGION, str} from "./common";
import {
  countFolderSignal, dropFromDiscovery, FOLDER_STATS_DAILY, FOLDER_TRENDING, FOLDER_TRENDING_DOC, MIN_DISCOVER_WALLS,
} from "./folderSignals";
import {folderIdFrom, PUBLIC_FOLDERS, publicFolderName} from "./publicFolders";
import {hasBlockedWord} from "./textSafety";
import {trendingDays} from "./trending";
import {matchesMood, MOODS} from "./wallMoods";

const DAY_MS = 24 * 60 * 60 * 1000;
const DAY_DECAY = 0.8;
const MIN_OWNER_AGE_MS = 7 * DAY_MS;
const NEW_DAYS = 7;
const MAX_PER_OWNER = 2;
const TRAIT_WALLS = 12;
const TOP_TRAITS = 3;
const CHUNK = 100;

/** Read caps. The cost table in docs/features/folders.md is computed from these. */
export const DISCOVERY_LIMITS = {
  listSize: 30,
  dailyDocs: 50_000,
  /** Scored folders read in score order, 100 at a time, until Trending is full. Ineligible ones do not block it. */
  trendingScan: 1_000,
  newCandidates: 300,
} as const;

type Doc = admin.firestore.DocumentData;
export type DailyRow = {folderId: string; day: string; follows: number; saves: number; opens: number};
export type OwnerAccount = {createdMs: number; disabled: boolean};
export type Refusal = "private" | "hidden" | "reported" | "size" | "name" | "owner";
export type DiscoverEntry = {
  id: string; ownerId: string; ownerName: string; ownerUsername?: string; ownerPhoto?: string;
  name: string; itemCount: number; covers: string[]; followerCount: number; moods: string[]; categories: string[];
};

const num = (v: unknown) => typeof v === "number" && Number.isFinite(v) ? Math.max(0, v) : 0;

/** Seam for tests: Auth is outside the fake database. */
export const folderDiscoveryDeps: {owners: (uids: string[]) => Promise<Map<string, OwnerAccount>>} = {
  owners: async (uids) => {
    const out = new Map<string, OwnerAccount>();
    for (let i = 0; i < uids.length; i += CHUNK) {
      const {users} = await admin.auth().getUsers(uids.slice(i, i + CHUNK).map((uid) => ({uid})));
      for (const user of users) {
        const created = Date.parse(user.metadata.creationTime);
        if (Number.isFinite(created)) out.set(user.uid, {createdMs: created, disabled: user.disabled});
      }
    }
    return out;
  },
};

/** Recent activity per folder: a follow counts 3, a save 2 and an open 1. Each day of age multiplies by 0.8. */
export function folderScores(rows: DailyRow[], days: string[]): Map<string, number> {
  const scores = new Map<string, number>();
  for (const row of rows) {
    const ago = days.indexOf(row.day);
    if (ago < 0 || !row.folderId) continue;
    const day = row.follows * 3 + row.saves * 2 + row.opens;
    scores.set(row.folderId, (scores.get(row.folderId) ?? 0) + day * DAY_DECAY ** ago);
  }
  return scores;
}

/** Why a public folder header may not show in discovery, or null when it may. */
export function discoveryRefusal(
  header: Doc | undefined, ctx: {nowMs: number; owners: Map<string, OwnerAccount>; reported: Set<string>},
  folderId: string,
): Refusal | null {
  if (!header) return "private";
  if (header.discoveryHidden === true) return "hidden";
  if (ctx.reported.has(folderId)) return "reported";
  if (num(header.itemCount) < MIN_DISCOVER_WALLS) return "size";
  const name = publicFolderName(header.name);
  if (!name || hasBlockedWord(name)) return "name";
  const owner = ctx.owners.get(str(header.ownerId));
  if (!owner || owner.disabled || ctx.nowMs - owner.createdMs < MIN_OWNER_AGE_MS) return "owner";
  return null;
}

/** Keeps the order and drops a folder once its owner already has [max] folders in the list. */
export function capPerOwner<T extends {ownerId: string}>(items: T[], size: number, max = MAX_PER_OWNER): T[] {
  const seen = new Map<string, number>();
  const out: T[] = [];
  for (const item of items) {
    const count = seen.get(item.ownerId) ?? 0;
    if (count >= max) continue;
    seen.set(item.ownerId, count + 1);
    out.push(item);
    if (out.length === size) break;
  }
  return out;
}

/** The most common values, ties by name, at most 3. */
function top(values: string[]): string[] {
  const counts = new Map<string, number>();
  for (const value of values) if (value) counts.set(value, (counts.get(value) ?? 0) + 1);
  return [...counts].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, TOP_TRAITS).map(([v]) => v);
}

/** Moods and categories of the folder's newest public walls. The app ranks "Like your saves" from them. */
async function folderTraits(folderId: string): Promise<{moods: string[]; categories: string[]}> {
  const items = await db.collection(PUBLIC_FOLDERS).doc(folderId).collection("items")
    .orderBy("addedAt", "desc").limit(TRAIT_WALLS).get();
  const walls = (await Promise.all(items.docs.map((item) => str(item.data().wallpaperDocumentId))
    .filter((id) => id && !id.includes("/")).map((id) => db.collection("walls").doc(id).get())))
    .map((snap) => snap.data()).filter((wall): wall is Doc => wall !== undefined);
  return {
    moods: top(walls.flatMap((wall) => MOODS.filter((rule) => matchesMood(rule, wall)).map((rule) => rule.id))),
    categories: top(walls.map((wall) => str(wall.category)).filter((c) => c !== "General")),
  };
}

function entryOf(id: string, header: Doc, profile: Doc | undefined, traits: {moods: string[]; categories: string[]}):
  DiscoverEntry {
  const entry: DiscoverEntry = {
    id, ownerId: str(header.ownerId), ownerName: str(profile?.name), name: str(publicFolderName(header.name)),
    itemCount: Math.trunc(num(header.itemCount)),
    covers: Array.isArray(header.covers) ? header.covers.filter((c): c is string => typeof c === "string").slice(0, 4) : [],
    followerCount: Math.trunc(num(header.followerCount)), ...traits,
  };
  if (typeof profile?.username === "string" && profile.username) entry.ownerUsername = profile.username;
  if (typeof profile?.profilePhoto === "string" && profile.profilePhoto) entry.ownerPhoto = profile.profilePhoto;
  return entry;
}

async function getDocs(refs: admin.firestore.DocumentReference[]): Promise<admin.firestore.DocumentSnapshot[]> {
  const out: admin.firestore.DocumentSnapshot[] = [];
  for (let i = 0; i < refs.length; i += CHUNK) out.push(...await Promise.all(refs.slice(i, i + CHUNK).map((r) => r.get())));
  return out;
}

/**
 * Rebuilds `folderTrending/current`: up to 30 trending and 30 new public folders, at most 2 per owner. It reads the
 * last 7 days of `folderStatsDaily`, the headers of the 300 newest eligible folders, then scored folders in score
 * order, 100 at a time, until Trending is full (at most 1,000), one bounded open-report lookup per candidate, and then 12 walls and one profile for each listed folder.
 * Never all folders.
 */
export async function rebuildFolderDiscovery(nowMs = Date.now()): Promise<{trending: number; fresh: number}> {
  const days = trendingDays(nowMs);
  const [dailySnap, newSnap] = await Promise.all([
    db.collection(FOLDER_STATS_DAILY).where("day", "in", days).select("folderId", "day", "follows", "saves", "opens")
      .limit(DISCOVERY_LIMITS.dailyDocs).get(),
    db.collection(PUBLIC_FOLDERS)
      .where("discoveryEligibleAt", ">=", admin.firestore.Timestamp.fromMillis(nowMs - NEW_DAYS * DAY_MS))
      .orderBy("discoveryEligibleAt", "desc").limit(DISCOVERY_LIMITS.newCandidates).get(),
  ]);
  if (dailySnap.size >= DISCOVERY_LIMITS.dailyDocs) logger.warn("folderDiscovery: daily docs hit the read cap.");

  const scores = folderScores(dailySnap.docs.map((d) => d.data()).map((d) => ({
    folderId: str(d.folderId), day: str(d.day), follows: num(d.follows), saves: num(d.saves), opens: num(d.opens),
  })), days);
  const ranked = [...scores].filter(([, score]) => score > 0)
    .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).map(([id]) => id);

  const headers = new Map<string, Doc>();
  const reported = new Set<string>();
  const owners = new Map<string, OwnerAccount>();
  const ctx = {nowMs, owners, reported};
  // Reports are checked per candidate, so unrelated reports cannot push a report past a global limit.
  const load = async (snaps: admin.firestore.DocumentSnapshot[]) => {
    const found = snaps.filter((snap) => snap.exists && !headers.has(snap.id));
    for (const snap of found) headers.set(snap.id, snap.data() as Doc);
    const checks = await Promise.all(found.map((snap) => db.collection("contentReports")
      .where("contentType", "==", "folder").where("status", "==", "open").where("targetFirestoreDocId", "==", snap.id)
      .limit(1).get()));
    found.forEach((snap, i) => {
      if (checks[i].size > 0) reported.add(snap.id);
    });
    const uids = [...new Set(found.map((snap) => str(snap.data()?.ownerId)))].filter((uid) => uid && !owners.has(uid));
    if (uids.length) for (const [uid, account] of await folderDiscoveryDeps.owners(uids)) owners.set(uid, account);
  };
  const eligible = (id: string) => discoveryRefusal(headers.get(id), ctx, id) === null;
  const rowOf = (id: string) => ({id, ownerId: str(headers.get(id)?.ownerId)});

  await load(newSnap.docs);
  const fresh = capPerOwner(newSnap.docs.map((d) => d.id).filter(eligible).map(rowOf), DISCOVERY_LIMITS.listSize);
  let trending: Array<{id: string; ownerId: string}> = [];
  const scan = Math.min(ranked.length, DISCOVERY_LIMITS.trendingScan);
  for (let i = 0; i < scan && trending.length < DISCOVERY_LIMITS.listSize; i += CHUNK) {
    const chunk = ranked.slice(i, Math.min(i + CHUNK, scan)).filter((id) => !headers.has(id));
    await load(await getDocs(chunk.map((id) => db.collection(PUBLIC_FOLDERS).doc(id))));
    trending = capPerOwner(ranked.slice(0, Math.min(i + CHUNK, scan)).filter(eligible).map(rowOf), DISCOVERY_LIMITS.listSize);
  }

  const listed = [...new Set([...trending, ...fresh].map((row) => row.id))];
  const ownerIds = [...new Set(listed.map((id) => str(headers.get(id)?.ownerId)))];
  const [profiles, traits] = await Promise.all([
    getDocs(ownerIds.map((uid) => db.collection("profiles").doc(uid))),
    Promise.all(listed.map(folderTraits)),
  ]);
  const profileOf = new Map(ownerIds.map((uid, i) => [uid, profiles[i].data()]));
  const traitsOf = new Map(listed.map((id, i) => [id, traits[i]]));

  // Recheck the live header: its name, size, owner and moderation state may have changed while the job ran.
  const ref = db.collection(FOLDER_TRENDING).doc(FOLDER_TRENDING_DOC);
  const result = await db.runTransaction(async (tx) => {
    const current = await Promise.all(listed.map((id) => tx.get(db.collection(PUBLIC_FOLDERS).doc(id))));
    const live = new Map(current.filter((snap) => snap.exists &&
      discoveryRefusal(snap.data() as Doc, ctx, snap.id) === null &&
      sameSourceIdentity(headers.get(snap.id), snap.data() as Doc))
      .map((snap) => [snap.id, snap.data() as Doc]));
    const entries = (rows: Array<{id: string}>) => rows.flatMap(({id}) => {
      const header = live.get(id);
      return header ? [entryOf(id, header, profileOf.get(str(header.ownerId)), traitsOf.get(id) ?? {moods: [], categories: []})] : [];
    });
    const doc = {trending: entries(trending), new: entries(fresh), updatedAt: admin.firestore.Timestamp.fromMillis(nowMs)};
    tx.set(ref, doc);
    return {trending: doc.trending.length, fresh: doc.new.length};
  });
  logger.info("folderDiscovery: rebuilt.", {...result, daily: dailySnap.size, candidates: headers.size});
  return result;
}

function sameSourceIdentity(candidate: Doc | undefined, current: Doc): boolean {
  if (!candidate) return false;
  if (typeof candidate.generation === "string" && candidate.generation !== current.generation) return false;
  if (candidate.sourceCreatedAt instanceof admin.firestore.Timestamp &&
      (!(current.sourceCreatedAt instanceof admin.firestore.Timestamp) ||
        !candidate.sourceCreatedAt.isEqual(current.sourceCreatedAt))) return false;
  return true;
}

export const computeFolderDiscovery = onSchedule(
  {schedule: "10 3 * * *", timeZone: "UTC", region: REGION, retryCount: 1, timeoutSeconds: 540},
  async () => {
    await rebuildFolderDiscovery();
  },
);

/** The app reports a public folder open or a Save all. `countFolderSignal` decides if it counts. */
export const recordFolderSignal = onCall(
  {region: CALLABLE_REGIONS, cors: true, maxInstances: 10},
  async (request: CallableRequest<{folderId?: unknown; signal?: unknown}>): Promise<{counted: boolean}> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to open folders.");
    const folderId = folderIdFrom(request.data?.folderId);
    const signal = request.data?.signal;
    if (signal !== "open" && signal !== "save") throw new HttpsError("invalid-argument", "signal must be open or save.");
    const header = await db.collection(PUBLIC_FOLDERS).doc(folderId).get();
    if (!header.exists) return {counted: false};
    return {counted: await countFolderSignal(uid, folderId, str(header.data()?.ownerId), signal)};
  },
);

/** Moderators take a public folder out of the discover lists. It stays public and opens by link. */
export const setFolderDiscoveryHidden = onCall(
  {region: CALLABLE_REGIONS, cors: true},
  async (request: CallableRequest<{folderId?: unknown; hidden?: unknown}>): Promise<{ok: true}> => {
    if (!(await isAdminCaller(request.auth))) throw new HttpsError("permission-denied", "Admins only.");
    const folderId = folderIdFrom(request.data?.folderId);
    const hidden = request.data?.hidden;
    if (typeof hidden !== "boolean") throw new HttpsError("invalid-argument", "hidden must be a boolean.");
    await setDiscoveryHidden(folderId, hidden);
    return {ok: true};
  },
);

export async function setDiscoveryHidden(folderId: string, hidden: boolean): Promise<void> {
  const folderRef = db.collection("folders").doc(folderId);
  const headerRef = db.collection(PUBLIC_FOLDERS).doc(folderId);
  await db.runTransaction(async (tx) => {
    const [folder, header] = await Promise.all([tx.get(folderRef), tx.get(headerRef)]);
    if (!folder.exists) throw new HttpsError("not-found", "Folder not found.");
    tx.update(folderRef, {discoveryHidden: hidden});
    if (header.exists) tx.update(headerRef, {discoveryHidden: hidden});
  });
  if (hidden) await dropFromDiscovery(folderId);
}
