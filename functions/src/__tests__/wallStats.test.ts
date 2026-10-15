import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {favouriteDelta, onFavouriteWritten, recordWallpaperAction} from "../wallStats";
import {installFakeDb} from "./fakeDb";

const DAY = "20260102";
const NOW = new Date("2026-01-02T10:00:00Z");

const call = (data: Record<string, unknown>, uid: string | null = "u1") => recordWallpaperAction.run({
  auth: uid ? {uid} : undefined, data,
} as unknown as Parameters<typeof recordWallpaperAction.run>[0]);

test("an action needs a signed-in caller, a valid wall id and a known action", async (t) => {
  installFakeDb(t);
  await assert.rejects(() => call({wallId: "w1", action: "set"}, null), {code: "unauthenticated"});
  await assert.rejects(() => call({wallId: "bad/id", action: "set"}), {code: "invalid-argument"});
  await assert.rejects(() => call({wallId: "w1", action: "view"}), {code: "invalid-argument"});
  await assert.rejects(() => call({wallId: "w1", action: "constructor"}), {code: "invalid-argument"});
  await assert.rejects(() => call({wallId: "w1"}), {code: "invalid-argument"});
});

test("each action adds to its own counter, the daily doc and the event time", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"wallpaper_stats/W1": {views: 9, downloads: 4}});
  assert.deepEqual(await call({wallId: "w1", action: "download"}), {counted: true});
  assert.deepEqual(await call({wallId: "w1", action: "set"}), {counted: true});
  assert.deepEqual(await call({wallId: "w1", action: "share"}), {counted: true});

  const stats = store.get("wallpaper_stats/W1");
  assert.equal(stats?.views, 9);
  assert.equal(stats?.downloads, 5);
  assert.equal(stats?.sets, 1);
  assert.equal(stats?.shares, 1);
  assert.equal((stats?.lastEventAt as admin.firestore.Timestamp).toMillis(), NOW.getTime());

  const daily = store.get(`wallpaper_stats_daily/${DAY}_W1`);
  assert.equal(daily?.wallId, "W1");
  assert.equal(daily?.day, DAY);
  assert.equal(daily?.downloads, 1);
  assert.equal(daily?.sets, 1);
  assert.equal(daily?.shares, 1);
  assert.equal((daily?.expireAt as admin.firestore.Timestamp).toMillis(), NOW.getTime() + 14 * 86_400_000);
});

test("the same user and action count once per 24 hours, and the rate doc expires", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t);
  assert.deepEqual(await call({wallId: "w1", action: "set"}), {counted: true});
  assert.deepEqual(await call({wallId: "w1", action: "set"}), {counted: false});
  assert.equal(store.get("wallpaper_stats/W1")?.sets, 1);
  const rate = store.get("wallActionRate/u1_W1_set");
  assert.equal((rate?.expireAt as admin.firestore.Timestamp).toMillis(), NOW.getTime() + 86_400_000);

  // Another action, another user and another wall each count on their own.
  assert.equal((await call({wallId: "w1", action: "download"})).counted, true);
  assert.equal((await call({wallId: "w1", action: "set"}, "u2")).counted, true);
  assert.equal((await call({wallId: "w2", action: "set"})).counted, true);
  assert.equal(store.get("wallpaper_stats/W1")?.sets, 2);

  t.mock.timers.setTime(NOW.getTime() + 24 * 3_600_000 + 1_000);
  assert.deepEqual(await call({wallId: "w1", action: "set"}), {counted: true});
  assert.equal(store.get("wallpaper_stats/W1")?.sets, 3);
});

test("two concurrent calls of one user count once", async (t) => {
  const store = installFakeDb(t);
  const results = await Promise.all([call({wallId: "w1", action: "share"}), call({wallId: "w1", action: "share"})]);
  assert.equal(results.filter((r) => r.counted).length, 1);
  assert.equal(store.get("wallpaper_stats/W1")?.shares, 1);
});

test("favouriteDelta is +1 on create, -1 on delete and 0 on update", () => {
  assert.equal(favouriteDelta(undefined, {id: "a"}), 1);
  assert.equal(favouriteDelta({id: "a"}, undefined), -1);
  assert.equal(favouriteDelta({id: "a"}, {id: "a", x: 1}), 0);
  assert.equal(favouriteDelta(undefined, undefined), 0);
});

const favEvent = (before: unknown, after: unknown, wallId = "w1") => onFavouriteWritten.run({
  params: {uid: "u1", wallId},
  data: {before: {data: () => before}, after: {data: () => after}},
} as unknown as Parameters<typeof onFavouriteWritten.run>[0]);

test("favourites add to favs, never take it below 0, and ignore other providers", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"wallpaper_stats/W1": {favs: 1}});
  const fav = {id: "w1", provider: "Prism"};
  await favEvent(undefined, fav);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);

  await favEvent(fav, undefined);
  await favEvent(fav, undefined);
  await favEvent(fav, undefined);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 0);

  await favEvent(undefined, {id: "w1", provider: "WallHaven"});
  await favEvent(fav, {...fav, thumb: "x"});
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 0);
});

test("a favourite for a wall with no stats doc starts the counter, and a delete for it stays at 0", async (t) => {
  const store = installFakeDb(t);
  await favEvent(undefined, {id: "new1", provider: "Prism"});
  assert.equal(store.get("wallpaper_stats/NEW1")?.favs, 1);
  await favEvent({provider: "Prism"}, undefined, "other9");
  assert.equal(store.get("wallpaper_stats/OTHER9")?.favs, 0);
});
