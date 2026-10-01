import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {buyStreakFreeze, isValidRequestId, planFreezePurchase, refundableDelta, rewardedAdAllowed} from "../coinsCallables";

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
