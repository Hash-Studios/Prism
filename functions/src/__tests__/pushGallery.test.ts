process.env.R2_PREVIEW_BASE_URL = "https://img.example.com";

import assert from "node:assert/strict";
import {randomBytes} from "node:crypto";
import test from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {
  buildPushGallery,
  galleryObjectKey,
  galleryOrder,
  galleryRects,
  galleryTags,
  galleryWall,
  GALLERY_MAX_BYTES,
  isGalleryWall,
  pickGalleryWalls,
  renderGallery,
  similarWallIds,
  tagsLine,
  wallTags,
  type GalleryDeps,
  type GalleryWall,
} from "../pushGallery";

const PREVIEW = "https://img.example.com/previews/abc.img";
const base = {review: true, originalProtected: true, collections: ["abstract"]};

async function noisePng(width: number, height: number): Promise<Buffer> {
  return sharp(randomBytes(width * height * 3), {raw: {width, height, channels: 3}}).png().toBuffer();
}

function gw(id: string, tags: string[] = ["Night"]): GalleryWall {
  return {id, thumb: `https://img.example.com/previews/${id}.img`, tags};
}

test("strip rects for four walls are equal tiles in a centred row", () => {
  const rects = galleryRects("strip", 4);
  assert.deepEqual(rects.map((r) => r.x), [16, 311, 606, 901]);
  assert.deepEqual(rects.map((r) => r.y), [16, 16, 16, 16]);
  assert.deepEqual(rects.map((r) => r.w), [283, 283, 283, 283]);
  assert.deepEqual(rects.map((r) => r.h), [513, 513, 513, 513]);
});

test("strip rects for three and two walls are centred", () => {
  assert.deepEqual(galleryRects("strip", 3).map((r) => r.x), [163.5, 458.5, 753.5]);
  assert.deepEqual(galleryRects("strip", 2).map((r) => r.x), [311, 606]);
});

test("hero rects put the lead wall in the centre square and the side walls outside it", () => {
  const rects = galleryRects("hero", 3);
  assert.deepEqual(rects, [
    {x: 344, y: 16, w: 512, h: 513},
    {x: 16, y: 16, w: 310, h: 513},
    {x: 874, y: 16, w: 310, h: 513},
  ]);
  const squareStart = (1200 - 545) / 2;
  const squareEnd = squareStart + 545;
  assert.equal(squareStart, 327.5);
  assert.equal(squareEnd, 872.5);
  const [lead, left, right] = rects;
  assert.ok(lead.x >= squareStart && lead.x + lead.w <= squareEnd);
  assert.ok(left.x + left.w <= squareStart);
  assert.ok(right.x >= squareEnd);
});

test("renderGallery makes a 1200x545 JPEG under the byte cap for four strip tiles", async () => {
  const thumbs = await Promise.all([1, 2, 3, 4].map(() => noisePng(600, 1300)));
  const out = await renderGallery(thumbs, galleryRects("strip", 4));
  const meta = await sharp(out).metadata();
  assert.equal(meta.format, "jpeg");
  assert.equal(meta.width, 1200);
  assert.equal(meta.height, 545);
  assert.ok(out.length <= GALLERY_MAX_BYTES);
});

test("renderGallery makes a 1200x545 JPEG under the byte cap for three hero tiles", async () => {
  const thumbs = await Promise.all([1, 2, 3].map(() => noisePng(600, 1300)));
  const out = await renderGallery(thumbs, galleryRects("hero", 3));
  const meta = await sharp(out).metadata();
  assert.equal(meta.format, "jpeg");
  assert.equal(meta.width, 1200);
  assert.equal(meta.height, 545);
  assert.ok(out.length <= GALLERY_MAX_BYTES);
});

test("isGalleryWall gates a normal wall by review, premium and reserved flags", () => {
  const premium = ["space"];
  assert.equal(isGalleryWall({...base}, premium), true);
  assert.equal(isGalleryWall({...base, collections: ["space"]}, premium), false);
  assert.equal(isGalleryWall({...base, is_streak_exclusive: true}, premium), false);
  assert.equal(isGalleryWall({...base, dropReserved: true}, premium), false);
  assert.equal(isGalleryWall({...base, dropWeek: "2026-W44"}, premium), false);
  assert.equal(isGalleryWall({...base, review: false}, premium), false);
});

test("isGalleryWall with a drop week shows only that drop's walls", () => {
  const premium = ["space"];
  const week = "2026-W44";
  assert.equal(isGalleryWall({dropWeek: "2026-W44", review: false}, premium, week), true);
  assert.equal(isGalleryWall({dropWeek: "2026-W43"}, premium, week), false);
  assert.equal(isGalleryWall({dropWeek: "2026-W44", dropReserved: true}, premium, week), false);
  assert.equal(isGalleryWall({dropWeek: "2026-W44", is_streak_exclusive: true}, premium, week), false);
});

test("galleryWall keeps a wall on the preview host and drops every other thumb or premium wall", () => {
  const wall = (thumb: string) => galleryWall({id: "doc1", data: {...base, id: "W1", wallpaper_thumb: thumb}}, []);
  assert.deepEqual(wall(PREVIEW), {id: "W1", thumb: PREVIEW, tags: ["Abstract"]});
  assert.equal(wall("https://evil.example.com/previews/abc.img"), null);
  assert.equal(wall("https://img.example.com/originals/abc.img"), null);
  assert.equal(wall("https://img.example.com/previews/abc.img?x=1"), null);
  assert.equal(wall("https://img.example.com/previews/../x.img"), null);
  const premium = galleryWall(
    {id: "doc1", data: {...base, id: "W1", collections: ["space"], wallpaper_thumb: PREVIEW}},
    ["space"],
  );
  assert.equal(premium, null);
});

test("pickGalleryWalls keeps up to four walls in order and needs at least two", () => {
  const five = ["a", "b", "c", "d", "e"].map((id) => gw(id));
  assert.deepEqual(pickGalleryWalls(five)?.map((w) => w.id), ["a", "b", "c", "d"]);
  assert.deepEqual(pickGalleryWalls(five.slice(0, 3))?.map((w) => w.id), ["a", "b", "c"]);
  assert.deepEqual(pickGalleryWalls(five.slice(0, 2))?.map((w) => w.id), ["a", "b"]);
  assert.equal(pickGalleryWalls(five.slice(0, 1)), null);
  const a = gw("a");
  const b = gw("b");
  assert.deepEqual(pickGalleryWalls([a, a, b])?.map((w) => w.id), ["a", "b"]);
});

test("galleryObjectKey ignores strip order and separates layouts", () => {
  assert.equal(galleryObjectKey("strip", ["b", "a", "c", "d"]), galleryObjectKey("strip", ["d", "c", "b", "a"]));
  assert.notEqual(galleryObjectKey("hero", ["a", "b", "c"]), galleryObjectKey("hero", ["b", "a", "c"]));
  assert.notEqual(galleryObjectKey("hero", ["a", "b", "c"]), galleryObjectKey("strip", ["a", "b", "c"]));
  for (const key of [
    galleryObjectKey("strip", ["a", "b"]),
    galleryObjectKey("hero", ["a", "b", "c"]),
  ]) {
    assert.match(key, /^push-gallery\/v1\/[a-f0-9]{64}\.jpg$/);
  }
});

test("galleryOrder sorts the strip and keeps the lead wall first in the hero", () => {
  assert.deepEqual(galleryOrder("strip", ["c", "a", "b"]), ["a", "b", "c"]);
  assert.deepEqual(galleryOrder("hero", ["c", "b", "a", "d"]), ["c", "a", "b"]);
});

test("buildPushGallery stores both images for four walls", async () => {
  const puts: unknown[][] = [];
  const storage = {
    head: async () => null,
    put: async (...args: unknown[]) => {
      puts.push(args);
      return true;
    },
  };
  const thumb = await noisePng(60, 130);
  const request = async () => new Response(new Uint8Array(thumb), {status: 200});
  const ids = ["d1", "b2", "c3", "a4"];
  const walls = ids.map((id) => gw(id, ["Night"]));
  const result = await buildPushGallery(walls, {
    storage: storage as unknown as GalleryDeps["storage"],
    request: request as unknown as typeof fetch,
  });
  assert.ok(result);
  assert.equal(result.count, 4);
  assert.deepEqual(result.wallIds, ["d1", "b2", "c3", "a4"]);
  assert.equal(result.thumbIndex, 3);
  assert.deepEqual(result.tags, ["Night"]);
  assert.equal(result.stripUrl, `https://img.example.com/${galleryObjectKey("strip", ids)}`);
  assert.equal(result.heroUrl, `https://img.example.com/${galleryObjectKey("hero", ids)}`);
  assert.equal(puts.length, 2);
  for (const put of puts) {
    assert.equal(put[0], "preview");
    assert.equal(put[4], "image/jpeg");
  }
});

test("buildPushGallery reuses stored images without fetching thumbs", async () => {
  let puts = 0;
  let requests = 0;
  const storage = {
    head: async () => ({size: 1}),
    put: async () => {
      puts += 1;
      return true;
    },
  };
  const request = async () => {
    requests += 1;
    return new Response(new Uint8Array(await noisePng(60, 130)), {status: 200});
  };
  const ids = ["d1", "b2", "c3", "a4"];
  const result = await buildPushGallery(ids.map((id) => gw(id)), {
    storage: storage as unknown as GalleryDeps["storage"],
    request: request as unknown as typeof fetch,
  });
  assert.equal(result?.stripUrl, `https://img.example.com/${galleryObjectKey("strip", ids)}`);
  assert.equal(result?.heroUrl, `https://img.example.com/${galleryObjectKey("hero", ids)}`);
  assert.equal(puts, 0);
  assert.equal(requests, 0);
});

test("buildPushGallery uses a hero image for three walls and the lead thumb for two", async () => {
  const thumb = await noisePng(60, 130);
  const storage = {head: async () => null, put: async () => true};
  const request = async () => new Response(new Uint8Array(thumb), {status: 200});
  const deps = {
    storage: storage as unknown as GalleryDeps["storage"],
    request: request as unknown as typeof fetch,
  };
  const three = await buildPushGallery(["a", "b", "c"].map((id) => gw(id)), deps);
  assert.equal(three?.count, 3);
  assert.equal(three?.heroUrl, `https://img.example.com/${galleryObjectKey("hero", ["a", "b", "c"])}`);

  const puts: unknown[][] = [];
  const countingStorage = {
    head: async () => null,
    put: async (...args: unknown[]) => {
      puts.push(args);
      return true;
    },
  };
  const two = await buildPushGallery([gw("x1"), gw("x2")], {
    storage: countingStorage as unknown as GalleryDeps["storage"],
    request: request as unknown as typeof fetch,
  });
  assert.equal(two?.count, 2);
  assert.equal(two?.heroUrl, "https://img.example.com/previews/x1.img");
  assert.equal(puts.length, 1);
});

test("buildPushGallery returns null for one wall without fetching", async () => {
  let requests = 0;
  const result = await buildPushGallery([gw("solo")], {
    storage: {head: async () => null, put: async () => true} as unknown as GalleryDeps["storage"],
    request: (async () => {
      requests += 1;
      return new Response(null, {status: 200});
    }) as unknown as typeof fetch,
  });
  assert.equal(result, null);
  assert.equal(requests, 0);
});

test("buildPushGallery returns null when a thumb fetch fails", async () => {
  const result = await buildPushGallery([gw("a1"), gw("a2")], {
    storage: {head: async () => null, put: async () => true} as unknown as GalleryDeps["storage"],
    request: (async () => {
      throw new Error("network down");
    }) as unknown as typeof fetch,
  });
  assert.equal(result, null);
});

test("wallTags keeps short, unique, non-generic tags in sentence case", () => {
  assert.deepEqual(wallTags({
    visionLabels: ["Night city", "Community", "general", "A very very long label here", "night CITY"],
    collections: ["abstract"],
  }), ["Night city", "Abstract"]);
});

test("galleryTags ranks the most shared tags first", () => {
  assert.deepEqual(galleryTags([
    {tags: ["Night", "City"]},
    {tags: ["night", "Neon"]},
    {tags: ["Neon"]},
  ]), ["Night", "Neon", "City"]);
});

test("tagsLine joins tags with a middle dot", () => {
  assert.equal(tagsLine(["A", "B"]), "A · B");
});

test("similarWallIds returns the closest gated walls, newest first on a tie", () => {
  const pick = {id: "p", data: {...base, id: "P", wallpaper_thumb: PREVIEW, visionLabels: ["Night", "Neon"]}};
  const cand = (id: string, visionLabels: string[], createdMs: number, collections: string[] = []) => ({
    id,
    data: {
      ...base,
      id,
      collections,
      visionLabels,
      wallpaper_thumb: PREVIEW,
      createdAt: admin.firestore.Timestamp.fromMillis(createdMs),
    },
  });
  const candidates = [
    pick,
    cand("x1", ["Night", "Neon"], 1000),
    cand("x2", ["Night"], 3000),
    cand("x3", ["Night"], 2000),
    cand("x4", ["Night", "Neon"], 4000, ["space"]),
    cand("x5", ["Forest"], 5000),
    cand("x6", ["Neon"], 500),
  ];
  assert.deepEqual(similarWallIds(pick, candidates, ["space"], 3), ["x1", "x2", "x3"]);
});
