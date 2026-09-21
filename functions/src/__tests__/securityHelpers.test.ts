import assert from "node:assert/strict";
import test from "node:test";

import {_resolveTimezoneOffset} from "../streak";
import {emailToTopic, userIdToTopic} from "../notificationHelper";
import {isViewCooldownActive} from "../viewStats";

test("streak timezone is fixed after first use", () => {
  assert.equal(_resolveTimezoneOffset(undefined, 330), 330);
  assert.equal(_resolveTimezoneOffset(330, 330), 330);
  assert.equal(_resolveTimezoneOffset(330, -720), 330);
});

test("notification topics match the names the app subscribes to", () => {
  assert.equal(emailToTopic("sam+one@example.com"), "samone");
  assert.equal(emailToTopic("john+alerts.test@example.com"), "johnalerts.test");
  assert.equal(emailToTopic("Az-_.~%09@example.com"), "Az-_.~%09");
  assert.equal(userIdToTopic("abc/123"), "u_abc123");
  assert.notEqual(userIdToTopic("a/b"), userIdToTopic("a-b"));
});

test("view cooldown blocks only the first hour", () => {
  assert.equal(isViewCooldownActive(1_000, 1_000 + 30 * 60 * 1000), true);
  assert.equal(isViewCooldownActive(1_000, 1_000 + 60 * 60 * 1000), false);
  assert.equal(isViewCooldownActive(undefined, 1_000), false);
});
