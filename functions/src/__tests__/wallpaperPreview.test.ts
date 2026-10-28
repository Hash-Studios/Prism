import assert from "node:assert/strict";
import test from "node:test";
import {createHash} from "node:crypto";
import sharp from "sharp";
import {loadWallpaperPreview, previewCacheObject, renderWallpaperPreview, wallpaperPreview} from "../wallpaperPreview";
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
  const stored = new Map<string, {bytes: Buffer; sha256: string}>();
  let sourceBytes: Buffer = bytes;
  let originalHead = {...original, gitSha: original.sha, uploadId: "imported", size: bytes.length};
  t.mock.method(R2Storage.prototype, "head", async (bucket: string, object: string) => {
    assert.equal(bucket, "private");
    if (object === original.object) return originalHead;
    const cached = stored.get(object);
    return cached ? {...original, sha256: cached.sha256, size: cached.bytes.length} : null;
  });
  const get = t.mock.method(R2Storage.prototype, "get", async (bucket: string, object: string) => {
    assert.equal(bucket, "private");
    if (object === original.object) return sourceBytes;
    const cached = stored.get(object);
    if (!cached) throw new Error("R2 GET failed (404)");
    return cached.bytes;
  });
  const put = t.mock.method(R2Storage.prototype, "put",
    async (bucket: string, object: string, body: Buffer, metadata: Record<string, string>) => {
      assert.equal(bucket, "private");
      stored.set(object, {bytes: body, sha256: metadata.sha256});
      return true;
    });
  const originalReads = () => get.mock.calls.filter((call) => call.arguments[1] === original.object).length;
  return {store, url, get, put, stored, original, originalReads,
    setSourceBytes: (next: Buffer) => { sourceBytes = next; },
    setOriginalHead: (patch: Partial<typeof originalHead>) => { originalHead = {...originalHead, ...patch}; }};
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

test("the first request stores the rendered preview and later requests serve it without re-rendering",
  async (t) => {
    const {url, stored, original, originalReads, put} = await setup(t);
    const first = await loadWallpaperPreview("asset", url);
    const object = previewCacheObject("asset", original.sha256);
    assert.equal(object, `display-previews/asset/${original.sha256}.jpg`);
    assert.deepEqual(stored.get(object)?.bytes, first);
    assert.equal(stored.get(object)?.sha256, digest(first));
    assert.equal(put.mock.callCount(), 1);
    const second = await loadWallpaperPreview("asset", url);
    assert.deepEqual(second, first);
    assert.equal(originalReads(), 2);
    assert.equal(put.mock.callCount(), 1);
  });

test("a stored preview that does not match its digest is rendered again from the verified original", async (t) => {
  const {url, stored, original, originalReads} = await setup(t);
  stored.set(previewCacheObject("asset", original.sha256), {bytes: Buffer.from("tampered"), sha256: "e".repeat(64)});
  const preview = await loadWallpaperPreview("asset", url);
  assert.equal((await sharp(preview).metadata()).format, "jpeg");
  assert.equal(originalReads(), 1);
});

test("a cached preview is refused when original bytes no longer match the registered SHA", async (t) => {
  const {url, stored, original, get, setSourceBytes} = await setup(t);
  const cacheObject = previewCacheObject("asset", original.sha256);
  await loadWallpaperPreview("asset", url);
  const cachedBytes = stored.get(cacheObject)?.bytes;
  assert.ok(cachedBytes);

  setSourceBytes(Buffer.from("tampered original"));
  await assert.rejects(loadWallpaperPreview("asset", url), /source mismatch/);
  assert.deepEqual(stored.get(cacheObject)?.bytes, cachedBytes);
  assert.equal(get.mock.calls.filter((call) => call.arguments[1] === cacheObject).length, 1);
});

test("a failed store still returns the rendered preview", async (t) => {
  const {url, put} = await setup(t);
  put.mock.mockImplementation(async () => {
    throw new Error("R2 PUT failed (500)");
  });
  const preview = await loadWallpaperPreview("asset", url);
  assert.equal((await sharp(preview).metadata()).format, "jpeg");
});

test("a withdrawn wall is refused even when its preview is stored", async (t) => {
  const {store, url, get} = await setup(t);
  await loadWallpaperPreview("asset", url);
  const reads = get.mock.callCount();
  const wall = store.get("walls/document");
  assert.ok(wall);
  for (const patch of [{review: false}, {is_streak_exclusive: true}, {dropReserved: true}, {dropWeek: "future"}]) {
    store.set("walls/document", {...wall, ...patch});
    await assert.rejects(loadWallpaperPreview("asset", url));
  }
  assert.equal(get.mock.callCount(), reads);
});

test("registry and original SHA checks run before a cached preview is read", async (t) => {
  const {store, url, get, original, setOriginalHead} = await setup(t);
  await loadWallpaperPreview("asset", url);
  const cacheReads = () => get.mock.calls.filter((call) => call.arguments[1] !== original.object).length;
  const readsAfterWarmup = cacheReads();

  const registryPath = `r2ObjectRegistry/${original.objectId}`;
  const registry = store.get(registryPath);
  assert.ok(registry);
  store.set(registryPath, {...registry, status: "tombstoned"});
  await assert.rejects(loadWallpaperPreview("asset", url));
  assert.equal(cacheReads(), readsAfterWarmup);

  store.set(registryPath, registry);
  setOriginalHead({sha256: "e".repeat(64)});
  await assert.rejects(loadWallpaperPreview("asset", url));
  assert.equal(cacheReads(), readsAfterWarmup);
});

test("duplicate wall identities are rejected before a cached preview is read", async (t) => {
  const {store, url, get, original} = await setup(t);
  await loadWallpaperPreview("asset", url);
  const cacheReads = () => get.mock.calls.filter((call) => call.arguments[1] !== original.object).length;
  const readsAfterWarmup = cacheReads();
  store.set("walls/duplicate", store.get("walls/document")!);
  await assert.rejects(loadWallpaperPreview("asset", url));
  assert.equal(cacheReads(), readsAfterWarmup);
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
  assert.equal(wallpaperPreview.__endpoint.concurrency, 8);
  assert.equal(wallpaperPreview.__endpoint.availableMemoryMb, 1024);
});

test("a served preview may be kept by the device for a year but never by a shared cache", async (t) => {
  const {url} = await setup(t);
  const headers: Record<string, string> = {};
  let body: Buffer | undefined;
  const response = {
    set(key: string, value: string) {
      headers[key] = value;
      return this;
    },
    status() {
      return this;
    },
    type() {
      return this;
    },
    send(value: Buffer) {
      body = value;
      return this;
    },
  };
  await wallpaperPreview({method: "GET", query: {id: "asset", thumb: url}} as unknown as
    Parameters<typeof wallpaperPreview>[0], response as unknown as Parameters<typeof wallpaperPreview>[1]);
  assert.equal(headers["Cache-Control"], "private, max-age=31536000, immutable");
  assert.ok(body && body.length > 0);
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
