import assert from "node:assert/strict";
import test from "node:test";
import {backfillWallSpatial, needsSpatial, parseSpatialBackfillArgs, spatialBackfillDeps} from "../scripts/backfillWallSpatial";

const WALL_URL = "https://raw.githubusercontent.com/hash-studios/Prism/main/test-wall.png";
const MAP_URL = "https://cdn.fal.media/files/depth.png";

test("dry run is the default and --apply writes", () => {
  assert.equal(parseSpatialBackfillArgs([]).apply, false);
  assert.equal(parseSpatialBackfillArgs(["--apply"]).apply, true);
});

test("--map-prefix sets the R2 folder for a dry run and cannot be combined with --apply", () => {
  assert.equal(parseSpatialBackfillArgs(["--map-prefix=spatial-test/v1"]).mapPrefix, "spatial-test/v1");
  assert.equal(parseSpatialBackfillArgs([]).mapPrefix, undefined);
  assert.throws(() => parseSpatialBackfillArgs(["--apply", "--map-prefix=x"]), /--map-prefix is for dry runs only/);
});

test("batch size and limit fall back to safe defaults", () => {
  assert.equal(parseSpatialBackfillArgs([]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--batch=500"]).batchSize, 500);
  assert.equal(parseSpatialBackfillArgs(["--batch=501"]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--batch=0"]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--batch=abc"]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--limit=0"]).limit, undefined);
  assert.equal(parseSpatialBackfillArgs(["--limit=50"]).limit, 50);
});

test("needsSpatial skips only walls already at the current version unless forced", () => {
  assert.equal(needsSpatial(undefined, false), true);
  assert.equal(needsSpatial({v: 0}, false), true);
  assert.equal(needsSpatial({v: 1}, false), false);
  assert.equal(needsSpatial({v: 1}, true), true);
});

test("a library dry run without injected dependencies never stores maps in R2", async () => {
  const options = parseSpatialBackfillArgs([]);
  assert.equal(await spatialBackfillDeps(options).store("spatial/v1/w1.png", Buffer.from("png")),
    "dry-run:spatial/v1/w1.png");
});

test("the library rejects apply and map-prefix together", () => {
  const options = {...parseSpatialBackfillArgs([]), apply: true, mapPrefix: "spatial-test/v1"};
  assert.throws(() => spatialBackfillDeps(options), /--map-prefix is for dry runs only/);
});

test("the backfill refuses apply plus map-prefix before accessing Firestore", async () => {
  const db = new Proxy({}, {
    get() {
      throw new Error("Firestore must not be accessed");
    },
  });
  const options = {...parseSpatialBackfillArgs([]), apply: true, mapPrefix: "spatial-test/v1"};
  await assert.rejects(backfillWallSpatial(db as never, options), /--map-prefix is for dry runs only/);
});

test("the backfill library dry run checks a wall without Firestore or R2 writes", async () => {
  const sharp = (await import("sharp")).default;
  const wall = await sharp({create: {width: 64, height: 128, channels: 3, background: "red"}}).png().toBuffer();
  const depthPixels = Buffer.alloc(64 * 128);
  depthPixels.fill(255, 0, depthPixels.length / 2);
  const depth = await sharp(depthPixels, {raw: {width: 64, height: 128, channels: 1}}).png().toBuffer();
  const calls: Array<{url: string; init: RequestInit}> = [];
  const originalFetch = globalThis.fetch;
  const originalKey = process.env.FAL_API_KEY;
  let firestoreWrites = 0;
  globalThis.fetch = async (input, init = {}) => {
    const url = String(input);
    calls.push({url, init});
    if (url === WALL_URL) return new Response(new Uint8Array(wall), {headers: {"content-type": "image/png"}});
    if (url === "https://fal.run/fal-ai/image-preprocessors/depth-anything/v2") {
      return Response.json({image: {url: MAP_URL}});
    }
    if (url === MAP_URL) return new Response(new Uint8Array(depth));
    throw new Error(`unexpected fetch: ${url}`);
  };
  process.env.FAL_API_KEY = "test-key";

  const doc = {
    id: "wall-1",
    ref: {},
    updateTime: {},
    get: (field: string) => field === "wallpaper_url" ? WALL_URL : undefined,
  };
  const query = {
    where() {
      return this;
    },
    orderBy() {
      return this;
    },
    limit() {
      return this;
    },
    startAfter() {
      return this;
    },
    async get() {
      return {empty: false, size: 1, docs: [doc]};
    },
  };
  const db = {
    collection() {
      return query;
    },
    bulkWriter() {
      return {
        update() {
          firestoreWrites++;
          return Promise.resolve();
        },
        flush() {
          return Promise.resolve();
        },
        close() {
          return Promise.resolve();
        },
      };
    },
  };

  try {
    const logs: string[] = [];
    const counts = await backfillWallSpatial(db as never, parseSpatialBackfillArgs([]), undefined,
      (line) => logs.push(line));
    assert.deepEqual(counts, {scanned: 1, skipped: 0, checked: 1, failed: 0, written: 0, tiers: {great: 1}});
    assert.equal(firestoreWrites, 0);
    assert.deepEqual(calls.map(({url}) => url), [WALL_URL,
      "https://fal.run/fal-ai/image-preprocessors/depth-anything/v2", MAP_URL]);
    assert.equal(calls[0].init.redirect, "manual");
    assert.equal(calls[1].init.redirect, undefined);
    assert.match(JSON.parse(calls[1].init.body as string).image_url, /^data:image\/jpeg;base64,/);
    assert.equal(calls[2].init.redirect, "error");
    assert.match(logs[0], /^wall-1 great dry-run:spatial\/v1\/wall-1-[a-f0-9]{64}\.png$/);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalKey === undefined) delete process.env.FAL_API_KEY;
    else process.env.FAL_API_KEY = originalKey;
  }
});
