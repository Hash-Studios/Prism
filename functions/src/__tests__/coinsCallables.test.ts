import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  awardCoins,
  buyStreakFreeze,
  duplicateSpendResponse,
  processReferral,
  isValidRequestId,
  planFreezePurchase,
  refundableDelta,
  restoreStreak,
  rewardedAdAllowed,
  spendCoins,
  STREAK_RESCUE_COST,
} from "../coinsCallables";

const NOW = 1_700_000_000_000;

function debitFixture(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    userId: "user-1",
    type: "debit",
    action: "wallpaperDownload",
    status: "completed",
    delta: -15,
    createdAt: {toMillis: () => NOW - 60_000},
    ...overrides,
  };
}

test("refundableDelta: happy path returns the absolute debited amount", () => {
  assert.equal(refundableDelta(debitFixture(), "user-1", NOW), 15);
});

test("refundableDelta: rejects a missing debit doc", () => {
  assert.throws(() => refundableDelta(undefined, "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects when the caller does not own the debit", () => {
  assert.throws(() => refundableDelta(debitFixture({userId: "someone-else"}), "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects a credit transaction", () => {
  assert.throws(() => refundableDelta(debitFixture({type: "credit"}), "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects an already-refunded debit", () => {
  assert.throws(() => refundableDelta(debitFixture({status: "refunded"}), "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: rejects a debit older than the refund window", () => {
  const old = debitFixture({createdAt: {toMillis: () => NOW - 600_001}});
  assert.throws(() => refundableDelta(old, "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: allows a debit right at the edge of the refund window", () => {
  const edge = debitFixture({createdAt: {toMillis: () => NOW - 600_000}});
  assert.equal(refundableDelta(edge, "user-1", NOW), 15);
});

test("rewardedAdAllowed: allows the 20th claim of the day", () => {
  assert.equal(rewardedAdAllowed({count: 19, lastAt: NOW - 25_000}, NOW), true);
});

test("rewardedAdAllowed: blocks the 21st claim of the day", () => {
  assert.equal(rewardedAdAllowed({count: 20, lastAt: NOW - 25_000}, NOW), false);
});

test("rewardedAdAllowed: blocks a claim only 19s after the last one", () => {
  assert.equal(rewardedAdAllowed({count: 1, lastAt: NOW - 19_000}, NOW), false);
});

test("rewardedAdAllowed: allows a claim 21s after the last one", () => {
  assert.equal(rewardedAdAllowed({count: 1, lastAt: NOW - 21_000}, NOW), true);
});

test("rewardedAdAllowed: allows the first claim with no prior state", () => {
  assert.equal(rewardedAdAllowed({}, NOW), true);
});

test("planFreezePurchase: debits 50 and adds a freeze", () => {
  assert.deepEqual(planFreezePurchase(120, 0), {current: 70, freezes: 1});
});

test("planFreezePurchase: rejects a balance of 49", () => {
  assert.deepEqual(planFreezePurchase(49, 0), {insufficientBalance: true});
});

test("planFreezePurchase: rejects at the cap even with a high balance", () => {
  assert.deepEqual(planFreezePurchase(10_000, 2), {atCap: true});
});

test("planFreezePurchase: has no premium input, so premium users still pay", () => {
  assert.equal(planFreezePurchase.length, 2);
  assert.deepEqual(planFreezePurchase(50, 1), {current: 0, freezes: 2});
});

test("planFreezePurchase: a second purchase on the post-first state at cap is rejected", () => {
  const first = planFreezePurchase(200, 1);
  assert.deepEqual(first, {current: 150, freezes: 2});
  if (!("current" in first)) throw new Error("expected success");
  assert.deepEqual(planFreezePurchase(first.current, first.freezes), {atCap: true});
});

test("isValidRequestId: rejects empty, oversize and bad characters", () => {
  assert.equal(isValidRequestId(""), false);
  assert.equal(isValidRequestId("short"), false);
  assert.equal(isValidRequestId("a".repeat(65)), false);
  assert.equal(isValidRequestId("has space 123"), false);
  assert.equal(isValidRequestId("bad/char_12345"), false);
  assert.equal(isValidRequestId(12345678), false);
  assert.equal(isValidRequestId("abc-DEF_1234"), true);
  assert.equal(isValidRequestId("a".repeat(64)), true);
});

for (const retry of ["duplicate", "cap", "balance"] as const) {
  test(`buyStreakFreeze: retry ending in ${retry} discards the first attempt's purchase`, async (t) => {
    const committedWrites: unknown[] = [];
    const finalFreezes = retry === "cap" ? 2 : 1;
    const finalBalance = retry === "balance" ? 0 : 70;
    t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
      for (let attempt = 0; attempt < 2; attempt++) {
        let reads = 0;
        await callback({
          get: async () => reads++ === 0 ? {
            exists: true,
            data: () => ({coins: attempt === 0 ? 120 : finalBalance,
              coinState: {streakFreezes: attempt === 0 ? 0 : finalFreezes}}),
          } : {exists: attempt === 1 && retry === "duplicate"},
          update: (_ref: unknown, data: unknown) => {
            if (attempt === 1) committedWrites.push(data);
          },
          set: (_ref: unknown, data: unknown) => {
            if (attempt === 1) committedWrites.push(data);
          },
        } as unknown as admin.firestore.Transaction);
      }
    });
    const result = await buyStreakFreeze.run({
      auth: {uid: "user-1"}, data: {requestId: "request_123"},
    } as Parameters<typeof buyStreakFreeze.run>[0]);
    assert.equal(result.success, retry === "duplicate");
    assert.equal(result.changed, false);
    assert.equal(result.delta, 0);
    assert.equal(result.atCap, retry === "cap");
    assert.equal(result.insufficientBalance, retry === "balance");
    assert.equal(result.currentBalance, finalBalance);
    assert.equal(result.streakFreezes, finalFreezes);
    assert.deepEqual(committedWrites, []);
  });
}

test("refundableDelta: only the download and AI generation debits are refundable", () => {
  for (const action of ["premiumFilter", "premiumPreview24h", "rewardedAd", undefined]) {
    assert.throws(() => refundableDelta(debitFixture({action}), "user-1", NOW), {code: "failed-precondition"});
  }
  for (const action of ["wallpaperDownload", "premiumWallpaperDownload", "aiGeneration"]) {
    assert.equal(refundableDelta(debitFixture({action}), "user-1", NOW), 15);
  }
});

test("refundableDelta: a streak freeze purchase is never refundable", () => {
  const freeze = debitFixture({action: "streakFreeze", delta: -50});
  assert.throws(() => refundableDelta(freeze, "user-1", NOW), {code: "failed-precondition"});
});

test("buyStreakFreeze validates auth and requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  await assert.rejects(() => buyStreakFreeze.run({
    data: {requestId: "request_123"},
  } as Parameters<typeof buyStreakFreeze.run>[0]), {code: "unauthenticated"});
  for (const requestId of [undefined, null, 12345678, "short", "a".repeat(65), "bad/path_123"]) {
    await assert.rejects(() => buyStreakFreeze.run({
      auth: {uid: "user-1"}, data: {requestId},
    } as Parameters<typeof buyStreakFreeze.run>[0]), {code: "invalid-argument"});
  }
});

test("buyStreakFreeze commits its debit and freeze together and replay cannot debit twice", async (t) => {
  let coins = 120;
  let freezes = 0;
  let ledger: Record<string, unknown> | undefined;
  const writes: string[] = [];
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    let reads = 0;
    await callback({
      get: async () => reads++ === 0 ? {
        exists: true, data: () => ({coins, premium: true, coinState: {streakFreezes: freezes}}),
      } : {exists: ledger != null},
      update: (ref: admin.firestore.DocumentReference, data: Record<string, number>) => {
        writes.push(ref.path);
        coins = data.coins;
        freezes = data["coinState.streakFreezes"];
      },
      set: (ref: admin.firestore.DocumentReference, data: Record<string, unknown>) => {
        writes.push(ref.path);
        ledger = data;
      },
    } as unknown as admin.firestore.Transaction);
  });
  const request = {
    auth: {uid: "user-1"}, data: {requestId: "request_123", amount: 0, freezes: 999, allowPremiumBypass: true},
  } as unknown as Parameters<typeof buyStreakFreeze.run>[0];
  const purchase = await buyStreakFreeze.run(request);
  assert.equal(purchase.changed, true);
  assert.equal(coins, 70);
  assert.equal(freezes, 1);
  assert.deepEqual(writes, ["usersv2/user-1", "coinTransactions/ctx_streakFreeze_user-1_request_123"]);
  assert.ok(ledger);
  assert.deepEqual(ledger, {
    id: "ctx_streakFreeze_user-1_request_123",
    userId: "user-1",
    createdAt: ledger.createdAt,
    updatedAt: ledger.createdAt,
    delta: -50,
    balanceBefore: 120,
    balanceAfter: 70,
    action: "streakFreeze",
    description: "Streak freeze",
    sourceTag: "coins.buy_streak_freeze.callable",
    reason: "streak_freeze_purchase",
    status: "completed",
    type: "debit",
  });
  const replay = await buyStreakFreeze.run(request);
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.delta, 0);
  assert.equal(coins, 70);
  assert.equal(freezes, 1);
  assert.equal(writes.length, 2);
});

interface SpendHarness {
  coins: number;
  premium?: boolean;
  ledger: Map<string, Record<string, unknown>>;
}

function mockSpendTransactions(t: test.TestContext, harness: SpendHarness): void {
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    await callback({
      get: async (ref: admin.firestore.DocumentReference) => {
        if (ref.path.startsWith("usersv2/")) {
          return {exists: true, data: () => ({coins: harness.coins, premium: harness.premium})};
        }
        const doc = harness.ledger.get(ref.id);
        return {exists: doc != null, data: () => doc};
      },
      update: (_ref: admin.firestore.DocumentReference, data: Record<string, number>) => {
        harness.coins = data.coins;
      },
      set: (ref: admin.firestore.DocumentReference, data: Record<string, unknown>) => {
        harness.ledger.set(ref.id, data);
      },
    } as unknown as admin.firestore.Transaction);
  });
}

function spendRequest(data: Record<string, unknown>): Parameters<typeof spendCoins.run>[0] {
  return {
    auth: {uid: "user-1"},
    data: {action: "wallpaperDownload", sourceTag: "test", ...data},
  } as unknown as Parameters<typeof spendCoins.run>[0];
}

test("spendCoins with a requestId debits once and a repeat returns the original result", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const first = await spendCoins.run(spendRequest({requestId: "request_123"}));
  assert.equal(first.changed, true);
  assert.equal(first.delta, -5);
  assert.equal(first.transactionId, "spend_user-1_request_123");
  assert.equal(harness.coins, 95);
  const repeat = await spendCoins.run(spendRequest({requestId: "request_123"}));
  assert.equal(repeat.success, true);
  assert.equal(repeat.changed, true);
  assert.equal(repeat.delta, -5);
  assert.equal(repeat.previousBalance, 100);
  assert.equal(repeat.currentBalance, 95);
  assert.equal(repeat.transactionId, "spend_user-1_request_123");
  assert.equal(harness.coins, 95);
  assert.equal(harness.ledger.size, 1);
  await spendCoins.run(spendRequest({requestId: "request_456"}));
  assert.equal(harness.coins, 90);
});

test("spendCoins without a requestId still works and each call debits", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  await spendCoins.run(spendRequest({}));
  await spendCoins.run(spendRequest({}));
  assert.equal(harness.coins, 90);
});

test("spendCoins rejects a malformed requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  for (const requestId of ["short", "a".repeat(65), "bad/path_123", 12345678]) {
    await assert.rejects(() => spendCoins.run(spendRequest({requestId})), {code: "invalid-argument"});
  }
});

test("spendCoins caps reason at 200 characters", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const result = await spendCoins.run(spendRequest({reason: "r".repeat(500)}));
  assert.equal(result.reason.length, 200);
  const [entry] = [...harness.ledger.values()];
  assert.equal((entry.reason as string).length, 200);
});

test("awardCoins caps reason at 200 characters", async (t) => {
  let ledger: Record<string, unknown> | undefined;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    await callback({
      get: async () => ({exists: true, data: () => ({coins: 0, premium: true, coinState: {}}), id: "x"}),
      update: () => undefined,
      set: (_ref: admin.firestore.DocumentReference, data: Record<string, unknown>) => {
        ledger = data;
      },
    } as unknown as admin.firestore.Transaction);
  });
  const result = await awardCoins.run({
    auth: {uid: "user-1"},
    data: {action: "proDailyBonus", sourceTag: "test", reason: "r".repeat(500)},
  } as unknown as Parameters<typeof awardCoins.run>[0]);
  assert.equal(result.changed, true);
  assert.equal(result.reason.length, 200);
  assert.equal((ledger?.reason as string).length, 200);
});

test("duplicateSpendResponse falls back to the live balance when the ledger lacks balances", () => {
  const result = duplicateSpendResponse({bypassed: false}, {id: "spend_1"}, 40, "why");
  assert.equal(result.currentBalance, 40);
  assert.equal(result.previousBalance, 40);
  assert.equal(result.delta, 0);
  assert.equal(result.transactionId, "spend_1");
});

test("refundableDelta: an unreadable delta is not refundable", () => {
  for (const delta of [undefined, "abc", Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.equal(refundableDelta(debitFixture({delta}), "user-1", NOW), null);
  }
});

test("refundableDelta: a longer window lets an older debit through", () => {
  const old = debitFixture({createdAt: {toMillis: () => NOW - 7_200_000}});
  assert.throws(() => refundableDelta(old, "user-1", NOW), {code: "failed-precondition"});
  assert.equal(refundableDelta(old, "user-1", NOW, 86_400_000), 15);
});

test("spendCoins: a replay of a refunded requestId is refused and never debits again", async (t) => {
  const harness: SpendHarness = {
    coins: 100,
    ledger: new Map([["spend_user-1_request_123", {id: "spend_user-1_request_123", status: "refunded", delta: -5}]]),
  };
  mockSpendTransactions(t, harness);
  const replay = await spendCoins.run(spendRequest({requestId: "request_123"}));
  assert.equal(replay.success, false);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "spend_refunded");
  assert.equal(replay.currentBalance, 100);
  assert.equal(harness.coins, 100);
});

test("spendCoins: a premium member skips the cost of a download only when asking to bypass", async (t) => {
  const harness: SpendHarness = {coins: 100, premium: true, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const bypassed = await spendCoins.run(spendRequest({allowPremiumBypass: true}));
  assert.equal(bypassed.success, true);
  assert.equal(bypassed.bypassed, true);
  assert.equal(harness.coins, 100);
  assert.equal(harness.ledger.size, 0);
  const charged = await spendCoins.run(spendRequest({}));
  assert.equal(charged.changed, true);
  assert.equal(harness.coins, 95);
});

test("spendCoins: a caller who is not premium is charged even with allowPremiumBypass", async (t) => {
  const harness: SpendHarness = {coins: 100, premium: false, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const result = await spendCoins.run(spendRequest({allowPremiumBypass: true}));
  assert.equal(result.bypassed, false);
  assert.equal(result.changed, true);
  assert.equal(harness.coins, 95);
  assert.equal(harness.ledger.size, 1);
});

test("spendCoins: allowPremiumBypass is ignored for aiGeneration, so a premium member is debited", async (t) => {
  const harness: SpendHarness = {coins: 200, premium: true, ledger: new Map()};
  mockSpendTransactions(t, harness);
  const result = await spendCoins.run(spendRequest({action: "aiGeneration", amount: 75, allowPremiumBypass: true}));
  assert.equal(result.success, true);
  assert.equal(result.bypassed, false);
  assert.equal(result.delta, -75);
  assert.equal(harness.coins, 125);
  assert.equal(harness.ledger.size, 1);
});

test("spendCoins: allowPremiumBypass still works for premiumWallpaperDownload and premiumFilter", async (t) => {
  const harness: SpendHarness = {coins: 100, premium: true, ledger: new Map()};
  mockSpendTransactions(t, harness);
  for (const action of ["premiumWallpaperDownload", "premiumFilter"]) {
    const result = await spendCoins.run(spendRequest({action, allowPremiumBypass: true}));
    assert.equal(result.bypassed, true, action);
  }
  assert.equal(harness.coins, 100);
});

test("spendCoins: aiGeneration accepts only 10, 75 and 100", async (t) => {
  const harness: SpendHarness = {coins: 1000, ledger: new Map()};
  mockSpendTransactions(t, harness);
  for (const amount of [10, 75, 100]) {
    const result = await spendCoins.run(spendRequest({action: "aiGeneration", amount}));
    assert.equal(result.delta, -amount);
  }
  for (const amount of [0, 11, "75", -75, null, undefined]) {
    await assert.rejects(() => spendCoins.run(spendRequest({action: "aiGeneration", amount})),
      {code: "invalid-argument"}, String(amount));
  }
  assert.equal(harness.coins, 1000 - 185);
});

test("spendCoins: label is trimmed, capped at 60 characters and stored as the description", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  await spendCoins.run(spendRequest({reason: "content_abc", label: `  ${"L".repeat(80)}  `}));
  const [entry] = [...harness.ledger.values()];
  assert.equal(entry.description, "L".repeat(60));
  assert.equal(entry.reason, "content_abc");
});

test("spendCoins: without a label the description is the reason; a blank label counts as none", async (t) => {
  const harness: SpendHarness = {coins: 100, ledger: new Map()};
  mockSpendTransactions(t, harness);
  await spendCoins.run(spendRequest({reason: "content_abc"}));
  await spendCoins.run(spendRequest({reason: "content_def", label: "   "}));
  await spendCoins.run(spendRequest({reason: "content_ghi", label: 42}));
  assert.deepEqual([...harness.ledger.values()].map((entry) => entry.description),
    ["content_abc", "content_def", "content_ghi"]);
});

type Store = Map<string, Record<string, unknown>>;

/** An in-memory Firestore for the award and rescue callables: transaction reads, writes and plain doc reads. */
function mockStore(t: test.TestContext, store: Store): void {
  const ref = (name: string, id: string) => ({
    id,
    path: `${name}/${id}`,
    get: async () => ({exists: store.has(`${name}/${id}`), data: () => store.get(`${name}/${id}`)}),
  });
  t.mock.method(db, "collection", (name: string) => ({doc: (id: string) => ref(name, id)}));
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const staged = new Map<string, Record<string, unknown>>();
    await callback({
      get: async (r: {path: string}) => ({exists: store.has(r.path), data: () => store.get(r.path)}),
      update: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, {...(staged.get(r.path) ?? store.get(r.path)), ...data});
      },
      set: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, data);
      },
    } as unknown as admin.firestore.Transaction);
    for (const [path, data] of staged) store.set(path, data);
  });
}

const awardRequest = (data: Record<string, unknown>) => ({
  auth: {uid: "user-1"}, data: {sourceTag: "test", ...data},
}) as unknown as Parameters<typeof awardCoins.run>[0];

const userDoc = (extra: Record<string, unknown> = {}): Record<string, unknown> => ({coins: 0, coinState: {}, ...extra});

test("awardCoins proDailyBonus: premium gets 50 once a day, others and repeats get nothing", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc({premium: true})]]);
  mockStore(t, store);
  const first = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(first.success, true);
  assert.equal(first.delta, 50);
  assert.equal(store.get("usersv2/user-1")?.coins, 50);
  const again = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(again.success, false);
  assert.equal(again.reason, "pro_bonus_already_claimed");
  assert.equal(store.get("usersv2/user-1")?.coins, 50);

  const freeStore: Store = new Map([["usersv2/user-1", userDoc({premium: false})]]);
  t.mock.reset();
  mockStore(t, freeStore);
  const free = await awardCoins.run(awardRequest({action: "proDailyBonus"}));
  assert.equal(free.success, false);
  assert.equal(free.reason, "pro_bonus_requires_premium");
  assert.equal(freeStore.get("usersv2/user-1")?.coins, 0);
});

test("awardCoins rewardedAd: two calls with one requestId credit 10 once and count once", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockStore(t, store);
  const first = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  assert.equal(first.success, true);
  assert.equal(first.delta, 10);
  assert.equal(first.currentBalance, 10);
  assert.equal(first.adsRemaining, 19);
  const replay = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  assert.equal(replay.success, true);
  assert.equal(replay.delta, 10);
  assert.equal(replay.previousBalance, 0);
  assert.equal(replay.currentBalance, 10);
  assert.equal(replay.adsRemaining, 19);
  assert.equal(store.get("usersv2/user-1")?.coins, 10);
  const rateDocs = [...store].filter(([path]) => path.startsWith("coinAdRateDaily/"));
  assert.equal(rateDocs.length, 1);
  assert.equal(rateDocs[0][1].count, 1);
  assert.ok(store.has("coinTransactions/award_user-1_request_123"));
});

test("awardCoins rewardedAd: a replay is not blocked by the 20 second gap and never changes the rate doc", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockStore(t, store);
  await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  const rateBefore = JSON.stringify([...store].filter(([path]) => path.startsWith("coinAdRateDaily/")));
  const blocked = await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_456"}));
  assert.equal(blocked.success, false);
  assert.equal(blocked.reason, "rewarded_ad_limit");
  assert.equal(blocked.adsRemaining, 19);
  await awardCoins.run(awardRequest({action: "rewardedAd", requestId: "request_123"}));
  assert.equal(JSON.stringify([...store].filter(([path]) => path.startsWith("coinAdRateDaily/"))), rateBefore);
});

test("awardCoins rewardedAd: without a requestId it still pays and reports the ads left", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockStore(t, store);
  const result = await awardCoins.run(awardRequest({action: "rewardedAd"}));
  assert.equal(result.success, true);
  assert.equal(result.adsRemaining, 19);
  assert.ok(![...store.keys()].some((path) => path.startsWith("coinTransactions/award_")));
});

test("awardCoins rejects a malformed requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  for (const requestId of ["short", "bad/path_123", 12345678]) {
    await assert.rejects(() => awardCoins.run(awardRequest({action: "rewardedAd", requestId})),
      {code: "invalid-argument"});
  }
});

function refundStore(debit: Record<string, unknown>): Store {
  return new Map([
    ["usersv2/user-1", userDoc({coins: 25})],
    ["coinTransactions/ctx_aiGeneration_1", debit],
  ]);
}

const aiDebit = (ageMs: number, overrides: Record<string, unknown> = {}) => ({
  userId: "user-1", type: "debit", action: "aiGeneration", status: "completed", delta: -75,
  createdAt: {toMillis: () => Date.now() - ageMs},
  ...overrides,
});

const refundRequest = () => awardRequest({action: "refund", transactionId: "ctx_aiGeneration_1"});

/** Stands in for the AI worker; returns the URLs that were asked. */
function mockWorker(t: test.TestContext, answer: () => Promise<Response>): string[] {
  const urls: string[] = [];
  t.mock.method(globalThis, "fetch", async (url: string) => {
    urls.push(url);
    return answer();
  });
  return urls;
}

const jsonResponse = (body: unknown, ok = true) => ({ok, status: ok ? 200 : 404, json: async () => body}) as Response;

test("awardCoins refund: an AI debit is refused when the worker says the image was made", async (t) => {
  const store = refundStore(aiDebit(60_000));
  mockStore(t, store);
  const asked = mockWorker(t, async () => jsonResponse({status: "succeeded"}));
  const result = await awardCoins.run(refundRequest());
  assert.equal(result.success, false);
  assert.equal(result.reason, "refund_denied_generation_succeeded");
  assert.equal(store.get("usersv2/user-1")?.coins, 25);
  assert.equal(store.get("coinTransactions/ctx_aiGeneration_1")?.status, "completed");
  assert.equal(asked.length, 1);
  assert.equal(asked[0], "https://prismwalls.com/api/ai/charges/ctx_aiGeneration_1");
});

test("awardCoins refund: an AI debit 2 hours old is refunded when the worker says failed or not_started", async (t) => {
  for (const status of ["failed", "not_started"]) {
    t.mock.reset();
    const store = refundStore(aiDebit(7_200_000));
    mockStore(t, store);
    mockWorker(t, async () => jsonResponse({status}));
    const result = await awardCoins.run(refundRequest());
    assert.equal(result.success, true, status);
    assert.equal(result.delta, 75);
    assert.equal(store.get("usersv2/user-1")?.coins, 100);
    assert.equal(store.get("coinTransactions/ctx_aiGeneration_1")?.status, "refunded");
  }
});

test("awardCoins refund: the 24 hour window ends after 24 hours", async (t) => {
  const store = refundStore(aiDebit(86_400_000 + 60_000));
  mockStore(t, store);
  mockWorker(t, async () => jsonResponse({status: "failed"}));
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
});

test("awardCoins refund: when the worker cannot be reached the 10 minute rule holds", async (t) => {
  const answers: Array<() => Promise<Response>> = [
    async () => {
      throw new Error("network down");
    },
    async () => jsonResponse({}, false),
    async () => jsonResponse({status: "teapot"}),
    async () => jsonResponse(null),
  ];
  for (const answer of answers) {
    t.mock.reset();
    mockStore(t, refundStore(aiDebit(7_200_000)));
    mockWorker(t, answer);
    await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});

    t.mock.reset();
    const store = refundStore(aiDebit(60_000));
    mockStore(t, store);
    mockWorker(t, answer);
    const result = await awardCoins.run(refundRequest());
    assert.equal(result.success, true);
    assert.equal(store.get("usersv2/user-1")?.coins, 100);
  }
});

test("awardCoins refund: AI_WORKER_BASE_URL overrides the worker address", async (t) => {
  const original = process.env.AI_WORKER_BASE_URL;
  process.env.AI_WORKER_BASE_URL = "https://worker.example/";
  t.after(() => {
    if (original === undefined) delete process.env.AI_WORKER_BASE_URL;
    else process.env.AI_WORKER_BASE_URL = original;
  });
  mockStore(t, refundStore(aiDebit(60_000)));
  const asked = mockWorker(t, async () => jsonResponse({status: "failed"}));
  await awardCoins.run(refundRequest());
  assert.equal(asked[0], "https://worker.example/api/ai/charges/ctx_aiGeneration_1");
});

test("awardCoins refund: a download debit never asks the worker", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc({coins: 0})],
    ["coinTransactions/ctx_aiGeneration_1", aiDebit(60_000, {action: "wallpaperDownload", delta: -5})],
  ]);
  mockStore(t, store);
  const asked = mockWorker(t, async () => jsonResponse({status: "succeeded"}));
  const result = await awardCoins.run(refundRequest());
  assert.equal(result.success, true);
  assert.equal(result.delta, 5);
  assert.equal(asked.length, 0);
});

test("awardCoins refund: a premium-bypassed spend left no ledger doc, so there is nothing to refund", async (t) => {
  mockStore(t, new Map([["usersv2/user-1", userDoc({coins: 25})]]));
  const asked = mockWorker(t, async () => jsonResponse({status: "failed"}));
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
  assert.equal(asked.length, 0);
});

test("awardCoins refund: an unreadable delta is refused", async (t) => {
  mockStore(t, refundStore(aiDebit(60_000, {delta: "lots"})));
  mockWorker(t, async () => jsonResponse({status: "failed"}));
  await assert.rejects(() => awardCoins.run(refundRequest()), {code: "failed-precondition"});
});

test("awardCoins profileCompletion and firstWallpaperUpload: a claimed flag blocks the award", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc({
    coinState: {profileCompletionRewarded: true, firstWallpaperUploadRewarded: true},
  })]]);
  mockStore(t, store);
  const profile = await awardCoins.run(awardRequest({action: "profileCompletion"}));
  assert.equal(profile.success, false);
  assert.equal(profile.reason, "profile_reward_already_claimed");
  const upload = await awardCoins.run(awardRequest({action: "firstWallpaperUpload"}));
  assert.equal(upload.success, false);
  assert.equal(upload.reason, "first_upload_reward_already_claimed");
  assert.equal(store.get("usersv2/user-1")?.coins, 0);
});

// restoreStreak

const RESCUE_NOW = 1_700_000_000_000;

function rescueStore(coinState: Record<string, unknown>, coins = 300): Store {
  return new Map([["usersv2/user-1", {coins, premium: true, coinState: {streakCount: 1, streakDay: 1, streakBest: 20, ...coinState}}]]);
}

const rescueState = (overrides: Record<string, unknown> = {}) => ({
  rescue: {count: 20, expiresAtMs: RESCUE_NOW + 3_600_000, ...overrides},
});

const rescueRequest = (requestId: unknown = "request_123") => ({
  auth: {uid: "user-1"}, data: {requestId},
}) as unknown as Parameters<typeof restoreStreak.run>[0];

function mockStoreAt(t: test.TestContext, store: Store): void {
  mockStore(t, store);
  t.mock.method(Date, "now", () => RESCUE_NOW);
}

test("restoreStreak: restores count + 1, debits 100 and writes one ledger row", async (t) => {
  const store = rescueStore(rescueState());
  mockStoreAt(t, store);
  const result = await restoreStreak.run(rescueRequest());
  assert.equal(result.success, true);
  assert.equal(result.streakCount, 21);
  assert.equal(result.delta, -STREAK_RESCUE_COST);
  assert.equal(result.currentBalance, 200);
  assert.equal(result.transactionId, "ctx_streakRescue_user-1_request_123");
  const user = store.get("usersv2/user-1") ?? {};
  assert.equal(user.coins, 200);
  assert.equal(user["coinState.streakCount"], 21);
  assert.equal(user["coinState.streakDay"], 7);
  assert.equal(user["coinState.streakBest"], 21);
  assert.equal(user["coinState.rescueLastAt"], RESCUE_NOW);
  assert.ok("coinState.rescue" in user);
  const ledger = store.get("coinTransactions/ctx_streakRescue_user-1_request_123");
  assert.equal(ledger?.delta, -100);
  assert.equal(ledger?.type, "debit");
  assert.equal(ledger?.reason, "streak_rescue");
  assert.equal(ledger?.balanceAfter, 200);
});

test("restoreStreak: a replay with the same requestId does not charge again", async (t) => {
  const store = rescueStore(rescueState());
  mockStoreAt(t, store);
  await restoreStreak.run(rescueRequest());
  const coinsAfter = store.get("usersv2/user-1")?.coins;
  const replay = await restoreStreak.run(rescueRequest());
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "duplicate");
  assert.equal(store.get("usersv2/user-1")?.coins, coinsAfter);
});

const refusals: Array<[string, Record<string, unknown>, number, string]> = [
  ["no rescue offer", {}, 300, "streak_rescue_unavailable"],
  ["an expired window", rescueState({expiresAtMs: RESCUE_NOW - 1}), 300, "streak_rescue_expired"],
  ["a streak under 7 days", rescueState({count: 6}), 300, "streak_rescue_too_short"],
  ["a rescue bought 29 days ago", {...rescueState(), rescueLastAt: RESCUE_NOW - 29 * 86_400_000}, 300,
    "streak_rescue_cooldown"],
  ["a streak already past the rescued count", {...rescueState(), streakCount: 25}, 300, "streak_rescue_not_needed"],
  ["too few coins", rescueState(), 99, "streak_rescue_insufficient_balance"],
];

for (const [name, coinState, coins, reason] of refusals) {
  test(`restoreStreak: refuses ${name} and changes nothing`, async (t) => {
    const store = rescueStore(coinState, coins);
    const before = JSON.stringify([...store]);
    mockStoreAt(t, store);
    const result = await restoreStreak.run(rescueRequest());
    assert.equal(result.success, false);
    assert.equal(result.reason, reason);
    assert.equal(result.insufficientBalance, reason === "streak_rescue_insufficient_balance");
    assert.equal(JSON.stringify([...store]), before);
  });
}

test("restoreStreak: a rescue bought 31 days ago is allowed again", async (t) => {
  const store = rescueStore({...rescueState(), rescueLastAt: RESCUE_NOW - 31 * 86_400_000});
  mockStoreAt(t, store);
  const result = await restoreStreak.run(rescueRequest());
  assert.equal(result.success, true);
});

test("restoreStreak validates auth and requestId before reading Firestore", async (t) => {
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not read Firestore");
  });
  await assert.rejects(() => restoreStreak.run({data: {requestId: "request_123"}} as
    Parameters<typeof restoreStreak.run>[0]), {code: "unauthenticated"});
  for (const requestId of [null, 12345678, "short", "bad/path_123"]) {
    await assert.rejects(() => restoreStreak.run(rescueRequest(requestId)), {code: "invalid-argument"});
  }
  await assert.rejects(() => restoreStreak.run({auth: {uid: "user-1"}, data: {}} as
    Parameters<typeof restoreStreak.run>[0]), {code: "invalid-argument"});
});

// processReferral

const REFERRAL_NOW = Date.now();
const authUser = (createdMsAgo: number) => ({metadata: {creationTime: new Date(REFERRAL_NOW - createdMsAgo).toUTCString()}});

function mockReferral(t: test.TestContext, store: Store, users: Record<string, unknown>) {
  t.mock.method(admin.auth(), "getUser", async (id: string) => {
    if (!(id in users)) throw Object.assign(new Error("none"), {code: "auth/user-not-found"});
    return users[id];
  });
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    const staged = new Map<string, Record<string, unknown>>();
    await callback({
      get: async (r: {path?: string}) => r.path == null ?
        {docs: [], size: 0} :
        {exists: store.has(r.path as string), data: () => store.get(r.path as string)},
      update: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, {...(staged.get(r.path) ?? store.get(r.path)), ...data});
      },
      set: (r: {path: string}, data: Record<string, unknown>) => {
        staged.set(r.path, data);
      },
    } as unknown as admin.firestore.Transaction);
    for (const [path, data] of staged) store.set(path, data);
  });
}

const referralRequest = (inviter = "inviter-1") => ({
  auth: {uid: "user-1"}, data: {inviterUserId: inviter},
}) as unknown as Parameters<typeof processReferral.run>[0];

test("processReferral: a missing inviter doc is not-found", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()]]);
  mockReferral(t, store, {"user-1": authUser(1000), "inviter-1": authUser(86_400_000)});
  await assert.rejects(() => processReferral.run(referralRequest()), {code: "not-found"});
});

test("processReferral: a caller or inviter missing from Firebase Auth is not-found", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()], ["usersv2/inviter-1", userDoc()]]);
  mockReferral(t, store, {"inviter-1": authUser(86_400_000)});
  await assert.rejects(() => processReferral.run(referralRequest()), {code: "not-found"});
});

test("processReferral: a permanent skip marks the referral processed and pays nobody", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["usersv2/inviter-1", userDoc()],
  ]);
  // The inviter is younger than the caller, so the referral can never pay.
  mockReferral(t, store, {"user-1": authUser(86_400_000), "inviter-1": authUser(1000)});
  const result = await processReferral.run(referralRequest());
  assert.equal(result.success, false);
  assert.equal(result.reason, "referral_inviter_not_older");
  assert.equal((store.get("usersv2/user-1")?.coinState as Record<string, unknown>).referralRewarded, true);
  assert.equal(store.get("usersv2/user-1")?.coins, 0);
  assert.equal(store.get("usersv2/inviter-1")?.coins, 0);
});

test("processReferral: a daily-limit skip stays retryable", async (t) => {
  const store: Store = new Map([
    ["usersv2/user-1", userDoc()],
    ["usersv2/inviter-1", userDoc()],
    ["referralStats/inviter-1", {day: new Date().toISOString().slice(0, 10), count: 10, total: 10}],
  ]);
  mockReferral(t, store, {"user-1": authUser(1000), "inviter-1": authUser(86_400_000)});
  const result = await processReferral.run(referralRequest());
  assert.equal(result.reason, "referral_inviter_daily_limit");
  assert.equal((store.get("usersv2/user-1")?.coinState as Record<string, unknown>).referralRewarded, undefined);
});

test("processReferral: a valid referral pays both sides 100", async (t) => {
  const store: Store = new Map([["usersv2/user-1", userDoc()], ["usersv2/inviter-1", userDoc({coins: 5})]]);
  mockReferral(t, store, {"user-1": authUser(1000), "inviter-1": authUser(86_400_000)});
  const result = await processReferral.run(referralRequest());
  assert.equal(result.success, true);
  assert.equal(store.get("usersv2/user-1")?.coins, 100);
  assert.equal(store.get("usersv2/inviter-1")?.coins, 105);
});
