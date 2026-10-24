import assert from "node:assert/strict";
import test from "node:test";
import {removeUidFollowGraph, setFollow, syncPublicProfile} from "../profiles";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";

const call = (targetUid: unknown, following: unknown = true) => ({
  auth: {uid: "alice"}, data: {targetUid, following},
} as Parameters<typeof setFollow.run>[0]);

test("setFollow follow and unfollow are idempotent on followerCount", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/alice": {email: "alice@example.com"},
    "usersv2/bob": {email: "bob@example.com"},
    "profiles/alice": {name: "Alice", followerCount: 0, followingCount: 0},
    "profiles/bob": {name: "Bob", followerCount: 0},
  });

  await setFollow.run(call("bob"));
  await setFollow.run(call("bob"));
  assert.equal(store.get("profiles/bob")?.followerCount, 1);
  assert.equal(store.get("profiles/alice")?.followingCount, 1);
  assert.equal(store.get("profiles/alice/following/bob")?.notify, true);
  assert.equal(store.get("profiles/bob/followers/alice")?.followerUid, "alice");

  await setFollow.run(call("bob", false));
  await setFollow.run(call("bob", false));
  assert.equal(store.get("profiles/bob")?.followerCount, 0);
  assert.equal(store.get("profiles/alice")?.followingCount, 0);
  assert.equal(store.has("profiles/alice/following/bob"), false);
  assert.equal(store.has("profiles/bob/followers/alice"), false);
});

test("setFollow creates missing profile projections before the first edge", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/alice": {name: "Alice", email: "alice@example.com"},
    "usersv2/bob": {name: "Bob", email: "bob@example.com"},
  });

  await setFollow.run(call("bob"));

  assert.equal(store.get("profiles/bob")?.name, "Bob");
  assert.equal(store.get("profiles/bob")?.followerCount, 1);
  assert.equal("email" in (store.get("profiles/bob") ?? {}), false);
});

test("profile projection keeps exactly the allowlisted fields", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/alice": {
      name: "Current", username: "current", profilePhoto: "photo", bio: "bio", coverPhoto: "cover",
      links: {github: "https://github.com/example", malicious: "x"},
      badges: [{id: "early", name: "Early"}, {id: ""}, {name: "no id"}, {id: "pro"}],
      xp: 120.9, cosmetics: {frame: "gold", nameGlow: "ember", other: "x"},
      email: "private@example.com", premium: true, coins: 999, followers: ["a@example.com"],
      following: ["friend@example.com"], lastAppOpenAt: 5, appOpenTimezoneOffsetMinutes: 330,
    },
    "profiles/alice": {followerCount: 7, followingCount: 3, oldPrivateField: "remove"},
  });

  await syncPublicProfile("alice");

  assert.deepEqual(store.get("profiles/alice"), {
    name: "Current", username: "current", profilePhoto: "photo", bio: "bio", coverPhoto: "cover",
    links: {github: "https://github.com/example"}, badges: ["early", "pro"], xp: 120,
    cosmetics: {frame: "gold", nameGlow: "ember"}, followerCount: 7, followingCount: 3,
  });
});

test("profile projection skips the write when the public fields did not change", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/alice": {name: "Alice", coins: 5, lastAppOpenAt: 9},
    "profiles/alice": {followerCount: 2, followingCount: 4, name: "Alice"},
  });
  const profile = store.get("profiles/alice");

  await syncPublicProfile("alice");

  assert.equal(store.get("profiles/alice"), profile);
});

test("profile projection deletes public documents after private profile deletion", async (t) => {
  const store = installFakeDb(t, {"profiles/alice": {name: "Stale", followerCount: 3}});
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    for (const path of [...store.keys()]) {
      if (path === ref.path || path.startsWith(`${ref.path}/`)) store.delete(path);
    }
  });
  await syncPublicProfile("alice");
  assert.equal(store.has("profiles/alice"), false);
});

test("account graph cleanup removes mirrored edges and decrements surviving incoming counts", async (t) => {
  const store = installFakeDb(t, {
    "profiles/alice": {followerCount: 1},
    "profiles/bob": {followerCount: 1},
    "profiles/alice/following/bob": {targetUid: "bob", notify: true},
    "profiles/bob/followers/alice": {followerUid: "alice", notify: true},
    "profiles/alice/followers/charlie": {followerUid: "charlie", notify: true},
    "profiles/charlie": {followerCount: 2, followingCount: 1},
    "profiles/charlie/following/alice": {targetUid: "alice", notify: true},
  });
  t.mock.method(db, "recursiveDelete", async (ref: {path: string}) => {
    for (const path of [...store.keys()]) {
      if (path === ref.path || path.startsWith(`${ref.path}/`)) store.delete(path);
    }
  });

  await removeUidFollowGraph("alice");

  assert.equal(store.has("profiles/alice"), false);
  assert.equal(store.has("profiles/bob/followers/alice"), false);
  assert.equal(store.has("profiles/charlie/following/alice"), false);
  assert.equal(store.get("profiles/bob")?.followerCount, 0);
  assert.equal(store.get("profiles/charlie")?.followerCount, 2);
  assert.equal(store.get("profiles/charlie")?.followingCount, 0);
});

test("setFollow rejects self, malformed and blocked relationships without graph writes", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/alice": {}, "usersv2/bob": {},
    "usersv2/alice/blockedUsers/bob": {blockedUid: "bob"},
    "profiles/alice": {followerCount: 0}, "profiles/bob": {followerCount: 0},
  });
  t.mock.method(db, "recursiveDelete", async () => undefined);

  await assert.rejects(() => setFollow.run(call("bob")), {code: "failed-precondition"});
  store.delete("usersv2/alice/blockedUsers/bob");
  store.set("usersv2/bob/blockedUsers/alice", {blockedUid: "alice"});
  await assert.rejects(() => setFollow.run(call("bob")), {code: "failed-precondition"});
  for (const target of ["alice", "a/b", ".", "..", "", null]) {
    await assert.rejects(() => setFollow.run(call(target)), {code: "invalid-argument"});
  }
  await assert.rejects(() => setFollow.run(call("valid.uid")), {code: "not-found"});
  assert.equal(store.has("profiles/alice/following/bob"), false);
});

test("setFollow removes both UID edges and does not underflow counts", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/alice": {}, "usersv2/bob": {},
    "profiles/alice": {}, "profiles/bob": {followerCount: 0},
    "profiles/alice/following/bob": {targetUid: "bob"},
    "profiles/bob/followers/alice": {followerUid: "alice"},
  });

  await setFollow.run(call("bob", false));
  assert.equal(store.has("profiles/alice/following/bob"), false);
  assert.equal(store.has("profiles/bob/followers/alice"), false);
  assert.equal(store.get("profiles/bob")?.followerCount, 0);
});
