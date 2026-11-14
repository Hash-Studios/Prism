import assert from "node:assert/strict";
import type {TestContext} from "node:test";
import test from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {db} from "../common";
import {ECONOMY_CONFIG_DOC, resetEconomyCache} from "../economy";
import {
  createPhotoWallpaper,
  failPhotoJob,
  finishImage,
  isPhotoSafe,
  normalizePhoto,
  PHOTO_JOBS,
  STALE_RUNNING_MS,
  photoDeps,
  PhotoJobResult,
  planPhotoJob,
  sweepStalePhotoJobsOnce,
  PHOTO_FAL_CLEANUP,
  PHOTO_JOB_CLOSURES,
  getPhotoWallpaper,
  PHOTO_JOB_BUDGET,
  removePhotoJobsForAccount,
  parseStyleId,
  PHOTO_STYLES,
  restylePrompt,
} from "../photoWallpaper";
import {installFakeDb} from "./fakeDb";

type Store = ReturnType<typeof installFakeDb>;
type Call = {url: string; method: string; headers: Record<string, string>; body: Record<string, unknown>};
type Succeeded = Extract<PhotoJobResult, {state: "succeeded"}>;
type Failed = Extract<PhotoJobResult, {state: "failed"}>;

const BLUE = {r: 40, g: 90, b: 160};
const SAFE = {adult: "VERY_UNLIKELY", racy: "UNLIKELY", violence: "VERY_UNLIKELY"};
const USER = {uid: "u1", token: {firebase: {sign_in_provider: "google.com"}}};
const JOB_ID = "pj_u1_req-00000001";
const JOB = `${PHOTO_JOBS}/${JOB_ID}`;
const CHARGE = "coinTransactions/ctx_photoWallpaper_u1_req-00000001";
const REFUND = "coinTransactions/ctx_photoWallpaperRefund_u1_req-00000001";
const OUT_URL = "https://cdn.test/photo-walls/x.jpg";
const FAL_EXTEND = "https://fal.run/fal-ai/bria/expand";
const FAL_UPSCALE = "https://fal.run/fal-ai/seedvr/upscale/image";
const FAL_RESTYLE = "https://fal.run/fal-ai/bytedance/seedream/v4/edit";
const FAL_DELETE = "https://api.fal.ai/v1/models/requests/req-abcdef12/payloads";
const MINUTE = 60_000;

const today = () => new Date().toISOString().slice(0, 10);
const jpegOf = (width: number, height: number): Promise<Buffer> =>
  sharp({create: {width, height, channels: 3, background: BLUE}}).jpeg().toBuffer();
const b64 = async (width: number, height: number) => (await jpegOf(width, height)).toString("base64");
const sizeOf = async (buf: Buffer) => {
  const meta = await sharp(buf).metadata();
  return {width: meta.width, height: meta.height};
};
const run = (data: Record<string, unknown>, auth: unknown = USER) =>
  createPhotoWallpaper.run({auth, data} as unknown as Parameters<typeof createPhotoWallpaper.run>[0]);
const coinTxCount = (store: Store) => [...store.keys()].filter((k) => k.startsWith("coinTransactions/")).length;

const extendData = async (patch: Record<string, unknown> = {}) => ({
  requestId: "req-00000001", mode: "extend", target: "phone", targetWidth: 1080, targetHeight: 2340,
  image: await b64(1600, 1200), ...patch,
});
const upscaleData = async (patch: Record<string, unknown> = {}) => ({
  requestId: "req-00000001", mode: "upscale", target: "phone", targetWidth: 1080, targetHeight: 2340,
  image: await b64(540, 1170), ...patch,
});
const restyleData = async (patch: Record<string, unknown> = {}) => ({
  requestId: "req-00000001", mode: "restyle", target: "phone", targetWidth: 1080, targetHeight: 2340,
  styleId: "anime", image: await b64(1600, 1200), ...patch,
});

/** Mocks every outside dependency. The fal output is a 1080x2340 JPEG unless `falStatus` makes fal fail. */
function mockDeps(t: TestContext, opts: {falStatus?: number; deleteStatus?: number; deleteException?: string;
  deleteTimeout?: () => void; safe?: (call: number) => Record<string, unknown> | Promise<Record<string, unknown>>} = {}) {
  const calls: Call[] = [];
  const stored: Buffer[] = [];
  const counts = {safe: 0};
  const output = sharp({create: {width: 1080, height: 2340, channels: 3, background: BLUE}})
    .withExif({IFD0: {Copyright: "private-provider-metadata"}}).jpeg().toBuffer();
  t.mock.method(photoDeps, "falKey", () => "test-key");
  t.mock.method(photoDeps, "safeSearch", async () => {
    counts.safe++;
    return opts.safe?.(counts.safe) ?? SAFE;
  });
  t.mock.method(photoDeps, "fetch", async (url: string, init: RequestInit) => {
    const method = init.method ?? "GET";
    const headers = (init.headers ?? {}) as Record<string, string>;
    const body = typeof init.body === "string" ? JSON.parse(init.body) as Record<string, unknown> : {};
    calls.push({url, method, headers, body});
    if (url.startsWith("https://fal.run/")) {
      const meta = {"x-fal-request-id": "req-abcdef12"};
      if (opts.falStatus) return new Response("provider error", {status: opts.falStatus, headers: meta});
      const image = (await output).toString("base64");
      return new Response(JSON.stringify({image: {url: `data:image/jpeg;base64,${image}`}}),
        {status: 200, headers: meta});
    }
    if (url.startsWith("https://api.fal.ai/v1/models/requests/") && method === "DELETE") {
      if (opts.deleteTimeout) {
        opts.deleteTimeout();
        throw new DOMException("request timed out", "TimeoutError");
      }
      return Response.json({cdn_delete_results: opts.deleteException ?
        [{link: "https://private-provider-link.test", exception: opts.deleteException}] : []},
      {status: opts.deleteStatus ?? 200});
    }
    throw new Error(`unexpected fetch ${method} ${url}`);
  });
  t.mock.method(photoDeps, "store", async (jpeg: Buffer, key: string) => {
    stored.push(jpeg);
    return {url: OUT_URL, key};
  });
  t.mock.method(photoDeps, "remove", async () => undefined);
  return {calls, stored, counts, fal: () => calls.filter((c) => c.url.startsWith("https://fal.run/"))};
}

test("no auth and anonymous auth are refused before any charge", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const data = await extendData();
  await assert.rejects(() => createPhotoWallpaper.run({data} as unknown as
    Parameters<typeof createPhotoWallpaper.run>[0]), {code: "unauthenticated"});
  await assert.rejects(() => run(data, {uid: "a", token: {firebase: {sign_in_provider: "anonymous"}}}),
    {code: "unauthenticated"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(coinTxCount(store), 0);
  assert.equal(deps.fal().length, 0);
});

test("bad input is refused before any charge or job is written", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const cases: Array<[string, Record<string, unknown>, {code: string; message?: string}]> = [
    ["bad requestId", {requestId: "short"}, {code: "invalid-argument"}],
    ["bad mode", {mode: "crop"}, {code: "invalid-argument"}],
    ["bad target size", {targetWidth: 500}, {code: "invalid-argument"}],
    ["non-image base64", {image: Buffer.from("hello world!").toString("base64")}, {code: "invalid-argument"}],
    ["photo that already fits", {image: await b64(1080, 2340)},
      {code: "failed-precondition", message: "plan_mismatch"}],
    ["upscale with a placement", await upscaleData({placement: {left: 0, top: 0, width: 1080, height: 2340}}),
      {code: "invalid-argument"}],
  ];
  for (const [name, patch, expected] of cases) {
    const data = name === "upscale with a placement" ? patch : {...await extendData(), ...patch};
    await assert.rejects(() => run(data), expected, name);
    assert.equal(store.get("usersv2/u1")?.coins, 200, name);
    assert.equal(coinTxCount(store), 0, name);
    assert.equal([...store.keys()].filter((k) => k.startsWith(`${PHOTO_JOBS}/`)).length, 0, name);
  }
  assert.equal(deps.fal().length, 0);
});

test("extend returns the 1080x2340 result, charges 75 and stores a succeeded job", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const result = await run(await extendData()) as Succeeded;
  assert.equal(result.state, "succeeded");
  assert.equal(result.cost, 75);
  assert.equal(result.width, 1080);
  assert.equal(result.height, 2340);
  assert.equal(result.watermarked, true);
  assert.equal(result.imageUrl, OUT_URL);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.get(CHARGE)?.delta, -75);
  assert.equal(store.get(CHARGE)?.action, "photoWallpaper");
  assert.equal(store.get(JOB)?.state, "succeeded");
  assert.equal(store.get(JOB)?.falCleanupPending, false);
  assert.deepEqual(await sizeOf(deps.stored[0]), {width: 1080, height: 2340});
  assert.equal((await sharp(deps.stored[0]).metadata()).exif, undefined);
  assert.equal(deps.stored[0].includes("private-provider-metadata"), false);
});

test("the fal request sends the photo inline, keeps no store, and deletes the payload", async (t) => {
  installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  await run(await extendData());
  const post = deps.fal()[0];
  assert.ok(post);
  assert.equal(post.method, "POST");
  assert.equal(post.url, FAL_EXTEND);
  assert.equal(post.headers["X-Fal-Store-IO"], "0");
  assert.ok(String(post.body.image_url).startsWith("data:image/jpeg;base64,"));
  assert.equal(post.body.sync_mode, true);
  assert.deepEqual(post.body.canvas_size, [1080, 2340]);
  const deletes = deps.calls.filter((c) => c.method === "DELETE");
  assert.equal(deletes.length, 1);
  assert.equal(deletes[0].url, FAL_DELETE);
  assert.equal(deletes[0].headers.Authorization, "Key test-key");
  // The input photo is never stored. Only the result is stored, once, at the target size.
  assert.equal(deps.stored.length, 1);
  assert.deepEqual(await sizeOf(deps.stored[0]), {width: 1080, height: 2340});
});

test("a rejected fal cleanup is reported without logging the photo or the provider response", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const opts = {deleteStatus: 403};
  mockDeps(t, opts);
  const removed: string[] = [];
  t.mock.method(photoDeps, "remove", async (key: string) => removed.push(key));
  const logs: unknown[][] = [];
  t.mock.method(logger, "warn", (...args: unknown[]) => logs.push(args));
  const result = await run(await extendData());
  assert.equal(result.state, "succeeded");
  assert.deepEqual(logs, [["photoWallpaper: fal payload delete failed.", {requestId: "req-abcdef12"}]]);
  assert.equal(store.get(JOB)?.falCleanupPending, true);
  opts.deleteStatus = 200;
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(store.get(JOB)?.falCleanupPending, false);
  assert.equal(store.get(JOB)?.state, "succeeded");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.deepEqual(removed, []);
});

test("an oversized inline fal image is rejected and refunded even when it is a decodable JPEG", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const fetch = photoDeps.fetch;
  const oversized = Buffer.concat([await jpegOf(1080, 2340), Buffer.alloc(30 * 1024 * 1024)]);
  t.mock.method(photoDeps, "fetch", (url: string, init: RequestInit) => url === FAL_EXTEND ?
    Promise.resolve(Response.json({image: {url: `data:image/jpeg;base64,${oversized.toString("base64")}`}},
      {headers: {"x-fal-request-id": "req-abcdef12"}})) : fetch(url, init));
  const result = await run(await extendData()) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "provider_error");
  assert.equal(result.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(deps.stored.length, 0);
});

test("fal per-file cleanup errors stay pending without logging the provider link or error", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const opts = {deleteException: "private-failure"};
  mockDeps(t, opts);
  const logs: unknown[][] = [];
  t.mock.method(logger, "warn", (...args: unknown[]) => logs.push(args));
  assert.equal((await run(await extendData())).state, "succeeded");
  assert.equal(store.get(JOB)?.falCleanupPending, true);
  assert.deepEqual(logs, [["photoWallpaper: fal payload delete failed.", {requestId: "req-abcdef12"}]]);
  opts.deleteException = "";
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(store.get(JOB)?.falCleanupPending, false);
});

test("omitted and explicit placements both reject a photo that cannot cover 10% of the canvas", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t);
  const data = await extendData({image: await b64(4096, 256)});
  await assert.rejects(() => run(data), {code: "invalid-argument"});
  await assert.rejects(() => run({...data, placement: {left: 0, top: 0, width: 1080, height: 68}}),
    {code: "invalid-argument"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.has(JOB), false);
});

test("the sweeper reaches stale jobs beyond its first 200 running jobs", async (t) => {
  const seed: Record<string, Record<string, unknown>> = {"usersv2/u1": {coins: 125}};
  for (let i = 0; i < 200; i++) {
    seed[`${PHOTO_JOBS}/pj_active_${i.toString().padStart(3, "0")}`] = runningJob(admin.firestore.Timestamp.now());
  }
  seed[JOB] = runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE));
  const store = installFakeDb(t, seed);
  assert.equal(await sweepStalePhotoJobsOnce(), 1);
  assert.equal(store.get(JOB)?.state, "failed");
  assert.equal(store.get("usersv2/u1")?.coins, 200);
});

test("the sweeper removes a result left by a crash and retries a failed deletion", async (t) => {
  const key = "photo-walls/crashed.jpg";
  const store = installFakeDb(t, {"usersv2/u1": {coins: 125}, [JOB]: {
    ...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
    resultKey: key, cleanupPending: true,
  }});
  const images = new Set([key]);
  let attempts = 0;
  t.mock.method(photoDeps, "remove", async (resultKey: string) => {
    if (++attempts === 1) throw new Error("temporary storage failure");
    images.delete(resultKey);
  });
  assert.equal(await sweepStalePhotoJobsOnce(), 1);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(JOB)?.cleanupPending, true);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(images.size, 0);
  assert.equal(store.get(JOB)?.cleanupPending, false);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
});

test("cleanup failures rotate across runs and cannot starve the other cleanup queue", async (t) => {
  let clock = Date.now();
  t.mock.method(Date, "now", () => clock);
  const seed: Record<string, Record<string, unknown>> = {};
  for (const id of ["a", "b", "c"]) {
    seed[`${PHOTO_JOBS}/pj_${id}`] = {...runningJob(admin.firestore.Timestamp.now()), state: "failed",
      resultKey: `photo-walls/${id}.jpg`, cleanupPending: true};
  }
  seed[`${PHOTO_JOBS}/pj_fal`] = {...runningJob(admin.firestore.Timestamp.now()), state: "succeeded",
    falRequestId: "req-abcdef12", falCleanupPending: true};
  const store = installFakeDb(t, seed);
  mockDeps(t);
  const remaining = new Set(["photo-walls/c.jpg"]);
  t.mock.method(photoDeps, "remove", async (key: string) => {
    if (key !== "photo-walls/c.jpg") {
      clock += 11_000;
      throw new Error("storage timeout");
    }
    remaining.delete(key);
  });
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(remaining.size, 1);
  assert.equal(store.get(`${PHOTO_JOBS}/pj_fal`)?.falCleanupPending, false);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(remaining.size, 0);
  assert.equal(store.get(`${PHOTO_JOBS}/pj_c`)?.cleanupPending, false);
});

test("a Pro member pays half, rounded up, and gets no watermark", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200, premium: true}});
  mockDeps(t);
  const result = await run(await extendData()) as Succeeded;
  assert.equal(result.cost, 38);
  assert.equal(result.watermarked, false);
  assert.equal(store.get("usersv2/u1")?.coins, 162);
  assert.equal(store.get(CHARGE)?.delta, -38);
});

test("upscale calls the SeedVR model, costs 10, and sends an upscale factor from 1 to 4", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const result = await run(await upscaleData()) as Succeeded;
  assert.equal(result.state, "succeeded");
  assert.equal(result.cost, 10);
  assert.equal(store.get("usersv2/u1")?.coins, 190);
  const post = deps.fal()[0];
  assert.ok(post);
  assert.equal(post.url, FAL_UPSCALE);
  const factor = post.body.upscale_factor;
  assert.equal(typeof factor, "number");
  assert.ok((factor as number) >= 1 && (factor as number) <= 4, `upscale_factor was ${factor}`);
});

test("an unsafe input photo fails as unsafe_input, refunds 75 and never reaches fal or storage", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t, {safe: (call) => call === 1 ? {...SAFE, adult: "VERY_LIKELY"} : SAFE});
  const result = await run(await extendData()) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "unsafe_input");
  assert.equal(result.refunded, true);
  assert.equal(deps.fal().length, 0);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(deps.stored.length, 0);
});

test("an unsafe result fails as unsafe_output, refunds the coins and stores nothing", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t, {safe: (call) => call === 2 ? {...SAFE, racy: "VERY_LIKELY"} : SAFE});
  const result = await run(await extendData()) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "unsafe_output");
  assert.equal(result.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(deps.stored.length, 0);
});

test("Vision input and output errors fail closed without logging private request details", async (t) => {
  for (const failingCall of [1, 2]) {
    await t.test(`Vision failure at check ${failingCall}`, async (s) => {
      const store = installFakeDb(s, {"usersv2/u1": {coins: 200}});
      const deps = mockDeps(s);
      const data = await extendData();
      const logs: unknown[][] = [];
      s.mock.method(logger, "warn", (...args: unknown[]) => logs.push(args));
      s.mock.method(logger, "error", (...args: unknown[]) => logs.push(args));
      let checks = 0;
      s.mock.method(photoDeps, "safeSearch", async () => {
        if (++checks === failingCall) throw new Error(`private-failure ${data.image}`);
        return SAFE;
      });
      const result = await run(data) as Failed;
      assert.equal(result.state, "failed");
      assert.equal(result.reason, "provider_error");
      assert.equal(result.refunded, true);
      assert.equal(store.get("usersv2/u1")?.coins, 200);
      assert.equal(deps.stored.length, 0);
      assert.equal(JSON.stringify(logs).includes("private-failure"), false);
      assert.equal(JSON.stringify(logs).includes(data.image), false);
    });
  }
});

test("a refund commit failure leaves a running job for the sweeper to refund once", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}}, undefined, {failCommitAt: 2});
  mockDeps(t, {falStatus: 500});
  const result = await run(await extendData()) as Failed;
  assert.equal(result.refunded, false);
  assert.equal(store.get(JOB)?.state, "running");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(await sweepStalePhotoJobsOnce(Date.now() + 11 * MINUTE), 1);
  assert.equal(await sweepStalePhotoJobsOnce(Date.now() + 11 * MINUTE), 0);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(coinTxCount(store), 2);
});

test("a fal error fails as provider_error and refunds the coins", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t, {falStatus: 500});
  const result = await run(await extendData()) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "provider_error");
  assert.equal(result.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
});

test("replaying a succeeded requestId returns the same image and charges once", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const first = await run(await extendData()) as Succeeded;
  const second = await run(await extendData()) as Succeeded;
  assert.equal(second.imageUrl, first.imageUrl);
  assert.equal(deps.fal().filter((c) => c.method === "POST").length, 1);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(coinTxCount(store), 1);
  assert.equal(store.get(CHARGE)?.delta, -75);
});

test("replaying a failed requestId returns the same failure and refunds once", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t, {falStatus: 500});
  const first = await run(await extendData()) as Failed;
  const second = await run(await extendData()) as Failed;
  assert.equal(second.state, "failed");
  assert.equal(second.reason, first.reason);
  assert.equal(second.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
});

test("a job that is still running is not run twice", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200},
    [JOB]: runningJob(admin.firestore.Timestamp.now()),
  });
  const deps = mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "aborted"});
  assert.equal(deps.fal().length, 0);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
});

test("concurrent replays charge once while the original job is running", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  let entered!: () => void;
  let release!: () => void;
  const started = new Promise<void>((resolve) => entered = resolve);
  const wait = new Promise<void>((resolve) => release = resolve);
  t.mock.method(photoDeps, "safeSearch", async () => {
    entered();
    await wait;
    return SAFE;
  });
  const data = await extendData();
  const first = run(data);
  await started;
  try {
    await assert.rejects(() => run(data), {code: "aborted", message: "in_progress"});
  } finally {
    release();
  }
  assert.equal((await first).state, "succeeded");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(coinTxCount(store), 1);
  assert.equal(deps.fal().length, 1);
});

test("racing failures and a stale claim cannot refund the same job twice", async (t) => {
  const started = admin.firestore.Timestamp.now();
  const store = installFakeDb(t, {"usersv2/u1": {coins: 125}, [JOB]: runningJob(started)});
  assert.equal((await failPhotoJob(JOB_ID, started.toMillis() - 1, "timeout"))?.state, "running");
  const results = await Promise.all([
    failPhotoJob(JOB_ID, started.toMillis(), "timeout"),
    failPhotoJob(JOB_ID, started.toMillis(), "provider_error"),
  ]);
  assert.deepEqual(results.map((r) => r?.state), ["failed", "failed"]);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(coinTxCount(store), 1);
});

test("a failure after the deletion barrier does not refund or create a refund transaction", async (t) => {
  const startedAt = admin.firestore.Timestamp.now();
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 0, deleted: true},
    "creatorDeletionState/u1": {closed: true},
    [JOB]: runningJob(startedAt),
  });
  const failed = await failPhotoJob(JOB_ID, startedAt.toMillis(), "timeout");
  assert.equal(failed?.state, "failed");
  assert.equal(failed?.refunded, false);
  assert.equal(store.get("usersv2/u1")?.coins, 0);
  assert.equal(store.has(REFUND), false);
});

test("finish acknowledgement and follow-up read failures preserve the committed outcome", async (t) => {
  for (const [committed, readFails] of [[true, false], [true, true], [false, true]]) {
    await t.test(`committed: ${committed}, follow-up read fails: ${readFails}`, async (s) => {
      const store = installFakeDb(s, {"usersv2/u1": {coins: 200}});
      mockDeps(s);
      const removed: string[] = [];
      s.mock.method(photoDeps, "remove", async (key: string) => removed.push(key));
      const collection = db.collection.bind(db);
      let failNextRead = false;
      s.mock.method(db, "collection", (name: string) => {
        const col = collection(name);
        return {...col, doc: (id: string) => {
          const ref = col.doc(id);
          return {...ref, get: async () => {
            if (name === PHOTO_JOBS && failNextRead) {
              failNextRead = false;
              throw new Error("read acknowledgement lost");
            }
            return ref.get();
          }};
        }};
      });
      const transaction = db.runTransaction.bind(db);
      let transactions = 0;
      s.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
        if (++transactions === 2 && !committed) {
          failNextRead = readFails;
          throw new Error("commit failed");
        }
        const result = await transaction(callback);
        if (transactions === 2) {
          failNextRead = readFails;
          throw new Error("commit acknowledgement lost");
        }
        return result;
      });
      const result = await run(await extendData());
      if (committed) {
        assert.equal(result.state, "succeeded");
        assert.equal((result as Succeeded).imageUrl, OUT_URL);
        assert.equal(store.get("usersv2/u1")?.coins, 125);
        assert.equal(store.has(REFUND), false);
        assert.deepEqual(removed, []);
      } else {
        assert.equal(result.state, "failed");
        assert.equal((result as Failed).refunded, true);
        assert.equal(store.get("usersv2/u1")?.coins, 200);
        assert.deepEqual(removed, [store.get(JOB)?.resultKey]);
      }
    });
  }
});

test("a sweeper that wins a late finish refunds once and removes the unused result", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t);
  const images = new Set<string>();
  let removals = 0;
  t.mock.method(photoDeps, "store", async (_jpeg: Buffer, key: string) => {
    assert.equal(await sweepStalePhotoJobsOnce(Date.now() + 11 * MINUTE), 1);
    images.add(OUT_URL);
    return {url: OUT_URL, key};
  });
  t.mock.method(photoDeps, "remove", async (key: string) => {
    assert.equal(key, store.get(JOB)?.resultKey);
    if (++removals === 2) throw new Error("temporary late cleanup failure");
    images.delete(OUT_URL);
  });
  const result = await run(await extendData()) as Failed;
  assert.equal(result.reason, "timeout");
  assert.equal(result.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(coinTxCount(store), 2);
  assert.equal(store.get(JOB)?.cleanupPending, true);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(images.size, 0);
});

test("a stale running job is refunded when its requestId is replayed", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 125},
    [JOB]: runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
  });
  const deps = mockDeps(t);
  const result = await run(await extendData()) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "timeout");
  assert.equal(result.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(deps.fal().length, 0);
});

test("the sweeper refunds only the stale running job, and a second sweep does nothing", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 50},
    [JOB]: runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
    [`${PHOTO_JOBS}/pj_u1_req-00000002`]: {...runningJob(admin.firestore.Timestamp.now()),
      requestId: "req-00000002", chargeTxId: "ctx_photoWallpaper_u1_req-00000002"},
  });
  assert.equal(await sweepStalePhotoJobsOnce(), 1);
  assert.equal(store.get(JOB)?.state, "failed");
  assert.equal(store.get(JOB)?.refunded, true);
  assert.equal(store.get(`${PHOTO_JOBS}/pj_u1_req-00000002`)?.state, "running");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
});

test("the daily cap per user refuses the job before any charge", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200},
    "photoJobDaily/u1": {day: today(), count: 10},
  });
  mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "resource-exhausted"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.has(JOB), false);
});

test("the global daily budget refuses the job before any charge", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200},
    [`photoJobBudget/${today()}`]: {day: today(), count: 400},
  });
  mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "resource-exhausted"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.has(JOB), false);
});

test("concurrent new jobs cannot cross either daily cap", async (t) => {
  for (const cap of ["user", "global"]) {
    await t.test(cap, async (s) => {
      const store = installFakeDb(s, {"usersv2/u1": {coins: 200},
        "photoJobDaily/u1": {day: today(), count: cap === "user" ? 9 : 0},
        [`photoJobBudget/${today()}`]: {day: today(), count: cap === "global" ? 399 : 0},
      });
      mockDeps(s, {safe: () => ({...SAFE, adult: "VERY_LIKELY"})});
      const data = await extendData();
      const results = await Promise.allSettled([run(data), run({...data, requestId: "req-00000002"})]);
      assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
      const rejected = results.find((r) => r.status === "rejected") as PromiseRejectedResult;
      assert.equal(rejected.reason.code, "resource-exhausted");
      assert.equal(store.get("photoJobDaily/u1")?.count, cap === "user" ? 10 : 1);
      assert.equal(store.get(`photoJobBudget/${today()}`)?.count, cap === "global" ? 400 : 1);
      assert.equal(coinTxCount(store), 2);
      assert.equal(store.get("usersv2/u1")?.coins, 200);
    });
  }
});

test("extend with too few coins fails with failed-precondition and charges nothing", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 10}});
  mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "failed-precondition"});
  assert.equal(store.get("usersv2/u1")?.coins, 10);
  assert.equal(store.has(JOB), false);
});

test("another user with the same requestId gets a separate job and its own charge", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}, "usersv2/u2": {coins: 200}});
  mockDeps(t);
  await run(await extendData());
  const second = await run(await extendData(), {uid: "u2", token: {firebase: {sign_in_provider: "google.com"}}}) as Succeeded;
  assert.equal(second.state, "succeeded");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.get("usersv2/u2")?.coins, 125);
  assert.equal(store.get("photoJobs/pj_u2_req-00000001")?.userId, "u2");
  assert.equal(store.get("coinTransactions/ctx_photoWallpaper_u2_req-00000001")?.delta, -75);
});

test("a closed account deletion barrier refuses a new photo job before charging", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200},
    "creatorDeletionState/u1": {closed: true},
  });
  mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "failed-precondition"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.has(JOB), false);
  assert.equal(store.has("photoJobDaily/u1"), false);
  assert.equal(coinTxCount(store), 0);
});

test("a closed account deletion barrier refuses replay of a stored photo result", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200},
    "creatorDeletionState/u1": {closed: true},
    [JOB]: {...runningJob(admin.firestore.Timestamp.now()), state: "succeeded", imageUrl: OUT_URL},
  });
  const deps = mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "failed-precondition"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(coinTxCount(store), 0);
  assert.equal(deps.fal().length, 0);
});

test("normalizePhoto strips EXIF and GPS metadata from the JPEG it returns", async () => {
  const withExif = await sharp({create: {width: 300, height: 300, channels: 3, background: BLUE}})
    .withExif({IFD0: {Copyright: "secret-owner"}, IFD3: {GPSLatitudeRef: "N"}}).jpeg().toBuffer();
  assert.ok((await sharp(withExif).metadata()).exif, "the test input must carry EXIF");
  const {jpeg} = await normalizePhoto(withExif.toString("base64"));
  assert.equal((await sharp(jpeg).metadata()).exif, undefined);
  assert.equal(jpeg.includes("secret-owner"), false);
  const result = await finishImage(withExif, {width: 720, height: 1600}, false);
  assert.deepEqual(await sizeOf(result), {width: 720, height: 1600});
  assert.equal((await sharp(result).metadata()).exif, undefined);
  assert.equal(result.includes("secret-owner"), false);
});

test("isPhotoSafe blocks the listed likelihoods and a missing annotation, and allows racy LIKELY", () => {
  assert.equal(isPhotoSafe({...SAFE, adult: "LIKELY"}), false);
  assert.equal(isPhotoSafe({...SAFE, violence: "LIKELY"}), false);
  assert.equal(isPhotoSafe({...SAFE, racy: "VERY_LIKELY"}), false);
  assert.equal(isPhotoSafe(null), false);
  assert.equal(isPhotoSafe(undefined), false);
  assert.equal(isPhotoSafe({adult: "VERY_UNLIKELY", violence: "VERY_UNLIKELY"}), false);
  assert.equal(isPhotoSafe({...SAFE, racy: "LIKELY"}), true);
});

test("planPhotoJob picks extend, upscale or fits from the photo and target shapes", () => {
  assert.equal(planPhotoJob({width: 1600, height: 1200}, {width: 1080, height: 2340}), "extend");
  assert.equal(planPhotoJob({width: 540, height: 1170}, {width: 1080, height: 2340}), "upscale");
  assert.equal(planPhotoJob({width: 1080, height: 2340}, {width: 1080, height: 2340}), "fits");
  assert.equal(planPhotoJob({width: 1200, height: 1600}, {width: 2560, height: 1600}), "extend");
  assert.equal(planPhotoJob({width: 1280, height: 800}, {width: 2560, height: 1600}), "upscale");
});

/** A job record as the functions write it, with the given start time and charge. */
function runningJob(startedAt: admin.firestore.Timestamp) {
  return {userId: "u1", requestId: "req-00000001", mode: "extend", target: "phone", model: "fal-ai/bria/expand",
    cost: 75, chargeTxId: "ctx_photoWallpaper_u1_req-00000001", state: "running", startedAt, width: 1080,
    height: 2340};
}

test("account deletion removes the user's stored results and job records, and nothing else", async (t) => {
  const store = installFakeDb(t, {
    "photoJobs/pj_u1_a": {userId: "u1", resultKey: "photo-walls/aaa.jpg"},
    "photoJobs/pj_u1_b": {userId: "u1"},
    "photoJobs/pj_u2_a": {userId: "u2", resultKey: "photo-walls/bbb.jpg"},
  });
  const removed: string[] = [];
  await removePhotoJobsForAccount("u1", {...photoDeps, remove: async (key: string) => {
    removed.push(key);
  }});
  assert.deepEqual(removed, ["photo-walls/aaa.jpg"]);
  assert.equal(store.get("photoJobs/pj_u1_a"), undefined);
  assert.equal(store.get("photoJobs/pj_u1_b"), undefined);
  assert.ok(store.get("photoJobs/pj_u2_a"));
});

test("account deletion waits for a fresh photo job, then cleans it after the stale-job horizon", async (t) => {
  const startedAt = admin.firestore.Timestamp.now();
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(startedAt), resultKey: "photo-walls/result.jpg", cleanupPending: true},
  });
  const removed: string[] = [];
  const deps = {...photoDeps, remove: async (key: string) => {
    removed.push(key);
  }};
  await assert.rejects(() => removePhotoJobsForAccount("u1", deps), {code: "internal"});
  assert.equal(store.get(JOB)?.state, "running");
  assert.deepEqual(removed, []);

  t.mock.method(Date, "now", () => startedAt.toMillis() + STALE_RUNNING_MS + 1);
  await removePhotoJobsForAccount("u1", deps);
  assert.deepEqual(removed, ["photo-walls/result.jpg"]);
  assert.equal(store.get(JOB), undefined);
});

test("account deletion never waits on fal: a failed payload delete moves to an anonymous retry record", async (t) => {
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)), state: "failed",
      falRequestId: "req-abcdef12", falCleanupPending: true},
  });
  mockDeps(t, {deleteStatus: 403});
  await removePhotoJobsForAccount("u1");
  assert.equal(store.get(JOB), undefined);
  const retry = store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`);
  assert.deepEqual(Object.keys(retry ?? {}).sort(), ["at", "falRequestId"]);
  assert.equal(retry?.falRequestId, "req-abcdef12");
});

test("account deletion queues more than 30 fal cleanups without waiting on provider timeouts", async (t) => {
  const seed = Object.fromEntries(Array.from({length: 40}, (_, i) => {
    const requestId = `req-${String(i).padStart(8, "0")}`;
    return [`photoJobs/job-${String(i).padStart(2, "0")}`, {
      ...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
      state: "failed", falRequestId: requestId, falCleanupPending: true,
    }];
  }));
  const store = installFakeDb(t, seed);
  let clock = Date.now();
  const started = clock;
  t.mock.method(Date, "now", () => clock);
  const deps = mockDeps(t, {deleteTimeout: () => {
    clock += 10_000;
  }});
  await removePhotoJobsForAccount("u1");
  assert.equal(deps.calls.filter((call) => call.method === "DELETE").length, 2);
  assert.equal(clock - started, 20_000);
  assert.equal(Array.from(store.entries()).filter(([path]) => path.startsWith(`${PHOTO_FAL_CLEANUP}/`)).length, 40);
  for (const [path, retry] of store) {
    if (path.startsWith(`${PHOTO_FAL_CLEANUP}/`)) {
      assert.deepEqual(Object.keys(retry).sort(), ["at", "falRequestId"]);
      assert.equal(retry.falRequestId, path.split("/")[1]);
    }
  }
  assert.equal(Array.from(store.entries()).filter(([path]) => path.startsWith("photoJobs/")).length, 0);
});

test("account deletion stops on an R2 failure before enqueueing fal cleanup", async (t) => {
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(admin.firestore.Timestamp.now()), state: "succeeded", resultKey: "photo-walls/result.jpg",
      falRequestId: "req-abcdef12", falCleanupPending: true},
  });
  const deps = mockDeps(t);
  await assert.rejects(() => removePhotoJobsForAccount("u1", {...photoDeps, remove: async () => {
    throw new Error("storage unavailable");
  }}));
  assert.equal(store.get(JOB)?.falCleanupPending, true);
  assert.equal(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`), undefined);
  assert.equal(deps.calls.filter((call) => call.method === "DELETE").length, 0);
});

test("the sweeper retries anonymous fal cleanup records and removes them once fal confirms", async (t) => {
  const store = installFakeDb(t, {[`${PHOTO_FAL_CLEANUP}/req-abcdef12`]: {falRequestId: "req-abcdef12",
    at: admin.firestore.Timestamp.now()}});
  const options = {deleteStatus: 403};
  const deps = mockDeps(t, options);
  await sweepStalePhotoJobsOnce();
  assert.ok(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`));
  options.deleteStatus = 200;
  await sweepStalePhotoJobsOnce();
  assert.equal(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`), undefined);
  assert.deepEqual(deps.calls.filter((call) => call.method === "DELETE").map((call) => call.url), [FAL_DELETE, FAL_DELETE]);
});

test("the orphan fal cleanup sweeper advances past a permanently failing first page", async (t) => {
  const seed = Object.fromEntries(Array.from({length: 11}, (_, i) => {
    const requestId = `req-${String(i).padStart(8, "0")}`;
    return [`${PHOTO_FAL_CLEANUP}/${requestId}`, {falRequestId: requestId}];
  }));
  const store = installFakeDb(t, seed);
  const calls: string[] = [];
  t.mock.method(photoDeps, "falKey", () => "test-key");
  t.mock.method(photoDeps, "fetch", async (url: string) => {
    calls.push(url);
    return Response.json({}, {status: 403});
  });
  await sweepStalePhotoJobsOnce();
  await sweepStalePhotoJobsOnce();
  assert.equal(calls.length, 11);
  assert.equal(calls[10], "https://api.fal.ai/v1/models/requests/req-00000010/payloads");
  assert.equal(Array.from(store.entries()).filter(([path]) => path.startsWith(`${PHOTO_FAL_CLEANUP}/`)).length, 11);
});

test("orphan cleanup timeouts rotate and wrap without blocking the other cleanup queues", async (t) => {
  const requestIds = Array.from({length: 5}, (_, i) => `req-${String(i).padStart(8, "0")}`);
  const startedAt = admin.firestore.Timestamp.now();
  const store = installFakeDb(t, {
    ...Object.fromEntries(requestIds.map((falRequestId) => [`${PHOTO_FAL_CLEANUP}/${falRequestId}`, {falRequestId}])),
    [`${PHOTO_JOBS}/storage`]: {...runningJob(startedAt), state: "failed", cleanupPending: true,
      resultKey: "photo-walls/cleanup.jpg"},
    [`${PHOTO_JOBS}/fal`]: {...runningJob(startedAt), state: "succeeded", falCleanupPending: true,
      falRequestId: "req-jobcleanup"},
  });
  let clock = startedAt.toMillis();
  t.mock.method(Date, "now", () => clock);
  mockDeps(t);
  const removed: string[] = [];
  const attempted: string[] = [];
  t.mock.method(photoDeps, "remove", async (key: string) => removed.push(key));
  t.mock.method(photoDeps, "fetch", async (url: string) => {
    if (url.includes("req-jobcleanup")) return Response.json({cdn_delete_results: []});
    attempted.push(url.split("/").at(-2) as string);
    clock += 10_000;
    throw new DOMException("request timed out", "TimeoutError");
  });
  const progress = `${PHOTO_JOB_BUDGET}/cleanup`;
  await sweepStalePhotoJobsOnce();
  assert.equal(clock - startedAt.toMillis(), 20_000);
  assert.deepEqual(attempted, requestIds.slice(0, 2));
  assert.equal(store.get(progress)?.falOrphans, requestIds[1]);
  assert.deepEqual(removed, ["photo-walls/cleanup.jpg"]);
  assert.equal(store.get(`${PHOTO_JOBS}/storage`)?.cleanupPending, false);
  assert.equal(store.get(`${PHOTO_JOBS}/fal`)?.falCleanupPending, false);
  await sweepStalePhotoJobsOnce();
  assert.equal(clock - startedAt.toMillis(), 40_000);
  assert.deepEqual(attempted, requestIds.slice(0, 4));
  assert.equal(store.get(progress)?.falOrphans, requestIds[3]);
  await sweepStalePhotoJobsOnce();
  assert.deepEqual(attempted, requestIds);
  assert.equal(store.get(progress)?.falOrphans, null);
  await sweepStalePhotoJobsOnce();
  assert.deepEqual(attempted, [...requestIds, ...requestIds.slice(0, 2)]);
  assert.equal(store.get(progress)?.falOrphans, requestIds[1]);
  assert.ok(requestIds.every((id) => store.has(`${PHOTO_FAL_CLEANUP}/${id}`)));
});

test("account deletion tolerates a concurrent deletion during successful fal cleanup", async (t) => {
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)), state: "failed",
      falRequestId: "req-abcdef12", falCleanupPending: true},
  });
  mockDeps(t);
  t.mock.method(photoDeps, "fetch", async (url: string) => {
    assert.equal(url, FAL_DELETE);
    store.delete(JOB);
    return Response.json({cdn_delete_results: []});
  });
  await assert.doesNotReject(() => removePhotoJobsForAccount("u1"));
  assert.equal(store.get(JOB), undefined);
});

test("overlapping account deletion and sweeping preserve a failed fal cleanup for retry", async (t) => {
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(admin.firestore.Timestamp.now()), state: "failed",
      falRequestId: "req-abcdef12", falCleanupPending: true},
  });
  mockDeps(t);
  let release!: () => void;
  let entered!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const paused = new Promise<void>((resolve) => {
    entered = resolve;
  });
  let calls = 0;
  t.mock.method(photoDeps, "fetch", async (url: string) => {
    assert.equal(url, FAL_DELETE);
    if (++calls === 1) {
      entered();
      await gate;
    }
    return Response.json({cdn_delete_results: []}, {status: calls < 3 ? 403 : 200});
  });
  const deletion = removePhotoJobsForAccount("u1");
  await paused;
  try {
    await sweepStalePhotoJobsOnce();
    assert.equal(calls, 2);
    assert.equal(store.get(JOB)?.falCleanupPending, true);
  } finally {
    release();
    await deletion;
  }
  assert.equal(store.get(JOB), undefined);
  assert.deepEqual(Object.keys(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`) ?? {}).sort(), ["at", "falRequestId"]);
  await sweepStalePhotoJobsOnce();
  assert.equal(calls, 3);
  assert.equal(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`), undefined);
});

test("concurrent sweeps tolerate deleting the same anonymous fal record", async (t) => {
  const path = `${PHOTO_FAL_CLEANUP}/req-abcdef12`;
  const store = installFakeDb(t, {[path]: {falRequestId: "req-abcdef12"}});
  mockDeps(t);
  let release!: () => void;
  let bothEntered!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const paused = new Promise<void>((resolve) => {
    bothEntered = resolve;
  });
  let calls = 0;
  t.mock.method(photoDeps, "fetch", async (url: string) => {
    assert.equal(url, FAL_DELETE);
    if (++calls === 2) bothEntered();
    await gate;
    return Response.json({cdn_delete_results: []});
  });
  const sweeps = Promise.all([sweepStalePhotoJobsOnce(), sweepStalePhotoJobsOnce()]);
  await paused;
  release();
  await sweeps;
  assert.equal(calls, 2);
  assert.equal(store.get(path), undefined);
});

test("account deletion handoff stays anonymous while the sweeper removes it", async (t) => {
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)), state: "failed",
      falRequestId: "req-abcdef12", falCleanupPending: true},
  });
  const options = {deleteStatus: 403};
  mockDeps(t, options);
  await removePhotoJobsForAccount("u1");
  assert.equal(store.get(JOB), undefined);
  assert.deepEqual(Object.keys(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`) ?? {}).sort(), ["at", "falRequestId"]);
  options.deleteStatus = 200;
  await sweepStalePhotoJobsOnce();
  assert.equal(store.get(JOB), undefined);
  assert.equal(store.get(`${PHOTO_FAL_CLEANUP}/req-abcdef12`), undefined);
});

test("account deletion retains a result record after storage removal fails, then retries it", async (t) => {
  const store = installFakeDb(t, {
    [JOB]: {...runningJob(admin.firestore.Timestamp.now()), state: "succeeded", resultKey: "photo-walls/result.jpg"},
  });
  await assert.rejects(() => removePhotoJobsForAccount("u1", {...photoDeps, remove: async () => {
    throw new Error("storage unavailable");
  }}));
  assert.ok(store.get(JOB));

  const removed: string[] = [];
  await removePhotoJobsForAccount("u1", {...photoDeps, remove: async (key: string) => {
    removed.push(key);
  }});
  assert.deepEqual(removed, ["photo-walls/result.jpg"]);
  assert.equal(store.get(JOB), undefined);
});

test("a photo paused in output SafeSearch cannot store after deletion begins", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  let releaseOutput!: () => void;
  let markPaused!: () => void;
  const outputGate = new Promise<void>((resolve) => {
    releaseOutput = resolve;
  });
  const outputPaused = new Promise<void>((resolve) => {
    markPaused = resolve;
  });
  let checks = 0;
  t.mock.method(photoDeps, "safeSearch", async () => {
    if (++checks === 2) {
      markPaused();
      await outputGate;
    }
    return SAFE;
  });
  const pending = run(await extendData()) as Promise<Succeeded | Failed>;
  await outputPaused;
  const job = store.get(JOB) as {startedAt: admin.firestore.Timestamp};
  store.set("creatorDeletionState/u1", {closed: true});
  t.mock.method(Date, "now", () => job.startedAt.toMillis() + 181_000);
  await assert.rejects(() => removePhotoJobsForAccount("u1"), {code: "internal"});
  assert.equal(store.get(JOB)?.state, "running");

  releaseOutput();
  const result = await pending;
  assert.equal(result.state, "failed");
  assert.equal(store.get(JOB)?.state, "failed");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.has(REFUND), false);
  assert.equal(deps.stored.length, 0);
});

test("an output SafeSearch result arriving after the work deadline cannot start storage", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  let releaseOutput!: () => void;
  let markPaused!: () => void;
  const outputGate = new Promise<void>((resolve) => {
    releaseOutput = resolve;
  });
  const outputPaused = new Promise<void>((resolve) => {
    markPaused = resolve;
  });
  let checks = 0;
  t.mock.method(photoDeps, "safeSearch", async () => {
    if (++checks === 2) {
      markPaused();
      await outputGate;
    }
    return SAFE;
  });
  const pending = run(await extendData()) as Promise<Succeeded | Failed>;
  await outputPaused;
  const job = store.get(JOB) as {startedAt: admin.firestore.Timestamp};
  t.mock.method(Date, "now", () => job.startedAt.toMillis() + 181_000);
  releaseOutput();
  const result = await pending;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "timeout");
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(deps.stored.length, 0);
});

test("a stale deletion retry leaves no row for a paused worker to recreate", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  let releaseOutput!: () => void;
  let markPaused!: () => void;
  const outputGate = new Promise<void>((resolve) => {
    releaseOutput = resolve;
  });
  const outputPaused = new Promise<void>((resolve) => {
    markPaused = resolve;
  });
  let checks = 0;
  t.mock.method(photoDeps, "safeSearch", async () => {
    if (++checks === 2) {
      markPaused();
      await outputGate;
    }
    return SAFE;
  });
  const pending = run(await extendData()) as Promise<Succeeded | Failed>;
  await outputPaused;
  const job = store.get(JOB) as {startedAt: admin.firestore.Timestamp};
  store.set("creatorDeletionState/u1", {closed: true});
  t.mock.method(Date, "now", () => job.startedAt.toMillis() + STALE_RUNNING_MS + 1);
  await removePhotoJobsForAccount("u1");
  assert.equal(store.get(JOB), undefined);

  releaseOutput();
  const result = await pending;
  assert.equal(result.state, "failed");
  assert.equal(store.get(JOB), undefined);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.has(REFUND), false);
  assert.equal(deps.stored.length, 0);
});

test("a photo paused in input SafeSearch cannot call fal after stale account cleanup", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  let releaseInput!: () => void;
  let markPaused!: () => void;
  const inputGate = new Promise<void>((resolve) => {
    releaseInput = resolve;
  });
  const inputPaused = new Promise<void>((resolve) => {
    markPaused = resolve;
  });
  t.mock.method(photoDeps, "safeSearch", async () => {
    markPaused();
    await inputGate;
    return SAFE;
  });
  const pending = run(await extendData()) as Promise<Succeeded | Failed>;
  await inputPaused;
  const job = store.get(JOB) as {startedAt: admin.firestore.Timestamp};
  store.set("creatorDeletionState/u1", {closed: true});
  t.mock.method(Date, "now", () => job.startedAt.toMillis() + STALE_RUNNING_MS + 1);
  await removePhotoJobsForAccount("u1");
  assert.equal(store.get(JOB), undefined);

  releaseInput();
  const result = await pending;
  assert.equal(result.state, "failed");
  assert.equal(deps.fal().length, 0);
  assert.equal(deps.stored.length, 0);
  assert.equal(store.get(JOB), undefined);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.has(REFUND), false);
});

test("deletion during an admitted storage write waits for the worker and can retry cleanup", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t);
  let releaseStore!: () => void;
  let markStoreStarted!: (key: string) => void;
  let releaseOutput!: () => void;
  let markOutputPaused!: () => void;
  const storeGate = new Promise<void>((resolve) => {
    releaseStore = resolve;
  });
  const storeStarted = new Promise<string>((resolve) => {
    markStoreStarted = resolve;
  });
  const outputGate = new Promise<void>((resolve) => {
    releaseOutput = resolve;
  });
  const outputPaused = new Promise<void>((resolve) => {
    markOutputPaused = resolve;
  });
  let checks = 0;
  t.mock.method(photoDeps, "safeSearch", async () => {
    if (++checks === 2) {
      markOutputPaused();
      await outputGate;
    }
    return SAFE;
  });
  t.mock.method(photoDeps, "store", async (_jpeg: Buffer, key: string) => {
    markStoreStarted(key);
    await storeGate;
    return {url: OUT_URL, key};
  });
  let removals = 0;
  t.mock.method(photoDeps, "remove", async () => {
    if (++removals === 1) throw new Error("storage unavailable");
  });
  const pending = run(await extendData()) as Promise<Succeeded | Failed>;
  await outputPaused;
  const job = store.get(JOB) as {startedAt: admin.firestore.Timestamp};
  t.mock.method(Date, "now", () => job.startedAt.toMillis() + 179_000);
  releaseOutput();
  const key = await storeStarted;
  store.set("creatorDeletionState/u1", {closed: true});
  t.mock.method(Date, "now", () => job.startedAt.toMillis() + 200_000);
  await assert.rejects(() => removePhotoJobsForAccount("u1"), {code: "internal"});
  assert.equal(store.get(JOB)?.state, "running");

  releaseStore();
  const result = await pending;
  assert.equal(result.state, "failed");
  assert.equal(store.get(JOB)?.state, "failed");
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.has(REFUND), false);
  assert.equal(store.get(JOB)?.resultKey, key);
  await removePhotoJobsForAccount("u1");
  assert.equal(store.get(JOB), undefined);
  assert.ok(key.startsWith("photo-walls/"));
});

const lookup = (data: Record<string, unknown>, auth: unknown = USER) =>
  getPhotoWallpaper.run({auth, data} as unknown as Parameters<typeof getPhotoWallpaper.run>[0]);

test("lookup after an app restart returns a finished job, and never charges", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 125}, [`${PHOTO_JOB_CLOSURES}/u1`]: {day: today(), count: 20},
    [JOB]: {...runningJob(admin.firestore.Timestamp.now()),
      state: "succeeded", imageUrl: OUT_URL, watermarked: true}});
  const result = await lookup({requestId: "req-00000001"}) as Succeeded;
  assert.equal(result.state, "succeeded");
  assert.equal(result.imageUrl, OUT_URL);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(coinTxCount(store), 0);
});

test("an unknown lookup closes the request, so a create that arrives later charges nothing", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const transaction = db.runTransaction.bind(db);
  let release!: () => void;
  let claimReached!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const entered = new Promise<void>((resolve) => {
    claimReached = resolve;
  });
  let first = true;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    if (first) {
      first = false;
      claimReached();
      await gate;
    }
    return transaction(callback);
  });
  const creating = run(await extendData());
  await entered;
  try {
    assert.deepEqual(await lookup({requestId: "req-00000001"}), {state: "unknown"});
    assert.equal(store.get(JOB)?.state, "closed");
    assert.equal(coinTxCount(store), 0);
  } finally {
    release();
  }
  await assert.rejects(creating, {code: "failed-precondition", message: "request_closed"});
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(coinTxCount(store), 0);
  assert.equal(deps.fal().length, 0);
  assert.deepEqual(await lookup({requestId: "req-00000001"}), {state: "unknown"});
});

test("lookup reports a running job as running, and ends a stale one with a refund", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 125}, [JOB]: runningJob(admin.firestore.Timestamp.now()),
    [`${PHOTO_JOB_CLOSURES}/u1`]: {day: today(), count: 20}});
  assert.deepEqual(await lookup({requestId: "req-00000001"}), {jobId: JOB_ID, state: "running", balance: 125});
  store.set(JOB, runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)));
  const failed = await lookup({requestId: "req-00000001"}) as Failed;
  assert.equal(failed.state, "failed");
  assert.equal(failed.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal((await lookup({requestId: "req-00000001"})).state, "failed");
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.count, 20);
});

test("lookup during a claimed create reports running, then replays its single completed charge", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  let release!: () => void;
  let checked!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const entered = new Promise<void>((resolve) => {
    checked = resolve;
  });
  mockDeps(t, {safe: async (call) => {
    if (call === 1) {
      checked();
      await gate;
    }
    return SAFE;
  }});
  const creating = run(await extendData());
  await entered;
  try {
    assert.deepEqual(await lookup({requestId: "req-00000001"}), {jobId: JOB_ID, state: "running", balance: 125});
  } finally {
    release();
  }
  const completed = await creating as Succeeded & {balance?: number};
  assert.equal(completed.state, "succeeded");
  assert.equal(completed.balance, 125);
  const replayed = await lookup({requestId: "req-00000001"}) as Succeeded & {balance?: number};
  assert.equal(replayed.state, "succeeded");
  assert.equal(replayed.balance, 125);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(coinTxCount(store), 1);
});

test("lookup during a claimed create replays its one refund after provider failure", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  let release!: () => void;
  let checked!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const entered = new Promise<void>((resolve) => {
    checked = resolve;
  });
  mockDeps(t, {falStatus: 500, safe: async (call) => {
    if (call === 1) {
      checked();
      await gate;
    }
    return SAFE;
  }});
  const creating = run(await extendData());
  await entered;
  try {
    assert.deepEqual(await lookup({requestId: "req-00000001"}), {jobId: JOB_ID, state: "running", balance: 125});
  } finally {
    release();
  }
  const failed = await creating as Failed & {balance?: number};
  assert.equal(failed.state, "failed");
  assert.equal(failed.refunded, true);
  assert.equal(failed.balance, 200);
  const replayed = await lookup({requestId: "req-00000001"}) as Failed & {balance?: number};
  assert.equal(replayed.refunded, true);
  assert.equal(replayed.balance, 200);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(coinTxCount(store), 2);
});

test("a stale lookup, create replay and sweeper refund once without running a new job", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 125},
    [JOB]: runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
    [CHARGE]: {delta: -75},
  });
  const deps = mockDeps(t);
  const data = await extendData();
  const [recovered, replayed] = await Promise.all([
    lookup({requestId: "req-00000001"}),
    run(data),
    sweepStalePhotoJobsOnce(),
  ]);
  for (const result of [recovered, replayed]) {
    assert.equal(result.state, "failed");
    assert.ok("refunded" in result && result.refunded);
    assert.ok("reason" in result && result.reason === "timeout");
  }
  assert.equal(store.get(JOB)?.state, "failed");
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(CHARGE)?.delta, -75);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(coinTxCount(store), 2);
  assert.equal(deps.counts.safe, 0);
  assert.deepEqual(deps.calls, []);
  assert.deepEqual(deps.stored, []);
});

test("lookup of an unknown job, or another user's job id, returns unknown", async (t) => {
  installFakeDb(t, {[JOB]: {...runningJob(admin.firestore.Timestamp.now()), state: "succeeded", imageUrl: OUT_URL}});
  assert.deepEqual(await lookup({requestId: "req-99999999"}), {state: "unknown"});
  const other = {uid: "u2", token: {firebase: {sign_in_provider: "google.com"}}};
  assert.deepEqual(await lookup({requestId: "req-00000001"}, other), {state: "unknown"});
});

test("an unknown lookup after account deletion does not recreate a job tombstone", async (t) => {
  const store = installFakeDb(t, {"creatorDeletionState/u1": {closed: true}});
  assert.deepEqual(await lookup({requestId: "req-00000001"}), {state: "unknown"});
  assert.equal(store.has(JOB), false);
});

test("the stale sweeper ignores closed tombstones, and account deletion removes them", async (t) => {
  const store = installFakeDb(t, {[JOB]: {userId: "u1", requestId: "req-00000001", state: "closed"}});
  const deps = mockDeps(t);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(store.get(JOB)?.state, "closed");
  assert.deepEqual(deps.calls, []);
  await removePhotoJobsForAccount("u1", photoDeps);
  assert.equal(store.has(JOB), false);
});

test("a closed request tombstone is scoped to its owner, and a fresh request id can still run", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200}, "usersv2/u2": {coins: 350},
    "photoJobs/pj_u1_req-00000001": {userId: "u1", requestId: "req-00000001", state: "closed"},
  });
  mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "failed-precondition", message: "request_closed"});
  const other = {uid: "u2", token: {firebase: {sign_in_provider: "google.com"}}};
  const otherResult = await run(await extendData(), other) as Succeeded & {balance?: number};
  assert.equal(otherResult.state, "succeeded");
  assert.equal(otherResult.balance, 275);
  const freshResult = await run(await extendData({requestId: "req-00000002"})) as Succeeded & {balance?: number};
  assert.equal(freshResult.state, "succeeded");
  assert.equal(freshResult.balance, 125);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(store.get("usersv2/u2")?.coins, 275);
});

test("lookup refuses a mismatched stored owner without revealing or changing that job", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 125}, "usersv2/u2": {coins: 50}});
  const deps = mockDeps(t);
  for (const state of ["running", "succeeded"]) {
    store.set(JOB, {...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
      userId: "u2", state, imageUrl: OUT_URL});
    const before = [...store.entries()];
    assert.deepEqual(await lookup({requestId: "req-00000001"}), {state: "unknown"});
    assert.deepEqual([...store.entries()], before);
  }
  assert.equal(coinTxCount(store), 0);
  assert.equal(deps.counts.safe, 0);
  assert.deepEqual(deps.calls, []);
});

test("lookup needs a signed-in, non-anonymous user and a valid requestId", async (t) => {
  installFakeDb(t);
  await assert.rejects(() => lookup({requestId: "req-00000001"}, null), {code: "unauthenticated"});
  await assert.rejects(() => lookup({requestId: "req-00000001"},
    {uid: "a", token: {firebase: {sign_in_provider: "anonymous"}}}), {code: "unauthenticated"});
  await assert.rejects(() => lookup({requestId: "x"}), {code: "invalid-argument"});
});

test("job results carry the user's coin balance after the charge or refund", async (t) => {
  installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t);
  const done = await run(await extendData()) as Succeeded & {balance?: number};
  assert.equal(done.balance, 125);
  const replayed = await lookup({requestId: "req-00000001"}) as Succeeded & {balance?: number};
  assert.equal(replayed.balance, 125);
});

test("a refunded failure carries the balance after the refund", async (t) => {
  installFakeDb(t, {"usersv2/u1": {coins: 200}});
  mockDeps(t, {falStatus: 500});
  const failed = await run(await extendData()) as Failed & {balance?: number};
  assert.equal(failed.state, "failed");
  assert.equal(failed.balance, 200);
});

test("balance lookup is optional when the user record is missing or unreadable", async (t) => {
  const store = installFakeDb(t, {[JOB]: {...runningJob(admin.firestore.Timestamp.now()), state: "succeeded", imageUrl: OUT_URL}});
  const missing = await lookup({requestId: "req-00000001"}) as Succeeded & {balance?: number};
  assert.equal(missing.state, "succeeded");
  assert.equal(missing.balance, undefined);

  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", ((name: string) => {
    const result = collection(name);
    if (name !== "usersv2") return result;
    const doc = result.doc.bind(result);
    return {...result, doc: (id?: string) => {
      const ref = doc(id ?? "u1");
      return {...ref, get: async () => {
        throw new Error("balance read unavailable");
      }};
    }};
  }) as typeof db.collection);
  const unreadable = await lookup({requestId: "req-00000001"}) as Succeeded & {balance?: number};
  assert.equal(unreadable.state, "succeeded");
  assert.equal(unreadable.balance, undefined);
  assert.equal(store.get(JOB)?.state, "succeeded");
});

test("an account can close at most 20 unknown request ids a day, so lookups cannot pile up records", async (t) => {
  const store = installFakeDb(t, {[`${PHOTO_JOB_CLOSURES}/u1`]: {day: today(), count: 19}});
  assert.deepEqual(await lookup({requestId: "req-00000101"}), {state: "unknown"});
  assert.equal(store.get(`${PHOTO_JOBS}/pj_u1_req-00000101`)?.state, "closed");
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.count, 20);
  assert.deepEqual(await lookup({requestId: "req-00000101"}), {state: "unknown"});
  await assert.rejects(() => lookup({requestId: "req-00000102"}), {code: "resource-exhausted"});
  assert.equal(store.has(`${PHOTO_JOBS}/pj_u1_req-00000102`), false);
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.count, 20);
});

test("a capped lookup stays retryable until a delayed create can be recovered", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200},
    [`${PHOTO_JOB_CLOSURES}/u1`]: {day: today(), count: 20},
  });
  let release!: () => void;
  let claimReached!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const entered = new Promise<void>((resolve) => {
    claimReached = resolve;
  });
  mockDeps(t);
  const transaction = db.runTransaction.bind(db);
  let first = true;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    if (first) {
      first = false;
      claimReached();
      await gate;
    }
    return transaction(callback);
  });
  const creating = run(await extendData());
  await entered;
  try {
    await assert.rejects(() => lookup({requestId: "req-00000001"}), {code: "resource-exhausted"});
    assert.equal(store.has(JOB), false);
  } finally {
    release();
    await creating;
  }
  const recovered = await lookup({requestId: "req-00000001"}) as Succeeded;
  assert.equal(recovered.state, "succeeded");
  assert.equal(recovered.imageUrl, OUT_URL);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
  assert.equal(coinTxCount(store), 1);
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.count, 20);
});

test("the closure cap rolls over by the server UTC day, not client-supplied fields", async (t) => {
  const yesterday = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
  const store = installFakeDb(t, {[`${PHOTO_JOB_CLOSURES}/u1`]: {day: yesterday, count: 20}});
  assert.deepEqual(await lookup({requestId: "req-00000101"}), {state: "unknown"});
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.day, today());
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.count, 1);

  store.set(`${PHOTO_JOB_CLOSURES}/u1`, {day: today(), count: 20});
  await assert.rejects(() => lookup({requestId: "req-00000102", day: yesterday, count: 0, uid: "u2"}),
    {code: "resource-exhausted"});
  assert.equal(store.get(`${PHOTO_JOB_CLOSURES}/u1`)?.count, 20);
  assert.equal(store.has(`${PHOTO_JOB_CLOSURES}/u2`), false);
  assert.equal(store.has(`${PHOTO_JOBS}/pj_u1_req-00000102`), false);
});

test("restyle with a missing, unknown or prototype styleId is refused before any charge", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const cases: Array<[string, Record<string, unknown>]> = [
    ["missing styleId", {...await restyleData(), styleId: undefined}],
    ["unknown styleId", await restyleData({styleId: "vaporwave"})],
    ["prototype styleId", await restyleData({styleId: "toString"})],
    ["prototype constructor", await restyleData({styleId: "constructor"})],
    ["prototype __proto__", await restyleData({styleId: "__proto__"})],
    ["null styleId", await restyleData({styleId: null})],
    ["object styleId", await restyleData({styleId: {id: "anime"}})],
    ["numeric styleId", await restyleData({styleId: 42})],
    ["extend with a styleId", await extendData({styleId: "anime"})],
    ["upscale with a styleId", await upscaleData({styleId: "anime"})],
    ["restyle with a placement", await restyleData({placement: {left: 0, top: 0, width: 1080, height: 2340}})],
  ];
  for (const [name, data] of cases) {
    await assert.rejects(() => run(data), {code: "invalid-argument"}, name);
    assert.equal(store.get("usersv2/u1")?.coins, 200, name);
    assert.equal(coinTxCount(store), 0, name);
    assert.equal([...store.keys()].filter((k) => k.startsWith(`${PHOTO_JOBS}/`)).length, 0, name);
  }
  assert.equal(deps.fal().length, 0);
});

test("restyle sends the photo to Seedream edit with the style prompt, charges 75, and crops the result to the target size",
  async (t) => {
    const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
    const deps = mockDeps(t);
    const fetch = photoDeps.fetch;
    const seedream = (await jpegOf(1024, 1024)).toString("base64");
    t.mock.method(photoDeps, "fetch", async (url: string, init: RequestInit) => {
      const response = await fetch(url, init);
      if (url !== FAL_RESTYLE) return response;
      return Response.json({images: [{url: `data:image/jpeg;base64,${seedream}`}]},
        {headers: {"x-fal-request-id": "req-abcdef12"}});
    });
    const result = await run(await restyleData()) as Succeeded;
    assert.equal(result.state, "succeeded");
    assert.equal(result.width, 1080);
    assert.equal(result.height, 2340);
    assert.deepEqual(await sizeOf(deps.stored[0]), {width: 1080, height: 2340});
    const post = deps.fal()[0];
    assert.ok(post);
    assert.equal(post.url, FAL_RESTYLE);
    assert.equal(post.method, "POST");
    assert.equal(post.headers["X-Fal-Store-IO"], "0");
    assert.ok((post.body.image_urls as string[])[0].startsWith("data:image/jpeg;base64,"));
    assert.deepEqual(post.body.image_size, {width: 1080, height: 2340});
    assert.equal(post.body.enable_safety_checker, true);
    assert.equal(post.body.sync_mode, true);
    assert.ok(String(post.body.prompt).includes("anime style"));
    assert.equal(store.get("usersv2/u1")?.coins, 125);
    assert.equal(store.get(CHARGE)?.delta, -75);
    assert.equal(store.get(JOB)?.mode, "restyle");
    assert.equal(store.get(JOB)?.styleId, "anime");
    assert.equal(store.get(JOB)?.model, "fal-ai/bytedance/seedream/v4/edit");
    const deletes = deps.calls.filter((c) => c.method === "DELETE");
    assert.equal(deletes.length, 1);
    assert.equal(deletes[0].url, FAL_DELETE);
  });

test("restyle price comes from the economy config, and Pro pays half rounded up", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}, [ECONOMY_CONFIG_DOC]: {spend: {photoRestyle: 51}}});
  mockDeps(t);
  try {
    assert.equal(((await run(await restyleData())) as Succeeded).cost, 51);
    assert.equal(store.get("usersv2/u1")?.coins, 149);
    store.set("usersv2/u1", {coins: 149, premium: true});
    assert.equal(((await run(await restyleData({requestId: "req-00000002"}))) as Succeeded).cost, 26);
    assert.equal(store.get("usersv2/u1")?.coins, 123);
    store.set(ECONOMY_CONFIG_DOC, {spend: {photoRestyle: 51}, proDiscountActions: []});
    resetEconomyCache();
    assert.equal(((await run(await restyleData({requestId: "req-00000003"}))) as Succeeded).cost, 51);
    assert.equal(store.get("usersv2/u1")?.coins, 72);
    assert.equal(store.get("coinTransactions/ctx_photoWallpaper_u1_req-00000003")?.delta, -51);
  } finally {
    resetEconomyCache();
  }
});

test("a restyle provider failure refunds once", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t, {falStatus: 500});
  const refundCount = () => [...store.keys()].filter((k) => k.startsWith("coinTransactions/ctx_photoWallpaperRefund_")).length;
  const first = await run(await restyleData()) as Failed;
  assert.equal(first.state, "failed");
  assert.equal(first.reason, "provider_error");
  assert.equal(first.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(refundCount(), 1);
  const second = await run(await restyleData()) as Failed;
  assert.equal(second.state, "failed");
  assert.equal(second.reason, "provider_error");
  assert.equal(second.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(refundCount(), 1);
  assert.equal(coinTxCount(store), 2);
  assert.equal(deps.fal().length, 1);
});

test("an unsafe restyle result fails as unsafe_output and refunds", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t, {safe: (call) => call === 2 ? {...SAFE, racy: "VERY_LIKELY"} : SAFE});
  const result = await run(await restyleData()) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.reason, "unsafe_output");
  assert.equal(result.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(deps.stored.length, 0);
});

test("the sweeper refunds a stale restyle job once", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 125},
    [CHARGE]: {delta: -75},
    [JOB]: {...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
      mode: "restyle", model: "fal-ai/bytedance/seedream/v4/edit", styleId: "anime"},
  });
  assert.equal(await sweepStalePhotoJobsOnce(), 1);
  assert.equal(store.get(JOB)?.state, "failed");
  assert.equal(store.get(JOB)?.reason, "timeout");
  assert.equal(store.get(JOB)?.refunded, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(store.get(REFUND)?.delta, 75);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
});

test("parseStyleId and restylePrompt read the Restyle style map", () => {
  assert.equal(parseStyleId("restyle", "3d render"), "3d render");
  assert.ok(restylePrompt("3d render").includes("clay-like"));
});

test("the Restyle prompt names no device, so the model does not draw a phone frame", () => {
  for (const style of PHOTO_STYLES.keys()) {
    const prompt = restylePrompt(style);
    assert.ok(!/wallpaper|phone screen|mockup/i.test(prompt), style);
    assert.ok(prompt.includes("Do not add a phone, a device frame, a border or text."), style);
  }
});

test("Seedream minimum-area output is cropped to a small phone target before SafeSearch and storage", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 200}});
  const deps = mockDeps(t);
  const fetch = photoDeps.fetch;
  const output = (await jpegOf(760, 1216)).toString("base64");
  t.mock.method(photoDeps, "fetch", async (url: string, init: RequestInit) => {
    const response = await fetch(url, init);
    return url === FAL_RESTYLE ? Response.json({images: [{url: `data:image/jpeg;base64,${output}`}]},
      {headers: {"x-fal-request-id": "req-abcdef12"}}) : response;
  });
  const checked: Buffer[] = [];
  t.mock.method(photoDeps, "safeSearch", async (jpeg: Buffer) => {
    checked.push(jpeg);
    assert.equal(deps.stored.length, 0);
    return SAFE;
  });
  const data = await restyleData({targetWidth: 720, targetHeight: 1152, cost: 0, price: 0});
  const result = await run(data) as Succeeded;
  assert.equal(result.state, "succeeded");
  assert.equal(result.cost, 75);
  assert.deepEqual(deps.fal()[0].body.image_size, {width: 720, height: 1152});
  assert.equal(checked.length, 2);
  assert.deepEqual(await sizeOf(checked[1]), {width: 720, height: 1152});
  assert.deepEqual(deps.stored[0], checked[1]);
  assert.deepEqual(await run(data), result);
  assert.equal(deps.fal().length, 1);
  assert.equal(coinTxCount(store), 1);
});

test("Seedream empty, invalid and oversized results refund once and clean provider payloads", async (t) => {
  const oversized = Buffer.alloc(30 * 1024 * 1024 + 1);
  const cases: Array<[string, unknown, Buffer | undefined]> = [
    ["empty images", {images: []}, undefined],
    ["null image", {images: [null]}, undefined],
    ["non-HTTPS URL", {images: [{url: "http://cdn.test/result.jpg"}]}, undefined],
    ["oversized inline", {images: [{url: `data:image/jpeg;base64,${oversized.toString("base64")}`}]}, undefined],
    ["oversized download", {images: [{url: "https://cdn.test/result.jpg"}]}, oversized],
  ];
  for (const [name, payload, download] of cases) {
    await t.test(name, async (s) => {
      const store = installFakeDb(s, {"usersv2/u1": {coins: 200}});
      const deps = mockDeps(s);
      const fetch = photoDeps.fetch;
      s.mock.method(photoDeps, "fetch", async (url: string, init: RequestInit) => {
        if (download && url === "https://cdn.test/result.jpg") return new Response(new Uint8Array(download));
        const response = await fetch(url, init);
        return url === FAL_RESTYLE ? Response.json(payload,
          {headers: {"x-fal-request-id": "req-abcdef12"}}) : response;
      });
      const removed: string[] = [];
      s.mock.method(photoDeps, "remove", async (key: string) => {
        removed.push(key);
      });
      const data = await restyleData();
      const result = await run(data) as Failed;
      assert.equal(result.state, "failed");
      assert.equal(result.reason, "provider_error");
      assert.equal(result.refunded, true);
      assert.equal(store.get("usersv2/u1")?.coins, 200);
      assert.equal(store.get(JOB)?.cleanupPending, false);
      assert.equal(store.get(JOB)?.falCleanupPending, false);
      assert.deepEqual(removed, [store.get(JOB)?.resultKey]);
      assert.equal(deps.calls.filter((c) => c.url === FAL_DELETE).length, 1);
      assert.equal(deps.stored.length, 0);
      assert.deepEqual(await run(data), result);
      assert.equal(coinTxCount(store), 2);
    });
  }
});

test("a recovered stale restyle refunds once across lookup, replay and sweeping", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 125},
    [CHARGE]: {delta: -75},
    [JOB]: {...runningJob(admin.firestore.Timestamp.fromMillis(Date.now() - 11 * MINUTE)),
      mode: "restyle", model: "fal-ai/bytedance/seedream/v4/edit", styleId: "anime"},
  });
  const deps = mockDeps(t);
  const result = await lookup({requestId: "req-00000001"}) as Failed;
  assert.equal(result.state, "failed");
  assert.equal(result.mode, "restyle");
  assert.equal(result.refunded, true);
  assert.deepEqual(await run(await restyleData()), result);
  assert.equal(await sweepStalePhotoJobsOnce(), 0);
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(coinTxCount(store), 2);
  assert.equal(deps.fal().length, 0);
});
