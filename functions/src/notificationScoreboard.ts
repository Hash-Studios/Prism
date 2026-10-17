import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {db, REGION, str, utcDateString} from "./common";

/** Kinds shared with the app. A personal push to the uid topic and the token counts as two attempts. */
export const NOTIFICATION_KINDS = [
  "wotd",
  "wotd_creator",
  "streak_reminder",
  "follower",
  "post",
  "moderation",
  "campaign",
  "rejection",
  "win_back",
] as const;

export type NotificationKind = (typeof NOTIFICATION_KINDS)[number];

const KIND_OUTCOMES = ["sends", "accepts", "fails", "taps", "returnedNextDay"] as const;
type KindOutcome = (typeof KIND_OUTCOMES)[number];

const INSTALL_ID = /^[A-Za-z0-9_-]{8,80}$/;

/** Spreads one UTC day across shard docs so a burst does not all transact on one document. */
export const SCOREBOARD_SHARD_COUNT = 32;

/** `{utc date}_{00-31}`. The date prefix stays sortable. */
export function scoreboardShardDocId(day: string, index: number): string {
  const shard = ((index % SCOREBOARD_SHARD_COUNT) + SCOREBOARD_SHARD_COUNT) % SCOREBOARD_SHARD_COUNT;
  return `${day}_${String(shard).padStart(2, "0")}`;
}

function randomShardDocId(day: string): string {
  return scoreboardShardDocId(day, Math.floor(Math.random() * SCOREBOARD_SHARD_COUNT));
}

/** Stable shard for a signal so a transaction retry updates the same counter. */
function signalShardDocId(day: string, signalId: string): string {
  let hash = 0;
  for (let i = 0; i < signalId.length; i++) hash = (hash + signalId.charCodeAt(i)) % SCOREBOARD_SHARD_COUNT;
  return scoreboardShardDocId(day, hash);
}

export function isNotificationKind(value: string): value is NotificationKind {
  return (NOTIFICATION_KINDS as readonly string[]).includes(value);
}

/** Explicit scoreKind, then push_kind, then the route. Unknown routes are not counted. */
export function scoreKindFor(input: {
  scoreKind?: string;
  data?: {route?: string; push_kind?: string; report_id?: string};
}): NotificationKind | null {
  const explicit = input.scoreKind || input.data?.push_kind || "";
  if (isNotificationKind(explicit)) return explicit;
  const route = input.data?.route ?? "";
  const report = (input.data?.report_id ?? "").length > 0;
  switch (route) {
  case "streak_reminder":
    return "streak_reminder";
  case "follower":
    return "follower";
  case "wall_of_the_day":
    return "wotd";
  case "content_report":
    return "moderation";
  case "wall":
    return report ? "moderation" : "post";
  default:
    return null;
  }
}

function countMap(value: unknown): Record<string, number> {
  if (!value || typeof value !== "object") return {};
  const out: Record<string, number> = {};
  for (const [key, count] of Object.entries(value as Record<string, unknown>)) {
    if (typeof count === "number" && Number.isFinite(count)) out[key] = count;
  }
  return out;
}

/** Adds one to `outcome.kind` and keeps the other kinds in that map. */
export function applyScore(
  current: Record<string, unknown> | undefined,
  outcome: KindOutcome,
  kind: string,
): Record<string, number> {
  const bucket = countMap(current?.[outcome]);
  bucket[kind] = (bucket[kind] ?? 0) + 1;
  return bucket;
}

function counterRef(docId: string) {
  return db.doc(`metrics/notificationScoreboard/days/${docId}`);
}

/** Test stubs implement get and nothing else. A live ref exposes the Firestore client. */
function isLiveRef(ref: unknown): boolean {
  return !!ref && typeof ref === "object" && "firestore" in ref;
}

/**
 * Counts one FCM attempt. Accepts are API accepts, not impressions.
 * A failure here never fails the push.
 */
export async function recordPushOutcome(kind: string, outcome: "sends" | "accepts" | "fails", at = new Date()): Promise<void> {
  if (!isNotificationKind(kind)) return;
  try {
    const ref = counterRef(randomShardDocId(utcDateString(at)));
    if (!isLiveRef(ref)) return;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      tx.set(ref, {[outcome]: applyScore(snap.data(), outcome, kind)}, {merge: true});
    });
  } catch (err) {
    logger.warn("notification scoreboard write failed", {kind, outcome, err});
  }
}

export type SignalPlan =
  | {ok: true; signalId: string; field: KindOutcome | "permissionGranted" | "permissionDeclined"; kind?: NotificationKind}
  | {ok: false; code: "unauthenticated" | "invalid-argument"; message: string};

/** Decides the dedupe doc and the counter. The callable does the write. */
export function planNotificationSignal(
  authUid: string | undefined,
  body: Record<string, unknown>,
  day: string,
): SignalPlan {
  const type = str(body.type);
  const kindRaw = str(body.kind);
  const installId = str(body.installId);
  if (type === "tap" || type === "returned_next_day") {
    if (!authUid) return {ok: false, code: "unauthenticated", message: "Sign in required."};
    if (!isNotificationKind(kindRaw)) return {ok: false, code: "invalid-argument", message: "Unknown kind."};
    const label = type === "tap" ? "tap" : "return";
    return {
      ok: true,
      signalId: `${authUid}_${label}_${day}_${kindRaw}`,
      field: type === "tap" ? "taps" : "returnedNextDay",
      kind: kindRaw,
    };
  }
  if (type === "permission") {
    const result = str(body.result);
    if (result !== "granted" && result !== "declined") {
      return {ok: false, code: "invalid-argument", message: "Unknown permission result."};
    }
    const who = authUid || installId;
    if (!who || (!authUid && !INSTALL_ID.test(installId))) {
      return {ok: false, code: "invalid-argument", message: "An id is required."};
    }
    return {
      ok: true,
      signalId: `${who}_permission_${day}`,
      field: result === "granted" ? "permissionGranted" : "permissionDeclined",
    };
  }
  return {ok: false, code: "invalid-argument", message: "Unknown signal."};
}

async function claimSignal(plan: Extract<SignalPlan, {ok: true}>, day: string): Promise<boolean> {
  const signal = db.doc(`metrics/notificationScoreboard/signals/${plan.signalId}`);
  const ref = counterRef(signalShardDocId(day, plan.signalId));
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(signal);
    if (existing.exists) return false;
    const snap = await tx.get(ref);
    const data = snap.data();
    const patch = plan.kind ?
      {[plan.field]: applyScore(data, plan.field as KindOutcome, plan.kind)} :
      {[plan.field]: (typeof data?.[plan.field] === "number" ? data[plan.field] as number : 0) + 1};
    tx.set(signal, {at: admin.firestore.FieldValue.serverTimestamp()});
    tx.set(ref, patch, {merge: true});
    return true;
  });
}

/** Records a tap, a next-day return, or a permission result. One credit per id per UTC day. */
export const recordNotificationSignal = onCall({region: REGION}, async (request) => {
  const body = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const day = utcDateString();
  const plan = planNotificationSignal(request.auth?.uid, body, day);
  if (!plan.ok) throw new HttpsError(plan.code, plan.message);
  const counted = await claimSignal(plan, day);
  return {ok: true, counted};
});
