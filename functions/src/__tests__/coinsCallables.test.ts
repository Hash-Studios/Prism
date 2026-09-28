import assert from "node:assert/strict";
import test from "node:test";
import {clampAmount, refundableDelta, rejectSelfReferral, rewardedAdAllowed} from "../coinsCallables";

const NOW = 1_700_000_000_000;

function debitFixture(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    userId: "user-1",
    type: "debit",
    status: "completed",
    delta: -15,
    createdAt: {toMillis: () => NOW - 60_000},
    ...overrides,
  };
}

test("clamps coin amounts to the callable limit", () => {
  assert.equal(clampAmount(-5), 0);
  assert.equal(clampAmount(12.9), 12);
  assert.equal(clampAmount(5000), 1000);
});

test("rejects self referrals", () => {
  assert.throws(() => rejectSelfReferral("user-1", "user-1"), {code: "invalid-argument"});
});

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
  const old = debitFixture({createdAt: {toMillis: () => NOW - 3_600_001}});
  assert.throws(() => refundableDelta(old, "user-1", NOW), {code: "failed-precondition"});
});

test("refundableDelta: allows a debit right at the edge of the refund window", () => {
  const edge = debitFixture({createdAt: {toMillis: () => NOW - 3_600_000}});
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
