import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {emailToTopic, sendNotification, userIdToTopic} from "./notificationHelper";
import {db, REGION, str} from "./common";

export const WIN_BACK_STEPS = [3, 7, 14, 30, 60];

const DAY_MS = 24 * 60 * 60 * 1000;
const PAGE_SIZE = 300;
const CHUNK_SIZE = 25;
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
          .where(FIELD, ">=", admin.firestore.Timestamp.fromMillis(nowMs - (n + 1) * DAY_MS))
          .where(FIELD, "<", admin.firestore.Timestamp.fromMillis(nowMs - n * DAY_MS))
          .orderBy(FIELD)
          .limit(PAGE_SIZE);
        if (cursor) q = q.startAfter(cursor);
        const snap = await q.get();
        if (snap.empty) break;

        for (let i = 0; i < snap.docs.length; i += CHUNK_SIZE) {
          const results = await Promise.allSettled(
            snap.docs.slice(i, i + CHUNK_SIZE).map(async (doc) => {
              const data = doc.data();
              const uid = str(data.uid) || doc.id;
              const email = str(data.email).toLowerCase();
              const claimAt = data.coinState?.streakLastClaimServerAt;
              if (!uid || !(claimAt instanceof admin.firestore.Timestamp)) return false;
              const step = winBackStepFor(nowMs, claimAt.toMillis(), {
                step: data.winBack?.step,
                claimAtMs: data.winBack?.claimAt?.toMillis?.(),
              });
              if (step !== n) return false;

              const topics = [userIdToTopic(uid), ...(email ? [emailToTopic(email)] : [])];
              for (const topic of topics) {
                await sendNotification({
                  title: copy.title,
                  body: copy.body(wall.title),
                  data: {route: "wall_of_the_day", ...(wall.wallId ? {wall_id: wall.wallId} : {})},
                  imageUrl: wall.imageUrl,
                  modifier: email || uid,
                  channelId: "wall_of_the_day",
                  fcmTarget: {topic},
                  pushOnly: true,
                  collapseKey: `win_back_${n}`,
                });
              }
              await doc.ref.update({
                winBack: {step: n, claimAt, sentAt: admin.firestore.FieldValue.serverTimestamp()},
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
  },
);
