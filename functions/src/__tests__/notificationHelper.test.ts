import assert from "node:assert/strict";
import test from "node:test";

import {emailToTopic, fcmMessage, userIdToTopic} from "../notificationHelper";

test("notification topics match the names the app subscribes to", () => {
  assert.equal(emailToTopic("sam+one@example.com"), "samone");
  assert.equal(emailToTopic("john+alerts.test@example.com"), "johnalerts.test");
  assert.equal(emailToTopic("Az-_.~%09@example.com"), "Az-_.~%09");
  assert.equal(userIdToTopic("abc/123"), "u_abc123");
  assert.notEqual(userIdToTopic("a/b"), userIdToTopic("a-b"));
});

test("fcmMessage puts a condition target on the message and no topic or token", () => {
  const message = fcmMessage({
    title: "t", body: "b", data: {route: "r"}, modifier: "m", channelId: "c",
    fcmTarget: {condition: "'a' in topics || 'b' in topics"},
  });
  assert.equal("condition" in message && message.condition, "'a' in topics || 'b' in topics");
  assert.ok(!("topic" in message));
  assert.ok(!("token" in message));
});
