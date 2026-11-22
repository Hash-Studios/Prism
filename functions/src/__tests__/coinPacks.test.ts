import assert from "node:assert/strict";
import {createHmac} from "node:crypto";
import test, {beforeEach, type TestContext} from "node:test";
import {
  findStorePurchase,
  decideGrant,
  handleWebhookEvent,
  revenueCatWebhook,
  verifyCoinPurchase,
  webhookAuthorized,
  webhookSignatureAuthorized,
} from "../coinPacks";
import {DEFAULT_ECONOMY, parseEconomy, resetEconomyCache} from "../economy";
import {installFakeDb} from "./fakeDb";
import {db} from "../common";

type Doc = Record<string, unknown>;
type WebhookEvent = Parameters<typeof handleWebhookEvent>[0];

beforeEach(() => resetEconomyCache());

const ENV_KEYS = ["REVENUECAT_SECRET_KEY", "REVENUECAT_WEBHOOK_AUTH", "REVENUECAT_WEBHOOK_SIGNING_SECRET",
  "COIN_PACKS_ALLOW_SANDBOX"] as const;

function setEnv(t: TestContext, allowSandbox: boolean) {
  const saved = ENV_KEYS.map((key) => [key, process.env[key]] as const);
  Object.assign(process.env, {
    REVENUECAT_SECRET_KEY: "test-rc",
    REVENUECAT_WEBHOOK_AUTH: "Bearer hook-secret",
    REVENUECAT_WEBHOOK_SIGNING_SECRET: "test-signing-secret",
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
  fetchBody?: string;
  allowSandbox?: boolean;
  fetchBarrier?: {started: () => void; wait: Promise<void>};
}

/** An in-memory Firestore, RevenueCat fetch mock and env, for one test. */
function setup(t: TestContext, options: SetupOptions = {}) {
  setEnv(t, options.allowSandbox ?? false);
  const store = installFakeDb(t, {"usersv2/u": {coins: 50}, ...options.seed});
  const fetches: string[] = [];
  const customer = options.customer ?? customerWith("prism_coins_300", [entry()]);
  t.mock.method(globalThis, "fetch", async (url: string | URL | Request) => {
    fetches.push(String(url));
    options.fetchBarrier?.started();
    await options.fetchBarrier?.wait;
    if (options.fetchStatus) return new Response("", {status: options.fetchStatus});
    return new Response(options.fetchBody ?? JSON.stringify(customer), {status: 200});
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
    store: "APP_STORE",
    environment: "PRODUCTION",
    ...overrides,
  } as WebhookEvent;
}

function cancelEvent(type = "CANCELLATION"): WebhookEvent {
  return purchaseEvent({type});
}

/** Calls the HTTPS webhook handler and returns the single status it sent. */
async function postWebhook(authHeader: string | undefined, body: unknown, method = "POST", signed = false): Promise<number> {
  const statuses: number[] = [];
  const rawBody = Buffer.from(JSON.stringify(body));
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = signed ? `t=${timestamp},v1=${createHmac("sha256", "test-signing-secret")
    .update(`${timestamp}.`).update(rawBody).digest("hex")}` : undefined;
  const req = {
    method,
    get: (name: string) => name === "Authorization" ? authHeader :
      name === "X-RevenueCat-Webhook-Signature" ? signature : undefined,
    body,
    rawBody,
  };
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

test("RevenueCat alias and canonical store id share one receipt and one grant", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await callVerify("u", "rc1"), {status: "granted", coins: 330, balance: 380});
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "already_granted", coins: 330, balance: 380});
  assert.equal(store.has("coinPackReceipts/rc1"), false);
  assert.equal(store.has("coinPackReceipts/1000000111"), true);
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

test("signed CANCELLATION for a non-pack product does not create a tombstone", async (t) => {
  const {store} = setup(t);
  assert.equal(await handleWebhookEvent(purchaseEvent({
    type: "CANCELLATION", product_id: "prism_v3_pro_monthly", transaction_id: "subscription-123",
  })), 200);
  assert.equal(store.has("coinPackReceipts/subscription-123"), false);
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

test("refunds remain processable after the product is removed from the current catalog", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  store.set("economyConfig/current", {coinPacks: []});
  resetEconomyCache();
  assert.equal(await handleWebhookEvent(cancelEvent()), 200);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
});

test("a grant remains already_granted when its pack is removed from the catalog", async (t) => {
  const {store, fetches} = setup(t);
  await callVerify("u", "1000000111");
  store.set("economyConfig/current", {coinPacks: []});
  const readsBeforeRetry = fetches.length;
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "already_granted", coins: 330, balance: 380});
  assert.equal(fetches.length, readsBeforeRetry);
});

test("catalog read failure fails closed, and a later successful catalog read can grant", async (t) => {
  const {store} = setup(t);
  let failCatalogRead = true;
  const originalDoc = db.doc;
  t.mock.method(db, "doc", (path: string) => {
    if (path === "economyConfig/current" && failCatalogRead) {
      return {get: async () => {
        throw new Error("injected catalog outage");
      }} as unknown as ReturnType<typeof db.doc>;
    }
    return originalDoc(path);
  });
  await assert.rejects(callVerify("u", "1000000111"), {code: "unavailable"});
  assert.equal(coinsOf(store, "u"), 50);
  failCatalogRead = false;
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "granted", coins: 330, balance: 380});
});

test("refund after account deletion preserves receipt without creating new debt or ledger", async (t) => {
  const {store} = setup(t, {
    seed: {
      "usersv2/u": {coins: 0, deleted: true},
      "coinPackReceipts/1000000111": {
        state: "granted", userId: "u", productId: "prism_coins_300", coins: 330,
        store: "app_store", environment: "production",
      },
    },
  });
  assert.equal(await handleWebhookEvent(cancelEvent()), 200);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
  assert.equal(coinsOf(store, "u"), 0);
  assert.equal(store.has("coinTransactions/ctx_coinpack_refund_1000000111"), false);
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

test("webhook alias resolution skips closed/deleted profiles and continues to the live alias", async (t) => {
  const {store} = setup(t, {seed: {
    "usersv2/closed-user": {coins: 0, deleted: true},
    "creatorDeletionState/closed-user": {closed: true},
  }});
  assert.equal(await handleWebhookEvent(purchaseEvent({
    app_user_id: "closed-user", aliases: ["closed-user", "u"],
  })), 200);
  assert.equal(coinsOf(store, "closed-user"), 0);
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

test("malformed RevenueCat JSON returns a generic unavailable error", async (t) => {
  setup(t, {fetchBody: "secret-like-private-response"});
  await assert.rejects(callVerify("u", "1000000111"), {
    code: "unavailable", message: "RevenueCat response was invalid.",
  });
});

test("RevenueCat API override is used only in the Functions emulator", async (t) => {
  const {fetches} = setup(t);
  const savedEmulator = process.env.FUNCTIONS_EMULATOR;
  const savedBase = process.env.REVENUECAT_API_BASE;
  t.after(() => {
    if (savedEmulator === undefined) delete process.env.FUNCTIONS_EMULATOR;
    else process.env.FUNCTIONS_EMULATOR = savedEmulator;
    if (savedBase === undefined) delete process.env.REVENUECAT_API_BASE;
    else process.env.REVENUECAT_API_BASE = savedBase;
  });
  process.env.REVENUECAT_API_BASE = "https://fake-revenuecat.invalid";
  delete process.env.FUNCTIONS_EMULATOR;
  await callVerify("u", "not-listed-1");
  process.env.FUNCTIONS_EMULATOR = "true";
  await callVerify("u", "not-listed-2");
  assert.match(fetches[0], /^https:\/\/api\.revenuecat\.com\//);
  assert.match(fetches[1], /^https:\/\/fake-revenuecat\.invalid\//);
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
  assert.deepEqual(findStorePurchase(json, "rc1"), expected);
  assert.equal(findStorePurchase(json, "5555"), null);
});

test("findStorePurchase: App Store and Play Store RevenueCat aliases resolve to canonical store ids", () => {
  const entries = customerWith("prism_coins_300", [entry({id: "rc-ios", store_transaction_id: "ios:123"})]);
  const ios = findStorePurchase(entries, "rc-ios");
  assert.equal(ios?.transactionId, "ios:123");
  assert.equal(ios?.store, "app_store");

  const play = findStorePurchase(customerWith("prism_coins_300", [entry({
    id: "rc-android", store_transaction_id: "GPA.123-456", store: "play_store",
  })]), "rc-android");
  assert.equal(play?.transactionId, "GPA.123-456");
  assert.equal(play?.store, "play_store");
});

test("findStorePurchase prioritizes an exact store id over another purchase's RevenueCat alias", () => {
  const customer = customerWith("prism_coins_300", [
    entry({id: "rc-other", store_transaction_id: "different-store-id"}),
    entry({id: "ios:123", store_transaction_id: "ios:123"}),
  ]);
  assert.equal(findStorePurchase(customer, "ios:123")?.transactionId, "ios:123");
});

test("findStorePurchase: rejects a RevenueCat-only id until the stable store transaction id is present", () => {
  assert.equal(findStorePurchase(customerWith("prism_coins_300", [entry({store_transaction_id: undefined})]), "rc1"), null);
});

test("verifyCoinPurchase: Firestore-reserved canonical ids are invalid-argument", async (t) => {
  setup(t);
  for (const transactionId of [".", "..", "__internal__"]) {
    await assert.rejects(callVerify("u", transactionId), {code: "invalid-argument"});
  }
});

test("verifyCoinPurchase rejects the reserved refund_ namespace used by ledger ids", async (t) => {
  setup(t);
  await assert.rejects(callVerify("u", "refund_123"), {code: "invalid-argument"});
});

test("concurrent verify calls grant the canonical transaction once", async (t) => {
  const {store} = setup(t);
  const results = await Promise.all([callVerify("u", "1000000111"), callVerify("u", "1000000111")]);
  assert.deepEqual(results.map((result) => (result as {status: string}).status).sort(), ["already_granted", "granted"]);
  assert.equal(coinsOf(store, "u"), 380);
  assert.equal(ledgerRows(store).length, 1);
});

test("callable alias and webhook canonical event racing still grant once", async (t) => {
  const {store} = setup(t);
  await Promise.all([callVerify("u", "rc1"), handleWebhookEvent(purchaseEvent())]);
  assert.equal(coinsOf(store, "u"), 380);
  assert.equal(store.has("coinPackReceipts/1000000111"), true);
  assert.equal(store.has("coinPackReceipts/rc1"), false);
  assert.equal(ledgerRows(store).length, 1);
});

test("grant racing a signed refund ends revoked with at most one debit and grant", async (t) => {
  const {store} = setup(t);
  await Promise.all([
    callVerify("u", "1000000111"),
    postWebhook("Bearer hook-secret", {event: cancelEvent("REFUND")}, "POST", true),
  ]);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
  assert.ok(ledgerRows(store).length === 0 || ledgerRows(store).length === 2);
});

test("deletion closing during RevenueCat lookup prevents an in-flight grant", async (t) => {
  let startFetch!: () => void;
  let releaseFetch!: () => void;
  const started = new Promise<void>((resolve) => {
    startFetch = resolve;
  });
  const wait = new Promise<void>((resolve) => {
    releaseFetch = resolve;
  });
  const {store} = setup(t, {fetchBarrier: {started: startFetch, wait}});
  const pending = callVerify("u", "1000000111");
  await started;
  store.set("creatorDeletionState/u", {closed: true});
  releaseFetch();
  await assert.rejects(pending, {code: "failed-precondition"});
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.has("coinPackReceipts/1000000111"), false);
});

test("verifyCoinPurchase refuses entries with missing or malformed is_sandbox metadata", async (t) => {
  const {store} = setup(t, {customer: customerWith("prism_coins_300", [entry({is_sandbox: undefined})])});
  assert.deepEqual(await callVerify("u", "1000000111"), {status: "not_found"});
  assert.equal(coinsOf(store, "u"), 50);
});

test("RevenueCat numeric canonical transaction ids are preserved without rounding", () => {
  assert.equal(findStorePurchase(customerWith("prism_coins_300", [entry({
    store_transaction_id: 1_000_000_111,
  })]), "1000000111")?.transactionId, "1000000111");
  assert.equal(findStorePurchase(customerWith("prism_coins_300", [entry({
    store_transaction_id: Number.MAX_SAFE_INTEGER + 1,
  })]), "9007199254740992"), null);
});

test("webhook HMAC uses exact bytes and rejects stale timestamps", () => {
  const secret = "test-signing-secret";
  const nowMs = 1_800_000_000_000;
  const timestamp = String(Math.floor(nowMs / 1000));
  const rawBody = Buffer.from("{ \"event\": {} }");
  const digest = createHmac("sha256", secret).update(`${timestamp}.`).update(rawBody).digest("hex");
  const signature = `t=${timestamp},v1=${digest}`;
  assert.equal(webhookSignatureAuthorized(signature, rawBody, secret, nowMs), true);
  assert.equal(webhookSignatureAuthorized(signature, Buffer.from("{\"event\":{}}"), secret, nowMs), false);
  assert.equal(webhookSignatureAuthorized(`t=${Number(timestamp) - 301},v1=${digest}`, rawBody, secret, nowMs), false);
});

test("revenueCatWebhook rejects unsigned refunds and accepts signed raw-body refunds", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  const body = {event: cancelEvent("REFUND")};
  assert.equal(await postWebhook("Bearer hook-secret", body), 401);
  assert.equal(coinsOf(store, "u"), 380);
  assert.equal(await postWebhook("Bearer hook-secret", body, "POST", true), 200);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
});

test("signed sandbox tombstones require the sandbox flag", async (t) => {
  const {store} = setup(t);
  const sandbox = purchaseEvent({environment: "SANDBOX", transaction_id: "sandbox-123"});
  assert.equal(await postWebhook("Bearer hook-secret", {event: {...sandbox, type: "REFUND"}}, "POST", true), 200);
  assert.equal(store.has("coinPackReceipts/sandbox-123"), false);
});

test("matching sandbox receipts can be refunded after the sandbox flag is disabled", async (t) => {
  const {store} = setup(t, {allowSandbox: true, customer: customerWith("prism_coins_300", [entry({
    store_transaction_id: "sandbox-123", is_sandbox: true,
  })])});
  assert.deepEqual(await callVerify("u", "sandbox-123"), {status: "granted", coins: 330, balance: 380});
  process.env.COIN_PACKS_ALLOW_SANDBOX = "false";
  const sandbox = purchaseEvent({environment: "SANDBOX", transaction_id: "sandbox-123"});
  assert.equal(await postWebhook("Bearer hook-secret", {event: {...sandbox, type: "REFUND"}}, "POST", true), 200);
  assert.equal(coinsOf(store, "u"), 50);
});

test("signed TEST_STORE sandbox refund is supported", async (t) => {
  const {store} = setup(t, {allowSandbox: true, customer: customerWith("prism_coins_300", [entry({
    store_transaction_id: "test-123", store: "test_store", is_sandbox: true,
  })])});
  await callVerify("u", "test-123");
  const event = purchaseEvent({type: "REFUND", store: "TEST_STORE", environment: "SANDBOX", transaction_id: "test-123"});
  assert.equal(await postWebhook("Bearer hook-secret", {event}, "POST", true), 200);
  assert.equal(coinsOf(store, "u"), 50);
});

test("REFUND_REVERSED does not restore a revoked pack", async (t) => {
  const {store} = setup(t);
  await callVerify("u", "1000000111");
  await handleWebhookEvent(cancelEvent("REFUND"));
  assert.equal(await handleWebhookEvent(cancelEvent("REFUND_REVERSED")), 200);
  assert.equal(coinsOf(store, "u"), 50);
  assert.equal(store.get("coinPackReceipts/1000000111")?.state, "revoked");
});

test("decideGrant: a promotional store is refused and a play_store purchase is accepted", () => {
  const packs = DEFAULT_ECONOMY.coinPacks;
  const base = {transactionId: "1", productId: "prism_coins_300", sandbox: false};
  assert.deepEqual(decideGrant({...base, store: "promotional"}, packs, false), {reason: "store_not_allowed"});
  assert.deepEqual(decideGrant({...base, store: "play_store"}, packs, false), {coins: 330});
  assert.deepEqual(decideGrant({...base, store: "test_store"}, packs, true), {reason: "sandbox_not_allowed"});
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
