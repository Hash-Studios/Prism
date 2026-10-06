import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {isViewCooldownActive, parseViews, recordWallpaperView} from "../viewStats";

test("view cooldown blocks only the first hour", () => {
  assert.equal(isViewCooldownActive(1_000, 1_000 + 30 * 60 * 1000), true);
  assert.equal(isViewCooldownActive(1_000, 1_000 + 60 * 60 * 1000), false);
  assert.equal(isViewCooldownActive(undefined, 1_000), false);
});

test("view counts parse numbers, numeric strings and junk", () => {
  assert.equal(parseViews(7), 7);
  assert.equal(parseViews("12"), 12);
  assert.equal(parseViews(undefined), 0);
  assert.equal(parseViews("many"), 0);
});

type Write = {path: string; data: Record<string, unknown>};

function store(t: TestContext, docs: Record<string, Record<string, unknown>>) {
  const writes: Write[] = [];
  t.mock.method(db, "runTransaction", () => {
    throw new Error("view counting must not use a transaction");
  });
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => ({
      get: async () => ({data: () => docs[`${name}/${id}`]}),
      set: async (data: Record<string, unknown>) => writes.push({path: `${name}/${id}`, data}),
    }),
  }));
  return writes;
}

const call = (wallId = "w1") => recordWallpaperView.run({
  auth: {uid: "u1"}, data: {wallId},
} as unknown as Parameters<typeof recordWallpaperView.run>[0]);

test("a view increments the counter atomically and stamps a rate doc that expires", async (t) => {
  const writes = store(t, {"wallpaper_stats/W1": {views: 4}});
  const before = Date.now();
  const result = await call();
  assert.equal(result.views, 5);
  const stats = writes.find((w) => w.path === "wallpaper_stats/W1");
  assert.ok(stats);
  assert.notEqual(typeof stats.data.views, "number", "a FieldValue.increment, not a read-modify-write number");
  const rate = writes.find((w) => w.path === "viewRate/u1_wallpaper_stats_W1");
  assert.ok(rate);
  const expireAt = (rate.data.expireAt as admin.firestore.Timestamp).toMillis();
  assert.ok(expireAt >= before + 24 * 60 * 60 * 1000 - 1000);
});

test("a repeat view inside the cooldown returns the count and writes nothing", async (t) => {
  const writes = store(t, {
    "wallpaper_stats/W1": {views: 4},
    "viewRate/u1_wallpaper_stats_W1": {lastAt: admin.firestore.Timestamp.now()},
  });
  assert.equal((await call()).views, 4);
  assert.deepEqual(writes, []);
});

test("a legacy string counter is rewritten as a number", async (t) => {
  const writes = store(t, {"wallpaper_stats/W1": {views: "9"}});
  assert.equal((await call()).views, 10);
  assert.equal(writes.find((w) => w.path === "wallpaper_stats/W1")?.data.views, 10);
});
