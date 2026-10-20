import assert from "node:assert/strict";
import test from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {ownedAssetStorageEnabled, ownedThumbnailUrl, retainUpload, deleteRetainedUpload, stored,
  signOriginalDelivery, bindOwnedWall, cleanupDeletedOwnedWall, sweepR2Tombstones, type StoredUpload} from "../ownedAssetDelivery";
import {r2ObjectId} from "../r2Storage";
import {installFakeDb} from "./fakeDb";

const configured = () => {
  process.env.R2_ACCOUNT_ID = "a".repeat(32);
  process.env.R2_ACCESS_KEY_ID = "access";
  process.env.R2_SECRET_ACCESS_KEY = "secret";
  process.env.R2_PRIVATE_BUCKET = "private-assets";
  process.env.R2_PREVIEW_BUCKET = "public-previews";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
  process.env.GH_REPO_WALLS = "walls";
};

test("R2 opt-in is absent by default and preview URLs use the immutable .img key", (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  for (const key of ["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET",
    "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"]) delete process.env[key];
  assert.equal(ownedAssetStorageEnabled(), false);
  process.env.R2_ACCESS_KEY_ID = "staged-only";
  assert.equal(ownedAssetStorageEnabled(), false, "staged secrets alone do not switch uploads away from GitHub");
  delete process.env.R2_ACCESS_KEY_ID;
  configured();
  const objectId = "b".repeat(64);
  const thumb: StoredUpload = {objectId, previewObjectId: objectId, bucket: "private-assets", object: `retained/${objectId}`,
    uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "a".repeat(40), sha256: "c".repeat(64)};
  thumb.objectId = r2ObjectId({uid: thumb.uid, repo: thumb.repo, path: thumb.path, sha: thumb.sha}, thumb.sha256);
  thumb.object = `retained/${thumb.objectId}`;
  thumb.previewObjectId = thumb.objectId;
  assert.equal(ownedThumbnailUrl(thumb),
    `https://images.example.com/previews/${thumb.objectId}.img`);
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com:8443";
  assert.throws(() => ownedThumbnailUrl(thumb), /Invalid/);
});

test("retention verifies Git blob SHA, create-only object metadata, bytes, and preview", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const store = installFakeDb(t);
  const bytes = Buffer.from("thumbnail bytes");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const digest = createHash("sha256").update(bytes).digest("hex");
  const calls: {method?: string; headers: Headers}[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers);
    calls.push({method: init?.method, headers});
    if (init?.method === "PUT") {
      assert.equal(headers.get("if-none-match"), "*");
      return new Response(null, {status: 200});
    }
    if (init?.method === "HEAD") {
      const objectId = new URL(String(input)).pathname.split("/").pop()!.replace(/\.img$/, "");
      return new Response(null, {status: 200, headers: {
        "content-length": String(bytes.length), "x-amz-meta-sha256": digest,
        "x-amz-meta-uid": "owner", "x-amz-meta-objectid": objectId,
        "x-amz-meta-repo64": Buffer.from("walls").toString("base64url"),
        "x-amz-meta-path64": Buffer.from("thumb_wall.jpg").toString("base64url"), "x-amz-meta-gitsha": sha,
        "x-amz-meta-uploadid": "imported",
      }});
    }
    if (init?.method === "GET") return new Response(bytes, {status: 200, headers: {"content-length": String(bytes.length)}});
    return new Response(null, {status: 204});
  });
  // The test response echoes the ID from the request URL because HEAD cannot read the signed metadata request body.
  const retained = await retainUpload({repo: "walls", path: "thumb_wall.jpg", sha, uid: "owner", bytes, sourceKind: "owned"});
  assert.equal(retained.objectId, r2ObjectId({uid: "owner", repo: "walls", path: "thumb_wall.jpg", sha,
    sourceKind: "owned"}, digest));
  assert.equal(retained.previewObjectId, retained.objectId);
  assert.ok(stored(retained));
  assert.equal(store.get(`r2ObjectRegistry/${retained.objectId}`)?.status, "active");
  assert.equal(calls.filter((call) => call.method === "PUT").length, 2);
  assert.ok(calls.every((call) => call.headers.has("authorization")));
  const docCount = store.size;
  await assert.rejects(retainUpload({repo: "walls", path: "../thumb_wall.jpg", sha, uid: "owner", bytes, sourceKind: "owned"}),
    /Invalid upload identity/);
  assert.equal(store.size, docCount);
});

test("deletion tombstones manifest and registry before bytes and cannot resurrect key", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const store = installFakeDb(t);
  const bytes = Buffer.from("original");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const digest = createHash("sha256").update(bytes).digest("hex");
  const objectId = r2ObjectId({uid: "owner", repo: "walls", path: "photo.jpg", sha, sourceKind: "owned"}, digest);
  const asset: StoredUpload = {bucket: "private-assets", object: `private-originals/${objectId}`, objectId,
    uid: "owner", repo: "walls", path: "photo.jpg", sha, sha256: digest, sourceKind: "owned"};
  store.set(`r2ObjectRegistry/${objectId}`, {status: "active", uploadId: "imported", ...asset});
  store.set("ownedAssets/wall", {status: "ready", original: asset});
  const deletes: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method === "DELETE") {
      assert.equal(store.get("ownedAssets/wall")?.status, "deleted");
      assert.equal(store.get(`r2ObjectRegistry/${objectId}`)?.status, "tombstoned");
      deletes.push(String(input));
      return new Response(null, {status: 204});
    }
    return new Response(null, {status: 404});
  });
  await deleteRetainedUpload({repo: "walls", path: "photo.jpg", sha, sourceKind: "owned", expected: asset});
  assert.equal(deletes.length, 1);
  await assert.rejects(retainUpload({repo: "walls", path: "photo.jpg", sha, uid: "owner", bytes, sourceKind: "owned"}),
    /deleted/);
});

test("original signing rejects duplicate wall IDs and stale object identity", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const store = installFakeDb(t, {"walls/a": {id: "wall"}, "walls/b": {id: "wall"},
    "ownedAssets/wall": {status: "ready"}});
  await assert.rejects(signOriginalDelivery("../wall"), /Invalid wall/);
  await assert.rejects(signOriginalDelivery("wall"), /unavailable/);
  store.delete("walls/b");
  store.set("walls/a", {id: "wall", originalProtected: true, originalObjectId: "wrong"});
  await assert.rejects(signOriginalDelivery("wall"), /unavailable/);
});

test("wall binding accepts matching GitHub receipts and redacts source URLs", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  process.env.GH_USERNAME = "hash";
  const paths = ["private/photo.jpg", "private/thumb_photo.jpg"];
  const sha = "a".repeat(40);
  const records: Record<string, Record<string, unknown>> = {};
  const assets = paths.map((path, index): StoredUpload => {
    const digest = String.fromCharCode(98 + index).repeat(64);
    const objectId = r2ObjectId({uid: "owner", repo: "walls", path, sha}, digest);
    const asset: StoredUpload = {bucket: "private-assets", object: `retained/${objectId}`, objectId,
      uid: "owner", repo: "walls", path, sha, sha256: digest,
      ...(index === 1 ? {previewObjectId: objectId} : {})};
    const url = `https://raw.githubusercontent.com/hash/walls/main/${path}`;
    const recordId = createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex");
    const intentId = createHash("sha256").update(`walls\0${path}`).digest("hex");
    records[`githubUploads/file_${recordId}`] = {uid: "owner", repo: "walls", path, sha,
      retainedAsset: asset};
    records[`githubUploadIntents/path_${intentId}`] = {uid: "owner", repo: "walls", path, blobSha: sha,
      status: "complete", retainedAsset: asset,
      response: {content: {path, sha, download_url: url}}};
    records[`r2ObjectRegistry/${objectId}`] = {status: "active", bucket: "private-assets", objectId,
      uploadId: "imported", object: asset.object, sha256: digest, uid: "owner", repo: "walls", path, sha,
      sourceKind: "github",
      ...(index === 1 ? {previewObjectId: objectId} : {})};
    return asset;
  });
  records["walls/wall"] = {id: "wall", email: "owner@example.com", review: true,
    wallpaper_url: "https://raw.githubusercontent.com/hash/walls/main/private/photo.jpg",
    wallpaper_thumb: "https://raw.githubusercontent.com/hash/walls/main/private/thumb_photo.jpg", wallpaper_path: paths[0],
    wallpaper_sha: sha, thumb_path: paths[1], thumb_sha: sha};
  const store = installFakeDb(t, records);
  const metadata = new Map(assets.map((asset) => [asset.objectId, asset]));
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    const objectId = new URL(String(input)).pathname.split("/").pop()!;
    const asset = metadata.get(objectId);
    assert.equal(init?.method, "HEAD");
    return new Response(null, {status: asset ? 200 : 404, headers: asset ? {
      "content-length": "100", "x-amz-meta-sha256": asset.sha256, "x-amz-meta-uid": asset.uid,
      "x-amz-meta-objectid": asset.objectId, "x-amz-meta-repo64": Buffer.from(asset.repo).toString("base64url"),
      "x-amz-meta-path64": Buffer.from(asset.path).toString("base64url"), "x-amz-meta-gitsha": asset.sha,
      "x-amz-meta-uploadid": "imported",
    } : undefined});
  });
  t.mock.method(admin.auth(), "getUser", async () => ({email: "owner@example.com", disabled: false}) as never);
  await bindOwnedWall("wall");
  assert.equal(store.get("ownedAssets/wall")?.status, "ready");
  assert.equal(store.get("walls/wall")?.wallpaper_url, "");
  assert.equal(store.get("walls/wall")?.originalObjectId, assets[0].objectId);
  assert.equal(store.get("walls/wall")?.wallpaper_thumb,
    `https://images.example.com/previews/${assets[1].objectId}.img`);
  assert.deepEqual(store.get("ownedAssets/wall")?.original, assets[0]);
});

test("deleted wall cleanup removes only an unshared preview and retries after marking deleted", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const previewObjectId = "c".repeat(64);
  const thumb: StoredUpload = {bucket: "private-assets", object: `retained/${previewObjectId}`, objectId: previewObjectId,
    sha256: "d".repeat(64), uid: "owner", repo: "walls", path: "thumb_old.jpg", sha: "a".repeat(40),
    previewObjectId};
  thumb.objectId = r2ObjectId({uid: thumb.uid, repo: thumb.repo, path: thumb.path, sha: thumb.sha}, thumb.sha256);
  thumb.object = `retained/${thumb.objectId}`;
  thumb.previewObjectId = thumb.objectId;
  const manifest = {status: "ready", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20,
    thumb};
  const registry = {status: "active", uploadId: "imported", bucket: thumb.bucket, object: thumb.object,
    objectId: thumb.objectId, sha256: thumb.sha256, uid: thumb.uid, repo: thumb.repo, path: thumb.path, sha: thumb.sha,
    sourceKind: "github", previewObjectId: thumb.objectId};
  const store = installFakeDb(t, {"ownedAssets/old": manifest,
    "ownedAssets/shared": {status: "ready", thumb}, [`r2ObjectRegistry/${thumb.objectId}`]: registry});
  const removed: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    assert.equal(init?.method, "DELETE");
    removed.push(String(input));
    return new Response(null, {status: 204});
  });
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20});
  assert.equal(store.get("ownedAssets/old")?.status, "deleted");
  assert.equal(removed.length, 0, "a ready manifest still shares the preview");
  store.set("ownedAssets/shared", {status: "deleted", thumb});
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20});
  assert.equal(removed.length, 1);
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20});
  assert.equal(removed.length, 2, "retries safely repeat the idempotent object delete");
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 9, incarnationNanos: 20});
  assert.equal(removed.length, 2, "stale incarnation cannot clean the current manifest");
});

test("tombstone sweep removes a late PUT after a crashed delete retry", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const store = installFakeDb(t);
  const sha = "a".repeat(40);
  const digest = "b".repeat(64);
  const identity = {uid: "owner", repo: "walls", path: "thumb_wall.jpg", sha, sourceKind: "owned" as const,
    uploadId: "retry-id"};
  const objectId = r2ObjectId(identity, digest);
  store.set(`r2ObjectRegistry/${objectId}`, {status: "tombstoned", cleanupPending: true,
    cleanupNotBeforeMs: 1, bucket: "private-assets", objectId, object: `private-originals/${objectId}`, sha256: digest,
    uid: identity.uid, repo: identity.repo, path: identity.path, sha, sourceKind: "owned", uploadId: "retry-id",
    previewObjectId: objectId});
  const removed: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    assert.equal(init?.method, "DELETE");
    removed.push(new URL(String(input)).pathname);
    return new Response(null, {status: 204});
  });
  assert.equal(await sweepR2Tombstones(10), 1);
  assert.deepEqual(removed.sort(), [`/private-assets/private-originals/${objectId}`,
    `/public-previews/previews/${objectId}.img`].sort());
  assert.equal(store.get(`r2ObjectRegistry/${objectId}`)?.status, "tombstoned");
  assert.equal(await sweepR2Tombstones(10), 1);
  assert.equal(removed.length, 4, "the periodic sweep rechecks tombstones for a late Put after process crash");
});
