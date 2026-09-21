import assert from "node:assert/strict";
import test from "node:test";

import {isFollowerAlertsOff} from "../onFollowCreated";

test("follower pushes are muted only by an explicit false", () => {
  assert.equal(isFollowerAlertsOff({followerAlerts: false}), true);
  assert.equal(isFollowerAlertsOff({followerAlerts: true}), false);
  assert.equal(isFollowerAlertsOff({fcmToken: "t"}), false);
  assert.equal(isFollowerAlertsOff(undefined), false);
  assert.equal(isFollowerAlertsOff({followerAlerts: "false"}), false);
});
