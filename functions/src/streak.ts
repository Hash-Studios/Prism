import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onCall, HttpsError, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {isLoggedOut, pickFcmToken, sendNotification, userPushTokens} from "./notificationHelper";
import {coinTransactionDoc, db, int, REGION, str} from "./common";

const USERS_COLLECTION = "usersv2";
const COIN_TX_COLLECTION = "coinTransactions";

const STREAK_REWARD_DAY_7_DAILY = 15;
const STREAK_DAY7_BONUS = 40;
const PRO_STREAK_DAILY_BONUS = 5;
const PRO_STREAK_7_BONUS = 20;

const DEFAULT_TZ_OFFSET_MINUTES = 330;
const REMINDER_HOUR_LOCAL = 20;
const REMINDER_CHUNK_SIZE = 25;
const REMINDER_PAGE_SIZE = 200;
const DAY_MS = 24 * 60 * 60 * 1000;
const REMINDER_RETRY_MS = 15 * 60_000;

const REMINDER_CHANNEL_ID = "streak_reminder";

const MAX_STREAK_FREEZES = 2;
const STREAK_MILESTONES = [7, 30, 100, 365];

interface ClaimDailyStreakRequest {
  timezoneOffsetMinutes?: number;
  reminderEnabled?: boolean;
}

interface ClaimDailyStreakResponse {
  claimed: boolean;
  alreadyClaimedToday: boolean;
  streakDay: number;
  streakCount: number;
  previousStreakCount: number;
  streakBest: number;
  streakBroken: boolean;
  freezesUsed: number;
  freezesLeft: number;
  isWeekComplete: boolean;
  milestone: number | null;
  dailyReward: number;
  streakBonusReward: number;
  proBonusReward: number;
  totalReward: number;
  newBalance: number;
  todayLocalKey: string;
  timezoneOffsetMinutes: number;
  nextReminderAtUtcMillis?: number;
}

interface CoinState extends Record<string, unknown> {
  lastDailyClaimDate: string;
  streakDay: number;
  streakCount: number;
  streakBest: number;
  streakFreezes: number;
  streakReminderEnabled: boolean;
  streakTimezoneOffsetMinutes: number;
  streakClaimTimezoneOffsetMinutes?: number;
  streakReminderLastSentDate: string;
  streakReminderNextAtUtc?: admin.firestore.Timestamp;
  streakLastClaimServerAt?: admin.firestore.Timestamp;
}

export const claimDailyStreak = onCall(
  {
    region: REGION,
    cors: true,
  },
  async (
    request: CallableRequest<ClaimDailyStreakRequest>,
  ): Promise<ClaimDailyStreakResponse> => {
    const uid = request.auth?.uid?.trim() ?? "";
    if (!uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to claim streak rewards.");
    }

    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);

    const requestedOffset = request.data?.timezoneOffsetMinutes;
    if (requestedOffset !== undefined &&
        (typeof requestedOffset !== "number" || !Number.isInteger(requestedOffset) ||
        requestedOffset < -720 || requestedOffset > 840)) {
      throw new HttpsError("invalid-argument", "timezoneOffsetMinutes must be an integer between -720 and 840.");
    }
    const reminderEnabled = request.data?.reminderEnabled;
    if (reminderEnabled !== undefined && typeof reminderEnabled !== "boolean") {
      throw new HttpsError("invalid-argument", "reminderEnabled must be a boolean.");
    }
    const requestOffset = requestedOffset ?? DEFAULT_TZ_OFFSET_MINUTES;
    const reminderEnabledRequest = reminderEnabled ?? true;

    const userRef = db.collection(USERS_COLLECTION).doc(uid);

    let claimed = false;
    let alreadyClaimedToday = false;
    let streakDay = 0;
    let streakCount = 0;
    let previousStreakCount = 0;
    let streakBest = 0;
    let streakBroken = false;
    let freezesUsed = 0;
    let freezesLeft = 0;
    let dailyReward = 0;
    let streakBonusReward = 0;
    let proBonusReward = 0;
    let totalReward = 0;
    let newBalance = 0;
    let todayLocalKey = "";
    let effectiveTimezoneOffsetMinutes = requestOffset;
    let nextReminderAtUtcMillis: number | undefined;

    await db.runTransaction(async (tx) => {
      claimed = false;
      dailyReward = 0;
      streakBonusReward = 0;
      proBonusReward = 0;
      totalReward = 0;
      nextReminderAtUtcMillis = undefined;
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile was not found.");
      }

      const userData = userSnap.data() as Record<string, unknown>;
      const previousBalance = int(userData.coins, 0);
      const rawCoinState = userData.coinState;
      const coinState = normalizeCoinState(rawCoinState);

      const lockedOffset = storedTimezoneOffset(rawCoinState, "streakClaimTimezoneOffsetMinutes");
      const storedOffset = lockedOffset ?? storedTimezoneOffset(rawCoinState);
      const relock = shouldRelockTimezone({
        locked: lockedOffset,
        requested: requestedOffset,
        lastClaimAtMs: coinState.streakLastClaimServerAt?.toMillis(),
        nowMs: now.getTime(),
      });
      const effectiveOffset = relock ? clampTimezoneOffset(requestOffset) : resolveTimezoneOffset(storedOffset, requestOffset);
      effectiveTimezoneOffsetMinutes = effectiveOffset;
      coinState.streakTimezoneOffsetMinutes = effectiveOffset;
      coinState.streakClaimTimezoneOffsetMinutes = effectiveOffset;
      coinState.streakReminderEnabled = reminderEnabledRequest;

      todayLocalKey = localDateKeyFromUtc(now, effectiveOffset);
      let lastClaimDate = coinState.lastDailyClaimDate.trim();
      // The legacy offset is client-writable. Rebase from the server timestamp when first locking it or moving the lock.
      if ((lockedOffset == null || relock) && coinState.streakLastClaimServerAt instanceof admin.firestore.Timestamp) {
        lastClaimDate = localDateKeyFromUtc(coinState.streakLastClaimServerAt.toDate(), effectiveOffset);
        coinState.lastDailyClaimDate = lastClaimDate;
      }
      const plan = planStreakClaim(
        {
          lastKey: lastClaimDate,
          streakDay: coinState.streakDay,
          streakCount: coinState.streakCount,
          streakBest: coinState.streakBest,
          freezes: coinState.streakFreezes,
        },
        todayLocalKey,
        asBool(userData.premium, false),
      );
      alreadyClaimedToday = plan.alreadyClaimed;
      streakCount = plan.count;
      previousStreakCount = plan.previousCount;
      streakBest = plan.best;
      freezesUsed = plan.freezesUsed;
      freezesLeft = plan.freezesLeft;
      streakBroken = plan.streakBroken;
      coinState.streakCount = plan.count;
      coinState.streakBest = plan.best;
      coinState.streakFreezes = plan.freezesLeft;

      if (!alreadyClaimedToday) {
        streakDay = plan.cycleDay;
        dailyReward = plan.dailyReward;
        streakBonusReward = plan.streakBonusReward;
        proBonusReward = plan.proBonusReward;
        totalReward = dailyReward + streakBonusReward + proBonusReward;
        newBalance = previousBalance + totalReward;
        claimed = true;

        coinState.lastDailyClaimDate = todayLocalKey;
        coinState.streakDay = streakDay;
        coinState.streakLastClaimServerAt = nowTs;

        const baseTxId = `${now.getTime()}_${Math.floor(Math.random() * 1e9).toString(16)}`;
        const parts = [
          {
            idPrefix: "ctx_daily_login",
            delta: dailyReward,
            action: "dailyLogin",
            description: `Daily login reward (+${dailyReward})`,
            reason:
              streakDay >= 3 && streakDay <= 6 ?
                `streak_mid_cycle_day_${streakDay}` :
                streakDay === 7 ?
                  "streak_day_7_daily" :
                  "daily_login",
          },
          {
            idPrefix: "ctx_streak_bonus",
            delta: streakBonusReward,
            action: "streakBonus",
            description: `7-day streak bonus (+${streakBonusReward})`,
            reason: "streak_day_7_bonus",
          },
          {
            idPrefix: "ctx_pro_streak_bonus",
            delta: proBonusReward,
            action: "proStreakBonus",
            description: `Pro streak bonus (+${proBonusReward})`,
            reason: "pro_streak_bonus",
          },
        ];
        let balanceBefore = previousBalance;
        for (const part of parts) {
          if (part.delta <= 0) continue;
          const id = `${part.idPrefix}_${baseTxId}`;
          tx.set(db.collection(COIN_TX_COLLECTION).doc(id), coinTransactionDoc({
            id,
            userId: uid,
            at: nowTs,
            delta: part.delta,
            balanceBefore,
            action: part.action,
            description: part.description,
            sourceTag: "coins.claim_daily_streak.callable",
            reason: part.reason,
          }));
          balanceBefore += part.delta;
        }
      } else {
        streakDay = clampStreakDay(int(coinState.streakDay, 0));
        newBalance = previousBalance;
      }

      if (coinState.streakReminderEnabled) {
        const reminderTs = nextReminderAfterTodayClaim(todayLocalKey, coinState.streakTimezoneOffsetMinutes);
        coinState.streakReminderNextAtUtc = reminderTs;
        nextReminderAtUtcMillis = reminderTs.toDate().getTime();
      } else {
        delete coinState.streakReminderNextAtUtc;
      }

      tx.update(userRef, {
        coins: newBalance,
        coinState,
      });
    });

    return {
      claimed,
      alreadyClaimedToday,
      streakDay,
      streakCount,
      previousStreakCount,
      streakBest,
      streakBroken,
      freezesUsed,
      freezesLeft,
      isWeekComplete: streakDay === 7,
      milestone: claimed ? streakMilestone(streakCount) : null,
      dailyReward,
      streakBonusReward,
      proBonusReward,
      totalReward,
      newBalance,
      todayLocalKey,
      timezoneOffsetMinutes: effectiveTimezoneOffsetMinutes,
      ...(nextReminderAtUtcMillis != null ? {nextReminderAtUtcMillis} : {}),
    };
  },
);

export const sendStreakReminders = onSchedule(
  {
    schedule: "*/15 * * * *",
    timeZone: "UTC",
    region: REGION,
    timeoutSeconds: 540,
  },
  async () => {
    const nowTs = admin.firestore.Timestamp.now();
    const now = nowTs.toDate();

    let processed = 0;
    let sent = 0;
    let skipped = 0;
    let failed = 0;
    let page = 0;
    const seen = new Set<string>();

    while (true) {
      const snapshot = await db
        .collection(USERS_COLLECTION)
        .where("coinState.streakReminderEnabled", "==", true)
        .where("coinState.streakReminderNextAtUtc", "<=", nowTs)
        .orderBy("coinState.streakReminderNextAtUtc", "asc")
        .limit(REMINDER_PAGE_SIZE)
        .get();

      const docs = snapshot.docs.filter((doc) => !seen.has(doc.ref.id));
      if (docs.length === 0) {
        break;
      }

      page += 1;

      for (let i = 0; i < docs.length; i += REMINDER_CHUNK_SIZE) {
        const results = await Promise.allSettled(
          docs.slice(i, i + REMINDER_CHUNK_SIZE).map((userDoc) => {
            seen.add(userDoc.ref.id);
            return remindUser(userDoc, nowTs, now);
          }),
        );
        for (const result of results) {
          processed += 1;
          if (result.status === "rejected") {
            failed += 1;
            logger.error("sendStreakReminders: user failed.", {err: result.reason});
          } else if (result.value === "sent") {
            sent += 1;
          } else if (result.value === "skipped") {
            skipped += 1;
          } else {
            failed += 1;
          }
        }
      }

      logger.info("sendStreakReminders: processed page", {
        page,
        pageSize: snapshot.size,
      });

      if (snapshot.size < REMINDER_PAGE_SIZE) {
        break;
      }
    }

    logger.info("sendStreakReminders: completed", {
      processed,
      sent,
      skipped,
      failed,
      now: now.toISOString(),
    });
  },
);

async function remindUser(
  userDoc: admin.firestore.QueryDocumentSnapshot,
  nowTs: admin.firestore.Timestamp,
  now: Date,
): Promise<"sent" | "skipped" | "failed"> {
  const userData = userDoc.data() as Record<string, unknown>;
  const userEmail = str(userData.email);
  const coinState = normalizeCoinState(userData.coinState);

  const offset = resolveTimezoneOffset(
    storedTimezoneOffset(userData.coinState, "streakClaimTimezoneOffsetMinutes"),
    coinState.streakTimezoneOffsetMinutes,
  );
  const todayLocalKey = localDateKeyFromUtc(now, offset);
  const lastClaimDate = coinState.lastDailyClaimDate;
  const lastSentDate = coinState.streakReminderLastSentDate;
  const streakDay = clampStreakDay(int(coinState.streakDay, 0));
  const streakCount = coinState.streakCount > 0 ? coinState.streakCount : streakDay;

  const activeStreak =
    streakCount > 0 && isStreakAlive(lastClaimDate, todayLocalKey, coinState.streakFreezes);
  const claimedToday = lastClaimDate === todayLocalKey;
  const alreadySentToday = lastSentDate === todayLocalKey;

  if (!activeStreak) {
    await userDoc.ref.update({
      "coinState.streakReminderNextAtUtc": admin.firestore.FieldValue.delete(),
    });
    return "skipped";
  }

  const nextReminderTs = nextReminderAfterTodayClaim(todayLocalKey, offset);
  const retryAt = admin.firestore.Timestamp.fromMillis(nowTs.toMillis() + REMINDER_RETRY_MS);
  const loggedOut = isLoggedOut(userData);
  const retryAfterLogin = loggedOut && !claimedToday && !alreadySentToday && userEmail.length > 0;
  const noReminder = claimedToday || alreadySentToday || userEmail.length === 0 || loggedOut;
  const [fcmToken] = noReminder ? [] : await userPushTokens(userDoc.ref.id, userData.fcmToken);

  if (noReminder || !fcmToken) {
    await userDoc.ref.update({
      "coinState.streakReminderNextAtUtc": retryAfterLogin ? retryAt : nextReminderTs,
    });
    return "skipped";
  }

  // The marker goes first so an overlapping run cannot send the same reminder twice.
  await userDoc.ref.update({
    "coinState.streakReminderLastSentDate": todayLocalKey,
    "coinState.streakReminderNextAtUtc": nextReminderTs,
  });
  const delivered = await sendNotification({
    title: "Your streak is about to break!",
    body: "Open Prism now to keep your login streak alive 🔥",
    data: {
      route: "streak_reminder",
      streak_day: streakDay.toString(),
      streak_count: streakCount.toString(),
    },
    modifier: userEmail,
    channelId: REMINDER_CHANNEL_ID,
    fcmTarget: {token: fcmToken},
    docId: `streak_${userDoc.ref.id}_${todayLocalKey}`,
  });
  if (!delivered) {
    await userDoc.ref.update({
      "coinState.streakReminderLastSentDate": lastSentDate,
      "coinState.streakReminderNextAtUtc": retryAt,
    });
    return "failed";
  }
  return "sent";
}

export {pickFcmToken};

/**
 * The claim offset is locked so a client cannot shift its day. It moves only when the device offset differs
 * and 24 hours passed since the last claim, so a traveller or a DST change is not stuck on the old day.
 */
export function shouldRelockTimezone(params: {
  locked?: number;
  requested?: number;
  lastClaimAtMs?: number;
  nowMs: number;
}): boolean {
  const {locked, requested, lastClaimAtMs, nowMs} = params;
  if (locked == null || requested === undefined || lastClaimAtMs == null) {
    return false;
  }
  return clampTimezoneOffset(requested) !== clampTimezoneOffset(locked) && nowMs - lastClaimAtMs >= DAY_MS;
}

function asBool(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true" || normalized === "1") {
      return true;
    }
    if (normalized === "false" || normalized === "0") {
      return false;
    }
  }
  return fallback;
}

function clampTimezoneOffset(offsetMinutes: number): number {
  if (!Number.isFinite(offsetMinutes)) {
    return DEFAULT_TZ_OFFSET_MINUTES;
  }
  return Math.max(-12 * 60, Math.min(14 * 60, Math.trunc(offsetMinutes)));
}

export function resolveTimezoneOffset(stored: number | undefined, requested: number): number {
  const requestedOffset = clampTimezoneOffset(requested);
  return stored == null || !Number.isFinite(stored) ? requestedOffset : clampTimezoneOffset(stored);
}

function storedTimezoneOffset(raw: unknown, field = "streakTimezoneOffsetMinutes"): number | undefined {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return undefined;
  }
  const value = (raw as Record<string, unknown>)[field];
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() && Number.isFinite(Number(value))) return Number(value);
  return undefined;
}

function clampStreakDay(day: number): number {
  if (!Number.isFinite(day)) {
    return 0;
  }
  return Math.max(0, Math.min(7, Math.trunc(day)));
}

function normalizeCoinState(raw: unknown): CoinState {
  const state: Record<string, unknown> =
    raw && typeof raw === "object" && !Array.isArray(raw) ?
      {...(raw as Record<string, unknown>)} :
      {};

  return {
    ...state,
    lastDailyClaimDate: str(state.lastDailyClaimDate),
    streakDay: clampStreakDay(int(state.streakDay, 0)),
    streakCount: Math.max(0, int(state.streakCount, 0)),
    streakBest: Math.max(0, int(state.streakBest, 0)),
    streakFreezes: Math.max(0, Math.min(MAX_STREAK_FREEZES, int(state.streakFreezes, 0))),
    streakReminderEnabled: asBool(state.streakReminderEnabled, true),
    streakTimezoneOffsetMinutes: clampTimezoneOffset(
      int(state.streakTimezoneOffsetMinutes, DEFAULT_TZ_OFFSET_MINUTES),
    ),
    streakReminderLastSentDate: str(state.streakReminderLastSentDate),
    ...(state.streakReminderNextAtUtc instanceof admin.firestore.Timestamp ?
      {streakReminderNextAtUtc: state.streakReminderNextAtUtc} :
      {}),
    ...(state.streakLastClaimServerAt instanceof admin.firestore.Timestamp ?
      {streakLastClaimServerAt: state.streakLastClaimServerAt} :
      {}),
  };
}

export function streakMilestone(count: number): number | null {
  return STREAK_MILESTONES.includes(count) ? count : null;
}

/** Whole days from day key `a` to day key `b`. NaN when either key is invalid. */
export function dayGap(a: string, b: string): number {
  const pa = parseDayKey(a);
  const pb = parseDayKey(b);
  if (!pa || !pb) {
    return Number.NaN;
  }
  const ms = Date.UTC(pb.year, pb.month - 1, pb.day) - Date.UTC(pa.year, pa.month - 1, pa.day);
  return Math.round(ms / 86_400_000);
}

/** A streak survives while the missed days fit inside the held freezes. */
export function isStreakAlive(lastKey: string, todayKey: string, freezes: number): boolean {
  if (!lastKey) {
    return false;
  }
  return dayGap(lastKey, todayKey) <= 1 + freezes;
}

export interface StreakClaimState {
  lastKey: string;
  streakDay: number;
  /** 0 or missing means a legacy doc: derive it from streakDay. */
  streakCount?: number;
  streakBest?: number;
  freezes: number;
}

export interface StreakClaimPlan {
  alreadyClaimed: boolean;
  count: number;
  previousCount: number;
  best: number;
  streakBroken: boolean;
  freezesUsed: number;
  freezesLeft: number;
  cycleDay: number;
  dailyReward: number;
  streakBonusReward: number;
  proBonusReward: number;
}

export function planStreakClaim(state: StreakClaimState, todayKey: string, isPro: boolean): StreakClaimPlan {
  const freezes = Math.max(0, Math.min(MAX_STREAK_FREEZES, Math.trunc(state.freezes || 0)));
  const storedCount = Math.max(0, Math.trunc(state.streakCount || 0));
  const prev = storedCount > 0 ? storedCount : clampStreakDay(state.streakDay);
  const best = Math.max(Math.max(0, Math.trunc(state.streakBest || 0)), prev);
  const base: StreakClaimPlan = {
    alreadyClaimed: true,
    count: prev,
    previousCount: prev,
    best,
    streakBroken: false,
    freezesUsed: 0,
    freezesLeft: freezes,
    cycleDay: 0,
    dailyReward: 0,
    streakBonusReward: 0,
    proBonusReward: 0,
  };

  const lastKey = state.lastKey.trim();
  const gap = lastKey ? dayGap(lastKey, todayKey) : Number.NaN;
  if (lastKey && gap <= 0) {
    return base;
  }

  let count = 1;
  let used = 0;
  if (prev > 0 && lastKey && Number.isFinite(gap) && gap <= 1 + freezes) {
    count = prev + 1;
    used = gap - 1;
  }
  const streakBroken = lastKey.length > 0 && count === 1 && prev > 0;
  const cycleDay = ((count - 1) % 7) + 1;
  const rewardParts = rewardForStreakDay(cycleDay);
  return {
    ...base,
    alreadyClaimed: false,
    count,
    best: Math.max(best, count),
    streakBroken,
    freezesUsed: used,
    freezesLeft: freezes - used,
    cycleDay,
    dailyReward: rewardParts.dailyReward,
    streakBonusReward: rewardParts.streakBonusReward,
    proBonusReward: isPro ? (cycleDay === 7 ? PRO_STREAK_7_BONUS : PRO_STREAK_DAILY_BONUS) : 0,
  };
}

function rewardForStreakDay(streakDay: number): {dailyReward: number; streakBonusReward: number} {
  if (streakDay >= 7) {
    return {dailyReward: STREAK_REWARD_DAY_7_DAILY, streakBonusReward: STREAK_DAY7_BONUS};
  }
  return {dailyReward: streakDay >= 5 ? 12 : streakDay >= 3 ? 8 : 5, streakBonusReward: 0};
}

export function localDateKeyFromUtc(utcDate: Date, offsetMinutes: number): string {
  const shifted = new Date(utcDate.getTime() + offsetMinutes * 60 * 1000);
  const year = shifted.getUTCFullYear();
  const month = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const day = String(shifted.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function parseDayKey(dayKey: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dayKey.trim());
  if (!match) {
    return null;
  }
  const year = Number.parseInt(match[1], 10);
  const month = Number.parseInt(match[2], 10);
  const day = Number.parseInt(match[3], 10);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return null;
  }
  return {year, month, day};
}

function nextReminderAfterTodayClaim(
  todayLocalKey: string,
  offsetMinutes: number,
): admin.firestore.Timestamp {
  const parsed = parseDayKey(todayLocalKey);
  if (!parsed) {
    const fallback = new Date(Date.now() + 24 * 60 * 60 * 1000);
    return admin.firestore.Timestamp.fromDate(fallback);
  }
  const localMillis = Date.UTC(
    parsed.year,
    parsed.month - 1,
    parsed.day + 1,
    REMINDER_HOUR_LOCAL,
    0,
    0,
    0,
  );
  const utcMillis = localMillis - offsetMinutes * 60 * 1000;
  return admin.firestore.Timestamp.fromMillis(utcMillis);
}
