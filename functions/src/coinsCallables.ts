import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, readDailyCount, REGION, str, utcDateString} from "./common";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const AD_RATE_DAILY = "coinAdRateDaily";
const REFUND_DAILY = "coinRefundDaily";
const REFERRAL_STATS = "referralStats";
const WALLS = "walls";

const AWARDS: Record<string, number> = {
  rewardedAd: 10,
  firstWallpaperUpload: 50,
  profileCompletion: 25,
  proDailyBonus: 50,
};

const SPENDS: Record<string, number> = {
  wallpaperDownload: 5,
  premiumWallpaperDownload: 15,
  premiumFilter: 5,
  premiumPreview24h: 10,
};

export const STREAK_FREEZE_COST = 50;
export const MAX_STREAK_FREEZES = 2;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;

const AI_GENERATION_AMOUNTS = new Set([10, 75, 100]);
const REFUND_WINDOW_MS = 600_000;
const REFUND_MAX_PER_DAY = 5;
// Only the debits the app refunds today: a failed download and a failed AI generation.
const REFUNDABLE_ACTIONS = new Set(["wallpaperDownload", "premiumWallpaperDownload", "aiGeneration"]);
const PREVIEW_ACCESS_MS = 86_400_000;
const REFERRAL_NEW_ACCOUNT_MS = 14 * 86_400_000;
const REFERRAL_MAX_PER_DAY = 10;
const REFERRAL_MAX_LIFETIME = 100;
// Mirrors defaultProfilePhotoUrl in lib/core/constants/app_constants.dart.
const DEFAULT_PROFILE_PHOTO =
  "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4";
const CALLABLE_OPTIONS = {region: REGION, cors: true, maxInstances: 10};
const AD_RATE_MAX_PER_DAY = 20;
const AD_RATE_MIN_GAP_MS = 20_000;

function requiredText(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.trim().length > 200) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return value.trim();
}

function uid(request: CallableRequest<unknown>): string {
  const value = request.auth?.uid?.trim() ?? "";
  if (!value) throw new HttpsError("unauthenticated", "Sign in to use coins.");
  return value;
}

function coinState(raw: unknown): Record<string, unknown> {
  return raw && typeof raw === "object" && !Array.isArray(raw) ? {...(raw as Record<string, unknown>)} : {};
}

function transactionId(action: string): string {
  return `ctx_${action}_${Date.now()}_${Math.floor(Math.random() * 1e9).toString(16)}`;
}

function awardAmount(action: string): number {
  const amount = AWARDS[action];
  if (amount == null || amount <= 0) throw new HttpsError("invalid-argument", "Unsupported award action.");
  return amount;
}

/**
 * Validates that `debit` (a coinTransactions doc) is refundable by `callerUid` right now.
 * Throws HttpsError otherwise. Returns the coin amount to credit back.
 */
export function refundableDelta(debit: admin.firestore.DocumentData | undefined, callerUid: string, nowMs: number): number {
  const notRefundable = () => new HttpsError("failed-precondition", "No refundable spend.");
  if (!debit) throw notRefundable();
  if (debit.userId !== callerUid) throw notRefundable();
  if (debit.type !== "debit") throw notRefundable();
  if (debit.status !== "completed") throw notRefundable();
  if (typeof debit.action !== "string" || !REFUNDABLE_ACTIONS.has(debit.action)) throw notRefundable();
  const createdAtMs = (debit.createdAt as admin.firestore.Timestamp | undefined)?.toMillis?.();
  if (typeof createdAtMs !== "number") throw notRefundable();
  if (nowMs - createdAtMs > REFUND_WINDOW_MS) throw notRefundable();
  return Math.abs(Math.trunc(Number(debit.delta)));
}

interface AdRateState {
  count?: number;
  lastAt?: number;
}

/** Whether a rewarded-ad award is allowed given the caller's rate-limit doc state. */
export function rewardedAdAllowed(state: AdRateState, nowMs: number): boolean {
  const count = typeof state.count === "number" ? state.count : 0;
  const lastAt = typeof state.lastAt === "number" ? state.lastAt : undefined;
  if (count >= AD_RATE_MAX_PER_DAY) return false;
  if (lastAt != null && nowMs - lastAt < AD_RATE_MIN_GAP_MS) return false;
  return true;
}

/** Epoch ms from a Firestore Timestamp, Date, ISO string or number; null when missing or unreadable. */
export function parseCreatedAtMs(raw: unknown): number | null {
  if (raw == null) return null;
  if (typeof raw === "number") return Number.isFinite(raw) ? raw : null;
  if (raw instanceof Date) return Number.isNaN(raw.getTime()) ? null : raw.getTime();
  if (typeof raw === "string") {
    const ms = Date.parse(raw);
    return Number.isNaN(ms) ? null : ms;
  }
  const toMillis = (raw as {toMillis?: () => number}).toMillis;
  return typeof toMillis === "function" ? toMillis.call(raw) : null;
}

interface ReferralStats {
  day?: string;
  count?: number;
  total?: number;
}

/** Why a referral must pay nobody, or null when it is allowed. */
export function referralSkipReason(
  callerCreatedAt: unknown,
  inviterCreatedAt: unknown,
  stats: ReferralStats,
  today: string,
  nowMs: number,
): string | null {
  const callerMs = parseCreatedAtMs(callerCreatedAt);
  if (callerMs == null || nowMs - callerMs > REFERRAL_NEW_ACCOUNT_MS) return "referral_caller_not_new";
  const inviterMs = parseCreatedAtMs(inviterCreatedAt);
  if (inviterMs == null || inviterMs >= callerMs) return "referral_inviter_not_older";
  const daily = stats.day === today && typeof stats.count === "number" ? stats.count : 0;
  if (daily >= REFERRAL_MAX_PER_DAY) return "referral_inviter_daily_limit";
  if ((typeof stats.total === "number" ? stats.total : 0) >= REFERRAL_MAX_LIFETIME) return "referral_inviter_lifetime_limit";
  return null;
}

/** Mirrors ProfileCompletenessEvaluator in lib/core/profile: photo, username, bio and one social link. */
export function isProfileComplete(user: admin.firestore.DocumentData): boolean {
  const text = (v: unknown) => (typeof v === "string" ? v.trim() : "");
  const photo = text(user.profilePhoto);
  const links = user.links && typeof user.links === "object" ? Object.values(user.links as Record<string, unknown>) : [];
  return photo !== "" && photo !== DEFAULT_PROFILE_PHOTO && text(user.username) !== "" && text(user.bio) !== "" &&
    links.some((v) => text(v) !== "");
}

async function hasSubmittedWall(emails: string[]): Promise<boolean> {
  for (const email of emails) {
    const snap = await db.collection(WALLS).where("email", "==", email).limit(1).get();
    if (!snap.empty) return true;
  }
  return false;
}

function spendAmount(action: string, requested: unknown): number {
  if (action === "aiGeneration") {
    const amount = typeof requested === "number" ? Math.trunc(requested) : 0;
    if (!AI_GENERATION_AMOUNTS.has(amount)) {
      throw new HttpsError("invalid-argument", "Unsupported AI generation amount.");
    }
    return amount;
  }
  const amount = SPENDS[action];
  if (amount == null || amount <= 0) throw new HttpsError("invalid-argument", "Unsupported spend action.");
  return amount;
}

function writeTx(
  tx: admin.firestore.Transaction,
  params: {userId: string; delta: number; previous: number; action: string; sourceTag: string; reason: string},
): string {
  const id = transactionId(params.action);
  tx.set(db.collection(TRANSACTIONS).doc(id), coinTransactionDoc({
    id,
    userId: params.userId,
    at: admin.firestore.Timestamp.now(),
    delta: params.delta,
    balanceBefore: params.previous,
    action: params.action,
    description: params.reason,
    sourceTag: params.sourceTag,
    reason: params.reason,
  }));
  return id;
}

export const awardCoins = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<Record<string, unknown>>) => {
  const callerUid = uid(request);
  const action = requiredText(request.data?.action, "action");
  const sourceTag = requiredText(request.data?.sourceTag, "sourceTag");
  const reason = typeof request.data?.reason === "string" ? request.data.reason.trim() : action;
  const refundTxId = action === "refund" ? requiredText(request.data?.transactionId, "transactionId") : "";
  const userRef = db.collection(USERS).doc(callerUid);
  const nowMs = Date.now();
  const today = utcDateString(new Date(nowMs));
  const adRateRef = db.collection(AD_RATE_DAILY).doc(`${callerUid}_${today}`);
  const debitRef = action === "refund" ? db.collection(TRANSACTIONS).doc(refundTxId) : null;
  const refundDailyRef = db.collection(REFUND_DAILY).doc(`${callerUid}_${today}`);
  // Evidence for the one-time upload award: the caller has at least one wall submission.
  let hasWall = false;
  if (action === "firstWallpaperUpload") {
    const email = str(request.auth?.token?.email);
    hasWall = email !== "" && await hasSubmittedWall([...new Set([email, email.toLowerCase()])]);
  }
  let response = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    reason,
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const adRateSnap = action === "rewardedAd" ? await tx.get(adRateRef) : null;
    const debitSnap = debitRef ? await tx.get(debitRef) : null;
    const refundDailySnap = debitRef ? await tx.get(refundDailyRef) : null;

    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const state = coinState(data.coinState);
    const skip = (skipReason: string) => {
      response = {...response, previousBalance: previous, currentBalance: previous, reason: skipReason};
    };

    if (action === "firstWallpaperUpload" && state.firstWallpaperUploadRewarded === true) {
      skip("first_upload_reward_already_claimed");
      return;
    }
    if (action === "firstWallpaperUpload" && !hasWall) {
      skip("first_upload_no_wall");
      return;
    }
    if (action === "profileCompletion" && state.profileCompletionRewarded === true) {
      skip("profile_reward_already_claimed");
      return;
    }
    if (action === "profileCompletion" && !isProfileComplete(data)) {
      skip("profile_incomplete");
      return;
    }
    const refundsToday = refundDailySnap ? readDailyCount(refundDailySnap, today) : 0;
    if (action === "refund" && refundsToday >= REFUND_MAX_PER_DAY) {
      skip("refund_daily_limit");
      return;
    }
    if (action === "proDailyBonus" && data.premium !== true) {
      skip("pro_bonus_requires_premium");
      return;
    }
    if (action === "proDailyBonus" && state.proDailyBonusDate === today) {
      skip("pro_bonus_already_claimed");
      return;
    }
    // ponytail: no AdMob server-side verification; add an SSV callback if ad fraud shows up
    if (action === "rewardedAd" && !rewardedAdAllowed(adRateSnap?.data() ?? {}, nowMs)) {
      skip("rewarded_ad_limit");
      return;
    }

    const delta = action === "refund" ? refundableDelta(debitSnap?.data(), callerUid, nowMs) : awardAmount(action);

    if (action === "refund" && debitRef) {
      tx.update(debitRef, {status: "refunded", updatedAt: admin.firestore.Timestamp.now()});
      tx.set(refundDailyRef, {day: today, count: refundsToday + 1});
    }
    if (action === "firstWallpaperUpload") state.firstWallpaperUploadRewarded = true;
    if (action === "profileCompletion") state.profileCompletionRewarded = true;
    if (action === "proDailyBonus") state.proDailyBonusDate = today;
    if (action === "rewardedAd") {
      const adData = adRateSnap?.data();
      const adCount = typeof adData?.count === "number" ? adData.count : 0;
      tx.set(adRateRef, {count: adCount + 1, lastAt: nowMs});
    }

    const current = previous + delta;
    tx.update(userRef, {coins: current, coinState: state});
    writeTx(tx, {userId: callerUid, delta, previous, action, sourceTag, reason});
    response = {success: true, changed: true, previousBalance: previous, currentBalance: current, delta, reason};
  });
  return response;
});

export const spendCoins = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<Record<string, unknown>>) => {
  const callerUid = uid(request);
  const action = requiredText(request.data?.action, "action");
  const sourceTag = requiredText(request.data?.sourceTag, "sourceTag");
  const reason = typeof request.data?.reason === "string" ? request.data.reason.trim() : action;
  const bypass = request.data?.allowPremiumBypass === true;
  const cost = spendAmount(action, request.data?.amount);
  const userRef = db.collection(USERS).doc(callerUid);
  let response = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    bypassed: false,
    insufficientBalance: false,
    reason,
    transactionId: "",
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    if (data.premium === true && bypass) {
      response = {
        ...response,
        success: true,
        bypassed: true,
        previousBalance: previous,
        currentBalance: previous,
        reason: `${action}_premium_bypass`,
      };
      return;
    }
    if (previous < cost) {
      response = {
        ...response,
        previousBalance: previous,
        currentBalance: previous,
        insufficientBalance: true,
        reason: `${action}_insufficient_balance`,
      };
      return;
    }
    const current = previous - cost;
    tx.update(userRef, {coins: current});
    const txId = writeTx(tx, {userId: callerUid, delta: -cost, previous, action, sourceTag, reason});
    response = {
      ...response,
      transactionId: txId,
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: current,
      delta: -cost,
    };
  });
  return response;
});

export const processReferral = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<{inviterUserId?: unknown}>) => {
  const callerUid = uid(request);
  const inviterUid = requiredText(request.data?.inviterUserId, "inviterUserId");
  if (callerUid === inviterUid) throw new HttpsError("invalid-argument", "You cannot refer yourself.");
  const reward = 100;
  const callerRef = db.collection(USERS).doc(callerUid);
  const inviterRef = db.collection(USERS).doc(inviterUid);
  const statsRef = db.collection(REFERRAL_STATS).doc(inviterUid);
  const nowMs = Date.now();
  const today = utcDateString(new Date(nowMs));
  let result = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    reason: "referral_already_processed",
  };
  await db.runTransaction(async (tx) => {
    const callerSnap = await tx.get(callerRef);
    const inviterSnap = await tx.get(inviterRef);
    const statsSnap = await tx.get(statsRef);
    if (!callerSnap.exists || !inviterSnap.exists) throw new HttpsError("not-found", "Referral user was not found.");
    const callerData = callerSnap.data() ?? {};
    const state = coinState(callerData.coinState);
    const previous = typeof callerData.coins === "number" ? Math.trunc(callerData.coins) : 0;
    if (state.referralRewarded === true) {
      result = {...result, previousBalance: previous, currentBalance: previous};
      return;
    }
    const inviterData = inviterSnap.data() ?? {};
    const stats = statsSnap.data() ?? {};
    const skipReason = referralSkipReason(callerData.createdAt, inviterData.createdAt, stats, today, nowMs);
    if (skipReason) {
      result = {...result, previousBalance: previous, currentBalance: previous, reason: skipReason};
      return;
    }
    tx.set(statsRef, {
      day: today,
      count: readDailyCount(statsSnap, today) + 1,
      total: (typeof stats.total === "number" ? stats.total : 0) + 1,
    });
    const inviterPrevious = typeof inviterData.coins === "number" ? Math.trunc(inviterData.coins) : 0;
    state.referredByUserId = inviterUid;
    state.referralRewarded = true;
    tx.update(callerRef, {coins: previous + reward, coinState: state});
    tx.update(inviterRef, {coins: inviterPrevious + reward});
    writeTx(tx, {userId: callerUid, delta: reward, previous, action: "referral", sourceTag: "coins.process_referral", reason: "referral_rewarded"});
    writeTx(tx, {userId: inviterUid, delta: reward, previous: inviterPrevious, action: "referral", sourceTag: "coins.process_referral", reason: "inviter_reward"});
    result = {
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: previous + reward,
      delta: reward,
      reason: "referral_rewarded",
    };
  });
  return result;
});

export const unlockPremiumPreview = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<{collectionKey?: unknown}>) => {
  const callerUid = uid(request);
  const key = requiredText(request.data?.collectionKey, "collectionKey").toLowerCase();
  const cost = SPENDS.premiumPreview24h;
  const userRef = db.collection(USERS).doc(callerUid);
  const nowMs = Date.now();
  const empty = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    bypassed: false,
    insufficientBalance: false,
    reason: "premium_preview_unlock_24h",
    transactionId: "",
    expiresAt: 0,
  };
  let response = empty;

  await db.runTransaction(async (tx) => {
    response = {...empty};
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const state = coinState(data.coinState);
    const unlocks: Record<string, number> = {};
    const rawUnlocks = state.premiumPreviewUnlocks;
    if (rawUnlocks && typeof rawUnlocks === "object") {
      for (const [k, v] of Object.entries(rawUnlocks as Record<string, unknown>)) {
        if (typeof v === "number" && v > nowMs) unlocks[k.trim().toLowerCase()] = v;
      }
    }
    const current = {previousBalance: previous, currentBalance: previous};
    if (unlocks[key]) {
      response = {...response, ...current, success: true, reason: "premium_preview_already_unlocked", expiresAt: unlocks[key]};
      return;
    }
    const bypassed = data.premium === true;
    if (!bypassed && previous < cost) {
      response = {...response, ...current, insufficientBalance: true, reason: "premiumPreview24h_insufficient_balance"};
      return;
    }
    unlocks[key] = nowMs + PREVIEW_ACCESS_MS;
    if (bypassed) {
      tx.update(userRef, {"coinState.premiumPreviewUnlocks": unlocks});
      response = {...response, ...current, success: true, bypassed: true, reason: "premiumPreview24h_premium_bypass", expiresAt: unlocks[key]};
      return;
    }
    const txId = writeTx(tx, {
      userId: callerUid,
      delta: -cost,
      previous,
      action: "premiumPreview24h",
      sourceTag: "coins.preview.unlock.callable",
      reason: "premium_preview_unlock_24h",
    });
    tx.update(userRef, {"coins": previous - cost, "coinState.premiumPreviewUnlocks": unlocks});
    response = {
      ...response,
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: previous - cost,
      delta: -cost,
      transactionId: txId,
      expiresAt: unlocks[key],
    };
  });
  return response;
});

export function isValidRequestId(value: unknown): value is string {
  return typeof value === "string" && REQUEST_ID_PATTERN.test(value);
}

export type FreezePurchasePlan =
  | {atCap: true}
  | {insufficientBalance: true}
  | {current: number; freezes: number};

/** Premium never changes the price or the cap. */
export function planFreezePurchase(balance: number, freezes: number): FreezePurchasePlan {
  if (freezes >= MAX_STREAK_FREEZES) return {atCap: true};
  if (balance < STREAK_FREEZE_COST) return {insufficientBalance: true};
  return {current: balance - STREAK_FREEZE_COST, freezes: freezes + 1};
}

export const buyStreakFreeze = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<{requestId?: unknown}>) => {
  const callerUid = uid(request);
  const requestId = request.data?.requestId;
  if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  const userRef = db.collection(USERS).doc(callerUid);
  const txId = `ctx_streakFreeze_${callerUid}_${requestId}`;
  const txRef = db.collection(TRANSACTIONS).doc(txId);
  const emptyResponse = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    streakFreezes: 0,
    insufficientBalance: false,
    atCap: false,
    reason: "streak_freeze_purchase",
    transactionId: "",
  };
  let response = emptyResponse;

  await db.runTransaction(async (tx) => {
    response = {...emptyResponse};
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const txSnap = await tx.get(txRef);
    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const rawFreezes = Number(coinState(data.coinState).streakFreezes);
    const freezes = Number.isFinite(rawFreezes) ? Math.max(0, Math.trunc(rawFreezes)) : 0;
    const current = {previousBalance: previous, currentBalance: previous, streakFreezes: freezes, transactionId: txId};
    if (txSnap.exists) {
      response = {...response, ...current, success: true, reason: "duplicate"};
      return;
    }
    const plan = planFreezePurchase(previous, freezes);
    if ("atCap" in plan) {
      response = {...response, ...current, atCap: true, reason: "streak_freeze_at_cap", transactionId: ""};
      return;
    }
    if ("insufficientBalance" in plan) {
      response = {...response, ...current, insufficientBalance: true, reason: "streak_freeze_insufficient_balance", transactionId: ""};
      return;
    }
    tx.update(userRef, {"coins": plan.current, "coinState.streakFreezes": plan.freezes});
    tx.set(txRef, coinTransactionDoc({
      id: txId,
      userId: callerUid,
      at: admin.firestore.Timestamp.now(),
      delta: -STREAK_FREEZE_COST,
      balanceBefore: previous,
      action: "streakFreeze",
      description: "Streak freeze",
      sourceTag: "coins.buy_streak_freeze.callable",
      reason: "streak_freeze_purchase",
    }));
    response = {
      ...response,
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: plan.current,
      delta: -STREAK_FREEZE_COST,
      streakFreezes: plan.freezes,
      transactionId: txId,
    };
  });
  return response;
});
