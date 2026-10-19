import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {db} from "../common";
import {onWallCategorize} from "../onWallCategorize";
import {backfillWallDepth, needsDepth, parseDepthBackfillArgs} from "../scripts/backfillWallDepth";
import * as wallDepth from "../wallDepth";
import {
  DEPTH_T_AUTO,
  DEPTH_T_MENU,
  type DepthKind,
  depthFromMaskPixels,
  depthKindFrom,
  type DepthVision,
  maskPixels,
  scoreDepth,
  type WallDepth,
  type WallDepthDeps,
  wallDepthFor,
} from "../wallDepth";

const W = 393;
const H = 852;

function screenMask(subject: (x: number, y: number) => boolean | number): Uint8Array {
  const pixels = new Uint8Array(W * H);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const value = subject(x, y);
      pixels[y * W + x] = typeof value === "number" ? value : value ? 255 : 0;
    }
  }
  return pixels;
}

function png(width: number, height: number, subject: (x: number, y: number) => boolean): Promise<Buffer> {
  const raw = Buffer.alloc(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) raw[y * width + x] = subject(x, y) ? 255 : 0;
  }
  return sharp(raw, {raw: {width, height, channels: 1}}).png().toBuffer();
}

const detector = (tier: WallDepth["tier"], kind: DepthKind | null, top: number | null): WallDepth =>
  ({tier, kind, top, v: 1, by: "detector"});

test("the thresholds come from the iPhone 15 Pro clock box", () => {
  assert.equal(Math.round(DEPTH_T_AUTO * 10000) / 10000, 0.0414);
  assert.equal(Math.round(DEPTH_T_MENU * 10000) / 10000, 0.2811);
});

test("a subject entirely below the clock box does not touch it", () => {
  assert.deepEqual(depthFromMaskPixels(screenMask((_, y) => y >= 300), "person"), detector("none", "person", 0));
});

test("a subject whose top edge sits only in the bottom quarter of the clock box gives auto", () => {
  assert.deepEqual(depthFromMaskPixels(screenMask((_, y) => y >= 250), "person"), detector("auto", "person", 0));
});

test("a subject over about 15% of the top region gives menu", () => {
  const head = screenMask((x, y) => (y >= 190 && x >= 172 && x < 223) || y >= 242);
  assert.deepEqual(depthFromMaskPixels(head, "person"), detector("menu", "person", 0.151));
});

test("a subject over half of the top region gives none", () => {
  const wide = screenMask((x, y) => (y >= 190 && x < 196) || y >= 242);
  assert.deepEqual(depthFromMaskPixels(wide, "pet"), detector("none", "pet", 0.5));
});

test("a blob under 2% of the screen is no subject, even when it touches the clock", () => {
  const blob = screenMask((x, y) => y >= 245 && y < 260 && x >= 100 && x < 300);
  assert.deepEqual(depthFromMaskPixels(blob, "person"), detector("none", "person", 0));
});

test("a faint mask under 0.002 over the clock box is no touch", () => {
  const faint = screenMask((_, y) => y >= 260 ? 255 : y >= 242 ? 1 : 0);
  assert.deepEqual(depthFromMaskPixels(faint, "sky"), detector("none", "sky", 0));
});

test("no subject kind gives none but keeps the measured top", () => {
  assert.deepEqual(depthFromMaskPixels(screenMask((_, y) => y >= 250), null), detector("none", null, 0));
  const half = screenMask((x, y) => (y >= 190 && x < 196) || y >= 242);
  assert.deepEqual(depthFromMaskPixels(half, null), detector("none", null, 0.5));
});

test("a mask of the wrong size is refused", () => {
  assert.throws(() => depthFromMaskPixels(new Uint8Array(10), "person"), /393x852/);
});

test("a mask wider than the screen shape is cropped at the sides", async () => {
  const pixels = await maskPixels(await png(3 * W, H, (x, y) => x < W || (x >= W && x < 2 * W && y >= 600)));
  assert.equal(pixels.length, W * H);
  assert.equal(pixels[100 * W], 0);
  assert.equal(pixels[599 * W + 200], 0);
  assert.equal(pixels[600 * W], 255);
  assert.equal(pixels[700 * W + W - 1], 255);
  assert.equal(pixels.filter((v) => v === 255).length, W * (H - 600));
});

test("a mask taller than the screen shape is cropped at the top and bottom", async () => {
  const pixels = await maskPixels(await png(W, 2 * H, (_, y) => y < 426 || (y >= 1000 && y <= 1100)));
  assert.equal(pixels[0], 0);
  assert.equal(pixels[573 * W], 0);
  assert.equal(pixels[574 * W], 255);
  assert.equal(pixels[674 * W + 200], 255);
  assert.equal(pixels[675 * W], 0);
  assert.equal(pixels.filter((v) => v === 255).length, W * 101);
});

test("scoreDepth reads a full size mask image", async () => {
  const mask = await png(1440, 3200, (_, y) => y >= 960);
  assert.deepEqual(await scoreDepth(mask, "pet"), detector("auto", "pet", 0));
  const rgba = await sharp(mask).ensureAlpha().webp({lossless: true}).toBuffer();
  assert.deepEqual(await scoreDepth(rgba, "pet"), detector("auto", "pet", 0));
  await assert.rejects(scoreDepth(Buffer.from("not an image"), "pet"));
});

const objects = (...items: Array<[string, number]>): DepthVision =>
  ({localizedObjectAnnotations: items.map(([name, score]) => ({name, score}))});
const labels = (...items: Array<[string, number]>): DepthVision =>
  ({labelAnnotations: items.map(([description, score]) => ({description, score}))});

test("depthKindFrom finds each kind", () => {
  for (const name of ["Person", "Man", "Woman", "Boy", "Girl", "Baby", "Toddler"]) {
    assert.equal(depthKindFrom(objects([name, 0.5])), "person", name);
  }
  assert.equal(depthKindFrom(objects(["Dog", 0.6])), "pet");
  assert.equal(depthKindFrom(objects(["Cat", 0.5])), "pet");
  assert.equal(depthKindFrom(labels(["Cat", 0.7])), "pet");
  assert.equal(depthKindFrom(labels(["Dog", 0.9])), "pet");
  for (const name of ["Sky", "Cloud", "Horizon", "Skyline"]) {
    assert.equal(depthKindFrom(labels([name, 0.7])), "sky", name);
  }
});

test("depthKindFrom follows the iOS order person, pet, sky", () => {
  const all: DepthVision = {...objects(["Dog", 0.9], ["Person", 0.6]), ...labels(["Sky", 0.99])};
  assert.equal(depthKindFrom(all), "person");
  assert.equal(depthKindFrom({...objects(["Cat", 0.8]), ...labels(["Sky", 0.99])}), "pet");
});

test("depthKindFrom ignores scores under the thresholds, other names and empty input", () => {
  assert.equal(depthKindFrom(objects(["Person", 0.49], ["Dog", 0.49])), null);
  assert.equal(depthKindFrom(labels(["Dog", 0.69], ["Sky", 0.69])), null);
  assert.equal(depthKindFrom(labels(["Person", 0.99])), null, "person counts as an object only");
  assert.equal(depthKindFrom(objects(["Sky", 0.99])), null, "sky counts as a label only");
  assert.equal(depthKindFrom(objects(["Car", 0.99], ["Horse", 0.99])), null);
  assert.equal(depthKindFrom({}), null);
  assert.equal(depthKindFrom({labelAnnotations: null, localizedObjectAnnotations: [{name: null, score: null}]}), null);
});

const WALL_URL = "https://raw.githubusercontent.com/o/r/main/a.jpg";

interface FalCall {
  url: string;
  init: RequestInit;
}

async function fakeDeps(opts: {
  vision?: DepthVision | (() => never);
  reply?: () => Response | Promise<Response>;
  key?: string;
} = {}) {
  const maskPng = await png(W, H, (_, y) => y >= 250);
  const annotated: wallDepth.DepthImage[] = [];
  const falCalls: FalCall[] = [];
  const deps: WallDepthDeps = {
    annotate: async (image) => {
      annotated.push(image);
      const vision = opts.vision ?? objects(["Person", 0.9]);
      return typeof vision === "function" ? vision() : vision;
    },
    fetch: async (url, init) => {
      falCalls.push({url, init});
      return opts.reply?.() ?? Response.json({mask_image: {url: `data:image/png;base64,${maskPng.toString("base64")}`}});
    },
    key: () => opts.key ?? "fal-key",
  };
  return {deps, annotated, falCalls};
}

test("wallDepthFor sends the wall URL to Vision and fal and scores the mask", async () => {
  const {deps, annotated, falCalls} = await fakeDeps();
  assert.deepEqual(await wallDepthFor("w1", {url: WALL_URL}, deps), detector("auto", "person", 0));
  assert.deepEqual(annotated, [{url: WALL_URL}]);
  assert.equal(falCalls.length, 1);
  const [{url, init}] = falCalls;
  assert.equal(url, "https://fal.run/fal-ai/birefnet");
  assert.equal(init.method, "POST");
  assert.deepEqual(init.headers, {"Authorization": "Key fal-key", "content-type": "application/json"});
  assert.deepEqual(JSON.parse(String(init.body)), {
    image_url: WALL_URL, model: "General Use (Light)", operating_resolution: "1024x1024", output_mask: true,
    refine_foreground: false, sync_mode: true, output_format: "png",
  });
  assert.ok(init.signal instanceof AbortSignal);
});

test("wallDepthFor sends JPEG bytes to fal as a data URI", async () => {
  const {deps, annotated, falCalls} = await fakeDeps({vision: labels(["Sky", 0.95])});
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 1, 2, 3]);
  assert.deepEqual(await wallDepthFor("c1", {jpeg}, deps), detector("auto", "sky", 0));
  assert.deepEqual(annotated, [{jpeg}]);
  assert.equal(JSON.parse(String(falCalls[0].init.body)).image_url, `data:image/jpeg;base64,${jpeg.toString("base64")}`);
});

test("wallDepthFor gives none without a mask call when Vision finds no subject", async () => {
  const {deps, falCalls} = await fakeDeps({vision: labels(["Pattern", 0.99], ["Sky", 0.5])});
  assert.deepEqual(await wallDepthFor("w1", {url: WALL_URL}, deps), detector("none", null, null));
  assert.equal(falCalls.length, 0);
});

test("wallDepthFor gives undefined on any failure and never throws", async () => {
  const visionDown = await fakeDeps({vision: () => {
    throw new Error("vision down");
  }});
  assert.equal(await wallDepthFor("w1", {url: WALL_URL}, visionDown.deps), undefined);
  assert.equal(visionDown.falCalls.length, 0);

  const falDown = await fakeDeps({reply: () => Response.json({detail: "boom"}, {status: 500})});
  assert.equal(await wallDepthFor("w1", {url: WALL_URL}, falDown.deps), undefined);

  const offline = await fakeDeps({reply: () => {
    throw new TypeError("fetch failed");
  }});
  assert.equal(await wallDepthFor("w1", {url: WALL_URL}, offline.deps), undefined);

  for (const url of ["https://v3.fal.media/files/mask.png", "data:image/png;base64,", "data:image/png,abc", 42]) {
    const notData = await fakeDeps({reply: () => Response.json({mask_image: {url}})});
    assert.equal(await wallDepthFor("w1", {url: WALL_URL}, notData.deps), undefined, String(url));
  }
  const noMask = await fakeDeps({reply: () => Response.json({image: {url: "data:image/png;base64,AAAA"}})});
  assert.equal(await wallDepthFor("w1", {url: WALL_URL}, noMask.deps), undefined);

  const badPng = await fakeDeps({reply: () => Response.json({mask_image: {url: "data:image/png;base64,AAAA"}})});
  assert.equal(await wallDepthFor("w1", {url: WALL_URL}, badPng.deps), undefined);

  const noKey = await fakeDeps({key: " "});
  assert.equal(await wallDepthFor("w1", {url: WALL_URL}, noKey.deps), undefined);
  assert.equal(noKey.falCalls.length, 0);
});

test("wallDepthFor refuses a wall URL outside the image host allowlist before any call", async () => {
  for (const url of ["https://evil.example/a.jpg", "http://raw.githubusercontent.com/o/r/main/a.jpg", "nope"]) {
    const {deps, annotated, falCalls} = await fakeDeps();
    assert.equal(await wallDepthFor("w1", {url}, deps), undefined, url);
    assert.equal(annotated.length + falCalls.length, 0, url);
  }
});

function fakeWalls(t: test.TestContext, updates: Array<Record<string, unknown>>) {
  t.mock.method(db, "collection", () => ({
    doc: () => ({
      update: async (data: Record<string, unknown>) => {
        updates.push(data);
      },
    }),
  }));
  t.mock.method(globalThis, "fetch", async () => {
    throw new Error("offline");
  });
}

const created = (data: Record<string, unknown>) => ({
  params: {wallId: "w1"},
  data: {data: () => data},
}) as unknown as Parameters<typeof onWallCategorize.run>[0];

const MENU: WallDepth = detector("menu", "person", 0.15);

test("onWallCategorize uses the thumbnail only when there is no full image", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWalls(t, updates);
  const depthMock = t.mock.method(wallDepth, "wallDepthFor", async () => undefined);
  await onWallCategorize.run(created({wallpaper_thumb: WALL_URL, category: "Space", colors: ["blue"]}));
  assert.deepEqual(depthMock.mock.calls[0].arguments, ["w1", {url: WALL_URL}]);
  assert.deepEqual(updates, [], "a failed check writes no depth");
});

test("onWallCategorize leaves an existing depth alone", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWalls(t, updates);
  const depthMock = t.mock.method(wallDepth, "wallDepthFor", async () => MENU);
  const adminDepth = {tier: "auto", kind: null, top: null, v: 1, by: "admin"};
  await onWallCategorize.run(created({wallpaper_url: WALL_URL, category: "Space", colors: ["blue"], depth: adminDepth}));
  assert.equal(depthMock.mock.callCount(), 0);
  assert.deepEqual(updates, []);
});

test("needsDepth skips admin values even with force, and current detector values without it", () => {
  const adminDepth = {tier: "auto", kind: null, top: null, v: 1, by: "admin"};
  assert.equal(needsDepth(adminDepth, false), false);
  assert.equal(needsDepth(adminDepth, true), false);
  assert.equal(needsDepth({...adminDepth, v: 0}, true), false);
  assert.equal(needsDepth(detector("menu", "pet", 0.1), false), false);
  assert.equal(needsDepth(detector("menu", "pet", 0.1), true), true);
  assert.equal(needsDepth({...detector("menu", "pet", 0.1), v: 0}, false), true);
  assert.equal(needsDepth(undefined, false), true);
  assert.equal(needsDepth(null, false), true);
  assert.equal(needsDepth("auto", false), true);
});

test("depth backfill arguments fall back to safe values", () => {
  assert.deepEqual(parseDepthBackfillArgs([]), {apply: false, force: false, batchSize: 100, startAfter: undefined,
    limit: undefined});
  assert.deepEqual(parseDepthBackfillArgs(["--apply", "--force", "--limit=50", "--batch=20", "--start-after=W1"]), {
    apply: true, force: true, batchSize: 20, startAfter: "W1", limit: 50,
  });
  assert.equal(parseDepthBackfillArgs(["--limit=0"]).limit, undefined);
  assert.equal(parseDepthBackfillArgs(["--limit=x"]).limit, undefined);
  assert.equal(parseDepthBackfillArgs(["--batch=9999"]).batchSize, 100);
});

type FakeWall = {id: string; data: Record<string, unknown>};

function fakeBackfillDb(walls: FakeWall[], updates: Array<[string, Record<string, unknown>]>) {
  const docOf = (wall: FakeWall) => ({
    id: wall.id,
    ref: {id: wall.id},
    get: (field: string) => wall.data[field],
    data: () => wall.data,
  });
  const collection = () => {
    let after: string | undefined;
    let max = 0;
    const query = {
      where: () => query,
      orderBy: () => query,
      limit: (n: number) => {
        max = n;
        return query;
      },
      startAfter: (id: string) => {
        after = id;
        return query;
      },
      get: async () => {
        const docs = walls.filter((w) => after === undefined || w.id > after).slice(0, max).map(docOf);
        return {docs, empty: docs.length === 0, size: docs.length};
      },
    };
    return query;
  };
  return {
    collection,
    bulkWriter: () => ({
      update: async (ref: {id: string}, data: Record<string, unknown>) => {
        updates.push([ref.id, data]);
      },
      flush: async () => undefined,
      close: async () => undefined,
    }),
  } as unknown as admin.firestore.Firestore;
}

const url = (id: string) => `https://raw.githubusercontent.com/o/r/main/${id}.jpg`;

test("the depth backfill is a dry run by default, logs each wall and counts tiers and kinds", async () => {
  const {deps} = await fakeDeps({vision: objects(["Cat", 0.9])});
  const walls: FakeWall[] = [
    {id: "a", data: {wallpaper_url: url("a")}},
    {id: "b", data: {wallpaper_url: url("b"), depth: detector("menu", "pet", 0.1)}},
    {id: "c", data: {wallpaper_thumb: url("c")}},
    {id: "d", data: {}},
  ];
  const updates: Array<[string, Record<string, unknown>]> = [];
  const logs: string[] = [];
  const counts = await backfillWallDepth(fakeBackfillDb(walls, updates), parseDepthBackfillArgs([]), deps,
    (line) => logs.push(line));
  assert.deepEqual(counts, {scanned: 4, skipped: 1, checked: 2, failed: 1, written: 0, tiers: {auto: 2},
    kinds: {pet: 2}});
  assert.deepEqual(updates, []);
  assert.deepEqual(logs.filter((l) => /^[a-d] /.test(l)).sort(), ["a auto pet 0", "c auto pet 0", "d failed"]);
  assert.match(logs[logs.length - 1], /^done tiers=\{"auto":2\} kinds=\{"pet":2\} .*applied=false$/);
});

test("the depth backfill with --apply --force rewrites detector values but never an admin value", async () => {
  const {deps} = await fakeDeps({vision: labels(["Pattern", 0.9])});
  const walls: FakeWall[] = [
    {id: "a", data: {wallpaper_url: url("a"), depth: detector("auto", "person", 0)}},
    {id: "b", data: {wallpaper_url: url("b"), depth: {tier: "auto", kind: null, top: null, v: 1, by: "admin"}}},
    {id: "c", data: {wallpaper_url: url("c")}},
  ];
  const updates: Array<[string, Record<string, unknown>]> = [];
  const counts = await backfillWallDepth(fakeBackfillDb(walls, updates),
    parseDepthBackfillArgs(["--apply", "--force", "--batch=2"]), deps, () => undefined);
  assert.equal(counts.skipped, 1);
  assert.equal(counts.written, 2);
  assert.deepEqual(updates.sort(), [["a", {depth: detector("none", null, null)}], ["c", {depth: detector("none", null, null)}]]);
});

test("the depth backfill stops after --limit walls and logs where to resume", async () => {
  const {deps, annotated} = await fakeDeps({vision: labels(["Pattern", 0.9])});
  const walls: FakeWall[] = ["a", "b", "c", "d", "e"].map((id) => ({id, data: {wallpaper_url: url(id)}}));
  walls[1].data.depth = detector("none", null, null);
  const updates: Array<[string, Record<string, unknown>]> = [];
  const logs: string[] = [];
  const counts = await backfillWallDepth(fakeBackfillDb(walls, updates),
    parseDepthBackfillArgs(["--apply", "--limit=2", "--batch=2"]), deps, (line) => logs.push(line));
  assert.equal(counts.checked, 2);
  assert.equal(annotated.length, 2);
  assert.deepEqual(updates.map(([id]) => id).sort(), ["a", "c"]);
  assert.ok(logs.some((l) => l.startsWith("batch done last=c ")));
});
