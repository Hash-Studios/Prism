import assert from "node:assert/strict";
import test from "node:test";
import {createHash} from "node:crypto";
import sharp from "sharp";
import {loadWallpaperPreview, renderWallpaperPreview, wallpaperPreview} from "../wallpaperPreview";
import {R2Storage, r2ObjectId} from "../r2Storage";
import {installFakeDb} from "./fakeDb";

const digest = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

test("preview is a bounded JPEG, preserves aspect ratio, and strips metadata", async () => {
  const original = await sharp({create: {width: 2160, height: 3840, channels: 3, background: "blue"}})
    .withMetadata().png().toBuffer();
  const preview = await renderWallpaperPreview(original);
  const metadata = await sharp(preview).metadata();
  assert.equal(metadata.format, "jpeg");
  assert.equal(metadata.width, 1440);
  assert.equal(metadata.height, 2560);
  assert.equal(metadata.exif, undefined);
  assert.notDeepEqual(preview, original);
});

test("preview does not upscale low resolution sources and rejects non-images", async () => {
  const bytes = await sharp({create: {width: 320, height: 180, channels: 3, background: "red"}}).png().toBuffer();
  const metadata = await sharp(await renderWallpaperPreview(bytes)).metadata();
  assert.equal(metadata.width, 320);
  assert.equal(metadata.height, 180);
  await assert.rejects(renderWallpaperPreview(Buffer.from("not an image")));
});

async function setup(t: Parameters<typeof installFakeDb>[0]) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: "https://images.example.com", GH_REPO_WALLS: "walls"});
  const bytes = await sharp({create: {width: 1200, height: 2000, channels: 3, background: "blue"}}).png().toBuffer();
  const asset = (path: string, sha256: string, preview = false) => {
    const identity = {uid: "owner", repo: "walls", path, sha: "c".repeat(40), sourceKind: "owned" as const};
    const objectId = r2ObjectId(identity, sha256);
    return {...identity, bucket: "private", object: `private-originals/${objectId}`, objectId, sha256,
      ...(preview ? {previewObjectId: objectId} : {})};
  };
  const original = asset("wall.png", digest(bytes));
  const thumb = asset("thumb_wall.png", "d".repeat(64), true);
  const url = `https://images.example.com/previews/${thumb.objectId}.img`;
  const store = installFakeDb(t, {
    "walls/document": {id: "asset", review: true, originalProtected: true, originalObjectId: original.objectId,
      wallpaper_url: "", wallpaper_thumb: url, wallpaper_path: "", wallpaper_sha: "", thumb_path: "", thumb_sha: ""},
    "ownedAssets/asset": {status: "ready", canonicalPath: "walls/document", incarnation: 1,
      incarnationNanos: 1000000, original, thumb},
    [`r2ObjectRegistry/${original.objectId}`]: {...original, status: "active", uploadId: "imported"},
  });
  t.mock.method(R2Storage.prototype, "head", async () => ({...original, gitSha: original.sha,
    uploadId: "imported", size: bytes.length}));
  const get = t.mock.method(R2Storage.prototype, "get", async (bucket: string, object: string) => {
    assert.equal(bucket, "private");
    assert.equal(object, original.object);
    return bytes;
  });
  return {store, url, get, original};
}

test("an approved protected wall returns display pixels without charging or signing an original", async (t) => {
  const {store, url} = await setup(t);
  const before = structuredClone([...store.entries()]);
  const preview = await loadWallpaperPreview("asset", url);
  const metadata = await sharp(preview).metadata();
  assert.equal(metadata.width, 1200);
  assert.equal(metadata.height, 2000);
  assert.equal(metadata.format, "jpeg");
  assert.deepEqual([...store.entries()], before);
});

test("withheld, stale, ambiguous, or invalid wall identities never read original bytes", async (t) => {
  const {store, url, get} = await setup(t);
  const wall = store.get("walls/document");
  assert.ok(wall);
  for (const patch of [{review: false}, {is_streak_exclusive: true}, {dropReserved: true}, {dropWeek: "future"},
    {wallpaper_thumb: "changed"}, {originalObjectId: "changed"}]) {
    store.set("walls/document", {...wall, ...patch});
    await assert.rejects(loadWallpaperPreview("asset", url));
  }
  store.set("walls/document", wall);
  await assert.rejects(loadWallpaperPreview("../asset", url));
  await assert.rejects(loadWallpaperPreview("asset", ""));
  store.set("walls/duplicate", wall);
  await assert.rejects(loadWallpaperPreview("asset", url));
  assert.equal(get.mock.callCount(), 0);
});

test("tombstoned storage and corrupt original bytes fail closed", async (t) => {
  const {store, url, original} = await setup(t);
  t.mock.method(R2Storage.prototype, "get", async () => Buffer.from("wrong bytes"));
  await assert.rejects(loadWallpaperPreview("asset", url), /source mismatch/);
  store.delete(`r2ObjectRegistry/${original.objectId}`);
  await assert.rejects(loadWallpaperPreview("asset", url));
});

test("preview endpoint is available in both app regions with bounded concurrency", () => {
  assert.deepEqual(wallpaperPreview.__endpoint.region, ["asia-south1", "us-central1"]);
  assert.equal(wallpaperPreview.__endpoint.concurrency, 1);
});


test("HTTP rejects unsupported methods and query shapes without cacheable errors", async () => {
  for (const [method, query, expected] of [
    ["POST", {}, 405], ["GET", {}, 400], ["GET", {id: ["asset"], thumb: "url"}, 400],
    ["GET", {id: "asset", thumb: "url", url: "https://private"}, 400],
    ["GET", {id: "../asset", thumb: "url"}, 404],
  ] as const) {
    let status = 200;
    const headers: Record<string, string> = {};
    const response = {
      set(key: string, value: string) {
        headers[key] = value;
        return this;
      },
      status(value: number) {
        status = value;
        return this;
      },
      send() {
        return this;
      },
    };
    await wallpaperPreview({method, query} as unknown as Parameters<typeof wallpaperPreview>[0],
      response as unknown as Parameters<typeof wallpaperPreview>[1]);
    assert.equal(status, expected);
    assert.equal(headers["Cache-Control"], "no-store");
  }
});
