import assert from "node:assert/strict";
import test from "node:test";

import {pickFcmToken, resolveTimezoneOffset} from "../streak";

test("streak reminders use the session token, then the legacy field", () => {
  assert.equal(pickFcmToken("session-token", "legacy-token"), "session-token");
  assert.equal(pickFcmToken(undefined, "legacy-token"), "legacy-token");
  assert.equal(pickFcmToken(undefined, undefined), "");
});

test("streak timezone is fixed after first use", () => {
  assert.equal(resolveTimezoneOffset(undefined, 330), 330);
  assert.equal(resolveTimezoneOffset(330, 330), 330);
  assert.equal(resolveTimezoneOffset(330, -720), 330);
});
