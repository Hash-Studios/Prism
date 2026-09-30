import assert from "node:assert/strict";
import test from "node:test";
import {isValidRequestId, planFreezePurchase, refundableDelta, rewardedAdAllowed} from "../coinsCallables";

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
