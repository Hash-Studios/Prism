import * as admin from "firebase-admin";
import {FieldPath, Timestamp} from "firebase-admin/firestore";
import {randomUUID} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {db, REGION, str} from "./common";
import {activeOwner, addHistory, atOrAfter, canonicalWall, count, hash, History, incarnation, METRICS,
  readWallIdentities, IdentityCapacityError} from "./creatorStatsHistory";
import {normalizeId} from "./viewStats";

type DailyCounters = {views: number; favs: number; sets: number; downloads: number; shares: number};
type DailyQueue = {
  schemaVersion: 1; sourcePath: string; incarnation: string; sourceCreatedAt: Timestamp;
  wallId: string; day: string; counters: DailyCounters; firstEnqueuedAt: Timestamp;
  updatedAt: Timestamp; state: "ready" | "blocked"; failure?: {code: string; at: Timestamp};
};
type DailyCheckpoint = Omit<DailyQueue, "firstEnqueuedAt" | "updatedAt" | "state" | "failure">;
type ProcessorState = {schemaVersion: 1; owner: string | null; leaseUntil: Timestamp; notBefore: Timestamp};

const counterFields = ["views", "favs", "sets", "downloads", "shares"] as const;
const metrics = {views: "views", favs: "saves", sets: "sets", downloads: "downloads", shares: "shares"} as const;
const timestamp = (ms: number) => Timestamp.fromMillis(ms);
const queueKey = (path: string, sourceIncarnation: string) => hash(`${path}:${sourceIncarnation}`);
const processorRef = () => db.doc("creatorStatsProcessorState/daily");
const queueRef = (key: string) => db.collection("creatorStatsDailyQueue").doc(key);
const checkpointRef = (key: string) => db.collection("creatorStatsDailyCheckpoints").doc(key);
const eventCounters = (data: Record<string, unknown>): DailyCounters => Object.fromEntries(
  counterFields.map((field) => [field, count(data[field])]),
) as DailyCounters;
const maxCounters = (...values: DailyCounters[]): DailyCounters => Object.fromEntries(
  counterFields.map((field) => [field, Math.max(...values.map((value) => value[field]))]),
) as DailyCounters;
const sameCounters = (a: DailyCounters, b: DailyCounters) => counterFields.every((field) => a[field] === b[field]);
const validDay = (day: unknown, now: number): day is string => {
  if (typeof day !== "string" || !/^\d{8}$/.test(day)) return false;
  const ms = Date.parse(`${day.slice(0, 4)}-${day.slice(4, 6)}-${day.slice(6, 8)}T00:00:00.000Z`);
  return Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10).replace(/-/g, "") === day && ms <= now;
};
const validSourcePath = (path: string) => /^wallpaper_stats_daily\/[^/]+$/.test(path);
const validCounters = (value: unknown) => {
  const counters = value as Record<string, unknown> | undefined;
  return !!counters && counterFields.every((field) => Number.isSafeInteger(counters[field]) && Number(counters[field]) >= 0);
};
const identityMatches = (value: Record<string, unknown> | undefined, path: string, sourceIncarnation: string,
  sourceCreatedAt: Timestamp, wallId: string, day: string) =>
  value?.sourcePath === path && value.incarnation === sourceIncarnation &&
  value.sourceCreatedAt instanceof Timestamp && value.sourceCreatedAt.isEqual(sourceCreatedAt) &&
  value.wallId === wallId && value.day === day;
const safeJsonBytes = (value: unknown) => Buffer.byteLength(JSON.stringify(value), "utf8");

export async function enqueueCreatorStatsDaily(after: admin.firestore.DocumentSnapshot, now = Date.now()): Promise<void> {
  if (!after.exists) return;
  const path = after.ref.path;
  const data = after.data();
  const sourceIncarnation = incarnation(after);
  const sourceCreatedAt = after.createTime;
  if (!data || !(sourceCreatedAt instanceof Timestamp) || !sourceIncarnation || !validSourcePath(path) || !validDay(data.day, now) ||
    typeof data.wallId !== "string") {
    logger.info("Creator stats daily source rejected", {processed: 0, coalesced: 0, rejected: 1, blocked: 0});
    return;
  }
  let wallId: string;
  try {
    wallId = normalizeId(data.wallId);
  } catch {
    logger.info("Creator stats daily source rejected", {processed: 0, coalesced: 0, rejected: 1, blocked: 0});
    return;
  }
  if (wallId !== data.wallId) {
    logger.info("Creator stats daily source rejected", {processed: 0, coalesced: 0, rejected: 1, blocked: 0});
    return;
  }
  const day = data.day;
  const event = eventCounters(data);
  const key = queueKey(path, sourceIncarnation);
  const queue = queueRef(key);
  const outcome = await db.runTransaction(async (tx): Promise<"rejected" | "coalesced" | "blocked" | "enqueued"> => {
    const current = await tx.get(db.doc(path));
    const checkpoint = await tx.get(checkpointRef(key));
    const checkpointData = checkpoint.data() as Record<string, unknown> | undefined;
    const checkpointMetaOkay = !checkpointData || (checkpointData.schemaVersion === 1 && identityMatches(checkpointData,
      path, sourceIncarnation, sourceCreatedAt, wallId, day) && validCounters(checkpointData.counters) && safeJsonBytes(checkpointData) <= 2048);
    const accepted = eventCounters((checkpointData?.counters as Record<string, unknown> | undefined) ?? {});
    const currentData = current.data();
    const sameIncarnationChangedIdentity = !!(current.exists && current.createTime && incarnation(current) === sourceIncarnation &&
      (currentData?.wallId !== wallId || currentData?.day !== day));
    const matchingCurrent = current.exists && current.createTime && incarnation(current) === sourceIncarnation &&
      !sameIncarnationChangedIdentity;
    const merged = maxCounters(event, ...(matchingCurrent ? [eventCounters(currentData as Record<string, unknown>)] : []));
    if (checkpointMetaOkay && !sameIncarnationChangedIdentity && counterFields.every((field) => merged[field] <= accepted[field])) return "rejected";
    const queued = await tx.get(queue);
    const old = queued.data() as unknown as DailyQueue | undefined;
    const oldValid = !old || validQueue(old as unknown as Record<string, unknown>, key, now);
    const metadataOkay = checkpointMetaOkay && !sameIncarnationChangedIdentity && oldValid && (!old || identityMatches(
        old as unknown as Record<string, unknown>, path, sourceIncarnation, sourceCreatedAt, wallId, day));
    const counters = maxCounters(merged, eventCounters(old?.counters ?? {}));
    if (old && metadataOkay && sameCounters(counters, old.counters)) return "coalesced";
    const next: DailyQueue = {
      schemaVersion: 1, sourcePath: path, incarnation: sourceIncarnation, sourceCreatedAt, wallId, day, counters,
      firstEnqueuedAt: old?.firstEnqueuedAt instanceof Timestamp ? old.firstEnqueuedAt : timestamp(now), updatedAt: timestamp(now),
      state: metadataOkay ? old?.state ?? "ready" : "blocked",
      ...(!metadataOkay ? {failure: {code: "metadata_mismatch", at: timestamp(now)}} : old?.failure ? {failure: old.failure} : {}),
    };
    if (safeJsonBytes(next) > 4096) {
      return "rejected";
    }
    tx.set(queue, next);
    return !metadataOkay ? "blocked" : old ? "coalesced" : "enqueued";
  });
  logger.info("Creator stats daily source handled", {processed: 0, coalesced: outcome === "coalesced" ? 1 : 0,
    rejected: outcome === "rejected" ? 1 : 0, blocked: outcome === "blocked" ? 1 : 0});
}

function validQueue(value: Record<string, unknown> | undefined, id: string, now: number): value is Record<string, unknown> & DailyQueue {
  if (!value || value.schemaVersion !== 1 || typeof value.sourcePath !== "string" || !validSourcePath(value.sourcePath) ||
    typeof value.incarnation !== "string" || !value.incarnation || !(value.sourceCreatedAt instanceof Timestamp) ||
    value.incarnation !== `${value.sourceCreatedAt.seconds}:${value.sourceCreatedAt.nanoseconds}` ||
    typeof value.wallId !== "string" || typeof value.day !== "string" || !validDay(value.day, now) ||
    !(value.firstEnqueuedAt instanceof Timestamp) || !(value.updatedAt instanceof Timestamp) ||
    !["ready", "blocked"].includes(String(value.state)) || id !== queueKey(value.sourcePath, value.incarnation)) return false;
  try {
    if (normalizeId(value.wallId) !== value.wallId) return false;
  } catch {
    return false;
  }
  const failure = value.failure as Record<string, unknown> | undefined;
  if (failure && (typeof failure.code !== "string" || !/^[a-z0-9_]{1,48}$/.test(failure.code) ||
    !(failure.at instanceof Timestamp))) return false;
  return validCounters(value.counters) && safeJsonBytes(value) <= 4096;
}

function validCheckpoint(value: Record<string, unknown> | undefined, item: DailyQueue): value is Record<string, unknown> & DailyCheckpoint {
  if (!value || value.schemaVersion !== 1 || !identityMatches(value, item.sourcePath, item.incarnation,
    item.sourceCreatedAt, item.wallId, item.day)) return false;
  return validCounters(value.counters) && safeJsonBytes(value) <= 2048;
}

function validHistory(value: History, wall: admin.firestore.QueryDocumentSnapshot): boolean {
  if (safeJsonBytes(value) > 16384 || value.wallPath !== wall.ref.path || value.incarnation !== incarnation(wall) ||
    value.creatorUid !== str(wall.data()?.creatorUid) || typeof value.from !== "string" ||
    !Number.isFinite(Date.parse(value.from)) || !Number.isSafeInteger(value.folderAdds) || value.folderAdds < 0 ||
    typeof value.weeks !== "object" || value.weeks === null || Array.isArray(value.weeks)) return false;
  const allowed = new Set<string>(METRICS);
  return Object.entries(value.weeks).every(([week, row]) => /^\d{4}-W\d{2}$/.test(week) && !!row &&
    typeof row === "object" && !Array.isArray(row) && Object.entries(row).every(([metric, amount]) => allowed.has(metric) &&
      Number.isSafeInteger(amount) && Number(amount) >= 0));
}

const MAX_BATCH = 100;
const LEASE_MS = 600_000;
const WORK_BUDGET_MS = 240_000;
const CAPACITY_COOLDOWN_MS = 900_000;

async function acquireLease(clock: () => number): Promise<string | null> {
  const owner = randomUUID();
  const stateRef = processorRef();
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(stateRef);
    const state = snapshot.data() as unknown as ProcessorState | undefined;
    const now = clock();
    if (state?.owner && (state.leaseUntil?.toMillis() ?? 0) > now || (state?.notBefore?.toMillis() ?? 0) > now) return null;
    tx.set(stateRef, {schemaVersion: 1, owner, leaseUntil: timestamp(now + LEASE_MS), notBefore: state?.notBefore ?? timestamp(0)});
    return owner;
  });
}

type Candidate = {key: string; ref: FirebaseFirestore.DocumentReference; item: DailyQueue; checkpoint: DailyCheckpoint;
  checkpointAfter: DailyCheckpoint;
  deltas: Partial<Record<keyof typeof metrics, number>>; wall?: admin.firestore.QueryDocumentSnapshot; historyPath?: string};

type BatchResult = {processed: number; capacity: boolean; empty: boolean; rejected: number; blocked: number;
  oldestPendingAgeMs: number; durationMs: number};

async function processBatch(owner: string, observationNow: number | undefined, clock: () => number): Promise<BatchResult> {
  const now = observationNow ?? clock();
  const started = Date.now();
  const result = await db.runTransaction(async (tx) => {
    const stateSnapshot = await tx.get(processorRef());
    const state = stateSnapshot.data() as unknown as ProcessorState | undefined;
    if (state?.owner !== owner || state.leaseUntil.toMillis() <= clock()) {
      return {processed: 0, capacity: false, empty: true, rejected: 0, blocked: 0, oldestPendingAgeMs: 0};
    }
    const query = db.collection("creatorStatsDailyQueue").where("state", "==", "ready")
      .orderBy("firstEnqueuedAt", "asc").orderBy(FieldPath.documentId(), "asc").limit(MAX_BATCH);
    const page = await tx.get(query);
    if (page.empty) return {processed: 0, capacity: false, empty: true, rejected: 0, blocked: 0, oldestPendingAgeMs: 0};
    const rows = page.docs as unknown as Array<admin.firestore.QueryDocumentSnapshot>;
    const candidates: Candidate[] = [];
    const poison = new Map<string, {ref: FirebaseFirestore.DocumentReference; code: string}>();
    const rejectedItems = new Set<string>();
    for (const row of rows) {
      const value = row.data() as Record<string, unknown>;
      const ref = row.ref;
      if (!validQueue(value, row.id, now)) {
        poison.set(ref.path, {ref, code: "invalid_queue"});
        continue;
      }
      const item = value as unknown as DailyQueue;
      const key = row.id;
      const checkpointSnapshot = await tx.get(checkpointRef(key));
      const checkpointData = checkpointSnapshot.data() as Record<string, unknown> | undefined;
      if (checkpointData && !validCheckpoint(checkpointData, item)) {
        poison.set(ref.path, {ref, code: "metadata_mismatch"});
        continue;
      }
      const checkpoint: DailyCheckpoint = checkpointData as unknown as DailyCheckpoint ?? {
        schemaVersion: 1, sourcePath: item.sourcePath, incarnation: item.incarnation, sourceCreatedAt: item.sourceCreatedAt,
        wallId: item.wallId, day: item.day, counters: {views: 0, favs: 0, sets: 0, downloads: 0, shares: 0},
      };
      const checkpointAfter: DailyCheckpoint = {schemaVersion: 1, sourcePath: item.sourcePath, incarnation: item.incarnation,
        sourceCreatedAt: item.sourceCreatedAt, wallId: item.wallId, day: item.day,
        counters: maxCounters(eventCounters(checkpoint.counters as unknown as Record<string, unknown>), item.counters)};
      if (safeJsonBytes(checkpointAfter) > 2048) {
        poison.set(ref.path, {ref, code: "checkpoint_too_large"});
        continue;
      }
      const accepted = eventCounters(checkpoint.counters as unknown as Record<string, unknown>);
      const deltas = Object.fromEntries(counterFields.map((field) => [field, Math.max(0, item.counters[field] - accepted[field])])) as
        Partial<Record<keyof typeof metrics, number>>;
      if (!counterFields.some((field) => (deltas[field] ?? 0) > 0)) {
        candidates.push({key, ref, item, checkpoint, checkpointAfter, deltas: {}});
      } else {
        candidates.push({key, ref, item, checkpoint, checkpointAfter, deltas});
      }
    }
    const positive = candidates.filter((candidate) => Object.values(candidate.deltas).some((delta) => (delta ?? 0) > 0));
    if (positive.length) {
      const identities = await readWallIdentities(tx);
      for (const candidate of positive) {
        const wall = canonicalWall(identities, candidate.item.wallId);
        if (!wall?.createTime || wall.data()?.review !== true || !atOrAfter(candidate.item.sourceCreatedAt, wall.createTime)) {
          rejectedItems.add(candidate.ref.path);
          continue;
        }
        candidate.wall = wall;
        candidate.historyPath = `${wall.ref.path}:${incarnation(wall)}`;
      }
    }
    const ownerEligibility = new Map<string, boolean>();
    for (const candidate of positive) {
      if (!candidate.wall) continue;
      const uid = str(candidate.wall.data()?.creatorUid);
      if (!ownerEligibility.has(uid)) ownerEligibility.set(uid, await activeOwner(tx, uid));
      if (!ownerEligibility.get(uid)) {
        candidate.wall = undefined;
        rejectedItems.add(candidate.ref.path);
      }
    }
    const wallGroups = new Map<string, {wall: admin.firestore.QueryDocumentSnapshot; candidates: Candidate[]}>();
    for (const candidate of positive) {
      if (!candidate.wall || !candidate.historyPath) continue;
      const group = wallGroups.get(candidate.historyPath) ?? {wall: candidate.wall, candidates: []};
      group.candidates.push(candidate);
      wallGroups.set(candidate.historyPath, group);
    }
    const histories = new Map<string, History>();
    const failedWalls = new Map<string, string>();
    for (const [path, {wall, candidates: group}] of wallGroups) {
      const ref = db.collection("creatorStatsHistory").doc(hash(path));
      const stored = (await tx.get(ref)).data() as History | undefined;
      // A wall moved to a new owner starts fresh history, as addHistory does for the other projections.
      const previous = typeof stored?.creatorUid === "string" && stored.creatorUid !== str(wall.data()?.creatorUid) ?
        undefined : stored;
      let next = previous;
      if (previous && !validHistory(previous, wall)) {
        failedWalls.set(path, "invalid_history");
        continue;
      }
      for (const candidate of group) {
        const deltas = Object.fromEntries(Object.entries(candidate.deltas).map(([field, value]) => [metrics[field as keyof typeof metrics], value])) as
          Partial<Record<string, number>>;
        next = addHistory(wall, next, deltas, Date.parse(`${candidate.item.day.slice(0, 4)}-${candidate.item.day.slice(4, 6)}-${candidate.item.day.slice(6)}T00:00:00Z`), now);
        if (!validHistory(next, wall)) {
          const overflow = Object.values(next.weeks).some((row) => Object.values(row).some((amount) =>
            !Number.isSafeInteger(amount) || Number(amount) < 0)) || !Number.isSafeInteger(next.folderAdds);
          failedWalls.set(path, overflow ? "arithmetic_overflow" : "history_too_large");
          break;
        }
      }
      if (next && !failedWalls.has(path)) histories.set(path, next);
    }
    for (const [path, code] of failedWalls) {
      for (const candidate of wallGroups.get(path)?.candidates ?? []) poison.set(candidate.ref.path, {ref: candidate.ref, code});
      histories.delete(path);
    }
    const accepted = [...wallGroups].flatMap(([path, group]) => failedWalls.has(path) ? [] : group.candidates);
    const checkpoints = accepted.map((candidate) => candidate.checkpointAfter);
    const checkpointWrites = accepted.map((candidate, index) => ({path: checkpointRef(candidate.key).path, data: checkpoints[index]}));
    const historyWrites = [...histories].map(([path, data]) => ({path: db.collection("creatorStatsHistory").doc(hash(path)).path, data}));
    const blockedWrites = [...poison.values()].map(({ref, code}) => ({path: ref.path,
      data: {state: "blocked", failure: {code, at: timestamp(now)}}}));
    const queueWrites = rows.map((row) => ({path: row.ref.path, data: null}));
    const writePlanBytes = [...historyWrites, ...checkpointWrites, ...blockedWrites, ...queueWrites]
      .reduce((total, value) => total + Buffer.byteLength(value.path, "utf8") + safeJsonBytes(value.data ?? {}), 0);
    if (writePlanBytes > 4 * 1024 * 1024) throw new Error("Creator stats daily write plan exceeded 4 MiB");
    for (const [path, history] of histories) tx.set(db.collection("creatorStatsHistory").doc(hash(path)), history);
    for (let index = 0; index < accepted.length; index++) tx.set(checkpointRef(accepted[index].key), checkpoints[index]);
    for (const candidate of candidates) {
      if (poison.has(candidate.ref.path)) continue;
      tx.delete(candidate.ref);
    }
    for (const {ref, code} of poison.values()) tx.update(ref, {state: "blocked", failure: {code, at: timestamp(now)}});
    return {processed: rows.length, capacity: false, empty: false,
      rejected: rejectedItems.size, blocked: poison.size,
      oldestPendingAgeMs: Math.max(0, clock() - Math.min(...rows.map((row) => {
        const enqueuedAt = row.data().firstEnqueuedAt;
        return enqueuedAt instanceof Timestamp ? enqueuedAt.toMillis() : clock();
      })))};
  }, {maxAttempts: 1}).catch((error: unknown) => {
    if (error instanceof IdentityCapacityError) {
      return {processed: 0, capacity: true, empty: false, rejected: 0, blocked: 0, oldestPendingAgeMs: 0};
    }
    throw error;
  });
  const batch = {...result, durationMs: Date.now() - started};
  if (batch.capacity) {
    logger.error("Creator stats daily identity capacity stop", {capacityStop: true, processed: 0,
      rejected: 0, blocked: 0, oldestPendingAgeMs: 0, batchDurationMs: batch.durationMs});
  } else if (!batch.empty) {
    logger.info("Creator stats daily batch complete", {processed: batch.processed,
      rejected: batch.rejected, blocked: batch.blocked, oldestPendingAgeMs: batch.oldestPendingAgeMs,
      batchDurationMs: batch.durationMs, capacityStop: false});
  }
  return batch;
}

async function releaseLease(owner: string, now: number, capacity: boolean): Promise<void> {
  await db.runTransaction(async (tx) => {
    const stateRef = processorRef();
    const snapshot = await tx.get(stateRef);
    const state = snapshot.data() as unknown as ProcessorState | undefined;
    if (state?.owner !== owner) return;
    tx.set(stateRef, {schemaVersion: 1, owner: null, leaseUntil: timestamp(now),
      notBefore: timestamp(capacity ? now + CAPACITY_COOLDOWN_MS : state.notBefore.toMillis())});
  });
}

export async function processCreatorStatsDailyQueue(now?: number, clock: () => number = Date.now): Promise<void> {
  const started = clock();
  const owner = await acquireLease(clock);
  if (!owner) return;
  let capacity = false;
  let processed = 0;
  let rejected = 0;
  let blocked = 0;
  let oldestPendingAgeMs = 0;
  let batchDurationMs = 0;
  try {
    while (clock() - started < WORK_BUDGET_MS) {
      const batch = await processBatch(owner, now, clock);
      processed += batch.processed;
      rejected += batch.rejected;
      blocked += batch.blocked;
      oldestPendingAgeMs = Math.max(oldestPendingAgeMs, batch.oldestPendingAgeMs);
      batchDurationMs += batch.durationMs;
      if (batch.capacity) {
        capacity = true;
        break;
      }
      if (batch.empty) break;
    }
  } finally {
    await releaseLease(owner, clock(), capacity);
    logger.info("Creator stats daily queue invocation complete", {processed, coalesced: 0, rejected, blocked,
      oldestPendingAgeMs, batchDurationMs, capacityStop: capacity});
  }
}

export const processCreatorStatsDailyQueueScheduled = onSchedule({schedule: "every 1 minutes", timeZone: "UTC",
  region: REGION, timeoutSeconds: 540, retryCount: 0}, async () => processCreatorStatsDailyQueue());

export const onCreatorStatsDailyWritten = onDocumentWritten(
  {document: "wallpaper_stats_daily/{dayId}", region: REGION, retry: true},
  async (event) => {
    if (event.data?.after.exists) await enqueueCreatorStatsDaily(event.data.after);
  },
);
