import assert from "node:assert/strict";
import test from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {resolveOriginalAccess} from "../originalAccess";
import {DEFAULT_ECONOMY, resetEconomyCache} from "../economy";
import {installFakeDb} from "./fakeDb";

function setup(t: Parameters<typeof installFakeDb>[0], user = {}, privateData = {}, collections = ["premium"]) {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  process.env.OWNED_ASSET_BUCKET = "private-test";
  process.env.OWNED_THUMBNAIL_BASE_URL = "https://example.com/ownedThumbnail";
  process.env.GH_REPO_WALLS = "walls";
  resetEconomyCache();
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {
    premiumCollections: {defaultValue: {value: "[\"premium\"]"}},
  }}));
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("Original delivery must not fetch the public origin");
  });
  const asset = (path: string, owned = false) => ({repo: "walls", path, sha: "a".repeat(40), uid: "owner",
    bucket: "private-test", generation: "42", sha256: "b".repeat(64),
    ...(owned ? {sourceKind: "owned"} : {}),
    object: `${owned ? "private-originals" : "retained"}/${createHash("sha256").update(`walls\0${path}\0${"a".repeat(40)}`).digest("hex")}`});
  const original = asset("private/original.jpg", true);
  const store = installFakeDb(t, {
    "walls/canonical": {id: "asset", review: true, originalProtected: true, originalGeneration: "42",
      collections, wallpaper_url: "", wallpaper_thumb: "https://example.com/ownedThumbnail/asset",
      wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""},
    "ownedAssets/asset": {status: "ready", canonicalPath: "walls/canonical", incarnation: 1,
      incarnationNanos: 1_000_000, original, thumb: asset("private/thumb.jpg"),
      provenance: {kind: "owned", uid: "owner"}},
    "usersv2/user": {coins: 100, ...user},
    "usersv2/user/private/economy": {graceDownloadsUsed: 100, ...privateData},
  });
  const target = admin.storage().bucket("private-test");
  const file = target.file(original.object);
  t.mock.method(admin.storage(), "bucket", () => target);
  t.mock.method(target, "file", (path: string, options?: {generation?: string | number}) => {
    assert.equal(path, original.object);
    assert.equal(options?.generation, "42");
    return file;
  });
  t.mock.method(file, "getMetadata", async () => [{generation: "42", metadata: {sha256: original.sha256}}]);
  const signed = t.mock.method(file, "getSignedUrl", async (options: {
    version?: string; action?: string; expires?: unknown; queryParams?: {generation?: string};
  }) => {
    assert.equal(options.version, "v4");
    assert.equal(options.action, "read");
    assert.equal(options.queryParams?.generation, "42");
    assert.equal(typeof options.expires, "number");
    return ["https://storage.example/pinned-original"];
  });
  return {store, signed};
}

const request = () => ({auth: {uid: "user", token: {}},
  data: {assetId: "asset", action: "download", requestId: "delivery_request"}, rawRequest: {},
} as Parameters<typeof resolveOriginalAccess.run>[0]);

test("real original delivery keeps both app callable regions", () => {
  assert.deepEqual(resolveOriginalAccess.__endpoint.region, ["asia-south1", "us-central1"]);
});

for (const [name, user, privateData, collections, basis, cost] of [
  ["Pro", {premium: true}, {}, ["premium"], "pro", 0],
  ["pass", {}, {passes: {premiumPassUntil: Date.now() + 600_000}}, ["premium"], "pass", 0],
  ["free grace", {}, {graceDownloadsUsed: 0}, ["nature"], "grace", 0],
  ["coin purchase", {}, {}, ["premium"], "coins", DEFAULT_ECONOMY.spend.premiumWallpaperDownload],
] as const) {
  test(`real signer grants a redacted approved original for ${name}`, async (t) => {
    const {store, signed} = setup(t, user, privateData, [...collections]);
    const before = Date.now();
    const result = await resolveOriginalAccess.run(request());
    assert(result.status === "granted");
    assert("url" in result && "generation" in result && "expiresAt" in result);
    assert.equal(result.url, "https://storage.example/pinned-original");
    assert.equal(result.generation, "42");
    assert.equal(typeof result.expiresAt, "number");
    assert.ok(result.expiresAt > before && result.expiresAt <= Date.now() + 120_000);
    assert.equal(result.basis, basis);
    assert.equal(result.chargedCoins, cost);
    assert.equal(store.get("usersv2/user")?.coins, 100 - cost);
    assert.equal(signed.mock.callCount(), 1);
  });
}

for (const [name, change] of [
  ["missing manifest", undefined],
  ["invalid private object", {original: {generation: "42", path: "private/original.jpg", sha: "a".repeat(40)}}],
  ["stale canonical path", {canonicalPath: "walls/replaced"}],
  ["stale incarnation", {incarnation: 2}],
] as const) {
  test(`real signer fails closed without URL or debit for ${name}`, async (t) => {
    const {store, signed} = setup(t);
    if (change === undefined) store.delete("ownedAssets/asset");
    else store.set("ownedAssets/asset", {...store.get("ownedAssets/asset"), ...change});
    const before = structuredClone([...store.entries()]);
    await assert.rejects(() => resolveOriginalAccess.run(request()));
    assert.equal(signed.mock.callCount(), 0);
    assert.deepEqual([...store.entries()], before);
  });
}
