import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test, {type TestContext} from "node:test";
import sharp from "sharp";
import {webCatalogDeps} from "../webCatalog";
import {DESKTOP_WEB_SIZES, loadWallpaperPreview, wallpaperPreview} from "../wallpaperPreview";
import {R2Storage} from "../r2Storage";
import {installFakeDb, type Doc} from "./fakeDb";

const PREVIEW = "https://images.example.com";
const WALL_THUMB = `${PREVIEW}/previews/phone-thumb.img`;

const digest = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

async function setup(t: TestContext) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: PREVIEW});
  const originalBytes = await sharp({create: {width: 2560, height: 1600, channels: 3, background: "navy"}})
    .jpeg().toBuffer();
  const wideBytes = await sharp({create: {width: 2560, height: 1440, channels: 3, background: "teal"}})
    .jpeg().toBuffer();
  const originalSha = digest(originalBytes);
  const wideSha = digest(wideBytes);
  const originalObject = `desktop-originals/W1/${originalSha}.jpg`;
  const wideObject = `desktop-originals/W1/${wideSha}.jpg`;
  const variant = {v: originalSha.slice(0, 16), width: 2560, height: 1600, wideHeight: 1440,
    thumb: `${PREVIEW}/previews/desktop-${originalSha}.jpg`};
  const baseWall: Doc = {id: "W1", review: true, originalProtected: true, collections: ["community"],
    is_streak_exclusive: false, dropReserved: false, wallpaper_thumb: WALL_THUMB, desktopVariant: variant};
  const store = installFakeDb(t, {
    "walls/W1": baseWall,
    "desktopCompanions/W1": {status: "ready",
      original: {object: originalObject, sha256: originalSha, width: 2560, height: 1600, bytes: originalBytes.length},
      wide: {object: wideObject, sha256: wideSha, width: 2560, height: 1440, bytes: wideBytes.length}},
  });
  let premium: () => Promise<string[]> = async () => ["premium"];
  t.mock.method(webCatalogDeps, "premium", async () => premium());
  const cache = new Map<string, {bytes: Buffer; sha256: string}>();
  const gets: string[] = [];
  const heads: string[] = [];
  t.mock.method(R2Storage.prototype, "head", async (_bucket: string, object: string) => {
    heads.push(object);
    if (object === originalObject) return {size: originalBytes.length, sha256: originalSha} as never;
    if (object === wideObject) return {size: wideBytes.length, sha256: wideSha} as never;
    const value = cache.get(object);
    return value ? {size: value.bytes.length, sha256: value.sha256} as never : null;
  });
  t.mock.method(R2Storage.prototype, "get", async (_bucket: string, object: string) => {
    gets.push(object);
    if (object === originalObject) return originalBytes;
    if (object === wideObject) return wideBytes;
    const cached = cache.get(object);
    if (cached) return cached.bytes;
    throw new Error("R2 GET failed (404)");
  });
  t.mock.method(R2Storage.prototype, "put", async (_bucket: string, object: string, bytes: Buffer,
    metadata: Record<string, string>) => {
    cache.set(object, {bytes, sha256: metadata.sha256});
    return true;
  });
  return {store, baseWall, version: variant.v, originalObject, wideObject,
    premium: (next: () => Promise<string[]>) => premium = next, cache, gets, heads};
}

test("desktop web renditions match each public size and never return the 2560px source", async (t) => {
  const {baseWall, version, originalObject, wideObject} = await setup(t);
  const sizes = [
    ["desktop", originalObject, {width: 2560, height: 1600}, DESKTOP_WEB_SIZES.desktop],
    ["desktop-16x9", wideObject, {width: 2560, height: 1440}, DESKTOP_WEB_SIZES["desktop-16x9"]],
  ] as const;

  for (const [variant, , sourceSize, outputSize] of sizes) {
    const bytes = await loadWallpaperPreview("W1", WALL_THUMB, variant, version);
    const metadata = await sharp(bytes).metadata();
    assert.equal(metadata.format, "jpeg");
    assert.deepEqual({width: metadata.width, height: metadata.height}, outputSize);
    assert.notDeepEqual({width: metadata.width, height: metadata.height}, sourceSize);
  }
  assert.equal(baseWall.desktopVariant && (baseWall.desktopVariant as Doc).v, version);
});

test("a cached desktop derivative is refused after a current premium or exclusivity gate, or version mismatch", async (t) => {
  const {store, baseWall, version, premium, cache, gets} = await setup(t);
  await loadWallpaperPreview("W1", WALL_THUMB, "desktop", version);
  assert.ok(cache.size > 0, "the tested path must have a warm derivative cache");
  const cacheReadsBefore = gets.filter((key) => key.startsWith("display-previews/")).length;

  const gates: Array<[string, Doc, () => Promise<string[]>]> = [
    ["premium collection", {...baseWall, collections: ["premium"]}, async () => ["premium"]],
    ["streak exclusive", {...baseWall, is_streak_exclusive: true}, async () => ["premium"]],
    ["drop reserved", {...baseWall, dropReserved: true}, async () => ["premium"]],
    ["drop week", {...baseWall, dropWeek: "2026-W44"}, async () => ["premium"]],
    ["unreviewed", {...baseWall, review: false}, async () => ["premium"]],
    ["Remote Config unavailable", baseWall, async () => {
      throw new Error("Remote Config unavailable");
    }],
    ["stale version", {...baseWall, desktopVariant: {...baseWall.desktopVariant as Doc, v: "f".repeat(16)}},
      async () => ["premium"]],
  ];
  for (const [reason, wall, config] of gates) {
    store.set("walls/W1", wall);
    premium(config);
    const requestedVersion = reason === "stale version" ? "f".repeat(16) : version;
    await assert.rejects(loadWallpaperPreview("W1", WALL_THUMB, "desktop", requestedVersion),
      (error: unknown) => {
        assert.ok(error instanceof Error, reason);
        return true;
      });
  }
  assert.equal(gets.filter((key) => key.startsWith("display-previews/")).length, cacheReadsBefore);
});

test("invalid desktop preview query shapes fail before any R2 HEAD or GET", async (t) => {
  const {heads, gets, version} = await setup(t);
  for (const query of [
    {id: "W1", thumb: WALL_THUMB, variant: "unknown", v: version},
    {id: "W1", thumb: WALL_THUMB, variant: "desktop", v: "not-a-version"},
    {id: "W1", thumb: WALL_THUMB, variant: "desktop", v: version, extra: "value"},
  ]) {
    let status = 200;
    const response = {
      set() {
        return this;
      },
      status(value: number) {
        status = value;
        return this;
      },
      type() {
        return this;
      },
      send() {
        return this;
      },
    };
    await wallpaperPreview({method: "GET", query} as unknown as Parameters<typeof wallpaperPreview>[0],
      response as unknown as Parameters<typeof wallpaperPreview>[1]);
    assert.equal(status, 400);
  }
  assert.deepEqual(heads, []);
  assert.deepEqual(gets, []);
});
