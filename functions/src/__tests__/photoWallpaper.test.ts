import assert from "node:assert/strict";
import type {TestContext} from "node:test";
import test from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {
  createPhotoWallpaper,
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
function mockDeps(t: TestContext, opts: {falStatus?: number; safe?: (call: number) => Record<string, unknown>} = {}) {
  const calls: Call[] = [];
  const stored: Buffer[] = [];
  const counts = {safe: 0};
  const output = jpegOf(1080, 2340);
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
    if (url === FAL_DELETE && method === "DELETE") return new Response(null, {status: 200});
    throw new Error(`unexpected fetch ${method} ${url}`);
  });
  t.mock.method(photoDeps, "store", async (jpeg: Buffer) => {
    stored.push(jpeg);
    return {url: OUT_URL, key: "photo-walls/x.jpg"};
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
  // The input photo is never stored. Only the result is stored, once, at the target size.
  assert.equal(deps.stored.length, 1);
  assert.deepEqual(await sizeOf(deps.stored[0]), {width: 1080, height: 2340});
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
