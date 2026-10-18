import * as admin from "firebase-admin";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, int, readDailyCount, REGION, str, utcDateString} from "./common";
import {
  DEFAULT_ECONOMY, type EconomyConfig, grantXp, isPrice, loadEconomy, proPrice, type WheelSegment, weightedPick,
  xpForCoins,
} from "./economy";
import {applyQuestEvent, buildQuestState, type QuestState} from "./questCatalog";
import {pickChestCosmetic} from "./shopCatalog";
import {STREAK_RESCUE_MIN_COUNT, streakCycleDay} from "./streak";
import {isStudioWall} from "./studio/process";
import {inventoryOwned, rankRewardsFor} from "./rankRewards";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const AD_RATE_DAILY = "coinAdRateDaily";
const REFUND_DAILY = "coinRefundDaily";
const REFERRAL_STATS = "referralStats";
const WALLS = "walls";
const UPLOADS = "githubUploads";

type SpendKey = keyof EconomyConfig["spend"];
type AiTier = "fast" | "balanced" | "quality";

const SPEND_PRICE_KEYS = new Map<string, SpendKey>([
  ["wallpaperDownload", "wallpaperDownload"],
  ["premiumWallpaperDownload", "premiumWallpaperDownload"],
  ["liveWallpaperStyle", "liveWallpaperStyle"],
  ["premiumFilter", "premiumFilter"],
  ["premiumPreview24h", "premiumPreview24h"],
  ["autoRotatePass7d", "autoRotatePass7d"],
]);
// What clients without `pricingVersion: 2` show, so they are never charged more than they confirmed.
const LEGACY_SPENDS = new Map<string, number>([
  ["wallpaperDownload", 5],
  ["premiumWallpaperDownload", 15],
  ["premiumFilter", 5],
  ["premiumPreview24h", 10],
]);
const AI_TIER_PRICE_KEYS: Record<AiTier, SpendKey> = {fast: "aiFast", balanced: "aiBalanced", quality: "aiQuality"};
const LEGACY_AI_TIERS = new Map<number, AiTier>([[10, "fast"], [75, "balanced"], [100, "quality"]]);
const PREMIUM_PASS_ACTIONS = new Set(["premiumWallpaperDownload", "premiumPreview24h"]);
const PASS_MS = 7 * 86_400_000;
const STYLE_ID_PATTERN = /^[a-z][a-z_]{1,39}$/;
const AD_XP_MAX_PER_DAY = 3;

export const STREAK_FREEZE_COST = DEFAULT_ECONOMY.spend.streakFreeze;
export const MAX_STREAK_FREEZES = 2;
export const STREAK_RESCUE_COST = DEFAULT_ECONOMY.spend.streakRescue;
const STREAK_RESCUE_COOLDOWN_MS = 30 * 86_400_000;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;

const REFUND_WINDOW_MS = 600_000;
// Allowed only when the AI worker confirms the generation did not succeed.
const AI_REFUND_EVIDENCE_WINDOW_MS = 86_400_000;
const AI_WORKER_DEFAULT_BASE = "https://prismwalls.com";
const AI_WORKER_TIMEOUT_MS = 3_000;
const REFUND_MAX_PER_DAY = 5;
// Only the debits the app refunds today: a failed download and a failed AI generation.
const REFUNDABLE_ACTIONS = new Set(["wallpaperDownload", "premiumWallpaperDownload", "aiGeneration"]);
const PREVIEW_ACCESS_MS = 86_400_000;
const REFERRAL_NEW_ACCOUNT_MS = 14 * 86_400_000;
// Mirrors defaultProfilePhotoUrl in lib/core/constants/app_constants.dart.
const DEFAULT_PROFILE_PHOTO =
  "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4";
const CALLABLE_OPTIONS = {region: REGION, cors: true, maxInstances: 10};
const AD_RATE_MIN_GAP_MS = 20_000;

function requiredText(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.trim().length > 200) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return value.trim();
}

function optionalReason(value: unknown, fallback: string): string {
  return typeof value === "string" ? value.trim().slice(0, 200) : fallback;
}

export function optionalLabel(value: unknown): string | undefined {
  const label = typeof value === "string" ? value.trim().slice(0, 60) : "";
  return label === "" ? undefined : label;
}

function requiredDocumentId(value: unknown, field: string): string {
  const id = requiredText(value, field);
  if (id.includes("/") || id === "." || id === "..") {
    throw new HttpsError("invalid-argument", `${field} must be a document ID.`);
  }
  return id;
}

function uid(request: CallableRequest<unknown>): string {
  const value = request.auth?.uid?.trim() ?? "";
  if (!value) throw new HttpsError("unauthenticated", "Sign in to use coins.");
  return value;
}

function coinState(raw: unknown): Record<string, unknown> {
  return raw && typeof raw === "object" && !Array.isArray(raw) ? {...(raw as Record<string, unknown>)} : {};
}

const privateEconomyRef = (userId: string) => db.doc(`${USERS}/${userId}/private/economy`);

/** Writes `fields` to `private/economy`, creating it when missing, and always bumps `rev`. */
function writePrivate(
  tx: admin.firestore.Transaction,
  ref: admin.firestore.DocumentReference,
  privateData: admin.firestore.DocumentData,
  fields: Record<string, unknown>,
): void {
  tx.set(ref, {...fields, rev: int(privateData.rev, 0) + 1}, {merge: true});
}

/** Quest state with the server-fed `event` counted; the bonus item it completes pays nothing by itself. */
function questsAfter(
  privateData: admin.firestore.DocumentData,
  event: "watch_ad" | "pro_spin",
  nowMs: number,
  isPro: boolean,
  config: EconomyConfig,
): {quests: QuestState} {
  return {quests: applyQuestEvent(buildQuestState(privateData.quests, nowMs, isPro), event, config).state};
}

function transactionId(action: string): string {
  return `ctx_${action}_${Date.now()}_${Math.floor(Math.random() * 1e9).toString(16)}`;
}

function awardAmount(action: string, award: EconomyConfig["award"], adCountToday: number): number {
  const amounts = new Map<string, number>([
    ["rewardedAd", adCountToday === 0 ? award.rewardedAdFirstOfDay : award.rewardedAd],
    ["firstWallpaperUpload", award.firstWallpaperUpload],
    ["profileCompletion", award.profileCompletion],
    ["proDailyBonus", Math.min(...award.proSpin.map((segment) => segment.coins))],
  ]);
  const amount = amounts.get(action);
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Unsupported award action.");
  }
  return amount;
}

/**
 * Validates that `debit` (a coinTransactions doc) is refundable by `callerUid` right now.
 * Throws HttpsError otherwise. Returns the coin amount to credit back, or null when the stored delta is unreadable.
 */
export function refundableDelta(
  debit: admin.firestore.DocumentData | undefined,
  callerUid: string,
  nowMs: number,
  windowMs = REFUND_WINDOW_MS,
): number | null {
  const notRefundable = () => new HttpsError("failed-precondition", "No refundable spend.");
  if (!debit) throw notRefundable();
  if (debit.userId !== callerUid) throw notRefundable();
  if (debit.type !== "debit") throw notRefundable();
  if (debit.status !== "completed") throw notRefundable();
  if (typeof debit.action !== "string" || !REFUNDABLE_ACTIONS.has(debit.action)) throw notRefundable();
  const createdAtMs = (debit.createdAt as admin.firestore.Timestamp | undefined)?.toMillis?.();
  if (typeof createdAtMs !== "number") throw notRefundable();
  if (nowMs - createdAtMs > windowMs) throw notRefundable();
  const delta = Number(debit.delta);
  return Number.isFinite(delta) ? Math.abs(Math.trunc(delta)) : null;
}

type AiChargeStatus = "succeeded" | "failed" | "not_started";

/**
 * Asks the AI worker whether the charge `txId` produced an image. Null when the worker cannot say: network
 * error, timeout, a non-200 answer or an answer in an unknown shape.
 */
async function fetchAiChargeStatus(txId: string): Promise<AiChargeStatus | null> {
  const base = (process.env.AI_WORKER_BASE_URL ?? "").trim().replace(/\/+$/, "") || AI_WORKER_DEFAULT_BASE;
  try {
    const response = await fetch(`${base}/api/ai/charges/${encodeURIComponent(txId)}`, {
      signal: AbortSignal.timeout(AI_WORKER_TIMEOUT_MS),
    });
    if (!response.ok) return null;
    const status = ((await response.json()) as {status?: unknown} | null)?.status;
    return status === "succeeded" || status === "failed" || status === "not_started" ? status : null;
  } catch {
    return null;
  }
}

interface AdRateState {
  count?: number;
  lastAt?: number;
}

/** Whether a rewarded-ad award is allowed given the caller's rate-limit doc state. */
export function rewardedAdAllowed(
  state: AdRateState,
  nowMs: number,
  maxPerDay = DEFAULT_ECONOMY.award.rewardedAdMaxPerDay,
): boolean {
  const count = typeof state.count === "number" ? state.count : 0;
  const lastAt = typeof state.lastAt === "number" ? state.lastAt : undefined;
  if (count >= maxPerDay) return false;
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
  caps = {maxPerDay: DEFAULT_ECONOMY.award.referralMaxPerDay, maxLifetime: DEFAULT_ECONOMY.award.referralMaxLifetime},
): string | null {
  const callerMs = parseCreatedAtMs(callerCreatedAt);
  if (callerMs == null || nowMs - callerMs > REFERRAL_NEW_ACCOUNT_MS) return "referral_caller_not_new";
  const inviterMs = parseCreatedAtMs(inviterCreatedAt);
  if (inviterMs == null || inviterMs >= callerMs) return "referral_inviter_not_older";
  const daily = stats.day === today && typeof stats.count === "number" ? stats.count : 0;
  if ((typeof stats.total === "number" ? stats.total : 0) >= caps.maxLifetime) return "referral_inviter_lifetime_limit";
  if (daily >= caps.maxPerDay) return "referral_inviter_daily_limit";
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

function thumbnailUploadPath(rawUrl: unknown, owner: string, repo: string): string | null {
  if (typeof rawUrl !== "string") return null;
  try {
    const url = new URL(rawUrl);
    const parts = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
    if (url.protocol !== "https:" || url.hostname !== "raw.githubusercontent.com" || parts[0] !== owner ||
      parts[1] !== repo || parts.length < 4) return null;
    const path = parts.slice(3).join("/");
    return path.startsWith("thumb_") ? path : null;
  } catch {
    return null;
  }
}

async function hasSubmittedWall(callerUid: string, emails: string[]): Promise<boolean> {
  const owner = str(process.env.GH_USERNAME);
  const repo = str(process.env.GH_REPO_WALLS);
  for (const email of emails) {
    const walls = await db.collection(WALLS).where("email", "==", email).get();
    for (const wall of walls.docs) {
      const data = wall.data();
      if (await isStudioWall(wall.id, data)) continue;
      if (data.review === true) return true;
      const path = owner !== "" && repo !== "" ? thumbnailUploadPath(data.wallpaper_thumb, owner, repo) : null;
      if (path === null) continue;
      const uploads = await db.collection(UPLOADS).where("path", "==", path).get();
      if (uploads.docs.some((upload) => {
        const evidence = upload.data();
        return evidence.uid === callerUid && evidence.repo === repo;
      })) return true;
    }
  }
  return false;
}

function aiTier(qualityTier: unknown, amount: unknown): AiTier {
  if (qualityTier === "fast" || qualityTier === "balanced" || qualityTier === "quality") return qualityTier;
  const legacy = qualityTier == null && typeof amount === "number" ? LEGACY_AI_TIERS.get(Math.trunc(amount)) : undefined;
  if (!legacy) throw new HttpsError("invalid-argument", "Unsupported AI generation amount.");
  return legacy;
}

/** List price of a spend before any Pro discount. Legacy clients pay legacy prices until the window closes. */
export function spendBasePrice(
  action: string,
  data: Record<string, unknown> | undefined,
  config: EconomyConfig,
  nowMs: number,
): {basePrice: number; qualityTier?: AiTier} {
  if (action === "aiGeneration") {
    const tier = aiTier(data?.qualityTier, data?.amount);
    return {basePrice: config.spend[AI_TIER_PRICE_KEYS[tier]], qualityTier: tier};
  }
  const key = SPEND_PRICE_KEYS.get(action);
  if (!key) throw new HttpsError("invalid-argument", "Unsupported spend action.");
  const legacy = !isPricingV2(data) && Date.parse(config.flags.legacyPricingUntil) > nowMs ?
    LEGACY_SPENDS.get(action) :
    undefined;
  return {basePrice: legacy ?? config.spend[key]};
}

const isPricingV2 = (data: Record<string, unknown> | undefined) =>
  typeof data?.pricingVersion === "number" && data.pricingVersion >= 2;

/** Response for a repeated spend: the original debit, with no second charge. */
export function duplicateSpendResponse<T extends Record<string, unknown>>(
  base: T,
  original: admin.firestore.DocumentData,
  balance: number,
  reason: string,
): T & {success: true; changed: true; previousBalance: number; currentBalance: number; delta: number; transactionId: string} {
  const delta = typeof original.delta === "number" ? Math.trunc(original.delta) : 0;
  return {
    ...base,
    success: true,
    changed: true,
    previousBalance: typeof original.balanceBefore === "number" ? Math.trunc(original.balanceBefore) : balance,
    currentBalance: balance,
    delta,
    reason,
    transactionId: typeof original.id === "string" ? original.id : "",
    ...coinState(original.replay),
  };
}

function writeTx(
  tx: admin.firestore.Transaction,
  params: {
    userId: string;
    delta: number;
    previous: number;
    action: string;
    sourceTag: string;
    reason: string;
    description?: string;
    fixedId?: string;
    extra?: Record<string, unknown>;
  },
): string {
  const id = params.fixedId ?? transactionId(params.action);
  tx.set(db.collection(TRANSACTIONS).doc(id), {
    ...coinTransactionDoc({
      id,
      userId: params.userId,
      at: admin.firestore.Timestamp.now(),
      delta: params.delta,
      balanceBefore: params.previous,
      action: params.action,
      description: params.description ?? params.reason,
      sourceTag: params.sourceTag,
      reason: params.reason,
    }),
    ...params.extra,
  });
  return id;
}

export const awardCoins = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<Record<string, unknown>>) => {
  const callerUid = uid(request);
  const action = requiredText(request.data?.action, "action");
  const sourceTag = requiredText(request.data?.sourceTag, "sourceTag");
  const reason = optionalReason(request.data?.reason, action);
  const refundTxId = action === "refund" ? requiredDocumentId(request.data?.transactionId, "transactionId") : "";
  const rawRequestId = request.data?.requestId;
  if (rawRequestId != null && !isValidRequestId(rawRequestId)) {
    throw new HttpsError("invalid-argument", "requestId is invalid.");
  }
  const config = await loadEconomy();
  const award = config.award;
  const userRef = db.collection(USERS).doc(callerUid);
  const privateRef = privateEconomyRef(callerUid);
  const nowMs = Date.now();
  const today = utcDateString(new Date(nowMs));
  const adRateRef = db.collection(AD_RATE_DAILY).doc(`${callerUid}_${today}`);
  const debitRef = action === "refund" ? db.collection(TRANSACTIONS).doc(refundTxId) : null;
  const adAwardRef = action === "rewardedAd" && rawRequestId != null ?
    db.collection(TRANSACTIONS).doc(`award_${callerUid}_${rawRequestId}`) :
    null;
  const refundDailyRef = db.collection(REFUND_DAILY).doc(`${callerUid}_${today}`);
  // Evidence for the one-time upload award: the caller has at least one wall submission.
  let hasWall = false;
  if (action === "firstWallpaperUpload") {
    const email = str(request.auth?.token?.email);
    hasWall = email !== "" && await hasSubmittedWall(callerUid, [...new Set([email, email.toLowerCase()])]);
  }
  // The worker's answer for an AI refund, asked once even when the transaction retries. Undefined: not asked yet.
  let aiChargeStatus: AiChargeStatus | null | undefined;
  let response: {
    success: boolean;
    changed: boolean;
    previousBalance: number;
    currentBalance: number;
    delta: number;
    reason: string;
    adsRemaining?: number;
  } = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    reason,
  };
  const initialResponse = {...response};

  await db.runTransaction(async (tx) => {
    response = {...initialResponse};
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const adRateSnap = action === "rewardedAd" ? await tx.get(adRateRef) : null;
    const adAwardSnap = adAwardRef ? await tx.get(adAwardRef) : null;
    const privateSnap = action !== "refund" ? await tx.get(privateRef) : null;
    const debitSnap = debitRef ? await tx.get(debitRef) : null;
    const refundDailySnap = debitRef ? await tx.get(refundDailyRef) : null;

    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const state = coinState(data.coinState);
    const adCountToday = typeof adRateSnap?.data()?.count === "number" ? adRateSnap.data()?.count : 0;
    const adsRemaining = action === "rewardedAd" ?
      {adsRemaining: Math.max(0, award.rewardedAdMaxPerDay - adCountToday)} :
      {};
    const skip = (skipReason: string) => {
      response = {...response, previousBalance: previous, currentBalance: previous, reason: skipReason, ...adsRemaining};
    };

    if (adAwardSnap?.exists) {
      const original = adAwardSnap.data() ?? {};
      response = {
        ...response,
        success: true,
        changed: true,
        previousBalance: typeof original.balanceBefore === "number" ? Math.trunc(original.balanceBefore) : previous,
        currentBalance: typeof original.balanceAfter === "number" ? Math.trunc(original.balanceAfter) : previous,
        delta: typeof original.delta === "number" ? Math.trunc(original.delta) : 0,
        ...adsRemaining,
      };
      return;
    }

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
    const debit = debitSnap?.data();
    if (action === "refund" && debit?.action === "aiGeneration" && debit.userId === callerUid &&
      aiChargeStatus === undefined) {
      aiChargeStatus = await fetchAiChargeStatus(refundTxId);
    }
    if (aiChargeStatus === "succeeded") {
      skip("refund_denied_generation_succeeded");
      return;
    }
    // An AI debit is refunded for up to 24 hours once the worker says no image was made. Without an answer the
    // 10 minute rule holds.
    const refundWindowMs = aiChargeStatus === "failed" || aiChargeStatus === "not_started" ?
      AI_REFUND_EVIDENCE_WINDOW_MS :
      REFUND_WINDOW_MS;
    if (action === "proDailyBonus" && data.premium !== true) {
      skip("pro_bonus_requires_premium");
      return;
    }
    // The legacy daily bonus and the Pro spin share one receipt a day.
    if (action === "proDailyBonus" && (state.proDailyBonusDate === today || state.proSpinDate === today)) {
      skip("pro_bonus_already_claimed");
      return;
    }
    // ponytail: no AdMob server-side verification; add an SSV callback if ad fraud shows up
    if (action === "rewardedAd" && !rewardedAdAllowed(adRateSnap?.data() ?? {}, nowMs, award.rewardedAdMaxPerDay)) {
      skip("rewarded_ad_limit");
      return;
    }

    const delta = action === "refund" ?
      refundableDelta(debit, callerUid, nowMs, refundWindowMs) :
      awardAmount(action, award, adCountToday);
    if (delta === null) throw new HttpsError("failed-precondition", "No refundable spend.");

    if (action === "refund" && debitRef) {
      tx.update(debitRef, {status: "refunded", updatedAt: admin.firestore.Timestamp.now()});
      tx.set(refundDailyRef, {day: today, count: refundsToday + 1});
    }
    if (action === "firstWallpaperUpload") state.firstWallpaperUploadRewarded = true;
    if (action === "profileCompletion") state.profileCompletionRewarded = true;
    if (action === "proDailyBonus") {
      state.proDailyBonusDate = today;
      state.proSpinDate = today;
    }
    if (action === "rewardedAd") {
      tx.set(adRateRef, {count: adCountToday + 1, lastAt: nowMs});
      state.adsToday = {day: today, count: adCountToday + 1};
    }
    // Refunds give back coins, not progress; only the first few ads of a day count for XP.
    const earnsXp = action !== "refund" && (action !== "rewardedAd" || adCountToday < AD_XP_MAX_PER_DAY);
    const nextXp = earnsXp ? grantXp(data, xpForCoins(delta, config), nowMs) : null;
    const privateData = privateSnap?.data() ?? {};
    const rewards = nextXp ? rankRewardsFor(nextXp.xp, inventoryOwned(privateData), config, nowMs) : null;
    if (action === "rewardedAd" || (rewards?.added.length ?? 0) > 0) {
      writePrivate(tx, privateRef, privateData, {
        ...(action === "rewardedAd" ? questsAfter(privateData, "watch_ad", nowMs, data.premium === true, config) : {}),
        ...(rewards && rewards.added.length > 0 ? {inventory: {owned: rewards.owned}} : {}),
      });
    }

    const current = previous + delta;
    tx.update(userRef, {
      coins: current,
      coinState: state,
      ...nextXp,
    });
    writeTx(tx, {userId: callerUid, delta, previous, action, sourceTag, reason, fixedId: adAwardRef?.id});
    response = {
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: current,
      delta,
      reason,
      ...(action === "rewardedAd" ? {adsRemaining: Math.max(0, award.rewardedAdMaxPerDay - adCountToday - 1)} : {}),
    };
  });
  return response;
});

export const claimProSpin = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<{requestId?: unknown}>) => {
  const callerUid = uid(request);
  const requestId = request.data?.requestId;
  if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  const config = await loadEconomy();
  const userRef = db.collection(USERS).doc(callerUid);
  const privateRef = privateEconomyRef(callerUid);
  const txId = `ctx_proSpin_${callerUid}_${requestId}`;
  const txRef = db.collection(TRANSACTIONS).doc(txId);
  const nowMs = Date.now();
  const today = utcDateString(new Date(nowMs));
  const empty = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    reason: "pro_spin",
    transactionId: "",
    coins: 0,
    segment: -1,
  };
  let response = empty;

  await db.runTransaction(async (tx) => {
    response = {...empty};
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const txSnap = await tx.get(txRef);
    const privateSnap = await tx.get(privateRef);
    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const state = coinState(data.coinState);
    if (txSnap.exists) {
      const original = txSnap.data() ?? {};
      response = {
        ...duplicateSpendResponse(response, original, previous, "pro_spin"),
        coins: int(original.coins, 0),
        segment: int(original.segment, -1),
      };
      return;
    }
    const current = {previousBalance: previous, currentBalance: previous};
    if (data.premium !== true) {
      response = {...response, ...current, reason: "pro_spin_requires_premium"};
      return;
    }
    if (state.proSpinDate === today || state.proDailyBonusDate === today) {
      response = {...response, ...current, reason: "pro_spin_already_claimed"};
      return;
    }
    const segment = weightedPick(config.award.proSpin);
    const coins = config.award.proSpin[segment].coins;
    const balance = previous + coins;
    const nextXp = grantXp(data, xpForCoins(coins, config), nowMs);
    tx.update(userRef, {
      "coins": balance,
      "coinState.proSpinDate": today,
      "coinState.proDailyBonusDate": today,
      ...nextXp,
    });
    writeTx(tx, {
      userId: callerUid,
      delta: coins,
      previous,
      action: "proSpin",
      sourceTag: "coins.claim_pro_spin.callable",
      reason: "pro_spin",
      description: `Pro spin (+${coins})`,
      fixedId: txId,
      extra: {coins, segment},
    });
    const privateData = privateSnap.data() ?? {};
    const rewards = rankRewardsFor(nextXp.xp, inventoryOwned(privateData), config, nowMs);
    writePrivate(tx, privateRef, privateData, {
      ...questsAfter(privateData, "pro_spin", nowMs, true, config),
      ...(rewards.added.length > 0 ? {inventory: {owned: rewards.owned}} : {}),
    });
    response = {
      ...response,
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: balance,
      delta: coins,
      transactionId: txId,
      coins,
      segment,
    };
  });
  return response;
});

/** `private/economy.spinWheel`: the paid spins of one UTC day and whether its free Pro spin is used. */
export interface WheelDay { dayKey: string; paid: number; freeUsed: boolean }

export interface WheelStatus { freeSpinAvailable: boolean; paidSpinsLeft: number; price: number }

export type WheelRefusal =
  "spin_wheel_daily_limit" | "spin_wheel_price_changed" | "spin_wheel_insufficient_balance";

export type WheelPlan =
  | {ok: false; reason: WheelRefusal}
  | {ok: true; free: boolean; cost: number; next: WheelDay};

export interface WheelPrize { kind: WheelSegment["kind"]; coins: number; xp: number; itemId: string | null }

interface WheelDayInput {
  isPro: boolean;
  today: string;
  coinState: Record<string, unknown>;
  wheelState: WheelDay;
  config: EconomyConfig;
}

/** The stored `spinWheel` field, read defensively. */
export function readWheelDay(raw: unknown): WheelDay {
  const stored = coinState(raw);
  return {
    dayKey: typeof stored.dayKey === "string" ? stored.dayKey : "",
    paid: Math.max(0, int(stored.paid, 0)),
    freeUsed: stored.freeUsed === true,
  };
}

/** Counts from another day are void. */
const wheelDayFor = (wheel: WheelDay, today: string): WheelDay =>
  wheel.dayKey === today ? wheel : {dayKey: today, paid: 0, freeUsed: false};

// The free spin shares its receipt with claimProSpin and proDailyBonus, so one Pro user gets one on any client.
function freeSpinAvailable({isPro, today, coinState: state, wheelState}: WheelDayInput): boolean {
  return isPro && state.proSpinDate !== today && state.proDailyBonusDate !== today &&
    !wheelDayFor(wheelState, today).freeUsed;
}

export function wheelStatus(input: WheelDayInput): WheelStatus {
  const {config, today, wheelState} = input;
  return {
    freeSpinAvailable: freeSpinAvailable(input),
    paidSpinsLeft: Math.max(0, config.award.spinWheelMaxPerDay - wheelDayFor(wheelState, today).paid),
    price: config.spend.spinWheel,
  };
}

/** Whether the spin may happen, what it costs and the state to store after it. The cost never exceeds `maxCost`. */
export function planWheelSpin(input: WheelDayInput & {balance: number; maxCost: number}): WheelPlan {
  const {today, config, wheelState, balance, maxCost} = input;
  const day = wheelDayFor(wheelState, today);
  const free = freeSpinAvailable(input);
  if (!free && day.paid >= config.award.spinWheelMaxPerDay) return {ok: false, reason: "spin_wheel_daily_limit"};
  const cost = free ? 0 : config.spend.spinWheel;
  if (cost > maxCost) return {ok: false, reason: "spin_wheel_price_changed"};
  if (balance < cost) return {ok: false, reason: "spin_wheel_insufficient_balance"};
  return {ok: true, free, cost, next: {dayKey: today, paid: day.paid + (free ? 0 : 1), freeUsed: day.freeUsed || free}};
}

/** What a slice pays. A cosmetic slice gives a random unowned common item, or its fallback coins when none is left. */
export function resolveWheelPrize(
  segment: WheelSegment,
  owned: readonly string[],
  random: () => number = Math.random,
): WheelPrize {
  switch (segment.kind) {
  case "coins": return {kind: "coins", coins: segment.coins, xp: 0, itemId: null};
  case "xp": return {kind: "xp", coins: 0, xp: segment.xp, itemId: null};
  case "cosmetic": {
    const item = pickChestCosmetic(owned, random);
    return {kind: "cosmetic", coins: item ? 0 : segment.fallbackCoins, xp: 0, itemId: item?.id ?? null};
  }
  }
}

interface SpinWheelReplyBase {
  previousBalance: number;
  currentBalance: number;
  delta: number;
  reason: string;
  transactionId: string;
  insufficientBalance: boolean;
  status: WheelStatus;
}

export type SpinWheelReply =
  | (SpinWheelReplyBase & {success: false; changed: false})
  | (SpinWheelReplyBase & {
    success: true;
    changed: true;
    cost: number;
    free: boolean;
    segment: number;
    prize: WheelPrize;
    segments: WheelSegment[];
  });

export const spinWheel = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<{requestId?: unknown; maxCost?: unknown; sourceTag?: unknown}>) => {
    const callerUid = uid(request);
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
    const maxCost = request.data?.maxCost;
    if (!isPrice(maxCost)) throw new HttpsError("invalid-argument", "maxCost is invalid.");
    const sourceTag = optionalLabel(request.data?.sourceTag) ?? "coins.spin_wheel.callable";
    const config = await loadEconomy();
    const userRef = db.collection(USERS).doc(callerUid);
    const privateRef = privateEconomyRef(callerUid);
    const txId = `ctx_spinWheel_${callerUid}_${requestId}`;
    const txRef = db.collection(TRANSACTIONS).doc(txId);
    const nowMs = Date.now();
    const today = utcDateString(new Date(nowMs));

    return db.runTransaction<SpinWheelReply>(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
      const txSnap = await tx.get(txRef);
      const privateSnap = await tx.get(privateRef);
      const data = snap.data() ?? {};
      const privateData = privateSnap.data() ?? {};
      const balance = int(data.coins, 0);
      const dayInput = {
        isPro: data.premium === true,
        today,
        coinState: coinState(data.coinState),
        wheelState: readWheelDay(privateData.spinWheel),
        config,
      };
      // The stored outcome with the live balance and today's status: other spends or a new day may have come between.
      if (txSnap.exists) {
        const stored = (txSnap.data() ?? {}).replay as SpinWheelReply;
        return {...stored, previousBalance: balance, currentBalance: balance, delta: 0, status: wheelStatus(dayInput)};
      }
      const plan = planWheelSpin({...dayInput, balance, maxCost});
      if (!plan.ok) {
        return {
          success: false,
          changed: false,
          previousBalance: balance,
          currentBalance: balance,
          delta: 0,
          reason: plan.reason,
          transactionId: "",
          insufficientBalance: plan.reason === "spin_wheel_insufficient_balance",
          status: wheelStatus(dayInput),
        };
      }

      const segments = config.award.spinWheel;
      const segment = weightedPick(segments);
      const rawInventory = coinState(privateData.inventory);
      const owned = coinState(rawInventory.owned);
      const prize = resolveWheelPrize(segments[segment], Object.keys(owned));
      const current = balance - plan.cost + prize.coins;
      const delta = prize.coins - plan.cost;
      const nextXp = grantXp(data, prize.xp + xpForCoins(prize.coins, config), nowMs);
      tx.update(userRef, {
        coins: current,
        ...(plan.free ? {"coinState.proSpinDate": today, "coinState.proDailyBonusDate": today} : {}),
        ...nextXp,
      });
      const ownedAfterPrize = prize.itemId ? {...inventoryOwned(privateData), [prize.itemId]: nowMs} : null;
      const rewards = rankRewardsFor(nextXp.xp, ownedAfterPrize ?? inventoryOwned(privateData), config, nowMs);
      const nextOwned = rewards.added.length > 0 ? rewards.owned : ownedAfterPrize;
      writePrivate(tx, privateRef, privateData, {
        spinWheel: plan.next,
        ...(plan.free ? questsAfter(privateData, "pro_spin", nowMs, true, config) : {}),
        ...(nextOwned ? {inventory: {...rawInventory, owned: nextOwned}} : {}),
      });
      const reply: SpinWheelReply = {
        success: true,
        changed: true,
        previousBalance: balance,
        currentBalance: current,
        delta,
        reason: "spin_wheel",
        transactionId: txId,
        insufficientBalance: false,
        status: wheelStatus({...dayInput, wheelState: plan.next}),
        cost: plan.cost,
        free: plan.free,
        segment,
        prize,
        segments,
      };
      writeTx(tx, {
        userId: callerUid,
        delta,
        previous: balance,
        action: "spinWheel",
        sourceTag,
        reason: "spin_wheel",
        description: `Wheel spin (${delta >= 0 ? "+" : ""}${delta})`,
        fixedId: txId,
        extra: {cost: plan.cost, free: plan.free, segment, prize, replay: reply},
      });
      return reply;
    });
  },
);

export const spendCoins = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<Record<string, unknown>>) => {
  const callerUid = uid(request);
  const action = requiredText(request.data?.action, "action");
  const sourceTag = requiredText(request.data?.sourceTag, "sourceTag");
  const reason = optionalReason(request.data?.reason, action);
  const label = optionalLabel(request.data?.label);
  const rawRequestId = request.data?.requestId;
  if (rawRequestId != null && !isValidRequestId(rawRequestId)) {
    throw new HttpsError("invalid-argument", "requestId is invalid.");
  }
  const styleId = action === "liveWallpaperStyle" ? request.data?.styleId : undefined;
  if (action === "liveWallpaperStyle" && (typeof styleId !== "string" || !STYLE_ID_PATTERN.test(styleId))) {
    throw new HttpsError("invalid-argument", "styleId is invalid.");
  }
  const config = await loadEconomy();
  const nowMs = Date.now();
  const {basePrice, qualityTier} = spendBasePrice(action, request.data, config, nowMs);
  const pricingV2 = isPricingV2(request.data);
  const bypassRequested = request.data?.allowPremiumBypass === true && config.proBypassActions.includes(action);
  const requestId = rawRequestId ?? null;
  const userRef = db.collection(USERS).doc(callerUid);
  const privateRef = privateEconomyRef(callerUid);
  const spendTxRef = requestId ? db.collection(TRANSACTIONS).doc(`spend_${callerUid}_${requestId}`) : null;
  let response: {
    success: boolean;
    changed: boolean;
    previousBalance: number;
    currentBalance: number;
    delta: number;
    bypassed: boolean;
    insufficientBalance: boolean;
    reason: string;
    transactionId: string;
    graceDownloadsLeft?: number;
    passUntil?: number;
    styleId?: string;
    qualityTier?: AiTier;
    basePrice?: number;
  } = {
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
  const initialResponse = {...response};
  const actionFields = {
    ...(qualityTier ? {qualityTier, basePrice} : {}),
    ...(typeof styleId === "string" ? {styleId} : {}),
  };

  await db.runTransaction(async (tx) => {
    response = {...initialResponse};
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const spendTxSnap = spendTxRef ? await tx.get(spendTxRef) : null;
    const privateSnap = await tx.get(privateRef);
    const data = snap.data() ?? {};
    const privateData = privateSnap.data() ?? {};
    const passes = coinState(privateData.passes);
    const liveStyles = coinState(passes.liveStyles);
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const free = (fields: {reason: string; graceDownloadsLeft?: number; passUntil?: number}) => {
      const replay = {...actionFields, ...fields};
      response = {...response, ...replay, success: true, bypassed: true, previousBalance: previous, currentBalance: previous};
      // A zero-delta receipt so a retried request replays the bypass instead of using grace or a pass again.
      if (spendTxRef) {
        writeTx(tx, {
          userId: callerUid,
          delta: 0,
          previous,
          action,
          sourceTag,
          reason: fields.reason,
          description: label,
          fixedId: spendTxRef.id,
          extra: {...actionFields, bypassed: true, replay},
        });
      }
    };
    if (spendTxSnap?.exists) {
      const original = spendTxSnap.data() ?? {};
      if (original.status !== "completed") {
        response = {
          ...response,
          previousBalance: previous,
          currentBalance: previous,
          reason: "spend_refunded",
          transactionId: spendTxRef?.id ?? "",
        };
      } else if (original.bypassed === true) {
        response = {
          ...response,
          ...coinState(original.replay),
          success: true,
          bypassed: true,
          previousBalance: previous,
          currentBalance: previous,
        };
      } else {
        response = duplicateSpendResponse(response, original, previous, reason);
      }
      return;
    }
    if (data.premium === true && bypassRequested) {
      free({reason: `${action}_premium_bypass`});
      return;
    }
    if (PREMIUM_PASS_ACTIONS.has(action) && int(passes.premiumPassUntil, 0) > nowMs) {
      free({reason: `${action}_pass_bypass`});
      return;
    }
    if (typeof styleId === "string" && int(liveStyles[styleId], 0) > nowMs) {
      free({reason: "liveWallpaperStyle_already_unlocked", passUntil: int(liveStyles[styleId], 0)});
      return;
    }
    const graceUsed = Math.max(0, int(privateData.graceDownloadsUsed, 0));
    if (pricingV2 && action === "wallpaperDownload" && graceUsed < config.award.graceDownloads) {
      writePrivate(tx, privateRef, privateData, {graceDownloadsUsed: graceUsed + 1});
      free({reason: "grace_download", graceDownloadsLeft: config.award.graceDownloads - graceUsed - 1});
      return;
    }
    const cost = config.proDiscountActions.includes(action) ? proPrice(basePrice, data.premium === true) : basePrice;
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
    let passUntil: number | undefined;
    if (action === "autoRotatePass7d") {
      passUntil = Math.max(nowMs, int(passes.autoRotatePassUntil, 0)) + PASS_MS;
      writePrivate(tx, privateRef, privateData, {passes: {...passes, autoRotatePassUntil: passUntil}});
    }
    if (typeof styleId === "string") {
      passUntil = nowMs + PASS_MS;
      writePrivate(tx, privateRef, privateData, {passes: {...passes, liveStyles: {...liveStyles, [styleId]: passUntil}}});
    }
    const passReply = passUntil === undefined ? {} : {passUntil};
    const replay = {...actionFields, ...passReply};
    if (cost <= 0) {
      free({reason: `${action}_free`, ...passReply});
      return;
    }
    const current = previous - cost;
    tx.update(userRef, {coins: current});
    const txId = writeTx(tx, {
      userId: callerUid,
      delta: -cost,
      previous,
      action,
      sourceTag,
      reason,
      description: label,
      fixedId: spendTxRef?.id,
      extra: {...actionFields, replay},
    });
    response = {
      ...response,
      ...replay,
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
  const inviterUid = requiredDocumentId(request.data?.inviterUserId, "inviterUserId");
  if (callerUid === inviterUid) throw new HttpsError("invalid-argument", "You cannot refer yourself.");
  let callerAuth: admin.auth.UserRecord;
  let inviterAuth: admin.auth.UserRecord;
  try {
    [callerAuth, inviterAuth] = await Promise.all([
      admin.auth().getUser(callerUid),
      admin.auth().getUser(inviterUid),
    ]);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Referral user was not found.");
    }
    throw error;
  }
  const award = (await loadEconomy()).award;
  const reward = award.referral;
  const caps = {maxPerDay: award.referralMaxPerDay, maxLifetime: award.referralMaxLifetime};
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
  const initialResult = {...result};
  await db.runTransaction(async (tx) => {
    result = {...initialResult};
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
    let stats = statsSnap.data() ?? {};
    if (!statsSnap.exists) {
      const history = await tx.get(db.collection(TRANSACTIONS)
        .where("userId", "==", inviterUid)
        .where("action", "==", "referral")
        .where("reason", "==", "inviter_reward")
        .limit(caps.maxLifetime));
      stats = {
        day: today,
        count: history.docs.filter((entry) => {
          const createdAtMs = parseCreatedAtMs(entry.data().createdAt);
          return createdAtMs != null && utcDateString(new Date(createdAtMs)) === today;
        }).length,
        total: history.size,
      };
    }
    const skipReason = referralSkipReason(
      callerAuth.metadata.creationTime, inviterAuth.metadata.creationTime, stats, today, nowMs, caps);
    if (skipReason) {
      // Permanent skips mark the referral processed so old clients stop retrying it on every launch.
      if (!statsSnap.exists) tx.set(statsRef, stats);
      if (skipReason !== "referral_inviter_daily_limit") {
        state.referralRewarded = true;
        tx.update(callerRef, {coinState: state});
      }
      result = {...result, previousBalance: previous, currentBalance: previous, reason: skipReason};
      return;
    }
    tx.set(statsRef, {
      day: today,
      count: (stats.day === today && typeof stats.count === "number" ? stats.count : 0) + 1,
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

type PreviewRequest = {collectionKey?: unknown; pricingVersion?: unknown};

export const unlockPremiumPreview = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<PreviewRequest>) => {
  const callerUid = uid(request);
  const key = requiredText(request.data?.collectionKey, "collectionKey").toLowerCase();
  if (/^__.*__$/.test(key)) throw new HttpsError("invalid-argument", "Invalid collection key.");
  const nowMs = Date.now();
  const cost = spendBasePrice("premiumPreview24h", request.data, await loadEconomy(), nowMs).basePrice;
  const userRef = db.collection(USERS).doc(callerUid);
  const privateRef = privateEconomyRef(callerUid);
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
    const privateSnap = await tx.get(privateRef);
    const data = snap.data() ?? {};
    const previous = typeof data.coins === "number" ? Math.trunc(data.coins) : 0;
    const state = coinState(data.coinState);
    const passActive = int(coinState(privateSnap.data()?.passes).premiumPassUntil, 0) > nowMs;
    const unlocks = Object.create(null) as Record<string, number>;
    const rawUnlocks = state.premiumPreviewUnlocks;
    if (rawUnlocks && typeof rawUnlocks === "object") {
      for (const [k, v] of Object.entries(rawUnlocks as Record<string, unknown>)) {
        if (typeof v === "number" && v > nowMs) unlocks[k.trim().toLowerCase()] = v;
      }
    }
    const current = {previousBalance: previous, currentBalance: previous};
    if (Object.prototype.hasOwnProperty.call(unlocks, key)) {
      response = {...response, ...current, success: true, reason: "premium_preview_already_unlocked", expiresAt: unlocks[key]};
      return;
    }
    const bypassReason = data.premium === true ? "premiumPreview24h_premium_bypass" :
      passActive ? "premiumPreview24h_pass_bypass" :
        cost <= 0 ? "premiumPreview24h_free" : null;
    if (!bypassReason && previous < cost) {
      response = {...response, ...current, insufficientBalance: true, reason: "premiumPreview24h_insufficient_balance"};
      return;
    }
    unlocks[key] = nowMs + PREVIEW_ACCESS_MS;
    if (bypassReason) {
      tx.update(userRef, {"coinState.premiumPreviewUnlocks": unlocks});
      response = {...response, ...current, success: true, bypassed: true, reason: bypassReason, expiresAt: unlocks[key]};
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
export function planFreezePurchase(balance: number, freezes: number, cost = STREAK_FREEZE_COST): FreezePurchasePlan {
  if (freezes >= MAX_STREAK_FREEZES) return {atCap: true};
  if (balance < cost) return {insufficientBalance: true};
  return {current: balance - cost, freezes: freezes + 1};
}

export const buyStreakFreeze = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<{requestId?: unknown}>) => {
  const callerUid = uid(request);
  const requestId = request.data?.requestId;
  if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  const userRef = db.collection(USERS).doc(callerUid);
  const cost = (await loadEconomy()).spend.streakFreeze;
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
    const plan = planFreezePurchase(previous, freezes, cost);
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
      delta: -cost,
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
      delta: -cost,
      streakFreezes: plan.freezes,
      transactionId: txId,
    };
  });
  return response;
});

type StreakRescueRefusal = "streak_rescue_unavailable" | "streak_rescue_expired" | "streak_rescue_too_short" |
  "streak_rescue_not_needed" | "streak_rescue_cooldown";

/** Why a streak cannot be bought back right now, or null when it can. Premium never changes the rules. */
function streakRescueRefusal(
  rescue: unknown,
  currentCount: number,
  lastRescueAtMs: unknown,
  nowMs: number,
): StreakRescueRefusal | null {
  if (!rescue || typeof rescue !== "object") return "streak_rescue_unavailable";
  const {count, expiresAtMs} = rescue as {count?: unknown; expiresAtMs?: unknown};
  if (typeof count !== "number" || !Number.isFinite(count) || typeof expiresAtMs !== "number") {
    return "streak_rescue_unavailable";
  }
  if (nowMs > expiresAtMs) return "streak_rescue_expired";
  if (count < STREAK_RESCUE_MIN_COUNT) return "streak_rescue_too_short";
  if (currentCount > count) return "streak_rescue_not_needed";
  if (typeof lastRescueAtMs === "number" && nowMs - lastRescueAtMs < STREAK_RESCUE_COOLDOWN_MS) {
    return "streak_rescue_cooldown";
  }
  return null;
}

export const restoreStreak = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<{requestId?: unknown}>) => {
  const callerUid = uid(request);
  const requestId = request.data?.requestId;
  if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
  const userRef = db.collection(USERS).doc(callerUid);
  const cost = (await loadEconomy()).spend.streakRescue;
  const txId = `ctx_streakRescue_${callerUid}_${requestId}`;
  const txRef = db.collection(TRANSACTIONS).doc(txId);
  const nowMs = Date.now();
  const emptyResponse = {
    success: false,
    changed: false,
    previousBalance: 0,
    currentBalance: 0,
    delta: 0,
    streakCount: 0,
    insufficientBalance: false,
    reason: "streak_rescue",
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
    const state = coinState(data.coinState);
    const rawCount = Number(state.streakCount);
    const currentCount = Number.isFinite(rawCount) ? Math.max(0, Math.trunc(rawCount)) : 0;
    const current = {previousBalance: previous, currentBalance: previous, streakCount: currentCount};
    if (txSnap.exists) {
      response = {...response, ...current, success: true, reason: "duplicate", transactionId: txId};
      return;
    }
    const refusal = streakRescueRefusal(state.rescue, currentCount, state.rescueLastAt, nowMs);
    if (refusal) {
      response = {...response, ...current, reason: refusal};
      return;
    }
    if (previous < cost) {
      response = {...response, ...current, insufficientBalance: true, reason: "streak_rescue_insufficient_balance"};
      return;
    }
    const restored = Math.trunc((state.rescue as {count: number}).count) + 1;
    const rawBest = Number(state.streakBest);
    const best = Math.max(Number.isFinite(rawBest) ? Math.trunc(rawBest) : 0, restored);
    const balance = previous - cost;
    tx.update(userRef, {
      "coins": balance,
      "coinState.streakCount": restored,
      "coinState.streakDay": streakCycleDay(restored),
      "coinState.streakBest": best,
      "coinState.rescue": admin.firestore.FieldValue.delete(),
      "coinState.rescueLastAt": nowMs,
    });
    tx.set(txRef, coinTransactionDoc({
      id: txId,
      userId: callerUid,
      at: admin.firestore.Timestamp.now(),
      delta: -cost,
      balanceBefore: previous,
      action: "streakRescue",
      description: "Streak rescue",
      sourceTag: "coins.restore_streak.callable",
      reason: "streak_rescue",
    }));
    response = {
      ...response,
      success: true,
      changed: true,
      previousBalance: previous,
      currentBalance: balance,
      delta: -cost,
      streakCount: restored,
      transactionId: txId,
    };
  });
  return response;
});
