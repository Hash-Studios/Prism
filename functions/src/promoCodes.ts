import * as admin from "firebase-admin";
import {createHash, randomBytes} from "node:crypto";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";
import {isAdminCaller} from "./adminConfig";
import {isValidRequestId} from "./coinsCallables";
import {CALLABLE_REGIONS, coinTransactionDoc, db, int, str} from "./common";

// The uppercase half of the short-link alphabet in infra/cloudflare/worker/src/index.ts: no I, O, 0 or 1, so a code
// read aloud or off a screenshot has one spelling. Lowercase input is uppercased first.
export const PROMO_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_PATTERN = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{10,32}$/;
export const GENERATED_CODE_LENGTH = 10;

const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;
export const ATTEMPTS_PER_USER_HOUR = 10;
// Only misses add to the IP counter. Once it reaches 30, new attempts from that IP are refused for the hour.
export const MISSES_PER_IP_HOUR = 30;
const MAX_COINS = 1_000;
const MAX_DAYS = 90;
const MAX_REDEMPTIONS = 100_000;
const MAX_AGE_RULE_DAYS = 365;
const MAX_LIFETIME_MS = 366 * DAY_MS;

const CODES = "promoCodes";
const RATES = "promoRedeemRate";
const CALLABLE_OPTIONS = {region: CALLABLE_REGIONS, cors: true, maxInstances: 10};

export type PromoReward = {type: "coins"; coins: number} | {type: "premiumDays"; days: number};

export type RedeemFailure =
  | "invalid_code"
  | "not_found"
  | "disabled"
  | "expired"
  | "limit_reached"
  | "already_redeemed"
  | "account_too_new"
  | "new_users_only"
  | "premium_not_on_ios"
  | "already_premium"
  | "rate_limited"
  | "busy";

export type RedeemResponse =
  | {ok: true; reward: PromoReward; coinBalance?: number; premiumUntil?: number; replayed: boolean}
  | {ok: false; reason: RedeemFailure};

interface PromoCode {
  code: string;
  reward: PromoReward;
  maxRedemptions: number;
  redemptionCount: number;
  expiresAtMs: number;
  minAccountAgeDays: number;
  newUsersOnlyDays: number | null;
  disabled: boolean;
}

/** Overridable in tests. */
export const promoIo = {
  async accountCreatedMs(uid: string): Promise<number> {
    return Date.parse((await admin.auth().getUser(uid)).metadata.creationTime);
  },
};

export function normalizePromoCode(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.length > 64) return null;
  const code = raw.toUpperCase().replace(/[\s-]/g, "");
  return CODE_PATTERN.test(code) ? code : null;
}

// The doc id never holds the code itself, so ledger ids, document paths and logs cannot reveal it.
export function promoCodeId(code: string): string {
  return createHash("sha256").update(code).digest("hex").slice(0, 32);
}

export function generatePromoCode(random: (size: number) => Uint8Array = randomBytes): string {
  // 256 is a multiple of 32, so the modulo keeps every character equally likely.
  return Array.from(random(GENERATED_CODE_LENGTH), (byte) => PROMO_ALPHABET[byte % PROMO_ALPHABET.length]).join("");
}

function isIntIn(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;
}

function parseReward(raw: unknown): PromoReward | null {
  const reward = (raw ?? {}) as Record<string, unknown>;
  if (reward.type === "coins" && isIntIn(reward.coins, 1, MAX_COINS)) return {type: "coins", coins: reward.coins};
  if (reward.type === "premiumDays" && isIntIn(reward.days, 1, MAX_DAYS)) return {type: "premiumDays", days: reward.days};
  return null;
}

function parseStoredCode(data: admin.firestore.DocumentData | undefined): PromoCode | null {
  const reward = parseReward(data?.reward);
  const expiresAt = data?.expiresAt;
  if (!data || !reward || !(expiresAt instanceof admin.firestore.Timestamp)) return null;
  return {
    code: str(data.code),
    reward,
    maxRedemptions: int(data.maxRedemptions, 0),
    redemptionCount: int(data.redemptionCount, 0),
    expiresAtMs: expiresAt.toMillis(),
    minAccountAgeDays: int(data.minAccountAgeDays, 0),
    newUsersOnlyDays: typeof data.newUsersOnlyDays === "number" ? int(data.newUsersOnlyDays, 0) : null,
    disabled: data.disabled === true,
  };
}

/** The limits that do not depend on the caller, in the order the user should hear about them. */
function codeFailure(code: PromoCode, nowMs: number): RedeemFailure | null {
  if (code.disabled) return "disabled";
  if (code.expiresAtMs <= nowMs) return "expired";
  if (code.redemptionCount >= code.maxRedemptions) return "limit_reached";
  return null;
}

function ageFailure(code: PromoCode, createdMs: number, nowMs: number): RedeemFailure | null {
  const ageMs = nowMs - createdMs;
  if (ageMs < code.minAccountAgeDays * DAY_MS) return "account_too_new";
  if (code.newUsersOnlyDays !== null && ageMs > code.newUsersOnlyDays * DAY_MS) return "new_users_only";
  return null;
}

function replayOf(data: admin.firestore.DocumentData, requestId: string, platform: "ios" | "android"): RedeemResponse {
  const reward = parseReward(data.reward);
  if (data.requestId !== requestId || !reward) return {ok: false, reason: "already_redeemed"};
  if (platform === "ios" && reward.type === "premiumDays") return {ok: false, reason: "premium_not_on_ios"};
  return {
    ok: true,
    reward,
    ...(typeof data.coinBalance === "number" ? {coinBalance: data.coinBalance} : {}),
    ...(typeof data.premiumUntil === "number" ? {premiumUntil: data.premiumUntil} : {}),
    replayed: true,
  };
}

/** Uses the final forwarded hop. Its trustworthiness depends on the deployed proxy chain. */
export function clientIp(rawRequest: {headers?: Record<string, unknown>; ip?: unknown} | undefined): string {
  const header = rawRequest?.headers?.["x-forwarded-for"];
  const hops = (Array.isArray(header) ? header.join(",") : str(header)).split(",").map((hop) => hop.trim());
  return hops.filter(Boolean).at(-1) ?? str(rawRequest?.ip);
}

function rateRefs(uid: string, ip: string, nowMs: number) {
  const bucket = Math.floor(nowMs / HOUR_MS);
  const ipKey = ip === "" ? null : createHash("sha256").update(`promo-ip\0${ip}`).digest("hex").slice(0, 32);
  return {
    expiresAt: admin.firestore.Timestamp.fromMillis((bucket + 2) * HOUR_MS),
    user: db.collection(RATES).doc(`u_${uid}_${bucket}`),
    ip: ipKey === null ? null : db.collection(RATES).doc(`ip_${ipKey}_${bucket}`),
  };
}

/** Counts this attempt for the user. False when the user's hourly limit is already exhausted. */
async function takeAttempt(refs: ReturnType<typeof rateRefs>): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(refs.user);
    const used = int(userSnap.data()?.count, 0);
    if (used >= ATTEMPTS_PER_USER_HOUR) return false;
    tx.set(refs.user, {count: used + 1, expiresAt: refs.expiresAt});
    return true;
  });
}

/** Checks the IP miss budget and looks up a code in one transaction, so parallel guesses cannot outrun the cap. */
async function lookupPromo(refs: ReturnType<typeof rateRefs>, codeRef: admin.firestore.DocumentReference | null):
  Promise<{promo: PromoCode | null; failure: "invalid_code" | "not_found" | "rate_limited" | null}> {
  return db.runTransaction(async (tx) => {
    const ipSnap = refs.ip ? await tx.get(refs.ip) : null;
    const count = int(ipSnap?.data()?.count, 0);
    if (count >= MISSES_PER_IP_HOUR) return {promo: null, failure: "rate_limited"};
    const codeSnap = codeRef ? await tx.get(codeRef) : null;
    const promo = codeRef ? parseStoredCode(codeSnap?.data()) : null;
    if (!promo) {
      if (refs.ip) tx.set(refs.ip, {count: count + 1, expiresAt: refs.expiresAt});
      return {promo: null, failure: codeRef ? "not_found" : "invalid_code"};
    }
    return {promo, failure: null};
  });
}

function errorCode(err: unknown): unknown {
  return (err as {code?: unknown})?.code;
}

/** The transaction gave up after its retries, usually a burst on one document. Nothing was written. */
function isAborted(err: unknown): boolean {
  return errorCode(err) === 10 || errorCode(err) === "aborted";
}

async function promoAccountCreatedMs(uid: string): Promise<number> {
  try {
    const createdMs = await promoIo.accountCreatedMs(uid);
    if (!Number.isFinite(createdMs)) throw new Error("Invalid Auth creation time.");
    return createdMs;
  } catch (err) {
    if (errorCode(err) === "auth/user-not-found") {
      throw new HttpsError("not-found", "User profile was not found.");
    }
    logger.error("redeemCode: account lookup failed.", {err});
    throw new HttpsError("unavailable", "Try again in a moment.");
  }
}

/** Redeems a promo code for the signed-in user. Every refusal is a `reason`; retries with one requestId are safe. */
export const redeemCode = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<{code?: unknown; requestId?: unknown; platform?: unknown}>): Promise<RedeemResponse> => {
    const uid = str(request.auth?.uid);
    const token = request.auth?.token;
    if (!uid || token?.firebase?.sign_in_provider === "anonymous" || token?.email_verified !== true) {
      throw new HttpsError("unauthenticated", "Sign in to redeem a code.");
    }
    const requestId = request.data?.requestId;
    if (!isValidRequestId(requestId)) throw new HttpsError("invalid-argument", "requestId is invalid.");
    const platform = request.data?.platform;
    if (platform !== "ios" && platform !== "android") throw new HttpsError("invalid-argument", "platform is invalid.");

    const nowMs = Date.now();
    const code = normalizePromoCode(request.data?.code);
    const codeRef = code === null ? null : db.collection(CODES).doc(promoCodeId(code));
    const redemptionRef = codeRef?.collection("redemptions").doc(uid) ?? null;
    if (redemptionRef) {
      const earlier = await redemptionRef.get();
      if (earlier.exists) {
        await promoAccountCreatedMs(uid);
        const userRef = db.collection("usersv2").doc(uid);
        const deletionRef = db.collection("creatorDeletionState").doc(uid);
        try {
          return await db.runTransaction(async (tx) => {
            const [redemptionSnap, userSnap, deletionSnap] = await Promise.all([
              tx.get(redemptionRef), tx.get(userRef), tx.get(deletionRef),
            ]);
            const user = userSnap.data();
            if (!user || user.deleted === true || deletionSnap.exists) {
              throw new HttpsError("not-found", "User profile was not found.");
            }
            return replayOf(redemptionSnap.data() ?? {}, requestId, platform);
          });
        } catch (err) {
          if (isAborted(err)) return {ok: false, reason: "busy"};
          throw err;
        }
      }
    }

    const refs = rateRefs(uid, clientIp(request.rawRequest), nowMs);
    try {
      if (!await takeAttempt(refs)) return {ok: false, reason: "rate_limited"};
    } catch (err) {
      if (isAborted(err)) return {ok: false, reason: "busy"};
      throw err;
    }
    let lookup: Awaited<ReturnType<typeof lookupPromo>>;
    try {
      lookup = await lookupPromo(refs, codeRef);
    } catch (err) {
      if (isAborted(err)) return {ok: false, reason: "busy"};
      throw err;
    }
    if (lookup.failure) return {ok: false, reason: lookup.failure};
    const promo = lookup.promo as PromoCode;
    const codeDocRef = codeRef as admin.firestore.DocumentReference;
    const redemptionDocRef = redemptionRef as admin.firestore.DocumentReference;
    const createdMs = await promoAccountCreatedMs(uid);

    const userRef = db.collection("usersv2").doc(uid);
    const privateRef = userRef.collection("private").doc("economy");
    const ledgerRef = db.collection("coinTransactions").doc(`ctx_promo_${codeDocRef.id}_${uid}`);
    const deletionRef = db.collection("creatorDeletionState").doc(uid);
    try {
      return await db.runTransaction(async (tx): Promise<RedeemResponse> => {
        const [codeSnap, redemptionSnap, userSnap, deletionSnap, privateSnap] = await Promise.all([
          tx.get(codeDocRef),
          tx.get(redemptionDocRef),
          tx.get(userRef),
          tx.get(deletionRef),
          promo.reward.type === "premiumDays" ? tx.get(privateRef) : null,
        ]);
        const user = userSnap.data();
        if (!user || user.deleted === true || deletionSnap.exists) {
          throw new HttpsError("not-found", "User profile was not found.");
        }
        if (redemptionSnap.exists) return replayOf(redemptionSnap.data() ?? {}, requestId, platform);
        const current = parseStoredCode(codeSnap.data());
        if (!current) return {ok: false, reason: "not_found"};
        const late = codeFailure(current, nowMs);
        if (late) return {ok: false, reason: late};
        const reward = current.reward;
        // Apple App Review 3.1.1: Pro access on iOS goes through In-App Purchase and App Store offer codes only.
        if (reward.type === "premiumDays" && platform === "ios") return {ok: false, reason: "premium_not_on_ios"};
        if (current.minAccountAgeDays > 0 || current.newUsersOnlyDays !== null) {
          const tooYoungOrOld = ageFailure(current, createdMs, nowMs);
          if (tooYoungOrOld) return {ok: false, reason: tooYoungOrOld};
        }
        if (reward.type === "premiumDays" && user.premium === true) return {ok: false, reason: "already_premium"};

        const at = admin.firestore.Timestamp.fromMillis(nowMs);
        let grant: {coinBalance: number; transactionId: string} | {premiumUntil: number};
        if (reward.type === "coins") {
          const previous = int(user.coins, 0);
          tx.update(userRef, {coins: previous + reward.coins});
          tx.create(ledgerRef, coinTransactionDoc({
            id: ledgerRef.id,
            userId: uid,
            at,
            delta: reward.coins,
            balanceBefore: previous,
            action: "promoCode",
            description: "Promo code",
            sourceTag: "promoCodes.redeem.callable",
            reason: "promo_code",
          }));
          grant = {coinBalance: previous + reward.coins, transactionId: ledgerRef.id};
        } else {
          const economy = privateSnap?.data() ?? {};
          const passes = typeof economy.passes === "object" && economy.passes !== null ? economy.passes : {};
          // Extends from the later of now and the current end, so a promo never shortens a longer pass.
          const premiumUntil = Math.max(nowMs, int(passes.premiumPassUntil, 0)) + reward.days * DAY_MS;
          tx.set(privateRef, {rev: int(economy.rev, 0) + 1, passes: {...passes, premiumPassUntil: premiumUntil}}, {merge: true});
          grant = {premiumUntil};
        }
        tx.update(codeDocRef, {redemptionCount: current.redemptionCount + 1, lastRedeemedAt: at});
        tx.create(redemptionDocRef, {uid, requestId, reward, platform, redeemedAt: at, ...grant});
        return {
          ok: true,
          reward,
          ...("coinBalance" in grant ? {coinBalance: grant.coinBalance} : {premiumUntil: grant.premiumUntil}),
          replayed: false,
        };
      });
    } catch (err) {
      // Two calls from one user raced: the other one created the redemption first.
      if (errorCode(err) === 6 || errorCode(err) === "already-exists") {
        try {
          return await db.runTransaction(async (tx) => {
            const [redemptionSnap, userSnap, deletionSnap] = await Promise.all([
              tx.get(redemptionDocRef), tx.get(userRef), tx.get(deletionRef),
            ]);
            const user = userSnap.data();
            if (!user || user.deleted === true || deletionSnap.exists) {
              throw new HttpsError("not-found", "User profile was not found.");
            }
            return replayOf(redemptionSnap.data() ?? {}, requestId, platform);
          });
        } catch (replayErr) {
          if (isAborted(replayErr)) return {ok: false, reason: "busy"};
          throw replayErr;
        }
      }
      if (isAborted(err)) return {ok: false, reason: "busy"};
      throw err;
    }
  },
);

export interface PromoCodeInput {
  code: string | null;
  reward: PromoReward;
  maxRedemptions: number;
  expiresAtMs: number;
  minAccountAgeDays: number;
  newUsersOnlyDays: number | null;
  label: string;
}

/** Validates an admin's create request. Throws `invalid-argument` naming the first bad field. */
export function parsePromoCodeInput(raw: unknown, nowMs: number): PromoCodeInput {
  const data = (raw ?? {}) as Record<string, unknown>;
  const bad = (field: string): never => {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  };
  let code: string | null = null;
  if (data.code !== undefined && data.code !== null && data.code !== "") {
    code = normalizePromoCode(data.code) ?? bad("code");
  }
  const amount = data.amount;
  const reward = parseReward(data.type === "coins" ? {type: "coins", coins: amount} : {type: data.type, days: amount});
  if (!reward) bad("amount");
  if (!isIntIn(data.maxRedemptions, 1, MAX_REDEMPTIONS)) bad("maxRedemptions");
  const expiresAtMs = data.expiresAtMs;
  if (typeof expiresAtMs !== "number" || !Number.isInteger(expiresAtMs) || expiresAtMs <= nowMs ||
    expiresAtMs > nowMs + MAX_LIFETIME_MS) {
    bad("expiresAtMs");
  }
  const minAccountAgeDays = data.minAccountAgeDays ?? 0;
  if (!isIntIn(minAccountAgeDays, 0, MAX_AGE_RULE_DAYS)) bad("minAccountAgeDays");
  const newUsersOnlyDays = data.newUsersOnlyDays ?? null;
  if (newUsersOnlyDays !== null && !isIntIn(newUsersOnlyDays, 1, MAX_AGE_RULE_DAYS)) bad("newUsersOnlyDays");
  if (newUsersOnlyDays !== null && (newUsersOnlyDays as number) <= (minAccountAgeDays as number)) bad("newUsersOnlyDays");
  if (data.label !== undefined && typeof data.label !== "string") bad("label");
  return {
    code,
    reward: reward as PromoReward,
    maxRedemptions: data.maxRedemptions as number,
    expiresAtMs: expiresAtMs as number,
    minAccountAgeDays: minAccountAgeDays as number,
    newUsersOnlyDays: newUsersOnlyDays as number | null,
    label: str(data.label).trim().slice(0, 80),
  };
}

/**
 * Writes one code. A generated code is redrawn on the rare collision; a chosen code that exists is refused.
 * Returns the code that was stored.
 */
export async function writePromoCode(input: PromoCodeInput, createdBy: string, nowMs: number): Promise<string> {
  for (let attempt = 0; attempt < 3; attempt++) {
    const code = input.code ?? generatePromoCode();
    try {
      await db.collection(CODES).doc(promoCodeId(code)).create({
        code,
        reward: input.reward,
        maxRedemptions: input.maxRedemptions,
        redemptionCount: 0,
        expiresAt: admin.firestore.Timestamp.fromMillis(input.expiresAtMs),
        minAccountAgeDays: input.minAccountAgeDays,
        newUsersOnlyDays: input.newUsersOnlyDays,
        disabled: false,
        label: input.label,
        createdBy,
        createdAt: admin.firestore.Timestamp.fromMillis(nowMs),
      });
      return code;
    } catch (err) {
      const exists = errorCode(err) === 6 || errorCode(err) === "already-exists";
      if (!exists) throw err;
      if (input.code !== null) throw new HttpsError("already-exists", "That code already exists.");
    }
  }
  throw new HttpsError("aborted", "Could not draw a free code. Try again.");
}

async function requireAdmin(request: CallableRequest<unknown>): Promise<string> {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!await isAdminCaller(request.auth)) throw new HttpsError("permission-denied", "Admins only.");
  return str(request.auth.token?.email) || request.auth.uid;
}

/** Admin only. Creates one promo code; codes and their counts are never readable by clients. */
export const createPromoCode = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<unknown>) => {
  const createdBy = await requireAdmin(request);
  const nowMs = Date.now();
  const code = await writePromoCode(parsePromoCodeInput(request.data, nowMs), createdBy, nowMs);
  return {code};
});

/** Admin only. The 50 newest codes with their redemption counts. */
export const listPromoCodes = onCall(CALLABLE_OPTIONS, async (request: CallableRequest<unknown>) => {
  await requireAdmin(request);
  const snap = await db.collection(CODES).orderBy("createdAt", "desc").limit(50).get();
  return {
    codes: snap.docs.flatMap((doc) => {
      const promo = parseStoredCode(doc.data());
      if (!promo) return [];
      const createdAt = doc.data().createdAt;
      return [{
        code: promo.code,
        label: str(doc.data().label),
        reward: promo.reward,
        maxRedemptions: promo.maxRedemptions,
        redemptionCount: promo.redemptionCount,
        expiresAtMs: promo.expiresAtMs,
        minAccountAgeDays: promo.minAccountAgeDays,
        newUsersOnlyDays: promo.newUsersOnlyDays,
        disabled: promo.disabled,
        createdAtMs: createdAt instanceof admin.firestore.Timestamp ? createdAt.toMillis() : 0,
      }];
    }),
  };
});

/** Admin only. Turns a leaked or finished code off, or back on. */
export const setPromoCodeDisabled = onCall(
  CALLABLE_OPTIONS,
  async (request: CallableRequest<{code?: unknown; disabled?: unknown}>) => {
    await requireAdmin(request);
    const code = normalizePromoCode(request.data?.code);
    if (code === null) throw new HttpsError("invalid-argument", "code is invalid.");
    if (typeof request.data?.disabled !== "boolean") throw new HttpsError("invalid-argument", "disabled is invalid.");
    try {
      await db.collection(CODES).doc(promoCodeId(code)).update({disabled: request.data.disabled});
    } catch (err) {
      if (errorCode(err) === 5 || errorCode(err) === "not-found") throw new HttpsError("not-found", "No such code.");
      throw err;
    }
    return {code, disabled: request.data.disabled};
  },
);
