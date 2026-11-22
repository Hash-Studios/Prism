import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {resetEconomyCache} from "../economy";
import {originalAccessDelivery, resetClassificationCache, resolveOriginalAccess} from "../originalAccess";
import {r2ObjectId} from "../r2Storage";
import {type Doc, installFakeDb} from "./fakeDb";

const SHA = "c".repeat(40);
const ORIGINAL_DIGEST = "b".repeat(64);
const THUMB_DIGEST = "d".repeat(64);
const ORIGINAL_ID = r2ObjectId({uid: "maker", repo: "walls", path: "original/path", sha: SHA, sourceKind: "owned"},
  ORIGINAL_DIGEST);
const THUMB_ID = r2ObjectId({uid: "maker", repo: "walls", path: "thumb_path", sha: SHA, sourceKind: "owned"}, THUMB_DIGEST);
const WALL = "document-not-asset";
const MARKER = `usersv2/user/creatorWallUnlocks/${WALL}`;

function setup(t: TestContext, user: Doc = {}, wall: Doc = {}) {
  const previousEnv = {...process.env};
  t.after(() => {
    process.env = previousEnv;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: "https://images.example.com", GH_REPO_WALLS: "walls"});
  resetEconomyCache();
  resetClassificationCache();
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
  const original = {bucket: "private", object: `private-originals/${ORIGINAL_ID}`, objectId: ORIGINAL_ID,
    sha256: ORIGINAL_DIGEST, uid: "maker", repo: "walls", path: "original/path", sha: SHA, sourceKind: "owned" as const};
  const thumb = {bucket: "private", object: `private-originals/${THUMB_ID}`, objectId: THUMB_ID,
    sha256: THUMB_DIGEST, uid: "maker", repo: "walls", path: "thumb_path", sha: SHA, sourceKind: "owned" as const,
    previewObjectId: THUMB_ID};
  t.mock.method(originalAccessDelivery, "sign", async () => ({url: "https://private.test/signed",
    objectId: ORIGINAL_ID, expiresAt: Date.now() + 60_000}));
  return installFakeDb(t, {
    [`walls/${WALL}`]: {id: "asset", creatorUid: "maker", creatorPrice: 40, review: true, originalProtected: true,
      originalObjectId: ORIGINAL_ID, collections: ["premium"], wallpaper_url: "",
      wallpaper_thumb: `https://images.example.com/previews/${THUMB_ID}.img`, wallpaper_path: "", wallpaper_sha: "",
      thumb_path: "", thumb_sha: "", ...wall},
    "ownedAssets/asset": {status: "ready", canonicalPath: `walls/${WALL}`, incarnation: 1, incarnationNanos: 1_000_000,
      original, thumb},
    [`r2ObjectRegistry/${ORIGINAL_ID}`]: {status: "active", ...original, uploadId: "imported"},
    [`r2ObjectRegistry/${THUMB_ID}`]: {status: "active", ...thumb, uploadId: "imported"},
    "usersv2/user": {coins: 100, ...user},
    "usersv2/user/private/economy": {graceDownloadsUsed: 0},
    "usersv2/maker": {coins: 5},
  });
}

const request = (uid: string) => ({
  auth: {uid, token: {}}, data: {assetId: "asset", action: "download", requestId: "request_123"}, rawRequest: {},
} as Parameters<typeof resolveOriginalAccess.run>[0]);

const markerDoc = (extra: Doc = {}): Doc => ({wallId: "asset", wallDocId: WALL, creatorUid: "maker", price: 40,
  creatorShare: 28, wallIncarnation: 1, wallIncarnationNanos: 1_000_000,
  transactionId: "ctx_cwbuy_user_request_0001", unlockedAt: admin.firestore.Timestamp.now(), ...extra});

test("a stranger cannot get the original of a creator wall, and no coins move", async (t) => {
  const store = setup(t);
  const result = await resolveOriginalAccess.run(request("user"));
  assert.equal(result.status, "creator_locked");
  assert.equal("requiredCoins" in result && result.requiredCoins, 40);
  assert.equal(store.get("usersv2/user")?.coins, 100);
  assert.equal([...store.keys()].some((path) => path.startsWith("coinTransactions/ctx_original_")), false);
});

test("a Pro subscriber who did not buy the wall is still locked out of it", async (t) => {
  const store = setup(t, {premium: true});
  const result = await resolveOriginalAccess.run(request("user"));
  assert.equal(result.status, "creator_locked");
  assert.equal("requiredCoins" in result && result.requiredCoins, 40);
  assert.equal(store.get("usersv2/user")?.coins, 100);
});

test("a buyer with an unlock marker gets the original at 0 coins with basis creator", async (t) => {
  const store = setup(t);
  store.set(MARKER, markerDoc());
  const result = await resolveOriginalAccess.run(request("user"));
  assert.equal(result.status, "granted");
  assert.equal("basis" in result && result.basis, "creator");
  assert.equal("chargedCoins" in result && result.chargedCoins, 0);
  assert.equal(store.get("usersv2/user")?.coins, 100);
});

test("the creator gets their own wall at 0 coins with basis owner", async (t) => {
  const store = setup(t);
  const result = await resolveOriginalAccess.run(request("maker"));
  assert.equal(result.status, "granted");
  assert.equal("basis" in result && result.basis, "owner");
  assert.equal("chargedCoins" in result && result.chargedCoins, 0);
  assert.equal(store.get("usersv2/maker")?.coins, 5);
});

test("a buyer whose marker was refunded is locked out again", async (t) => {
  const store = setup(t);
  store.set(MARKER, markerDoc());
  assert.equal((await resolveOriginalAccess.run(request("user"))).status, "granted");
  store.set(MARKER, markerDoc({refundedAt: admin.firestore.Timestamp.now()}));
  const result = await resolveOriginalAccess.run(request("user"));
  assert.equal(result.status, "creator_locked");
  assert.equal("requiredCoins" in result && result.requiredCoins, 40);
});

test("a wall held for review cannot deliver a previously unlocked creator original", async (t) => {
  const store = setup(t, {}, {heldForReview: true});
  store.set(MARKER, markerDoc());

  await assert.rejects(() => resolveOriginalAccess.run(request("user")), {code: "failed-precondition"});

  assert.equal(store.get("usersv2/user")?.coins, 100);
  assert.equal([...store.keys()].some((path) => path.startsWith("coinTransactions/ctx_original_")), false);
});

test("a batch with one locked creator wall grants neither delivery nor receipt", async (t) => {
  const store = setup(t);
  const wall = store.get(`walls/${WALL}`);
  assert.ok(wall);
  store.set("walls/second", {...wall, id: "second"});
  store.set("ownedAssets/second", {...store.get("ownedAssets/asset"), canonicalPath: "walls/second"});
  store.set(MARKER, markerDoc());
  const batch = {auth: {uid: "user", token: {}}, data: {assets: [
    {assetId: "asset", action: "set"}, {assetId: "second", action: "set"}], requestId: "batch_1234"}, rawRequest: {}} as
      Parameters<typeof resolveOriginalAccess.run>[0];

  const result = await resolveOriginalAccess.run(batch);

  assert.equal(result.status, "creator_locked");
  assert.equal(store.get("usersv2/user")?.coins, 100);
  assert.equal([...store.keys()].some((path) => path.startsWith("coinTransactions/ctx_original_")), false);
});

test("creator original receipt replay returns the same entitlement without a second charge", async (t) => {
  const store = setup(t);
  store.set(MARKER, markerDoc());

  const first = await resolveOriginalAccess.run(request("user"));
  assert.equal(first.status, "granted");
  const balance = store.get("usersv2/user")?.coins;
  const replay = await resolveOriginalAccess.run(request("user"));

  assert.equal(replay.status, "granted");
  assert.equal("basis" in replay && replay.basis, "creator");
  assert.equal(store.get("usersv2/user")?.coins, balance);
});

test("a buyer keeps free access after the creator removes the wall price", async (t) => {
  const store = setup(t);
  store.set(MARKER, markerDoc());
  const wall = store.get(`walls/${WALL}`);
  assert.ok(wall);
  delete wall.creatorPrice;
  store.set(`walls/${WALL}`, wall);

  const result = await resolveOriginalAccess.run(request("user"));

  assert.equal(result.status, "granted");
  assert.equal("basis" in result && result.basis, "creator");
  assert.equal("chargedCoins" in result && result.chargedCoins, 0);
  assert.equal(store.get("usersv2/user")?.coins, 100);
});

test("a creator-basis receipt is not replayed after its marker is refunded and the price is removed", async (t) => {
  const store = setup(t);
  store.set(MARKER, markerDoc());
  const first = await resolveOriginalAccess.run(request("user"));
  assert.equal(first.status, "granted");
  const wall = store.get(`walls/${WALL}`);
  assert.ok(wall);
  delete wall.creatorPrice;
  store.set(`walls/${WALL}`, wall);
  store.set(MARKER, markerDoc({refundedAt: admin.firestore.Timestamp.now()}));

  await assert.rejects(() => resolveOriginalAccess.run(request("user")), {code: "failed-precondition"});
  assert.equal(store.get("usersv2/user")?.coins, 100);
});

test("an owner-basis receipt is not replayed after the wall changes ownership", async (t) => {
  const store = setup(t);
  const first = await resolveOriginalAccess.run(request("maker"));
  assert.equal(first.status, "granted");
  const wall = store.get(`walls/${WALL}`);
  assert.ok(wall);
  delete wall.creatorPrice;
  wall.creatorUid = "new-owner";
  store.set(`walls/${WALL}`, wall);

  await assert.rejects(() => resolveOriginalAccess.run(request("maker")), {code: "failed-precondition"});
});
