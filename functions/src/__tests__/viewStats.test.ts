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
  const versions: Record<string, number> = {};
  const tick = () => new Promise((resolve) => setImmediate(resolve));
  const lost = (code: number) => Object.assign(new Error("claim lost"), {code});
  t.mock.method(admin.firestore.FieldValue, "increment", (n: number) => ({increment: n}));
  const applyStats = (path: string, data: Record<string, unknown>) => {
    const views = data.views as {increment?: number} | number;
    const current = docs[path]?.views;
    const base = typeof current === "number" ? current : 0;
    const next = typeof views === "object" ? base + (views.increment ?? 0) : views;
    docs[path] = {...docs[path], views: next};
    writes.push({path, data});
  };
  t.mock.method(db, "runTransaction", async (fn: (tx: unknown) => Promise<unknown>) => fn({
    get: async (ref: {path: string}) => ({data: () => docs[ref.path]}),
    set: (ref: {path: string}, data: Record<string, unknown>) => applyStats(ref.path, data),
  }));
  t.mock.method(db, "collection", (name: string) => ({
    doc: (id: string) => {
      const path = `${name}/${id}`;
      return {
        path,
        get: async () => {
          const data = docs[path];
          const updateTime = data ? {version: versions[path] ?? 0} : undefined;
          await tick();
          return {exists: data !== undefined, data: () => data, updateTime};
        },
        set: async (data: Record<string, unknown>) => {
          if (name.endsWith("_stats")) applyStats(path, data);
          else writes.push({path, data});
        },
        create: async (data: Record<string, unknown>) => {
          if (docs[path]) throw lost(6);
          docs[path] = data;
          versions[path] = 1;
          writes.push({path, data});
        },
        update: async (data: Record<string, unknown>, precondition: {lastUpdateTime: {version: number}}) => {
          if (!docs[path]) throw lost(5);
          if ((versions[path] ?? 0) !== precondition.lastUpdateTime.version) throw lost(9);
          docs[path] = data;
          versions[path] = (versions[path] ?? 0) + 1;
          writes.push({path, data});
        },
      };
    },
  }));
  return writes;
}

const call = (wallId = "w1", uid = "u1") => recordWallpaperView.run({
  auth: {uid}, data: {wallId},
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

const statsWrites = (writes: Write[]) => writes.filter((w) => w.path === "wallpaper_stats/W1");

test("two concurrent first views from distinct users on a new counter end at 2", async (t) => {
  const docs: Record<string, Record<string, unknown>> = {};
  store(t, docs);
  await Promise.all([call("w1", "u1"), call("w1", "u2")]);
  assert.equal(docs["wallpaper_stats/W1"].views, 2);
});

test("two concurrent distinct viewers of a numeric counter end at +2", async (t) => {
  const docs: Record<string, Record<string, unknown>> = {"wallpaper_stats/W1": {views: 4}};
  store(t, docs);
  await Promise.all([call("w1", "u1"), call("w1", "u2")]);
  assert.equal(docs["wallpaper_stats/W1"].views, 6);
});

test("ten concurrent first views from one user increment once", async (t) => {
  const writes = store(t, {"wallpaper_stats/W1": {views: 4}});
  const results = await Promise.all(Array.from({length: 10}, () => call()));
  assert.equal(statsWrites(writes).length, 1);
  assert.deepEqual(results.map((r) => r.views).sort(), [4, 4, 4, 4, 4, 4, 4, 4, 4, 5]);
});

test("ten concurrent views after the cooldown expires increment once", async (t) => {
  const old = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 60 * 60 * 1000);
  const writes = store(t, {
    "wallpaper_stats/W1": {views: 4},
    "viewRate/u1_wallpaper_stats_W1": {lastAt: old},
  });
  await Promise.all(Array.from({length: 10}, () => call()));
  assert.equal(statsWrites(writes).length, 1);
});

test("a wallpaper view also counts in the daily doc that expires, and a repeat view does not", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: new Date("2026-01-02T10:00:00Z")});
  const writes = store(t, {});
  await call();
  await call();
  const daily = writes.filter((w) => w.path === "wallpaper_stats_daily/20260102_W1");
  assert.equal(daily.length, 1);
  assert.equal(daily[0].data.wallId, "W1");
  assert.equal(daily[0].data.day, "20260102");
  assert.deepEqual(daily[0].data.views, {increment: 1});
  assert.equal((daily[0].data.expireAt as admin.firestore.Timestamp).toMillis(), Date.now() + 14 * 86_400_000);
});
