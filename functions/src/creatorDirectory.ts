import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {db, CALLABLE_REGIONS, readDailyCount, REGION, str, utcDateString} from "./common";
import {WALLPAPER_STATS_DAILY} from "./viewStats";
import {trendingDays} from "./trending";
import {isWotdEligible, premiumCollections} from "./wallEligibility";

export const CREATOR_DIRECTORY = "creatorDirectory";
export const FOLLOWED_BY_CACHE = "followedByCache";
const FOLLOWED_BY_RATE = "followedByRateDaily";
const PROFILES = "profiles";
const USERS = "usersv2";

const DAY_MS = 24 * 60 * 60 * 1000;
const MIN_WALLS = 3;
const ACTIVE_DAYS = 60;
const NEW_CREATOR_DAYS = 30;
const NEW_CREATOR_BONUS = 3;
const NEW_CREATOR_MULTIPLIER = 1.25;
const DAY_DECAY = 0.8;
const TOP_WALLS = 4;
const TOP_CATEGORIES = 3;
const SIMILAR = 12;
const MAX_WALLS = 50_000;
const MAX_DAILY_DOCS = 50_000;
const MAX_FOLLOW_EDGES = 20_000;
const CHUNK = 100;

/** Maximum viewer follow edges scanned by one lookup. */
export const FOLLOWING_SCAN_CAP = 500;
const IN_CHUNK = 30;
const FOLLOWED_BY_PEOPLE = 3;
const FOLLOWED_BY_TTL_MS = DAY_MS;
const MAX_FOLLOWED_BY_LOOKUPS_PER_DAY = 300;

export type DirectoryWall = {id: string; thumb: string};
export type WallRow = {id: string; creatorUid: string; thumb: string; category: string; createdMs: number};
export type DailyRow = {wallId: string; day: string; favs: number; sets: number};
export type FollowEdge = {followerUid: string; targetUid: string; createdMs: number};
export type DirectoryEntry = {
  uid: string;
  name: string;
  username?: string;
  profilePhoto?: string;
  followerCount: number;
  walls: DirectoryWall[];
  categories: string[];
  similar: string[];
  rank: number;
};
type Candidate = {uid: string; walls: WallRow[]; score: number; categories: string[]; top: DirectoryWall[]};

const num = (v: unknown) => typeof v === "number" && Number.isFinite(v) ? Math.max(0, v) : 0;

/**
 * Pure planning step. Groups public walls by creator, keeps creators with at least 3 walls and one in the last 60 days,
 * and scores them by recent saves, sets and follows (newer days count more), with a bonus for creators whose first
 * wall is under 30 days old.
 */
export function planCandidates(
  {walls, daily, edges, nowMs}: {walls: WallRow[]; daily: DailyRow[]; edges: FollowEdge[]; nowMs: number},
): Candidate[] {
  const days = trendingDays(nowMs);
  const byCreator = new Map<string, WallRow[]>();
  for (const wall of walls) {
    if (!wall.creatorUid || !wall.id || !wall.thumb) continue;
    const own = byCreator.get(wall.creatorUid) ?? [];
    own.push(wall);
    byCreator.set(wall.creatorUid, own);
  }
  const wallActivity = new Map<string, number>();
  const wallWeighted = new Map<string, number>();
  for (const row of daily) {
    const ago = days.indexOf(row.day);
    if (ago < 0) continue;
    const id = row.wallId.toUpperCase();
    wallActivity.set(id, (wallActivity.get(id) ?? 0) + row.favs + row.sets);
    wallWeighted.set(id, (wallWeighted.get(id) ?? 0) + (row.favs * 2 + row.sets * 3) * DAY_DECAY ** ago);
  }
  const recentFollows = new Map<string, number>();
  for (const edge of edges) {
    const ago = Math.floor((nowMs - edge.createdMs) / DAY_MS);
    if (ago < 0 || ago >= days.length) continue;
    recentFollows.set(edge.targetUid, (recentFollows.get(edge.targetUid) ?? 0) + 4 * DAY_DECAY ** ago);
  }

  const out: Candidate[] = [];
  for (const [uid, own] of byCreator) {
    if (own.length < MIN_WALLS) continue;
    const newest = Math.max(...own.map((w) => w.createdMs));
    const first = Math.min(...own.map((w) => w.createdMs));
    if (nowMs - newest > ACTIVE_DAYS * DAY_MS) continue;
    const activity = own.reduce((sum, w) => sum + (wallWeighted.get(w.id.toUpperCase()) ?? 0), 0) +
      (recentFollows.get(uid) ?? 0);
    const isNew = nowMs - first <= NEW_CREATOR_DAYS * DAY_MS;
    const top = [...own]
      .sort((a, b) => (wallActivity.get(b.id.toUpperCase()) ?? 0) - (wallActivity.get(a.id.toUpperCase()) ?? 0) ||
        b.createdMs - a.createdMs)
      .slice(0, TOP_WALLS)
      .map((w) => ({id: w.id, thumb: w.thumb}));
    const counts = new Map<string, number>();
    for (const w of own) if (w.category) counts.set(w.category, (counts.get(w.category) ?? 0) + 1);
    const categories = [...counts.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, TOP_CATEGORIES)
      .map(([c]) => c);
    out.push({
      uid, walls: own, top, categories,
      score: isNew ? activity * NEW_CREATOR_MULTIPLIER + NEW_CREATOR_BONUS : activity,
    });
  }
  return out;
}

/** Up to 12 other listed creators per creator, by shared followers (2 points each) and shared main categories. */
export function similarCreators(entries: Array<{uid: string; categories: string[]}>, edges: FollowEdge[]): Map<string, string[]> {
  const listed = new Set(entries.map((e) => e.uid));
  const followsByUser = new Map<string, Set<string>>();
  for (const edge of edges) {
    if (!listed.has(edge.targetUid)) continue;
    const set = followsByUser.get(edge.followerUid) ?? new Set<string>();
    set.add(edge.targetUid);
    followsByUser.set(edge.followerUid, set);
  }
  const followersByCreator = new Map<string, Set<string>>();
  for (const [uid, follows] of followsByUser) {
    for (const creator of follows) {
      const followers = followersByCreator.get(creator) ?? new Set<string>();
      followers.add(uid);
      followersByCreator.set(creator, followers);
    }
  }
  const order = new Map(entries.map((e, i) => [e.uid, i]));
  const result = new Map<string, string[]>();
  for (const a of entries) {
    const scores = new Map<string, number>();
    for (const follower of followersByCreator.get(a.uid) ?? []) {
      for (const uid of followsByUser.get(follower) ?? []) {
        if (uid !== a.uid) scores.set(uid, (scores.get(uid) ?? 0) + 2);
      }
    }
    const cats = new Set(a.categories);
    for (const b of entries) {
      if (b.uid === a.uid) continue;
      const shared = b.categories.filter((c) => cats.has(c)).length;
      if (shared) scores.set(b.uid, (scores.get(b.uid) ?? 0) + shared);
    }
    const top: Array<{uid: string; score: number}> = [];
    for (const [uid, score] of scores) {
      const at = top.findIndex((other) => score > other.score ||
        (score === other.score && (order.get(uid) ?? 0) < (order.get(other.uid) ?? 0)));
      top.splice(at < 0 ? top.length : at, 0, {uid, score});
      if (top.length > SIMILAR) top.pop();
    }
    result.set(a.uid, top.map((entry) => entry.uid));
  }
  return result;
}

/** Only the public profile fields the profile page already shows. */
export function directoryEntry(
  candidate: Candidate, profile: Record<string, unknown>, rank: number, similar: string[],
): DirectoryEntry {
  const entry: DirectoryEntry = {
    uid: candidate.uid,
    name: str(profile.name),
    followerCount: Math.trunc(num(profile.followerCount)),
    walls: candidate.top,
    categories: candidate.categories,
    similar,
    rank,
  };
  if (typeof profile.username === "string" && profile.username) entry.username = profile.username;
  if (typeof profile.profilePhoto === "string" && profile.profilePhoto) entry.profilePhoto = profile.profilePhoto;
  return entry;
}

/** Seams for tests: Auth and Remote Config are outside the fake database. */
export const creatorDirectoryDeps: {
  disabledUids: (uids: string[]) => Promise<Set<string>>;
  premium: () => Promise<string[]>;
} = {
  premium: premiumCollections,
  disabledUids: async (uids) => {
    const out = new Set<string>(uids);
    for (let i = 0; i < uids.length; i += CHUNK) {
      const {users} = await admin.auth().getUsers(uids.slice(i, i + CHUNK).map((uid) => ({uid})));
      for (const user of users) if (!user.disabled) out.delete(user.uid);
    }
    return out;
  },
};

function wallRow(doc: admin.firestore.DocumentData, premium: string[]): WallRow | null {
  if (doc.review !== true || !isWotdEligible(doc, premium)) return null;
  const created = doc.createdAt;
  const createdMs = created instanceof admin.firestore.Timestamp ? created.toMillis() : NaN;
  if (!Number.isFinite(createdMs)) return null;
  return {
    id: str(doc.id), creatorUid: str(doc.creatorUid), thumb: str(doc.wallpaper_thumb),
    category: str(doc.category), createdMs,
  };
}

/** Edges come from the `following` collection group. Other collections with that name are skipped. */
function edgeFrom(doc: admin.firestore.QueryDocumentSnapshot): FollowEdge | null {
  const parts = doc.ref.path.split("/");
  if (parts.length !== 4 || parts[0] !== PROFILES || parts[2] !== "following") return null;
  const created = doc.data().createdAt;
  return {
    followerUid: parts[1], targetUid: parts[3],
    createdMs: created instanceof admin.firestore.Timestamp ? created.toMillis() : 0,
  };
}

async function getDocs(refs: admin.firestore.DocumentReference[]): Promise<admin.firestore.DocumentSnapshot[]> {
  const out: admin.firestore.DocumentSnapshot[] = [];
  for (let i = 0; i < refs.length; i += CHUNK) out.push(...await Promise.all(refs.slice(i, i + CHUNK).map((r) => r.get())));
  return out;
}

async function projectedDocs(collection: string, uids: string[], fields: string[]): Promise<Array<Record<string, unknown> | undefined>> {
  const out: Array<Record<string, unknown> | undefined> = [];
  for (let i = 0; i < uids.length; i += CHUNK) {
    out.push(...await Promise.all(uids.slice(i, i + CHUNK).map(async (uid) => {
      const data = (await db.collection(collection).doc(uid).get()).data();
      if (!data) return undefined;
      return Object.fromEntries(fields.filter((field) => data[field] !== undefined).map((field) => [field, data[field]]));
    })));
  }
  return out;
}

/**
 * Rebuilds `creatorDirectory`. Reads every public approved wall, 7 days of wall stats, the newest 20k follow edges,
 * and three docs per candidate, then rechecks those docs when publishing. Writes one doc per listed creator.
 */
export async function rebuildCreatorDirectory(nowMs = Date.now()): Promise<{listed: number; removed: number}> {
  const premium = await creatorDirectoryDeps.premium();
  const [wallSnap, dailySnap, edgeSnap, existing] = await Promise.all([
    db.collection("walls").where("review", "==", true).select(
      "id", "creatorUid", "wallpaper_thumb", "category", "createdAt", "review", "originalProtected",
      "is_streak_exclusive", "dropReserved", "dropWeek", "collections",
    ).limit(MAX_WALLS).get(),
    db.collection(WALLPAPER_STATS_DAILY).where("day", "in", trendingDays(nowMs)).select("wallId", "day", "favs", "sets").limit(MAX_DAILY_DOCS).get(),
    db.collectionGroup("following").orderBy("createdAt", "desc").select("createdAt").limit(MAX_FOLLOW_EDGES).get(),
    db.collection(CREATOR_DIRECTORY).select().get(),
  ]);
  if (wallSnap.size >= MAX_WALLS) logger.warn("rebuildCreatorDirectory: walls hit the read cap.", {cap: MAX_WALLS});
  if (edgeSnap.size >= MAX_FOLLOW_EDGES) logger.warn("rebuildCreatorDirectory: follow edges hit the read cap.");

  const walls = wallSnap.docs.map((d) => wallRow(d.data(), premium)).filter((w): w is WallRow => w !== null);
  const daily = dailySnap.docs.map((d) => d.data()).map((d) => ({
    wallId: str(d.wallId), day: str(d.day), favs: num(d.favs), sets: num(d.sets),
  }));
  const edges = edgeSnap.docs.map(edgeFrom).filter((e): e is FollowEdge => e !== null);
  const candidates = planCandidates({walls, daily, edges, nowMs});

  const uids = candidates.map((c) => c.uid);
  const [users, profiles, barriers, disabled] = await Promise.all([
    projectedDocs(USERS, uids, ["deleted", "creatorDirectoryOptOut"]),
    projectedDocs(PROFILES, uids, ["name", "username", "profilePhoto", "followerCount"]),
    projectedDocs("creatorDeletionState", uids, ["closed"]),
    creatorDirectoryDeps.disabledUids(uids),
  ]);
  const listed = candidates
    .map((candidate, i) => ({candidate, user: users[i], profile: profiles[i], barrier: barriers[i]}))
    .filter(({candidate, user, profile, barrier}) => user && profile && user.deleted !== true &&
      user.creatorDirectoryOptOut !== true && barrier?.closed !== true && !disabled.has(candidate.uid))
    .sort((a, b) => b.candidate.score - a.candidate.score ||
      num(b.profile?.followerCount) - num(a.profile?.followerCount) || (a.candidate.uid < b.candidate.uid ? -1 : 1));
  const similar = similarCreators(listed.map(({candidate}) => candidate), edges);

  const updatedAt = admin.firestore.Timestamp.fromMillis(nowMs);
  const keep = new Set(listed.map(({candidate}) => candidate.uid));
  const writes = [
    ...listed.map(({candidate}, i) => () => db.runTransaction(async (tx) => {
      const uid = candidate.uid;
      const [user, profile, barrier] = await Promise.all([
        tx.get(db.collection(USERS).doc(uid)), tx.get(db.collection(PROFILES).doc(uid)),
        tx.get(db.collection("creatorDeletionState").doc(uid)),
      ]);
      const ref = db.collection(CREATOR_DIRECTORY).doc(uid);
      if (!user.exists || !profile.exists || user.data()?.deleted === true ||
        user.data()?.creatorDirectoryOptOut === true || barrier.data()?.closed === true) {
        tx.delete(ref);
        return;
      }
      tx.set(ref, {...directoryEntry(candidate, profile.data() ?? {}, i + 1, similar.get(uid) ?? []), updatedAt});
    })),
    ...existing.docs.filter((d) => !keep.has(d.id)).map((d) => () => d.ref.delete()),
  ];
  for (let i = 0; i < writes.length; i += CHUNK) await Promise.all(writes.slice(i, i + CHUNK).map((w) => w()));
  const removed = existing.docs.filter((d) => !keep.has(d.id)).length;
  logger.info("rebuildCreatorDirectory: done.", {
    listed: listed.length, removed, walls: wallSnap.size, daily: dailySnap.size, edges: edgeSnap.size,
  });
  return {listed: listed.length, removed};
}

export const buildCreatorDirectory = onSchedule(
  {schedule: "30 2 * * *", timeZone: "UTC", region: REGION, retryCount: 1, timeoutSeconds: 540, memory: "512MiB"},
  async (event) => {
    const ms = Date.parse(event.scheduleTime);
    await rebuildCreatorDirectory(Number.isFinite(ms) ? ms : Date.now());
  },
);

export type FollowedBy = {count: number; people: Array<{name: string; photo: string}>};

/**
 * People the viewer follows who also follow the creator. It never returns anyone the viewer does not follow, and
 * it returns names and photos only, never uids. A miss scans at most 500 of the viewer's follows and caches the
 * matching uids for a day. A hit re-reads only those follow edges. Shown people are checked live (deleted, disabled,
 * blocked in any direction) until three pass.
 */
export async function followedBy(viewerUid: string, creatorUid: string, nowMs = Date.now()): Promise<FollowedBy> {
  const day = utcDateString(new Date(nowMs));
  const rateRef = db.collection(FOLLOWED_BY_RATE).doc(viewerUid);
  await db.runTransaction(async (tx) => {
    const used = readDailyCount(await tx.get(rateRef), day);
    if (used >= MAX_FOLLOWED_BY_LOOKUPS_PER_DAY) throw new HttpsError("resource-exhausted", "Try again tomorrow.");
    tx.set(rateRef, {day, count: used + 1, expireAt: admin.firestore.Timestamp.fromMillis(nowMs + 2 * DAY_MS)});
  });

  const unavailable = async (uid: string, peers: string[]): Promise<boolean> => {
    const [user, profile, barrier, ...blocks] = await getDocs([
      db.collection(USERS).doc(uid), db.collection(PROFILES).doc(uid),
      db.collection("creatorDeletionState").doc(uid),
      ...peers.flatMap((peer) => [
        db.collection(USERS).doc(uid).collection("blockedUsers").doc(peer),
        db.collection(USERS).doc(peer).collection("blockedUsers").doc(uid),
      ]),
    ]);
    return !user.exists || !profile.exists || user.data()?.deleted === true ||
      barrier.data()?.closed === true || blocks.some((b) => b.exists);
  };
  const disabled = await creatorDirectoryDeps.disabledUids([viewerUid, creatorUid]);
  if (disabled.size || await unavailable(viewerUid, [creatorUid]) || await unavailable(creatorUid, [])) {
    return {count: 0, people: []};
  }

  const key = createHash("sha256").update(JSON.stringify([viewerUid, creatorUid])).digest("hex");
  const cacheRef = db.collection(FOLLOWED_BY_CACHE).doc(key);
  const cached = (await cacheRef.get()).data();
  const following = db.collection(PROFILES).doc(viewerUid).collection("following");
  let ordered: string[];
  if (cached?.expireAt instanceof admin.firestore.Timestamp && cached.expireAt.toMillis() > nowMs &&
    Array.isArray(cached.matches)) {
    const matches = (cached.matches as unknown[]).filter((uid): uid is string => typeof uid === "string")
      .slice(0, FOLLOWING_SCAN_CAP);
    const edges = await getDocs(matches.map((uid) => following.doc(uid)));
    ordered = matches.filter((_, i) => edges[i].exists);
  } else {
    const followingSnap = await following.orderBy("createdAt", "desc").limit(FOLLOWING_SCAN_CAP).get();
    const followed = followingSnap.docs.map((d) => d.id).filter((uid) => uid !== creatorUid && uid !== viewerUid);
    const followers = db.collection(PROFILES).doc(creatorUid).collection("followers");
    const matched = new Set<string>();
    for (let i = 0; i < followed.length; i += IN_CHUNK) {
      const chunk = followed.slice(i, i + IN_CHUNK);
      const snap = await followers.where("followerUid", "in", chunk).get();
      for (const doc of snap.docs) if (chunk.includes(doc.id)) matched.add(doc.id);
    }
    ordered = followed.filter((uid) => matched.has(uid));
    await cacheRef.set({matches: ordered, expireAt: admin.firestore.Timestamp.fromMillis(nowMs + FOLLOWED_BY_TTL_MS)});
  }

  // ponytail: count keeps people hidden by a block or ban; only the named ones are checked, to bound the reads.
  const people: FollowedBy["people"] = [];
  let hidden = 0;
  for (let i = 0; i < ordered.length && people.length < FOLLOWED_BY_PEOPLE; i += FOLLOWED_BY_PEOPLE) {
    const chunk = ordered.slice(i, i + FOLLOWED_BY_PEOPLE);
    const off = await creatorDirectoryDeps.disabledUids(chunk);
    for (const uid of chunk) {
      if (people.length >= FOLLOWED_BY_PEOPLE) break;
      if (off.has(uid) || await unavailable(uid, [viewerUid, creatorUid])) {
        hidden++;
        continue;
      }
      const profile = (await db.collection(PROFILES).doc(uid).get()).data();
      if (profile) people.push({name: str(profile.name) || str(profile.username), photo: str(profile.profilePhoto)});
    }
  }
  return {count: people.length ? ordered.length - hidden : 0, people};
}

export const getFollowedBy = onCall(
  {region: CALLABLE_REGIONS, cors: true, maxInstances: 10},
  async (request: CallableRequest<{creatorUid?: unknown}>): Promise<FollowedBy> => {
    const viewerUid = request.auth?.uid;
    if (!viewerUid) throw new HttpsError("unauthenticated", "Sign in to see who you follow.");
    const raw = request.data?.creatorUid;
    if (typeof raw !== "string" || !raw || raw.length > 128 || raw.includes("/") || raw === "." || raw === "..") {
      throw new HttpsError("invalid-argument", "creatorUid is invalid.");
    }
    if (raw === viewerUid) return {count: 0, people: []};
    return followedBy(viewerUid, raw);
  },
);
