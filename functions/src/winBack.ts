import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  sendNotification,
  userPushTokens,
} from "./notificationHelper";
import {db, REGION, str} from "./common";
import {
  notificationCopyPayload,
  type NotificationCopy,
} from "./notificationCatalog";

export const WIN_BACK_STEPS = [7, 14, 30, 60];

const DAY_MS = 24 * 60 * 60 * 1000;
/** Days a step stays open. A missed evening still sends the next day; the dedupe stamp blocks repeats. */
const WINDOW_DAYS = 2;
const PAGE_SIZE = 300;
const CHUNK_SIZE = 25;
const OPEN_FIELD = "lastAppOpenAt";
const OFFSET_FIELD = "appOpenTimezoneOffsetMinutes";
const EVENING_MINUTE = 18 * 60;
const OFFSET_STEP = 15;

function winBackCopy(step: number): NotificationCopy {
  switch (step) {
  case 7:
    return {kind: "winBack7"};
  case 14:
    return {kind: "winBack14"};
  case 30:
    return {kind: "winBack30"};
  case 60:
    return {kind: "winBack60"};
  default:
    throw new Error(`Unsupported win-back step: ${step}`);
  }
}

interface WinBackState {
  step?: number;
  /** Milliseconds of the last app open this sequence was sent for. */
  openAtMs?: number;
}

/**
 * Returns the step N whose window holds the inactivity (>= N days, < N + 2 days),
 * or null. Null also when this same last open already got step N or later.
 */
export function winBackStepFor(
  nowMs: number,
  lastOpenMs: number,
  state: WinBackState | undefined,
): number | null {
  const idle = nowMs - lastOpenMs;
  for (const n of WIN_BACK_STEPS) {
    if (idle >= n * DAY_MS && idle < (n + WINDOW_DAYS) * DAY_MS) {
      if (state?.openAtMs === lastOpenMs && (state.step ?? 0) >= n) return null;
      return n;
    }
  }
  return null;
}

/** UTC offsets (minutes, in 15 minute steps, -12:00 to +14:00) where it is 18:00 local at `nowMs`. */
export function offsetsAtEveningLocal(nowMs: number): number[] {
  const utcMinutes =
    Math.round(((nowMs / 60_000) % 1440) / OFFSET_STEP) * OFFSET_STEP;
  const base = (((EVENING_MINUTE - utcMinutes) % 1440) + 1440) % 1440;
  return [base, base - 1440].filter(
    (offset) => offset >= -720 && offset <= 840,
  );
}

function destination(step: number): string {
  if (step === 30) return "ai";
  if (step === 60) return "wall_of_the_day";
  return "home";
}

/** The slot the scheduler meant to run. A late run still sends to that slot. */
function scheduledAtMs(scheduleTime: string | undefined): number {
  const ms = Date.parse(scheduleTime ?? "");
  return Number.isFinite(ms) ? ms : Date.now();
}

function completedState(data: admin.firestore.DocumentData): WinBackState {
  const winBack = data.winBack;
  const openAt = winBack?.openAt;
  return {
    step: Number.isFinite(winBack?.step) ? winBack.step : undefined,
    openAtMs:
      openAt instanceof admin.firestore.Timestamp ?
        openAt.toMillis() :
        undefined,
  };
}

/** True only when the user turned marketing pushes off; an unreadable pref does not block the push. */
async function marketingPushesOff(uid: string): Promise<boolean> {
  try {
    return (
      (await db.doc(`usersv2/${uid}/private/session`).get()).data()
        ?.marketingPushes === false
    );
  } catch (err) {
    logger.warn("winBack: could not read the marketing push pref.", {
      uid,
      err,
    });
    return false;
  }
}

async function todaysWall(): Promise<{
  title: string;
  wallId?: string;
  imageUrl?: string;
}> {
  const fallback = {title: "A fresh pick"};
  try {
    const cur = await db.collection("wall_of_the_day").doc("current").get();
    const wallId = str(cur.data()?.wallId);
    if (!wallId) return fallback;
    const wall = (await db.collection("walls").doc(wallId).get()).data();
    if (!wall) return fallback;
    return {
      title: str(wall.title).trim() || fallback.title,
      wallId,
      imageUrl: str(wall.wallpaper_thumb) || undefined,
    };
  } catch (err) {
    logger.warn("winBack: could not read wall of the day.", {err});
    return fallback;
  }
}

export const sendWinBackPushes = onSchedule(
  {
    schedule: "*/15 * * * *",
    timeZone: "UTC",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
    maxInstances: 1,
  },
  async (event) => {
    const nowMs = scheduledAtMs(event.scheduleTime);
    const offsets = offsetsAtEveningLocal(nowMs);
    let wallPromise: ReturnType<typeof todaysWall> | undefined;
    const wallForDay60 = () => (wallPromise ??= todaysWall());
    let sent = 0;
    let failed = 0;

    for (const offset of offsets) {
      for (const n of WIN_BACK_STEPS) {
        const copy = notificationCopyPayload(winBackCopy(n));
        let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
        while (true) {
          let q = db
            .collection("usersv2")
            .where(OFFSET_FIELD, "==", offset)
            .where(
              OPEN_FIELD,
              ">",
              admin.firestore.Timestamp.fromMillis(
                nowMs - (n + WINDOW_DAYS) * DAY_MS,
              ),
            )
            .where(
              OPEN_FIELD,
              "<=",
              admin.firestore.Timestamp.fromMillis(nowMs - n * DAY_MS),
            )
            .orderBy(OPEN_FIELD)
            .limit(PAGE_SIZE);
          if (cursor) q = q.startAfter(cursor);
          const snap = await q.get();
          if (snap.empty) break;

          for (let i = 0; i < snap.docs.length; i += CHUNK_SIZE) {
            const results = await Promise.allSettled(
              snap.docs.slice(i, i + CHUNK_SIZE).map(async (doc) => {
                const data = doc.data();
                const uid = doc.id;
                const lastOpen = data.lastAppOpenAt;
                if (
                  data.deleted === true ||
                  data.loggedIn === false ||
                  !(lastOpen instanceof admin.firestore.Timestamp)
                ) {
                  return false;
                }
                const step = winBackStepFor(
                  nowMs,
                  lastOpen.toMillis(),
                  completedState(data),
                );
                if (step !== n) return false;
                if (await marketingPushesOff(uid)) return false;

                const wall = n === 60 ? await wallForDay60() : undefined;
                const targets = [
                  ...(await userPushTokens(uid, data.fcmToken)).map(
                    ({token, nativeLocalization}) => ({
                      fcmTarget: {token},
                      nativeLocalization,
                    }),
                  ),
                ];
                // The query snapshot can age while preferences and tokens are read. Recheck
                // activity and dedupe state immediately before sending.
                const current = (await doc.ref.get()).data();
                if (
                  !current ||
                  current.deleted === true ||
                  current.loggedIn === false ||
                  current.appOpenTimezoneOffsetMinutes !== offset ||
                  !(
                    current.lastAppOpenAt instanceof admin.firestore.Timestamp
                  ) ||
                  current.lastAppOpenAt.toMillis() !== lastOpen.toMillis() ||
                  winBackStepFor(
                    nowMs,
                    lastOpen.toMillis(),
                    completedState(current),
                  ) !== n
                ) {
                  return false;
                }
                if (targets.length === 0) return false;
                let accepted = 0;
                for (const {fcmTarget, nativeLocalization} of targets) {
                  const sent = await sendNotification({
                    ...copy,
                    data: {
                      route: destination(n),
                      push_kind: "win_back",
                      step: String(n),
                      ...(wall?.wallId ? {wall_id: wall.wallId} : {}),
                    },
                    imageUrl: wall?.imageUrl,
                    modifier: uid,
                    channelId: "recommendations",
                    scoreKind: "win_back",
                    pushOnly: true,
                    collapseKey: `win_back_${n}`,
                    fcmTarget,
                    nativeLocalization,
                  });
                  if (sent) accepted += 1;
                }
                if (accepted === 0) throw new Error("win-back push failed");
                await doc.ref.update({
                  winBack: {
                    step: n,
                    openAt: lastOpen,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                  },
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
    }
    logger.info("sendWinBackPushes: done", {sent, failed, offsets});
  },
);
