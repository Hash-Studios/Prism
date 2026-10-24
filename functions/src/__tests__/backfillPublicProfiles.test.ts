import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {backfillPublicProfiles} from "../scripts/backfillPublicProfiles";
import {installFakeDb} from "./fakeDb";

const seed = () => ({
  "usersv2/alice": {name: "Alice", email: "alice@example.com", following: ["bob@example.com", "ghost@example.com"]},
  "usersv2/bob": {name: "Bob", email: "bob@example.com", followers: ["alice@example.com"]},
});

function mockAuth(t: Parameters<typeof installFakeDb>[0]) {
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    if (email.startsWith("ghost")) throw Object.assign(new Error("not found"), {code: "auth/user-not-found"});
    return {uid: email.split("@")[0], emailVerified: true} as admin.auth.UserRecord;
  });
}

test("dry-run counts users and edges but writes nothing", async (t) => {
  const store = installFakeDb(t, seed());
  mockAuth(t);
  const before = [...store.keys()];

  const counts = await backfillPublicProfiles({apply: false}, () => undefined);

  assert.deepEqual(counts, {users: 2, profiles: 2, edges: 2, created: 0, unresolved: 1, refused: 0});
  assert.deepEqual([...store.keys()], before);
});

test("apply projects profiles and converts email arrays to silent edges once", async (t) => {
  const store = installFakeDb(t, seed());
  mockAuth(t);

  const counts = await backfillPublicProfiles({apply: true}, () => undefined);
  assert.deepEqual(counts, {users: 2, profiles: 2, edges: 2, created: 1, unresolved: 1, refused: 0});
  assert.equal(store.get("profiles/alice")?.name, "Alice");
  assert.equal(store.get("profiles/alice/following/bob")?.notify, false);
  assert.equal(store.get("profiles/bob/followers/alice")?.notify, false);
  assert.equal(store.get("profiles/bob")?.followerCount, 1);

  await backfillPublicProfiles({apply: true}, () => undefined);
  assert.equal(store.get("profiles/bob")?.followerCount, 1);
});

test("concurrent apply gives the same profiles and edges as one user at a time", async (t) => {
  const store = installFakeDb(t, seed());
  mockAuth(t);

  const counts = await backfillPublicProfiles({apply: true, concurrency: 10}, () => undefined);

  assert.deepEqual(counts, {users: 2, profiles: 2, edges: 2, created: 1, unresolved: 1, refused: 0});
  assert.equal(store.get("profiles/bob")?.followerCount, 1);
  assert.equal(store.get("profiles/alice")?.followingCount, 1);
});

test("an edge that fails once, for example on contention, is retried before it counts as refused", async (t) => {
  const store = installFakeDb(t, seed());
  // Fail only the first edge transaction: lookups start only after every profile is projected.
  let armed = false;
  let fired = false;
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    armed = !fired;
    if (email.startsWith("ghost")) throw Object.assign(new Error("not found"), {code: "auth/user-not-found"});
    return {uid: email.split("@")[0], emailVerified: true} as admin.auth.UserRecord;
  });
  const run = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    if (armed) {
      armed = false;
      fired = true;
      return Promise.reject(new Error("10 ABORTED: Too much contention"));
    }
    return run(callback);
  });

  const counts = await backfillPublicProfiles({apply: true, concurrency: 10}, () => undefined);

  assert.equal(counts.refused, 0);
  assert.equal(store.get("profiles/bob/followers/alice")?.notify, false);
  assert.equal(store.get("profiles/bob")?.followerCount, 1);
});

test("edges-only skips the profile pass and still applies each follow once", async (t) => {
  const store = installFakeDb(t, {...seed(), "profiles/alice": {name: "Old"}, "profiles/bob": {name: "Bob"}});
  mockAuth(t);
  let lookups = 0;
  const original = admin.auth().getUserByEmail;
  t.mock.method(admin.auth(), "getUserByEmail", async (email: string) => {
    lookups += 1;
    return original.call(admin.auth(), email);
  });

  const counts = await backfillPublicProfiles({apply: true, concurrency: 5, edgesOnly: true}, () => undefined);

  assert.deepEqual(counts, {users: 2, profiles: 2, edges: 2, created: 1, unresolved: 1, refused: 0});
  assert.equal(store.get("profiles/alice")?.name, "Old");
  assert.equal(store.get("profiles/bob")?.followerCount, 1);
  assert.equal(lookups, 3);
});
