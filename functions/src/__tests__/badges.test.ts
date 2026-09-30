import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {BADGES, badgeIo, checkBadges, evaluateBadges, isProfileComplete, type BadgeFacts} from "../badges";

const NONE: BadgeFacts = {
  streakBest: 0, approvedWalls: 0, aiSpends: 0, accountAgeDays: 0, favourites: 0, following: 0, profileComplete: false,
};
const earns = (facts: Partial<BadgeFacts>) => evaluateBadges({...NONE, ...facts});

test("evaluateBadges: nothing earned from empty facts", () => {
  assert.deepEqual(earns({}), []);
});

test("evaluateBadges: streak thresholds 7 and 28", () => {
  assert.deepEqual(earns({streakBest: 6}), []);
  assert.deepEqual(earns({streakBest: 7}), ["week_warrior"]);
  assert.deepEqual(earns({streakBest: 27}), ["week_warrior"]);
  assert.deepEqual(earns({streakBest: 28}), ["week_warrior", "streak_master"]);
});

test("evaluateBadges: creator needs one approved wall", () => {
  assert.deepEqual(earns({approvedWalls: 0}), []);
  assert.deepEqual(earns({approvedWalls: 1}), ["creator"]);
});

test("evaluateBadges: ai artist needs 10 spends", () => {
  assert.deepEqual(earns({aiSpends: 9}), []);
  assert.deepEqual(earns({aiSpends: 10}), ["ai_artist"]);
});

test("evaluateBadges: veteran needs 30 days and a 7 day streak", () => {
  assert.deepEqual(earns({accountAgeDays: 29, streakBest: 7}), ["week_warrior"]);
  assert.deepEqual(earns({accountAgeDays: 30, streakBest: 6}), []);
  assert.deepEqual(earns({accountAgeDays: 30, streakBest: 7}), ["week_warrior", "prism_veteran"]);
});

test("evaluateBadges: favourites thresholds 10 and 50", () => {
  assert.deepEqual(earns({favourites: 9}), []);
  assert.deepEqual(earns({favourites: 10}), ["collector"]);
  assert.deepEqual(earns({favourites: 49}), ["collector"]);
  assert.deepEqual(earns({favourites: 50}), ["collector", "art_curator"]);
});

test("evaluateBadges: social butterfly needs 10 follows", () => {
  assert.deepEqual(earns({following: 9}), []);
  assert.deepEqual(earns({following: 10}), ["social_butterfly"]);
});

test("evaluateBadges: profile complete flag", () => {
  assert.deepEqual(earns({profileComplete: true}), ["profile_complete"]);
});

test("isProfileComplete: needs photo, username, bio and a link", () => {
  const ok = {profilePhoto: "https://x/p.png", username: "a", bio: "b", links: {web: "https://a"}};
  assert.equal(isProfileComplete(ok), true);
  assert.equal(isProfileComplete({...ok, profilePhoto: ""}), false);
  assert.equal(isProfileComplete({...ok, username: " "}), false);
  assert.equal(isProfileComplete({...ok, bio: ""}), false);
  assert.equal(isProfileComplete({...ok, links: {web: " "}}), false);
  assert.equal(isProfileComplete({...ok, links: undefined}), false);
  assert.equal(isProfileComplete({...ok, profilePhoto: "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers." +
    "appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4"}), false);
});

test("coin badges are only the server-backed ones", () => {
  const coinIds = BADGES.filter((b) => b.coins > 0).map((b) => b.id).sort();
  assert.deepEqual(coinIds, ["ai_artist", "creator", "prism_veteran", "streak_master", "week_warrior"]);
});

// ---- checkBadges with a fake Firestore ----

interface Store {
  user: Record<string, unknown>;
  rate: Record<string, unknown> | undefined;
  ledger: Record<string, Record<string, unknown>>;
}

function fakeDb(t: test.TestContext, store: Store, counts: Record<string, number>) {
  const docRef = (path: string) => ({path, get: async () => snapOf(path)});
  const snapOf = (path: string) => {
    const data = path.startsWith("usersv2/") ? store.user : path.startsWith("badgeCheckRate/") ? store.rate : undefined;
    return {exists: data !== undefined, data: () => data};
  };
  t.mock.method(db, "collection", (name: string) => {
    const query: Record<string, unknown> = {
      doc: (id: string) => docRef(`${name}/${id}`),
      where: () => query,
      limit: () => query,
      count: () => ({get: async () => ({data: () => ({count: counts[name] ?? 0})})}),
    };
    return query;
  });
  t.mock.method(db, "runTransaction", async (cb: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const writes: (() => void)[] = [];
    await cb({
      get: async (ref: {path: string}) => snapOf(ref.path),
      set: (ref: {path: string}, data: Record<string, unknown>) => writes.push(() => {
        if (ref.path.startsWith("badgeCheckRate/")) store.rate = data;
        else store.ledger[ref.path] = data;
      }),
      update: (_ref: unknown, data: Record<string, unknown>) => writes.push(() => Object.assign(store.user, data)),
    } as unknown as admin.firestore.Transaction);
    writes.forEach((w) => w());
  });
}

const call = (uid = "u1") => checkBadges.run({auth: {uid}, data: {}} as Parameters<typeof checkBadges.run>[0]);

function baseStore(): Store {
  return {
    user: {
      email: "a@b.c", coins: 10, badges: [], following: [],
      coinState: {streakBest: 30, streakCount: 3},
    },
    rate: undefined,
    ledger: {},
  };
}

test("checkBadges: requires auth", async () => {
  await assert.rejects(() => checkBadges.run({data: {}} as Parameters<typeof checkBadges.run>[0]), {code: "unauthenticated"});
});

test("checkBadges: awards coin badges once, credits coins and writes the ledger", async (t) => {
  const store = baseStore();
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  fakeDb(t, store, {});
  t.mock.method(badgeIo, "accountCreatedMs", async () => 1_700_000_000_000 - 40 * 86_400_000);

  const first = await call();
  assert.deepEqual(first.newBadges, [
    {id: "week_warrior", coins: 25},
    {id: "streak_master", coins: 100},
    {id: "prism_veteran", coins: 75},
  ]);
  assert.equal(first.currentBalance, 210);
  assert.equal(store.user.coins, 210);
  assert.deepEqual((store.user.badges as {id: string}[]).map((b) => b.id), ["week_warrior", "streak_master", "prism_veteran"]);
  assert.deepEqual(Object.keys(store.ledger).sort(), [
    "coinTransactions/ctx_badgeReward_u1_prism_veteran",
    "coinTransactions/ctx_badgeReward_u1_streak_master",
    "coinTransactions/ctx_badgeReward_u1_week_warrior",
  ]);
  const ledger = store.ledger["coinTransactions/ctx_badgeReward_u1_streak_master"];
  assert.equal(ledger.delta, 100);
  assert.equal(ledger.balanceBefore, 35);
  assert.equal(ledger.balanceAfter, 135);
  assert.equal(ledger.action, "badgeReward");

  // Second call after the cooldown awards nothing and keeps the list intact.
  t.mock.method(Date, "now", () => 1_700_000_000_000 + 61_000);
  const second = await call();
  assert.deepEqual(second.newBadges, []);
  assert.equal(second.badges.length, 3);
  assert.equal(store.user.coins, 210);
  assert.equal(Object.keys(store.ledger).length, 3);
});

test("checkBadges: cooldown returns no awards and reads no counts", async (t) => {
  const store = baseStore();
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  store.rate = {lastAt: now - 30_000};
  fakeDb(t, store, {});
  const result = await call();
  assert.deepEqual(result.newBadges, []);
  assert.deepEqual(store.user.badges, []);
  assert.equal(store.user.coins, 10);
});

test("checkBadges: zero-coin badges add no coins and no ledger rows", async (t) => {
  const store = baseStore();
  store.user.coinState = {};
  store.user.following = Array.from({length: 10}, (_, i) => `f${i}@x.y`);
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  fakeDb(t, store, {});
  const result = await call();
  assert.deepEqual(result.newBadges, [{id: "social_butterfly", coins: 0}]);
  assert.equal(store.user.coins, 10);
  assert.deepEqual(store.ledger, {});
});

test("checkBadges: never duplicates or removes existing badges", async (t) => {
  const store = baseStore();
  store.user.badges = [{id: "week_warrior"}, {id: "legacy_custom"}];
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  fakeDb(t, store, {});
  t.mock.method(badgeIo, "accountCreatedMs", async () => 1_700_000_000_000);
  const result = await call();
  assert.deepEqual(result.newBadges, [{id: "streak_master", coins: 100}]);
  assert.deepEqual((store.user.badges as {id: string}[]).map((b) => b.id), ["week_warrior", "legacy_custom", "streak_master"]);
});

test("checkBadges: a concurrent call that lost the race awards nothing", async (t) => {
  const store = baseStore();
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  fakeDb(t, store, {});
  t.mock.method(badgeIo, "accountCreatedMs", async () => now);
  // Another call sets the cooldown after this call's pre-read but before its transaction.
  const original = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (cb: Parameters<typeof original>[0]) => {
    store.rate = {lastAt: now - 1_000};
    return (original as unknown as (c: unknown) => Promise<unknown>)(cb);
  });
  const result = await call();
  assert.deepEqual(result.newBadges, []);
  assert.deepEqual(store.user.badges, []);
});
