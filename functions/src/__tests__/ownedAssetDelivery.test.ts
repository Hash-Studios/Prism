import assert from "node:assert/strict";
import test from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {db} from "../common";
import {ownedAssetStorageEnabled, ownedThumbnailUrl, retainUpload, deleteRetainedUpload, stored,
  signOriginalDelivery, bindOwnedWall, cleanupDeletedOwnedWall, sweepR2Tombstones, type StoredUpload} from "../ownedAssetDelivery";
import {r2ObjectId, R2Storage} from "../r2Storage";
import {installFakeDb} from "./fakeDb";
import * as ownerAuth from "../authoredContentUid";

test("ISO BMFF image previews retain image MIME types instead of video/mp4", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  installFakeDb(t);
  for (const [brand, mime] of [["avif", "image/avif"], ["heic", "image/heic"], ["mif1", "image/heif"]]) {
    const bytes = Buffer.alloc(24);
    bytes.writeUInt32BE(24);
    bytes.write("ftyp", 4);
    bytes.write(brand, 8);
    const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
    const digest = createHash("sha256").update(bytes).digest("hex");
    const identity = {repo: "walls", path: `thumb_wall.${brand}`, sha, uid: "owner", sourceKind: "owned" as const};
    const objectId = r2ObjectId(identity, digest);
    const put = t.mock.method(R2Storage.prototype, "put", async (...args: Parameters<R2Storage["put"]>) => {
      const type = args[4];
      assert.equal(type, mime);
      return true;
    });
    const head = t.mock.method(R2Storage.prototype, "head", async () => ({size: bytes.length, sha256: digest, objectId,
      uid: "owner", repo: "walls", path: identity.path, gitSha: sha, uploadId: "imported", contentType: mime}));
    const get = t.mock.method(R2Storage.prototype, "get", async () => bytes);
    await retainUpload({...identity, bytes});
    put.mock.restore(); head.mock.restore(); get.mock.restore();
  }
});

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
  assert.ok(stored(thumb));
  process.env.R2_PRIVATE_BUCKET = "private assets";
  assert.throws(() => stored(thumb), /R2 storage configuration is invalid: R2_PRIVATE_BUCKET/,
    "a valid receipt reports unsafe configuration instead of looking corrupt");
  delete process.env.R2_ACCOUNT_ID;
  assert.throws(() => ownedAssetStorageEnabled(), /R2 storage configuration is invalid: R2_PRIVATE_BUCKET/,
    "an invalid non-secret setting fails the opt-in gate closed");
  process.env.R2_ACCOUNT_ID = "a".repeat(32);
  process.env.R2_PRIVATE_BUCKET = " private-assets ";
  assert.equal(ownedAssetStorageEnabled(), true, "valid surrounding whitespace is normalized");
  assert.ok(stored(thumb));
  process.env.R2_PRIVATE_BUCKET = "private-assets\n";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com\n";
  assert.ok(stored(thumb), "a trailing newline from the secret store does not orphan stored receipts");
  assert.equal(ownedThumbnailUrl(thumb), `https://images.example.com/previews/${thumb.objectId}.img`);
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

test("live upload cannot start after creator deletion closes the upload barrier", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const store = installFakeDb(t, {"usersv2/owner": {deleted: true}, "creatorDeletionState/owner": {closed: true}});
  const puts = t.mock.method(R2Storage.prototype, "put", async () => true);
  const bytes = Buffer.from("live video bytes");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const digest = createHash("sha256").update(bytes).digest("hex");
  const identity = {repo: "walls", path: "live_recording.mp4", sha, uid: "owner", sourceKind: "owned" as const};
  const objectId = r2ObjectId(identity, digest);
  t.mock.method(R2Storage.prototype, "head", async () => ({size: bytes.length, sha256: digest, objectId, uid: "owner",
    repo: "walls", path: identity.path, gitSha: sha, uploadId: "imported", contentType: "video/mp4"}));
  t.mock.method(R2Storage.prototype, "get", async () => bytes);
  await assert.rejects(retainUpload({repo: "walls", path: "live_recording.mp4", sha, uid: "owner", bytes,
    sourceKind: "owned"}), /account is closed/);
  assert.equal(puts.mock.callCount(), 0, "closed accounts cannot write live bytes to R2");
  assert.equal(store.has(`r2ObjectRegistry/${objectId}`), false, "a closed account gets no upload registry row");
});

test("live upload raced by creator deletion is tombstoned and cleaned after readback", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const store = installFakeDb(t, {"usersv2/owner": {deleted: false}, "creatorDeletionState/owner": {closed: false}});
  const bytes = Buffer.from("live video bytes");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const digest = createHash("sha256").update(bytes).digest("hex");
  const identity = {repo: "walls", path: "live_recording.mp4", sha, uid: "owner", sourceKind: "owned" as const};
  const objectId = r2ObjectId(identity, digest);
  const objects = new Set<string>();
  t.mock.method(R2Storage.prototype, "put", async (kind: string, object: string) => {
    objects.add(`${kind}/${object}`);
    return true;
  });
  t.mock.method(R2Storage.prototype, "head", async (kind: string, object: string) => ({size: bytes.length,
    sha256: digest, objectId, uid: "owner", repo: "walls", path: identity.path, gitSha: sha,
    uploadId: "imported", contentType: "video/mp4"}));
  t.mock.method(R2Storage.prototype, "get", async (kind: string) => {
    if (kind === "preview") {
      store.set("usersv2/owner", {deleted: true});
      store.set("creatorDeletionState/owner", {closed: true});
    }
    return bytes;
  });
  const deletes: string[] = [];
  t.mock.method(R2Storage.prototype, "delete", async (kind: string, object: string) => {
    deletes.push(`${kind}/${object}`);
    objects.delete(`${kind}/${object}`);
  });
  await assert.rejects(retainUpload({...identity, bytes}), /deleted during upload/);
  assert.equal(store.get(`r2ObjectRegistry/${objectId}`)?.status, "tombstoned");
  assert.ok(deletes.includes(`private/private-originals/${objectId}`));
  assert.ok(deletes.includes(`preview/previews/${objectId}.img`));
  assert.equal(objects.size, 0, "the private original and preview are both removed");
  assert.notEqual(store.get(`r2ObjectRegistry/${objectId}`)?.status, "active");
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

for (const firstFailure of ["walls", "ownedAssets"] as const) {
  test(`original signing fails closed when ${firstFailure} rejects before the other read`, async (t) => {
    const started: string[] = [];
    const rejectReads: Map<string, (reason: Error) => void> = new Map();
    t.mock.method(db, "collection", (name: string) => {
      const target = {
        where: () => target,
        limit: () => target,
        doc: () => target,
        get: () => {
          started.push(name);
          return new Promise((_, reject) => rejectReads.set(name, reject));
        },
      };
      return target;
    });
    const signing = signOriginalDelivery("wall");
    assert.deepEqual(started, ["walls", "ownedAssets"]);
    const error = new Error(`${firstFailure} unavailable`);
    const rejectFirst = rejectReads.get(firstFailure);
    assert.ok(rejectFirst);
    rejectFirst(error);
    await assert.rejects(signing, (caught: unknown) => caught === error);
    const other = firstFailure === "walls" ? "ownedAssets" : "walls";
    const rejectOther = rejectReads.get(other);
    assert.ok(rejectOther);
    rejectOther(new Error(`${other} also unavailable`));
    await new Promise((resolve) => setImmediate(resolve));
  });
}

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
  const expectation = {canonicalPath: "walls/wall", incarnation: 2, incarnationNanos: 2000000,
    originalUrl: records["walls/wall"].wallpaper_url, thumbUrl: records["walls/wall"].wallpaper_thumb,
    originalPath: paths[0], thumbPath: paths[1], originalSha: sha, thumbSha: sha};
  await (bindOwnedWall as (...args: unknown[]) => Promise<void>)("wall", expectation);
  assert.equal(store.has("ownedAssets/wall"), false, "a stale converter cannot bind a recreated wall");
  await (bindOwnedWall as (...args: unknown[]) => Promise<void>)("wall", {...expectation, incarnation: 1,
    incarnationNanos: 1000000, originalUrl: "https://raw.githubusercontent.com/hash/walls/main/other.jpg"});
  assert.equal(store.has("ownedAssets/wall"), false, "a converter cannot bind changed source URLs");
  store.set("walls/wall", {...records["walls/wall"], review: false});
  await (bindOwnedWall as (...args: unknown[]) => Promise<void>)("wall", {...expectation, incarnation: 1,
    incarnationNanos: 1000000});
  assert.equal(store.has("ownedAssets/wall"), false, "a converter cannot bind revoked approval");
  store.set("walls/wall", {...records["walls/wall"], dropReserved: true});
  await bindOwnedWall("wall");
  assert.equal(store.has("ownedAssets/wall"), false, "native uploads cannot bind reserved Drop walls");
  const removedSource = {...records["walls/wall"]};
  delete removedSource.wallpaper_path;
  store.set("walls/wall", removedSource);
  const currentExpectation = {...expectation, incarnation: 1, incarnationNanos: 1000000};
  await (bindOwnedWall as (...args: unknown[]) => Promise<void>)("wall", {...currentExpectation,
    recordedSource: {originalPath: paths[0], thumbPath: paths[1], originalSha: sha, thumbSha: sha}});
  assert.equal(store.has("ownedAssets/wall"), false, "a converter cannot bind source metadata removed since its snapshot");
  await (bindOwnedWall as (...args: unknown[]) => Promise<void>)("wall", currentExpectation);
  assert.equal(store.get("ownedAssets/wall")?.status, "ready", "without the snapshot, missing metadata is accepted as legacy");
  store.delete("ownedAssets/wall");
  store.set("walls/wall", records["walls/wall"]);
  t.mock.method(admin.auth(), "getUser", async () => {
    throw Object.assign(new Error("Uploader was deleted"), {code: "auth/user-not-found"});
  });
  await bindOwnedWall("wall");
  assert.equal(store.has("ownedAssets/wall"), false, "a deleted uploader permanently prevents binding without a retry");
  t.mock.method(admin.auth(), "getUser", async () => {
    throw Object.assign(new Error("Auth temporarily unavailable"), {code: "auth/internal-error"});
  });
  await assert.rejects(bindOwnedWall("wall"), /Auth temporarily unavailable/);
  assert.equal(store.has("ownedAssets/wall"), false);
  t.mock.method(admin.auth(), "getUser", async () => ({email: "owner@example.com", disabled: false}) as never);
  await bindOwnedWall("wall");
  assert.equal(store.get("ownedAssets/wall")?.status, "ready");
  assert.equal(store.get("walls/wall")?.wallpaper_url, "");
  assert.equal(store.get("walls/wall")?.originalObjectId, assets[0].objectId);
  assert.equal(store.get("walls/wall")?.wallpaper_thumb,
    `https://images.example.com/previews/${assets[1].objectId}.img`);
  assert.deepEqual(store.get("ownedAssets/wall")?.original, assets[0]);
});

test("live rejection preserves exact protected poster incarnation for undo, not a stale archive", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const asset = (path: string, preview = false): StoredUpload => {
    const identity = {uid: "owner", repo: "walls", path, sha: "a".repeat(40), sourceKind: "owned" as const};
    const sha256 = (preview ? "c" : "b").repeat(64);
    const objectId = r2ObjectId(identity, sha256);
    return {...identity, sha256, objectId, object: `private-originals/${objectId}`, bucket: "private-assets",
      ...(preview ? {previewObjectId: objectId} : {})};
  };
  const original = asset("photo.jpg"); const thumb = asset("thumb_photo.jpg", true);
  const created = new admin.firestore.Timestamp(1, 20);
  const archive = {kind: "live", id: "wall", creatorUid: "owner", sourceWallCreateTime: created,
    originalProtected: true, originalObjectId: original.objectId, wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "",
    thumb_path: "", thumb_sha: "", wallpaper_thumb: ownedThumbnailUrl(thumb)};
  const store = installFakeDb(t, {"ownedAssets/wall": {status: "ready", canonicalPath: "walls/doc", incarnation: created.toMillis(),
    incarnationNanos: 20, original, thumb}, "rejectedWalls/doc": archive,
  [`r2ObjectRegistry/${original.objectId}`]: {...original, status: "active", uploadId: "imported"},
  [`r2ObjectRegistry/${thumb.objectId}`]: {...thumb, status: "active", uploadId: "imported"}});
  const deletion = t.mock.method(R2Storage.prototype, "delete", async () => undefined);
  const cleanup = () => cleanupDeletedOwnedWall({wallId: "wall", canonicalPath: "walls/doc", incarnation: created.toMillis(),
    incarnationNanos: 20});
  await cleanup();
  assert.equal(store.get("ownedAssets/wall")?.status, "ready");
  assert.equal(store.get(`r2ObjectRegistry/${original.objectId}`)?.status, "active");
  assert.equal(deletion.mock.callCount(), 0);
  const lookup = t.mock.method(ownerAuth, "verifiedUidForEmail", async () => "owner");
  store.set("rejectedWalls/doc", {...archive, creatorUid: undefined, email: "owner@example.com"});
  await cleanup();
  assert.equal(store.get("ownedAssets/wall")?.status, "ready", "Auth ownership fills a pending creatorUid");
  assert.equal(lookup.mock.callCount(), 1);
  store.set("rejectedWalls/doc", {...archive, sourceWallCreateTime: new admin.firestore.Timestamp(1, 21)});
  await cleanup();
  assert.equal(store.get("ownedAssets/wall")?.status, "deleted");
  assert.equal(store.get(`r2ObjectRegistry/${original.objectId}`)?.status, "tombstoned");
  assert.equal(deletion.mock.callCount(), 1);
});

test("deleted wall cleanup tombstones unshared original and thumb registries and retries safely", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const makeAsset = (path: string, digest: string, preview = false, owned = false): StoredUpload => {
    const asset: StoredUpload = {bucket: "private-assets", object: "", objectId: "", sha256: digest.repeat(64),
      uid: "owner", repo: "walls", path, sha: "a".repeat(40),
      ...(owned ? {sourceKind: "owned" as const} : {}), ...(preview ? {previewObjectId: ""} : {})};
    asset.objectId = r2ObjectId({uid: asset.uid, repo: asset.repo, path: asset.path, sha: asset.sha,
      ...(owned ? {sourceKind: "owned" as const} : {})}, asset.sha256);
    asset.object = `${owned ? "private-originals" : "retained"}/${asset.objectId}`;
    if (preview) asset.previewObjectId = asset.objectId;
    return asset;
  };
  const original = makeAsset("old.jpg", "b", false, true);
  const thumb = makeAsset("thumb_old.jpg", "c", true);
  const manifest = {status: "ready", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20,
    thumb};
  const registry = (asset: StoredUpload) => ({status: "active", uploadId: "imported", bucket: asset.bucket,
    object: asset.object, objectId: asset.objectId, sha256: asset.sha256, uid: asset.uid, repo: asset.repo,
    path: asset.path, sha: asset.sha, sourceKind: asset.sourceKind ?? "github",
    ...(asset.previewObjectId ? {previewObjectId: asset.objectId} : {})});
  const store = installFakeDb(t, {"ownedAssets/old": {...manifest, original},
    "ownedAssets/shared": {status: "ready", original, thumb},
    [`r2ObjectRegistry/${original.objectId}`]: registry(original),
    [`r2ObjectRegistry/${thumb.objectId}`]: registry(thumb)});
  const removed: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    assert.equal(init?.method, "DELETE");
    removed.push(String(input));
    return new Response(null, {status: 204});
  });
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20});
  assert.equal(store.get("ownedAssets/old")?.status, "deleted");
  assert.equal(store.get(`r2ObjectRegistry/${original.objectId}`)?.status, "active",
    "a ready manifest still shares the original");
  assert.equal(store.get(`r2ObjectRegistry/${thumb.objectId}`)?.status, "active",
    "a ready manifest still shares the thumbnail");
  assert.equal(removed.length, 0, "a ready manifest still shares the preview");
  store.set("ownedAssets/shared", {status: "deleted", original, thumb});
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20});
  assert.equal(store.get(`r2ObjectRegistry/${original.objectId}`)?.status, "tombstoned");
  assert.equal(store.get(`r2ObjectRegistry/${thumb.objectId}`)?.status, "tombstoned");
  assert.equal(removed.length, 1);
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 10, incarnationNanos: 20});
  assert.equal(removed.length, 2, "retries safely repeat the idempotent object delete");
  await cleanupDeletedOwnedWall({wallId: "old", canonicalPath: "walls/old", incarnation: 9, incarnationNanos: 20});
  assert.equal(removed.length, 2, "stale incarnation cannot clean the current manifest");
  await sweepR2Tombstones(Number.MAX_SAFE_INTEGER);
  assert.ok(removed.some((url) => url.includes(`/private-originals/${original.objectId}`)),
    "the tombstone sweeper reclaims the private original after direct wall deletion");
});

test("deleted wall cleanup rejects stale incarnations and malformed registry identities without writes", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const makeAsset = (path: string, digest: string, preview = false): StoredUpload => {
    const asset: StoredUpload = {bucket: "private-assets", object: "", objectId: "", sha256: digest.repeat(64),
      uid: "owner", repo: "walls", path, sha: "a".repeat(40), ...(preview ? {previewObjectId: ""} : {})};
    asset.objectId = r2ObjectId({uid: asset.uid, repo: asset.repo, path: asset.path, sha: asset.sha}, asset.sha256);
    asset.object = `retained/${asset.objectId}`;
    if (preview) asset.previewObjectId = asset.objectId;
    return asset;
  };
  const asset = makeAsset("photo.jpg", "d");
  const thumb = makeAsset("thumb_photo.jpg", "e", true);
  const registry = (storedAsset: StoredUpload) => ({status: "active", uploadId: "imported", ...storedAsset,
    sourceKind: storedAsset.sourceKind ?? "github",
    ...(storedAsset.previewObjectId ? {previewObjectId: storedAsset.objectId} : {})});
  const store = installFakeDb(t, {"ownedAssets/wall": {status: "ready", canonicalPath: "walls/wall", incarnation: 10,
    incarnationNanos: 20, original: asset, thumb}, [`r2ObjectRegistry/${asset.objectId}`]: {...registry(asset),
    object: "retained/wrong"}, [`r2ObjectRegistry/${thumb.objectId}`]: registry(thumb)});
  let fetches = 0;
  t.mock.method(globalThis, "fetch", async () => {
    fetches++;
    return new Response(null, {status: 204});
  });
  await cleanupDeletedOwnedWall({wallId: "wall", canonicalPath: "walls/wall", incarnation: 9, incarnationNanos: 20});
  assert.equal(store.get("ownedAssets/wall")?.status, "ready");
  assert.equal(store.get(`r2ObjectRegistry/${asset.objectId}`)?.status, "active");
  assert.equal(store.get(`r2ObjectRegistry/${thumb.objectId}`)?.status, "active");
  assert.equal(fetches, 0, "stale incarnation performs no object deletes");
  await cleanupDeletedOwnedWall({wallId: "wall", canonicalPath: "walls/wall", incarnation: 10, incarnationNanos: 20});
  assert.equal(store.get("ownedAssets/wall")?.status, "ready", "malformed registry identity fails closed");
  assert.equal(store.get(`r2ObjectRegistry/${asset.objectId}`)?.status, "active");
  assert.equal(store.get(`r2ObjectRegistry/${thumb.objectId}`)?.status, "active");
  assert.equal(fetches, 0, "registry mismatch performs no object deletes");
});

test("deleted wall cleanup checks original and thumb sharing independently", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const makeAsset = (path: string, digest: string, preview = false): StoredUpload => {
    const asset: StoredUpload = {bucket: "private-assets", object: "", objectId: "", sha256: digest.repeat(64),
      uid: "owner", repo: "walls", path, sha: "a".repeat(40), ...(preview ? {previewObjectId: ""} : {})};
    asset.objectId = r2ObjectId({uid: asset.uid, repo: asset.repo, path: asset.path, sha: asset.sha}, asset.sha256);
    asset.object = `retained/${asset.objectId}`;
    if (preview) asset.previewObjectId = asset.objectId;
    return asset;
  };
  const original = makeAsset("photo.jpg", "f");
  const thumb = makeAsset("thumb_photo.jpg", "1", true);
  const registry = (asset: StoredUpload) => ({status: "active", uploadId: "imported", ...asset,
    sourceKind: asset.sourceKind ?? "github",
    ...(asset.previewObjectId ? {previewObjectId: asset.objectId} : {})});
  for (const shared of ["original", "thumb"] as const) {
    const wallId = `old-${shared}`;
    const otherManifest = shared === "original" ? {original} : {thumb};
    const store = installFakeDb(t, {
      [`ownedAssets/${wallId}`]: {status: "ready", canonicalPath: `walls/${wallId}`, incarnation: 10,
        incarnationNanos: 20, original, thumb},
      [`ownedAssets/shared-${shared}`]: {status: "ready", ...otherManifest},
      [`r2ObjectRegistry/${original.objectId}`]: registry(original),
      [`r2ObjectRegistry/${thumb.objectId}`]: registry(thumb),
    });
    const deleted: string[] = [];
    t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
      assert.equal(init?.method, "DELETE");
      deleted.push(new URL(String(input)).pathname);
      return new Response(null, {status: 204});
    });
    await cleanupDeletedOwnedWall({wallId, canonicalPath: `walls/${wallId}`, incarnation: 10, incarnationNanos: 20});
    const sharedAsset = shared === "original" ? original : thumb;
    const unsharedAsset = shared === "original" ? thumb : original;
    assert.equal(store.get(`r2ObjectRegistry/${sharedAsset.objectId}`)?.status, "active",
      `${shared} remains active while shared by another ready manifest`);
    assert.equal(store.get(`r2ObjectRegistry/${unsharedAsset.objectId}`)?.status, "tombstoned",
      `${shared === "original" ? "thumb" : "original"} is tombstoned when unshared`);
    assert.equal(deleted.length, shared === "original" ? 1 : 0,
      "only an unshared preview is directly deleted; original bytes are reclaimed by the tombstone sweep");
    if (shared === "original") assert.ok(deleted[0]!.includes(unsharedAsset.objectId));
    t.mock.restoreAll();
  }
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

test("tombstone sweep preserves objects and cursor on malformed config, then recovers", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configured();
  const sha = "a".repeat(40);
  const digest = "b".repeat(64);
  const identity = {uid: "owner", repo: "walls", path: "thumb_wall.jpg", sha, sourceKind: "owned" as const};
  const objectId = r2ObjectId(identity, digest);
  const cursorId = "0-existing-cursor";
  const cursor = {status: "active"};
  const tombstone = {status: "tombstoned", cleanupPending: true, cleanupNotBeforeMs: 1, bucket: "private-assets",
    objectId, object: `private-originals/${objectId}`, sha256: digest, uid: identity.uid, repo: identity.repo,
    path: identity.path, sha, sourceKind: "owned", uploadId: "imported", previewObjectId: objectId};
  const store = installFakeDb(t, {
    [`r2ObjectRegistry/${cursorId}`]: cursor,
    [`r2ObjectRegistry/${objectId}`]: tombstone,
    "r2ObjectRegistryState/tombstoneSweep": {cursorId},
  });
  const removed: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
    assert.equal(init?.method, "DELETE");
    removed.push(String(input));
    return new Response(null, {status: 204});
  });

  process.env.R2_PRIVATE_BUCKET = "private assets";
  await assert.rejects(sweepR2Tombstones(10), /R2 storage configuration is invalid: R2_PRIVATE_BUCKET/);
  assert.deepEqual(removed, [], "invalid configuration prevents object deletion");
  assert.deepEqual(store.get("r2ObjectRegistryState/tombstoneSweep"), {cursorId},
    "invalid configuration does not advance or reset the saved cursor");
  assert.deepEqual(store.get(`r2ObjectRegistry/${objectId}`), tombstone);

  process.env.R2_PRIVATE_BUCKET = " private-assets ";
  assert.equal(await sweepR2Tombstones(10), 1);
  assert.deepEqual(removed.map((url) => new URL(url).pathname).sort(), [
    `/private-assets/private-originals/${objectId}`,
    `/public-previews/previews/${objectId}.img`,
  ], "the corrected configuration removes the intended original and preview");
  assert.deepEqual(store.get("r2ObjectRegistryState/tombstoneSweep"), {cursorId: ""},
    "the recovered sweep completes and resets its cursor");
});
