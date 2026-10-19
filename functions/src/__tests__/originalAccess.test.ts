import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {resolveOriginalAccess, originalAccessDelivery} from "../originalAccess";
import {refundableDelta} from "../coinsCallables";
import {resetEconomyCache, DEFAULT_ECONOMY} from "../economy";
import {installFakeDb} from "./fakeDb";

function setup(t: Parameters<typeof installFakeDb>[0], wall = {}, user = {}, privateData = {}) {
  resetEconomyCache();
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
  t.mock.method(originalAccessDelivery, "sign", async () => ({url: "https://private.test/signed",
    generation: "v1", expiresAt: Date.now() + 60_000}));
  return installFakeDb(t, {
    "walls/document-not-asset": {id: "asset", review: true, originalProtected: true,
      originalGeneration: "v1", collections: ["premium"], wallpaper_url: "", wallpaper_path: "original/path",
      wallpaper_sha: "original-sha", thumb_path: "thumb/path", thumb_sha: "thumb-sha", ...wall},
    "ownedAssets/asset": {status: "ready", canonicalPath: "walls/document-not-asset", incarnation: 1,
      incarnationNanos: 1_000_000, original: {generation: "v1", path: "original/path", sha: "original-sha"},
      thumb: {path: "thumb/path", sha: "thumb-sha"}},
    "usersv2/user": {coins: 100, ...user},
    "usersv2/user/private/economy": {graceDownloadsUsed: 100, ...privateData},
  });
}
const request = (data = {}, auth: unknown = {uid: "user", token: {}}) => ({
  auth, data: {assetId: "asset", action: "download", requestId: "request_123", ...data},
  rawRequest: {},
} as Parameters<typeof resolveOriginalAccess.run>[0]);

function setupPair(t: Parameters<typeof installFakeDb>[0], user = {}, privateData = {}) {
  const store = setup(t, {collections: ["nature"]}, user, privateData);
  store.set("walls/second", {...store.get("walls/document-not-asset"), id: "second"});
  store.set("ownedAssets/second", {...store.get("ownedAssets/asset"), canonicalPath: "walls/second"});
  return store;
}
const pairRequest = (data = {}) => request({assetId: undefined, action: undefined,
  assets: [{assetId: "asset", action: "set"}, {assetId: "second", action: "set"}], ...data});

test("pair quote shares remaining grace and acquire atomically charges once with replay", async (t) => {
  const store = setupPair(t, {}, {graceDownloadsUsed: DEFAULT_ECONOMY.award.graceDownloads - 1});
  const before = structuredClone([...store.entries()]);
  const quote = await resolveOriginalAccess.run(pairRequest({mode: "quote"}));
  assert.equal(quote.status, "quoted");
  assert.equal("requiredCoins" in quote && quote.requiredCoins, DEFAULT_ECONOMY.spend.wallpaperDownload);
  assert.deepEqual([...store.entries()], before);
  const result = await resolveOriginalAccess.run(pairRequest({maxCoins: DEFAULT_ECONOMY.spend.wallpaperDownload}));
  assert(result.status === "granted");
  assert.equal("grants" in result && result.grants.length, 2);
  assert.equal(result.chargedCoins, DEFAULT_ECONOMY.spend.wallpaperDownload);
  assert.equal(store.get("usersv2/user/private/economy")?.graceDownloadsUsed, DEFAULT_ECONOMY.award.graceDownloads);
  const after = structuredClone([...store.entries()]);
  const continuation = await resolveOriginalAccess.run(pairRequest({mode: "quote"}));
  assert.equal("requiredCoins" in continuation && continuation.requiredCoins, 0);
  const replay = await resolveOriginalAccess.run(pairRequest({maxCoins: 0}));
  assert.equal(replay.status, "granted");
  assert.deepEqual(structuredClone([...store.entries()]), after);
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest({assets: [
    {assetId: "second", action: "set"}, {assetId: "asset", action: "set"},
  ]})), {code: "failed-precondition"});
});

test("pair insufficient balance, changed price, missing asset and second signer failure never mutate", async (t) => {
  const store = setupPair(t, {coins: DEFAULT_ECONOMY.spend.wallpaperDownload});
  const before = structuredClone([...store.entries()]);
  assert.equal((await resolveOriginalAccess.run(pairRequest())).status, "insufficient_balance");
  assert.equal((await resolveOriginalAccess.run(pairRequest({maxCoins: 0}))).status, "price_changed");
  assert.deepEqual([...store.entries()], before);
  t.mock.method(originalAccessDelivery, "sign", async (id: string) => {
    if (id === "second") throw new Error("sign failed");
    return {url: "https://private.test/signed", generation: "v1", expiresAt: Date.now() + 60_000};
  });
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest()));
  assert.deepEqual([...store.entries()], before);
  store.delete("ownedAssets/second");
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest({mode: "quote"})), {code: "failed-precondition"});
});

test("pair validates shape and actions strictly", async (t) => {
  setupPair(t);
  for (const assets of [[], null, [{assetId: "asset", action: "download"}],
    [{assetId: "asset", action: "set"}, {assetId: "asset", action: "set"}],
    [{assetId: "asset", action: "set", price: 0}], [{assetId: "bad.id", action: "set"}]]) {
    await assert.rejects(() => resolveOriginalAccess.run(pairRequest({assets})), {code: "invalid-argument"});
  }
});

test("pair replay rechecks second generation, classification, receipt expiry and entitlement", async (t) => {
  const store = setupPair(t, {premium: true});
  const result = await resolveOriginalAccess.run(pairRequest());
  assert(result.status === "granted");
  const path = `coinTransactions/${result.transactionId}`;
  const receipt = store.get(path)!;
  store.set(path, {...receipt, retryUntil: 1});
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest()), {code: "failed-precondition"});
  store.set(path, receipt);
  store.set("usersv2/user", {coins: 100, premium: false});
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest()), {code: "failed-precondition"});
  store.set("usersv2/user", {coins: 100, premium: true});
  const wall = store.get("walls/second")!;
  store.set("walls/second", {...wall, collections: ["premium"]});
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest()), {code: "failed-precondition"});
  store.set("walls/second", {...wall, originalGeneration: "v2"});
  await assert.rejects(() => resolveOriginalAccess.run(pairRequest()), {code: "failed-precondition"});
  assert.equal(store.get("usersv2/user")?.coins, 100);
});

test("original access charges server premium price once and binds request to asset/action/generation", async (t) => {
  const store = setup(t);
  const first = await resolveOriginalAccess.run(request());
  assert(first.status === "granted");
  assert.equal(first.chargedCoins, DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
  const continuation = await resolveOriginalAccess.run(request({mode: "quote"}));
  assert.equal("requiredCoins" in continuation && continuation.requiredCoins, 0);
  const retry = await resolveOriginalAccess.run(request());
  assert(retry.status === "granted");
  assert.equal(retry.transactionId, first.transactionId);
  assert.equal(store.get("usersv2/user")?.coins, 100 - DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
  await assert.rejects(() => resolveOriginalAccess.run(request({action: "edit"})), {code: "failed-precondition"});
  store.set("walls/document-not-asset", {...store.get("walls/document-not-asset"), originalGeneration: "v2"});
  await assert.rejects(() => resolveOriginalAccess.run(request()), {code: "failed-precondition"});
});

test("original access refuses guests, anonymous auth and invalid inputs", async (t) => {
  setup(t);
  await assert.rejects(() => resolveOriginalAccess.run(request({}, null)), {code: "unauthenticated"});
  await assert.rejects(() => resolveOriginalAccess.run(request({}, {uid: "user", token: {
    firebase: {sign_in_provider: "anonymous"},
  }})), {code: "unauthenticated"});
  await assert.rejects(() => resolveOriginalAccess.run(request({action: "share"})), {code: "invalid-argument"});
});

for (const [name, user, privateData, basis] of [
  ["Pro", {premium: true}, {}, "pro"],
  ["active pass", {}, {passes: {premiumPassUntil: Date.now() + 600_000}}, "pass"],
  ["expired pass", {}, {passes: {premiumPassUntil: 1}}, "coins"],
] as const) {
  test(`original access uses ${name} server entitlement`, async (t) => {
    setup(t, {}, user, privateData);
    const result = await resolveOriginalAccess.run(request());
    assert(result.status === "granted");
    assert.equal(result.basis, basis);
    assert.equal(result.chargedCoins, basis === "coins" ? DEFAULT_ECONOMY.spend.premiumWallpaperDownload : 0);
  });
}

test("current collection membership and free-wall grace come from server", async (t) => {
  const store = setup(t, {collections: ["nature"]}, {}, {graceDownloadsUsed: 0});
  const result = await resolveOriginalAccess.run(request({price: 999, isPremium: true}));
  assert(result.status === "granted");
  assert.equal(result.basis, "grace");
  assert.equal(store.get("usersv2/user/private/economy")?.graceDownloadsUsed, 1);
});

test("edit and live cannot acquire a premium original at the cheaper filter price", async (t) => {
  setup(t);
  for (const action of ["edit", "live"]) {
    const result = await resolveOriginalAccess.run(request({action, requestId: `request_${action}`}));
    assert(result.status === "granted");
    assert.equal(result.chargedCoins, DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
  }
});

test("reclassification and pass expiry invalidate earlier receipt retries", async (t) => {
  const store = setup(t, {collections: ["nature"]});
  await resolveOriginalAccess.run(request());
  store.set("walls/document-not-asset", {...store.get("walls/document-not-asset"), collections: ["premium"]});
  await assert.rejects(() => resolveOriginalAccess.run(request()), {code: "failed-precondition"});
  store.set("usersv2/user/private/economy", {passes: {premiumPassUntil: Date.now() + 600_000}});
  await resolveOriginalAccess.run(request({requestId: "request_pass"}));
  store.set("usersv2/user/private/economy", {passes: {premiumPassUntil: 1}});
  await assert.rejects(() => resolveOriginalAccess.run(request({requestId: "request_pass"})), {code: "failed-precondition"});
});

test("insufficient balance leaves no receipt or charge", async (t) => {
  const store = setup(t, {}, {coins: 0});
  const result = await resolveOriginalAccess.run(request());
  assert.equal(result.status, "insufficient_balance");
  assert.equal([...store.keys()].some((key) => key.startsWith("coinTransactions/")), false);
});

test("signer failure is safe to retry without a second debit", async (t) => {
  const store = setup(t);
  const signer = t.mock.method(originalAccessDelivery, "sign", async () => {
    throw new Error("missing signer");
  });
  await assert.rejects(() => resolveOriginalAccess.run(request()));
  assert.equal(store.get("usersv2/user")?.coins, 100);
  signer.mock.restore();
  const result = await resolveOriginalAccess.run(request());
  assert.equal(result.status, "granted");
});

for (const wall of [{is_streak_exclusive: true}, {dropWeek: "2026-W40"}, {review: false},
  {originalProtected: false}]) {
  test(`original access fails closed for ${JSON.stringify(wall)}`, async (t) => {
    const store = setup(t, wall, {premium: true});
    await assert.rejects(() => resolveOriginalAccess.run(request()));
    assert.equal(store.get("usersv2/user")?.coins, 100);
  });
}

test("revoked/refunded receipts cannot authorize and issued originals cannot be refunded", async (t) => {
  const store = setup(t);
  const first = await resolveOriginalAccess.run(request());
  assert(first.status === "granted");
  const path = `coinTransactions/${first.transactionId}`;
  const receipt = store.get(path)!;
  assert.throws(() => refundableDelta({...receipt, action: "wallpaperDownload"}, "user", Date.now()),
    {code: "failed-precondition"});
  for (const status of ["refunded", "revoked"]) {
    store.set(path, {...receipt, status});
    await assert.rejects(() => resolveOriginalAccess.run(request()), {code: "failed-precondition"});
  }
});

test("classification failure and duplicate canonical IDs fail closed", async (t) => {
  const store = setup(t);
  store.set("walls/duplicate", {...store.get("walls/document-not-asset")});
  await assert.rejects(() => resolveOriginalAccess.run(request()), {code: "failed-precondition"});
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    throw new Error("offline");
  });
  await assert.rejects(() => resolveOriginalAccess.run(request()), {code: "unavailable"});
});

test("quotes expose only current server price and never sign or mutate state", async (t) => {
  const store = setup(t);
  const before = structuredClone([...store.entries()]);
  const signer = t.mock.method(originalAccessDelivery, "sign", async () => {
    throw new Error("must not sign");
  });
  const result = await resolveOriginalAccess.run(request({mode: "quote", price: 0, isPremium: false}));
  assert.deepEqual(result, {status: "quoted", assetId: "asset", action: "download", generation: "v1",
    requiredCoins: DEFAULT_ECONOMY.spend.premiumWallpaperDownload, currentBalance: 100, basis: "coins"});
  assert.equal(signer.mock.callCount(), 0);
  assert.deepEqual([...store.entries()], before);
});

for (const [name, wall, user, privateData, basis, cost] of [
  ["Pro", {}, {premium: true}, {}, "pro", 0],
  ["pass", {}, {}, {passes: {premiumPassUntil: Date.now() + 600_000}}, "pass", 0],
  ["grace", {collections: ["nature"]}, {}, {graceDownloadsUsed: 0}, "grace", 0],
  ["free collection", {collections: ["nature"]}, {}, {}, "coins", DEFAULT_ECONOMY.spend.wallpaperDownload],
] as const) {
  test(`quote uses current ${name} server price`, async (t) => {
    setup(t, wall, user, privateData);
    const result = await resolveOriginalAccess.run(request({mode: "quote"}));
    assert.equal(result.status, "quoted");
    assert.equal("requiredCoins" in result && result.requiredCoins, cost);
    assert.equal("basis" in result && result.basis, basis);
  });
}

test("acquire enforces consent ceiling without allowing client pricing or changing receipt replay", async (t) => {
  const store = setup(t);
  const before = structuredClone([...store.entries()]);
  const denied = await resolveOriginalAccess.run(request({mode: "acquire", maxCoins: 0, price: 0}));
  assert.deepEqual(denied, {status: "price_changed",
    requiredCoins: DEFAULT_ECONOMY.spend.premiumWallpaperDownload, currentBalance: 100});
  assert.deepEqual([...store.entries()], before);
  const first = await resolveOriginalAccess.run(request({maxCoins: 100, price: 0}));
  assert(first.status === "granted");
  assert.equal(first.chargedCoins, DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
  const replay = await resolveOriginalAccess.run(request({maxCoins: 0}));
  assert(replay.status === "granted");
  assert.equal(replay.transactionId, first.transactionId);
  assert.equal(store.get("usersv2/user")?.coins, 100 - first.chargedCoins);
});

test("quote/acquire inputs reject invalid mode and consent ceilings", async (t) => {
  setup(t);
  for (const data of [{mode: "peek"}, {mode: null}, {maxCoins: -1}, {maxCoins: 1.5},
    {maxCoins: "0"}, {maxCoins: null}, {maxCoins: Number.MAX_SAFE_INTEGER + 1}, {assetId: "bad.id"},
    {assetId: "a".repeat(201)}]) {
    await assert.rejects(() => resolveOriginalAccess.run(request(data)), {code: "invalid-argument"});
  }
});

test("quotes and acquire reject stale or substituted manifest bindings", async (t) => {
  const store = setup(t);
  const manifest = store.get("ownedAssets/asset")!;
  for (const patch of [{status: "deleted"}, {canonicalPath: "walls/other"}, {incarnation: 2}, {incarnationNanos: 2},
    {original: {generation: "v1", path: "other/path", sha: "original-sha"}},
    {thumb: {path: "other/thumb", sha: "thumb-sha"}}]) {
    store.set("ownedAssets/asset", {...manifest, ...patch});
    for (const mode of ["quote", "acquire"]) {
      await assert.rejects(() => resolveOriginalAccess.run(request({mode})), {code: "failed-precondition"});
    }
  }
  assert.equal(store.get("usersv2/user")?.coins, 100);
});

test("quote is not an entitlement and acquisition rechecks changed price and grace", async (t) => {
  const store = setup(t, {collections: ["nature"]}, {}, {graceDownloadsUsed: 0});
  const quote = await resolveOriginalAccess.run(request({mode: "quote"}));
  assert(quote.status === "quoted");
  assert.equal(quote.requiredCoins, 0);
  store.set("walls/document-not-asset", {...store.get("walls/document-not-asset"), collections: ["premium"]});
  const denied = await resolveOriginalAccess.run(request({maxCoins: quote.requiredCoins}));
  assert.equal(denied.status, "price_changed");
  assert.equal(store.get("usersv2/user")?.coins, 100);
  assert.equal(store.get("usersv2/user/private/economy")?.graceDownloadsUsed, 0);
  assert.equal([...store.keys()].some((key) => key.startsWith("coinTransactions/")), false);
});
