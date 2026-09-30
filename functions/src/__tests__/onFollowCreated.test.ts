import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

import {followCollapseKey, isFollowerAlertsOff, onFollowCreated} from "../onFollowCreated";

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

test("a signed-out user keeps the follow in the inbox but gets no push", async (t) => {
  const inbox: unknown[] = [];
  const query = {
    where: () => query,
    limit: () => query,
    get: async () => ({empty: true, docs: []}),
    add: async (data: unknown) => inbox.push(data),
  };
  t.mock.method(db, "collection", () => query);
  t.mock.method(db, "doc", () => ({get: async () => ({data: () => undefined})}));
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  const user = {email: "sam@example.com", username: "sam", usernameLower: "sam"};
  await onFollowCreated.run({
    params: {userId: "u1"},
    data: {
      before: {data: () => ({...user, followers: []})},
      after: {data: () => ({...user, loggedIn: false, followers: ["kim@example.com"]}), ref: {update: async () => undefined}},
    },
  } as unknown as Parameters<typeof onFollowCreated.run>[0]);
  assert.equal(send.mock.callCount(), 0);
  assert.equal(inbox.length, 1);
});
