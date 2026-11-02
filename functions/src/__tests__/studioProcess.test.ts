import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {db} from "../common";
import {onWallApproved} from "../onWallApproved";
import {onWallSubmitted} from "../onWallSubmitted";
import {imageSignature, type VisionResult} from "../studio/gates";
import {randomWallId} from "../studio/ids";
import {humanSize, isStudioWall, processCandidate, type StudioProcessDeps, thumbSize} from "../studio/process";
import type {WallDepth} from "../wallDepth";
import {type Doc, installFakeDb} from "./fakeDb";
import {flatPng, gradientPng, seededRng} from "./studioTestUtil";

const BASE = "https://worker.test";
const RUN = "d20261012";
const CAND = "d20261012-0";
const CAND_PATH = `studioRuns/${RUN}/candidates/${CAND}`;
const RAW_KEY = `ai/studio/raw/${CAND}.png`;
const IMAGE_URL = `https://prismwalls.com/api/ai/assets/${RAW_KEY}`;
const IDENTITY = {by: "Prism Studio", email: "studio@prismwalls.com", userPhoto: "https://p/studio.png"};
const CLEAN: VisionResult = {safeSearchAnnotation: {adult: 1, racy: 1, violence: 1, medical: 1}};

let wallpaper: Buffer;
test.before(async () => {
  wallpaper = await flatPng(1440, 3200);
});

interface Call {
  method: string;
  url: string;
  headers: Record<string, string>;
  body: unknown;
}

const candidate = (extra: Doc = {}): Doc => ({
  status: "queued", attempts: 0, runId: RUN, index: 0, seriesId: "after-dark", subjectId: "eclipse",
  paletteId: "ember", prompt: "an eclipse, ember light", title: "Eclipse · Ember", category: "Space",
  tags: ["amoled", "dark", "eclipse"], seed: 42, model: "fal-ai/model", width: 1440, height: 3200, ...extra,
});

function setup(t: TestContext, opts: {
  seed?: Record<string, Doc>;
  generate?: () => Response | Promise<Response>;
  image?: () => Promise<Buffer>;
  vision?: VisionResult | (() => VisionResult);
  rng?: () => number;
  nowMs?: () => number;
  deleteAsset?: () => Response;
  putAsset?: (key: string) => Response;
  beforePut?: (store: Map<string, Doc>, key: string) => void;
  depth?: WallDepth;
} = {}) {
  const store = installFakeDb(t, {
    "studioConfig/current": {generationEnabled: true, identity: IDENTITY},
    [CAND_PATH]: candidate(),
    ...opts.seed,
  });
  const calls: Call[] = [];
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit = {}) => {
    const url = String(rawUrl);
    const method = init.method ?? "GET";
    const headers = (init.headers ?? {}) as Record<string, string>;
    const body = typeof init.body === "string" ? JSON.parse(init.body) : init.body;
    calls.push({method, url, headers, body});
    if (method === "POST" && url === `${BASE}/api/ai/studio/generations`) {
      return await opts.generate?.() ?? Response.json({
        id: CAND, imageUrl: IMAGE_URL, key: RAW_KEY, width: 1440, height: 3200, contentType: "image/png",
        bytes: wallpaper.length, model: "fal-ai/model-v2", provider: "fal", seed: 42, costUsd: 0.04,
      });
    }
    if (method === "GET" && url === IMAGE_URL) return new Response(new Uint8Array(await (opts.image?.() ?? wallpaper)));
    const asset = url.replace(`${BASE}/api/ai/studio/assets/`, "");
    if (method === "PUT") {
      opts.beforePut?.(store, asset);
      return opts.putAsset?.(asset) ?? Response.json({key: asset, url: `https://prismwalls.com/api/ai/assets/${asset}`});
    }
    if (method === "DELETE") return opts.deleteAsset?.() ?? Response.json({deleted: true});
    throw new Error(`unexpected fetch ${method} ${url}`);
  });
  const depthCalls: Array<{candidateId: string; jpeg: Buffer}> = [];
  const deps: StudioProcessDeps = {
    worker: {base: BASE, secret: "test-secret"},
    annotate: async () => typeof opts.vision === "function" ? opts.vision() : opts.vision ?? CLEAN,
    depth: async (candidateId, jpeg) => {
      depthCalls.push({candidateId, jpeg});
      if (!opts.depth) throw new Error("depth check down");
      return opts.depth;
    },
    rng: opts.rng ?? seededRng(1),
    nowMs: opts.nowMs ?? Date.now,
  };
  const run = () => processCandidate(RUN, CAND, deps);
  return {store, calls, depthCalls, run, cand: () => store.get(CAND_PATH) as Doc};
}

const walls = (store: Map<string, Doc>) => [...store.entries()].filter(([path]) => path.startsWith("walls/"));
const workerError = (status: number, error: string) => () => Response.json({error, message: "x"}, {status});

test("Duo publishes exact wide original to normal review with no automatic Drop reserve", async (t) => {
  const wide = await flatPng(2688, 1888);
  const {store, run, cand, calls} = setup(t, {
    seed: {[CAND_PATH]: candidate({seriesId: "duo-reveal", duoPresetId: "prism-right-v1", width: 2688, height: 1888,
      tags: ["duo", "duo-reveal"]})},
    image: async () => wide,
  });
  await run();
  assert.equal(cand().status, "pending_review");
  const wall = walls(store)[0][1];
  assert.equal(wall.review, false);
  assert.equal(wall.dropReserved, undefined);
  assert.equal(wall.resolution, "2670x1878");
  assert.equal(wall.duoPresetId, "prism-right-v1");
  const body = calls.find((c) => c.method === "POST")?.body as Doc;
  assert.equal(body.duoPresetId, "prism-right-v1");
});

test("a clean candidate becomes a pending wall with the app's fields, a signature doc and two uploads", async (t) => {
  const {store, calls, run, cand} = setup(t);
  await run();

  const generate = calls.find((c) => c.method === "POST");
  assert.deepEqual(generate?.body, {id: CAND, prompt: "an eclipse, ember light", model: "fal-ai/model", width: 1440,
    height: 3200, seed: 42});
  assert.equal(generate?.headers["x-studio-secret"], "test-secret");

  const puts = calls.filter((c) => c.method === "PUT");
  assert.deepEqual(puts.map((c) => c.url), [`${BASE}/api/ai/studio/assets/ai/studio/${CAND}.jpg`,
    `${BASE}/api/ai/studio/assets/ai/studio/thumb_${CAND}.jpg`]);
  for (const put of puts) {
    assert.equal(put.headers["content-type"], "image/jpeg");
    assert.equal(put.headers["x-studio-secret"], "test-secret");
  }
  const wallMeta = await sharp(Buffer.from(puts[0].body as Uint8Array)).metadata();
  const thumbMeta = await sharp(Buffer.from(puts[1].body as Uint8Array)).metadata();
  assert.deepEqual([wallMeta.format, wallMeta.width, wallMeta.height], ["jpeg", 1440, 3200]);
  assert.deepEqual([thumbMeta.format, thumbMeta.width, thumbMeta.height], ["jpeg", 486, 1080]);
  assert.deepEqual(calls.filter((c) => c.method === "DELETE").map((c) => c.url),
    [`${BASE}/api/ai/studio/assets/${RAW_KEY}`]);

  const [[path, wall]] = walls(store);
  const wallId = path.split("/")[1];
  assert.match(wallId, /^[A-Z0-9]{10}$/);
  const {createdAt, size, ...rest} = wall;
  assert.ok(createdAt instanceof admin.firestore.Timestamp);
  assert.match(String(size), /^\d+\.\d{2}MB$/);
  assert.deepEqual(rest, {
    by: "Prism Studio", email: "studio@prismwalls.com", userPhoto: "https://p/studio.png", id: wallId,
    wallpaper_provider: "Prism",
    wallpaper_thumb: `https://prismwalls.com/api/ai/assets/ai/studio/thumb_${CAND}.jpg`,
    wallpaper_url: `https://prismwalls.com/api/ai/assets/ai/studio/${CAND}.jpg`,
    resolution: "1440x3200", title: "Eclipse · Ember", category: "Space", desc: "After Dark by Prism Studio",
    review: false, collections: ["community"], tags: ["amoled", "dark", "eclipse"], isAiGenerated: true,
    aiProvider: "fal", aiModel: "fal-ai/model-v2", aiPrompt: "an eclipse, ember light", origin: "studio",
    seriesId: "after-dark", studioCandidateId: CAND, studioRunId: RUN, dropReserved: true,
  });

  const signature = store.get(`studioSignatures/${CAND}`);
  assert.deepEqual({...signature, createdAt: undefined}, {signature: await imageSignature(wallpaper), wallId,
    candidateId: CAND, createdAt: undefined});
  const done = cand();
  assert.equal(done.status, "pending_review");
  assert.equal(done.wallId, wallId);
  assert.equal(done.attempts, 1);
  assert.equal((done.gates as Doc).passed, true);
  assert.equal((done.worker as Doc).costUsd, 0.04);

  calls.length = 0;
  await run();
  assert.equal(calls.length, 0, "a terminal candidate does nothing");
  assert.equal(walls(store).length, 1);
});

const depthCandidate = candidate({seriesId: "depth-effect", subjectId: "sky-cat", paletteId: "clear-blue",
  prompt: "a fluffy cat, clear blue sky", title: "Sky Cat · Clear Blue", category: "Nature", tags: ["cat"]});
const AUTO_DEPTH: WallDepth = {tier: "auto", kind: "pet", top: 0.012, v: 1, by: "detector"};

test("a depth series candidate that passes the depth check writes depth on the new wall", async (t) => {
  const {store, depthCalls, run, cand} = setup(t, {seed: {[CAND_PATH]: depthCandidate}, depth: AUTO_DEPTH});
  await run();
  assert.equal(cand().status, "pending_review");
  assert.deepEqual(((cand().gates as Doc).details as Doc).depth, {tier: "auto", kind: "pet", top: 0.012});
  const [[, wall]] = walls(store);
  assert.deepEqual(wall.depth, AUTO_DEPTH);
  assert.equal(wall.desc, "Depth Effect by Prism Studio");
  assert.equal(depthCalls.length, 1);
  assert.equal(depthCalls[0].candidateId, CAND);
  const meta = await sharp(depthCalls[0].jpeg).metadata();
  assert.deepEqual([meta.format, meta.width, meta.height], ["jpeg", 720, 1600]);
});

test("a depth series candidate with tier none is rejected for depth and makes no wall", async (t) => {
  const {store, calls, run, cand} = setup(t, {seed: {[CAND_PATH]: depthCandidate},
    depth: {tier: "none", kind: "pet", top: 0.6, v: 1, by: "detector"}});
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().reasons, ["depth"]);
  assert.deepEqual(((cand().gates as Doc).details as Doc).depth, {tier: "none", kind: "pet", top: 0.6});
  assert.deepEqual(calls.filter((c) => c.method === "DELETE").map((c) => c.url),
    [`${BASE}/api/ai/studio/assets/${RAW_KEY}`]);
  assert.equal(walls(store).length, 0);
});

test("a depth series candidate whose depth check cannot run goes back to the queue and the event retries", async (t) => {
  const {store, run, cand} = setup(t, {seed: {[CAND_PATH]: depthCandidate}});
  await assert.rejects(run(), /depth check down/);
  assert.equal(cand().status, "queued");
  assert.match(String(cand().lastError), /depth check down/);
  assert.equal(walls(store).length, 0);
});

test("a candidate of a series without depth never runs the depth check", async (t) => {
  const {store, depthCalls, run} = setup(t, {depth: AUTO_DEPTH});
  await run();
  assert.equal(depthCalls.length, 0);
  const [[, wall]] = walls(store);
  assert.equal("depth" in wall, false);
});

test("only the first dailyDropReserves walls of a UTC day are reserved for the Drop", async (t) => {
  const nowMs = () => Date.parse("2026-10-19T21:00:00Z");
  const first = setup(t, {nowMs});
  await first.run();
  assert.equal(walls(first.store)[0][1].dropReserved, true);
  assert.equal(first.store.get("studioDropReserves/2026-10-19")?.count, 1);

  const second = setup(t, {nowMs, seed: {"studioDropReserves/2026-10-19": {day: "2026-10-19", count: 1}}});
  await second.run();
  assert.equal(walls(second.store)[0][1].dropReserved, undefined);
  assert.equal(second.store.get("studioDropReserves/2026-10-19")?.count, 1);

  const nextDay = setup(t, {nowMs: () => Date.parse("2026-10-20T00:30:00Z"),
    seed: {"studioDropReserves/2026-10-19": {day: "2026-10-19", count: 1}}});
  await nextDay.run();
  assert.equal(walls(nextDay.store)[0][1].dropReserved, true);
  assert.equal(nextDay.store.get("studioDropReserves/2026-10-20")?.count, 1);

  const off = setup(t, {nowMs,
    seed: {"studioConfig/current": {generationEnabled: true, identity: IDENTITY, dailyDropReserves: 0}}});
  await off.run();
  assert.equal(walls(off.store)[0][1].dropReserved, undefined);
  assert.equal(off.store.has("studioDropReserves/2026-10-19"), false);
});

test("a wall id that exists already is not overwritten; the next id is used", async (t) => {
  const taken = randomWallId(seededRng(9));
  const {store, run, cand} = setup(t, {seed: {[`walls/${taken}`]: {title: "Old"}}, rng: seededRng(9)});
  await run();
  assert.deepEqual(store.get(`walls/${taken}`), {title: "Old"});
  assert.notEqual(cand().wallId, taken);
  assert.equal(store.get(`walls/${cand().wallId}`)?.origin, "studio");
});

test("a gate failure rejects the candidate, deletes the raw image and makes no wall", async (t) => {
  const {store, calls, run, cand} = setup(t, {vision: {safeSearchAnnotation: {adult: "LIKELY", racy: 1,
    violence: 1, medical: 1}}});
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().reasons, ["unsafe_adult"]);
  assert.equal(((cand().gates as Doc).details as Doc).vision !== undefined, true);
  assert.deepEqual(calls.filter((c) => c.method === "DELETE").map((c) => c.url),
    [`${BASE}/api/ai/studio/assets/${RAW_KEY}`]);
  assert.equal(calls.some((c) => c.method === "PUT"), false);
  assert.equal(walls(store).length, 0);
});

test("a near copy of an earlier Studio wall is rejected as a duplicate", async (t) => {
  const earlier = await gradientPng(1440, 3200);
  const {run, cand} = setup(t, {
    image: async () => sharp(earlier).jpeg({quality: 70}).toBuffer(),
    seed: {"studioSignatures/old": {signature: await imageSignature(earlier), wallId: "OLDWALL1AB"}},
  });
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().reasons, ["duplicate"]);
  assert.equal((((cand().gates as Doc).details as Doc).duplicate as Doc).nearestWallId, "OLDWALL1AB");
});

test("a signature added after gates still blocks publication", async (t) => {
  const signature = await imageSignature(wallpaper);
  const {store, calls, run, cand} = setup(t, {beforePut: (docs, key) => {
    if (key === `ai/studio/${CAND}.jpg`) docs.set("studioSignatures/concurrent", {signature, wallId: "OTHERWALL01"});
  }});
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().reasons, ["duplicate"]);
  assert.deepEqual(calls.filter((call) => call.method === "DELETE").map((call) => call.url), [
    `${BASE}/api/ai/studio/assets/${RAW_KEY}`,
    `${BASE}/api/ai/studio/assets/ai/studio/${CAND}.jpg`,
    `${BASE}/api/ai/studio/assets/ai/studio/thumb_${CAND}.jpg`,
  ]);
  assert.deepEqual(store.get(CAND_PATH)?.cleanupKeys, []);
  assert.equal(walls(store).length, 0);
});

test("a stale attempt cannot reset a newer attempt that published", async (t) => {
  let clock = Date.now();
  let generationCount = 0;
  let firstStarted!: () => void;
  let releaseFirst!: (response: Response) => void;
  const started = new Promise<void>((resolve) => {
    firstStarted = resolve;
  });
  const firstResponse = new Promise<Response>((resolve) => {
    releaseFirst = resolve;
  });
  const {run, cand, store} = setup(t, {
    nowMs: () => clock,
    generate: () => ++generationCount === 1 ? (firstStarted(), firstResponse) : Response.json({
      id: CAND, imageUrl: IMAGE_URL, key: RAW_KEY, width: 1440, height: 3200, contentType: "image/png",
      bytes: wallpaper.length, model: "fal-ai/model-v2", provider: "fal", seed: 42, costUsd: 0.04,
    }),
  });
  const firstAttempt = run();
  await started;
  clock += 7 * 60_000;
  await run();
  assert.equal(cand().status, "pending_review");
  releaseFirst(Response.json({error: "provider_error"}, {status: 502}));
  await assert.rejects(firstAttempt);
  assert.equal(cand().status, "pending_review");
  assert.equal(walls(store).length, 1);
});

test("failed R2 deletion is retried without regenerating a terminal candidate", async (t) => {
  let deleteCount = 0;
  const {calls, run, cand} = setup(t, {vision: {safeSearchAnnotation: {adult: "LIKELY", racy: 1, violence: 1, medical: 1}},
    deleteAsset: () => ++deleteCount === 1 ? Response.json({error: "unavailable"}, {status: 503}) : Response.json({deleted: true})});
  await assert.rejects(run());
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().cleanupKeys, [RAW_KEY]);
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().cleanupKeys, []);
  assert.equal(calls.filter((call) => call.method === "POST").length, 1);
  assert.equal(deleteCount, 2);
});

test("a retry that ends in rejection cleans assets from its earlier partial upload", async (t) => {
  let rejectImage = false;
  let thumbUploads = 0;
  const wallKey = `ai/studio/${CAND}.jpg`;
  const thumbKey = `ai/studio/thumb_${CAND}.jpg`;
  const upload = (key: string) => {
    if (key === thumbKey && ++thumbUploads === 1) return Response.json({error: "provider_error"}, {status: 503});
    return Response.json({key, url: `https://prismwalls.com/api/ai/assets/${key}`});
  };
  const {calls, run, cand} = setup(t, {
    vision: () => rejectImage ? {safeSearchAnnotation: {adult: "LIKELY", racy: 1, violence: 1, medical: 1}} : CLEAN,
    putAsset: upload,
  });
  await assert.rejects(run());
  assert.equal(cand().status, "queued");
  assert.deepEqual(cand().outputAssetKeys, [wallKey, thumbKey]);
  assert.equal(calls.some((call) => call.method === "DELETE"), false);

  rejectImage = true;
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(calls.filter((call) => call.method === "DELETE").map((call) => call.url), [
    `${BASE}/api/ai/studio/assets/${wallKey}`,
    `${BASE}/api/ai/studio/assets/${thumbKey}`,
    `${BASE}/api/ai/studio/assets/${RAW_KEY}`,
  ]);
});

test("a permanent retry failure cleans prior raw and partial output assets", async (t) => {
  const wallKey = `ai/studio/${CAND}.jpg`;
  const thumbKey = `ai/studio/thumb_${CAND}.jpg`;
  const {calls, run, cand} = setup(t, {seed: {
    "studioConfig/current": {generationEnabled: false, identity: IDENTITY},
    [CAND_PATH]: candidate({attempts: 1, worker: {key: RAW_KEY}, outputAssetKeys: [wallKey, thumbKey]}),
  }});
  await run();
  assert.equal(cand().status, "failed");
  assert.equal(cand().error, "disabled");
  assert.deepEqual(calls.filter((call) => call.method === "DELETE").map((call) => call.url), [
    `${BASE}/api/ai/studio/assets/${wallKey}`,
    `${BASE}/api/ai/studio/assets/${thumbKey}`,
    `${BASE}/api/ai/studio/assets/${RAW_KEY}`,
  ]);
});

test("an image that does not decode is rejected and deleted", async (t) => {
  const {store, calls, run, cand} = setup(t, {image: async () => Buffer.from("<html>not an image</html>")});
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().reasons, ["undecodable"]);
  assert.equal(calls.filter((c) => c.method === "DELETE").length, 1);
  assert.equal(walls(store).length, 0);
});

for (const [name, response] of [
  ["503 service_disabled", workerError(503, "service_disabled")],
  ["502 provider_error", workerError(502, "provider_error")],
  ["502 provider_timeout", workerError(502, "provider_timeout")],
  ["409 in_progress", workerError(409, "in_progress")],
] as const) {
  test(`worker ${name} is transient: back to queued and the event retries`, async (t) => {
    const {run, cand} = setup(t, {generate: response});
    await assert.rejects(run());
    assert.equal(cand().status, "queued");
    assert.equal(cand().attempts, 1);
    assert.match(String(cand().lastError), new RegExp(name.split(" ")[0]));
  });
}

test("a network error is transient", async (t) => {
  const {run, cand} = setup(t, {generate: () => {
    throw new TypeError("fetch failed");
  }});
  await assert.rejects(run());
  assert.equal(cand().status, "queued");
  assert.match(String(cand().lastError), /fetch failed/);
});

test("budget_exhausted and 400 fail the candidate without a retry", async (t) => {
  for (const [response, code] of [[workerError(429, "budget_exhausted"), "budget_exhausted"],
    [workerError(400, "invalid_request"), "invalid_request"], [workerError(401, "unauthorized"), "unauthorized"]] as const) {
    const {run, cand} = setup(t, {generate: response});
    await run();
    assert.equal(cand().status, "failed");
    assert.equal(cand().error, code);
  }
});

test("502 unsafe_output rejects the candidate", async (t) => {
  const {store, run, cand} = setup(t, {generate: workerError(502, "unsafe_output")});
  await run();
  assert.equal(cand().status, "rejected");
  assert.deepEqual(cand().reasons, ["unsafe_output"]);
  assert.equal(walls(store).length, 0);
});

test("the fourth claim marks the candidate failed and calls nothing", async (t) => {
  const {calls, run, cand} = setup(t, {seed: {[CAND_PATH]: candidate({attempts: 3})}});
  await run();
  assert.equal(cand().status, "failed");
  assert.equal(cand().error, "max_attempts");
  assert.equal(calls.length, 0);
});

test("the terminal attempt removes raw and partial output assets", async (t) => {
  const partialWallKey = `ai/studio/${CAND}.jpg`;
  const partialThumbKey = `ai/studio/thumb_${CAND}.jpg`;
  const {calls, run, cand} = setup(t, {seed: {[CAND_PATH]: candidate({attempts: 3,
    worker: {key: RAW_KEY}, outputAssetKeys: [partialWallKey, partialThumbKey]})}});
  await run();
  assert.equal(cand().status, "failed");
  assert.equal(cand().error, "max_attempts");
  assert.deepEqual(calls.filter((call) => call.method === "DELETE").map((call) => call.url), [
    `${BASE}/api/ai/studio/assets/${partialWallKey}`,
    `${BASE}/api/ai/studio/assets/${partialThumbKey}`,
    `${BASE}/api/ai/studio/assets/${RAW_KEY}`,
  ]);
  assert.deepEqual(cand().cleanupKeys, []);
  assert.equal(calls.some((call) => call.method === "POST"), false);
});

test("three transient failures, then the next delivery gives up", async (t) => {
  const {run, cand} = setup(t, {generate: workerError(503, "service_disabled")});
  for (let i = 1; i <= 3; i++) {
    await assert.rejects(run());
    assert.equal(cand().attempts, i);
  }
  await run();
  assert.equal(cand().status, "failed");
  assert.equal(cand().error, "max_attempts");
});

test("a fresh claim by another attempt makes the event retry later; a stale one is taken over", async (t) => {
  const fresh = setup(t, {seed: {[CAND_PATH]: candidate({status: "generating", attempts: 1,
    claimedAt: admin.firestore.Timestamp.now()})}});
  await assert.rejects(fresh.run(), /another attempt/);
  assert.equal(fresh.calls.length, 0);

  const stale = setup(t, {seed: {[CAND_PATH]: candidate({status: "generating", attempts: 1,
    claimedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 10 * 60_000)})}});
  await stale.run();
  assert.equal(stale.cand().status, "pending_review");
  assert.equal(stale.cand().attempts, 2);
});

test("generation off at processing time fails the candidate before calling the worker", async (t) => {
  const {calls, run, cand} = setup(t, {seed: {"studioConfig/current": {generationEnabled: false, identity: IDENTITY}}});
  await run();
  assert.equal(cand().status, "failed");
  assert.equal(cand().error, "disabled");
  assert.equal(calls.length, 0);
});

test("a hidden, deleted, or filled request rejects its queued candidate before generation", async (t) => {
  const openRequest = {status: "open", hidden: false};
  for (const scenario of [
    {name: "hidden", request: {...openRequest, hidden: true}},
    {name: "deleted", request: undefined},
    {name: "filled", request: {...openRequest, status: "filled"}},
  ]) {
    await t.test(scenario.name, async (child) => {
      const {calls, run, cand, store} = setup(child, {seed: {
        [CAND_PATH]: candidate({seriesId: "request", requestId: "r1"}),
        ...(scenario.request ? {"wallRequests/r1": scenario.request} : {}),
      }});
      await run();
      assert.equal(cand().status, "rejected");
      assert.equal(cand().lastError, "request_unavailable");
      assert.deepEqual(cand().reasons, ["request_unavailable"]);
      assert.equal(calls.some((call) => call.method === "POST"), false);
      assert.equal(walls(store).length, 0);
    });
  }
});

test("a request hidden after generation cannot publish a wall", async (t) => {
  const {calls, run, cand, store} = setup(t, {seed: {
    [CAND_PATH]: candidate({seriesId: "request", requestId: "r1"}),
    "wallRequests/r1": {status: "open", hidden: false},
  }, beforePut: (docs, key) => {
    if (key === `ai/studio/${CAND}.jpg`) docs.set("wallRequests/r1", {status: "open", hidden: true});
  }});
  await run();
  assert.equal(cand().status, "rejected");
  assert.equal(cand().lastError, "request_unavailable");
  assert.deepEqual(cand().reasons, ["request_unavailable"]);
  assert.equal(calls.some((call) => call.method === "POST"), true);
  assert.equal(walls(store).length, 0);
  assert.deepEqual(cand().cleanupKeys, []);
});

test("thumbnails match the app's FlutterImageCompress(minWidth 400) result; size reads like the app", () => {
  assert.deepEqual(thumbSize(1440, 3200), {width: 486, height: 1080});
  assert.deepEqual(thumbSize(300, 600), {width: 300, height: 600});
  assert.equal(humanSize(2_202_010), "2.10MB");
});

const studioWall = (extra: Doc = {}): Doc => ({
  ...IDENTITY, review: false, title: "Eclipse · Ember", wallpaper_thumb: "https://prismwalls.com/t.jpg",
  origin: "studio", studioRunId: RUN, studioCandidateId: CAND, ...extra,
});

test("isStudioWall needs origin studio and a candidate that points back at the wall", async (t) => {
  installFakeDb(t, {[CAND_PATH]: candidate({wallId: "WALL1AAAAA"})});
  assert.equal(await isStudioWall("WALL1AAAAA", studioWall()), true);
  assert.equal(await isStudioWall("WALL1AAAAA", studioWall({email: "attacker@example.com"})), false);
  assert.equal(await isStudioWall("OTHER1AAAA", studioWall()), false);
  assert.equal(await isStudioWall("WALL1AAAAA", studioWall({origin: "app"})), false);
  assert.equal(await isStudioWall("WALL1AAAAA", studioWall({studioRunId: "../x"})), false);
  assert.equal(await isStudioWall("WALL1AAAAA", studioWall({studioCandidateId: undefined})), false);
});

function walls2(t: TestContext, wall: Doc) {
  const store = installFakeDb(t, {
    "walls/WALL1AAAAA": wall,
    [CAND_PATH]: candidate({wallId: "WALL1AAAAA"}),
    "usersv2/studio": {email: IDENTITY.email, name: "Someone Else", profilePhoto: "https://p/other.png", premium: true},
    "config/adminNotifications": {emails: ["admin@example.com"]},
    "usersv2/adm1": {email: "admin@example.com"},
    "usersv2/adm1/private/session": {
      fcmToken: "admin-token", fcmTokenBindingVersion: 1, fcmTokenBindingToken: "admin-token",
    },
  });
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  return {store, send};
}

function failStudioCandidateRead(t: TestContext) {
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => name === "studioRuns" ? {
    doc: () => ({collection: () => ({doc: () => ({get: async () => {
      throw new Error("candidate read failed");
    }})})}),
  } : collection(name));
}

async function approvalEvent(store: Map<string, Doc>): Promise<Parameters<typeof onWallApproved.run>[0]> {
  const before = store.get("walls/WALL1AAAAA");
  store.set("walls/WALL1AAAAA", {...before, id: "WALL1AAAAA", review: true});
  return {params: {wallId: "WALL1AAAAA"}, data: {before: {data: () => before},
    after: await db.doc("walls/WALL1AAAAA").get()},
  } as unknown as Parameters<typeof onWallApproved.run>[0];
}

test("onWallSubmitted leaves a Studio wall alone: no owner sync, no admin push", async (t) => {
  const {store, send} = walls2(t, studioWall());
  await onWallSubmitted.run({
    params: {wallId: "WALL1AAAAA"},
    data: {data: () => store.get("walls/WALL1AAAAA"), ref: {update: async (u: Doc) =>
      void store.set("walls/WALL1AAAAA", {...store.get("walls/WALL1AAAAA"), ...u})}},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.equal(store.get("walls/WALL1AAAAA")?.by, "Prism Studio");
  assert.equal(send.mock.callCount(), 0);
});

test("a user wall that only claims origin studio still gets the owner sync", async (t) => {
  const {store, send} = walls2(t, studioWall({studioCandidateId: "d20261012-9"}));
  await onWallSubmitted.run({
    params: {wallId: "WALL1AAAAA"},
    data: {data: () => store.get("walls/WALL1AAAAA"), ref: {update: async (u: Doc) =>
      void store.set("walls/WALL1AAAAA", {...store.get("walls/WALL1AAAAA"), ...u})}},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.equal(store.get("walls/WALL1AAAAA")?.by, "Someone Else");
  assert.equal(send.mock.callCount(), 1, "the spoofed Studio wall gets one generic private-session alert");
});

test("onWallSubmitted stops before owner sync or notification when the candidate read fails", async (t) => {
  const {store, send} = walls2(t, studioWall());
  failStudioCandidateRead(t);
  const updates: Doc[] = [];
  await assert.rejects(onWallSubmitted.run({
    params: {wallId: "WALL1AAAAA"},
    data: {data: () => store.get("walls/WALL1AAAAA"), ref: {update: async (u: Doc) => {
      updates.push(u);
    }}},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]), /candidate read failed/);
  assert.deepEqual(updates, []);
  assert.equal(send.mock.callCount(), 0);
});

test("onWallApproved sends no pushes for a Studio wall", async (t) => {
  const {store, send} = walls2(t, studioWall());
  await onWallApproved.run(await approvalEvent(store));
  assert.equal(send.mock.callCount(), 0);
});

test("a recreated Studio wall under another email cannot bypass blocked-requester fill checks", async (t) => {
  const {store} = walls2(t, studioWall({email: "attacker@example.com", creatorUid: "attacker", requestId: "r1"}));
  store.set("usersv2/requester", {email: "requester@example.com", loggedIn: true});
  store.set("wallRequests/r1", {status: "open", hidden: false, requesterUid: "requester", text: "Dark mountains"});
  store.set("usersv2/attacker/blockedUsers/requester", {});
  await onWallApproved.run(await approvalEvent(store));
  assert.equal(store.get("wallRequests/r1")?.status, "open");
  assert.equal(store.get("wallRequests/r1")?.notifiedAt, undefined);
});

test("onWallApproved stops before notification when the candidate read fails", async (t) => {
  const {store, send} = walls2(t, studioWall());
  failStudioCandidateRead(t);
  await assert.rejects(onWallApproved.run(await approvalEvent(store)), /candidate read failed/);
  assert.equal(send.mock.callCount(), 0);
});

test("a user wall that only claims origin studio still gets approval notifications", async (t) => {
  const {store, send} = walls2(t, studioWall({studioCandidateId: "d20261012-9"}));
  await onWallApproved.run(await approvalEvent(store));
  assert.ok(send.mock.callCount() > 0, "the spoofed Studio wall still sends approval notifications");
});
