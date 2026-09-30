import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, REGION, utcDateString} from "./common";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const AD_RATE_DAILY = "coinAdRateDaily";

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
const REFUND_WINDOW_MS = 3_600_000;
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
  if (debit.action === "streakFreeze") throw notRefundable();
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

export const awardCoins = onCall({region: REGION, cors: true}, async (request: CallableRequest<Record<string, unknown>>) => {
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
    if (action === "profileCompletion" && state.profileCompletionRewarded === true) {
      skip("profile_reward_already_claimed");
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

export const spendCoins = onCall({region: REGION, cors: true}, async (request: CallableRequest<Record<string, unknown>>) => {
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

export const processReferral = onCall({region: REGION, cors: true}, async (request: CallableRequest<{inviterUserId?: unknown}>) => {
  const callerUid = uid(request);
  const inviterUid = requiredText(request.data?.inviterUserId, "inviterUserId");
  if (callerUid === inviterUid) throw new HttpsError("invalid-argument", "You cannot refer yourself.");
  const reward = 100;
  const callerRef = db.collection(USERS).doc(callerUid);
  const inviterRef = db.collection(USERS).doc(inviterUid);
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
    if (!callerSnap.exists || !inviterSnap.exists) throw new HttpsError("not-found", "Referral user was not found.");
    const callerData = callerSnap.data() ?? {};
    const state = coinState(callerData.coinState);
    const previous = typeof callerData.coins === "number" ? Math.trunc(callerData.coins) : 0;
    if (state.referralRewarded === true) {
      result = {...result, previousBalance: previous, currentBalance: previous};
      return;
    }
    const inviterData = inviterSnap.data() ?? {};
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

export const buyStreakFreeze = onCall({region: REGION, cors: true}, async (request: CallableRequest<{requestId?: unknown}>) => {
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
