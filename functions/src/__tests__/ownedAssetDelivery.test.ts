import assert from "node:assert/strict";
import test from "node:test";
import {createHash} from "node:crypto";
import * as admin from "firebase-admin";
import {retainUpload, signOriginalDelivery, ownedAssetStorageEnabled, ownedThumbnailUrl, ownedThumbnail,
  bindLegacyOwnedWall, bindOwnedWall, onOwnedWallWritten} from "../ownedAssetDelivery";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";

test("owned storage is explicit and thumb URL never uses origin", (t) => {
  const previous = {...process.env};
  t.after(() => {process.env = previous;});
  delete process.env.OWNED_ASSET_BUCKET;
  assert.equal(ownedAssetStorageEnabled(), false);
  process.env.OWNED_THUMBNAIL_BASE_URL = "https://example.com/ownedThumbnail";
  assert.equal(ownedThumbnailUrl("wall"), "https://example.com/ownedThumbnail/wall");
  process.env.OWNED_THUMBNAIL_BASE_URL = "https://example.com:8443/ownedThumbnail";
  assert.throws(() => ownedThumbnailUrl("wall"), /Invalid owned thumbnail endpoint/);
});

test("retention verifies Git SHA and retries create-only object with matching private metadata", async (t) => {
  const previous = {...process.env};
  t.after(() => {process.env = previous;});
  process.env.OWNED_ASSET_BUCKET = "private-test";
  process.env.GH_REPO_WALLS = "walls";
  const bytes = Buffer.from("jpeg-bytes");
  const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
  const digest = createHash("sha256").update(bytes).digest("hex");
  const target = admin.storage().bucket("private-test");
  const file = target.file("mock");
  t.mock.method(target, "file", () => file);
  t.mock.method(admin.storage(), "bucket", () => target);
  let saves = 0;
  t.mock.method(file, "save", async (_bytes: Buffer, options: {preconditionOpts?: {ifGenerationMatch?: number}}) => {
    assert.equal(options?.preconditionOpts?.ifGenerationMatch, 0);
    saves++;
    throw Object.assign(new Error("exists"), {code: 412});
  });
  t.mock.method(file, "getMetadata", async () => [{generation: "42", size: String(bytes.length), metadata: {sha256: digest, uid: "owner"}}]);
  const retained = await retainUpload({repo: "walls", path: "photo.jpg", sha, uid: "owner", bytes});
  assert.equal(retained.generation, "42");
  assert.equal(saves, 1);
  await assert.rejects(retainUpload({repo: "walls", path: "photo.jpg", sha: "a".repeat(40), uid: "owner", bytes}), /Git blob SHA/);
  t.mock.method(file, "getMetadata", async () => [{generation: "42", size: String(bytes.length), metadata: {sha256: "bad", uid: "owner"}}]);
  await assert.rejects(retainUpload({repo: "walls", path: "photo.jpg", sha, uid: "owner", bytes}), /mismatch/);
});

test("signer denies missing, malformed, duplicate and tombstoned identities without origin fetch", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(globalThis, "fetch", async () => {throw new Error("Origin must not be fetched");});
  await assert.rejects(signOriginalDelivery("../wall"), /Invalid wall/);
  await assert.rejects(signOriginalDelivery("wall"), /unavailable/);
  store.set("walls/a", {id: "wall"});
  store.set("walls/b", {id: "wall"});
  await assert.rejects(signOriginalDelivery("wall"), /unavailable/);
  store.delete("walls/b");
  store.set("ownedAssets/wall", {status: "deleted"});
  await assert.rejects(signOriginalDelivery("wall"), /unavailable/);
});

test("reviewed legacy binding serves retained PNG and signs pinned original during origin outage, then deletion tombstones", async (t) => {
  const previous = {...process.env};
  t.after(() => {process.env = previous;});
  process.env.OWNED_ASSET_BUCKET = "private-test";
  process.env.OWNED_THUMBNAIL_BASE_URL = "https://example.com/ownedThumbnail";
  process.env.GH_USERNAME = "hash";
  process.env.GH_REPO_WALLS = "walls";
  let fetches = 0;
  t.mock.method(globalThis, "fetch", async () => {fetches++; throw new Error("GitHub is down");});
  const originalUrl = "https://raw.githubusercontent.com/hash/walls/main/photo.png";
  const thumbUrl = "https://raw.githubusercontent.com/hash/walls/main/thumb_photo.png";
  const sha = "a".repeat(40);
  const digest = "b".repeat(64);
  const store = installFakeDb(t, {"walls/doc": {id: "wall", review: true, wallpaper_url: originalUrl, wallpaper_thumb: thumbUrl}});
  const time = admin.firestore.Timestamp.fromMillis(1000);
  const baseCollection = db.collection.bind(db);
  const wrap = <T extends object>(target: T): T => new Proxy(target, {get(current, property) {
    const value: unknown = Reflect.get(current, property);
    if (typeof value !== "function") return value;
    if (property === "get") return async () => {
      const result = await Reflect.apply(value, current, []) as Record<string, unknown>;
      return Array.isArray(result.docs) ? {...result, docs: result.docs.map((doc) => ({...doc, createTime: time}))} :
        {...result, createTime: time};
    };
    if (["doc", "collection", "where", "limit"].includes(String(property))) {
      return (...args: unknown[]) => wrap(Reflect.apply(value, current, args) as object);
    }
    return value;
  }});
  t.mock.method(db, "collection", (path: string) => wrap(baseCollection(path)));
  const asset = (path: string) => ({repo: "walls", path, sha, bucket: "private-test", uid: "legacy-migration",
    object: `retained/${createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex")}`, generation: "42", sha256: digest});
  const target = admin.storage().bucket("private-test");
  const file = target.file("mock");
  t.mock.method(admin.storage(), "bucket", () => target);
  t.mock.method(target, "file", (_path: string, options?: {generation?: string | number}) => {
    assert.equal(options?.generation, "42");
    return file;
  });
  t.mock.method(file, "getMetadata", async () => [{generation: "42", metadata: {sha256: digest}, contentType: "image/png"}]);
  t.mock.method(file, "getSignedUrl", async (options: {queryParams?: {generation?: string}; expires?: unknown}) => {
    assert.equal(options.queryParams?.generation, "42");
    return ["https://storage.example/pinned"];
  });
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  t.mock.method(file, "download", async () => [png]);
  let deletes = 0;
  t.mock.method(file, "delete", async (options: {ifGenerationMatch?: string}) => {
    assert.equal(options.ifGenerationMatch, "42"); deletes++;
  });
  await bindLegacyOwnedWall({wallId: "wall", canonicalPath: "walls/doc", incarnation: 1000, incarnationNanos: time.nanoseconds,
    originalUrl, thumbUrl, original: asset("photo.png"), thumb: asset("thumb_photo.png")});
  const signed = await signOriginalDelivery("wall");
  assert.equal(signed.generation, "42");
  assert.equal(signed.url, "https://storage.example/pinned");
  assert.ok(signed.expiresAt > Date.now() && signed.expiresAt <= Date.now() + 120000);
  let status = 200;
  let body: unknown;
  const response = {set: () => response, type: (type: string) => {assert.equal(type, "image/png"); return response;},
    send: (value: unknown) => {body = value; return response;}, status: (value: number) => {status = value; return response;}};
  await ownedThumbnail({path: "/wall"} as never, response as never);
  assert.equal(status, 200);
  assert.deepEqual(body, png);
  assert.equal(fetches, 0);
  store.set("walls/doc", {...store.get("walls/doc"), review: false});
  await ownedThumbnail({path: "/wall"} as never, response as never);
  assert.equal(status, 200);
  assert.deepEqual(body, png);
  const before = await db.collection("walls").doc("doc").get();
  store.delete("walls/doc");
  await onOwnedWallWritten.run({data: {before, after: {exists: false}}} as never);
  assert.equal(store.get("ownedAssets/wall")?.status, "deleted");
  assert.equal(deletes, 0);
  await assert.rejects(signOriginalDelivery("wall"), /unavailable/);
  t.mock.method(admin.auth(), "getUser", async () => ({email: "owner@example.com", disabled: false}) as never);
  store.set("walls/modern", {id: "modern", email: "owner@example.com", review: true, wallpaper_url: originalUrl, wallpaper_thumb: thumbUrl,
    wallpaper_path: "photo.png", wallpaper_sha: sha, thumb_path: "thumb_photo.png", thumb_sha: sha});
  for (const path of ["photo.png", "thumb_photo.png"]) {
    const url = path === "photo.png" ? originalUrl : thumbUrl;
    store.set(`githubUploads/file_${createHash("sha256").update(`walls\0${path}\0${sha}`).digest("hex")}`,
      {repo: "walls", path, sha, uid: "legacy-migration", retainedAsset: asset(path)});
    store.set(`githubUploadIntents/path_${createHash("sha256").update(`walls\0${path}`).digest("hex")}`,
      {repo: "walls", path, blobSha: sha, status: "complete", uid: "legacy-migration",
        response: {content: {path, sha, download_url: url}}});
  }
  await bindOwnedWall("modern");
  assert.equal(store.get("ownedAssets/modern")?.status, "ready");
  assert.equal((await signOriginalDelivery("modern")).generation, "42");
  const originalKey = `githubUploads/file_${createHash("sha256").update(`walls\0photo.png\0${sha}`).digest("hex")}`;
  const intentKey = `githubUploadIntents/path_${createHash("sha256").update("walls\0photo.png").digest("hex")}`;
  store.set(originalKey, {...store.get(originalKey), sourceKind: "owned"});
  const intent = store.get(intentKey)!;
  store.set(intentKey, {...intent, sourceKind: "owned", retainedAsset: asset("photo.png"),
    response: {content: {path: "photo.png", sha, download_url: ""}}});
  store.set("walls/private", {...store.get("walls/modern"), id: "private", wallpaper_url: "", wallpaper_thumb: thumbUrl});
  await bindOwnedWall("private");
  assert.deepEqual(store.get("ownedAssets/private")?.provenance, {kind: "owned", uid: "legacy-migration"});
  store.set("walls/spoof", {...store.get("walls/private"), id: "spoof", email: "attacker@example.com", wallpaper_thumb: thumbUrl});
  await bindOwnedWall("spoof");
  assert.equal(store.has("ownedAssets/spoof"), false);
  store.set(intentKey, {...store.get(intentKey), sourceKind: "github"});
  store.set("walls/forged", {...store.get("walls/private"), id: "forged", wallpaper_thumb: thumbUrl});
  await bindOwnedWall("forged");
  assert.equal(store.has("ownedAssets/forged"), false);
  t.mock.method(file, "getMetadata", async () => {throw new Error("Retained original is missing");});
  await assert.rejects(signOriginalDelivery("private"), /missing/);
});
