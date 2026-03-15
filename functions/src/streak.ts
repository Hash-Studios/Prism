import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {onCall, HttpsError, type CallableRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {sendNotification} from "./notificationHelper";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const USERS_COLLECTION = "usersv2";
const COIN_TX_COLLECTION = "coinTransactions";

const STREAK_REWARD_DAY_1_TO_2 = 5;
const STREAK_REWARD_DAY_3_TO_4 = 8;
const STREAK_REWARD_DAY_5_TO_6 = 12;
const STREAK_REWARD_DAY_7_DAILY = 15;
const STREAK_DAY7_BONUS = 40;

const DEFAULT_TZ_OFFSET_MINUTES = 330;
const REMINDER_HOUR_LOCAL = 20;

const REGION = "asia-south1";
const REMINDER_CHANNEL_ID = "streak_reminder";

interface ClaimDailyStreakRequest {
  timezoneOffsetMinutes?: number;
  reminderEnabled?: boolean;
}

interface ClaimDailyStreakResponse {
  claimed: boolean;
  alreadyClaimedToday: boolean;
  streakDay: number;
  dailyReward: number;
  streakBonusReward: number;
  totalReward: number;
  newBalance: number;
  todayLocalKey: string;
  nextReminderAtUtcMillis?: number;
}

interface RewardParts {
  dailyReward: number;
  streakBonusReward: number;
  totalReward: number;
}

interface CoinState extends Record<string, unknown> {
  lastDailyClaimDate: string;
  streakDay: number;
  streakReminderEnabled: boolean;
  streakTimezoneOffsetMinutes: number;
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

    const requestOffset = _clampTimezoneOffset(
      _asInt(request.data?.timezoneOffsetMinutes, DEFAULT_TZ_OFFSET_MINUTES),
    );
    const reminderEnabledRequest = _asBool(request.data?.reminderEnabled, true);

    const userRef = db.collection(USERS_COLLECTION).doc(uid);

    let claimed = false;
    let alreadyClaimedToday = false;
    let streakDay = 0;
    let dailyReward = 0;
    let streakBonusReward = 0;
    let totalReward = 0;
    let newBalance = 0;
    let todayLocalKey = "";
    let nextReminderAtUtcMillis: number | undefined;

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User profile was not found.");
      }

      const userData = userSnap.data() as Record<string, unknown>;
      const previousBalance = _asInt(userData.coins, 0);
      const coinState = _normalizeCoinState(userData.coinState);

      const effectiveOffset = _clampTimezoneOffset(
        request.data?.timezoneOffsetMinutes == null ?
          _asInt(coinState.streakTimezoneOffsetMinutes, requestOffset) :
          requestOffset,
      );
      coinState.streakTimezoneOffsetMinutes = effectiveOffset;
      coinState.streakReminderEnabled = reminderEnabledRequest;

      todayLocalKey = _localDateKeyFromUtc(now, effectiveOffset);
      const lastClaimDate = coinState.lastDailyClaimDate.trim();
      alreadyClaimedToday = lastClaimDate === todayLocalKey;

      if (!alreadyClaimedToday) {
        const previousStreakDay = _clampStreakDay(_asInt(coinState.streakDay, 0));
        const nextStreakDay = _computeNextStreakDay(lastClaimDate, todayLocalKey, previousStreakDay);
        const rewardParts = _rewardForStreakDay(nextStreakDay);

        streakDay = nextStreakDay;
        dailyReward = rewardParts.dailyReward;
        streakBonusReward = rewardParts.streakBonusReward;
        totalReward = rewardParts.totalReward;
        newBalance = previousBalance + totalReward;
        claimed = true;

        coinState.lastDailyClaimDate = todayLocalKey;
        coinState.streakDay = streakDay;
        coinState.streakLastClaimServerAt = nowTs;

        const baseTxId = `${now.getTime()}_${Math.floor(Math.random() * 1e9).toString(16)}`;
        const dailyTxId = `ctx_daily_login_${baseTxId}`;

        tx.set(db.collection(COIN_TX_COLLECTION).doc(dailyTxId), {
          id: dailyTxId,
          userId: uid,
          createdAt: nowTs,
          updatedAt: nowTs,
          delta: dailyReward,
          balanceBefore: previousBalance,
          balanceAfter: previousBalance + dailyReward,
          action: "dailyLogin",
          description: `Daily login reward (+${dailyReward})`,
          sourceTag: "coins.claim_daily_streak.callable",
          status: "completed",
          type: "credit",
          reason:
            streakDay >= 3 && streakDay <= 6 ?
              `streak_mid_cycle_day_${streakDay}` :
              streakDay === 7 ?
                "streak_day_7_daily" :
                "daily_login",
        });

        if (streakBonusReward > 0) {
          const streakTxId = `ctx_streak_bonus_${baseTxId}`;
          tx.set(db.collection(COIN_TX_COLLECTION).doc(streakTxId), {
            id: streakTxId,
            userId: uid,
            createdAt: nowTs,
            updatedAt: nowTs,
            delta: streakBonusReward,
            balanceBefore: previousBalance + dailyReward,
            balanceAfter: newBalance,
            action: "streakBonus",
            description: `7-day streak bonus (+${streakBonusReward})`,
            sourceTag: "coins.claim_daily_streak.callable",
            status: "completed",
            type: "credit",
            reason: "streak_day_7_bonus",
          });
        }
      } else {
        streakDay = _clampStreakDay(_asInt(coinState.streakDay, 0));
        newBalance = previousBalance;
      }

      if (coinState.streakReminderEnabled) {
        const reminderTs = _nextReminderAfterTodayClaim(todayLocalKey, coinState.streakTimezoneOffsetMinutes);
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
      dailyReward,
      streakBonusReward,
      totalReward,
      newBalance,
      todayLocalKey,
      ...(nextReminderAtUtcMillis != null ? {nextReminderAtUtcMillis} : {}),
    };
  },
);

export const sendStreakReminders = onSchedule(
  {
    schedule: "*/15 * * * *",
    timeZone: "UTC",
    region: REGION,
  },
  async () => {
    const nowTs = admin.firestore.Timestamp.now();
    const now = nowTs.toDate();

    let processed = 0;
    let sent = 0;
    let skipped = 0;
    let page = 0;

    while (true) {
      const snapshot = await db
        .collection(USERS_COLLECTION)
        .where("coinState.streakReminderEnabled", "==", true)
        .where("coinState.streakReminderNextAtUtc", "<=", nowTs)
        .orderBy("coinState.streakReminderNextAtUtc", "asc")
        .limit(200)
        .get();

      if (snapshot.empty) {
        break;
      }

      page += 1;

      for (const userDoc of snapshot.docs) {
        processed += 1;
        const userData = userDoc.data() as Record<string, unknown>;
        const userEmail = _asString(userData.email).toLowerCase();
        const fcmToken = _asString(userData.fcmToken);
        const coinState = _normalizeCoinState(userData.coinState);

        const offset = _clampTimezoneOffset(
          _asInt(coinState.streakTimezoneOffsetMinutes, DEFAULT_TZ_OFFSET_MINUTES),
        );
        const todayLocalKey = _localDateKeyFromUtc(now, offset);
        const yesterdayLocalKey = _localDateKeyFromUtc(new Date(now.getTime() - 24 * 60 * 60 * 1000), offset);
        const lastClaimDate = coinState.lastDailyClaimDate;
        const lastSentDate = coinState.streakReminderLastSentDate;
        const streakDay = _clampStreakDay(_asInt(coinState.streakDay, 0));

        const activeStreak =
          streakDay > 0 && (lastClaimDate === todayLocalKey || lastClaimDate === yesterdayLocalKey);
        const claimedToday = lastClaimDate === todayLocalKey;
        const alreadySentToday = lastSentDate === todayLocalKey;

        if (!activeStreak) {
          await userDoc.ref.update({
            "coinState.streakReminderNextAtUtc": admin.firestore.FieldValue.delete(),
          });
          skipped += 1;
          continue;
        }

        const nextReminderTs = _nextReminderAfterTodayClaim(todayLocalKey, offset);

        if (claimedToday || alreadySentToday || userEmail.length === 0 || fcmToken.length === 0) {
          await userDoc.ref.update({
            "coinState.streakReminderNextAtUtc": nextReminderTs,
          });
          skipped += 1;
          continue;
        }

        await sendNotification({
          title: "Your streak is about to break!",
          body: "Open Prism now to keep your login streak alive 🔥",
          data: {
            route: "streak_reminder",
            channel_id: REMINDER_CHANNEL_ID,
            streak_day: streakDay.toString(),
          },
          modifier: userEmail,
          channelId: REMINDER_CHANNEL_ID,
          fcmTarget: {token: fcmToken},
        });

        await userDoc.ref.update({
          "coinState.streakReminderLastSentDate": todayLocalKey,
          "coinState.streakReminderNextAtUtc": nextReminderTs,
        });
        sent += 1;
      }

      logger.info("sendStreakReminders: processed page", {
        page,
        pageSize: snapshot.size,
      });

      if (snapshot.size < 200) {
        break;
      }
    }

    logger.info("sendStreakReminders: completed", {
      processed,
      sent,
      skipped,
      now: now.toISOString(),
    });
  },
);

function _asString(value: unknown): string {
  return value == null ? "" : String(value).trim();
}

function _asInt(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

function _asBool(value: unknown, fallback: boolean): boolean {
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

function _clampTimezoneOffset(offsetMinutes: number): number {
  if (!Number.isFinite(offsetMinutes)) {
    return DEFAULT_TZ_OFFSET_MINUTES;
  }
  return Math.max(-12 * 60, Math.min(14 * 60, Math.trunc(offsetMinutes)));
}

function _clampStreakDay(day: number): number {
  if (!Number.isFinite(day)) {
    return 0;
  }
  return Math.max(0, Math.min(7, Math.trunc(day)));
}

function _normalizeCoinState(raw: unknown): CoinState {
  const state: Record<string, unknown> =
    raw && typeof raw === "object" && !Array.isArray(raw) ?
      {...(raw as Record<string, unknown>)} :
      {};

  return {
    ...state,
    lastDailyClaimDate: _asString(state.lastDailyClaimDate),
    streakDay: _clampStreakDay(_asInt(state.streakDay, 0)),
    streakReminderEnabled: _asBool(state.streakReminderEnabled, true),
    streakTimezoneOffsetMinutes: _clampTimezoneOffset(
      _asInt(state.streakTimezoneOffsetMinutes, DEFAULT_TZ_OFFSET_MINUTES),
    ),
    streakReminderLastSentDate: _asString(state.streakReminderLastSentDate),
    ...(state.streakReminderNextAtUtc instanceof admin.firestore.Timestamp ?
      {streakReminderNextAtUtc: state.streakReminderNextAtUtc} :
      {}),
    ...(state.streakLastClaimServerAt instanceof admin.firestore.Timestamp ?
      {streakLastClaimServerAt: state.streakLastClaimServerAt} :
      {}),
  };
}

function _computeNextStreakDay(lastClaimDate: string, todayLocalKey: string, previousStreakDay: number): number {
  if (!lastClaimDate) {
    return 1;
  }
  const yesterday = _previousDayKey(todayLocalKey);
  if (lastClaimDate === yesterday) {
    const incremented = previousStreakDay + 1;
    return incremented > 7 ? 1 : incremented;
  }
  return 1;
}

function _rewardForStreakDay(streakDay: number): RewardParts {
  if (streakDay >= 1 && streakDay <= 2) {
    return {
      dailyReward: STREAK_REWARD_DAY_1_TO_2,
      streakBonusReward: 0,
      totalReward: STREAK_REWARD_DAY_1_TO_2,
    };
  }
  if (streakDay >= 3 && streakDay <= 4) {
    return {
      dailyReward: STREAK_REWARD_DAY_3_TO_4,
      streakBonusReward: 0,
      totalReward: STREAK_REWARD_DAY_3_TO_4,
    };
  }
  if (streakDay >= 5 && streakDay <= 6) {
    return {
      dailyReward: STREAK_REWARD_DAY_5_TO_6,
      streakBonusReward: 0,
      totalReward: STREAK_REWARD_DAY_5_TO_6,
    };
  }
  if (streakDay >= 7) {
    return {
      dailyReward: STREAK_REWARD_DAY_7_DAILY,
      streakBonusReward: STREAK_DAY7_BONUS,
      totalReward: STREAK_REWARD_DAY_7_DAILY + STREAK_DAY7_BONUS,
    };
  }
  return {
    dailyReward: STREAK_REWARD_DAY_1_TO_2,
    streakBonusReward: 0,
    totalReward: STREAK_REWARD_DAY_1_TO_2,
  };
}

function _localDateKeyFromUtc(utcDate: Date, offsetMinutes: number): string {
  const shifted = new Date(utcDate.getTime() + offsetMinutes * 60 * 1000);
  const year = shifted.getUTCFullYear();
  const month = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const day = String(shifted.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function _previousDayKey(dayKey: string): string {
  const parsed = _parseDayKey(dayKey);
  if (!parsed) {
    return "";
  }
  const previous = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day - 1));
  const y = previous.getUTCFullYear();
  const m = String(previous.getUTCMonth() + 1).padStart(2, "0");
  const d = String(previous.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function _parseDayKey(dayKey: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dayKey.trim());
  if (!match) {
    return null;
  }
  return {
    year: Number.parseInt(match[1], 10),
    month: Number.parseInt(match[2], 10),
    day: Number.parseInt(match[3], 10),
  };
}

function _nextReminderAfterTodayClaim(
  todayLocalKey: string,
  offsetMinutes: number,
): admin.firestore.Timestamp {
  const parsed = _parseDayKey(todayLocalKey);
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
