import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {DEFAULT_ECONOMY, resetEconomyCache, weekKey} from "../economy";
import {leaderboardEntries, runSnapshotLeaderboard} from "../leaderboard";
import {installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 14, 12);
const KEY = weekKey(NOW);
const OLD = "2026-01-01T00:00:00.000Z";

test("entries carry the shaped fields, the equipped frame and the rank from lifetime XP", () => {
  const entries = leaderboardEntries([
    {id: "a", data: {
      createdAt: OLD, name: "Ann", username: "ann", profilePhoto: "http://p/a.png", xp: 2100, xpWeek: {weekKey: KEY, xp: 300},
      cosmetics: {frame: "frame_ring"},
    }},
    {id: "b", data: {createdAt: OLD, name: " Bea ", username: "", xpWeek: {weekKey: KEY, xp: 120}, xp: 120}},
  ], DEFAULT_ECONOMY, NOW);
  assert.deepEqual(entries, [
    {uid: "a", name: "Ann", username: "ann", photo: "http://p/a.png", xp: 300, frame: "frame_ring", rank: "gold"},
    {uid: "b", name: "Bea", username: "", photo: "", xp: 120, frame: null, rank: "bronze"},
  ]);
});

test("deleted users are left out and the order is kept", () => {
  const entries = leaderboardEntries([
    {id: "a", data: {createdAt: OLD, xpWeek: {xp: 50}}},
    {id: "gone", data: {createdAt: OLD, deleted: true, xpWeek: {xp: 40}}},
    {id: "c", data: {createdAt: OLD, xpWeek: {xp: 30}}},
  ], DEFAULT_ECONOMY, NOW);
  assert.deepEqual(entries.map((e) => e.uid), ["a", "c"]);
});

test("accounts under 7 days old, or with no readable createdAt, are left out", () => {
  const day = 86_400_000;
  const entries = leaderboardEntries([
    {id: "old", data: {createdAt: new Date(NOW - 7 * day).toISOString()}},
    {id: "new", data: {createdAt: new Date(NOW - 6 * day).toISOString()}},
    {id: "none", data: {}},
    {id: "junk", data: {createdAt: "yesterday"}},
    {id: "ms", data: {createdAt: NOW - 30 * day}},
  ], DEFAULT_ECONOMY, NOW);
  assert.deepEqual(entries.map((e) => e.uid), ["old", "ms"]);
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

test("the snapshot queries the top 50 for this week and writes the week doc and current", async (t) => {
  resetEconomyCache();
  const store = installFakeDb(t);
  const asked = stubUsersQuery(t, [
    {id: "a", data: {createdAt: OLD, name: "Ann", xp: 600, xpWeek: {weekKey: KEY, xp: 300}, cosmetics: {frame: "frame_ring"}}},
    {id: "gone", data: {createdAt: OLD, deleted: true, xpWeek: {weekKey: KEY, xp: 200}}},
    {id: "b", data: {createdAt: OLD, name: "Bea", username: "bea", xp: 100, xpWeek: {weekKey: KEY, xp: 100}}},
  ]);
  await runSnapshotLeaderboard(NOW);
  assert.deepEqual(asked, [
    ["where", "xpWeek.weekKey", "==", KEY],
    ["orderBy", "xpWeek.xp", "desc"],
    ["limit", 50],
  ]);
  const week = store.get(`leaderboards/${KEY}`);
  assert.equal(week?.weekKey, KEY);
  assert.ok((week?.updatedAt as admin.firestore.Timestamp).toMillis() === NOW);
  assert.deepEqual((week?.entries as Array<{uid: string; rank: string; frame: string | null}>)
    .map((e) => [e.uid, e.rank, e.frame]), [["a", "silver", "frame_ring"], ["b", "bronze", null]]);
  assert.deepEqual(store.get("leaderboards/current"), week);
});
