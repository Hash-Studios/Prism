import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {isAdminCaller} from "../adminConfig";
import {db, readDailyCount, REGION, utcDateString} from "../common";
import {loadStudioConfig, STUDIO_MAX_CANDIDATES_PER_DAY} from "./config";
import {type Rng, studioCandidateId} from "./ids";
import {buildDailyPlan} from "./plan";
import {STUDIO_SERIES, STUDIO_SUBJECT_COOLDOWN_DAYS} from "./series";

const DAY_MS = 24 * 60 * 60 * 1000;

export interface StudioRunRequest {
  runId: string;
  /** Candidates to plan. Defaults to studioConfig dailyCandidates. */
  count?: number;
  /** Plan from this series only. */
  seriesId?: string;
  source: "schedule" | "manual";
  nowMs?: number;
  rng?: Rng;
}

export type StudioRunResult =
  | {status: "created"; runId: string; count: number}
  | {status: "exists" | "disabled" | "daily_cap" | "empty_plan"; runId: string; count: 0};

/**
 * Plans one run and writes it in one transaction: `studioRuns/{runId}`, a queued candidate per plan item, the day's
 * counter in `studioDaily/{yyyy-mm-dd}` and `studioSubjectUse/{subjectId}`. A run id that exists is a no-op, so a
 * second delivery of the same schedule plans nothing. The day's counter keeps all runs under maxCandidatesPerDay.
 */
export async function createStudioRun(request: StudioRunRequest): Promise<StudioRunResult> {
  const {runId} = request;
  const config = await loadStudioConfig();
  if (!config.generationEnabled) {
    logger.info("studio: generation is off; no run planned.", {runId});
    return {status: "disabled", runId, count: 0};
  }
  const nowMs = request.nowMs ?? Date.now();
  const day = utcDateString(new Date(nowMs));
  const requested = request.count ?? config.dailyCandidates;
  const series = request.seriesId ? STUDIO_SERIES.filter((s) => s.id === request.seriesId) : STUDIO_SERIES;
  const weights = request.seriesId ? {} : config.seriesWeights;
  const runRef = db.collection("studioRuns").doc(runId);
  const dailyRef = db.collection("studioDaily").doc(day);
  const usesRef = db.collection("studioSubjectUse");

  const result = await db.runTransaction(async (tx): Promise<StudioRunResult> => {
    if ((await tx.get(runRef)).exists) return {status: "exists", runId, count: 0};
    const used = readDailyCount(await tx.get(dailyRef), day);
    const allowed = Math.min(requested, config.maxCandidatesPerDay - used);
    if (allowed <= 0) return {status: "daily_cap", runId, count: 0};

    const cutoff = nowMs - STUDIO_SUBJECT_COOLDOWN_DAYS * DAY_MS;
    const recentSubjectIds = new Set<string>();
    const lastUsedMs = new Map<string, number>();
    for (const doc of (await tx.get(usesRef)).docs) {
      const at = doc.data().lastUsedAt;
      if (!(at instanceof admin.firestore.Timestamp)) continue;
      lastUsedMs.set(doc.id, at.toMillis());
      if (at.toMillis() >= cutoff) recentSubjectIds.add(doc.id);
    }
    const plan = buildDailyPlan({series, count: allowed, weights, recentSubjectIds, lastUsedMs,
      rng: request.rng ?? Math.random});
    if (plan.length === 0) return {status: "empty_plan", runId, count: 0};

    const now = admin.firestore.FieldValue.serverTimestamp();
    const usedAt = admin.firestore.Timestamp.fromMillis(nowMs);
    const size = {model: config.model, width: config.width, height: config.height};
    tx.create(runRef, {source: request.source, day, createdAt: now, requested, count: plan.length, ...size,
      ...(request.seriesId ? {seriesId: request.seriesId} : {})});
    tx.set(dailyRef, {day, count: used + plan.length, updatedAt: now});
    plan.forEach((item, index) => {
      tx.create(runRef.collection("candidates").doc(studioCandidateId(runId, index)), {
        ...item, ...size, runId, index, status: "queued", attempts: 0, createdAt: now, updatedAt: now,
      });
      tx.set(usesRef.doc(item.subjectId), {lastUsedAt: usedAt, seriesId: item.seriesId, lastRunId: runId});
    });
    return {status: "created", runId, count: plan.length};
  });
  logger.info("studio: run planned.", {...result, source: request.source, requested});
  return result;
}

/** Callable input: `count` 1..30 and an optional known `seriesId`. */
export function parseRunInput(data: unknown): {count: number; seriesId?: string} {
  const input = typeof data === "object" && data !== null ? data as Record<string, unknown> : {};
  const {count, seriesId} = input;
  if (typeof count !== "number" || !Number.isInteger(count) || count < 1 || count > STUDIO_MAX_CANDIDATES_PER_DAY) {
    throw new HttpsError("invalid-argument", `count must be a whole number from 1 to ${STUDIO_MAX_CANDIDATES_PER_DAY}.`);
  }
  if (seriesId == null) return {count};
  if (typeof seriesId !== "string" || !STUDIO_SERIES.some((s) => s.id === seriesId)) {
    throw new HttpsError("invalid-argument", "seriesId must be the id of a Prism Studio series.");
  }
  return {count, seriesId};
}

/** Every day at 20:00 UTC (01:30 IST): plans dailyCandidates candidates. */
export const planStudioBatch = onSchedule(
  {
    schedule: "0 20 * * *",
    timeZone: "UTC",
    region: REGION,
    retryCount: 2,
  },
  async (event) => {
    const scheduledMs = Date.parse(event.scheduleTime);
    const nowMs = Number.isFinite(scheduledMs) ? scheduledMs : Date.now();
    await createStudioRun({runId: `d${utcDateString(new Date(nowMs)).replace(/-/g, "")}`, source: "schedule", nowMs});
  },
);

/** Admin only: plans a run now. Input `{count, seriesId?}`, returns `{runId, count}`. */
export const runStudioBatch = onCall(
  {region: REGION, cors: true, maxInstances: 10},
  async (request: CallableRequest<unknown>) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to run Prism Studio.");
    if (!(await isAdminCaller(request.auth))) throw new HttpsError("permission-denied", "Only admins can run Prism Studio.");
    const input = parseRunInput(request.data);
    const result = await createStudioRun({runId: `m${Date.now()}`, ...input, source: "manual"});
    switch (result.status) {
    case "created":
      return {runId: result.runId, count: result.count};
    case "disabled":
      throw new HttpsError("failed-precondition", "Prism Studio generation is off in studioConfig/current.");
    case "daily_cap":
      throw new HttpsError("resource-exhausted", "Today's Prism Studio candidate limit is reached.");
    default:
      throw new HttpsError("failed-precondition", `No run was planned (${result.status}).`);
    }
  },
);
