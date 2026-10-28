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

function falFetch(calls: Array<{url: string; init: RequestInit}>, map: Buffer, mapUrl = MAP_URL, source = map) {
  return async (url: string, init: RequestInit): Promise<Response> => {
    calls.push({url, init});
    if (url.startsWith("https://fal.run/")) return Response.json({image: {url: mapUrl}});
    if (url === WALL_URL) return new Response(new Uint8Array(source), {headers: {"content-type": "image/png"}});
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

test("a wall image gets its tier and a 512 px grey map stored under a content-addressed key", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const stored: Array<{object: string; png: Buffer}> = [];
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch(calls, await twoLevelPng(), MAP_URL, await twoLevelPng()),
    store: async (object, png) => {
      stored.push({object, png});
      return `https://img.example/${object}`;
    },
  }));
  assert.equal(result?.tier, "great");
  assert.equal(result?.v, 1);
  assert.equal(stored.length, 1);
  assert.match(stored[0].object, /^spatial-test\/v1\/w1-[a-f0-9]{64}\.png$/);
  assert.equal(result?.map, `https://img.example/${stored[0].object}`);
  const meta = await sharp(stored[0].png).metadata();
  assert.equal(meta.channels, 1);
  assert.equal(meta.depth, "uchar");
  assert.equal(Math.max(meta.width ?? 0, meta.height ?? 0), 512);
  assert.equal(calls.length, 3);
  assert.equal(calls[0].url, WALL_URL);
  assert.equal((calls[0].init as RequestInit).redirect, "manual");
  assert.equal(calls[1].url, "https://fal.run/fal-ai/image-preprocessors/depth-anything/v2");
  const request = JSON.parse(calls[1].init.body as string) as {image_url: string};
  assert.match(request.image_url, /^data:image\/jpeg;base64,/);
  assert.deepEqual((calls[1].init.headers as Record<string, string>).Authorization, "Key k");
  assert.equal(calls[2].init.redirect, "error");
});

test("a changed map gets a new object key so force and retry cannot reuse stale bytes", async () => {
  const first = await twoLevelPng();
  const second = await sharp(Buffer.alloc(64 * 128, 128), {raw: {width: 64, height: 128, channels: 1}}).png().toBuffer();
  const objects: string[] = [];
  const store = async (object: string) => {
    objects.push(object);
    return `https://img.example/${object}`;
  };
  const firstResult = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch([], first, MAP_URL, first), store,
  }));
  const secondResult = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: falFetch([], second, MAP_URL, first), store,
  }));
  assert.notEqual(firstResult?.map, secondResult?.map);
  assert.equal(new Set(objects).size, 2);
});

test("a source JPEG is auto-oriented before fal receives its data URI", async () => {
  const sharp = (await import("sharp")).default;
  const source = await sharp({create: {width: 64, height: 128, channels: 3, background: "red"}})
    .jpeg().withMetadata({orientation: 6}).toBuffer();
  const sourceMetadata = await sharp(source).metadata();
  assert.equal(sourceMetadata.orientation, 6);
  const calls: Array<{url: string; init: RequestInit}> = [];
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: async (url, init) => {
      calls.push({url, init});
      if (url === WALL_URL) return new Response(new Uint8Array(source), {headers: {"content-type": "image/jpeg"}});
      if (url.startsWith("https://fal.run/")) return Response.json({image: {url: MAP_URL}});
      return new Response(new Uint8Array(await twoLevelPng()));
    },
  }));
  assert.ok(result);
  const request = JSON.parse(calls[1].init.body as string) as {image_url: string};
  const normalized = Buffer.from(request.image_url.slice("data:image/jpeg;base64,".length), "base64");
  const normalizedMetadata = await sharp(normalized).metadata();
  assert.equal(normalizedMetadata.width, 128);
  assert.equal(normalizedMetadata.height, 64);
  assert.equal(normalizedMetadata.orientation, undefined);
});

test("a non-allowed wall host is rejected before any fetch", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  const fetch = falFetch(calls, await twoLevelPng());
  assert.equal(await wallSpatialFor("w1", {url: "https://evil.example.com/a.jpg"}, deps({fetch})), undefined);
  assert.equal(await wallSpatialFor("w1", {url: "http://raw.githubusercontent.com/a.jpg"}, deps({fetch})), undefined);
  assert.equal(calls.length, 0);
});

test("an allowed wall URL redirecting to a non-allowed host is rejected before fal", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  let stores = 0;
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: async (url, init) => {
      calls.push({url, init});
      return new Response(null, {status: 302, headers: {location: "https://evil.example/secret"}});
    },
    store: async () => {
      stores++;
      return "";
    },
  }));
  assert.equal(result, undefined);
  assert.deepEqual(calls.map((call) => call.url), [WALL_URL]);
  assert.equal(stores, 0);
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

test("a fal map redirect is not followed and the map is never stored", async () => {
  const calls: Array<{url: string; init: RequestInit}> = [];
  let stores = 0;
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: async (url, init) => {
      calls.push({url, init});
      if (url === WALL_URL) return new Response(new Uint8Array(await twoLevelPng()));
      if (url.startsWith("https://fal.run/")) return Response.json({image: {url: MAP_URL}});
      return new Response(null, {status: 302, headers: {location: "https://evil.example/map.png"}});
    },
    store: async () => {
      stores++;
      return "";
    },
  }));
  assert.equal(result, undefined);
  assert.deepEqual(calls.map((call) => call.url), [WALL_URL,
    "https://fal.run/fal-ai/image-preprocessors/depth-anything/v2", MAP_URL]);
  assert.equal(calls[2].init.redirect, "error");
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

test("a large source is shrunk to 1536 px on the long side before fal receives it", async () => {
  const sharp = (await import("sharp")).default;
  const source = await sharp({create: {width: 2000, height: 4000, channels: 3, background: "red"}}).jpeg().toBuffer();
  const calls: Array<{url: string; init: RequestInit}> = [];
  const result = await wallSpatialFor("w1", {url: WALL_URL}, deps({
    fetch: async (url, init) => {
      calls.push({url, init});
      if (url === WALL_URL) return new Response(new Uint8Array(source), {headers: {"content-type": "image/jpeg"}});
      if (url.startsWith("https://fal.run/")) return Response.json({image: {url: MAP_URL}});
      return new Response(new Uint8Array(await twoLevelPng()));
    },
  }));
  assert.ok(result);
  const request = JSON.parse(calls[1].init.body as string) as {image_url: string};
  const sent = await sharp(Buffer.from(request.image_url.slice("data:image/jpeg;base64,".length), "base64")).metadata();
  assert.deepEqual([sent.width, sent.height], [768, 1536]);
});
