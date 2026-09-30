import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {emailToTopic, userIdToTopic} from "./notificationHelper";
import {db, REGION, str} from "./common";

export const WIN_BACK_STEPS = [3, 7, 14, 30, 60];

const DAY_MS = 24 * 60 * 60 * 1000;
const PAGE_SIZE = 300;
const CHUNK_SIZE = 25;
const LEASE_MS = 10 * 60 * 1000;
const FIELD = "coinState.streakLastClaimServerAt";

const COPY: Record<number, {title: string; body: (wallTitle: string) => string}> = {
  3: {title: "Today's Wall of the Day is up", body: (t) => `${t} is waiting for you.`},
  7: {title: "Your feed has new walls", body: () => "Fresh wallpapers landed while you were away."},
  14: {title: "New walls are waiting", body: () => "Come see what creators added this fortnight."},
  30: {title: "New AI styles to try", body: () => "Make a wallpaper that feels like you."},
  60: {title: "Prism misses you", body: () => "Your next favourite wall is a tap away."},
};

interface WinBackState {
  step?: number;
  claimAtMs?: number;
}

/**
 * Returns the step N whose window holds the inactivity (>= N days, < N+1 days),
 * or null. Null also when this inactivity period already got step N or later.
 */
export function winBackStepFor(
  nowMs: number,
  lastActiveMs: number,
  state: WinBackState | undefined,
): number | null {
  const idle = nowMs - lastActiveMs;
  for (const n of WIN_BACK_STEPS) {
    if (idle >= n * DAY_MS && idle < (n + 1) * DAY_MS) {
      if (state?.claimAtMs === lastActiveMs && (state.step ?? 0) >= n) return null;
      return n;
    }
  }
  return null;
}

function completedState(data: admin.firestore.DocumentData): WinBackState {
  const winBack = data.winBack;
  return {
    step: Number.isFinite(winBack?.step) ? winBack.step : undefined,
    claimAtMs: winBack?.claimAt instanceof admin.firestore.Timestamp ? winBack.claimAt.toMillis() : undefined,
  };
}

async function todaysWall(): Promise<{title: string; wallId?: string; imageUrl?: string}> {
  const fallback = {title: "A fresh pick"};
  try {
    const cur = await db.collection("wall_of_the_day").doc("current").get();
    const wallId = str(cur.data()?.wallId);
    if (!wallId) return fallback;
    const wall = (await db.collection("walls").doc(wallId).get()).data();
    if (!wall) return fallback;
    return {title: str(wall.title).trim() || fallback.title, wallId, imageUrl: str(wall.wallpaper_thumb) || undefined};
  } catch (err) {
    logger.warn("winBack: could not read wall of the day.", {err});
    return fallback;
  }
}

export const sendWinBackPushes = onSchedule(
  {
    schedule: "30 18 * * *",
    timeZone: "Asia/Kolkata",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
    maxInstances: 1,
    retryCount: 3,
    minBackoffSeconds: LEASE_MS / 1000,
  },
  async () => {
    const nowMs = Date.now();
    const wall = await todaysWall();
    let sent = 0;
    let failed = 0;

    for (const n of WIN_BACK_STEPS) {
      const copy = COPY[n];
      let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
      while (true) {
        let q = db
          .collection("usersv2")
          .where(FIELD, ">", admin.firestore.Timestamp.fromMillis(nowMs - (n + 1) * DAY_MS))
          .where(FIELD, "<=", admin.firestore.Timestamp.fromMillis(nowMs - n * DAY_MS))
          .orderBy(FIELD)
          .limit(PAGE_SIZE);
        if (cursor) q = q.startAfter(cursor);
        const snap = await q.get();
        if (snap.empty) break;

        for (let i = 0; i < snap.docs.length; i += CHUNK_SIZE) {
          const results = await Promise.allSettled(
            snap.docs.slice(i, i + CHUNK_SIZE).map(async (doc) => {
              const data = doc.data();
              const uid = doc.id;
              const claimAt = data.coinState?.streakLastClaimServerAt;
              if (data.deleted === true || data.loggedIn === false ||
                  !(claimAt instanceof admin.firestore.Timestamp)) return false;
              const step = winBackStepFor(nowMs, claimAt.toMillis(), completedState(data));
              if (step !== n) return false;

              if (data.winBack?.pending?.id &&
                  data.winBack.pending.expiresAt instanceof admin.firestore.Timestamp &&
                  data.winBack.pending.expiresAt.toMillis() > nowMs) return false;
              const reservationId = randomUUID();
              const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + LEASE_MS);
              const topics = await db.runTransaction(async (tx) => {
                const current = await tx.get(doc.ref);
                const fresh = current.data();
                if (!current.exists || !fresh) return undefined;
                const freshClaimAt = fresh.coinState?.streakLastClaimServerAt;
                if (fresh.deleted === true || fresh.loggedIn === false ||
                    !(freshClaimAt instanceof admin.firestore.Timestamp) || !freshClaimAt.isEqual(claimAt) ||
                    winBackStepFor(nowMs, freshClaimAt.toMillis(), completedState(fresh)) !== n) return undefined;
                const pending = fresh.winBack?.pending;
                if (pending?.id && pending.expiresAt instanceof admin.firestore.Timestamp &&
                    pending.expiresAt.toMillis() > nowMs) {
                  return undefined;
                }
                const freshEmail = str(fresh.email);
                const freshTopics = [...new Set([userIdToTopic(uid), freshEmail && emailToTopic(freshEmail)].filter(Boolean))];
                tx.update(doc.ref, {
                  winBack: {...fresh.winBack, pending: {id: reservationId, step: n, claimAt, expiresAt}},
                });
                return freshTopics;
              });
              if (!topics) return false;

              const payload: admin.messaging.Message = {
                notification: {title: copy.title, body: copy.body(wall.title)},
                data: {
                  route: "wall_of_the_day",
                  ...(wall.wallId ? {wall_id: wall.wallId} : {}),
                  channel_id: "wall_of_the_day",
                  ...(wall.imageUrl ? {imageUrl: wall.imageUrl} : {}),
                },
                android: {
                  notification: {
                    channelId: "wall_of_the_day",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    ...(wall.imageUrl ? {imageUrl: wall.imageUrl} : {}),
                    tag: `win_back_${n}`,
                  },
                  collapseKey: `win_back_${n}`,
                  priority: "high",
                },
                apns: {
                  headers: {"apns-collapse-id": `win_back_${n}`},
                  payload: {aps: {sound: "default", badge: 1}},
                },
                condition: topics.map((topic) => `'${topic}' in topics`).join(" || "),
              };
              try {
                await admin.messaging().send(payload);
              } catch (err) {
                await db.runTransaction(async (tx) => {
                  const current = await tx.get(doc.ref);
                  const fresh = current.data();
                  if (!current.exists || !fresh || fresh.winBack?.pending?.id !== reservationId) return;
                  const winBack = {...fresh.winBack};
                  delete winBack.pending;
                  tx.update(doc.ref, {winBack});
                });
                throw err;
              }

              await db.runTransaction(async (tx) => {
                const current = await tx.get(doc.ref);
                const fresh = current.data();
                if (!current.exists || !fresh || fresh.winBack?.pending?.id !== reservationId) return;
                const freshClaimAt = fresh.coinState?.streakLastClaimServerAt;
                const winBack = {...fresh.winBack};
                delete winBack.pending;
                if (fresh.deleted !== true && fresh.loggedIn !== false &&
                    freshClaimAt instanceof admin.firestore.Timestamp && freshClaimAt.isEqual(claimAt)) {
                  tx.update(doc.ref, {
                    winBack: {...winBack, step: n, claimAt, sentAt: admin.firestore.FieldValue.serverTimestamp()},
                  });
                } else {
                  tx.update(doc.ref, {winBack});
                }
              });
              return true;
            }),
          );
          for (const r of results) {
            if (r.status === "fulfilled") {
              if (r.value) sent += 1;
            } else {
              failed += 1;
              logger.error("winBack: user failed.", {err: r.reason});
            }
          }
        }

        if (snap.size < PAGE_SIZE) break;
        cursor = snap.docs[snap.docs.length - 1];
      }
    }
    logger.info("sendWinBackPushes: done", {sent, failed});
    if (failed > 0) throw new Error(`winBack: ${failed} user(s) failed`);
  },
);
