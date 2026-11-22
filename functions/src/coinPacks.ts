import * as admin from "firebase-admin";
import {timingSafeEqual} from "node:crypto";
import {defineBoolean, defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall, onRequest, type CallableRequest} from "firebase-functions/v2/https";
import {coinTransactionDoc, db, US_REGION} from "./common";
import {type CoinPackDef, loadEconomy} from "./economy";

const USERS = "usersv2";
const TRANSACTIONS = "coinTransactions";
const RECEIPTS = "coinPackReceipts";
const THROTTLE = "coinPackVerifyThrottle";
const THROTTLE_WINDOW_MS = 10 * 60_000;
const THROTTLE_MAX_CALLS = 20;
const TRANSACTION_ID = /^[A-Za-z0-9._:-]{1,128}$/;
const ANONYMOUS_RC_ID = "$RCAnonymousID:";
const REAL_STORES = new Set(["app_store", "play_store"]);
const SANDBOX_STORES = new Set(["test_store"]);

const revenueCatSecret = defineSecret("REVENUECAT_SECRET_KEY");
const webhookAuth = defineSecret("REVENUECAT_WEBHOOK_AUTH");
const allowSandbox = defineBoolean("COIN_PACKS_ALLOW_SANDBOX", {default: false});

/** One store transaction as RevenueCat's customer record lists it. */
export interface StorePurchase {
  transactionId: string;
  productId: string;
  store: string;
  sandbox: boolean;
}

export type RefuseReason = "unknown_product" | "store_not_allowed" | "sandbox_not_allowed" | "other_user";

export type GrantResult =
  | {status: "granted" | "already_granted"; coins: number; balance: number}
  | {status: "not_found"}
  | {status: "refused"; reason: RefuseReason}
  | {status: "revoked"};

export type RevokeResult = "revoked" | "tombstoned" | "unchanged";

type Doc = Record<string, unknown>;

/** RevenueCat's API base. The local emulator can point it at a fake RevenueCat for device proof. */
function revenueCatBase(): string {
  const override = process.env.REVENUECAT_API_BASE;
  return process.env.FUNCTIONS_EMULATOR === "true" && override ? override : "https://api.revenuecat.com";
}

/** Finds `transactionId` in a RevenueCat v1 customer record. Matches the store id, or RevenueCat's own id. */
export function findStorePurchase(json: unknown, transactionId: string): StorePurchase | null {
  const nonSubscriptions = (json as {subscriber?: {non_subscriptions?: unknown}})?.subscriber?.non_subscriptions;
  if (typeof nonSubscriptions !== "object" || nonSubscriptions === null) return null;
  for (const [productId, entries] of Object.entries(nonSubscriptions as Record<string, unknown>)) {
    if (!Array.isArray(entries)) continue;
    for (const entry of entries as Doc[]) {
      if (typeof entry !== "object" || entry === null) continue;
      const storeId = entry.store_transaction_id == null ? "" : String(entry.store_transaction_id);
      const rcId = entry.id == null ? "" : String(entry.id);
      if (storeId !== transactionId && rcId !== transactionId) continue;
      return {
        transactionId,
        productId,
        store: typeof entry.store === "string" ? entry.store : "",
        sandbox: entry.is_sandbox === true,
      };
    }
  }
  return null;
}

/** The coins a verified purchase earns, or why it earns none. Pure: no I/O. */
export function decideGrant(
  purchase: StorePurchase,
  packs: readonly CoinPackDef[],
  sandboxAllowed: boolean,
): {coins: number} | {reason: Exclude<RefuseReason, "other_user">} {
  const pack = packs.find((p) => p.productId === purchase.productId);
  if (!pack) return {reason: "unknown_product"};
  if (!REAL_STORES.has(purchase.store) && !(sandboxAllowed && SANDBOX_STORES.has(purchase.store))) {
    return {reason: "store_not_allowed"};
  }
  if (purchase.sandbox && !sandboxAllowed) return {reason: "sandbox_not_allowed"};
  return {coins: pack.coins};
}

async function readCustomer(uid: string): Promise<unknown> {
  let response: Response;
  try {
    response = await fetch(`${revenueCatBase()}/v1/subscribers/${encodeURIComponent(uid)}`, {
      headers: {Authorization: `Bearer ${revenueCatSecret.value()}`},
    });
  } catch {
    throw new HttpsError("unavailable", "RevenueCat request failed.");
  }
  if (!response.ok) throw new HttpsError("unavailable", `RevenueCat request failed (${response.status}).`);
  return response.json();
}

function balanceOf(user: Doc | undefined): number {
  return typeof user?.coins === "number" ? Math.trunc(user.coins) : 0;
}

/** Adds the pack's coins once per store transaction. Safe to run any number of times, in any order with revoke. */
export async function grantPurchase(
  uid: string,
  purchase: StorePurchase,
  coins: number,
  via: "callable" | "webhook",
): Promise<GrantResult> {
  const userRef = db.collection(USERS).doc(uid);
  const receiptRef = db.collection(RECEIPTS).doc(purchase.transactionId);
  const ledgerId = `ctx_coinpack_${purchase.transactionId}`;
  return db.runTransaction(async (tx): Promise<GrantResult> => {
    const [userSnap, receiptSnap] = await tx.getAll(userRef, receiptRef);
    if (!userSnap.exists) throw new HttpsError("not-found", "User profile was not found.");
    const balance = balanceOf(userSnap.data());
    const receipt = receiptSnap.data();
    if (receipt) {
      if (receipt.state === "revoked") return {status: "revoked"};
      if (receipt.userId !== uid) return {status: "refused", reason: "other_user"};
      return {status: "already_granted", coins: Number(receipt.coins) || 0, balance};
    }
    const now = admin.firestore.Timestamp.now();
    const environment = purchase.sandbox ? "sandbox" : "production";
    tx.update(userRef, {coins: balance + coins});
    tx.set(receiptRef, {
      state: "granted",
      userId: uid,
      productId: purchase.productId,
      coins,
      store: purchase.store,
      environment,
      grantedVia: via,
      grantedAt: now,
    });
    tx.set(db.collection(TRANSACTIONS).doc(ledgerId), {
      ...coinTransactionDoc({
        id: ledgerId,
        userId: uid,
        at: now,
        delta: coins,
        balanceBefore: balance,
        action: "coinPack",
        description: "Coin pack",
        sourceTag: `coins.coin_pack.${via}`,
        reason: "coin_pack_purchase",
      }),
      source: "purchase",
      productId: purchase.productId,
      store: purchase.store,
      environment,
      storeTransactionId: purchase.transactionId,
    });
    return {status: "granted", coins, balance: balance + coins};
  });
}

/**
 * Takes a refunded pack back from the user its receipt names. The balance may go negative (see the doc). A refund that
 * arrives before any grant leaves a tombstone, so that transaction can never be granted later.
 */
export async function revokePurchase(transactionId: string, productId: string): Promise<RevokeResult> {
  const receiptRef = db.collection(RECEIPTS).doc(transactionId);
  return db.runTransaction(async (tx): Promise<RevokeResult> => {
    const receipt = (await tx.get(receiptRef)).data();
    const now = admin.firestore.Timestamp.now();
    if (!receipt) {
      tx.set(receiptRef, {state: "revoked", productId, coins: 0, revokedAt: now});
      return "tombstoned";
    }
    if (receipt.state !== "granted") return "unchanged";
    const uid = String(receipt.userId);
    const coins = Number(receipt.coins) || 0;
    const userRef = db.collection(USERS).doc(uid);
    const userSnap = await tx.get(userRef);
    tx.update(receiptRef, {state: "revoked", revokedAt: now});
    if (!userSnap.exists) return "revoked";
    const balance = balanceOf(userSnap.data());
    const ledgerId = `ctx_coinpack_refund_${transactionId}`;
    tx.update(userRef, {coins: balance - coins});
    tx.set(db.collection(TRANSACTIONS).doc(ledgerId), {
      ...coinTransactionDoc({
        id: ledgerId,
        userId: uid,
        at: now,
        delta: -coins,
        balanceBefore: balance,
        action: "coinPackRefund",
        description: "Coin pack refund",
        sourceTag: "coins.coin_pack.refund",
        reason: "coin_pack_refund",
      }),
      source: "purchase",
      productId: receipt.productId,
      storeTransactionId: transactionId,
    });
    return "revoked";
  });
}

/** Reads RevenueCat for `uid`, then grants once if the purchase is real and allowed. */
export async function verifyAndGrant(uid: string, transactionId: string, via: "callable" | "webhook"): Promise<GrantResult> {
  const purchase = findStorePurchase(await readCustomer(uid), transactionId);
  if (!purchase) return {status: "not_found"};
  const decision = decideGrant(purchase, (await loadEconomy()).coinPacks, allowSandbox.value());
  if ("reason" in decision) return {status: "refused", reason: decision.reason};
  return grantPurchase(uid, purchase, decision.coins, via);
}

async function claimVerifyCall(uid: string, nowMs: number): Promise<boolean> {
  const ref = db.collection(THROTTLE).doc(uid);
  return db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    const start = typeof data?.windowStart === "number" ? data.windowStart : 0;
    const count = typeof data?.count === "number" ? data.count : 0;
    if (nowMs - start >= THROTTLE_WINDOW_MS) {
      tx.set(ref, {windowStart: nowMs, count: 1});
      return true;
    }
    if (count >= THROTTLE_MAX_CALLS) return false;
    tx.set(ref, {windowStart: start, count: count + 1});
    return true;
  });
}

export const verifyCoinPurchase = onCall(
  // The app calls us-central1 only (lib/core/constants/app_functions.dart), and asia-south1 has no CPU budget left.
  {region: US_REGION, cors: true, maxInstances: 2, secrets: [revenueCatSecret]},
  async (request: CallableRequest<{transactionId?: unknown}>) => {
    const uid = request.auth?.uid;
    if (!uid || request.auth?.token.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign in to buy coins.");
    }
    const transactionId = request.data?.transactionId;
    if (typeof transactionId !== "string" || !TRANSACTION_ID.test(transactionId)) {
      throw new HttpsError("invalid-argument", "transactionId is invalid.");
    }
    if (!(await db.collection(USERS).doc(uid).get()).exists) {
      throw new HttpsError("not-found", "User profile was not found.");
    }
    if (!await claimVerifyCall(uid, Date.now())) {
      throw new HttpsError("resource-exhausted", "Too many checks. Try again in a few minutes.");
    }
    return verifyAndGrant(uid, transactionId, "callable");
  },
);

interface WebhookEvent {
  type?: unknown;
  product_id?: unknown;
  transaction_id?: unknown;
  app_user_id?: unknown;
  original_app_user_id?: unknown;
  aliases?: unknown;
}

/** The first non-anonymous app user id on the event that has a Prism profile. */
async function webhookUser(event: WebhookEvent): Promise<string | null> {
  const candidates = [event.app_user_id, event.original_app_user_id, ...(Array.isArray(event.aliases) ? event.aliases : [])];
  const seen = new Set<string>();
  for (const candidate of candidates) {
    if (typeof candidate !== "string" || candidate === "" || candidate.startsWith(ANONYMOUS_RC_ID)) continue;
    if (candidate.includes("/") || seen.has(candidate)) continue;
    seen.add(candidate);
    if ((await db.collection(USERS).doc(candidate).get()).exists) return candidate;
  }
  return null;
}

export function webhookAuthorized(header: string | undefined, expected: string): boolean {
  const supplied = Buffer.from(header ?? "");
  const wanted = Buffer.from(expected);
  return wanted.length > 0 && supplied.length === wanted.length && timingSafeEqual(supplied, wanted);
}

/** What the webhook does with one event. Returns the HTTP status RevenueCat should see. */
export async function handleWebhookEvent(event: WebhookEvent): Promise<number> {
  const productId = typeof event.product_id === "string" ? event.product_id : "";
  const transactionId = typeof event.transaction_id === "string" ? event.transaction_id : "";
  const packs = (await loadEconomy()).coinPacks;
  if (!packs.some((p) => p.productId === productId) || !TRANSACTION_ID.test(transactionId)) return 200;
  if (event.type === "CANCELLATION" || event.type === "REFUND") {
    const result = await revokePurchase(transactionId, productId);
    logger.info("coinPacks: refund", {transactionId, result});
    return 200;
  }
  if (event.type !== "NON_RENEWING_PURCHASE") return 200;
  const uid = await webhookUser(event);
  if (!uid) {
    logger.warn("coinPacks: unknown_user", {transactionId});
    return 200;
  }
  const result = await verifyAndGrant(uid, transactionId, "webhook");
  logger.info("coinPacks: webhook grant", {transactionId, status: result.status});
  return result.status === "not_found" ? 503 : 200;
}

/** RevenueCat calls this for every event. Only requests with the configured Authorization header count. */
export const revenueCatWebhook = onRequest(
  {region: US_REGION, invoker: "public", maxInstances: 2, cpu: "gcf_gen1", memory: "256MiB", timeoutSeconds: 60,
    secrets: [revenueCatSecret, webhookAuth]},
  async (req, res) => {
    if (req.method !== "POST") {
      res.sendStatus(405);
      return;
    }
    if (!webhookAuthorized(req.get("Authorization"), webhookAuth.value())) {
      res.sendStatus(401);
      return;
    }
    const event = (req.body as {event?: WebhookEvent} | undefined)?.event;
    if (typeof event !== "object" || event === null) {
      res.sendStatus(200);
      return;
    }
    try {
      res.sendStatus(await handleWebhookEvent(event));
    } catch (error) {
      logger.error("coinPacks: webhook failed", {err: error instanceof Error ? error.message : String(error)});
      res.sendStatus(503);
    }
  },
);
