import assert from "node:assert/strict";
import test from "node:test";
import sharp from "sharp";
import {
  spatialScore,
  spatialTierFor,
  type SpatialScore,
  type WallSpatialDeps,
  wallSpatialFor,
} from "../wallSpatial";

const WALL_URL = "https://raw.githubusercontent.com/o/r/main/a.jpg";
const MAP_URL = "https://v3b.fal.media/files/x.png";

/** A 64x128 grey image: the top half is 20 and the bottom half is 220. */
function twoLevelRaw(): Buffer {
  const raw = Buffer.alloc(64 * 128);
  raw.fill(220);
  raw.fill(20, 0, 64 * 64);
  return raw;
}

async function twoLevelPng(): Promise<Buffer> {
  return sharp(twoLevelRaw(), {raw: {width: 64, height: 128, channels: 1}}).png().toBuffer();
}

function falFetch(calls: Array<{url: string; init: RequestInit}>, map: Buffer, mapUrl = MAP_URL) {
  return async (url: string, init: RequestInit): Promise<Response> => {
    calls.push({url, init});
    if (url.startsWith("https://fal.run/")) return Response.json({image: {url: mapUrl}});
    return new Response(new Uint8Array(map));
  };
}

function deps(overrides: Partial<WallSpatialDeps> = {}): WallSpatialDeps {
  return {
    fetch: async () => {
      throw new Error("fetch not expected");
    },
    key: () => "k",
    store: async (object) => `https://img.example/${object}`,
    prefix: "spatial-test/v1",
    ...overrides,
  };
}

test("a two-level image splits fully into near and far parts", () => {
  const pixels = new Uint8Array(1000);
  pixels.fill(20, 0, 600);
  pixels.fill(220, 600);
  const expected: SpatialScore = {split: 1, gap: 0.784, near: 0.4};
  assert.deepEqual(spatialScore(pixels), expected);
});

test("a flat image has no split", () => {
  assert.deepEqual(spatialScore(new Uint8Array(1000).fill(128)), {split: 0, gap: 0, near: 0});
});

test("an empty image has no split", () => {
  assert.deepEqual(spatialScore(new Uint8Array(0)), {split: 0, gap: 0, near: 0});
});

test("a repeated linear ramp gives a split near 0.75", () => {
  const pixels = new Uint8Array(256 * 4);
  for (let i = 0; i < pixels.length; i++) pixels[i] = i % 256;
  const {split} = spatialScore(pixels);
  assert.ok(split > 0.74 && split < 0.76, `split was ${split}`);
});

test("a strong split with a near part of the right size is great", () => {
  assert.equal(spatialTierFor({split: 0.9, gap: 0.6, near: 0.3}), "great");
});

test("a split just under the great bar is ok", () => {
  assert.equal(spatialTierFor({split: 0.8, gap: 0.5, near: 0.3}), "ok");
});

test("a near part above the allowed share is none", () => {
  assert.equal(spatialTierFor({split: 0.9, gap: 0.6, near: 0.9}), "none");
});

test("a split below the ok bar is none", () => {
  assert.equal(spatialTierFor({split: 0.7, gap: 0.6, near: 0.3}), "none");
});

test("a wall image gets its tier and a 512 px grey map stored under its wall id", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const stored: Array<{object: string; png: Buffer}> = [];
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch(calls, await twoLevelPng()),
    store: async (object, png) => {
      stored.push({object, png});
      return `https://img.example/${object}`;
    },
  }));
  assert.deepEqual(result, {tier: "great", map: "https://img.example/spatial-test/v1/w1.png", v: 1});
  assert.equal(stored.length, 1);
  assert.equal(stored[0].object, "spatial-test/v1/w1.png");
  const meta = await sharp(stored[0].png).metadata();
  assert.equal(meta.channels, 1);
  assert.equal(meta.depth, "uchar");
  assert.equal(Math.max(meta.width ?? 0, meta.height ?? 0), 512);
  assert.equal(calls.length, 2);
  assert.equal(calls[0].url, "https://fal.run/fal-ai/image-preprocessors/depth-anything/v2");
  assert.deepEqual(JSON.parse(calls[0].init.body as string), {image_url: WALL_URL});
  assert.deepEqual((calls[0].init.headers as Record<string, string>).Authorization, "Key k");
});

test("a non-allowed wall host is rejected before any fetch", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const fetch = falFetch(calls, await twoLevelPng());
  assert.equal(await wallSpatialFor("w1", {url: "https://evil.example.com/a.jpg"}, deps({fetch})), undefined);
  assert.equal(await wallSpatialFor("w1", {url: "http://raw.githubusercontent.com/a.jpg"}, deps({fetch})), undefined);
  assert.equal(calls.length, 0);
});

test("a fal map host that is not fal.media is rejected and never stored", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  let stores = 0;
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch(calls, await twoLevelPng(), "https://evil.example.com/x.png"),
    store: async () => {
      stores++;
      return "";
    },
  }));
  assert.equal(result, undefined);
  assert.equal(stores, 0);
});

test("a fal error status gives undefined and stores nothing", async () => {
  let stores = 0;
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: async () => new Response("nope", {status: 500}),
    store: async () => {
      stores++;
      return "";
    },
  }));
  assert.equal(result, undefined);
  assert.equal(stores, 0);
});

test("an empty fal key gives undefined without any fetch", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch(calls, await twoLevelPng()),
    key: () => "",
  }));
  assert.equal(result, undefined);
  assert.equal(calls.length, 0);
});

test("a store that throws gives undefined", async () => {
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch([], await twoLevelPng()),
    store: async () => {
      throw new Error("r2 down");
    },
  }));
  assert.equal(result, undefined);
});

test("a wall id with a slash gives undefined without any fetch", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const result = await wallSpatialFor("a/b", {url: WALL_URL}, deps({fetch: falFetch(calls, await twoLevelPng())}));
  assert.equal(result, undefined);
  assert.equal(calls.length, 0);
});

test("a JPEG input is sent to fal as a data URI", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const jpeg = await sharp(twoLevelRaw(), {raw: {width: 64, height: 128, channels: 1}}).jpeg().toBuffer();
  const result = await wallSpatialFor("w1", {jpeg}, deps({fetch: falFetch(calls, await twoLevelPng())}));
  assert.notEqual(result, undefined);
  const body = JSON.parse(calls[0].init.body as string) as {image_url: string};
  assert.equal(body.image_url, `data:image/jpeg;base64,${jpeg.toString("base64")}`);
});
