import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const REGION = "asia-south1";
const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";

const AWARDS: Record<string, number> = {
  rewardedAd: 10,
  firstWallpaperUpload: 50,
  profileCompletion: 25,
  proDailyBonus: 50,
  refund: 0,
};

const SPENDS: Record<string, number> = {
  wallpaperDownload: 5,
  premiumWallpaperDownload: 15,
  aiGeneration: 0,
  premiumFilter: 5,
  premiumPreview24h: 10,
};

const AI_GENERATION_AMOUNTS = new Set([10, 75, 100]);
const MAX_AMOUNT = 1000;
const MAX_REFUND = 100;

export function clampAmount(value: unknown): number {
  const amount = typeof value === "number" && Number.isFinite(value) ? Math.trunc(value) : 0;
  return Math.max(0, Math.min(MAX_AMOUNT, amount));
}

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

function utcDateString(d = new Date()): string {
  return d.toISOString().slice(0, 10);
}

function coinState(raw: unknown): Record<string, unknown> {
  return raw && typeof raw === "object" && !Array.isArray(raw) ? {...(raw as Record<string, unknown>)} : {};
}

function transactionId(action: string): string {
  return `ctx_${action}_${Date.now()}_${Math.floor(Math.random() * 1e9).toString(16)}`;
}

function awardAmount(action: string, requested: unknown): number {
  if (action === "refund") {
    const amount = Math.min(clampAmount(requested), MAX_REFUND);
    if (amount <= 0) throw new HttpsError("invalid-argument", "refund amount must be positive.");
    return amount;
  }
  const amount = AWARDS[action];
  if (amount == null || amount <= 0) throw new HttpsError("invalid-argument", "Unsupported award action.");
  return amount;
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

async function writeTx(
  tx: admin.firestore.Transaction,
  params: {userId: string; delta: number; previous: number; action: string; sourceTag: string; reason: string},
): Promise<void> {
  const id = transactionId(params.action);
  const now = admin.firestore.Timestamp.now();
  tx.set(db.collection(TRANSACTIONS).doc(id), {
    id,
    userId: params.userId,
    createdAt: now,
    updatedAt: now,
    delta: params.delta,
    balanceBefore: params.previous,
    balanceAfter: params.previous + params.delta,
    action: params.action,
    description: params.reason,
    sourceTag: params.sourceTag,
    reason: params.reason,
    status: "completed",
    type: params.delta >= 0 ? "credit" : "debit",
  });
}

export const awardCoins = onCall({region: REGION, cors: true}, async (request: CallableRequest<Record<string, unknown>>) => {
  const callerUid = uid(request);
  const action = requiredText(request.data?.action, "action");
  const sourceTag = requiredText(request.data?.sourceTag, "sourceTag");
  const reason = typeof request.data?.reason === "string" ? request.data.reason.trim() : action;
  const delta = awardAmount(action, request.data?.amount);
  const userRef = db.collection(USERS).doc(callerUid);
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
    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const state = coinState(data.coinState);
    if (action === "firstWallpaperUpload" && state.firstWallpaperUploadRewarded === true) {
      response = {...response, previousBalance: previous, currentBalance: previous, reason: "first_upload_reward_already_claimed"};
      return;
    }
    if (action === "profileCompletion" && state.profileCompletionRewarded === true) {
      response = {...response, previousBalance: previous, currentBalance: previous, reason: "profile_reward_already_claimed"};
      return;
    }
    if (action === "proDailyBonus" && state.proDailyBonusDate === utcDateString()) {
      response = {...response, previousBalance: previous, currentBalance: previous, reason: "pro_bonus_already_claimed"};
      return;
    }
    if (action === "firstWallpaperUpload") state.firstWallpaperUploadRewarded = true;
    if (action === "profileCompletion") state.profileCompletionRewarded = true;
    if (action === "proDailyBonus") state.proDailyBonusDate = utcDateString();
    const current = previous + delta;
    tx.update(userRef, {coins: current, coinState: state});
    await writeTx(tx, {userId: callerUid, delta, previous, action, sourceTag, reason});
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
    await writeTx(tx, {userId: callerUid, delta: -cost, previous, action, sourceTag, reason});
    response = {
      ...response,
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: current,
      delta: -cost,
    };
  });
  return response;
});

export function rejectSelfReferral(callerUid: string, inviterUserId: string): void {
  if (callerUid === inviterUserId) throw new HttpsError("invalid-argument", "You cannot refer yourself.");
}

export const processReferral = onCall({region: REGION, cors: true}, async (request: CallableRequest<{inviterUserId?: unknown}>) => {
  const callerUid = uid(request);
  const inviterUid = requiredText(request.data?.inviterUserId, "inviterUserId");
  rejectSelfReferral(callerUid, inviterUid);
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
    await writeTx(tx, {userId: callerUid, delta: reward, previous, action: "referral", sourceTag: "coins.process_referral", reason: "referral_rewarded"});
    await writeTx(tx, {userId: inviterUid, delta: reward, previous: inviterPrevious, action: "referral", sourceTag: "coins.process_referral", reason: "inviter_reward"});
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
