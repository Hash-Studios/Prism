import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {claimUsername, isAllCapsUsername, parseUsername} from "../claimUsername";
import {installFakeDb} from "./fakeDb";

const claim = (username: unknown, uid: string | null = "u1") => claimUsername.run({
  auth: uid ? {uid} : undefined, data: {username},
} as unknown as Parameters<typeof claimUsername.run>[0]);

test("a username is 3 to 30 letters, digits or underscores", () => {
  assert.equal(parseUsername(" Sam_k9 "), "Sam_k9");
  for (const bad of [undefined, 5, "", "ab", "a b c", "sam!", "a/b", "x".repeat(31)]) {
    assert.throws(() => parseUsername(bad), {code: "invalid-argument"});
  }
});

test("a name shouts when it has 3 or more letters and no lowercase letter", () => {
  const cases: Array<[string, boolean]> = [
    ["AKSHAY", true], ["ABC_123", true], ["NASA", true],
    ["AB_12", false], ["Akshay", false], ["akshay", false], ["123_456", false],
  ];
  for (const [name, shouts] of cases) assert.equal(isAllCapsUsername(name), shouts, name);
});

test("claiming needs a signed-in caller who has a profile", async (t) => {
  installFakeDb(t);
  await assert.rejects(() => claim("SamK", null), {code: "unauthenticated"});
  await assert.rejects(() => claim("SamK"), {code: "failed-precondition"});
});

test("a free name is registered, written to the profile and the old name is released", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName", usernameLower: "oldname"},
    "usernames/oldname": {uid: "u1"},
  });
  assert.deepEqual(await claim("NewName"), {username: "NewName", usernameLower: "newname"});
  assert.equal(store.get("usernames/newname")?.uid, "u1");
  assert.ok(store.get("usernames/newname")?.claimedAt instanceof admin.firestore.Timestamp);
  assert.equal(store.has("usernames/oldname"), false);
  assert.equal(store.get("usersv2/u1")?.username, "NewName");
  assert.equal(store.get("usersv2/u1")?.usernameLower, "newname");
});

test("a name in the registry for someone else is taken, in any letter case", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName", usernameLower: "oldname"},
    "usernames/samk": {uid: "u2"},
  });
  await assert.rejects(() => claim("SamK"), {code: "already-exists"});
  assert.equal(store.get("usersv2/u1")?.username, "OldName");
});

test("a name that only a profile holds is taken too", async (t) => {
  installFakeDb(t, {
    "usersv2/u1": {username: "OldName"},
    "usersv2/u2": {username: "SamK", usernameLower: "samk"},
  });
  await assert.rejects(() => claim("samk"), {code: "already-exists"});
});

test("the owner can change only the letter case of the name", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "samk", usernameLower: "samk"},
    "usernames/samk": {uid: "u1"},
  });
  await claim("SamK");
  assert.equal(store.get("usersv2/u1")?.username, "SamK");
  assert.equal(store.get("usernames/samk")?.uid, "u1");
});

test("the previous registry doc of another user is not released", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName"},
    "usernames/oldname": {uid: "u2"},
  });
  await claim("NewName");
  assert.equal(store.get("usernames/oldname")?.uid, "u2");
});

test("SV-S12 a name released by deletion can be claimed by a new account", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/deleted": {name: "Deleted Account", deleted: true},
    "usersv2/u1": {username: "NewUser"},
  });
  await claim("ReusedName");
  assert.equal(store.get("usernames/reusedname")?.uid, "u1");
  assert.equal(store.get("usersv2/u1")?.username, "ReusedName");
});

test("an account whose deletion has started cannot reserve more names", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "OldName"}, "creatorDeletionState/u1": {closed: true},
  });
  await assert.rejects(() => claim("NewName"), {code: "failed-precondition"});
  assert.equal(store.has("usernames/newname"), false);
});

test("initial claim inputs must still supply a string candidate", async (t) => {
  installFakeDb(t, {"usersv2/u1": {username: ""}});
  await assert.rejects(() => claimUsername.run({auth: {uid: "u1"}, data: {initial: true, username: {name: "Bad"}}} as unknown as
    Parameters<typeof claimUsername.run>[0]), {code: "invalid-argument"});
});

test("historical reservations owned by a deleted profile can be reclaimed on demand", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {}, "usersv2/gone": {deleted: true,
    usernameLower: "reusedname"}, "usernames/reusedname": {uid: "gone"}});
  await claim("ReusedName");
  assert.equal(store.get("usernames/reusedname")?.uid, "u1");
});

test("missing, unknown and active reservation owners cannot be reclaimed", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {}, "usersv2/active": {deleted: false}});
  for (const owner of [undefined, "", 7, "missing", "active"]) {
    store.set("usernames/blocked", {uid: owner});
    await assert.rejects(() => claim("Blocked"), {code: "already-exists"});
    assert.equal(store.get("usernames/blocked")?.uid, owner);
  }
});

test("two concurrent historical reclaims have exactly one winner", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {}, "usersv2/u2": {}, "usersv2/gone": {deleted: true},
    "usernames/reuse": {uid: "gone"}});
  const results = await Promise.allSettled([claim("Reuse", "u1"), claim("rEUSE", "u2")]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.filter((r) => r.status === "rejected").length, 1);
  const owner = store.get("usernames/reuse")?.uid;
  assert.equal(store.get(`usersv2/${owner}`)?.usernameLower, "reuse");
});

test("a reservation transferred to an active owner cannot be reclaimed again", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {}, "usersv2/u2": {}, "usersv2/gone": {deleted: true},
    "usernames/reuse": {uid: "gone"}});
  await claim("Reuse", "u2");
  await assert.rejects(() => claim("Reuse", "u1"), {code: "already-exists"});
  assert.equal(store.get("usernames/reuse")?.uid, "u2");
});

test("an explicit claim of an all caps name is refused", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {username: "old_name", usernameLower: "old_name"}});
  await assert.rejects(() => claim("SHOUTY"), {code: "invalid-argument"});
  assert.equal(store.has("usernames/shouty"), false);
  assert.equal(store.get("usersv2/u1")?.username, "old_name");
});

test("an explicit claim with a lowercase letter is accepted", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {username: "old_name", usernameLower: "old_name"}});
  assert.deepEqual(await claim("Shouty"), {username: "Shouty", usernameLower: "shouty"});
  assert.equal(store.get("usernames/shouty")?.uid, "u1");
});

test("a user can re-claim the all caps name they already hold", async (t) => {
  installFakeDb(t, {"usersv2/u1": {username: "LEGACY", usernameLower: "legacy"}, "usernames/legacy": {uid: "u1"}});
  assert.deepEqual(await claim("LEGACY"), {username: "LEGACY", usernameLower: "legacy"});
});

test("an initial name from an all caps display name is lowercased", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {}});
  assert.deepEqual(await claimUsername.run({auth: {uid: "u1"}, data: {initial: true, username: "JOHNDOE"}} as unknown as
    Parameters<typeof claimUsername.run>[0]), {username: "johndoe", usernameLower: "johndoe"});
  assert.equal(store.get("usernames/johndoe")?.uid, "u1");
});
