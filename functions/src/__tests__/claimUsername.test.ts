import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {claimUsername, parseUsername} from "../claimUsername";
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
  await assert.rejects(() => claim("SAMK"), {code: "already-exists"});
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
