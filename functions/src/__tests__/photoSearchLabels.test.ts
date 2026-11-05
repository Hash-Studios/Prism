import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {logger} from "firebase-functions/v2";
import * as wallCategory from "../wallCategory";
import {MAX_PHOTO_BYTES, MAX_PHOTO_SEARCHES_PER_DAY, PHOTO_SEARCH_RATE, parsePhoto, photoSearchLabels} from "../photoSearchLabels";
import {installFakeDb} from "./fakeDb";

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1]);
const image = JPEG.toString("base64");
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const today = () => new Date().toISOString().slice(0, 10);
const RATE_DOC = `${PHOTO_SEARCH_RATE}/u1`;

const call = (data: Record<string, unknown>, auth: unknown = {uid: "u1", token: {firebase: {sign_in_provider: "google.com"}}}) =>
  photoSearchLabels.run({auth, data} as unknown as Parameters<typeof photoSearchLabels.run>[0]);

async function waitUntil(predicate: () => boolean): Promise<void> {
  for (let i = 0; i < 10 && !predicate(); i++) await new Promise((resolve) => setImmediate(resolve));
  assert.ok(predicate(), "condition did not become true");
}

test("no auth is refused", async (t) => {
  installFakeDb(t);
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  // `call` would replace an undefined auth with its default signed-in user, so send a request with no auth at all.
  await assert.rejects(() => photoSearchLabels.run({data: {image, requestId: "req-00000001"}} as unknown as
    Parameters<typeof photoSearchLabels.run>[0]), {code: "unauthenticated"});
  await assert.rejects(() => call({image, requestId: "req-00000001"},
    {uid: "a", token: {firebase: {sign_in_provider: "anonymous"}}}), {code: "unauthenticated"});
  assert.equal(mock.mock.callCount(), 0);
});

test("a bad requestId is refused", async (t) => {
  installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  await assert.rejects(() => call({image, requestId: "short"}), {code: "invalid-argument"});
  await assert.rejects(() => call({image, requestId: 123}), {code: "invalid-argument"});
});

test("an oversize image is refused before any count or Vision call", async (t) => {
  const store = installFakeDb(t);
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  const big = Buffer.alloc(MAX_PHOTO_BYTES + 1, 0xff).toString("base64");
  await assert.rejects(() => call({image: big, requestId: "req-00000001"}), {code: "invalid-argument"});
  assert.equal(mock.mock.callCount(), 0);
  assert.equal(store.get(RATE_DOC), undefined);
});

test("a non-image is refused", async (t) => {
  installFakeDb(t);
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  await assert.rejects(() => call({image: Buffer.from("hello world!").toString("base64"), requestId: "req-00000001"}),
    {code: "invalid-argument"});
  await assert.rejects(() => call({image: "not base64!!", requestId: "req-00000001"}), {code: "invalid-argument"});
  assert.equal(mock.mock.callCount(), 0);
});

test("labels come back, at most 5, with the mapped category", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () =>
    ["Sky", "Sunset", "Cloud", "Afterglow", "Evening", "Horizon", "Dusk"]);
  const result = await call({image, requestId: "req-00000001"});
  const labels = ["Sky", "Sunset", "Cloud", "Afterglow", "Evening"];
  assert.deepEqual(result, {labels, category: "Nature", remaining: 19});
  assert.equal(store.get(RATE_DOC)?.count, 1);
  assert.equal(store.get(RATE_DOC)?.day, today());
  assert.deepEqual((store.get(RATE_DOC)?.results as Record<string, unknown>)["req-00000001"],
    {labels, category: "Nature"});
});

test("a General category comes back as null", async (t) => {
  installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Qwerty"]);
  const result = await call({image, requestId: "req-00000001"}) as {category: string | null};
  assert.equal(result.category, null);
});

test("a replayed requestId returns the same labels without a new count or Vision call", async (t) => {
  const store = installFakeDb(t);
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky", "Sunset"]);
  const first = await call({image, requestId: "req-00000001"});
  const second = await call({image, requestId: "req-00000001"});
  assert.deepEqual(second, first);
  assert.equal(mock.mock.callCount(), 1);
  assert.equal(store.get(RATE_DOC)?.count, 1);
});

test("a result-cache write failure still returns the counted Vision result", async (t) => {
  const store = installFakeDb(t, {}, undefined, {failCommitAt: 2});
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  const warn = t.mock.method(logger, "warn", () => undefined);
  const result = await call({image, requestId: "req-00000001"});
  assert.deepEqual(result, {labels: ["Sky"], category: "Nature", remaining: 19});
  assert.equal(store.get(RATE_DOC)?.count, 1);
  const slot = (store.get(RATE_DOC)?.results as Record<string, {pending?: boolean; at?: unknown}>)["req-00000001"];
  assert.equal(slot.pending, true);
  assert.equal(typeof slot.at, "number");
  const log = JSON.stringify(warn.mock.calls[0]?.arguments ?? []);
  assert.equal(log.includes(image), false);
});

test("the 21st search of the day is refused", async (t) => {
  const store = installFakeDb(t, {[RATE_DOC]: {day: today(), count: MAX_PHOTO_SEARCHES_PER_DAY, results: {}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "resource-exhausted"});
  assert.equal(mock.mock.callCount(), 0);
  assert.equal(store.get(RATE_DOC)?.count, MAX_PHOTO_SEARCHES_PER_DAY);
});

test("a claim that reaches its transaction after UTC midnight uses the new day", async (t) => {
  const tomorrow = "2026-11-06";
  const store = installFakeDb(t, {[RATE_DOC]: {day: tomorrow, count: MAX_PHOTO_SEARCHES_PER_DAY, results: {}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  let now = Date.parse("2026-11-05T23:59:59.900Z");
  t.mock.method(Date, "now", () => now);
  const pending = call({image, requestId: "req-00000001"});
  now = Date.parse("2026-11-06T00:00:00.100Z");
  await assert.rejects(() => pending, {code: "resource-exhausted"});
  assert.equal(mock.mock.callCount(), 0);
  assert.equal(store.get(RATE_DOC)?.day, tomorrow);
  assert.equal(store.get(RATE_DOC)?.count, MAX_PHOTO_SEARCHES_PER_DAY);
});

test("an older Vision success or failure cannot change the next day's rate document", async (t) => {
  for (const outcome of ["success", "failure"] as const) {
    await t.test(outcome, async (st) => {
      const store = installFakeDb(st);
      let now = Date.parse("2026-11-05T23:59:59.900Z");
      st.mock.method(Date, "now", () => now);
      let finishFirst: ((labels: string[]) => void) | undefined;
      let failFirst: ((error: Error) => void) | undefined;
      const firstVision = new Promise<string[]>((resolve, reject) => {
        finishFirst = resolve;
        failFirst = reject;
      });
      let calls = 0;
      st.mock.method(wallCategory, "detectLabelsInImage", async () => ++calls === 1 ? firstVision : ["New"]);
      const first = call({image, requestId: "req-00000001"});
      await waitUntil(() => calls === 1);
      now = Date.parse("2026-11-06T00:00:00.100Z");
      const nextDay = await call({image, requestId: "req-00000002"});
      if (outcome === "success") {
        finishFirst?.(["Old"]);
        await first;
      } else {
        failFirst?.(new Error("old-day call failed"));
        await assert.rejects(() => first, {code: "unavailable"});
      }
      assert.equal(store.get(RATE_DOC)?.day, "2026-11-06");
      assert.equal(store.get(RATE_DOC)?.count, 1);
      assert.deepEqual((store.get(RATE_DOC)?.results as Record<string, unknown>)["req-00000002"],
        {labels: nextDay.labels, category: nextDay.category});
      assert.equal("req-00000001" in (store.get(RATE_DOC)?.results as Record<string, unknown>), false);
    });
  }
});

test("concurrent different requestIds cannot exceed the daily cap", async (t) => {
  const store = installFakeDb(t, {[RATE_DOC]: {day: today(), count: MAX_PHOTO_SEARCHES_PER_DAY - 1, results: {}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  const outcomes = await Promise.allSettled([
    call({image, requestId: "req-00000001"}),
    call({image, requestId: "req-00000002"}),
  ]);
  assert.equal(outcomes.filter((outcome) => outcome.status === "fulfilled").length, 1);
  assert.equal(mock.mock.callCount(), 1);
  assert.equal(store.get(RATE_DOC)?.count, MAX_PHOTO_SEARCHES_PER_DAY);
});

test("the cap cannot be bypassed with fresh requestIds", async (t) => {
  installFakeDb(t);
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  for (let i = 1; i <= MAX_PHOTO_SEARCHES_PER_DAY; i++) {
    await call({image, requestId: `req-000000${String(i).padStart(2, "0")}`});
  }
  await assert.rejects(() => call({image, requestId: "req-00000021"}), {code: "resource-exhausted"});
  assert.equal(mock.mock.callCount(), MAX_PHOTO_SEARCHES_PER_DAY);
});

test("yesterday's count does not block today", async (t) => {
  const store = installFakeDb(t, {[RATE_DOC]: {day: "2000-01-01", count: MAX_PHOTO_SEARCHES_PER_DAY,
    results: {"req-00000001": {labels: ["Old"], category: null}}}});
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  const result = await call({image, requestId: "req-00000001"}) as {labels: string[]};
  assert.notDeepEqual(result.labels, ["Old"]);
  assert.deepEqual(result.labels, ["Sky"]);
  assert.equal(store.get(RATE_DOC)?.count, 1);
});

test("a Vision failure still counts and frees the request", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () => {
    throw new Error("boom");
  });
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "unavailable"});
  assert.equal(store.get(RATE_DOC)?.count, 1);
  assert.equal("req-00000001" in (store.get(RATE_DOC)?.results as Record<string, unknown>), false);
});

test("Vision failures cannot be used to get more than 20 Vision calls", async (t) => {
  installFakeDb(t);
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => {
    throw new Error("boom");
  });
  for (let i = 1; i <= MAX_PHOTO_SEARCHES_PER_DAY; i++) {
    await assert.rejects(() => call({image, requestId: `req-fail-${String(i).padStart(4, "0")}`}), {code: "unavailable"});
  }
  await assert.rejects(() => call({image, requestId: "req-fail-0021"}), {code: "resource-exhausted"});
  assert.equal(mock.mock.callCount(), MAX_PHOTO_SEARCHES_PER_DAY);
});

test("a stale running request counts again when it is retried", async (t) => {
  const store = installFakeDb(t, {[RATE_DOC]: {day: today(), count: 1,
    results: {"req-00000001": {pending: true, at: Date.now() - 120_000}}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  const result = await call({image, requestId: "req-00000001"});
  assert.deepEqual(result, {labels: ["Sky"], category: "Nature", remaining: 18});
  assert.equal(store.get(RATE_DOC)?.count, 2);
  assert.equal(mock.mock.callCount(), 1);
});

test("a stale running request is refused at the cap", async (t) => {
  installFakeDb(t, {[RATE_DOC]: {day: today(), count: MAX_PHOTO_SEARCHES_PER_DAY,
    results: {"req-00000001": {pending: true, at: Date.now() - 120_000}}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "resource-exhausted"});
  assert.equal(mock.mock.callCount(), 0);
});

test("an older successful attempt cannot overwrite its stale-reclaimed request", async (t) => {
  const store = installFakeDb(t);
  let now = Date.parse("2026-11-05T12:00:00.000Z");
  t.mock.method(Date, "now", () => now);
  let finishFirst: ((labels: string[]) => void) | undefined;
  const firstVision = new Promise<string[]>((resolve) => {
    finishFirst = resolve;
  });
  let finishSecond: ((labels: string[]) => void) | undefined;
  const secondVision = new Promise<string[]>((resolve) => {
    finishSecond = resolve;
  });
  let calls = 0;
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ++calls === 1 ? firstVision : secondVision);
  const first = call({image, requestId: "req-00000001"});
  await waitUntil(() => calls === 1);
  now += 120_000;
  const second = call({image, requestId: "req-00000001"});
  await waitUntil(() => calls === 2);
  finishFirst?.(["Old"]);
  await first;
  assert.deepEqual((store.get(RATE_DOC)?.results as Record<string, unknown>)["req-00000001"],
    {pending: true, at: now});
  finishSecond?.(["New"]);
  const secondResult = await second;
  assert.deepEqual((store.get(RATE_DOC)?.results as Record<string, unknown>)["req-00000001"],
    {labels: ["New"], category: null});
  assert.deepEqual(await call({image, requestId: "req-00000001"}), secondResult);
});

test("an older failed attempt cannot clear its stale-reclaimed request", async (t) => {
  const store = installFakeDb(t);
  let now = Date.parse("2026-11-05T12:00:00.000Z");
  t.mock.method(Date, "now", () => now);
  let failFirst: ((error: Error) => void) | undefined;
  let finishSecond: ((labels: string[]) => void) | undefined;
  const firstVision = new Promise<string[]>((_, reject) => {
    failFirst = reject;
  });
  const secondVision = new Promise<string[]>((resolve) => {
    finishSecond = resolve;
  });
  let calls = 0;
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ++calls === 1 ? firstVision : secondVision);
  const first = call({image, requestId: "req-00000001"});
  await waitUntil(() => calls === 1);
  now += 120_000;
  const second = call({image, requestId: "req-00000001"});
  await waitUntil(() => calls === 2);
  failFirst?.(new Error("first attempt failed"));
  await assert.rejects(() => first, {code: "unavailable"});
  assert.deepEqual((store.get(RATE_DOC)?.results as Record<string, unknown>)["req-00000001"],
    {pending: true, at: now});
  finishSecond?.(["New"]);
  await second;
  assert.deepEqual((store.get(RATE_DOC)?.results as Record<string, unknown>)["req-00000001"],
    {labels: ["New"], category: null});
});

test("a Vision failure logs no image data or error payload", async (t) => {
  installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () => {
    throw Object.assign(new Error(`Vision failed for ${image} derivative-thumbnail`),
      {request: {image: {content: image}}});
  });
  const warn = t.mock.method(logger, "warn", () => undefined);
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "unavailable"});
  assert.equal(warn.mock.callCount(), 1);
  const log = JSON.stringify(warn.mock.calls[0].arguments);
  assert.equal(log.includes(image), false);
  assert.equal(log.includes("derivative-thumbnail"), false);
});

test("inline photo Vision calls disable retries and fit within the callable timeout", async (t) => {
  const prototype = ImageAnnotatorClient.prototype as unknown as Record<string, (...args: unknown[]) => unknown>;
  t.mock.method(prototype, "annotateImage", async () =>
    [{labelAnnotations: [{description: "Sky", score: 0.9}]}]);
  const annotate = t.mock.method(prototype, "batchAnnotateImages", async () =>
    [{responses: [{labelAnnotations: [{description: "Sky", score: 0.9}]}]}]);
  const labels = await wallCategory.detectLabelsInImage(Buffer.from("jpeg"));
  assert.deepEqual(labels, ["Sky"]);
  assert.equal(annotate.mock.callCount(), 1);
  const [request, options] = annotate.mock.calls[0].arguments;
  assert.deepEqual(request, {requests: [{image: {content: Buffer.from("jpeg")},
    features: [{type: "LABEL_DETECTION", maxResults: 10}]}]});
  assert.deepEqual(options, {retry: null, timeout: 20_000});
});

test("a Vision response error is unavailable, counted, and not stored or logged", async (t) => {
  const store = installFakeDb(t);
  const prototype = ImageAnnotatorClient.prototype as unknown as Record<string, (...args: unknown[]) => unknown>;
  t.mock.method(prototype, "annotateImage", async () =>
    [{error: {code: 3, message: `request failed ${image} derivative-thumbnail`}}]);
  t.mock.method(prototype, "batchAnnotateImages", async () =>
    [{responses: [{error: {code: 3, message: `request failed ${image} derivative-thumbnail`}}]}]);
  const warn = t.mock.method(logger, "warn", () => undefined);
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "unavailable"});
  assert.equal(store.get(RATE_DOC)?.count, 1);
  assert.equal("req-00000001" in (store.get(RATE_DOC)?.results as Record<string, unknown>), false);
  const log = JSON.stringify(warn.mock.calls[0]?.arguments ?? []);
  assert.equal(log.includes(image), false);
  assert.equal(log.includes("derivative-thumbnail"), false);
});

test("a request still running is refused", async (t) => {
  const store = installFakeDb(t, {[RATE_DOC]: {day: today(), count: 1,
    results: {"req-00000001": {pending: true, at: Date.now()}}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "aborted"});
  assert.equal(mock.mock.callCount(), 0);
  assert.equal(store.get(RATE_DOC)?.count, 1);
});

test("nothing about the image is stored", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  // The admin namespace has no `storage` member, so t.mock.method cannot wrap it; define the trap directly.
  Object.defineProperty(admin, "storage", {configurable: true, get: () => {
    throw new Error("storage must not be used");
  }});
  t.after(() => {
    delete (admin as unknown as Record<string, unknown>).storage;
  });
  await assert.doesNotReject(() => call({image, requestId: "req-00000001"}));
  const dump = JSON.stringify([...store.entries()]);
  assert.equal(dump.includes(image), false);
  assert.equal(dump.includes("image"), false);
  assert.deepEqual(Object.keys(store.get(RATE_DOC) ?? {}).sort(), ["count", "day", "expireAt", "results"]);
});

test("parsePhoto accepts PNG and JPEG", () => {
  const png = parsePhoto(PNG.toString("base64"));
  assert.ok(Buffer.isBuffer(png));
  assert.equal(png[0], 0x89);
  const jpeg = parsePhoto(image);
  assert.equal(jpeg[0], 0xff);
});
