import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {onWallApproved} from "../onWallApproved";
import {onWallSubmitted} from "../onWallSubmitted";
import {imageSignature, type VisionResult} from "../studio/gates";
import {randomWallId} from "../studio/ids";
import {humanSize, isStudioWall, processCandidate, type StudioProcessDeps, thumbSize} from "../studio/process";
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
  generate?: () => Response;
  image?: () => Promise<Buffer>;
  vision?: VisionResult;
  rng?: () => number;
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
      return opts.generate?.() ?? Response.json({
        id: CAND, imageUrl: IMAGE_URL, key: RAW_KEY, width: 1440, height: 3200, contentType: "image/png",
        bytes: wallpaper.length, model: "fal-ai/model-v2", provider: "fal", seed: 42, costUsd: 0.04,
      });
    }
    if (method === "GET" && url === IMAGE_URL) return new Response(new Uint8Array(await (opts.image?.() ?? wallpaper)));
    const asset = url.replace(`${BASE}/api/ai/studio/assets/`, "");
    if (method === "PUT") return Response.json({key: asset, url: `https://prismwalls.com/api/ai/assets/${asset}`});
    if (method === "DELETE") return Response.json({deleted: true});
    throw new Error(`unexpected fetch ${method} ${url}`);
  });
  const deps: StudioProcessDeps = {
    worker: {base: BASE, secret: "test-secret"},
    annotate: async () => opts.vision ?? CLEAN,
    rng: opts.rng ?? seededRng(1),
    nowMs: Date.now,
  };
  const run = () => processCandidate(RUN, CAND, deps);
  return {store, calls, run, cand: () => store.get(CAND_PATH) as Doc};
}

const walls = (store: Map<string, Doc>) => [...store.entries()].filter(([path]) => path.startsWith("walls/"));
const workerError = (status: number, error: string) => () => Response.json({error, message: "x"}, {status});

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
  assert.equal(calls.some((c) => c.method === "DELETE"), false);

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
    seriesId: "after-dark", studioCandidateId: CAND, studioRunId: RUN,
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

test("a wall id that exists already is not overwritten; the next id is used", async (t) => {
  const taken = randomWallId(seededRng(9));
  const {store, run, cand} = setup(t, {seed: {[`walls/${taken}`]: {title: "Old"}}, rng: seededRng(9)});
  await run();
  assert.deepEqual(store.get(`walls/${taken}`), {title: "Old"});
  assert.notEqual(cand().wallId, taken);
  assert.equal(store.get(`walls/${cand().wallId}`)?.origin, "studio");
});

test("a gate failure rejects the candidate, deletes the raw image and makes no wall", async (t) => {
  const {store, calls, run, cand} = setup(t, {vision: {safeSearchAnnotation: {adult: "LIKELY"}}});
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
  });
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  return {store, send};
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
  const {store} = walls2(t, studioWall({studioCandidateId: "d20261012-9"}));
  await onWallSubmitted.run({
    params: {wallId: "WALL1AAAAA"},
    data: {data: () => store.get("walls/WALL1AAAAA"), ref: {update: async (u: Doc) =>
      void store.set("walls/WALL1AAAAA", {...store.get("walls/WALL1AAAAA"), ...u})}},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.equal(store.get("walls/WALL1AAAAA")?.by, "Someone Else");
});

test("onWallApproved sends no pushes for a Studio wall", async (t) => {
  const {store, send} = walls2(t, studioWall());
  await onWallApproved.run({
    params: {wallId: "WALL1AAAAA"},
    data: {
      before: {data: () => store.get("walls/WALL1AAAAA")},
      after: {data: () => ({...store.get("walls/WALL1AAAAA"), review: true})},
    },
  } as unknown as Parameters<typeof onWallApproved.run>[0]);
  assert.equal(send.mock.callCount(), 0);
});
