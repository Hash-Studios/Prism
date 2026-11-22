import assert from "node:assert/strict";
import test, {beforeEach, type TestContext} from "node:test";
import {
  findStorePurchase,
  decideGrant,
  handleWebhookEvent,
  revenueCatWebhook,
  verifyCoinPurchase,
  webhookAuthorized,
} from "../coinPacks";
import {DEFAULT_ECONOMY, parseEconomy, resetEconomyCache} from "../economy";
import {installFakeDb} from "./fakeDb";

type Doc = Record<string, unknown>;
type WebhookEvent = Parameters<typeof handleWebhookEvent>[0];

beforeEach(() => resetEconomyCache());

const ENV_KEYS = ["REVENUECAT_SECRET_KEY", "REVENUECAT_WEBHOOK_AUTH", "COIN_PACKS_ALLOW_SANDBOX"] as const;

function setEnv(t: TestContext, allowSandbox: boolean) {
  const saved = ENV_KEYS.map((key) => [key, process.env[key]] as const);
  Object.assign(process.env, {
    REVENUECAT_SECRET_KEY: "test-rc",
    REVENUECAT_WEBHOOK_AUTH: "Bearer hook-secret",
    COIN_PACKS_ALLOW_SANDBOX: allowSandbox ? "true" : "false",
  });
  t.after(() => {
    for (const [key, value] of saved) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
}

/** One RevenueCat v1 non-subscription entry. */
function entry(overrides: Doc = {}): Doc {
  return {
    id: "rc1",
    store_transaction_id: "1000000111",
    is_sandbox: false,
    store: "app_store",
    purchase_date: "2026-11-01T00:00:00Z",
    ...overrides,
  };
}

function customerWith(productId: string, entries: Doc[]): unknown {
  return {subscriber: {non_subscriptions: {[productId]: entries}}};
}

interface SetupOptions {
  seed?: Record<string, Doc>;
  customer?: unknown;
  fetchStatus?: number;
  allowSandbox?: boolean;
}

/** An in-memory Firestore, RevenueCat fetch mock and env, for one test. */
function setup(t: TestContext, options: SetupOptions = {}) {
  setEnv(t, options.allowSandbox ?? false);
  const store = installFakeDb(t, {"usersv2/u": {coins: 50}, ...options.seed});
  const fetches: string[] = [];
  const customer = options.customer ?? customerWith("prism_coins_300", [entry()]);
  t.mock.method(globalThis, "fetch", async (url: string | URL | Request) => {
    fetches.push(String(url));
    if (options.fetchStatus) return new Response("", {status: options.fetchStatus});
    return new Response(JSON.stringify(customer), {status: 200});
  });
  return {store, fetches};
}

const callVerify = (uid: string, transactionId: unknown) =>
  verifyCoinPurchase.run({
    auth: {uid, token: {firebase: {sign_in_provider: "google.com"}}},
    data: {transactionId},
  } as never);

function purchaseEvent(overrides: Doc = {}): WebhookEvent {
  return {
    type: "NON_RENEWING_PURCHASE",
    product_id: "prism_coins_300",
    transaction_id: "1000000111",
    app_user_id: "u",
    ...overrides,
  } as WebhookEvent;
}

function cancelEvent(type = "CANCELLATION"): WebhookEvent {
  return purchaseEvent({type});
}

/** Calls the HTTPS webhook handler and returns the single status it sent. */
async function postWebhook(authHeader: string | undefined, body: unknown, method = "POST"): Promise<number> {
  const statuses: number[] = [];
  const req = {method, get: (name: string) => name === "Authorization" ? authHeader : undefined, body};
  const res = {sendStatus: (code: number) => {
    statuses.push(code);
  }};
  await revenueCatWebhook(
    req as unknown as Parameters<typeof revenueCatWebhook>[0],
    res as unknown as Parameters<typeof revenueCatWebhook>[1],
  );
  assert.equal(statuses.length, 1);
  return statuses[0];
}

const coinsOf = (store: Map<string, Doc>, uid: string) => store.get(`usersv2/${uid}`)?.coins;
const ledgerRows = (store: Map<string, Doc>) => [...store.keys()].filter((key) => key.startsWith("coinTransactions/"));

test("verifyCoinPurchase: a real purchase grants the pack coins once and writes the ledger and receipt", async (t) => {
  const {store} = setup(t);
  const reply = await callVerify("u", "1000000111");
  assert.deepEqual(reply, {status: "granted", coins: 330, balance: 380});
  assert.equal(coinsOf(store, "u"), 380);
  assert.deepEqual(
    {
      delta: store.get("coinTransactions/ctx_coinpack_1000000111")?.delta,
      action: store.get("coinTransactions/ctx_coinpack_1000000111")?.action,
      source: store.get("coinTransactions/ctx_coinpack_1000000111")?.source,
      productId: store.get("coinTransactions/ctx_coinpack_1000000111")?.productId,
      environment: store.get("coinTransactions/ctx_coinpack_1000000111")?.environment,
    },
    {delta: 330, action: "coinPack", source: "purchase", productId: "prism_coins_300", environment: "production"},
  );
  assert.deepEqual(
    {state: store.get("coinPackReceipts/1000000111")?.state, userId: store.get("coinPackReceipts/1000000111")?.userId},
    {state: "granted", userId: "u"},
  );
});

test("verifyCoinPurchase then webhook: the same transaction grants only once", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  assert.equal(await handleWebhookEvent(purchaseEvent()), 200);
  assert.equal(coinsOf(store, "u"), 380);
  assert.equal(ledgerRows(store).length, 1);
});

test("webhook then verifyCoinPurchase: the callable reports already_granted and does not pay again", async (t) => {
  const {store} = setup(t);
  assert.equal(await handleWebhookEvent(purchaseEvent()), 200);
  assert.equal(coinsOf(store, "u"), 380);
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "already_granted", coins: 330, balance: 380});
  assert.equal(coinsOf(store, "u"), 380);
});

test("verifyCoinPurchase called twice: the second call is already_granted and the balance is unchanged", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "already_granted", coins: 330, balance: 380});
  assert.equal(coinsOf(store, "u"), 380);
});

test("verifyCoinPurchase: a transaction RevenueCat does not list is not_found and writes nothing", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await callVerify("u", "9999999999"), {status: "not_found"});
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.has("coinPackReceipts/9999999999"), false);
});

test("verifyCoinPurchase: a receipt that names another user is refused and pays nobody", async (t) => {
  const {store} = setup(t, {
    seed: {
      "usersv2/v": {coins: 50},
      "coinPackReceipts/1000000111": {state: "granted", userId: "u", coins: 330},
    },
  });
  assert.deepEqual(await callVerify("v", "1000000111"), {status: "refused", reason: "other_user"});
  assert.equal(coinsOf(store, "v"), 50);
  assert.equal(coinsOf(store, "u"), 50);
});

test("verifyCoinPurchase: a purchase of a product that is not a coin pack is refused", async (t) => {
  const {store} = setup(t, {
    customer: customerWith("prism_v3_pro_monthly", [entry({id: "rc2", store_transaction_id: "2000"})]),
  });
  assert.deepEqual(await callVerify("u", "2000"), {status: "refused", reason: "unknown_product"});
  assert.equal(coinsOf(store, "u"), 50);
});

test("verifyCoinPurchase: a sandbox purchase is refused in production", async (t) => {
  const {store} = setup(t, {customer: customerWith("prism_coins_300", [entry({is_sandbox: true})])});
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "refused", reason: "sandbox_not_allowed"});
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.has("coinPackReceipts/1000000111"), false);
});

test("verifyCoinPurchase: a sandbox purchase grants in dev and is logged as sandbox", async (t) => {
  const {store} = setup(t, {
    allowSandbox: true,
    customer: customerWith("prism_coins_300", [entry({is_sandbox: true})]),
  });
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "granted", coins: 330, balance: 380});
  assert.equal(store.get("coinTransactions/ctx_coinpack_1000000111")?.environment, "sandbox");
  assert.equal(store.get("coinPackReceipts/1000000111")?.environment, "sandbox");
});

test("refund after a grant: CANCELLATION takes the pack back and leaves a revoked receipt", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  assert.equal(await handleWebhookEvent(cancelEvent()), 200);
  assert.equal(coinsOf(store, "u"), 50);
  assert.deepEqual(
    {
      delta: store.get("coinTransactions/ctx_coinpack_refund_1000000111")?.delta,
      action: store.get("coinTransactions/ctx_coinpack_refund_1000000111")?.action,
    },
    {delta: -330, action: "coinPackRefund"},
  );
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
});

test("refund after a grant: a second CANCELLATION changes nothing", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  await handleWebhookEvent(cancelEvent());
  assert.equal(await handleWebhookEvent(cancelEvent()), 200);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(ledgerRows(store).length, 2);
});

test("refund after a grant: a REFUND event behaves like CANCELLATION", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  assert.equal(await handleWebhookEvent(cancelEvent("REFUND")), 200);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
});

test("refund can take the balance below zero when the user already spent the coins", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  store.set("usersv2/u", {...store.get("usersv2/u"), coins: 10});
  await handleWebhookEvent(cancelEvent());
  assert.equal(coinsOf(store, "u"), -320);
});

test("refund before any grant: the tombstone blocks a later callable grant", async (t) => {
  const {store} = setup(t);
  assert.equal(await handleWebhookEvent(cancelEvent()), 200);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "revoked"});
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(ledgerRows(store).length, 0);
});

test("refund before any grant: a REFUND tombstone blocks a later webhook grant", async (t) => {
  const {store} = setup(t);
  assert.equal(await handleWebhookEvent(cancelEvent("REFUND")), 200);
  assert.equal(await handleWebhookEvent(purchaseEvent()), 200);
  assert.equal(coinsOf(store, "u"), 50);
});

test("webhookAuthorized: only the exact configured Authorization header passes", () => {
  assert.equal(webhookAuthorized(undefined, "Bearer hook-secret"), false);
  assert.equal(webhookAuthorized("Bearer wrong", "Bearer hook-secret"), false);
  assert.equal(webhookAuthorized("Bearer hook-secret", "Bearer hook-secret"), true);
  assert.equal(webhookAuthorized("x", ""), false);
});

test("revenueCatWebhook: a wrong Authorization header gets 401 and no coins, and RevenueCat is never read", async (t) => {
  const {store, fetches} = setup(t);
  assert.equal(await postWebhook("Bearer wrong", {event: purchaseEvent()}), 401);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(fetches.length, 0);
});

test("revenueCatWebhook: a GET gets 405", async (t) => {
  setup(t);
  assert.equal(await postWebhook("Bearer hook-secret", {event: purchaseEvent()}, "GET"), 405);
});

test("handleWebhookEvent: an event for a user with no Prism profile is acknowledged and grants nothing", async (t) => {
  const {store, fetches} = setup(t);
  assert.equal(await handleWebhookEvent(purchaseEvent({app_user_id: "ghost"})), 200);
  assert.equal(store.has("usersv2/ghost"), false);
  assert.equal(ledgerRows(store).length, 0);
  assert.equal(fetches.length, 0);
});

test("verifyCoinPurchase: an unknown user gets not-found", async (t) => {
  setup(t);
  await assert.rejects(callVerify("ghost", "1000000111"), {code: "not-found"});
});

test("handleWebhookEvent: an anonymous app user id grants to the real alias", async (t) => {
  const {store} = setup(t);
  const event = purchaseEvent({
    app_user_id: "$RCAnonymousID:abc",
    aliases: ["$RCAnonymousID:abc", "u"],
  });
  assert.equal(await handleWebhookEvent(event), 200);
  assert.equal(coinsOf(store, "u"), 380);
});

test("handleWebhookEvent: an event for a product that is not a coin pack is ignored", async (t) => {
  const {fetches} = setup(t);
  const event = purchaseEvent({product_id: "prism_v3_pro_monthly", type: "INITIAL_PURCHASE"});
  assert.equal(await handleWebhookEvent(event), 200);
  assert.equal(fetches.length, 0);
});

test("revenueCatWebhook: a transaction RevenueCat does not list yet gets 503 so RevenueCat retries", async (t) => {
  setup(t);
  assert.equal(await postWebhook("Bearer hook-secret", {event: purchaseEvent({transaction_id: "1000000999"})}), 503);
});

test("revenueCatWebhook: a failed RevenueCat read gets 503 so RevenueCat retries", async (t) => {
  const {store} = setup(t, {fetchStatus: 500});
  assert.equal(await postWebhook("Bearer hook-secret", {event: purchaseEvent()}), 503);
  assert.equal(coinsOf(store, "u"), 50);
});

test("verifyCoinPurchase: an anonymous sign-in is unauthenticated", async (t) => {
  setup(t);
  await assert.rejects(
    verifyCoinPurchase.run({
      auth: {uid: "u", token: {firebase: {sign_in_provider: "anonymous"}}},
      data: {transactionId: "1000000111"},
    } as never),
    {code: "unauthenticated"},
  );
});

test("verifyCoinPurchase: a transaction id with a slash or an empty id is invalid-argument", async (t) => {
  setup(t);
  await assert.rejects(callVerify("u", "a/b"), {code: "invalid-argument"});
  await assert.rejects(callVerify("u", ""), {code: "invalid-argument"});
});

test("verifyCoinPurchase: the 21st check within 10 minutes is resource-exhausted", async (t) => {
  setup(t);
  let now = Date.parse("2026-11-01T00:00:00.000Z");
  t.mock.method(Date, "now", () => now);
  for (let i = 0; i < 20; i += 1) await callVerify("u", "1000000111");
  await assert.rejects(callVerify("u", "1000000111"), {code: "resource-exhausted"});
  now += 10 * 60_000;
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "already_granted", coins: 330, balance: 380});
});

test("findStorePurchase: matches by store transaction id and by RevenueCat id, and returns null when missing", () => {
  const json = customerWith("prism_coins_300", [entry()]);
  const expected = {transactionId: "1000000111", productId: "prism_coins_300", store: "app_store", sandbox: false};
  assert.deepEqual(findStorePurchase(json, "1000000111"), expected);
  assert.deepEqual(findStorePurchase(json, "rc1"), {...expected, transactionId: "rc1"});
  assert.equal(findStorePurchase(json, "5555"), null);
});

test("decideGrant: a promotional store is refused and a play_store purchase is accepted", () => {
  const packs = DEFAULT_ECONOMY.coinPacks;
  const base = {transactionId: "1", productId: "prism_coins_300", sandbox: false};
  assert.deepEqual(decideGrant({...base, store: "promotional"}, packs, false), {reason: "store_not_allowed"});
  assert.deepEqual(decideGrant({...base, store: "play_store"}, packs, false), {coins: 330});
});

test("parseEconomy: invalid and duplicate coin packs are dropped and the first valid entry of each product is kept", () => {
  const config = parseEconomy({
    coinPacks: [
      {productId: "bad", coins: 0, bonusPercent: 0},
      {productId: "prism_coins_100", coins: 100, bonusPercent: 5},
      {productId: "prism_coins_100", coins: 999, bonusPercent: 50},
      {productId: "prism_coins_700", coins: 840, bonusPercent: 20},
    ],
  });
  assert.deepEqual(config.coinPacks, [
    {productId: "prism_coins_100", coins: 100, bonusPercent: 5},
    {productId: "prism_coins_700", coins: 840, bonusPercent: 20},
  ]);
});

test("parseEconomy: a non-array coinPacks falls back to the defaults and an empty list sells nothing", () => {
  assert.deepEqual(parseEconomy({coinPacks: "nope"}).coinPacks, DEFAULT_ECONOMY.coinPacks);
  assert.deepEqual(parseEconomy({coinPacks: []}).coinPacks, []);
});
