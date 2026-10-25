import * as admin from "firebase-admin";
import type {Message} from "firebase-admin/messaging";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db, REGION, CALLABLE_REGIONS} from "./common";
import {isAdminCaller} from "./adminConfig";
import {userPushTokens} from "./notificationHelper";

const LIVE_ACTIVITIES = "adminLiveActivities";
const START_COOLDOWN_MS = 120_000;
const DEAD_TOKEN_CODES = new Set(["messaging/registration-token-not-registered", "messaging/invalid-argument"]);

export type ReviewQueueState = {pending: number; newestBy: string | null; oldestAt: number | null};

type ActivityDoc = {
  pushToStartToken: string | null;
  activityToken: string | null;
  startRequestedAtMs: number | null;
  lastStateKey: string | null;
};

type SendPlan = {event: "start" | "update" | "end"; token: string};

export function isPendingWall(data: Record<string, unknown> | undefined): boolean {
  return data !== undefined && data.review === false && (data.dropWeek === undefined || data.dropWeek === null);
}

function toMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "object" && value !== null && typeof (value as {toMillis?: unknown}).toMillis === "function") {
    return (value as {toMillis: () => number}).toMillis();
  }
  return null;
}

export function summarizeQueue(docs: Array<Record<string, unknown>>): ReviewQueueState {
  const pending = docs.filter(isPendingWall);
  if (pending.length === 0) return {pending: 0, newestBy: null, oldestAt: null};
  const by = typeof pending[0].by === "string" ? pending[0].by.trim() : "";
  const oldestMs = toMillis(pending[pending.length - 1].createdAt);
  return {
    pending: pending.length,
    newestBy: by === "" ? null : by,
    oldestAt: oldestMs === null ? null : Math.floor(oldestMs / 1000),
  };
}

export function stateKey(s: ReviewQueueState): string {
  return `${s.pending}|${s.newestBy ?? ""}|${s.oldestAt ?? ""}`;
}

export function isApnsToken(raw: unknown): raw is string {
  return typeof raw === "string" && raw.length >= 16 && raw.length <= 512 && /^[0-9a-fA-F]+$/.test(raw);
}

export function buildLiveActivityMessage(args: {
  fcmToken: string;
  liveActivityToken: string;
  event: "start" | "update" | "end";
  state: ReviewQueueState;
  nowSeconds: number;
}): Message {
  const {fcmToken, liveActivityToken, event, state, nowSeconds} = args;
  const contentState: Record<string, unknown> = {pending: state.pending};
  if (state.newestBy !== null) contentState.newestBy = state.newestBy;
  if (state.oldestAt !== null) contentState.oldestAt = state.oldestAt;
  const aps: Record<string, unknown> = {"timestamp": nowSeconds, event, "content-state": contentState};
  if (event === "start") {
    aps["attributes-type"] = "PrismReviewAttributes";
    aps.attributes = {};
    aps.alert = {title: "Walls to review", body: `${state.pending} waiting for review`};
  }
  if (event === "end") aps["dismissal-date"] = nowSeconds;
  return {
    token: fcmToken,
    apns: {
      liveActivityToken,
      headers: {"apns-priority": event === "update" ? "5" : "10"},
      payload: {aps},
    },
  };
}

export function planSend(doc: ActivityDoc, state: ReviewQueueState, nowMs: number): SendPlan | null {
  if (state.pending === 0) {
    return doc.activityToken ? {event: "end", token: doc.activityToken} : null;
  }
  if (doc.activityToken) {
    return doc.lastStateKey === stateKey(state) ? null : {event: "update", token: doc.activityToken};
  }
  if (doc.pushToStartToken &&
    (doc.startRequestedAtMs === null || nowMs - doc.startRequestedAtMs > START_COOLDOWN_MS)) {
    return {event: "start", token: doc.pushToStartToken};
  }
  return null;
}

export async function syncReviewLiveActivities(onlyUid?: string): Promise<void> {
  const walls = await db.collection("walls")
    .where("review", "==", false)
    .orderBy("createdAt", "desc")
    .select("by", "createdAt", "dropWeek", "review")
    .get();
  const state = summarizeQueue(walls.docs.map((d) => d.data()));
  const laRef = db.collection(LIVE_ACTIVITIES);
  const snaps = onlyUid ? [await laRef.doc(onlyUid).get()] : (await laRef.get()).docs;

  for (const snap of snaps) {
    const uid = snap.id;
    const data = snap.data();
    if (!data) continue;
    try {
      const doc: ActivityDoc = {
        pushToStartToken: typeof data.pushToStartToken === "string" ? data.pushToStartToken : null,
        activityToken: typeof data.activityToken === "string" ? data.activityToken : null,
        startRequestedAtMs: toMillis(data.startRequestedAt),
        lastStateKey: typeof data.lastStateKey === "string" ? data.lastStateKey : null,
      };
      const plan = planSend(doc, state, Date.now());
      if (!plan) continue;
      const fcmToken = (await userPushTokens(uid, undefined))[0]?.token;
      if (!fcmToken) {
        logger.info("syncReviewLiveActivities: admin has no FCM token, skipping.", {uid});
        continue;
      }
      const now = admin.firestore.Timestamp.now();
      try {
        await admin.messaging().send(buildLiveActivityMessage({
          fcmToken,
          liveActivityToken: plan.token,
          event: plan.event,
          state,
          nowSeconds: Math.floor(now.toMillis() / 1000),
        }));
      } catch (err) {
        const code = (err as {code?: unknown}).code;
        logger.warn("syncReviewLiveActivities: send failed.", {uid, event: plan.event, code});
        if (typeof code === "string" && DEAD_TOKEN_CODES.has(code)) {
          const field = plan.event === "start" ? "pushToStartToken" : "activityToken";
          await laRef.doc(uid).set({[field]: null, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
        }
        continue;
      }
      const update: Record<string, unknown> = {
        lastStateKey: stateKey(state),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (plan.event === "start") update.startRequestedAt = now;
      if (plan.event === "end") {
        update.activityToken = null;
        update.lastStateKey = null;
      }
      await laRef.doc(uid).set(update, {merge: true});
    } catch (err) {
      logger.error("syncReviewLiveActivities: failed for admin.", {uid, err});
    }
  }
}

export const registerReviewLiveActivity = onCall(
  {
    region: CALLABLE_REGIONS,
    cors: true,
    maxInstances: 10,
  },
  async (request: CallableRequest<{pushToStartToken?: string | null; activityToken?: string | null}>) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to register the review Live Activity.");
    }
    if (!(await isAdminCaller(request.auth))) {
      throw new HttpsError("permission-denied", "Only admins can register the review Live Activity.");
    }
    const input = request.data ?? {};
    const keys = ["pushToStartToken", "activityToken"] as const;
    const present = keys.filter((key) => input[key] !== undefined);
    if (present.length === 0) {
      throw new HttpsError("invalid-argument", "Send pushToStartToken or activityToken.");
    }
    for (const key of present) {
      const value = input[key];
      if (value !== null && !isApnsToken(value)) {
        throw new HttpsError("invalid-argument", `${key} must be null or a hex APNs token.`);
      }
    }

    const ref = db.collection(LIVE_ACTIVITIES).doc(uid);
    const update: Record<string, unknown> = {updatedAt: admin.firestore.FieldValue.serverTimestamp()};
    for (const key of present) update[key] = input[key] ?? null;
    if (typeof input.activityToken === "string") {
      const prev = (await ref.get()).data();
      if (input.activityToken !== prev?.activityToken) update.lastStateKey = null;
    }
    await ref.set(update, {merge: true});
    await syncReviewLiveActivities(uid);
    return {ok: true};
  },
);

export const onReviewQueueChanged = onDocumentWritten(
  {
    document: "walls/{wallId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (isPendingWall(before) === isPendingWall(after)) return;
    await syncReviewLiveActivities();
  },
);
