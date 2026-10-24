import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
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
