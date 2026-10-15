import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";

import {blockUser, buildBlockContentReportDoc, isSameTargetCooldownActive} from "../userBlockCallables";
import {installFakeDb} from "./fakeDb";

test("keeps the same-target cooldown for repeated block actions", () => {
  assert.equal(isSameTargetCooldownActive(10_000, 10_500), true);
  assert.equal(isSameTargetCooldownActive(10_000, 70_000), false);
  assert.equal(isSameTargetCooldownActive(undefined, 10_500), false);
});

test("builds a block content report doc matching submitContentReport's shape", () => {
  const now = admin.firestore.Timestamp.now();
  const doc = buildBlockContentReportDoc({blockedUid: "blocked-uid", callerUid: "caller-uid", now});

  assert.deepEqual(doc, {
    contentType: "user",
    targetFirestoreDocId: "blocked-uid",
    targetCollection: "usersv2",
    reason: "blocked",
    reporterUid: "caller-uid",
    status: "open",
    createdAt: now,
  });
});

test("blockUser ends the follow in both directions", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/caller": {email: "Caller@x.com", following: ["b@x.com", "keep@x.com"], followers: ["B@x.com", "z@x.com"]},
    "usersv2/blocked": {email: "b@x.com", followers: ["caller@x.com", "y@x.com"], following: ["Caller@x.com", "q@x.com"]},
  });
  await blockUser.run({
    auth: {uid: "caller"}, data: {targetUserId: "blocked"},
  } as unknown as Parameters<typeof blockUser.run>[0]);

  assert.deepEqual(store.get("usersv2/caller")?.following, ["keep@x.com"]);
  assert.deepEqual(store.get("usersv2/caller")?.followers, ["z@x.com"]);
  assert.deepEqual(store.get("usersv2/blocked")?.followers, ["y@x.com"]);
  assert.deepEqual(store.get("usersv2/blocked")?.following, ["q@x.com"]);
  assert.equal(store.get("usersv2/caller/blockedUsers/blocked")?.blockedUid, "blocked");
});

test("blockUser leaves users that do not follow each other untouched", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/caller": {email: "caller@x.com", following: ["keep@x.com"]},
    "usersv2/blocked": {email: "b@x.com", followers: ["y@x.com"]},
  });
  await blockUser.run({
    auth: {uid: "caller"}, data: {targetUserId: "blocked"},
  } as unknown as Parameters<typeof blockUser.run>[0]);
  assert.deepEqual(store.get("usersv2/caller")?.following, ["keep@x.com"]);
  assert.deepEqual(store.get("usersv2/blocked")?.followers, ["y@x.com"]);
});
