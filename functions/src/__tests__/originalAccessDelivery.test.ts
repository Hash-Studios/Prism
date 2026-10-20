import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {resolveOriginalAccess} from "../originalAccess";
import {signOriginalDelivery} from "../ownedAssetDelivery";
import {DEFAULT_ECONOMY, resetEconomyCache} from "../economy";
import {r2ObjectId} from "../r2Storage";
import {installFakeDb} from "./fakeDb";

function setup(t: Parameters<typeof installFakeDb>[0]) {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  process.env.R2_ACCOUNT_ID = "a".repeat(32);
  process.env.R2_ACCESS_KEY_ID = "access";
  process.env.R2_SECRET_ACCESS_KEY = "secret";
  process.env.R2_PRIVATE_BUCKET = "private-assets";
  process.env.R2_PREVIEW_BUCKET = "public-previews";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
  process.env.GH_REPO_WALLS = "walls";
  resetEconomyCache();
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
  const originalDigest = "b".repeat(64);
  const thumbDigest = "c".repeat(64);
  const sha = "a".repeat(40);
  const originalId = r2ObjectId({uid: "owner", repo: "walls", path: "private/original.jpg", sha, sourceKind: "owned"}, originalDigest);
  const thumbId = r2ObjectId({uid: "owner", repo: "walls", path: "private/thumb_asset.jpg", sha, sourceKind: "owned"}, thumbDigest);
  const original = {repo: "walls", path: "private/original.jpg", sha, uid: "owner", bucket: "private-assets",
    object: `private-originals/${originalId}`, objectId: originalId, sha256: originalDigest, sourceKind: "owned" as const};
  const thumb = {repo: "walls", path: "private/thumb_asset.jpg", sha, uid: "owner", bucket: "private-assets",
    object: `private-originals/${thumbId}`, objectId: thumbId, sha256: thumbDigest, sourceKind: "owned" as const,
    previewObjectId: thumbId};
  const registry = (asset: typeof original | typeof thumb) => ({status: "active", uploadId: "imported",
    sourceKind: "owned", bucket: asset.bucket, object: asset.object, objectId: asset.objectId, sha256: asset.sha256,
    uid: asset.uid, repo: asset.repo, path: asset.path, sha: asset.sha,
    ...("previewObjectId" in asset ? {previewObjectId: asset.previewObjectId} : {})});
  const store = installFakeDb(t, {
    "walls/canonical": {id: "asset", review: true, originalProtected: true, originalObjectId: originalId,
      collections: ["premium"], wallpaper_url: "", wallpaper_thumb: `https://images.example.com/previews/${thumbId}.img`,
      wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""},
    "ownedAssets/asset": {status: "ready", canonicalPath: "walls/canonical", incarnation: 1, incarnationNanos: 1_000_000,
      original, thumb, provenance: {kind: "owned", uid: "owner"}},
    [`r2ObjectRegistry/${originalId}`]: registry(original), [`r2ObjectRegistry/${thumbId}`]: registry(thumb),
    "usersv2/user": {coins: 100}, "usersv2/user/private/economy": {graceDownloadsUsed: 100},
  });
  const signatures: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method !== "HEAD") return new Response(null, {status: 500});
    const objectId = new URL(String(input)).pathname.split("/").pop()!.split(".")[0];
    signatures.push(new Headers(init.headers).get("authorization") ?? "");
    return new Response(null, {status: 200, headers: {"content-length": "100", "x-amz-meta-sha256": originalDigest,
      "x-amz-meta-uid": "owner", "x-amz-meta-objectid": objectId,
      "x-amz-meta-repo64": Buffer.from("walls").toString("base64url"),
      "x-amz-meta-path64": Buffer.from("private/original.jpg").toString("base64url"), "x-amz-meta-gitsha": sha,
      "x-amz-meta-uploadid": "imported"}});
  });
  return {store, signatures, originalId};
}

const request = () => ({auth: {uid: "user", token: {}},
  data: {assetId: "asset", action: "download", requestId: "delivery_request"}, rawRequest: {},
} as Parameters<typeof resolveOriginalAccess.run>[0]);

test("real original delivery keeps both app callable regions", () => {
  assert.deepEqual(resolveOriginalAccess.__endpoint.region, ["asia-south1", "us-central1"]);
});

test("R2 signer grants a redacted original, validates registry, and signs a short-lived private URL", async (t) => {
  const {store, signatures, originalId} = setup(t);
  await signOriginalDelivery("asset");
  const before = Date.now();
  const result = await resolveOriginalAccess.run(request());
  assert(result.status === "granted");
  assert("url" in result && "objectId" in result && "expiresAt" in result);
  assert.match(result.url, /^https:\/\/[-a-f0-9]+\.r2\.cloudflarestorage\.com\/private-assets\/private-originals\//);
  assert.match(result.url, /X-Amz-Expires=119|X-Amz-Expires=120/);
  assert.equal(result.objectId, originalId);
  assert.ok(result.expiresAt > before && result.expiresAt <= Date.now() + 120_000);
  assert.equal(result.basis, "coins");
  assert.equal(result.chargedCoins, DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
  assert.equal(store.get("usersv2/user")?.coins, 100 - result.chargedCoins);
  assert.ok(signatures.every((value) => value.startsWith("AWS4-HMAC-SHA256 ")));
});

test("registry mismatch denies signing and debit", async (t) => {
  const {store, originalId} = setup(t);
  store.set("r2ObjectRegistry/" + originalId, {status: "tombstoned"});
  const before = structuredClone([...store.entries()]);
  await assert.rejects(() => resolveOriginalAccess.run(request()));
  assert.deepEqual([...store.entries()], before);
});

for (const [name, change] of [
  ["missing manifest", undefined],
  ["invalid immutable object", {original: {objectId: "bad"}}],
  ["stale canonical path", {canonicalPath: "walls/replaced"}],
  ["stale wall incarnation", {incarnation: 2}],
  ["wall object identity changed", {wallObjectId: "wrong"}],
] as const) {
  test(`R2 signer fails closed without URL or debit for ${name}`, async (t) => {
    const {store, signatures} = setup(t);
    if (change === undefined) store.delete("ownedAssets/asset");
    else if (name === "wall object identity changed") {
      store.set("walls/canonical", {...store.get("walls/canonical"), originalObjectId: change.wallObjectId});
    } else store.set("ownedAssets/asset", {...store.get("ownedAssets/asset"), ...change});
    const before = structuredClone([...store.entries()]);
    await assert.rejects(() => resolveOriginalAccess.run(request()));
    assert.equal(signatures.length, 0);
    assert.deepEqual([...store.entries()], before);
  });
}
