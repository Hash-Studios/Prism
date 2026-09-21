import assert from "node:assert/strict";
import test from "node:test";

import {usernameLowerOf} from "../usernameLower";

test("usernameLower is the trimmed, lowercased username", () => {
  assert.equal(usernameLowerOf(" KevinDoran "), "kevindoran");
  assert.equal(usernameLowerOf(undefined), "");
  assert.equal(usernameLowerOf(42), "");
});
