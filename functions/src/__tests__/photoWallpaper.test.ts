import assert from "node:assert/strict";
import type {TestContext} from "node:test";
import test from "node:test";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import sharp from "sharp";
import {db} from "../common";
import {
  createPhotoWallpaper,
  failPhotoJob,
  finishImage,
  isPhotoSafe,
  normalizePhoto,
  PHOTO_JOBS,
  photoDeps,
  PhotoJobResult,
  planPhotoJob,
  sweepStalePhotoJobsOnce,
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

/** Mocks every outside dependency. The fal output is a 1080x2340 JPEG unless `falStatus` makes fal fail. */
function mockDeps(t: TestContext, opts: {falStatus?: number; deleteStatus?: number; deleteException?: string;
  safe?: (call: number) => Record<string, unknown>} = {}) {
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
    if (url === FAL_DELETE && method === "DELETE") {
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
    "usersv2/u1": {coins: 125},
    [JOB]: runningJob(admin.firestore.Timestamp.now()),
  });
  const deps = mockDeps(t);
  await assert.rejects(async () => run(await extendData()), {code: "aborted"});
  assert.equal(deps.fal().length, 0);
  assert.equal(store.get("usersv2/u1")?.coins, 125);
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
