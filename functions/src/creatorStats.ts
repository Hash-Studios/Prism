import * as admin from "firebase-admin";
import {FieldPath, FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {db, CALLABLE_REGIONS, REGION, str} from "./common";
import {normalizeId} from "./viewStats";
import {notificationCopyPayload} from "./notificationCatalog";
import {activeOwner, atOrAfter, canonicalWall, count, hash, historyRef, incarnation, isoWeek, METRICS,
  readWallIdentities, weekStart, weekWindows, type Counts, type History, type Metric} from "./creatorStatsHistory";

const MAX_WALLS = 500;
const CACHE_MS = 5 * 60000;
type Week = ReturnType<typeof weekWindows>[number] & {metrics: Counts};
type WallStats = {wallId: string; title: string; thumbnailUrl: string; totals: Counts; weeks: Week[]};
type Coverage = {weeklyFrom: string | null; totalBasis: "recordedLifetime" | "currentMembership" | "since"; totalFrom: string | null};
export type CreatorStats = {
  schemaVersion: 1; generatedAt: string; asOf: string; timezone: "UTC";
  approvedWallCount: number; totals: Counts; coverage: Record<Metric, Coverage>; weeks: Week[]; walls: WallStats[];
};
type CachedWall = {at: number; row: WallStats; from: string | null};
const counts = (value: (metric: Metric) => number | null): Counts => Object.fromEntries(
  METRICS.map((metric) => [metric, value(metric)]),
) as Counts;
const capacity = () => new HttpsError("resource-exhausted", "Creator stats capacity exceeded. Contact support.");
function sum(rows: Counts[]): Counts {
  return counts((metric) => {
    if (rows.some((row) => row[metric] === null)) return null;
    const total = rows.reduce((value, row) => value + (row[metric] ?? 0), 0);
    if (!Number.isSafeInteger(total)) throw capacity();
    return total;
  });
}
async function wallStats(tx: admin.firestore.Transaction, wall: admin.firestore.QueryDocumentSnapshot, uid: string, now: number,
  identities: Awaited<ReturnType<typeof readWallIdentities>>) {
  const data = wall.data();
  let statsId = "";
  try {
    statsId = normalizeId(data.id);
  } catch {/* Legacy walls can have no stats ID. */}
  const canonical = statsId ? canonicalWall(identities, statsId) : undefined;
  const unique = canonical?.ref.path === wall.ref.path;
  const key = hash(JSON.stringify([uid, wall.ref.path, incarnation(wall), data.id ?? null,
    data.title ?? null, data.wallpaper_thumb ?? null, data.remixCount ?? null, unique]));
  const ref = db.collection("creatorStatsCache").doc(key);
  const cached = (await tx.get(ref)).data() as CachedWall | undefined;
  if (cached && cached.at <= now && now - cached.at < CACHE_MS && isoWeek(cached.at) === isoWeek(now)) {
    return {ref, cache: cached, write: false};
  }
  const raw = (await tx.get(historyRef(wall))).data() as History | undefined;
  const history = raw?.creatorUid === uid && raw.wallPath === wall.ref.path && raw.incarnation === incarnation(wall) ? raw : undefined;
  const statsSnap = unique ? await tx.get(db.doc(`wallpaper_stats/${statsId}`)) : undefined;
  const stats = statsSnap?.createTime && wall.createTime && atOrAfter(statsSnap.createTime, wall.createTime) ?
    statsSnap.data() : undefined;
  const fields = {views: "views", saves: "favs", sets: "sets", downloads: "downloads", shares: "shares"} as const;
  const totals = counts((metric) => {
    if (metric === "remixes") {
      return typeof data.remixCount === "number" &&
      Number.isSafeInteger(data.remixCount) && data.remixCount >= 0 ? data.remixCount : null;
    }
    if (metric === "folderAdds") return history ? count(history.folderAdds) : null;
    if (!unique || !stats) return null;
    const raw = stats[fields[metric]];
    const value = typeof raw === "string" && /^\d+$/.test(raw) ? Number(raw) : raw;
    return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
  });
  const weeks = weekWindows(now).map((window) => ({...window, metrics: counts((metric) => {
    const recorded = history?.weeks[window.week]?.[metric];
    if (recorded !== undefined) return count(recorded);
    return history && window.start >= history.from ? 0 : null;
  })}));
  const row: WallStats = {wallId: wall.id, title: str(data.title), thumbnailUrl: str(data.wallpaper_thumb), totals, weeks};
  const cache: CachedWall = {at: now, row, from: history?.from ?? null};
  if (Buffer.byteLength(JSON.stringify(cache)) > 12000) throw capacity();
  return {ref, cache, write: true};
}
export async function readCreatorStats(uid: string, input: unknown, now = Date.now()): Promise<CreatorStats> {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to view creator stats.");
  if (!input || typeof input !== "object" || Array.isArray(input) || Object.keys(input).length !== 0) {
    throw new HttpsError("invalid-argument", "getCreatorStats accepts an empty object only.");
  }
  return db.runTransaction(async (tx) => {
    if (!await activeOwner(tx, uid)) throw new HttpsError("failed-precondition", "The creator account is unavailable.");
    const walls = await tx.get(db.collection("walls").where("creatorUid", "==", uid).where("review", "==", true).limit(MAX_WALLS + 1));
    if (walls.size > MAX_WALLS) throw capacity();
    const identities = walls.empty ? new Map() : await readWallIdentities(tx);
    const results: Awaited<ReturnType<typeof wallStats>>[] = [];
    for (let i = 0; i < walls.size; i += 10) {
      results.push(...await Promise.all(walls.docs.slice(i, i + 10).map((wall) => wallStats(tx, wall, uid, now, identities))));
    }
    const rows = results.map(({cache}) => cache.row);
    const froms = results.map(({cache}) => cache.from);
    const from = froms.length && froms.every((value): value is string => value !== null) ? froms.sort().slice(-1)[0] : null;
    const coverage = Object.fromEntries(METRICS.map((metric) => [metric, {
      weeklyFrom: from, totalBasis: metric === "saves" || metric === "remixes" ? "currentMembership" :
        metric === "folderAdds" ? "since" : "recordedLifetime", totalFrom: metric === "folderAdds" && from ? froms[0] : null,
    }])) as Record<Metric, Coverage>;
    const response: CreatorStats = {schemaVersion: 1, generatedAt: new Date(now).toISOString(),
      asOf: new Date(Math.min(now, ...results.map(({cache}) => cache.at))).toISOString(), timezone: "UTC",
      approvedWallCount: rows.length, totals: sum(rows.map((row) => row.totals)), coverage,
      weeks: weekWindows(now).map((window, i) => ({...window, metrics: sum(rows.map((row) => row.weeks[i].metrics))})), walls: rows};
    if (Buffer.byteLength(JSON.stringify(response)) > 3 * 1024 * 1024) throw capacity();
    for (const result of results) {
      if (result.write) {
        tx.set(result.ref, {...result.cache,
          expireAt: Timestamp.fromMillis(now + CACHE_MS)});
      }
    }
    return response;
  });
}
export const getCreatorStats = onCall(
  {region: CALLABLE_REGIONS, cors: true, maxInstances: 10, timeoutSeconds: 120},
  async (request: CallableRequest<unknown>) => readCreatorStats(request.auth?.uid ?? "", request.data),
);
export async function deliverCreatorWeek(uid: string, now: number): Promise<boolean> {
  const week = isoWeek(weekStart(now) - 7 * 86400000);
  const marker = db.collection("creatorStatsWeeklyMarkers").doc(hash(`${uid}:${week}`));
  return db.runTransaction(async (tx) => {
    if ((await tx.get(marker)).exists) return false;
    if (!await activeOwner(tx, uid)) return false;
    const [user, session, walls] = await Promise.all([
      tx.get(db.doc(`usersv2/${uid}`)), tx.get(db.doc(`usersv2/${uid}/private/session`)),
      tx.get(db.collection("walls").where("creatorUid", "==", uid).where("review", "==", true).limit(MAX_WALLS + 1)),
    ]);
    if (session.data()?.postAlerts === false || !str(user.data()?.email)) return false;
    if (walls.size > MAX_WALLS) throw capacity();
    let activity = false;
    for (const wall of walls.docs) {
      const data = (await tx.get(historyRef(wall))).data() as History | undefined;
      if (data?.creatorUid === uid && data.wallPath === wall.ref.path && data.incarnation === incarnation(wall) &&
        METRICS.some((metric) => count(data.weeks[week]?.[metric]) > 0)) activity = true;
    }
    if (!activity) return false;
    const copy = notificationCopyPayload({kind: "creatorStatsWeekly", week});
    tx.create(db.collection("notifications").doc(`creator_stats_${hash(`${uid}:${week}`)}`), {
      notification: {title: copy.title, body: copy.body}, message: {kind: copy.message.kind, args: copy.message.args},
      data: {route: "creator_stats", url: "prism://creator-stats", pageName: "", arguments: [],
        imageUrl: "", notification_kind: "creator_stats_weekly"},
      modifier: str(user.data()?.email), pushHandled: true, createdAt: FieldValue.serverTimestamp()});
    tx.create(marker, {sent: true});
    return true;
  });
}
export async function sendCreatorWeeklyStats(now: number): Promise<void> {
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  let failures = 0;
  for (;;) {
    let query = db.collection("walls").where("review", "==", true).orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const uid of new Set(page.docs.map((wall) => str(wall.data().creatorUid)).filter(Boolean))) {
      try {
        await deliverCreatorWeek(uid, now);
      } catch (err) {
        failures++;
        logger.error("Creator stats weekly delivery failed.", {uid, err});
      }
    }
    if (page.size < 100) break;
    cursor = page.docs[page.docs.length - 1];
  }
  if (failures) throw new Error(`Creator stats weekly delivery failed for ${failures} visits.`);
}
export const creatorStatsWeekly = onSchedule(
  {schedule: "0 9 * * 1", timeZone: "UTC", region: REGION, retryCount: 3, timeoutSeconds: 540},
  async (event) => sendCreatorWeeklyStats(Date.parse(event.scheduleTime)),
);
