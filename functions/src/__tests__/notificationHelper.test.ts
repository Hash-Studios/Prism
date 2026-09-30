import assert from "node:assert/strict";
import test from "node:test";

import {emailToTopic, userIdToTopic} from "../notificationHelper";

test("notification topics match the names the app subscribes to", () => {
  assert.equal(emailToTopic("sam+one@example.com"), "samone");
  assert.equal(emailToTopic("john+alerts.test@example.com"), "johnalerts.test");
  assert.equal(emailToTopic("Az-_.~%09@example.com"), "Az-_.~%09");
  assert.equal(userIdToTopic("abc/123"), "u_abc123");
  assert.notEqual(userIdToTopic("a/b"), userIdToTopic("a-b"));
});
