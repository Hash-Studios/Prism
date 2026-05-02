import assert from "node:assert/strict";
import test from "node:test";

import {isSameTargetCooldownActive} from "../userBlockCallables";

test("allows immediate unblock after a recent block action", () => {
  assert.equal(
    isSameTargetCooldownActive({
      action: "unblock",
      lastAtMs: 10_000,
      nowMs: 10_500,
    }),
    false,
  );
});

test("keeps the same-target cooldown for repeated block actions", () => {
  assert.equal(
    isSameTargetCooldownActive({
      action: "block",
      lastAtMs: 10_000,
      nowMs: 10_500,
    }),
    true,
  );
});
