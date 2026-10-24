import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {installFakeDb} from "./fakeDb";
import {onFollowCreated} from "../onFollowCreated";
import {onUidFollowCreated} from "../onUidFollowCreated";

function updateEvent(uid: string, before: string[], after: string[]) {
  return {
    params: {userId: uid},
    data: {
      before: {exists: true, data: () => ({name: "Alice", email: "alice@example.com", followers: before})},
      after: {
        exists: true,
        data: () => ({name: "Alice", email: "alice@example.com", followers: after}),
        ref: {update: async () => undefined},
      },
    },
  } as unknown as Parameters<typeof onFollowCreated.run>[0];
}

function followerEvent(targetUid: string, followerUid: string, edge: Record<string, unknown>) {
  return {
    params: {targetUid, followerUid},
    data: {data: () => edge},
  } as unknown as Parameters<typeof onUidFollowCreated.run>[0];
}

function legacyStore(t: Parameters<typeof installFakeDb>[0], extra: Record<string, Record<string, unknown>> = {}) {
  const store = installFakeDb(t, {
    "usersv2/target": {email: "alice@example.com"}, "usersv2/follower": {email: "kim@example.com"},
    "profiles/target": {followerCount: 0}, "profiles/follower": {followerCount: 0}, ...extra,
  });
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) =>
    ({uid: email.toLowerCase().startsWith("kim") ? "follower" : "other", emailVerified: true} as admin.auth.UserRecord));
  return store;
}

test("a legacy followers-array add creates both notifying edges and removal deletes them", async (t) => {
  const store = legacyStore(t);

  await onFollowCreated.run(updateEvent("target", [], ["Kim@Example.com "]));
  assert.equal(store.get("profiles/target/followers/follower")?.notify, true);
  assert.equal(store.get("profiles/follower/following/target")?.notify, true);
  assert.equal(store.get("profiles/target")?.followerCount, 1);
  assert.equal([...store.keys()].filter((path) => path.startsWith("notifications/")).length, 0);

  await onFollowCreated.run(updateEvent("target", ["kim@example.com"], []));
  assert.equal(store.has("profiles/target/followers/follower"), false);
  assert.equal(store.has("profiles/follower/following/target"), false);
  assert.equal(store.get("profiles/target")?.followerCount, 0);
});

test("a legacy follow from a blocked user is removed from both arrays and no edge is made", async (t) => {
  const store = legacyStore(t, {
    "usersv2/target": {email: "alice@example.com", followers: ["kim@example.com"]},
    "usersv2/follower": {email: "kim@example.com", following: ["alice@example.com"]},
    "usersv2/target/blockedUsers/follower": {blockedUid: "follower"},
  });

  await onFollowCreated.run(updateEvent("target", [], ["kim@example.com"]));

  assert.deepEqual(store.get("usersv2/target")?.followers, []);
  assert.deepEqual(store.get("usersv2/follower")?.following, []);
  assert.equal(store.has("profiles/target/followers/follower"), false);
});

test("UID edge notification is retriable and contains no follower email", async (t) => {
  const store = installFakeDb(t, {
    "profiles/target/followers/follower": {followerUid: "follower", notify: true},
    "usersv2/target": {email: "private@example.com", username: "target", loggedIn: false},
    "profiles/follower": {username: "follower-name"},
  });
  const event = followerEvent("target", "follower", {notify: true});
  await onUidFollowCreated.run(event);
  await onUidFollowCreated.run(event);

  const inbox = [...store.entries()].filter(([path]) => path.startsWith("notifications/"));
  assert.equal(inbox.length, 1);
  const data = inbox[0][1].data as Record<string, unknown>;
  assert.equal(data.follower_uid, "follower");
  assert.equal(data.username, "follower-name");
  assert.equal("follower_email" in data, false);
});

test("an explicit follower-alert opt-out still writes inbox but sends no push", async (t) => {
  const store = installFakeDb(t, {
    "profiles/target/followers/follower": {followerUid: "follower", notify: true},
    "usersv2/target": {email: "private@example.com", username: "target", loggedIn: true},
    "usersv2/target/private/session": {followerAlerts: false},
    "profiles/follower": {username: "follower-name"},
  });
  const send = t.mock.method(admin.messaging(), "send", async () => "message-id");
  await onUidFollowCreated.run(followerEvent("target", "follower", {notify: true}));
  assert.equal([...store.keys()].filter((path) => path.startsWith("notifications/")).length, 1);
  assert.equal(send.mock.callCount(), 0);
});

test("stale, backfilled, blocked, and deleted edge events do not notify", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/target": {email: "private@example.com", loggedIn: false},
    "profiles/follower": {username: "follower"},
    "profiles/target/followers/backfill": {followerUid: "backfill", notify: false},
    "profiles/backfill": {username: "backfill"},
    "profiles/target/followers/blocked": {followerUid: "blocked", notify: true},
    "profiles/blocked": {username: "blocked"},
    "usersv2/target/blockedUsers/blocked": {blockedUid: "blocked"},
    "profiles/target/followers/deleted": {followerUid: "deleted", notify: true},
    "profiles/deleted": {username: "deleted"},
    "creatorDeletionState/deleted": {closed: true},
  });
  await onUidFollowCreated.run(followerEvent("target", "missing", {notify: true}));
  await onUidFollowCreated.run(followerEvent("target", "backfill", {notify: false}));
  await onUidFollowCreated.run(followerEvent("target", "blocked", {notify: true}));
  await onUidFollowCreated.run(followerEvent("target", "deleted", {notify: true}));
  assert.equal([...store.keys()].filter((path) => path.startsWith("notifications/")).length, 0);
});
