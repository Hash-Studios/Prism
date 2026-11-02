import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {DEFAULT_ECONOMY, resetEconomyCache} from "../economy";
import {originalAccessDelivery, resetClassificationCache, resolveOriginalAccess} from "../originalAccess";
import {R2Storage, r2ObjectId} from "../r2Storage";
import {installFakeDb, type Doc} from "./fakeDb";

const DESKTOP_SHA = "a".repeat(64);
const WIDE_SHA = "b".repeat(64);
const PHONE_SHA = "c".repeat(64);
const THUMB_SHA = "d".repeat(64);
const PREVIEW = "https://images.example.com";
const DESKTOP_OBJECT = `desktop-originals/asset/${DESKTOP_SHA}.jpg`;
const PHONE_OBJECT_ID = r2ObjectId({uid: "owner", repo: "walls", path: "original/path", sha: "e".repeat(40),
  sourceKind: "owned"}, PHONE_SHA);

function request(data: Doc = {}) {
  return {auth: {uid: "user", token: {}}, data: {assetId: "asset", action: "set", requestId: "desktop_123",
    variant: "desktop", ...data}, rawRequest: {}} as unknown as Parameters<typeof resolveOriginalAccess.run>[0];
}

function setup(t: TestContext, desktopHead: {size: number; sha256: string} | null) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: PREVIEW, GH_REPO_WALLS: "walls"});
  resetEconomyCache();
  resetClassificationCache();
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
  const original = {bucket: "private", object: `private-originals/${PHONE_OBJECT_ID}`, objectId: PHONE_OBJECT_ID,
    sha256: PHONE_SHA, uid: "owner", repo: "walls", path: "original/path", sha: "e".repeat(40),
    sourceKind: "owned" as const};
  const thumbId = r2ObjectId({uid: "owner", repo: "walls", path: "thumb_wall.png", sha: "f".repeat(40),
    sourceKind: "owned"}, THUMB_SHA);
  const thumb = {bucket: "private", object: `private-originals/${thumbId}`, objectId: thumbId,
    sha256: THUMB_SHA, uid: "owner", repo: "walls", path: "thumb_wall.png", sha: "f".repeat(40),
    sourceKind: "owned" as const, previewObjectId: thumbId};
  const desktop = {object: DESKTOP_OBJECT, sha256: DESKTOP_SHA, width: 2560, height: 1600, bytes: 1234};
  const wide = {object: `desktop-originals/asset/${WIDE_SHA}.jpg`, sha256: WIDE_SHA,
    width: 2560, height: 1440, bytes: 1200};
  const desktopThumb = `${PREVIEW}/previews/desktop-${THUMB_SHA}.jpg`;
  const wall = {id: "asset", review: true, originalProtected: true, originalObjectId: PHONE_OBJECT_ID,
    collections: ["premium"], wallpaper_url: "", wallpaper_thumb: `${PREVIEW}/previews/${thumbId}.img`,
    wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: "",
    desktopVariant: {v: DESKTOP_SHA.slice(0, 16), width: 2560, height: 1600, wideHeight: 1440, thumb: desktopThumb}};
  const store = installFakeDb(t, {
    "walls/wall-doc": wall,
    "ownedAssets/asset": {status: "ready", canonicalPath: "walls/wall-doc", incarnation: 1,
      incarnationNanos: 1_000_000, original, thumb},
    "desktopCompanions/asset": {status: "ready", original: desktop, wide},
    [`r2ObjectRegistry/${PHONE_OBJECT_ID}`]: {status: "active", ...original, uploadId: "imported"},
    [`r2ObjectRegistry/${thumbId}`]: {status: "active", ...thumb, uploadId: "imported"},
    "usersv2/user": {coins: 100},
    "usersv2/user/private/economy": {graceDownloadsUsed: 0},
  });
  t.mock.method(R2Storage.prototype, "head", async (_bucket: string, object: string) => {
    assert.equal(object, DESKTOP_OBJECT);
    return desktopHead;
  });
  t.mock.method(originalAccessDelivery, "sign", async () => ({url: "https://private.test/phone",
    objectId: PHONE_OBJECT_ID, expiresAt: Date.now() + 60_000}));
  return {store, desktop};
}

test("desktop signing refuses a missing or mismatched R2 HEAD before charging or issuing a receipt", async (t) => {
  for (const [name, head] of [["missing", null], ["wrong digest", {size: 1234, sha256: "f".repeat(64)}],
    ["wrong size", {size: 1235, sha256: DESKTOP_SHA}]] as const) {
    await t.test(name, async (subtest) => {
      const {store} = setup(subtest, head);

      await assert.rejects(() => resolveOriginalAccess.run(request()), {code: "unavailable"});

      assert.equal(store.get("usersv2/user")?.coins, 100);
      assert.equal(store.get("usersv2/user/private/economy")?.graceDownloadsUsed, 0);
      assert.equal([...store.keys()].some((key) => key.startsWith("coinTransactions/ctx_original_")), false);
    });
  }
});

test("desktop set quote and acquire use the same server price and bind replay to the desktop object", async (t) => {
  const {store} = setup(t, {size: 1234, sha256: DESKTOP_SHA});
  const quote = await resolveOriginalAccess.run(request({mode: "quote"}));
  const expectedPrice = DEFAULT_ECONOMY.spend.premiumWallpaperDownload;
  assert.deepEqual(quote, {status: "quoted", assetId: "asset", action: "set", objectId: DESKTOP_SHA,
    requiredCoins: expectedPrice, currentBalance: 100, basis: "coins"});

  const acquired = await resolveOriginalAccess.run(request({maxCoins: expectedPrice}));
  assert.equal(acquired.status, "granted");
  assert.equal("objectId" in acquired && acquired.objectId, DESKTOP_SHA);
  assert.equal("chargedCoins" in acquired && acquired.chargedCoins, expectedPrice);
  const balanceAfterAcquire = store.get("usersv2/user")?.coins;

  const replay = await resolveOriginalAccess.run(request({maxCoins: 0}));
  assert.equal(replay.status, "granted");
  assert.equal("objectId" in replay && replay.objectId, DESKTOP_SHA);
  assert.equal(store.get("usersv2/user")?.coins, balanceAfterAcquire);
  assert.equal((await resolveOriginalAccess.run(request({mode: "quote"}))).requiredCoins, 0);
  await assert.rejects(() => resolveOriginalAccess.run(request({variant: undefined})), {code: "failed-precondition"});
});
