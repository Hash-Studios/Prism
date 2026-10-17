import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {DEFAULT_ECONOMY, resetEconomyCache, weekKey} from "../economy";
import {leaderboardEntries, leaderboardIo, runSnapshotLeaderboard} from "../leaderboard";
import {installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 14, 12);
const KEY = weekKey(NOW);
const DAY = 86_400_000;
const OLD = NOW - 30 * DAY;
const aged = (...uids: string[]) => new Map(uids.map((uid) => [uid, OLD]));

test("entries carry the shaped fields, the equipped frame and the rank from lifetime XP", () => {
  const entries = leaderboardEntries([
    {id: "a", data: {
      name: "Ann", username: "ann", profilePhoto: "http://p/a.png", xp: 2100, xpWeek: {weekKey: KEY, xp: 300},
      cosmetics: {frame: "frame_ring"}, premium: true,
    }},
    {id: "b", data: {name: " Bea ", username: "", xpWeek: {weekKey: KEY, xp: 120}, xp: 120}},
  ], aged("a", "b"), DEFAULT_ECONOMY, NOW);
  assert.deepEqual(entries, [
    {uid: "a", name: "Ann", username: "ann", photo: "http://p/a.png", xp: 300, frame: "frame_ring", rank: "gold", premium: true},
    {uid: "b", name: "Bea", username: "", photo: "", xp: 120, frame: null, rank: "bronze", premium: false},
  ]);
});

test("deleted users are left out and the order is kept", () => {
  const entries = leaderboardEntries([
    {id: "a", data: {xpWeek: {xp: 50}}},
    {id: "gone", data: {deleted: true, xpWeek: {xp: 40}}},
    {id: "c", data: {xpWeek: {xp: 30}}},
  ], aged("a", "gone", "c"), DEFAULT_ECONOMY, NOW);
  assert.deepEqual(entries.map((e) => e.uid), ["a", "c"]);
});

test("account age comes from Auth: under 7 days, unknown or unreadable is left out; a client createdAt is ignored", () => {
  const created = new Map([["old", NOW - 7 * DAY], ["new", NOW - 6 * DAY], ["junk", Number.NaN], ["fake", NOW - DAY]]);
  const entries = leaderboardEntries([
    {id: "old", data: {}},
    {id: "new", data: {}},
    {id: "none", data: {createdAt: "2020-01-01T00:00:00.000Z"}},
    {id: "junk", data: {}},
    {id: "fake", data: {createdAt: "2020-01-01T00:00:00.000Z"}},
  ], created, DEFAULT_ECONOMY, NOW);
  assert.deepEqual(entries.map((e) => e.uid), ["old"]);
});

test("at most 50 entries are kept after the filter", () => {
  const docs = Array.from({length: 100}, (_, i) => ({id: `u${i}`, data: {deleted: i % 2 === 0}}));
  const entries = leaderboardEntries(docs, aged(...docs.map((d) => d.id)), DEFAULT_ECONOMY, NOW);
  assert.equal(entries.length, 50);
  assert.equal(entries[0].uid, "u1");
  assert.equal(entries[49].uid, "u99");
});

// fakeDb filters on top-level fields only, so the xpWeek query is answered here.
function stubUsersQuery(t: TestContext, rows: Array<{id: string; data: Record<string, unknown>}>) {
  const asked: unknown[][] = [];
  const collection = db.collection as unknown as (name: string) => Record<string, unknown>;
  t.mock.method(db, "collection", (name: string) => {
    if (name !== "usersv2") return collection(name);
    const q = {
      where: (...args: unknown[]) => {
        asked.push(["where", ...args]);
        return q;
      },
      orderBy: (...args: unknown[]) => {
        asked.push(["orderBy", ...args]);
        return q;
      },
      limit: (n: number) => {
        asked.push(["limit", n]);
        return q;
      },
      get: async () => ({docs: rows.map((r) => ({id: r.id, data: () => r.data}))}),
    };
    return q;
  });
  return asked;
}

test("the snapshot queries 100 candidates for this week and writes the week doc and current", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t);
  const asked = stubUsersQuery(t, [
    {id: "a", data: {name: "Ann", xp: 600, xpWeek: {weekKey: KEY, xp: 300}, cosmetics: {frame: "frame_ring"}}},
    {id: "gone", data: {deleted: true, xpWeek: {weekKey: KEY, xp: 200}}},
    {id: "b", data: {name: "Bea", username: "bea", xp: 100, xpWeek: {weekKey: KEY, xp: 100}}},
  ]);
  const authAsked: string[][] = [];
  t.mock.method(leaderboardIo, "accountCreatedMs", async (uids: string[]) => {
    authAsked.push(uids);
    return aged(...uids);
  });
  await runSnapshotLeaderboard(NOW);
  assert.deepEqual(asked, [
    ["where", "xpWeek.weekKey", "==", KEY],
    ["orderBy", "xpWeek.xp", "desc"],
    ["limit", 100],
  ]);
  assert.deepEqual(authAsked, [["a", "b"]]);
  const week = store.get(`leaderboards/${KEY}`);
  assert.equal(week?.weekKey, KEY);
  assert.ok((week?.updatedAt as admin.firestore.Timestamp).toMillis() === NOW);
  assert.deepEqual((week?.entries as Array<{uid: string; rank: string; frame: string | null}>)
    .map((e) => [e.uid, e.rank, e.frame]), [["a", "silver", "frame_ring"], ["b", "bronze", null]]);
  assert.deepEqual(store.get("leaderboards/current"), week);
});

test("accountCreatedMs asks Auth in chunks of 100 and skips unknown uids", async (t) => {
  const batches: number[] = [];
  t.mock.method(admin.auth(), "getUsers", async (ids: Array<{uid: string}>) => {
    batches.push(ids.length);
    return {
      users: ids.filter(({uid}) => uid !== "u3").map(({uid}) => ({uid, metadata: {creationTime: new Date(OLD).toUTCString()}})),
      notFound: [],
    };
  });
  const uids = Array.from({length: 150}, (_, i) => `u${i}`);
  const created = await leaderboardIo.accountCreatedMs(uids);
  assert.deepEqual(batches, [100, 50]);
  assert.equal(created.size, 149);
  assert.equal(created.get("u0"), OLD);
  assert.equal(created.has("u3"), false);
});
