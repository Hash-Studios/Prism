import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onFavouriteWritten, recordWallpaperAction} from "../wallStats";
import {installFakeDb as installDb, type Doc} from "./fakeDb";

const GATE = "maintenance/favouriteAggregation";
const installFakeDb = (t: TestContext, seed: Record<string, Doc> = {}) => installDb(t, {
  [GATE]: {phase: "ready", epoch: "test-v1"}, "usersv2/u1": {coins: 0}, ...seed,
});

function failQuestWrites(t: TestContext) {
  const failure = {active: true};
  const run = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const set = tx.set.bind(tx);
      tx.set = ((ref: admin.firestore.DocumentReference, ...args: unknown[]) => {
        if (failure.active && ref.path === "usersv2/u1/private/economy") throw new Error("quest storage unavailable");
        return Reflect.apply(set, tx, [ref, ...args]);
      }) as typeof tx.set;
      return callback(tx);
    }));
  return failure;
}

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

const favEvent = async (before: unknown, after: unknown, wallId = "w1", id = `event_${wallId}_${Math.random()}`,
  source = db.doc(`usersv2/u1/images/${wallId}`).get(), time = new Date().toISOString()) => {
  const snapshot = await source;
  return onFavouriteWritten.run({
    id,
    time,
    params: {uid: "u1", wallId},
    data: {before: {data: () => before}, after: {
      data: () => after, createTime: snapshot.createTime, updateTime: snapshot.updateTime,
    }},
  } as unknown as Parameters<typeof onFavouriteWritten.run>[0]);
};

test("favourites add to favs, never take it below 0, and ignore other providers", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"wallpaper_stats/W1": {favs: 1}});
  const fav = {id: "w1", provider: "Prism"};
  store.set("usersv2/u1/images/w1", fav);
  await favEvent(undefined, fav);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);

  store.delete("usersv2/u1/images/w1");
  await favEvent(fav, undefined);
  await favEvent(fav, undefined);
  await favEvent(fav, undefined);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);

  await favEvent(undefined, {id: "w1", provider: "WallHaven"});
  await favEvent(fav, {...fav, thumb: "x"});
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
});

test("a favourite for a wall with no stats doc starts the counter, and a delete for it stays at 0", async (t) => {
  const store = installFakeDb(t);
  const fav = {id: "new1", provider: "Prism"};
  store.set("usersv2/u1/images/new1", fav);
  await favEvent(undefined, fav, "new1");
  assert.equal(store.get("wallpaper_stats/NEW1")?.favs, 1);
  await favEvent({provider: "Prism"}, undefined, "other9");
  assert.equal(store.get("wallpaper_stats/OTHER9"), undefined);
});

const quests = (store: Map<string, Record<string, unknown>>) =>
  (store.get("usersv2/u1/private/economy") as {quests: {items: Array<{event: string; progress: number}>; weekly: {progress: number}}}).quests;

test("a counted download feeds the set and download quests, a repeat does not", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}});
  await call({wallId: "w1", action: "download"});
  assert.equal(quests(store).weekly.progress, 1);
  await call({wallId: "w1", action: "download"});
  assert.equal(quests(store).weekly.progress, 1);
  await call({wallId: "w2", action: "set"});
  assert.equal(quests(store).weekly.progress, 2);
  assert.equal(store.get("questEventRate/u1_2026-01-02_download")?.count, 1);
  assert.equal(store.get("questEventRate/u1_2026-01-02_set_wallpaper")?.count, 2);
});

test("a set and a download of one wall on one day count once for the set quest", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}});
  await call({wallId: "w1", action: "set"});
  await call({wallId: "w1", action: "download"});
  assert.equal(quests(store).weekly.progress, 1);
  assert.equal(store.get("questEventRate/u1_2026-01-02_set_wallpaper")?.count, 1);
  assert.equal(store.get("questEventRate/u1_2026-01-02_download")?.count, 1);
});

test("a retried favourite trigger counts the quest once", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}});
  const fav = {id: "w1", provider: "Prism"};
  store.set("usersv2/u1/images/w1", fav);
  await favEvent(undefined, fav, "w1", "event_retry_1");
  await favEvent(undefined, fav, "w1", "event_retry_1");
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 1);
  store.set("usersv2/u1/images/w2", {id: "w2", provider: "Prism"});
  await favEvent(undefined, {id: "w2", provider: "Prism"}, "w2", "event_retry_2");
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 2);
});

test("a counted share feeds the share quest only", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}});
  await call({wallId: "w1", action: "share"});
  assert.equal(store.get("questEventRate/u1_2026-01-02_share")?.count, 1);
  assert.equal(quests(store).weekly.progress, 0);
});

test("a quest failure does not fail the action", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t);
  store.delete("usersv2/u1");
  assert.deepEqual(await call({wallId: "w1", action: "set"}), {counted: true});
});

test("adding a favourite feeds the favourite quest, removing one does not", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}});
  const fav = {id: "w1", provider: "Prism"};
  await favEvent(fav, undefined);
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite"), undefined);
  store.set("usersv2/u1/images/w1", fav);
  await favEvent(undefined, fav);
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 1);
  await favEvent(undefined, {id: "w1", provider: "WallHaven"});
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 1);
});

test("favourite identity comes from the path and requires a scalar Prism provider and matching id", async (t) => {
  const store = installFakeDb(t);
  for (const fav of [{id: "target", provider: "Prism"}, {id: "w1", provider: ["Prism"]},
    {id: "w1", provider: "Wallhaven"}, {provider: "Prism"}]) {
    store.set("usersv2/u1/images/w1", fav);
    await favEvent(undefined, fav);
  }
  assert.equal(store.has("wallpaper_stats/TARGET"), false);
  assert.equal(store.has("wallpaper_stats/W1"), false);
});

test("unrelated favourite events never read membership, but provider flips still reconcile", async (t) => {
  const fav = {id: "w1", provider: "Prism"};
  const external = {...fav, provider: "Pexels"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": external});
  const run = db.runTransaction.bind(db);
  const transactions = t.mock.method(db, "runTransaction", run);
  await favEvent(undefined, external);
  await favEvent(undefined, {id: "target", provider: "Prism"});
  assert.equal(transactions.mock.callCount(), 0);
  store.set("usersv2/u1/images/w1", fav);
  await favEvent(external, fav);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  store.set("usersv2/u1/images/w1", external);
  await favEvent(fav, external);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 0);
});

test("case aliases and concurrent event retries contribute once and deleting one keeps the surviving alias", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const lower = {id: "w1", provider: "Prism"};
  const upper = {id: "W1", provider: "wall_of_the_day"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": lower, "usersv2/u1/images/W1": upper});
  await Promise.all([favEvent(undefined, lower, "w1", "retry"), favEvent(undefined, upper, "W1"),
    favEvent(undefined, lower, "w1", "retry")]);
  store.delete("usersv2/u1/images/w1");
  await favEvent(lower, undefined);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);
  store.delete("usersv2/u1/images/W1");
  await favEvent(upper, undefined, "W1");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 0);
});

test("delayed create/delete/create deliveries converge to actual current membership", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t);
  await favEvent(fav, undefined, "w1", "delete-before-create");
  await favEvent(undefined, fav, "w1", "stale-create");
  assert.equal(store.get("wallpaper_stats/W1"), undefined);
  store.set("usersv2/u1/images/w1", fav);
  await favEvent(undefined, fav, "w1", "second-create");
  await favEvent(fav, undefined, "w1", "delayed-delete");
  await favEvent(undefined, fav, "w1", "stale-create");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);
  store.delete("usersv2/u1/images/w1");
  await favEvent(undefined, fav, "w1", "late-second-create");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 0);
});

test("failure staging the daily favourite rolls back aggregate and contribution, then retry counts once", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": fav});
  const runTransaction = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    runTransaction(async (tx) => {
      const set = tx.set.bind(tx);
      tx.set = ((ref: admin.firestore.DocumentReference, ...args: unknown[]) => {
        if (fail && ref.path.startsWith("wallpaper_stats_daily/")) throw new Error("daily unavailable");
        return Reflect.apply(set, tx, [ref, ...args]);
      }) as typeof tx.set;
      return callback(tx);
    }));
  await assert.rejects(() => favEvent(undefined, fav), /daily unavailable/);
  assert.equal(store.has("wallpaper_stats/W1"), false);
  assert.equal(store.has("wallpaper_stats/W1/favouriteContributions/u1"), false);
  fail = false;
  await favEvent(undefined, fav);
  await favEvent(undefined, fav);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);
});

test("a failed favourite quest is durable and retried without recounting membership or daily activity", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": fav});
  const failure = failQuestWrites(t);
  await assert.rejects(() => favEvent(undefined, fav, "w1", "failed-quest"), /quest/i);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);

  failure.active = false;
  await Promise.all([favEvent(undefined, fav, "w1", "failed-quest"),
    favEvent(undefined, fav, "w1", "failed-quest")]);
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 1);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);
});

test("pending favourite quests survive unlike and re-favourite without overwriting each other", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": fav});
  const failure = failQuestWrites(t);
  await assert.rejects(() => favEvent(undefined, fav), /quest/i);
  store.delete("usersv2/u1/images/w1");
  await assert.rejects(() => favEvent(fav, undefined), /quest/i);
  store.set("usersv2/u1/images/w1", fav);
  await assert.rejects(() => favEvent(undefined, fav), /quest/i);

  failure.active = false;
  await Promise.all([favEvent(undefined, fav), favEvent(fav, undefined), favEvent(undefined, fav)]);
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 2);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 2);
});

test("expired pending favourites do not award tomorrow's quests or rewind current progress", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": fav});
  const failure = failQuestWrites(t);
  await assert.rejects(() => favEvent(undefined, fav), /quest/i);
  t.mock.timers.setTime(NOW.getTime() + 86_400_000);
  failure.active = false;
  await call({wallId: "w2", action: "set"});
  const currentQuests = store.get("usersv2/u1/private/economy");
  await favEvent(undefined, fav);
  assert.deepEqual(store.get("usersv2/u1/private/economy"), currentQuests);
  assert.equal(store.has("questEventRate/u1_2026-01-02_favourite"), false);
  assert.equal(store.has("questEventRate/u1_2026-01-03_favourite"), false);
  assert.equal(store.get("usersv2/u1")?.coins, 0);
});

test("stale deletion and metadata updates may reconcile membership but never earn favourite quests", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}, "usersv2/u1/images/w1": fav});
  await favEvent(fav, undefined);
  await favEvent(fav, {...fav, thumb: "changed"});
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.has("questEventRate/u1_2026-01-02_favourite"), false);
  // The later genuine create can claim this accepted positive transition, without counting it twice.
  await favEvent(undefined, fav);
  await favEvent(undefined, fav);
  assert.equal(store.get("questEventRate/u1_2026-01-02_favourite")?.count, 1);
  assert.equal(store.get(`wallpaper_stats_daily/${DAY}_W1`)?.favs, 1);
});

test("a create from an old favourite incarnation cannot reward the current recreated favourite", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}, "usersv2/u1/images/w1": fav});
  const source = await db.doc("usersv2/u1/images/w1").get();
  store.delete("usersv2/u1/images/w1");
  store.set("usersv2/u1/images/w1", fav);
  await favEvent(undefined, fav, "w1", "stale-incarnation", Promise.resolve(source));
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.has("questEventRate/u1_2026-01-02_favourite"), false);
});

test("legacy counts with no contribution ledger are gated, not doubled or silently left high on deletion", async (t) => {
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"wallpaper_stats/W1": {favs: 1}, "usersv2/u1/images/w1": fav});
  store.delete(GATE);
  await assert.rejects(() => favEvent(fav, fav), /backfill/i);
  store.delete("usersv2/u1/images/w1");
  await assert.rejects(() => favEvent(fav, undefined), /backfill/i);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.has("wallpaper_stats/W1/favouriteContributions/u1"), false);
});

test("a previous-day create that is still live cannot earn today's favourite quest", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const fav = {id: "w1", provider: "Prism"};
  const store = installFakeDb(t, {"usersv2/u1/images/w1": fav});
  await favEvent(undefined, fav, "w1", "old-live-create", undefined, "2026-01-01T23:59:00Z");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.has("questEventRate/u1_2026-01-02_favourite"), false);
});
