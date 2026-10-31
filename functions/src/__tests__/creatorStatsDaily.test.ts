import assert from "node:assert/strict";
import test from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {db} from "../common";
import {readCreatorStats} from "../creatorStats";
import {enqueueCreatorStatsDaily, processCreatorStatsDailyQueue} from "../creatorStatsDaily";
import {hash, historyRef, incarnation} from "../creatorStatsHistory";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.parse("2026-10-26T09:00:00Z");
const seed = (extra: Record<string, Doc> = {}) => ({
  "usersv2/alice": {email: "alice@example.com"},
  "walls/wall": {id: "WALL", creatorUid: "alice", review: true},
  "wallpaper_stats_daily/20261025_WALL": {wallId: "WALL", day: "20261025", views: 5, favs: 2},
  ...extra,
});

test("enqueue stores daily maxima without scanning walls or writing history", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed(), observed);
  for (let i = 0; i < 20_001; i++) store.set(`walls/foreign${i}`, {id: `X${i}`, creatorUid: "other", review: true});
  const source = await db.doc(path).get();
  await enqueueCreatorStatsDaily(source, NOW);
  const queue = [...store.entries()].filter(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  assert.equal(queue.length, 1);
  assert.deepEqual(queue[0][1].counters, {views: 5, favs: 2, sets: 0, downloads: 0, shares: 0});
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsHistory/")), false);
  assert.deepEqual(observed, {reads: 3, writes: 1});
});

test("processor projects enqueued daily deltas and advances the incarnation checkpoint", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  const wall = await db.doc("walls/wall").get();
  const history = (await historyRef(wall).get()).data();
  assert.equal(history?.weeks["2026-W43"].views, 5);
  assert.equal(history?.weeks["2026-W43"].saves, 2);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 1);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyQueue/")), false);
});

test("fake database separates direct operations and applies field projections", async (t) => {
  const observed = {reads: 0, writes: 0, outsideReads: 0, outsideWrites: 0};
  installFakeDb(t, {"rows/one": {visible: 1, private: 2}}, observed);
  const projected = await db.collection("rows").select("visible").get();
  assert.deepEqual(projected.docs[0].data(), {visible: 1});
  await db.doc("rows/one").get();
  await db.doc("rows/two").set({visible: 3});
  assert.deepEqual(observed, {reads: 0, writes: 0, outsideReads: 2, outsideWrites: 1});
});

test("fake database reports direct reads inside a transaction callback as outside operations", async (t) => {
  const observed = {reads: 0, writes: 0, outsideReads: 0, outsideWrites: 0};
  installFakeDb(t, {"rows/one": {visible: 1}}, observed);
  await db.runTransaction(async (tx) => {
    await db.doc("rows/one").get();
    await tx.get(db.doc("rows/one"));
  });
  assert.deepEqual(observed, {reads: 1, writes: 0, outsideReads: 1, outsideWrites: 0});
});

test("pending transaction operations cannot hide direct database reads or writes", async (t) => {
  const observed = {reads: 0, writes: 0, outsideReads: 0, outsideWrites: 0};
  installFakeDb(t, {"rows/one": {visible: 1}}, observed);
  await db.runTransaction(async (tx) => {
    const pending = tx.get(db.doc("rows/one"));
    await db.doc("rows/one").get();
    await pending;
    tx.set(db.doc("rows/one"), {visible: 2});
    await db.doc("rows/two").set({visible: 3});
  });
  assert.deepEqual(observed, {reads: 1, writes: 1, outsideReads: 1, outsideWrites: 1});
});

test("old after-images remain projectable after TTL deletion and deletes enqueue nothing", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed(), observed);
  const delayed = await db.doc(path).get();
  store.delete(path);
  await enqueueCreatorStatsDaily(delayed, NOW);
  const deleted = await db.doc(path).get();
  observed.reads = 0; observed.writes = 0;
  await enqueueCreatorStatsDaily(deleted, NOW);
  assert.deepEqual(observed, {reads: 0, writes: 0});
  await processCreatorStatsDailyQueue(NOW);
  const wall = await db.doc("walls/wall").get();
  assert.equal((await historyRef(wall).get()).data()?.weeks["2026-W43"].views, 5);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 1);
});

test("multiple days and source incarnations fold into one wall-history write", async (t) => {
  const firstPath = "wallpaper_stats_daily/20261024_WALL";
  const secondPath = "wallpaper_stats_daily/20261025_WALL";
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed({
    [firstPath]: {wallId: "WALL", day: "20261024", views: 3},
    [secondPath]: {wallId: "WALL", day: "20261025", views: 4},
  }), observed);
  await enqueueCreatorStatsDaily(await db.doc(firstPath).get(), NOW);
  await enqueueCreatorStatsDaily(await db.doc(secondPath).get(), NOW);
  store.delete(firstPath);
  store.set(firstPath, {wallId: "WALL", day: "20261024", views: 5});
  await enqueueCreatorStatsDaily(await db.doc(firstPath).get(), NOW);
  observed.reads = 0;
  observed.writes = 0;
  await processCreatorStatsDailyQueue(NOW);
  const wall = await db.doc("walls/wall").get();
  assert.equal((await historyRef(wall).get()).data()?.weeks["2026-W43"].views, 12);
  assert.equal(observed.reads, 15);
  assert.equal(observed.writes, 9);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 3);
});

test("failed daily batch commit keeps history and checkpoints out and preserves queue work", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const options = {failCommitAt: 3};
  const store = installFakeDb(t, seed(), undefined, options);
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  await assert.rejects(processCreatorStatsDailyQueue(NOW), /injected transaction commit failure/);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsHistory/")), false);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyCheckpoints/")), false);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyQueue/")).length, 1);
});

test("an unexpected history read failure preserves ready work and retries without poison", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  const queue = [...store.entries()].filter(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  const collection = db.collection.bind(db);
  const failure = t.mock.method(db, "collection", (name: string) => {
    const result = collection(name);
    if (name === "creatorStatsHistory") {
      const doc = result.doc.bind(result);
      t.mock.method(result, "doc", (id: string) => {
        const ref = doc(id);
        t.mock.method(ref, "get", async () => {
          throw new Error("injected history read failure");
        });
        return ref;
      });
    }
    return result;
  });
  await assert.rejects(processCreatorStatsDailyQueue(NOW), /injected history read failure/);
  assert.deepEqual([...store.entries()].filter(([name]) => name.startsWith("creatorStatsDailyQueue/")), queue);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyCheckpoints/")), false);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsHistory/")), false);
  failure.mock.restore();
  await processCreatorStatsDailyQueue(NOW);
  const wall = await db.doc("walls/wall").get();
  assert.equal((await historyRef(wall).get()).data()?.weeks["2026-W43"].views, 5);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyQueue/")).length, 0);
});

test("malformed history blocks only its contributing wall while peer work commits", async (t) => {
  const store = installFakeDb(t, seed({
    "walls/other": {id: "OTHER", creatorUid: "alice", review: true},
    "wallpaper_stats_daily/20261025_WALL": {wallId: "WALL", day: "20261025", views: 1},
    "wallpaper_stats_daily/20261025_OTHER": {wallId: "OTHER", day: "20261025", views: 2},
  }));
  const wall = await db.doc("walls/wall").get();
  await historyRef(wall).set({wallPath: wall.ref.path, incarnation: incarnation(wall), creatorUid: "alice",
    from: "2026-10-20T00:00:00.000Z", weeks: {"2026-W43": {views: "bad"}}, folderAdds: 0});
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261025_WALL").get(), NOW);
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261025_OTHER").get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  const badQueue = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"))?.[1];
  assert.equal(badQueue?.state, "blocked");
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 1);
  const other = await db.doc("walls/other").get();
  assert.equal((await historyRef(other).get()).data()?.weeks["2026-W43"].views, 2);
});

test("unsafe history arithmetic blocks every contributor to that wall, not peer walls", async (t) => {
  const store = installFakeDb(t, seed({
    "walls/other": {id: "OTHER", creatorUid: "alice", review: true},
    "wallpaper_stats_daily/20261025_WALL": {wallId: "WALL", day: "20261025", views: 1},
    "wallpaper_stats_daily/20261024_WALL": {wallId: "WALL", day: "20261024", views: 1},
    "wallpaper_stats_daily/20261025_OTHER": {wallId: "OTHER", day: "20261025", views: 2},
  }));
  const wall = await db.doc("walls/wall").get();
  await historyRef(wall).set({wallPath: wall.ref.path, incarnation: incarnation(wall), creatorUid: "alice",
    from: "2026-10-20T00:00:00.000Z", weeks: {"2026-W43": {views: Number.MAX_SAFE_INTEGER - 1}}, folderAdds: 0});
  const before = (await historyRef(wall).get()).data();
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261025_WALL").get(), NOW);
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261024_WALL").get(), NOW);
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261025_OTHER").get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  const poisoned = [...store.entries()].filter(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  assert.equal(poisoned.length, 2);
  assert.deepEqual(poisoned.map(([, data]) => data.state), ["blocked", "blocked"]);
  assert.deepEqual((await historyRef(wall).get()).data(), before);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 1);
  const other = await db.doc("walls/other").get();
  assert.equal((await historyRef(other).get()).data()?.weeks["2026-W43"].views, 2);
});

test("nanosecond creation order prevents projection onto a slightly newer wall", async (t) => {
  const sourcePath = "wallpaper_stats_daily/20261025_WALL";
  const second = Math.floor(NOW / 1000);
  const store = installFakeDb(t, seed(), undefined, {createTimes: {
    "walls/wall": new Timestamp(second, 2),
    [sourcePath]: new Timestamp(second, 1),
  }});
  await enqueueCreatorStatsDaily(await db.doc(sourcePath).get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsHistory/")), false);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyCheckpoints/")), false);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyQueue/")), false);
});

test("per-field maxima survive reordered after-images and lower current snapshots", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 3, favs: 8}}));
  const delayed = await db.doc(path).get();
  store.set(path, {wallId: "WALL", day: "20261025", views: 7, favs: 2});
  await enqueueCreatorStatsDaily(delayed, NOW);
  const queue = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"))?.[1];
  assert.deepEqual(queue?.counters, {views: 7, favs: 8, sets: 0, downloads: 0, shares: 0});
  await enqueueCreatorStatsDaily(delayed, NOW);
  assert.deepEqual([...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"))?.[1]?.counters,
    {views: 7, favs: 8, sets: 0, downloads: 0, shares: 0});
});

test("recreated source incarnations use independent queue and checkpoint keys", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 5}}));
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  store.delete(path);
  store.set(path, {wallId: "WALL", day: "20261025", views: 2});
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  const wall = await db.doc("walls/wall").get();
  assert.equal((await historyRef(wall).get()).data()?.weeks["2026-W43"].views, 7);
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 2);
});

test("an already represented pending increment reads its queue without rewriting it", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, seed(), observed);
  const source = await db.doc(path).get();
  await enqueueCreatorStatsDaily(source, NOW);
  const queuePath = [...store.keys()].find((name) => name.startsWith("creatorStatsDailyQueue/"));
  assert.ok(queuePath);
  const queued = store.get(queuePath);
  observed.reads = 0;
  observed.writes = 0;
  await enqueueCreatorStatsDaily(source, NOW + 1000);
  assert.deepEqual(observed, {reads: 3, writes: 0});
  assert.deepEqual(store.get(queuePath), queued);
});

test("malformed or future source days and noncanonical source IDs are rejected", async (t) => {
  const future = {wallId: "WALL", day: "20261027", views: 5};
  const impossible = {wallId: "WALL", day: "20260230", views: 5};
  const alias = {wallId: " WALL ", day: "20261025", views: 5};
  const store = installFakeDb(t, seed({
    "wallpaper_stats_daily/future": future,
    "wallpaper_stats_daily/impossible": impossible,
    "wallpaper_stats_daily/alias": alias,
  }));
  for (const path of ["wallpaper_stats_daily/future", "wallpaper_stats_daily/impossible", "wallpaper_stats_daily/alias"]) {
    await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  }
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyQueue/")), false);
});

test("metadata disagreement blocks queue work instead of guessing attribution", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed());
  const source = await db.doc(path).get();
  await enqueueCreatorStatsDaily(source, NOW);
  const queueEntry = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  assert.ok(queueEntry);
  store.set(queueEntry[0], {...queueEntry[1], wallId: "ALIEN"});
  store.set(path, {wallId: "WALL", day: "20261025", views: 9});
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW + 1);
  assert.equal(store.get(queueEntry[0])?.state, "blocked");
  assert.equal((store.get(queueEntry[0])?.counters as Doc).views, 9);
  await processCreatorStatsDailyQueue(NOW);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsHistory/")), false);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyCheckpoints/")), false);
});

test("malformed queue metadata preserves maxima and later deliveries cannot unblock work", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 100, favs: 2}}));
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  const queue = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  assert.ok(queue);
  store.set(queue[0], {...queue[1], failure: {code: "INVALID", at: Timestamp.fromMillis(NOW)}});
  store.set(path, {wallId: "WALL", day: "20261025", views: 5, favs: 1, sets: 1});
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW + 1);
  assert.deepEqual(store.get(queue[0])?.counters, {views: 100, favs: 2, sets: 1, downloads: 0, shares: 0});
  assert.equal(store.get(queue[0])?.state, "blocked");
  store.set(path, {wallId: "WALL", day: "20261025", views: 200, favs: 1, sets: 1});
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW + 2);
  assert.deepEqual(store.get(queue[0])?.counters, {views: 200, favs: 2, sets: 1, downloads: 0, shares: 0});
  assert.equal(store.get(queue[0])?.state, "blocked");
  await processCreatorStatsDailyQueue(NOW);
  assert.equal(store.get(queue[0])?.state, "blocked");
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 0);
});

test("malformed queue and checkpoint payloads block independently while valid work commits", async (t) => {
  for (const kind of ["queue_size", "checkpoint_identity", "checkpoint_size"] as const) {
    await t.test(kind, async (subtest) => {
      const store = installFakeDb(subtest, seed({
        "walls/other": {id: "OTHER", creatorUid: "alice", review: true},
        "wallpaper_stats_daily/other": {wallId: "OTHER", day: "20261025", views: 2},
      }));
      await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261025_WALL").get(), NOW);
      const queue = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"));
      assert.ok(queue);
      if (kind === "queue_size") store.set(queue[0], {...queue[1], unexpected: "x".repeat(4096)});
      else {
        const item = queue[1];
        const checkpoint = {schemaVersion: 1, sourcePath: item.sourcePath, incarnation: item.incarnation,
          sourceCreatedAt: item.sourceCreatedAt, wallId: kind === "checkpoint_identity" ? "ALIEN" : item.wallId,
          day: item.day, counters: item.counters, ...(kind === "checkpoint_size" ? {unexpected: "x".repeat(2048)} : {})};
        store.set(queue[0].replace("creatorStatsDailyQueue/", "creatorStatsDailyCheckpoints/"), checkpoint);
      }
      const checkpointPath = queue[0].replace("creatorStatsDailyQueue/", "creatorStatsDailyCheckpoints/");
      const before = store.get(checkpointPath);
      await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/other").get(), NOW);
      await processCreatorStatsDailyQueue(NOW);
      assert.equal(store.get(queue[0])?.state, "blocked");
      assert.deepEqual(store.get(checkpointPath), before);
      const wall = await db.doc("walls/wall").get();
      assert.equal((await historyRef(wall).get()).exists, false);
      const other = await db.doc("walls/other").get();
      assert.equal((await historyRef(other).get()).data()?.weeks["2026-W43"].views, 2);
    });
  }
});

test("oversized queued source metadata cannot create a checkpoint", async (t) => {
  const path = `wallpaper_stats_daily/${"q".repeat(1700)}`;
  const wallId = "W".repeat(128);
  const counters = {views: Number.MAX_SAFE_INTEGER, favs: Number.MAX_SAFE_INTEGER,
    sets: Number.MAX_SAFE_INTEGER, downloads: Number.MAX_SAFE_INTEGER, shares: Number.MAX_SAFE_INTEGER};
  const observed = {reads: 0, writes: 0};
  const key = hash(`${path}:0:1000000`);
  const store = installFakeDb(t, seed({[`creatorStatsDailyQueue/${key}`]: {schemaVersion: 1, sourcePath: path,
    incarnation: "0:1000000", sourceCreatedAt: Timestamp.fromMillis(1), wallId, day: "20261025", counters,
    firstEnqueuedAt: Timestamp.fromMillis(NOW), updatedAt: Timestamp.fromMillis(NOW), state: "ready"}}), observed);
  await processCreatorStatsDailyQueue(NOW);
  const queue = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  assert.ok(queue);
  assert.equal(queue[1].state, "blocked");
  assert.deepEqual(queue[1].counters, counters);
  assert.equal((queue[1].failure as Doc).code, "checkpoint_too_large");
  assert.deepEqual(observed, {reads: 7, writes: 3});
});

test("oversized history remains unchanged and blocks its source", async (t) => {
  const store = installFakeDb(t, seed());
  const wall = await db.doc("walls/wall").get();
  const previous = {wallPath: wall.ref.path, incarnation: incarnation(wall), creatorUid: "alice",
    from: new Date(NOW).toISOString(), weeks: {"2026-W43": {views: 1}}, folderAdds: 0, unexpected: "x".repeat(16384)};
  await historyRef(wall).set(previous);
  await enqueueCreatorStatsDaily(await db.doc("wallpaper_stats_daily/20261025_WALL").get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  assert.deepEqual((await historyRef(wall).get()).data(), previous);
  const queue = [...store.entries()].find(([name]) => name.startsWith("creatorStatsDailyQueue/"));
  assert.ok(queue);
  assert.equal(queue[1].state, "blocked");
  assert.equal([...store.keys()].filter((name) => name.startsWith("creatorStatsDailyCheckpoints/")).length, 0);
});

test("missing, deleted, and deletion-barred owners drop work without advancing checkpoints", async (t) => {
  const sources = [
    ["wallpaper_stats_daily/20261025_MISSING", {wallId: "MISSING", day: "20261025", views: 2}],
    ["wallpaper_stats_daily/20261025_WALLLESS", {wallId: "WALLLESS", day: "20261025", views: 2}],
    ["wallpaper_stats_daily/20261025_DELETED", {wallId: "DELETED", day: "20261025", views: 2}],
    ["wallpaper_stats_daily/20261025_BARRIER", {wallId: "BARRIER", day: "20261025", views: 2}],
  ] as const;
  const store = installFakeDb(t, seed({
    "usersv2/bob": {deleted: true}, "usersv2/charlie": {email: "charlie@example.com"},
    "creatorDeletionState/charlie": {closed: true},
    "walls/missing": {id: "MISSING", creatorUid: "missing", review: true},
    "walls/deleted": {id: "DELETED", creatorUid: "bob", review: true},
    "walls/barrier": {id: "BARRIER", creatorUid: "charlie", review: true},
    ...Object.fromEntries(sources),
  }));
  for (const [path] of sources) await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  await processCreatorStatsDailyQueue(NOW);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyCheckpoints/")), false);
  assert.equal([...store.keys()].some((name) => name.startsWith("creatorStatsDailyQueue/")), false);
});

test("a batch observes a new UTC day after lease acquisition", async (t) => {
  let clock = Date.parse("2026-10-26T23:59:59.000Z");
  t.mock.method(Date, "now", () => clock);
  const path = "wallpaper_stats_daily/20261027_WALL";
  const store = installFakeDb(t, seed());
  const run = db.runTransaction.bind(db);
  let first = true;
  t.mock.method(db, "runTransaction", async (...args: Parameters<typeof db.runTransaction>) => {
    const result = await run(...args);
    if (first) {
      first = false;
      clock += 2000;
      store.set(path, {wallId: "WALL", day: "20261027", views: 2});
      await enqueueCreatorStatsDaily(await db.doc(path).get(), clock);
    }
    return result;
  });
  await processCreatorStatsDailyQueue();
  const wall = await db.doc("walls/wall").get();
  const history = (await historyRef(wall).get()).data();
  assert.equal(history?.weeks["2026-W44"].views, 2);
  assert.equal(history?.from, new Date(clock).toISOString());
});

test("processing after source expiry preserves partial history, null coverage, and nine-week pruning", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", shares: 4}}));
  const wall = await db.doc("walls/wall").get();
  await historyRef(wall).set({wallPath: wall.ref.path, incarnation: "0:1000000", creatorUid: "alice",
    from: new Date(NOW).toISOString(), weeks: {"2026-W35": {views: 2}, "2026-W43": {views: 3}}, folderAdds: 0});
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  store.delete(path);
  const later = NOW + 21 * 86400000;
  await processCreatorStatsDailyQueue(later);
  const history = (await historyRef(wall).get()).data();
  assert.equal(history?.from, new Date(NOW).toISOString());
  assert.equal(Object.keys(history?.weeks ?? {}).length, 1);
  assert.equal(history?.weeks["2026-W43"].views, 3);
  assert.equal(history?.weeks["2026-W43"].shares, 4);
  const coverage = await readCreatorStats("alice", {}, later);
  assert.equal(coverage.weeks[0].metrics.views, null);
  assert.equal(coverage.weeks[3].metrics.views, 3);
});

test("first history coverage starts when a delayed queue item is processed", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed());
  await enqueueCreatorStatsDaily(await db.doc(path).get(), NOW);
  assert.equal((await readCreatorStats("alice", {}, NOW)).coverage.views.weeklyFrom, null);
  store.delete(path);
  const later = NOW + 21 * 86400000;
  await processCreatorStatsDailyQueue(later);
  const wall = await db.doc("walls/wall").get();
  assert.equal((await historyRef(wall).get()).data()?.from, new Date(later).toISOString());
  const stats = await readCreatorStats("alice", {}, later);
  assert.equal(stats.weeks[3].metrics.views, 5);
  assert.equal(stats.weeks[0].metrics.views, null);
  assert.equal(stats.coverage.views.weeklyFrom, new Date(later).toISOString());
});
