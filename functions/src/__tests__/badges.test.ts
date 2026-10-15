import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {AI_SPEND_SETTLE_MS, BADGES, badgeIo, checkBadges, evaluateBadges, isProfileComplete, settledCount, type BadgeFacts} from "../badges";

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

function fakeDb(
  t: test.TestContext, store: Store,
  counts: Record<string, number | ((filters: [string, unknown][]) => number)>,
  onTransactionRetry?: () => void,
  onCountQuery?: (collection: string, filters: [string, unknown][], limit: number | undefined) => void,
  onGetQuery?: (collection: string, limit: number | undefined) => void,
) {
  const docRef = (path: string) => ({path, get: async () => snapOf(path)});
  const snapOf = (path: string) => {
    const data = path.startsWith("usersv2/") ? store.user : path.startsWith("badgeCheckRate/") ? store.rate : undefined;
    const snapshot = data === undefined ? undefined : structuredClone(data);
    return {exists: snapshot !== undefined, data: () => snapshot};
  };
  t.mock.method(db, "collection", (name: string) => {
    const filters: [string, unknown][] = [];
    let queryLimit: number | undefined;
    const query: Record<string, unknown> = {
      doc: (id: string) => docRef(`${name}/${id}`),
      where: (field: string, _op: string, value: unknown) => {
        filters.push([field, value]);
        return query;
      },
      limit: (limit: number) => {
        queryLimit = limit;
        return query;
      },
      get: async () => {
        // coinTransactions rows: counts.coinTransactions = settled rows, counts["coinTransactions:fresh"] = fresh rows.
        onGetQuery?.(name, queryLimit);
        const nowMs = Date.now();
        const make = (n: number, ageMs: number) => Array.from({length: n}, () => ({
          get: (field: string) => field === "createdAt" ?
            admin.firestore.Timestamp.fromMillis(nowMs - ageMs) : undefined,
        }));
        const docs = [
          ...make(Number(counts[name] ?? 0), AI_SPEND_SETTLE_MS + 1000),
          ...make(Number(counts[`${name}:fresh`] ?? 0), 1000),
        ];
        return {docs: docs.slice(0, queryLimit ?? docs.length)};
      },
      count: () => ({get: async () => {
        onCountQuery?.(name, filters, queryLimit);
        const count = counts[name];
        const value = typeof count === "function" ? count(filters) : count ?? 0;
        return {data: () => ({count: Math.min(value, queryLimit ?? value)})};
      }}),
    };
    return query;
  });
  let transactionTail: Promise<void> = Promise.resolve();
  let transactionNumber = 0;
  t.mock.method(db, "runTransaction", async (cb: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const previous = transactionTail;
    let release!: () => void;
    transactionTail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    let result: unknown;
    const currentTransaction = transactionNumber++;
    try {
      for (let attempt = 0; attempt < (currentTransaction === 1 && onTransactionRetry ? 2 : 1); attempt++) {
        const writes: (() => void)[] = [];
        result = await cb({
          get: async (ref: {path: string}) => snapOf(ref.path),
          set: (ref: {path: string}, data: Record<string, unknown>) => writes.push(() => {
            if (ref.path.startsWith("badgeCheckRate/")) store.rate = data;
            else store.ledger[ref.path] = data;
          }),
          update: (_ref: unknown, data: Record<string, unknown>) => writes.push(() => Object.assign(store.user, data)),
        } as unknown as admin.firestore.Transaction);
        if (attempt === 0 && currentTransaction === 1 && onTransactionRetry) {
          onTransactionRetry();
        } else {
          writes.forEach((w) => w());
        }
      }
      return result;
    } finally {
      release();
    }
  });
}

const call = (uid = "u1", email = "a@b.c") =>
  checkBadges.run({auth: {uid, token: {email}}, data: {}} as Parameters<typeof checkBadges.run>[0]);

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

test("checkBadges: creator coins cannot be farmed with a forged profile email", async (t) => {
  const store = baseStore();
  store.user.coinState = {};
  store.user.email = "creator@example.com";
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  fakeDb(t, store, {walls: (filters) => filters.some(([field, value]) =>
    field === "email" && value === "attacker@example.com") ? 0 : 1});

  const result = await call("u1", "attacker@example.com");

  assert.deepEqual(result.newBadges, []);
  assert.equal(store.user.coins, 10);
  assert.deepEqual(store.ledger, {});
});

test("checkBadges: veteran age comes from Auth, not the client-writable profile date", async (t) => {
  const store = baseStore();
  store.user.coinState = {streakBest: 7};
  store.user.createdAt = "2010-01-01T00:00:00.000Z";
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  let lookedUpUid = "";
  t.mock.method(badgeIo, "accountCreatedMs", async (uid: string) => {
    lookedUpUid = uid;
    return now - 29 * 86_400_000;
  });
  fakeDb(t, store, {});

  const result = await call();

  assert.equal(lookedUpUid, "u1");
  assert.deepEqual(result.newBadges, [{id: "week_warrior", coins: 25}]);
});

test("checkBadges: transaction retry uses the latest server-owned streak", async (t) => {
  const store = baseStore();
  store.user.coinState = {};
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  t.mock.method(badgeIo, "accountCreatedMs", async () => 1_700_000_000_000);
  fakeDb(t, store, {}, () => {
    store.user.coinState = {streakBest: 7};
  });

  const result = await call();

  assert.deepEqual(result.newBadges, [{id: "week_warrior", coins: 25}]);
  assert.equal(store.user.coins, 35);
  assert.deepEqual(Object.keys(store.ledger), ["coinTransactions/ctx_badgeReward_u1_week_warrior"]);
});

test("checkBadges: a newly current 7-day streak uses Auth age for the veteran badge", async (t) => {
  const store = baseStore();
  store.user.coinState = {};
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  t.mock.method(badgeIo, "accountCreatedMs", async () => now - 40 * 86_400_000);
  fakeDb(t, store, {}, () => {
    store.user.coinState = {streakBest: 7};
  });

  const result = await call();

  assert.deepEqual(result.newBadges, [
    {id: "week_warrior", coins: 25},
    {id: "prism_veteran", coins: 75},
  ]);
  assert.equal(store.user.coins, 110);
});

test("checkBadges: a transaction retry does not trust an outdated streak snapshot", async (t) => {
  const store = baseStore();
  store.user.coinState = {streakBest: 7};
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  t.mock.method(badgeIo, "accountCreatedMs", async () => now);
  fakeDb(t, store, {}, () => {
    store.user.coinState = {streakBest: 0};
  });

  const result = await call();

  assert.deepEqual(result.newBadges, []);
  assert.equal(store.user.coins, 10);
  assert.deepEqual(store.ledger, {});
});

test("checkBadges: transaction retry does not repay a badge committed by a concurrent call", async (t) => {
  const store = baseStore();
  store.user.coinState = {streakBest: 7};
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  t.mock.method(badgeIo, "accountCreatedMs", async () => 1_700_000_000_000);
  fakeDb(t, store, {}, () => {
    store.user.coins = 35;
    store.user.badges = [{id: "week_warrior"}];
    store.ledger["coinTransactions/ctx_badgeReward_u1_week_warrior"] = {delta: 25};
  });

  const result = await call();

  assert.deepEqual(result.newBadges, []);
  assert.equal(result.currentBalance, 35);
  assert.equal(store.user.coins, 35);
  assert.deepEqual(Object.keys(store.ledger), ["coinTransactions/ctx_badgeReward_u1_week_warrior"]);
});

test("checkBadges: cooldown returns no awards and reads no counts", async (t) => {
  const store = baseStore();
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  store.rate = {lastAt: now - 30_000};
  const countQueries: string[] = [];
  fakeDb(t, store, {}, undefined, (collection) => countQueries.push(collection));
  const result = await call();
  assert.deepEqual(result.newBadges, []);
  assert.deepEqual(store.user.badges, []);
  assert.equal(store.user.coins, 10);
  assert.deepEqual(countQueries, []);
});

test("checkBadges: a badge earned during cooldown is awarded after the next eligible check", async (t) => {
  const store = baseStore();
  store.user.coinState = {streakBest: 6};
  let now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  t.mock.method(badgeIo, "accountCreatedMs", async () => now);
  const countQueries: string[] = [];
  fakeDb(t, store, {}, undefined, (collection) => countQueries.push(collection));

  const first = await call();
  assert.deepEqual(first.newBadges, []);
  assert.equal(countQueries.length, 2);

  store.user.coinState = {streakBest: 7};
  now += 30_000;
  const cooling = await call();
  assert.deepEqual(cooling.newBadges, []);
  assert.equal(countQueries.length, 2);

  now += 31_000;
  const eligible = await call();
  assert.deepEqual(eligible.newBadges, [{id: "week_warrior", coins: 25}]);
  assert.equal(countQueries.length, 4);
  assert.equal(store.user.coins, 35);
});

test("checkBadges: cooldown returns the current profile", async (t) => {
  const store = baseStore();
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  store.user.badges = [{id: "week_warrior"}];
  store.user.coins = 35;
  store.rate = {lastAt: now};
  fakeDb(t, store, {});

  const result = await call();

  assert.deepEqual(result.newBadges, []);
  assert.deepEqual(result.badges.map((badge) => badge.id), ["week_warrior"]);
  assert.equal(result.currentBalance, 35);
});

test("checkBadges: zero-coin badges add no coins and no ledger rows", async (t) => {
  const store = baseStore();
  store.user.coinState = {};
  store.user.following = Array.from({length: 10}, (_, i) => `f${i}@x.y`);
  store.user.profilePhoto = "https://x/p.png";
  store.user.username = "a";
  store.user.bio = "b";
  store.user.links = {web: "https://a"};
  t.mock.method(Date, "now", () => 1_700_000_000_000);
  fakeDb(t, store, {"usersv2/u1/images": 50});
  const result = await call();
  assert.deepEqual(result.newBadges, [
    {id: "collector", coins: 0},
    {id: "art_curator", coins: 0},
    {id: "social_butterfly", coins: 0},
    {id: "profile_complete", coins: 0},
  ]);
  assert.equal(store.user.coins, 10);
  assert.deepEqual(store.ledger, {});
});

test("checkBadges: aggregate counts are capped at each badge threshold", async (t) => {
  const store = baseStore();
  store.user.coinState = {streakBest: 7};
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  t.mock.method(badgeIo, "accountCreatedMs", async () => now);
  const limits: [string, number | undefined][] = [];
  const gets: [string, number | undefined][] = [];
  fakeDb(t, store, {"walls": 40, "coinTransactions": 40, "usersv2/u1/images": 100}, undefined,
    (collection, _filters, limit) => limits.push([collection, limit]),
    (collection, limit) => gets.push([collection, limit]));

  await call();

  assert.deepEqual(limits.sort(([a], [b]) => a.localeCompare(b)), [
    ["usersv2/u1/images", 50],
    ["walls", 1],
  ]);
  assert.deepEqual(gets, [["coinTransactions", 40]]);
  assert.equal(store.user.coins, 115);
});

test("checkBadges: already-owned badges skip their aggregate counts", async (t) => {
  const store = baseStore();
  store.user.badges = [
    {id: "creator"}, {id: "ai_artist"}, {id: "collector"}, {id: "art_curator"},
  ];
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  t.mock.method(badgeIo, "accountCreatedMs", async () => now);
  const countQueries: string[] = [];
  fakeDb(t, store, {}, undefined, (collection) => countQueries.push(collection));

  const result = await call();

  assert.deepEqual(result.newBadges, [{id: "week_warrior", coins: 25}, {id: "streak_master", coins: 100}]);
  assert.deepEqual(countQueries, []);
});

test("checkBadges: concurrent first checks reserve cooldown before aggregating", async (t) => {
  const store = baseStore();
  store.user.coinState = {streakBest: 7};
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  t.mock.method(badgeIo, "accountCreatedMs", async () => now);
  const countQueries: string[] = [];
  fakeDb(t, store, {}, undefined, (collection) => countQueries.push(collection));

  const results = await Promise.all([call(), call()]);

  assert.deepEqual(results.flatMap((result) => result.newBadges), [{id: "week_warrior", coins: 25}]);
  assert.deepEqual(countQueries.sort(), ["usersv2/u1/images", "walls"]);
  assert.equal(store.user.coins, 35);
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
  const original = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (cb: Parameters<typeof original>[0]) => {
    store.rate = {lastAt: now - 1_000};
    return (original as unknown as (c: unknown) => Promise<unknown>)(cb);
  });
  const result = await call();
  assert.deepEqual(result.newBadges, []);
  assert.deepEqual(store.user.badges, []);
});

test("AI spends count only once they are past the refund window", () => {
  const now = 10 * AI_SPEND_SETTLE_MS;
  const settled = now - AI_SPEND_SETTLE_MS;
  const fresh = now - AI_SPEND_SETTLE_MS + 1;
  assert.equal(settledCount([settled, settled - 5, fresh, Number.NaN], now), 2);
});

test("checkBadges: ai_artist needs 10 settled AI spends, fresh ones do not count", async (t) => {
  const now = 1_700_000_000_000;
  t.mock.method(Date, "now", () => now);
  const run = async (counts: Record<string, number>) => {
    const store = baseStore();
    store.user.coinState = {streakBest: 0};
    t.mock.restoreAll();
    t.mock.method(Date, "now", () => now);
    t.mock.method(badgeIo, "accountCreatedMs", async () => now);
    fakeDb(t, store, counts);
    return (await call()).newBadges.map((b) => b.id);
  };
  assert.ok(!(await run({"coinTransactions:fresh": 10})).includes("ai_artist"));
  assert.ok((await run({"coinTransactions": 10})).includes("ai_artist"));
});
