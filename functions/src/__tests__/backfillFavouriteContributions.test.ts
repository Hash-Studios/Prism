import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";
import {runInNewContext} from "node:vm";
import * as admin from "firebase-admin";
import {db} from "../common";
import {backfillFavouriteContributions} from "../backfillFavouriteContributions";
import {onFavouriteWritten} from "../wallStats";
import {installFakeDb} from "./fakeDb";

const GATE = "maintenance/favouriteAggregation";
const fav = (id: string, provider = "Prism") => ({id, provider});
const apply = (maxPages = 100) => backfillFavouriteContributions({
  apply: true, epoch: "rollout-v1", favouritesFrozen: true, pageSize: 1, maxPages,
});
const deliver = async (before: unknown, after: unknown) => {
  const source = await db.doc("usersv2/u1/images/w1").get();
  await onFavouriteWritten.run({params: {uid: "u1", wallId: "w1"}, data: {
    before: {data: () => before}, after: {...source, data: () => after},
  }} as unknown as Parameters<typeof onFavouriteWritten.run>[0]);
};

async function runCli(args: string[]) {
  const source = readFileSync(require.resolve("../backfillFavouriteContributions"), "utf8");
  const module = {exports: {}};
  const cliProcess = {argv: ["node", "backfillFavouriteContributions.js", ...args], exitCode: 0};
  const errors: unknown[] = [];
  const cliConsole = {log: () => undefined, error: (...values: unknown[]) => errors.push(...values)};
  let dbAccesses = 0;
  const cliRequire = Object.assign((name: string) => {
    if (name === "firebase-admin") return {firestore: {FieldPath: {documentId: () => "__name__"}}};
    if (name === "./common") {
      return {db: new Proxy({}, {get: () => {
        dbAccesses++;
        throw new Error("DB accessed before validation");
      }})};
    }
    if (name === "./wallStats") {
      return {FAVOURITE_AGGREGATION_GATE: "maintenance/favouriteAggregation", isPrismFavourite: () => true};
    }
    if (name === "./viewStats") return {normalizeId: (id: string) => id, WALLPAPER_STATS: "wallpaper_stats"};
    throw new Error(`Unexpected CLI dependency: ${name}`);
  }, {main: module});
  const wrapped = `(function (require, module, exports, process, console) { ${source}\n})`;
  runInNewContext(wrapped, {require: cliRequire, module, process: cliProcess,
    console: cliConsole})(cliRequire, module, module.exports, cliProcess, cliConsole);
  await new Promise<void>((resolve) => setImmediate(resolve));
  return {dbAccesses, errors, exitCode: cliProcess.exitCode};
}

test("CLI validates concurrency values before accessing Firestore", async () => {
  for (const value of ["NaN", ""]) {
    const result = await runCli(["--apply", "--epoch=offline", "--confirm-favourites-frozen", `--concurrency=${value}`]);
    assert.equal(result.dbAccesses, 0, `--concurrency=${value} must reject before DB access`);
    assert.equal(result.exitCode, 1);
    assert.match(String(result.errors[0]), /Invalid page bounds/);
  }
  const bare = await runCli(["--apply", "--epoch=offline", "--confirm-favourites-frozen", "--concurrency"]);
  assert.equal(bare.dbAccesses, 0, "bare --concurrency must reject before DB access");
  assert.equal(bare.exitCode, 1);
  assert.match(String(bare.errors[0]), /Invalid page bounds/);
  for (const args of [[], ["--concurrency=30"]]) {
    const result = await runCli(["--apply", "--epoch=offline", "--confirm-favourites-frozen", ...args]);
    assert.equal(result.dbAccesses, 1, "missing option defaults to 1 and 30 is within bounds");
    assert.equal(result.exitCode, 1);
    assert.match(String(result.errors[0]), /DB accessed before validation/);
  }
});

test("dry-run scans without changing legacy counts, ledger or rollout gate", async (t) => {
  const store = installFakeDb(t, {"wallpaper_stats/W1": {favs: 1}, "usersv2/u1/images/w1": fav("w1")});
  const before = new Map(store);
  const result = await backfillFavouriteContributions({apply: false});
  assert.equal(result.scanned, 1);
  assert.deepEqual(new Map(store), before);
});

test("apply refuses an unconfirmed freeze before any write", async (t) => {
  const store = installFakeDb(t);
  await assert.rejects(() => backfillFavouriteContributions({apply: true, epoch: "rollout-v1", favouritesFrozen: false}), /frozen/);
  assert.equal(store.size, 0);
});

test("bootstrap preserves an existing correct count on update and decrements its first deletion", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}, "wallpaper_stats/W1": {favs: 1, views: 9},
    "usersv2/u1/images/w1": fav("w1")});
  assert.equal((await apply()).phase, "ready");
  await deliver(fav("w1"), fav("w1"));
  await deliver(undefined, fav("w1"));
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get("wallpaper_stats/W1")?.views, 9);
  store.delete("usersv2/u1/images/w1");
  await deliver(fav("w1"), undefined);
  await deliver(fav("w1"), undefined);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 0);
  assert.equal([...store.keys()].some((key) => key.startsWith("wallpaper_stats_daily/")), false);
  assert.equal([...store.keys()].some((key) => key.startsWith("questEventRate/")), false);
});

test("resumable bootstrap deduplicates arbitrary-case aliases, includes orphan subcollections and clears empty legacy walls", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1/images/w1": fav("w1"), "usersv2/u1/images/W1": fav("W1", "WaLlOfThEdAy"),
    "usersv2/orphan/images/w1": fav("w1"), "usersv2/u2/images/w1": fav("target"),
    "usersv2/u3/images/w1": fav("w1", "Pexels"), "other/u1/images/w1": fav("w1"),
    "wallpaper_stats/W1": {favs: 99}, "wallpaper_stats/EMPTY": {favs: 5, downloads: 8},
  });
  await apply(1);
  assert.equal(store.get(GATE)?.phase, "scanning");
  await assert.rejects(() => deliver(fav("w1"), fav("w1")), /backfill/);
  assert.equal((await apply()).phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get("wallpaper_stats/EMPTY")?.favs, 0);
  assert.equal(store.get("wallpaper_stats/EMPTY")?.downloads, 8);
  const before = new Map(store);
  await apply();
  assert.deepEqual(new Map(store), before);
  await assert.rejects(() => backfillFavouriteContributions({apply: true, epoch: "other-run", favouritesFrozen: true}), /epoch|ready/);
});

test("a failed pair transaction resumes without a partial contribution or a repeated bootstrap increment", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/a/images/w1": fav("w1"), "usersv2/b/images/w1": fav("w1"),
  });
  await apply(1);
  const run = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const set = tx.set.bind(tx);
      tx.set = ((ref: admin.firestore.DocumentReference, ...args: unknown[]) => {
        if (fail && ref.path.includes("/favouriteBootstrap/")) throw new Error("bootstrap unavailable");
        return Reflect.apply(set, tx, [ref, ...args]);
      }) as typeof tx.set;
      return callback(tx);
    }));
  await assert.rejects(() => apply(), /bootstrap unavailable/);
  assert.equal(store.get(GATE)?.cursor, "usersv2/a/images/w1");
  assert.equal(store.has("wallpaper_stats/W1/favouriteContributions/b"), false);
  fail = false;
  await Promise.all([apply(), apply()]);
  assert.equal(store.get(GATE)?.phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get("wallpaper_stats/W1/favouriteBootstrap/rollout-v1")?.count, 2);
});

test("a failed publish checkpoint can replay absolute totals without double counting", async (t) => {
  const store = installFakeDb(t, {"usersv2/a/images/w1": fav("w1"), "wallpaper_stats/W1": {favs: 17}});
  const run = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const update = tx.update.bind(tx);
      tx.update = ((ref: admin.firestore.DocumentReference, data: admin.firestore.UpdateData<admin.firestore.DocumentData>) => {
        if (fail && ref.path === GATE && data.phase === "publishing" && data.cursor) {
          throw new Error("checkpoint unavailable");
        }
        return update(ref, data);
      }) as typeof tx.update;
      return callback(tx);
    }));
  await assert.rejects(() => apply(), /checkpoint unavailable/);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get(GATE)?.phase, "publishing");
  assert.equal(store.get(GATE)?.cursor, null);
  fail = false;
  assert.equal((await apply()).phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
});

test("a failed concurrent publish chunk replays absolute totals without double counting", async (t) => {
  const store = installFakeDb(t, {"usersv2/a/images/w1": fav("w1"), "usersv2/b/images/w2": fav("w2"),
    "wallpaper_stats/W1": {favs: 17}, "wallpaper_stats/W2": {favs: 23}});
  const run = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const set = tx.set.bind(tx);
      tx.set = ((ref: admin.firestore.DocumentReference, data: admin.firestore.UpdateData<admin.firestore.DocumentData>, ...args: unknown[]) => {
        if (fail && ref.path === "wallpaper_stats/W2" && "favs" in data && "favouriteEpoch" in data) {
          throw new Error("publish unavailable");
        }
        return Reflect.apply(set, tx, [ref, data, ...args]);
      }) as typeof tx.set;
      return callback(tx);
    }));
  const runApply = (concurrency: number) => backfillFavouriteContributions({apply: true, epoch: "rollout-v1",
    favouritesFrozen: true, pageSize: 100, maxPages: 100, concurrency});
  await assert.rejects(() => runApply(2), /publish unavailable/);
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get("wallpaper_stats/W2")?.favs, 23);
  assert.equal(store.get(GATE)?.phase, "publishing");
  assert.equal(store.get(GATE)?.cursor, null);
  fail = false;
  assert.equal((await runApply(2)).phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 1);
  assert.equal(store.get("wallpaper_stats/W2")?.favs, 1);
});

test("a serial partial page resumes concurrently in the same epoch", async (t) => {
  const store = installFakeDb(t, {"usersv2/a/images/w1": fav("w1"), "usersv2/b/images/w1": fav("w1")});
  const run = db.runTransaction.bind(db);
  let fail = true;
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const set = tx.set.bind(tx);
      tx.set = ((ref: admin.firestore.DocumentReference, ...args: unknown[]) => {
        if (fail && ref.path.endsWith("/favouriteContributions/b")) throw new Error("pair unavailable");
        return Reflect.apply(set, tx, [ref, ...args]);
      }) as typeof tx.set;
      return callback(tx);
    }));
  const runApply = (concurrency: number) => backfillFavouriteContributions({apply: true, epoch: "rollout-v1",
    favouritesFrozen: true, pageSize: 2, maxPages: 100, concurrency});
  await assert.rejects(() => runApply(1), /pair unavailable/);
  assert.equal(store.get(GATE)?.cursor, null);
  assert.equal(store.get("wallpaper_stats/W1/favouriteBootstrap/rollout-v1")?.count, 1);
  fail = false;
  assert.equal((await runApply(2)).phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get("wallpaper_stats/W1/favouriteBootstrap/rollout-v1")?.count, 2);
});

test("a rejected concurrent chunk holds its checkpoint while a sibling is in flight", async (t) => {
  const store = installFakeDb(t, {"usersv2/a/images/w1": fav("w1"), "usersv2/b/images/w1": fav("w1")});
  const run = db.runTransaction.bind(db);
  let calls = 0;
  let fail = true;
  let releaseSibling!: () => void;
  let siblingFinished!: () => void;
  const siblingGate = new Promise<void>((resolve) => {
    releaseSibling = resolve;
  });
  const siblingDone = new Promise<void>((resolve) => {
    siblingFinished = resolve;
  });
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    calls++;
    if (calls === 3) return siblingGate.then(() => run(callback)).finally(siblingFinished);
    return run(async (tx) => {
      const set = tx.set.bind(tx);
      tx.set = ((ref: admin.firestore.DocumentReference, ...args: unknown[]) => {
        if (fail && ref.path.endsWith("/favouriteContributions/a")) throw new Error("pair unavailable");
        return Reflect.apply(set, tx, [ref, ...args]);
      }) as typeof tx.set;
      return callback(tx);
    });
  });
  const runApply = () => backfillFavouriteContributions({apply: true, epoch: "rollout-v1",
    favouritesFrozen: true, pageSize: 2, maxPages: 100, concurrency: 2});
  await assert.rejects(() => runApply(), /pair unavailable/);
  assert.equal(store.get(GATE)?.cursor, null);
  assert.equal(store.has("wallpaper_stats/W1/favouriteContributions/b"), false);
  fail = false;
  assert.equal((await runApply()).phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get("wallpaper_stats/W1/favouriteBootstrap/rollout-v1")?.count, 2);
  const readyTotals = [store.get("wallpaper_stats/W1")?.favs,
    store.get("wallpaper_stats/W1/favouriteBootstrap/rollout-v1")?.count, store.get(GATE)?.phase];
  releaseSibling();
  await siblingDone;
  assert.deepEqual([store.get("wallpaper_stats/W1")?.favs,
    store.get("wallpaper_stats/W1/favouriteBootstrap/rollout-v1")?.count, store.get(GATE)?.phase], readyTotals);
});

test("concurrent apply inside a page gives the same totals as one document at a time", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1/images/w1": fav("w1"), "usersv2/u1/images/W1": fav("W1", "WaLlOfThEdAy"),
    "usersv2/u2/images/w1": fav("w1"), "usersv2/u2/images/w2": fav("w2"), "usersv2/u3/images/w2": fav("w2", "Pexels"),
    "wallpaper_stats/W1": {favs: 99}, "wallpaper_stats/EMPTY": {favs: 5},
  });
  const result = await backfillFavouriteContributions({
    apply: true, epoch: "rollout-v1", favouritesFrozen: true, pageSize: 100, maxPages: 100, concurrency: 10,
  });
  assert.equal(result.phase, "ready");
  assert.equal(store.get("wallpaper_stats/W1")?.favs, 2);
  assert.equal(store.get("wallpaper_stats/W2")?.favs, 1);
  assert.equal(store.get("wallpaper_stats/EMPTY")?.favs, 0);
  await assert.rejects(() => backfillFavouriteContributions({
    apply: true, epoch: "rollout-v1", favouritesFrozen: true, concurrency: 0,
  }), /bounds/);
});
