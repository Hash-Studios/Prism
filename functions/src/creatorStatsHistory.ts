import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {onDocumentCreated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "./common";
import {HttpsError} from "firebase-functions/v2/https";
import {normalizeId} from "./viewStats";

export const METRICS = ["views", "saves", "sets", "downloads", "shares", "folderAdds", "remixes"] as const;
export type Metric = typeof METRICS[number];
export type Counts = Record<Metric, number | null>;
export type History = {
  wallPath: string; incarnation: string; creatorUid: string;
  from: string; weeks: Record<string, Partial<Record<Metric, number>>>;
  folderAdds: number;
};
const WEEK_MS = 7 * 86400000;
export const count = (value: unknown): number => typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : 0;
export const hash = (value: string): string => createHash("sha256").update(value).digest("hex");
export const incarnation = (snap: admin.firestore.DocumentSnapshot): string =>
  snap.createTime ? `${snap.createTime.seconds}:${snap.createTime.nanoseconds}` : "";
export const atOrAfter = (a: admin.firestore.Timestamp, b: admin.firestore.Timestamp): boolean =>
  a.seconds > b.seconds || a.seconds === b.seconds && a.nanoseconds >= b.nanoseconds;
export const historyRef = (snap: admin.firestore.DocumentSnapshot) =>
  db.collection("creatorStatsHistory").doc(hash(`${snap.ref.path}:${incarnation(snap)}`));

export function weekStart(ms: number): number {
  const d = new Date(ms);
  d.setUTCHours(0, 0, 0, 0);
  return d.getTime() - ((d.getUTCDay() + 6) % 7) * 86400000;
}
export function isoWeek(ms: number): string {
  const thursday = new Date(weekStart(ms) + 3 * 86400000);
  const year = thursday.getUTCFullYear();
  const first = weekStart(Date.UTC(year, 0, 4));
  return `${year}-W${String(1 + Math.round((weekStart(ms) - first) / WEEK_MS)).padStart(2, "0")}`;
}
export function weekWindows(now: number) {
  return Array.from({length: 8}, (_, i) => {
    const start = weekStart(now) - (7 - i) * WEEK_MS;
    return {week: isoWeek(start), start: new Date(start).toISOString(), endExclusive: new Date(start + WEEK_MS).toISOString()};
  });
}
export function addHistory(
  wall: admin.firestore.DocumentSnapshot, previous: History | undefined,
  metricDeltas: Partial<Record<Metric, number>>, eventMs: number, now: number,
): History {
  const valid = previous?.wallPath === wall.ref.path && previous.incarnation === incarnation(wall) &&
    previous.creatorUid === wall.data()?.creatorUid;
  const from = valid ? previous.from : new Date(now).toISOString();
  const keep = new Set(Array.from({length: 9}, (_, i) => isoWeek(weekStart(now) - i * WEEK_MS)));
  const weeks = Object.fromEntries(Object.entries(valid ? previous.weeks : {}).filter(([key]) => keep.has(key)));
  const key = isoWeek(eventMs);
  if (keep.has(key)) {
    const row = {...weeks[key]};
    for (const metric of METRICS) if (metricDeltas[metric]) row[metric] = count(row[metric]) + count(metricDeltas[metric]);
    weeks[key] = row;
  }
  return {wallPath: wall.ref.path, incarnation: incarnation(wall), creatorUid: str(wall.data()?.creatorUid),
    from, weeks, folderAdds: (valid ? count(previous.folderAdds) : 0) + count(metricDeltas.folderAdds)};
}

export async function activeOwner(tx: admin.firestore.Transaction, uid: string): Promise<boolean> {
  if (!uid || uid.includes("/")) return false;
  const [user, barrier] = await Promise.all([
    tx.get(db.doc(`usersv2/${uid}`)), tx.get(db.doc(`creatorDeletionState/${uid}`)),
  ]);
  return user.exists && user.data()?.deleted !== true && barrier.data()?.closed !== true;
}

export const MAX_IDENTITY_WALLS = 20000;
export async function readWallIdentities(tx: admin.firestore.Transaction) {
  const walls = await tx.get(db.collection("walls").select("id", "creatorUid", "review").limit(MAX_IDENTITY_WALLS + 1));
  if (walls.size > MAX_IDENTITY_WALLS) {
    throw new HttpsError("resource-exhausted", "Creator stats global identity capacity exceeded. Contact support.");
  }
  const identities = new Map<string, admin.firestore.QueryDocumentSnapshot | null>();
  for (const wall of walls.docs) {
    let id: string;
    try {
      id = normalizeId(wall.data().id);
    } catch {
      continue;
    }
    identities.set(id, identities.has(id) ? null : wall);
  }
  return identities;
}

export function canonicalWall(identities: Awaited<ReturnType<typeof readWallIdentities>>, id: string) {
  return identities.get(id) ?? undefined;
}

export async function projectDailyStats(
  path: string, now = Date.now(), eventSource?: admin.firestore.DocumentSnapshot,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const current = await tx.get(db.doc(path));
    const source = eventSource?.exists && eventSource.ref.path === path &&
      (!current.exists || incarnation(current) !== incarnation(eventSource)) ? eventSource : current;
    const data = source.data();
    if (!data || typeof data.wallId !== "string" || !/^\d{8}$/.test(str(data.day))) return;
    let id: string;
    try {
      id = normalizeId(data.wallId);
    } catch {
      return;
    }
    if (id !== data.wallId) return;
    const wall = canonicalWall(await readWallIdentities(tx), id);
    if (!wall || !wall.createTime || !source.createTime || !atOrAfter(source.createTime, wall.createTime) ||
      !await activeOwner(tx, str(wall.data()?.creatorUid))) return;
    const day = str(data.day);
    const eventMs = Date.parse(`${day.slice(0, 4)}-${day.slice(4, 6)}-${day.slice(6, 8)}T00:00:00Z`);
    if (!Number.isFinite(eventMs) || eventMs > now) return;
    const checkpointRef = db.collection("creatorStatsDailyCheckpoints").doc(hash(`${path}:${incarnation(source)}`));
    const ref = historyRef(wall);
    const [checkpoint, history] = await Promise.all([tx.get(checkpointRef), tx.get(ref)]);
    const previous = checkpoint.data();
    const deltas: Partial<Record<Metric, number>> = {};
    const next: Record<string, number> = {};
    for (const [field, metric] of Object.entries({views: "views", favs: "saves", sets: "sets", downloads: "downloads", shares: "shares"} as const)) {
      next[field] = Math.max(count(previous?.[field]), count(data[field]));
      deltas[metric] = next[field] - count(previous?.[field]);
    }
    if (!Object.values(deltas).some((value) => value > 0)) return;
    tx.set(ref, addHistory(wall, history.data() as History | undefined, deltas, eventMs, now));
    tx.set(checkpointRef, next);
  });
}
export const onCreatorStatsDailyWritten = onDocumentWritten(
  {document: "wallpaper_stats_daily/{dayId}", region: REGION, retry: true},
  async (event) => {
    if (!event.data?.after.exists) return;
    await projectDailyStats(event.data.after.ref.path, Date.now(), event.data.after);
  },
);

export async function countFolderCreation(source: admin.firestore.DocumentSnapshot, now = Date.now()): Promise<void> {
  const item = source.data();
  if (!item || !source.createTime || !["prism", "wall_of_the_day", "walloftheday"].includes(str(item.provider).toLowerCase())) return;
  const createdAt = source.createTime;
  const parts = source.ref.path.split("/");
  if (parts.length !== 4 || parts[0] !== "folders" || parts[2] !== "items") return;
  const marker = db.collection("creatorStatsFolderMarkers").doc(hash(`${source.ref.path}:${incarnation(source)}`));
  await db.runTransaction(async (tx) => {
    const [seen, folder] = await Promise.all([tx.get(marker), tx.get(db.doc(`folders/${parts[1]}`))]);
    if (seen.exists || !folder.exists || !item.ownerId || folder.data()?.ownerId !== item.ownerId ||
      !await activeOwner(tx, str(item.ownerId))) return;
    let id: string;
    try {
      id = normalizeId(item.id);
    } catch {
      return;
    }
    const docId = str(item.wallpaperDocumentId);
    if (docId.includes("/")) return;
    const wall = docId ? await tx.get(db.doc(`walls/${docId}`)) : canonicalWall(await readWallIdentities(tx), id);
    let wallId: string;
    try {
      wallId = normalizeId(wall?.data()?.id);
    } catch {
      return;
    }
    if (!wall?.exists || wallId !== id || wall.data()?.review !== true ||
      !wall.createTime || !atOrAfter(createdAt, wall.createTime) ||
      !await activeOwner(tx, str(wall.data()?.creatorUid))) return;
    const ref = historyRef(wall);
    const history = await tx.get(ref);
    tx.set(ref, addHistory(wall, history.data() as History | undefined, {folderAdds: 1}, createdAt.toMillis(), now));
    tx.create(marker, {counted: true});
  });
}
export const onCreatorStatsFolderCreated = onDocumentCreated(
  {document: "folders/{folderId}/items/{itemId}", region: REGION, retry: true},
  async (event) => {
    if (event.data) await countFolderCreation(event.data);
  },
);
