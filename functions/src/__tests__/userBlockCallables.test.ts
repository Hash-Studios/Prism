import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";

import {blockUser, unblockUser, buildBlockContentReportDoc, isSameTargetCooldownActive} from "../userBlockCallables";
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

const NOW = new Date("2026-01-10T12:00:00Z");
const call = (targetUserId: unknown = "blocked") => ({auth: {uid: "caller"}, data: {targetUserId},
} as Parameters<typeof blockUser.run>[0]);

test("block and unblock reject unauthenticated, malformed and self targets without writes", async (t) => {
  const store = installFakeDb(t, {"usersv2/caller": {email: "caller@example.com"}});
  const before = [...store.entries()];
  for (const callable of [blockUser, unblockUser]) {
    await assert.rejects(() => callable.run({...call(), auth: undefined}), {code: "unauthenticated"});
    for (const target of [null, 1, "", "a".repeat(129), "a/b", "..", "caller"]) {
      await assert.rejects(() => callable.run(call(target)), {code: "invalid-argument"});
    }
  }
  assert.deepEqual([...store.entries()], before);
});

test("block rejects missing profiles, missing email and either rate limit without writes", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t);
  await assert.rejects(() => blockUser.run(call()), {code: "failed-precondition"});
  store.set("usersv2/caller", {email: "caller@example.com"});
  await assert.rejects(() => blockUser.run(call()), {code: "not-found"});
  store.set("usersv2/blocked", {});
  await assert.rejects(() => blockUser.run(call()), {code: "failed-precondition"});
  store.set("usersv2/blocked", {email: "blocked@example.com"});
  store.set("userBlockRateByTarget/caller_blocked", {lastAt: admin.firestore.Timestamp.fromDate(NOW)});
  const cooldown = [...store.entries()];
  await assert.rejects(() => blockUser.run(call()), {code: "resource-exhausted"});
  assert.deepEqual([...store.entries()], cooldown);
  store.delete("userBlockRateByTarget/caller_blocked");
  store.set("userBlockRateDaily/caller_2026-01-10", {day: "2026-01-10", count: 200});
  const cap = [...store.entries()];
  await assert.rejects(() => blockUser.run(call()), {code: "resource-exhausted"});
  assert.deepEqual([...store.entries()], cap);
});

test("unblock removes only the block and prevents an immediate reblock below the daily cap", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {
    "usersv2/caller": {email: "caller@example.com", following: []},
    "usersv2/blocked": {email: "blocked@example.com", followers: []},
    "usersv2/caller/blockedUsers/blocked": {blockedUid: "blocked"},
    "userBlockRateDaily/caller_2026-01-10": {day: "2026-01-10", count: 1},
  });
  assert.deepEqual(await unblockUser.run(call()), {ok: true});
  assert.equal(store.has("usersv2/caller/blockedUsers/blocked"), false);
  assert.equal(store.get("userBlockRateDaily/caller_2026-01-10")?.count, 2);
  assert.equal(store.get("userBlockRateByTarget/caller_blocked")?.action, "unblock");
  assert.deepEqual(store.get("userBlockRateByTarget/caller_blocked")?.lastAt,
    admin.firestore.Timestamp.fromDate(NOW));
  assert.deepEqual(store.get("usersv2/caller")?.following, []);
  assert.deepEqual(store.get("usersv2/blocked")?.followers, []);
  assert.equal([...store.keys()].some((key) => key.startsWith("contentReports/")), false);
  await assert.rejects(() => blockUser.run(call()), {code: "resource-exhausted"});
  await assert.rejects(() => unblockUser.run(call()), {code: "not-found"});
});

test("unblock spends the last daily action", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {
    "usersv2/caller/blockedUsers/blocked": {blockedUid: "blocked"},
    "userBlockRateDaily/caller_2026-01-10": {day: "2026-01-10", count: 199},
  });
  assert.deepEqual(await unblockUser.run(call()), {ok: true});
  assert.equal(store.has("usersv2/caller/blockedUsers/blocked"), false);
  assert.equal(store.get("userBlockRateDaily/caller_2026-01-10")?.count, 200);
});

test("unblock at the daily cap keeps the block and counters intact", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {"usersv2/caller/blockedUsers/blocked": {blockedUid: "blocked"},
    "userBlockRateDaily/caller_2026-01-10": {day: "2026-01-10", count: 200}});
  const before = [...store.entries()];
  await assert.rejects(() => unblockUser.run(call()), {code: "resource-exhausted"});
  assert.deepEqual([...store.entries()], before);
});
