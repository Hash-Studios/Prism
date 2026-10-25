import * as admin from "firebase-admin";
import type {Message} from "firebase-admin/messaging";
import {randomUUID} from "node:crypto";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {db, REGION, CALLABLE_REGIONS} from "./common";
import {isAdminCaller} from "./adminConfig";
import {userPushTokens} from "./notificationHelper";

const LIVE_ACTIVITIES = "adminLiveActivities";
const START_COOLDOWN_MS = 120_000;
const SYNC_LEASE_MS = 120_000;
const IMMEDIATE_RETRY_CODES = new Set(["messaging/server-unavailable", "messaging/internal-error"]);
const PERMANENT_SEND_CODES = new Set([
  "messaging/invalid-argument",
  "messaging/registration-token-not-registered",
]);

export type ReviewQueueState = {pending: number; newestBy: string | null; oldestAt: number | null};

type ActivityDoc = {
  pushToStartToken: string | null;
  activityToken: string | null;
  startRequestedAtMs: number | null;
  lastStateKey: string | null;
};

type SendPlan = {event: "start" | "update" | "end"; token: string};

type ActivitySnapshot = {id: string; data: () => Record<string, unknown> | undefined};

type ActivityRef = ReturnType<ReturnType<typeof db.collection>["doc"]>;

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
  const laRef = db.collection(LIVE_ACTIVITIES);
  const snaps: ActivitySnapshot[] = onlyUid ? [await laRef.doc(onlyUid).get()] : (await laRef.get()).docs;
  let firstRetryError: unknown;

  for (const snap of snaps) {
    const uid = snap.id;
    const ref = laRef.doc(uid);
    let owner: string | null = null;
    let retryError: unknown;
    try {
      owner = await acquireSyncLease(ref);
      if (owner === null) {
        retryError = new HttpsError("unavailable", "Another review activity sync is still running.");
      } else {
        const leaseOwner = owner;
        let drain = true;
        while (drain) {
          drain = false;
          const current = await ref.get();
          const data = current.data();
          if (!data) break;
          if (!(await isActiveAdmin(uid))) break;
          const profile = await db.doc(`usersv2/${uid}`).get();
          if (!profile.exists || profile.data()?.loggedIn === false) {
            await clearSavedTokens(ref, leaseOwner, data);
            break;
          }

          const walls = await db.collection("walls")
            .where("review", "==", false)
            .orderBy("createdAt", "desc")
            .select("by", "createdAt", "dropWeek", "review")
            .get();
          const state = summarizeQueue(walls.docs.map((d) => d.data()));
          const doc: ActivityDoc = {
            pushToStartToken: typeof data.pushToStartToken === "string" ? data.pushToStartToken : null,
            activityToken: typeof data.activityToken === "string" ? data.activityToken : null,
            startRequestedAtMs: toMillis(data.startRequestedAt),
            lastStateKey: typeof data.lastStateKey === "string" ? data.lastStateKey : null,
          };
          const plan = planSend(doc, state, Date.now());
          if (plan) {
            const fcmToken = (await userPushTokens(uid, undefined))[0]?.token;
            if (!fcmToken) {
              logger.info("syncReviewLiveActivities: admin has no FCM token, skipping.", {uid});
              if (onlyUid !== undefined) {
                retryError = new HttpsError("unavailable", "The admin device is not ready for push delivery.");
              }
            } else {
              const now = admin.firestore.Timestamp.now();
              let sendError: unknown;
              try {
                await admin.messaging().send(buildLiveActivityMessage({
                  fcmToken,
                  liveActivityToken: plan.token,
                  event: plan.event,
                  state,
                  nowSeconds: Math.floor(now.toMillis() / 1000),
                }));
              } catch (firstError) {
                const firstCode = (firstError as {code?: unknown}).code;
                if (typeof firstCode === "string" && IMMEDIATE_RETRY_CODES.has(firstCode)) {
                  try {
                    await admin.messaging().send(buildLiveActivityMessage({
                      fcmToken,
                      liveActivityToken: plan.token,
                      event: plan.event,
                      state,
                      nowSeconds: Math.floor(now.toMillis() / 1000),
                    }));
                  } catch (secondError) {
                    sendError = secondError;
                  }
                } else {
                  sendError = firstError;
                }
              }
              if (sendError !== undefined) {
                const code = (sendError as {code?: unknown}).code;
                logger.warn("syncReviewLiveActivities: send failed.", {uid, event: plan.event, code});
                if (code === "messaging/registration-token-not-registered") {
                  await clearInvalidFcmToken(uid, fcmToken);
                }
                if (typeof code !== "string" || !PERMANENT_SEND_CODES.has(code)) retryError = sendError;
              } else {
                await recordSuccessfulSend(ref, leaseOwner, plan, state, now);
              }
            }
          }
          if (retryError !== undefined) break;
          drain = await releaseSyncLease(ref, leaseOwner, true);
          if (!drain) {
            owner = null;
          }
        }
      }
    } catch (err) {
      logger.error("syncReviewLiveActivities: failed for admin.", {uid, err});
      retryError ??= err;
    } finally {
      if (owner !== null) {
        try {
          await releaseSyncLease(ref, owner, false);
        } catch (err) {
          retryError ??= err;
        }
      }
    }
    if (retryError !== undefined) firstRetryError ??= retryError;
  }
  if (firstRetryError !== undefined) throw firstRetryError;
}

async function isActiveAdmin(uid: string): Promise<boolean> {
  let user: admin.auth.UserRecord;
  try {
    user = await admin.auth().getUser(uid);
  } catch (err) {
    if ((err as {code?: unknown}).code === "auth/user-not-found") return false;
    throw err;
  }
  if (user.disabled) return false;
  return isAdminCaller({token: {
    admin: user.customClaims?.admin,
    email: user.email,
    email_verified: user.emailVerified,
  }});
}

async function acquireSyncLease(ref: ActivityRef): Promise<string | null> {
  const owner = randomUUID();
  const acquired = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const data = snap.data();
    if (!data) return false;
    const leaseUntil = toMillis(data.syncLeaseUntil);
    if (leaseUntil !== null && leaseUntil > Date.now()) {
      transaction.set(ref, {syncRequested: true}, {merge: true});
      return false;
    }
    transaction.set(ref, {
      syncLeaseOwner: owner,
      syncLeaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + SYNC_LEASE_MS),
      syncRequested: false,
    }, {merge: true});
    return true;
  });
  return acquired ? owner : null;
}

async function clearSavedTokens(ref: ActivityRef, owner: string, previous: Record<string, unknown>): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const current = snap.data();
    if (current?.syncLeaseOwner !== owner) return;
    if (current.pushToStartToken !== previous.pushToStartToken || current.activityToken !== previous.activityToken) {
      transaction.set(ref, {syncRequested: true}, {merge: true});
      return;
    }
    transaction.set(ref, {
      pushToStartToken: null,
      activityToken: null,
      lastStateKey: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

async function clearInvalidFcmToken(uid: string, token: string): Promise<void> {
  const ref = db.doc(`usersv2/${uid}/private/session`);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (snap.data()?.fcmToken !== token) return;
    transaction.set(ref, {
      fcmToken: admin.firestore.FieldValue.delete(),
      fcmTokenBindingVersion: admin.firestore.FieldValue.delete(),
      fcmTokenBindingToken: admin.firestore.FieldValue.delete(),
    }, {merge: true});
  });
}

async function releaseSyncLease(ref: ActivityRef, owner: string, checkRequested: boolean): Promise<boolean> {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const data = snap.data();
    if (!data || data.syncLeaseOwner !== owner) return false;
    const repeat = checkRequested && data.syncRequested === true;
    transaction.set(ref, repeat ? {
      syncLeaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + SYNC_LEASE_MS),
      syncRequested: false,
    } : {
      syncLeaseOwner: admin.firestore.FieldValue.delete(),
      syncLeaseUntil: admin.firestore.FieldValue.delete(),
      syncRequested: false,
    }, {merge: true});
    return repeat;
  });
}

async function recordSuccessfulSend(
  ref: ActivityRef,
  owner: string,
  plan: SendPlan,
  state: ReviewQueueState,
  now: admin.firestore.Timestamp,
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const data = snap.data();
    const tokenField = plan.event === "start" ? "pushToStartToken" : "activityToken";
    if (data?.syncLeaseOwner !== owner || data[tokenField] !== plan.token) {
      if (data?.syncLeaseOwner === owner) transaction.set(ref, {syncRequested: true}, {merge: true});
      return;
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
    transaction.set(ref, update, {merge: true});
  });
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
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(ref);
        if (input.activityToken !== current.data()?.activityToken) update.lastStateKey = null;
        transaction.set(ref, update, {merge: true});
      });
    } else {
      await ref.set(update, {merge: true});
    }
    await syncReviewLiveActivities(uid);
    return {ok: true};
  },
);

export const onReviewQueueChanged = onDocumentWritten(
  {
    document: "walls/{wallId}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (isPendingWall(before) === isPendingWall(after)) return;
    await syncReviewLiveActivities();
  },
);
