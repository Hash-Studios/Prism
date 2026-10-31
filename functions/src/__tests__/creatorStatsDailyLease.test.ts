import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {enqueueCreatorStatsDaily, processCreatorStatsDailyQueue} from "../creatorStatsDaily";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.parse("2026-10-26T09:00:00Z");
const STATE = "creatorStatsProcessorState/daily";
const timestamp = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const seed = () => ({"usersv2/alice": {email: "alice@example.com"},
  "walls/wall": {id: "WALL", creatorUid: "alice", review: true},
  "wallpaper_stats_daily/source": {wallId: "WALL", day: "20261025", views: 5}});
const paths = (store: Map<string, Doc>, collection: string) => [...store.keys()].filter((path) => path.startsWith(`${collection}/`));
const views = (store: Map<string, Doc>) => paths(store, "creatorStatsHistory").map((path) =>
  (store.get(path)?.weeks as Record<string, Doc>)["2026-W43"].views);

function afterTransaction(t: TestContext, hook: (number: number) => void) {
  const original = db.runTransaction.bind(db);
  let completed = 0;
  t.mock.method(db, "runTransaction", async (...args: Parameters<typeof db.runTransaction>) => {
    const result = await original(...args);
    hook(++completed);
    return result;
  });
}

function afterProcessorStateRead(t: TestContext, hook: (number: number) => void) {
  const original = db.doc.bind(db);
  let completed = 0;
  t.mock.method(db, "doc", (path: string) => {
    const ref = original(path);
    if (path === STATE) {
      const get = ref.get.bind(ref);
      t.mock.method(ref, "get", async () => {
        const result = await get();
        hook(++completed);
        return result;
      });
    }
    return ref;
  });
}

test("a lease that expires before the batch cannot project queued work", async (t) => {
  let clock = NOW;
  t.mock.method(Date, "now", () => clock);
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
  afterProcessorStateRead(t, (number) => {
    if (number === 2) clock = NOW + 600_000;
  });
  await processCreatorStatsDailyQueue(NOW);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 1);
  assert.deepEqual(views(store), []);
  await processCreatorStatsDailyQueue(clock);
  assert.deepEqual(views(store), [5]);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
});

test("an unexpired lease excludes another invocation until its exact expiry", async (t) => {
  let clock = NOW;
  t.mock.method(Date, "now", () => clock);
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed(), observed);
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
  const incumbent = {schemaVersion: 1, owner: "incumbent", leaseUntil: timestamp(NOW + 1), notBefore: timestamp(0)};
  store.set(STATE, incumbent);
  observed.reads = 0; observed.writes = 0;
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(store.get(STATE), incumbent);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 1);
  assert.deepEqual({reads: observed.reads, writes: observed.writes}, {reads: 1, writes: 0});
  clock++;
  await processCreatorStatsDailyQueue(clock);
  assert.deepEqual(views(store), [5]);
  assert.equal(store.get(STATE)?.owner, null);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
});

test("a stale token cannot project work after another owner takes the lease", async (t) => {
  let clock = NOW;
  t.mock.method(Date, "now", () => clock);
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
  const successor = {schemaVersion: 1, owner: "successor", leaseUntil: timestamp(NOW + 600_000), notBefore: timestamp(0)};
  afterTransaction(t, (number) => {
    if (number === 1) store.set(STATE, successor);
  });
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(store.get(STATE), successor);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 1);
  assert.deepEqual(views(store), []);
  clock += 600_000;
  await processCreatorStatsDailyQueue(clock);
  assert.deepEqual(views(store), [5]);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
});

test("finishing an old invocation cannot release its successor's lease or cooldown", async (t) => {
  t.mock.method(Date, "now", () => NOW);
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
  const successor = {schemaVersion: 1, owner: "successor", leaseUntil: timestamp(NOW + 600_000),
    notBefore: timestamp(NOW + 900_000)};
  afterTransaction(t, (number) => {
    if (number === 2) store.set(STATE, successor);
  });
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store), [5]);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
  assert.deepEqual(store.get(STATE), successor);
});

test("oldest-first batches keep hot work in place and break enqueue-time ties by document ID", async (t) => {
  t.mock.method(Date, "now", () => NOW + 3000);
  const store = installFakeDb(t, seed());
  const source = "wallpaper_stats_daily/source";
  await enqueueCreatorStatsDaily(await db.doc(source).get(), NOW - 1000);
  for (let i = 0; i < 100; i++) {
    const path = `wallpaper_stats_daily/tie${i}`;
    store.set(path, {wallId: "WALL", day: "20261025", views: 1});
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  const young = "wallpaper_stats_daily/young";
  store.set(young, {wallId: "WALL", day: "20261025", views: 1});
  await enqueueCreatorStatsDaily(await db.doc(young).get(), NOW + 1000);
  const tiePaths = paths(store, "creatorStatsDailyQueue").filter((path) =>
    String(store.get(path)?.sourcePath).startsWith("wallpaper_stats_daily/tie")).sort();
  const youngPath = paths(store, "creatorStatsDailyQueue").find((path) => store.get(path)?.sourcePath === young);
  assert.ok(youngPath);
  store.set(source, {wallId: "WALL", day: "20261025", views: 7});
  await enqueueCreatorStatsDaily(await db.doc(source).get(), NOW + 2000);
  afterTransaction(t, (number) => {
    if (number === 2) {
      store.set(STATE, {schemaVersion: 1, owner: "successor",
        leaseUntil: timestamp(NOW + 600_000), notBefore: timestamp(0)});
    }
  });
  await processCreatorStatsDailyQueue(NOW + 3000);
  assert.deepEqual(paths(store, "creatorStatsDailyQueue").sort(), [tiePaths[99], youngPath].sort());
  assert.equal(paths(store, "creatorStatsDailyCheckpoints").length, 100);
  assert.deepEqual(views(store), [106]);
});

test("the 240-second work budget starts no second batch and leaves it for the next invocation", async (t) => {
  let clock = NOW;
  t.mock.method(Date, "now", () => clock);
  const store = installFakeDb(t, seed());
  for (let i = 0; i < 101; i++) {
    const path = `wallpaper_stats_daily/budget${i}`;
    store.set(path, {wallId: "WALL", day: "20261025", views: 1});
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  afterTransaction(t, (number) => {
    if (number === 2) clock += 240_000;
  });
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store), [100]);
  assert.equal(paths(store, "creatorStatsDailyCheckpoints").length, 100);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 1);
  assert.equal(store.get(STATE)?.owner, null);
  await processCreatorStatsDailyQueue(clock);
  assert.deepEqual(views(store), [101]);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
});

test("lease acquisition time counts toward the 240-second invocation work budget", async (t) => {
  let clock = NOW;
  t.mock.method(Date, "now", () => clock);
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
  afterTransaction(t, (number) => {
    if (number === 1) clock += 240_000;
  });
  await processCreatorStatsDailyQueue(NOW);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 1);
  assert.deepEqual(views(store), []);
  assert.equal(store.get(STATE)?.owner, null);
  await processCreatorStatsDailyQueue(clock);
  assert.deepEqual(views(store), [5]);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
});

test("lease acquisition compares expiry against the clock after the state read returns", async (t) => {
  let clock = NOW;
  t.mock.method(Date, "now", () => clock);
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
  store.set(STATE, {schemaVersion: 1, owner: "incumbent", leaseUntil: timestamp(NOW + 1), notBefore: timestamp(0)});
  afterProcessorStateRead(t, (number) => {
    if (number === 1) clock += 2;
  });
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store), [5]);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
  assert.equal(store.get(STATE)?.owner, null);
});

test("three distinct creators and walls use exactly 23 reads and 11 writes including invocation overhead", async (t) => {
  t.mock.method(Date, "now", () => NOW);
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, {}, observed);
  for (let i = 1; i <= 3; i++) {
    store.set(`usersv2/creator${i}`, {email: `creator${i}@example.com`});
    store.set(`walls/wall${i}`, {id: `WALL${i}`, creatorUid: `creator${i}`, review: true});
    const path = `wallpaper_stats_daily/distinct${i}`;
    store.set(path, {wallId: `WALL${i}`, day: "20261025", views: i});
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  observed.reads = 0; observed.writes = 0;
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store).sort(), [1, 2, 3]);
  assert.equal(paths(store, "creatorStatsDailyCheckpoints").length, 3);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
  assert.deepEqual({reads: observed.reads, writes: observed.writes}, {reads: 23, writes: 11});
});

test("three walls sharing one creator use exactly 19 reads and 11 writes", async (t) => {
  t.mock.method(Date, "now", () => NOW);
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, {"usersv2/alice": {email: "alice@example.com"}}, observed);
  for (let i = 1; i <= 3; i++) {
    store.set(`walls/wall${i}`, {id: `WALL${i}`, creatorUid: "alice", review: true});
    const path = `wallpaper_stats_daily/sharedOwner${i}`;
    store.set(path, {wallId: `WALL${i}`, day: "20261025", views: i});
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  observed.reads = 0; observed.writes = 0;
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store).sort(), [1, 2, 3]);
  assert.equal(paths(store, "creatorStatsDailyCheckpoints").length, 3);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
  assert.deepEqual({reads: observed.reads, writes: observed.writes}, {reads: 19, writes: 11});
});

test("three sources sharing one wall write its summed history once with 15 reads and 9 writes", async (t) => {
  t.mock.method(Date, "now", () => NOW);
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed(), observed);
  for (let i = 1; i <= 3; i++) {
    const path = `wallpaper_stats_daily/sharedWall${i}`;
    store.set(path, {wallId: "WALL", day: `2026102${i + 2}`, views: i});
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  observed.reads = 0; observed.writes = 0;
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store), [6]);
  assert.equal(paths(store, "creatorStatsDailyCheckpoints").length, 3);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
  assert.deepEqual({reads: observed.reads, writes: observed.writes}, {reads: 15, writes: 9});
});

test("an all-no-delta batch deletes completed work with 11 reads and 5 writes without a census", async (t) => {
  t.mock.method(Date, "now", () => NOW);
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed(), observed);
  for (let i = 1; i <= 3; i++) {
    const path = `wallpaper_stats_daily/noDelta${i}`;
    store.set(path, {wallId: "WALL", day: "20261025", views: i});
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  const queued = [...store.entries()].filter(([path]) => path.startsWith("creatorStatsDailyQueue/"));
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store), [6]);
  for (const [path, value] of queued) store.set(path, value);
  for (let i = 0; i < 20_000; i++) store.set(`walls/foreign${i}`, {id: `FOREIGN${i}`, creatorUid: "alice", review: false});
  observed.reads = 0; observed.writes = 0;
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual(views(store), [6]);
  assert.equal(paths(store, "creatorStatsDailyCheckpoints").length, 3);
  assert.equal(paths(store, "creatorStatsDailyQueue").length, 0);
  assert.deepEqual({reads: observed.reads, writes: observed.writes}, {reads: 11, writes: 5});
});

test("processor read costs include rejected owners, rejected histories, and an empty census", async (t) => {
  for (const kind of ["inactive_owner", "invalid_history", "empty_census", "invalid_queue"] as const) {
    await t.test(kind, async (subtest) => {
      const observed = {reads: 0, writes: 0};
      const store = installFakeDb(subtest, seed(), observed);
      await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
      const queuePath = paths(store, "creatorStatsDailyQueue")[0];
      if (kind === "inactive_owner") store.delete("usersv2/alice");
      if (kind === "empty_census") store.delete("walls/wall");
      if (kind === "invalid_queue") store.set(queuePath, {...store.get(queuePath), counters: {views: -1}});
      if (kind === "invalid_history") {
        await processCreatorStatsDailyQueue(NOW);
        const historyPath = paths(store, "creatorStatsHistory")[0];
        store.set(historyPath, {...store.get(historyPath), weeks: {"2026-W43": {views: -1}}});
        store.set("wallpaper_stats_daily/source", {wallId: "WALL", day: "20261025", views: 6});
        await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/source").get(), NOW);
      }
      observed.reads = 0; observed.writes = 0;
      await processCreatorStatsDailyQueue(NOW);
      const expectedReads = {inactive_owner: 10, invalid_history: 11, empty_census: 8, invalid_queue: 6};
      assert.deepEqual(observed, {reads: expectedReads[kind], writes: 3});
      if (kind === "invalid_history" || kind === "invalid_queue") assert.equal(store.get(queuePath)?.state, "blocked");
      else assert.equal(store.has(queuePath), false);
    });
  }
});
