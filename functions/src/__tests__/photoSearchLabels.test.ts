import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
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

test("the 21st search of the day is refused", async (t) => {
  const store = installFakeDb(t, {[RATE_DOC]: {day: today(), count: MAX_PHOTO_SEARCHES_PER_DAY, results: {}}});
  const mock = t.mock.method(wallCategory, "detectLabelsInImage", async () => ["Sky"]);
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "resource-exhausted"});
  assert.equal(mock.mock.callCount(), 0);
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

test("a Vision failure gives the count back", async (t) => {
  const store = installFakeDb(t);
  t.mock.method(wallCategory, "detectLabelsInImage", async () => {
    throw new Error("boom");
  });
  await assert.rejects(() => call({image, requestId: "req-00000001"}), {code: "unavailable"});
  assert.equal(store.get(RATE_DOC)?.count, 0);
  assert.equal("req-00000001" in (store.get(RATE_DOC)?.results as Record<string, unknown>), false);
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
