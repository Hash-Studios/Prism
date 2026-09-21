import assert from "node:assert/strict";
import test from "node:test";

import {followCollapseKey, isFollowerAlertsOff} from "../onFollowCreated";

test("follower pushes are muted only by an explicit false", () => {
  assert.equal(isFollowerAlertsOff({followerAlerts: false}), true);
  assert.equal(isFollowerAlertsOff({followerAlerts: true}), false);
  assert.equal(isFollowerAlertsOff({fcmToken: "t"}), false);
  assert.equal(isFollowerAlertsOff(undefined), false);
  assert.equal(isFollowerAlertsOff({followerAlerts: "false"}), false);
});

test("both follow pushes share one short collapse key per follower", () => {
  const key = followCollapseKey(" Kevin@Example.com ");
  assert.equal(key, followCollapseKey("kevin@example.com"));
  assert.notEqual(key, followCollapseKey("sam@example.com"));
  assert.ok(Buffer.byteLength(key) <= 64);
});
