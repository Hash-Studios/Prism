import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {backfillWallSignatures, parseBackfillArgs} from "../scripts/backfillWallSignatures";
import {db} from "../common";
import {STUDIO_ACCOUNT} from "../studio/account";
import {imageSignature} from "../studio/gates";
import {isStudioWall} from "../studio/isStudioWall";
import {fetchImageBuffer} from "../wallColors";
import {
  buildModeration,
  type ModerationAnnotate,
  type ModerationDeps,
  type ModerationVisionResult,
  moderateWall,
  onWallModerate,
} from "../wallModeration";
import {type Doc, installFakeDb} from "./fakeDb";

const W = 32;
const H = 72;
const url = (name: string) => `https://raw.githubusercontent.com/o/r/main/${name}.jpg`;

/** Two images with no correlation: tones that change down the image, and tones that change across it. */
function gradient(axis: "down" | "across"): Promise<Buffer> {
  const raw = Buffer.alloc(W * H * 3);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      raw.fill(axis === "down" ? Math.round(y * 255 / (H - 1)) : Math.round(x * 255 / (W - 1)), (y * W + x) * 3, (y * W + x) * 3 + 3);
    }
  }
  return sharp(raw, {raw: {width: W, height: H, channels: 3}}).png().toBuffer();
}

const CLEAR: ModerationVisionResult = {
  safeSearchAnnotation: {adult: "VERY_UNLIKELY", racy: "UNLIKELY", violence: "VERY_UNLIKELY", medical: "UNLIKELY"},
  textAnnotations: [],
  logoAnnotations: [],
  webDetection: {fullMatchingImages: [], pagesWithMatchingImages: []},
};

const EMPTY = {v: 1, flags: [], duplicate: null, web: [], words: [], logos: [], unsafe: []};

function deps(images: Record<string, Buffer>, annotate: ModerationAnnotate = async () => CLEAR) {
  const fetched: string[] = [];
  const value: ModerationDeps = {
    fetchImage: async (imageUrl) => {
      fetched.push(imageUrl);
      const bytes = images[imageUrl];
      if (!bytes) throw new Error("image request failed with 404");
      return bytes;
    },
    annotate,
  };
  return {value, fetched};
}

function quiet(t: TestContext) {
  return {
    warn: t.mock.method(logger, "warn", () => undefined),
    error: t.mock.method(logger, "error", () => undefined),
    info: t.mock.method(logger, "info", () => undefined),
  };
}

const withoutTime = (moderation: unknown) => {
  const {checkedAt, ...rest} = moderation as Doc;
  // The fake db leaves a server timestamp inside a map as its marker.
  assert.deepEqual(checkedAt, {__op: "ts"});
  return rest;
};

test("a clear image gets an empty moderation and its signature is stored", async (t) => {
  quiet(t);
  const image = await gradient("down");
  const store = installFakeDb(t, {"walls/w1": {wallpaper_url: url("a")}});
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: image}).value);
  assert.deepEqual(withoutTime(store.get("walls/w1")?.moderation), EMPTY);
  const stored = store.get("wallSignatures/w1");
  assert.equal(stored?.signature, await imageSignature(image));
  assert.equal(stored?.wallId, "w1");
  assert.ok(stored?.createdAt instanceof admin.firestore.Timestamp);
});

test("a near copy of a known wall is flagged with the matched wall's thumbnail", async (t) => {
  quiet(t);
  const image = await gradient("down");
  const store = installFakeDb(t, {
    "walls/w1": {wallpaper_url: url("a")},
    "walls/old": {wallpaper_thumb: url("old-thumb")},
    "wallSignatures/old": {signature: await imageSignature(image), wallId: "old"},
    "wallSignatures/other": {signature: await imageSignature(await gradient("across")), wallId: "other"},
    "wallSignatures/w1": {signature: await imageSignature(image), wallId: "w1"},
  });
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: image}).value);
  assert.deepEqual(withoutTime(store.get("walls/w1")?.moderation), {
    ...EMPTY,
    flags: ["duplicate"],
    duplicate: {wallId: "old", similarity: 1, thumb: url("old-thumb")},
  });
});

test("a copy of a Studio wall is flagged, and a matched wall with no doc gives an empty thumbnail", async (t) => {
  quiet(t);
  const image = await gradient("across");
  const store = installFakeDb(t, {
    "walls/w1": {wallpaper_url: url("a")},
    "studioSignatures/c1": {signature: await imageSignature(image), wallId: "studio-wall", candidateId: "c1"},
  });
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: image}).value);
  assert.deepEqual(withoutTime(store.get("walls/w1")?.moderation), {
    ...EMPTY,
    flags: ["duplicate"],
    duplicate: {wallId: "studio-wall", similarity: 1, thumb: ""},
  });
});

test("the thumbnail is read when the original is private", async (t) => {
  quiet(t);
  const image = await gradient("down");
  const wall = {wallpaper_url: "", wallpaper_thumb: url("thumb")};
  const store = installFakeDb(t, {"walls/w1": wall});
  const {value, fetched} = deps({[url("thumb")]: image});
  await moderateWall("w1", wall, value);
  assert.deepEqual(fetched, [url("thumb")]);
  assert.deepEqual(withoutTime(store.get("walls/w1")?.moderation), EMPTY);
});

test("a private original with an exact R2 preview is moderated through the real image fetcher", async (t) => {
  quiet(t);
  const previousEnv = {...process.env};
  t.after(() => {
    process.env = previousEnv;
  });
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com/assets";

  const image = await gradient("down");
  const preview = `https://images.example.com/assets/previews/${"a".repeat(64)}.img`;
  const wall = {wallpaper_url: "", wallpaper_thumb: preview};
  const store = installFakeDb(t, {"walls/w1": wall});
  const fetched: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    fetched.push(String(input));
    return new Response(new Uint8Array(image), {headers: {"content-type": "image/png"}});
  });

  await moderateWall("w1", wall, {
    fetchImage: (imageUrl) => fetchImageBuffer(imageUrl),
    annotate: async () => CLEAR,
  });

  assert.deepEqual(fetched, [preview]);
  assert.deepEqual(withoutTime(store.get("walls/w1")?.moderation), EMPTY);
  assert.equal(store.get("wallSignatures/w1")?.signature, await imageSignature(image));
});

test("the thumbnail is the fallback when the original cannot be read", async (t) => {
  quiet(t);
  const image = await gradient("down");
  const wall = {wallpaper_url: url("gone"), wallpaper_thumb: url("thumb")};
  const store = installFakeDb(t, {"walls/w1": wall});
  const {value, fetched} = deps({[url("thumb")]: image});
  await moderateWall("w1", wall, value);
  assert.deepEqual(fetched, [url("gone"), url("thumb")]);
  assert.ok(store.get("walls/w1")?.moderation);
});

test("a wall with no readable image gets no signature and no moderation", async (t) => {
  const log = quiet(t);
  const wall = {wallpaper_url: url("gone"), wallpaper_thumb: url("gone")};
  const store = installFakeDb(t, {"walls/w1": wall});
  const {value, fetched} = deps({[url("notimage")]: Buffer.from("not an image")});
  await moderateWall("w1", wall, value);
  await moderateWall("w1", {wallpaper_url: url("notimage")}, value);
  assert.deepEqual(fetched, [url("gone"), url("notimage")]);
  assert.equal(store.get("walls/w1")?.moderation, undefined);
  assert.equal(store.has("wallSignatures/w1"), false);
  assert.equal(log.warn.mock.callCount() >= 3, true);
});

test("web matches keep other sites, drop own hosts, strip www and cap at five", async () => {
  const page = (pageUrl: string, full = [{url: "https://cdn.example.com/x.jpg"}]) =>
    ({url: pageUrl, fullMatchingImages: full});
  const result = buildModeration(null, {
    ...CLEAR,
    webDetection: {
      fullMatchingImages: [{url: "https://ignored.example.com/never-used.jpg"}],
      pagesWithMatchingImages: [
        page("https://WWW.Pinterest.com/pin/1"),
        page("https://raw.githubusercontent.com/o/r/main/a.jpg"),
        page("https://user.githubusercontent.com/a.jpg"),
        page("https://cdn.prismwalls.com/a.jpg"),
        page("https://prismwalls.com/a.jpg"),
        page("https://notprismwalls.com/a.jpg"),
        page("https://www.pinterest.com/pin/1"),
        page("https://www.pinterest.com/pin/1"),
        page("not a url"),
        page("https://partial.example.com/p", []),
        page("https://b.example.org/2"),
        page("https://c.example.org/3"),
        page("https://d.example.org/4"),
        page("https://e.example.org/5"),
        page("https://f.example.org/6"),
      ],
    },
  });
  assert.deepEqual(result, {
    ...EMPTY,
    flags: ["web_match"],
    web: [
      {url: "https://WWW.Pinterest.com/pin/1", host: "pinterest.com"},
      {url: "https://notprismwalls.com/a.jpg", host: "notprismwalls.com"},
      {url: "https://www.pinterest.com/pin/1", host: "pinterest.com"},
      {url: "https://b.example.org/2", host: "b.example.org"},
      {url: "https://c.example.org/3", host: "c.example.org"},
    ],
  });
});

test("full matching images are used when no page has a full match", async () => {
  const result = buildModeration(null, {
    ...CLEAR,
    webDetection: {
      fullMatchingImages: [{url: "https://www.Example.com/a.jpg"}, {url: "https://raw.githubusercontent.com/a.jpg"}],
      pagesWithMatchingImages: [{url: "https://partial.example.com/p", fullMatchingImages: []}],
    },
  });
  assert.deepEqual(result.web, [{url: "https://www.Example.com/a.jpg", host: "example.com"}]);
});

test("text, logo and unsafe signals are listed in flag order", async (t) => {
  quiet(t);
  const vision: ModerationVisionResult = {
    safeSearchAnnotation: {adult: "POSSIBLE", racy: "VERY_LIKELY", violence: "UNLIKELY", medical: "UNLIKELY"},
    textAnnotations: [
      {description: "BUY NOW\nsale"}, {description: "BUY"}, {description: "NOW"}, {description: "sale"}, {description: "a"},
    ],
    logoAnnotations: [
      {description: "Nike", score: 0.91234}, {description: "Weak", score: 0.2}, {description: "Adidas", score: 0.5},
    ],
    webDetection: {pagesWithMatchingImages: [{url: "https://shop.example.com/p", fullMatchingImages: [{url: "x"}]}]},
  };
  const image = await gradient("down");
  const store = installFakeDb(t, {
    "walls/w1": {wallpaper_url: url("a")},
    "wallSignatures/old": {signature: await imageSignature(image), wallId: "old"},
    "walls/old": {wallpaper_thumb: url("old-thumb")},
  });
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: image}, async () => vision).value);
  assert.deepEqual(withoutTime(store.get("walls/w1")?.moderation), {
    v: 1,
    flags: ["duplicate", "web_match", "text", "logo", "unsafe"],
    duplicate: {wallId: "old", similarity: 1, thumb: url("old-thumb")},
    web: [{url: "https://shop.example.com/p", host: "shop.example.com"}],
    words: ["BUY", "NOW", "sale", "a"],
    logos: ["Nike", "Adidas"],
    unsafe: ["adult", "racy"],
  });
});

test("short marks are not text, and a missing safe search result is not a flag", async () => {
  const result = buildModeration(null, {...CLEAR, safeSearchAnnotation: null, textAnnotations: [{description: "ab"}, {description: "ab"}]});
  assert.deepEqual(result, EMPTY);
});

test("Vision is asked once, with a JPEG of at most 1600 px", async (t) => {
  quiet(t);
  const big = await sharp({create: {width: 2400, height: 3200, channels: 3, background: "#336699"}}).png().toBuffer();
  installFakeDb(t, {"walls/w1": {wallpaper_url: url("a")}});
  const sent: Buffer[] = [];
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: big}, async (jpeg) => {
    sent.push(jpeg);
    return CLEAR;
  }).value);
  assert.equal(sent.length, 1);
  const meta = await sharp(sent[0]).metadata();
  assert.deepEqual([meta.format, meta.width, meta.height], ["jpeg", 1200, 1600]);
});

test("a Studio wall is skipped", async (t) => {
  quiet(t);
  const wall = {email: STUDIO_ACCOUNT.email, wallpaper_url: url("a"), origin: "studio", studioRunId: "r1",
    studioCandidateId: "c1"};
  const store = installFakeDb(t, {"walls/w1": wall, "studioRuns/r1/candidates/c1": {wallId: "w1"}});
  const {value, fetched} = deps({[url("a")]: await gradient("down")});
  await moderateWall("w1", wall, value);
  assert.deepEqual(fetched, []);
  assert.equal(store.get("walls/w1")?.moderation, undefined);
  assert.equal(store.has("wallSignatures/w1"), false);
});

test("a wall that only claims to be Studio is checked", async (t) => {
  quiet(t);
  const wall = {email: "attacker@example.com", wallpaper_url: url("a"), origin: "studio", studioRunId: "r1",
    studioCandidateId: "c1"};
  const store = installFakeDb(t, {"walls/w1": wall});
  await moderateWall("w1", wall, deps({[url("a")]: await gradient("down")}).value);
  assert.ok(store.get("walls/w1")?.moderation);
});

test("a wall with a moderation field is skipped", async (t) => {
  quiet(t);
  const wall = {wallpaper_url: url("a"), moderation: {v: 1, flags: ["text"]}};
  const store = installFakeDb(t, {"walls/w1": wall});
  const {value, fetched} = deps({[url("a")]: await gradient("down")});
  await moderateWall("w1", wall, value);
  assert.deepEqual(fetched, []);
  assert.deepEqual(store.get("walls/w1")?.moderation, {v: 1, flags: ["text"]});
});

test("when Vision fails only the signature is written", async (t) => {
  const log = quiet(t);
  const image = await gradient("down");
  const store = installFakeDb(t, {"walls/w1": {wallpaper_url: url("a")}});
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: image}, async () => {
    throw new Error("Vision error 8: quota");
  }).value);
  assert.equal(store.get("walls/w1")?.moderation, undefined);
  assert.equal(store.get("wallSignatures/w1")?.signature, await imageSignature(image));
  assert.equal(log.error.mock.callCount(), 1);
});

test("a wall deleted during the check is tolerated", async (t) => {
  const log = quiet(t);
  const store = installFakeDb(t, {"walls/w1": {wallpaper_url: url("a")}});
  await moderateWall("w1", {wallpaper_url: url("a")}, deps({[url("a")]: await gradient("down")}, async () => {
    store.delete("walls/w1");
    return CLEAR;
  }).value);
  assert.equal(store.has("walls/w1"), false);
  assert.equal(store.has("wallSignatures/w1"), true);
  assert.equal(log.error.mock.callCount(), 0);
});

test("the trigger ignores an event with no data", async (t) => {
  const store = installFakeDb(t);
  await onWallModerate.run({params: {wallId: "w1"}, data: undefined} as unknown as Parameters<typeof onWallModerate.run>[0]);
  assert.equal(store.size, 0);
});

test("the signature backfill signs reviewed walls that have none and is a dry run by default", async (t) => {
  quiet(t);
  const image = await gradient("down");
  const images: Record<string, Buffer> = {[url("a")]: image, [url("c")]: image, [url("t")]: image};
  const studio = {email: STUDIO_ACCOUNT.email, wallpaper_url: url("s"), origin: "studio", studioRunId: "r1",
    studioCandidateId: "c1"};
  const store = installFakeDb(t, {
    "walls/a": {review: true, wallpaper_url: url("a")},
    "walls/b": {review: true, wallpaper_url: url("b")},
    "walls/c": {review: true, wallpaper_url: url("c")},
    "walls/d": {review: true, wallpaper_url: "", wallpaper_thumb: url("t")},
    "walls/e": {review: false, wallpaper_url: url("a")},
    "walls/s": {review: true, ...studio},
    "studioRuns/r1/candidates/c1": {wallId: "s"},
    "wallSignatures/c": {signature: "kept", wallId: "c"},
  });
  t.mock.method(db, "bulkWriter", () => ({
    set: async (ref: {path: string}, data: Doc) => {
      store.set(ref.path, data);
    },
    flush: async () => undefined,
    close: async () => undefined,
  }));
  const backfillDeps = {
    fetchImage: async (imageUrl: string) => {
      if (!images[imageUrl]) throw new Error("image request failed with 404");
      return images[imageUrl];
    },
    isStudio: isStudioWall,
  };

  const dry = await backfillWallSignatures(db, parseBackfillArgs([]), backfillDeps, () => undefined);
  assert.deepEqual(dry, {scanned: 5, skipped: 2, signed: 2, failed: 1, written: 0});
  assert.equal(store.has("wallSignatures/a"), false);

  const applied = await backfillWallSignatures(db, parseBackfillArgs(["--apply"]), backfillDeps, () => undefined);
  assert.deepEqual(applied, {scanned: 5, skipped: 2, signed: 2, failed: 1, written: 2});
  const signature = await imageSignature(image);
  assert.equal(store.get("wallSignatures/a")?.signature, signature);
  assert.equal(store.get("wallSignatures/d")?.signature, signature);
  assert.equal(store.get("wallSignatures/d")?.wallId, "d");
  assert.deepEqual(store.get("wallSignatures/c"), {signature: "kept", wallId: "c"});
  assert.equal(store.has("wallSignatures/b"), false);
  assert.equal(store.has("wallSignatures/s"), false);
});

test("backfill arguments fall back to safe values", () => {
  assert.deepEqual(parseBackfillArgs(["--batch=9999", "--start-after="]), {apply: false, batchSize: 100, startAfter: undefined});
  assert.deepEqual(parseBackfillArgs(["--apply", "--batch=5", "--start-after=x"]), {apply: true, batchSize: 5, startAfter: "x"});
});
