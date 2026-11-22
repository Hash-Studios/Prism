import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {refundableDelta} from "../coinsCallables";
import {
  CREATOR_SALE_COINS_PER_DAY, CREATOR_SHARE_PERCENT, UNLOCKS_PER_BUYER_PER_DAY, UNLOCKS_PER_PAIR_PER_DAY,
  creatorShareOf, creatorWallIo, refundDeletedWall, setWallPrice, unlockCreatorWall,
} from "../creatorWalls";
import {resetEconomyCache} from "../economy";
import {ownedThumbnailUrl} from "../ownedAssetDelivery";
import {r2ObjectId} from "../r2Storage";
import {type Doc, installFakeDb} from "./fakeDb";

type Store = Map<string, Doc>;

const NOW = new Date("2026-11-22T12:00:00Z");
const TODAY = "2026-11-22";
const DAY = 86_400_000;
const REQ = "request_0001";
const BUY_TX = `coinTransactions/ctx_cwbuy_fan_${REQ}`;
const SALE_TX = `coinTransactions/ctx_cwsale_fan_${REQ}`;
const pendingRefundKey = (wallId = "neon", millis = 1, nanos = 1_000_000) =>
  createHash("sha256").update(`walls/${wallId}\0${millis}:${nanos}`).digest("hex");
const assetUpload = (path: string, digest: string, preview = false) => {
  const identity = {uid: "maker", repo: "walls", path, sha: "c".repeat(40), sourceKind: "owned" as const};
  const objectId = r2ObjectId(identity, digest);
  return {bucket: "private", object: `private-originals/${objectId}`, objectId, sha256: digest, ...identity,
    ...(preview ? {previewObjectId: objectId} : {})};
};
const ORIGINAL = assetUpload("original/neon.jpg", "a".repeat(64));
const THUMB = assetUpload("thumb_neon.jpg", "b".repeat(64), true);

const neon = (patch: Doc = {}): Doc => ({id: "NEON", creatorUid: "maker", review: true, wallpaper_provider: "prism",
  collections: ["general"],
  wallpaper_url: "", wallpaper_thumb: ownedThumbnailUrl(THUMB), wallpaper_path: "", wallpaper_sha: "", thumb_path: "",
  thumb_sha: "", originalProtected: true, originalObjectId: ORIGINAL.objectId, title: "Neon rain", creatorPrice: 40,
  ...patch});
const asset = (patch: Doc = {}): Doc => ({status: "ready", canonicalPath: "walls/neon",
  incarnation: 1, incarnationNanos: 1_000_000, provenance: {kind: "owned", uid: "maker"},
  original: ORIGINAL, thumb: THUMB,
  ...patch});

function registerAsset(store: Store, manifest: Doc): void {
  for (const part of [manifest.original, manifest.thumb] as Doc[]) {
    store.set(`r2ObjectRegistry/${part.objectId}`, {...part, status: "active", uploadId: part.uploadId ?? "imported"});
  }
}

function setup(t: TestContext, extra: Record<string, Doc> = {}, wall: Doc = {},
  dbOptions: {failCommits?: number; failCommitAt?: number; retryCommitAt?: number; beforeRetry?: () => void} = {}) {
  const previousEnv = {...process.env};
  t.after(() => {
    process.env = previousEnv;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: "https://images.example.com", GH_REPO_WALLS: "walls"});
  resetEconomyCache();
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const account = {createdMs: NOW.getTime() - 8 * DAY, verified: true};
  const disabled = new Set<string>();
  const hooks: {beforeDisabled?: () => void} = {};
  t.mock.method(creatorWallIo, "account", async () => ({...account}));
  t.mock.method(creatorWallIo, "disabled", async (uid: string) => {
    hooks.beforeDisabled?.();
    hooks.beforeDisabled = undefined;
    return disabled.has(uid);
  });
  const store: Store = installFakeDb(t, {
    "walls/neon": neon(wall),
    "ownedAssets/NEON": asset(),
    "usersv2/fan": {coins: 200},
    "usersv2/maker": {coins: 5},
    "economyConfig/current": {flags: {creatorWallsEnabled: true}},
    ...extra,
  }, undefined, dbOptions);
  registerAsset(store, store.get("ownedAssets/NEON") ?? asset());
  return {store, account, disabled, hooks};
}

const unlock = (data: Doc, uid = "fan") => unlockCreatorWall.run({auth: {uid, token: {}}, data} as never);
const unlockData = (patch: Doc = {}): Doc => ({wallId: "neon", expectedPrice: 40, requestId: REQ, ...patch});
const setPrice = (data: Doc, auth: Doc = {uid: "maker", token: {}}) => setWallPrice.run({auth, data} as never);
const coins = (store: Store, uid: string) => store.get(`usersv2/${uid}`)?.coins;
const snapshot = (store: Store) => structuredClone([...store.entries()]);

test("an unlock moves both balances and writes both ledger rows, the marker, the sales totals and the caps", async (t) => {
  const {store} = setup(t);
  const result = await unlock(unlockData());
  assert.equal(result.success, true);
  assert.equal(result.changed, true);
  assert.equal(result.insufficientBalance, false);
  assert.equal(coins(store, "fan"), 160);
  assert.equal(coins(store, "maker"), 33);
  const buy = store.get(BUY_TX);
  assert.equal(buy?.action, "creatorWallUnlock");
  assert.equal(buy?.delta, -40);
  assert.equal(buy?.counterpartyUid, "maker");
  assert.equal(buy?.price, 40);
  assert.equal(buy?.creatorShare, 28);
  const sale = store.get(SALE_TX);
  assert.equal(sale?.action, "creatorWallSale");
  assert.equal(sale?.delta, 28);
  assert.equal(store.get("usersv2/fan/creatorWallUnlocks/neon")?.wallDocId, "neon");
  const sales = store.get("creatorSales/maker");
  assert.equal(sales?.count, 1);
  assert.equal(sales?.coins, 28);
  assert.deepEqual(sales?.walls, {neon: {count: 1, coins: 28}});
  assert.equal(store.get(`creatorWallSaleDaily/buy_fan_${TODAY}`)?.count, 1);
  assert.equal(store.get(`creatorWallSaleDaily/pair_fan_maker_${TODAY}`)?.count, 1);
  assert.equal(store.get(`creatorWallSaleDaily/sell_maker_${TODAY}`)?.coins, 28);
});

test("a retry with the same requestId returns the stored result and changes nothing", async (t) => {
  const {store} = setup(t);
  const first = await unlock(unlockData());
  const before = snapshot(store);
  const second = await unlock(unlockData());
  assert.deepEqual(second, first);
  assert.deepEqual(snapshot(store), before);
  assert.equal(coins(store, "fan"), 160);
  assert.equal(coins(store, "maker"), 33);
});

test("a replay after refund and wall recreation does not report the old unlock as current", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 1);
  store.delete("walls/neon");
  store.set("walls/neon", neon());
  const result = await unlock(unlockData());
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_unavailable");
  assert.equal(coins(store, "fan"), 200);
  assert.equal(store.get("usersv2/fan/creatorWallUnlocks/neon")?.refundedAt !== undefined, true);
});

test("a requestId already used for another wall is rejected without another charge", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  const before = snapshot(store);
  await assert.rejects(unlock(unlockData({wallId: "other"})), {code: "already-exists"});
  assert.deepEqual(snapshot(store), before);
});

test("a retry after a failed commit completes once with the same requestId", async (t) => {
  const {store} = setup(t, {}, {}, {failCommitAt: 2});
  await assert.rejects(unlock(unlockData()), /injected transaction commit failure/);
  assert.equal(coins(store, "fan"), 200);
  const result = await unlock(unlockData());
  assert.equal(result.success, true);
  assert.equal(coins(store, "fan"), 160);
  assert.equal(coins(store, "maker"), 33);
});

test("a Firestore callback retry rechecks price and discards every write from its first attempt", async (t) => {
  const holder: {store?: Store} = {};
  const {store: installed} = setup(t, {}, {}, {retryCommitAt: 2, beforeRetry: () => {
    holder.store?.set("walls/neon", neon({creatorPrice: 75}));
  }});
  holder.store = installed;
  const store = installed;
  const result = await unlock(unlockData());
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_price_changed");
  assert.equal(result.price, 75);
  assert.equal(coins(store, "fan"), 200);
  assert.equal(coins(store, "maker"), 5);
  assert.equal(store.has(BUY_TX), false);
  assert.equal(store.has(SALE_TX), false);
  assert.equal(store.has("usersv2/fan/creatorWallUnlocks/neon"), false);
});

test("overlapping unlocks with one requestId charge and write ledgers once", async (t) => {
  const {store} = setup(t);
  const results = await Promise.all([unlock(unlockData()), unlock(unlockData())]);
  assert.equal(results.every((result) => result.success), true);
  assert.equal(coins(store, "fan"), 160);
  assert.equal(coins(store, "maker"), 33);
  assert.equal([...store.values()].filter((doc) => doc.action === "creatorWallUnlock").length, 1);
  assert.equal([...store.values()].filter((doc) => doc.action === "creatorWallSale").length, 1);
});

test("overlapping unlocks with different requestIds charge the wall once", async (t) => {
  const {store} = setup(t);
  const results = await Promise.all([unlock(unlockData()), unlock(unlockData({requestId: "request_0002"}))]);
  assert.equal(results.filter((result) => result.success && result.changed).length, 1);
  assert.equal(results.filter((result) => result.reason === "already_unlocked").length, 1);
  assert.equal(coins(store, "fan"), 160);
  assert.equal(coins(store, "maker"), 33);
  assert.equal([...store.values()].filter((doc) => doc.action === "creatorWallUnlock").length, 1);
  assert.equal([...store.values()].filter((doc) => doc.action === "creatorWallSale").length, 1);
});

test("a creator identity change between lookup and transaction prevents the sale", async (t) => {
  const {store, hooks} = setup(t);
  hooks.beforeDisabled = () => store.set("walls/neon", neon({creatorUid: "replacement"}));
  const result = await unlock(unlockData());
  assert.equal(result.reason, "creator_wall_unavailable");
  assert.equal(coins(store, "fan"), 200);
  assert.equal(store.has(BUY_TX), false);
});

test("a price change between lookup and transaction is reported without charging", async (t) => {
  const {store, hooks} = setup(t);
  hooks.beforeDisabled = () => store.set("walls/neon", neon({creatorPrice: 75}));
  const result = await unlock(unlockData());
  assert.equal(result.reason, "creator_wall_price_changed");
  assert.equal(result.price, 75);
  assert.equal(coins(store, "fan"), 200);
  assert.equal(store.has(BUY_TX), false);
});

test("a second unlock of the same wall with a new requestId returns already_unlocked and moves no coins", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  const before = snapshot(store);
  const again = await unlock(unlockData({requestId: "request_0002"}));
  assert.equal(again.success, true);
  assert.equal(again.changed, false);
  assert.equal(again.reason, "already_unlocked");
  assert.equal(again.delta, 0);
  assert.deepEqual(snapshot(store), before);
});

test("a buyer short of the price is refused with insufficientBalance and nothing is written", async (t) => {
  const {store} = setup(t, {"usersv2/fan": {coins: 30}});
  const before = snapshot(store);
  const result = await unlock(unlockData());
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_insufficient_balance");
  assert.equal(result.insufficientBalance, true);
  assert.deepEqual(snapshot(store), before);
  assert.equal(coins(store, "fan"), 30);
});

test("a creator cannot buy their own wall", async (t) => {
  const {store} = setup(t);
  const before = snapshot(store);
  const result = await unlock(unlockData(), "maker");
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_self");
  assert.deepEqual(snapshot(store), before);
});

test("a block in either direction between buyer and creator refuses the unlock", async (t) => {
  const {store} = setup(t);
  const before = snapshot(store);
  for (const path of ["usersv2/maker/blockedUsers/fan", "usersv2/fan/blockedUsers/maker"]) {
    store.set(path, {});
    const result = await unlock(unlockData());
    assert.equal(result.success, false, path);
    assert.equal(result.reason, "creator_wall_blocked", path);
    store.delete(path);
  }
  assert.deepEqual(snapshot(store), before);
});

test("the buyer, pair and creator daily caps each refuse the unlock", async (t) => {
  const {store} = setup(t);
  const before = snapshot(store);
  const cases: Array<[string, Doc, string]> = [
    [`creatorWallSaleDaily/buy_fan_${TODAY}`, {day: TODAY, count: 10}, "creator_wall_daily_limit"],
    [`creatorWallSaleDaily/pair_fan_maker_${TODAY}`, {day: TODAY, count: 3}, "creator_wall_pair_limit"],
    [`creatorWallSaleDaily/sell_maker_${TODAY}`, {day: TODAY, coins: 480}, "creator_wall_creator_limit"],
  ];
  for (const [path, cap, reason] of cases) {
    store.set(path, cap);
    const result = await unlock(unlockData());
    assert.equal(result.success, false, reason);
    assert.equal(result.reason, reason);
    store.delete(path);
  }
  assert.deepEqual(snapshot(store), before);
});

test("another ready manifest cannot serve the same retained original", async (t) => {
  const {store} = setup(t);
  store.set("ownedAssets/shared", {...asset(), canonicalPath: "walls/other"});
  const before = snapshot(store);
  const result = await unlock(unlockData());
  assert.equal(result.reason, "creator_wall_unavailable");
  assert.deepEqual(snapshot(store), before);
});

test("another ready manifest with a different object id cannot serve the same original bytes", async (t) => {
  const {store} = setup(t);
  const manifest = asset();
  store.set("ownedAssets/shared", {...manifest, canonicalPath: "walls/other",
    original: {...manifest.original as Doc, objectId: "9".repeat(64)}});
  const before = snapshot(store);
  const result = await unlock(unlockData());
  assert.equal(result.reason, "creator_wall_unavailable");
  assert.deepEqual(snapshot(store), before);
});

test("a held wall cannot be bought", async (t) => {
  const {store} = setup(t, {}, {review: false, heldForReview: true});
  const before = snapshot(store);
  const result = await unlock(unlockData());
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_unavailable");
  assert.deepEqual(snapshot(store), before);
});

test("a deleted, closed or disabled creator cannot be bought from, and no coins move", async (t) => {
  const {store, disabled} = setup(t);
  store.set("usersv2/maker", {coins: 5, deleted: true});
  assert.equal((await unlock(unlockData())).reason, "creator_wall_unavailable");
  store.set("usersv2/maker", {coins: 5});
  store.set("creatorDeletionState/maker", {closed: true});
  assert.equal((await unlock(unlockData())).reason, "creator_wall_unavailable");
  store.delete("creatorDeletionState/maker");
  disabled.add("maker");
  assert.equal((await unlock(unlockData())).reason, "creator_wall_unavailable");
  assert.equal(coins(store, "fan"), 200);
  assert.equal(coins(store, "maker"), 5);
  assert.equal(store.has(BUY_TX), false);
});

test("a price that differs from expectedPrice is refused and the buyer sees the new price", async (t) => {
  const {store} = setup(t);
  const before = snapshot(store);
  const result = await unlock(unlockData({expectedPrice: 20}));
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_price_changed");
  assert.equal(result.price, 40);
  assert.deepEqual(snapshot(store), before);
});

test("creator shares round down at 70 percent, and a 75 coin unlock splits 23 to Prism and 52 to the creator", async (t) => {
  assert.equal(CREATOR_SHARE_PERCENT, 70);
  assert.equal(UNLOCKS_PER_BUYER_PER_DAY, 10);
  assert.equal(UNLOCKS_PER_PAIR_PER_DAY, 3);
  assert.equal(CREATOR_SALE_COINS_PER_DAY, 500);
  assert.equal(creatorShareOf(20), 14);
  assert.equal(creatorShareOf(40), 28);
  assert.equal(creatorShareOf(75), 52);
  assert.equal(creatorShareOf(10), 7);
  assert.equal(creatorShareOf(1000), 700);
  const {store} = setup(t, {}, {creatorPrice: 75});
  const result = await unlock(unlockData({expectedPrice: 75}));
  assert.equal(result.success, true);
  assert.equal(coins(store, "fan"), 125);
  assert.equal(coins(store, "maker"), 57);
  assert.equal(store.get(BUY_TX)?.delta, -75);
  assert.equal(store.get(SALE_TX)?.delta, 52);
});

test("with the server switch off, an unlock is refused and nothing moves", async (t) => {
  const {store} = setup(t, {"economyConfig/current": {flags: {creatorWallsEnabled: false}}});
  const before = snapshot(store);
  const result = await unlock(unlockData());
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_disabled");
  assert.deepEqual(snapshot(store), before);
});

test("walls that are not for sale are refused and no coins move", async (t) => {
  const {store} = setup(t);
  const cases: Array<[string, Doc, Doc]> = [
    ["studio origin", {origin: "studio"}, {}],
    ["AI generated", {isAiGenerated: true}, {}],
    ["legacy AI metadata", {aiMetadata: {model: "legacy"}}, {}],
    ["Studio account", {email: "studio@prismwalls.com"}, {}],
    ["remix", {remixOf: "other-wall"}, {}],
    ["public URL", {wallpaper_url: "https://cdn.example.com/neon.jpg"}, {}],
    ["GitHub original", {}, {provenance: {kind: "github", uid: "maker"}}],
    ["wrong incarnation", {}, {incarnation: 2}],
    ["leaked original path", {wallpaper_path: "original.jpg"}, {}],
    ["duplicate wall alias", {}, {}],
    ["no price", {creatorPrice: undefined}, {}],
  ];
  for (const [name, wall, manifest] of cases) {
    store.set("walls/neon", neon(wall));
    store.set("ownedAssets/NEON", asset(manifest));
    if (name === "duplicate wall alias") store.set("walls/alias", {...neon(), id: "NEON"});
    const result = await unlock(unlockData());
    assert.equal(result.success, false, name);
    assert.equal(result.reason, "creator_wall_unavailable", name);
    assert.equal(coins(store, "fan"), 200, name);
    store.delete("walls/alias");
  }
  assert.equal(store.has(BUY_TX), false);
});

test("a buyer who is unverified, or younger than 7 days, is refused", async (t) => {
  const {store, account} = setup(t);
  account.verified = false;
  assert.equal((await unlock(unlockData())).reason, "creator_wall_buyer_ineligible");
  account.verified = true;
  account.createdMs = NOW.getTime() - 6 * DAY;
  assert.equal((await unlock(unlockData())).reason, "creator_wall_buyer_too_new");
  assert.equal(coins(store, "fan"), 200);
  assert.equal(store.has(BUY_TX), false);
});

test("bad input is refused before any read of the wall or balances", async (t) => {
  const {store} = setup(t);
  const before = snapshot(store);
  await assert.rejects(unlockCreatorWall.run({data: unlockData()} as never), {code: "unauthenticated"});
  for (const patch of [{wallId: "a/b"}, {expectedPrice: 5}, {expectedPrice: "40"}, {requestId: "x"}]) {
    await assert.rejects(unlock(unlockData(patch)), {code: "invalid-argument"});
  }
  assert.deepEqual(snapshot(store), before);
});

test("a refund of a deleted wall returns the price, takes back the creator share, and stamps the marker once", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 1);
  assert.equal(coins(store, "fan"), 200);
  assert.equal(coins(store, "maker"), 5);
  assert.notEqual(store.get("usersv2/fan/creatorWallUnlocks/neon")?.refundedAt, undefined);
  const refund = [...store.values()].find((doc) => doc.action === "creatorWallRefund");
  const reversal = [...store.values()].find((doc) => doc.action === "creatorWallSaleReversal");
  assert.equal(refund?.delta, 40);
  assert.equal(reversal?.delta, -28);
  assert.equal(store.get("creatorSales/maker")?.count, 0);
  assert.equal(store.get("creatorSales/maker")?.coins, 0);
  const weekTotals = (store.get("creatorSales/maker")?.weeks as Record<string, unknown> | undefined)?.["2026-W47"];
  assert.deepEqual(weekTotals, {count: 0, coins: 0});
  const before = snapshot(store);
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 0);
  assert.deepEqual(snapshot(store), before);
});

test("a refund takes only the creator's remaining balance when the creator has spent part of it", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  store.set("usersv2/maker", {coins: 10});
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 1);
  assert.equal(coins(store, "fan"), 200);
  assert.equal(coins(store, "maker"), 0);
  assert.equal([...store.values()].find((doc) => doc.action === "creatorWallSaleReversal")?.delta, -10);
});

test("a buyer deletion barrier preserves the creator's sale and does not refund a closing account", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  store.set("creatorDeletionState/fan", {closed: true});
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 1);
  assert.equal(coins(store, "fan"), 160);
  assert.equal(coins(store, "maker"), 33);
  assert.equal(store.get("creatorSales/maker")?.coins, 28);
});

test("the generic refund path refuses a creator wall debit", async (t) => {
  const {store} = setup(t);
  await unlock(unlockData());
  const debit = store.get(BUY_TX);
  assert.ok(debit);
  assert.throws(() => refundableDelta(debit, "fan", NOW.getTime()), {code: "failed-precondition"});
});

test("a deleted-wall event cannot refund a sale from a recreated wall incarnation", async (t) => {
  const {store} = setup(t);
  store.set("usersv2/fan/creatorWallUnlocks/neon", {wallId: "NEON", wallDocId: "neon", creatorUid: "maker",
    price: 40, creatorShare: 28, transactionId: "old", wallIncarnation: 2, wallIncarnationNanos: 1_000_000,
    pendingRefundKey: pendingRefundKey("neon", 2),
    unlockedAt: admin.firestore.Timestamp.fromMillis(NOW.getTime())});
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 0);
  assert.equal(coins(store, "fan"), 200);
  assert.equal(store.get("usersv2/fan/creatorWallUnlocks/neon")?.refundedAt, undefined);
});

test("refund pagination resumes after a transaction failure on the second page", async (t) => {
  const {store} = setup(t, {}, {}, {failCommitAt: 102});
  for (let index = 0; index < 105; index++) {
    const uid = `buyer_${index}`;
    store.set(`usersv2/${uid}`, {coins: 0});
    store.set(`usersv2/${uid}/creatorWallUnlocks/neon`, {wallId: "NEON", wallDocId: "neon", creatorUid: "maker",
      price: 40, creatorShare: 28, transactionId: `old_${index}`, wallIncarnation: 1, wallIncarnationNanos: 1_000_000,
      pendingRefundKey: pendingRefundKey(),
      unlockedAt: admin.firestore.Timestamp.fromMillis(NOW.getTime())});
  }
  await assert.rejects(refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), /injected transaction commit failure/);
  assert.equal(await refundDeletedWall("neon", {millis: 1, nanos: 1_000_000}), 4);
  assert.equal([...store.entries()].filter(([path]) => path.endsWith("/creatorWallUnlocks/neon"))
    .filter(([, marker]) => marker.refundedAt !== undefined).length, 105);
  assert.equal([...store.entries()].filter(([path]) => path.startsWith("usersv2/buyer_") && path.split("/").length === 2)
    .every(([, user]) => user.coins === 40), true);
  assert.equal([...store.values()].filter((doc) => doc.action === "creatorWallRefund").length, 105);
});

test("the owner sets a price on an approved original", async (t) => {
  const {store} = setup(t, {}, {creatorPrice: undefined});
  const result = await setPrice({wallId: "neon", price: 40});
  assert.equal(result.success, true);
  assert.equal(result.reason, "creator_wall_price_set");
  assert.equal(result.price, 40);
  assert.equal(store.get("walls/neon")?.creatorPrice, 40);
});

test("a price that is not on the price list is invalid-argument", async (t) => {
  const {store} = setup(t, {}, {creatorPrice: undefined});
  await assert.rejects(setPrice({wallId: "neon", price: 30}), {code: "invalid-argument"});
  assert.equal(store.get("walls/neon")?.creatorPrice, undefined);
});

test("a signed-in user who does not own the wall is refused as not the owner", async (t) => {
  setup(t, {}, {creatorPrice: undefined});
  await assert.rejects(setPrice({wallId: "neon", price: 40}, {uid: "fan", token: {}}),
    (err: {code?: string; message?: string}) => err.code === "permission-denied" &&
      err.message === "creator_wall_not_owner");
});

test("price 0 removes the price and leaves buyers' unlocks in place", async (t) => {
  const {store} = setup(t);
  const result = await setPrice({wallId: "neon", price: 0});
  assert.equal(result.success, true);
  assert.equal(result.reason, "creator_wall_price_removed");
  assert.equal(result.price, 0);
  assert.equal(store.get("walls/neon")?.creatorPrice, undefined);
  assert.equal("creatorPrice" in (store.get("walls/neon") ?? {}), false);
});

test("with the server switch off, setting a price is refused", async (t) => {
  const {store} = setup(t, {"economyConfig/current": {flags: {creatorWallsEnabled: false}}}, {creatorPrice: undefined});
  const result = await setPrice({wallId: "neon", price: 40});
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_disabled");
  assert.equal(store.get("walls/neon")?.creatorPrice, undefined);
});

test("a seller younger than 7 days cannot set a price", async (t) => {
  const {store, account} = setup(t, {}, {creatorPrice: undefined});
  account.createdMs = NOW.getTime() - 6 * DAY;
  const result = await setPrice({wallId: "neon", price: 40});
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_seller_too_new");
  assert.equal(store.get("walls/neon")?.creatorPrice, undefined);
});

test("the owner of a pending upload can price it when they have another approved sellable wall", async (t) => {
  const {store} = setup(t, {"walls/pending": {id: "PENDING", review: false, wallpaper_provider: "prism",
    wallpaper_url: "", email: "maker@example.com", title: "Draft"}});
  const result = await setPrice({wallId: "pending", price: 40},
    {uid: "maker", token: {email: "maker@example.com", email_verified: true}});
  assert.equal(result.success, true);
  assert.equal(result.reason, "creator_wall_price_set");
  assert.equal(store.get("walls/pending")?.creatorPrice, 40);
  assert.equal(store.get("walls/pending")?.creatorUid, "maker");
  const pendingOriginal = assetUpload("original/pending.jpg", "9".repeat(64));
  store.set("walls/pending", {...store.get("walls/pending"), review: true, originalProtected: true,
    originalObjectId: pendingOriginal.objectId, wallpaper_thumb: ownedThumbnailUrl(THUMB), wallpaper_path: "",
    wallpaper_sha: "", thumb_path: "", thumb_sha: "", collections: ["general"]});
  store.set("ownedAssets/PENDING", {status: "ready", canonicalPath: "walls/pending",
    incarnation: 1, incarnationNanos: 1_000_000, provenance: {kind: "owned", uid: "maker"},
    original: pendingOriginal,
    thumb: asset().thumb});
  registerAsset(store, store.get("ownedAssets/PENDING") ?? {});
  const purchased = await unlock(unlockData({wallId: "pending"}));
  assert.equal(purchased.success, true, JSON.stringify(purchased));
});

test("seller eligibility pagination finds an approved wall beyond the first page", async (t) => {
  const extra: Record<string, Doc> = {"walls/pending": {id: "PENDING", creatorUid: "maker", review: false,
    wallpaper_provider: "prism", wallpaper_url: ""}, "walls/z-valid": {id: "VALID", creatorUid: "maker",
    review: true, wallpaper_provider: "prism"}};
  for (let index = 0; index < 25; index++) {
    extra[`walls/a_studio_${index}`] = {id: `STUDIO_${index}`, creatorUid: "maker", review: true,
      wallpaper_provider: "prism", origin: "studio"};
  }
  const {store} = setup(t, extra, {origin: "studio"});
  const result = await setPrice({wallId: "pending", price: 40});
  assert.equal(result.success, true);
  assert.equal(store.get("walls/pending")?.creatorPrice, 40);
});

test("a creator with no approved wall cannot set a price", async (t) => {
  const {store} = setup(t, {
    "usersv2/maker2": {coins: 0},
    "walls/draft2": {id: "DRAFT2", creatorUid: "maker2", review: false, wallpaper_provider: "prism", wallpaper_url: ""},
  });
  const result = await setPrice({wallId: "draft2", price: 40}, {uid: "maker2", token: {}});
  assert.equal(result.success, false);
  assert.equal(result.reason, "creator_wall_seller_no_approved_wall");
  assert.equal(store.get("walls/draft2")?.creatorPrice, undefined);
});
