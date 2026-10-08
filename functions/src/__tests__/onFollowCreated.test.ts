import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";

import {followCollapseKey, followInboxDocId, isFollowerAlertsOff, onFollowCreated} from "../onFollowCreated";

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
    doc: () => ({set: async (data: unknown) => inbox.push(data)}),
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

test("one follower has one inbox doc id, so a retried trigger rewrites it", () => {
  assert.equal(followInboxDocId("u1", " Kim@Example.com "), followInboxDocId("u1", "kim@example.com"));
  assert.notEqual(followInboxDocId("u1", "kim@example.com"), followInboxDocId("u2", "kim@example.com"));
  assert.notEqual(followInboxDocId("u1", "kim@example.com"), followInboxDocId("u1", "lee@example.com"));
});

function followEvent(after: Record<string, unknown>, before: Record<string, unknown> = {followers: []}) {
  const updates: Array<Record<string, unknown>> = [];
  const event = {
    params: {userId: "followed"},
    data: {
      before: {data: () => before},
      after: {data: () => after, ref: {update: async (data: Record<string, unknown>) => updates.push(data)}},
    },
  } as unknown as Parameters<typeof onFollowCreated.run>[0];
  return {event, updates};
}

test("a follow by a blocked user is removed from both users and sends nothing", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/followed": {email: "Sam@example.com", followers: ["kim@example.com", "lee@example.com"]},
    "usersv2/kim": {email: "kim@example.com", following: ["Sam@example.com", "other@example.com"]},
    "usersv2/followed/blockedUsers/kim": {blockedUid: "kim"},
  });
  const send = t.mock.method(admin.messaging(), "send", async () => "id");
  const {event} = followEvent({
    email: "Sam@example.com", username: "sam", usernameLower: "sam", followers: ["kim@example.com"],
  });
  await onFollowCreated.run(event);
  assert.deepEqual(store.get("usersv2/followed")?.followers, ["lee@example.com"]);
  assert.deepEqual(store.get("usersv2/kim")?.following, ["other@example.com"]);
  assert.equal(send.mock.callCount(), 0);
  assert.equal([...store.keys()].filter((path) => path.startsWith("notifications/")).length, 0);
});

test("a follow by a user who is not blocked stays in both arrays", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/followed": {email: "sam@example.com", followers: ["kim@example.com"]},
    "usersv2/kim": {email: "kim@example.com", following: ["sam@example.com"]},
  });
  t.mock.method(admin.messaging(), "send", async () => "id");
  const {event} = followEvent({
    email: "sam@example.com", username: "sam", usernameLower: "sam", followers: ["kim@example.com"],
  });
  await onFollowCreated.run(event);
  assert.deepEqual(store.get("usersv2/followed")?.followers, ["kim@example.com"]);
  assert.deepEqual(store.get("usersv2/kim")?.following, ["sam@example.com"]);
});

test("the trigger keeps usernameLower and nameLower in sync in one write", async (t) => {
  installFakeDb(t);
  const {event, updates} = followEvent({email: "sam@example.com", username: "SamK", name: "Sam K", followers: []});
  await onFollowCreated.run(event);
  assert.deepEqual(updates, [{usernameLower: "samk", nameLower: "sam k"}]);

  const synced = followEvent({
    email: "sam@example.com", username: "SamK", usernameLower: "samk", name: "Sam K", nameLower: "sam k", followers: [],
  });
  await onFollowCreated.run(synced.event);
  assert.deepEqual(synced.updates, []);
});
