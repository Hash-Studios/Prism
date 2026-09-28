import assert from "node:assert/strict";
import test from "node:test";
import {clampAmount, rejectSelfReferral} from "../coinsCallables";

test("clamps coin amounts to the callable limit", () => {
  assert.equal(clampAmount(-5), 0);
  assert.equal(clampAmount(12.9), 12);
  assert.equal(clampAmount(5000), 1000);
});

test("rejects self referrals", () => {
  assert.throws(() => rejectSelfReferral("user-1", "user-1"), {code: "invalid-argument"});
});
