import assert from "node:assert/strict";
import test from "node:test";

import {isViewCooldownActive} from "../viewStats";

test("view cooldown blocks only the first hour", () => {
  assert.equal(isViewCooldownActive(1_000, 1_000 + 30 * 60 * 1000), true);
  assert.equal(isViewCooldownActive(1_000, 1_000 + 60 * 60 * 1000), false);
  assert.equal(isViewCooldownActive(undefined, 1_000), false);
});
