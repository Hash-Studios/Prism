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

test("notification topics distinguish user ids while preserving admin email topics", () => {
  assert.equal(emailToTopic("sam+one@example.com"), "sam_one");
  assert.equal(userIdToTopic("abc/123"), "u_abc_123");
  assert.notEqual(userIdToTopic("a/b"), userIdToTopic("a-b"));
});

test("view cooldown blocks only the first hour", () => {
  assert.equal(isViewCooldownActive(1_000, 1_000 + 30 * 60 * 1000), true);
  assert.equal(isViewCooldownActive(1_000, 1_000 + 60 * 60 * 1000), false);
  assert.equal(isViewCooldownActive(undefined, 1_000), false);
});
