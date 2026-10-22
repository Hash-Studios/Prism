import assert from "node:assert/strict";
import test from "node:test";
import {onUserCreated} from "../onUserCreated";
import {claimUsername} from "../claimUsername";
import {db} from "../common";
import {type Doc, installFakeDb} from "./fakeDb";

async function create(store: Map<string, Doc>, uid: string) {
  const path = `usersv2/${uid}`;
  const data = store.get(path) as Doc;
  await onUserCreated.run({
    params: {uid},
    data: {data: () => data, ref: {update: async (update: Doc) => void store.set(path, {...data, ...update})}},
  } as unknown as Parameters<typeof onUserCreated.run>[0]);
  return store.get(path);
}

test("a new profile with a free username only gets its lowercase search fields", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/uid12345": {username: "JohnSmith", name: "John Smith"},
    "usersv2/other": {username: "Jane", usernameLower: "jane"},
  });
  const user = await create(store, "uid12345");
  assert.deepEqual(user, {username: "JohnSmith", name: "John Smith", usernameLower: "johnsmith", nameLower: "john smith"});
  assert.equal(store.get("usernames/johnsmith")?.uid, "uid12345");
});

test("a username that another profile holds gets a short suffix from the uid", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/first": {username: "JohnSmith", usernameLower: "johnsmith"},
    "usersv2/AbCd1234": {username: "johnsmith"},
  });
  const user = await create(store, "AbCd1234");
  assert.equal(user?.username, "johnsmith_abcd");
  assert.equal(user?.usernameLower, "johnsmith_abcd");
  assert.equal(store.get("usersv2/first")?.username, "JohnSmith");
});

test("a longer suffix is used when the short one is taken too", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/first": {username: "John", usernameLower: "john"},
    "usersv2/squatter": {username: "John_abcd", usernameLower: "john_abcd"},
    "usersv2/AbCd1234": {username: "John"},
  });
  const user = await create(store, "AbCd1234");
  assert.equal(user?.username, "John_abcd1234");
});

test("a profile without a username is left alone", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {coins: 0}});
  assert.deepEqual(await create(store, "u1"), {coins: 0});
});

test("a name-only profile still gets its search normalization", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {name: "New User"}});
  assert.deepEqual(await create(store, "u1"), {name: "New User", nameLower: "new user"});
});

test("a provisional candidate is reserved before it becomes canonical", async (t) => {
  const store = installFakeDb(t, {"usersv2/u1": {username: "", usernameCandidate: "NewUser", name: "New User"}});
  const user = await create(store, "u1");
  assert.equal(user?.username, "NewUser");
  assert.equal(user?.usernameLower, "newuser");
  assert.equal(store.get("usernames/newuser")?.uid, "u1");
});

test("a delayed creation event does not overwrite a username already claimed", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1": {username: "", usernameCandidate: "Original"},
  });
  const stale = store.get("usersv2/u1");
  await claimUsername.run({auth: {uid: "u1"}, data: {username: "Chosen"}} as Parameters<typeof claimUsername.run>[0]);
  await onUserCreated.run({params: {uid: "u1"}, data: {data: () => stale}} as Parameters<typeof onUserCreated.run>[0]);
  assert.equal(store.get("usersv2/u1")?.username, "Chosen");
  assert.equal(store.has("usernames/original"), false);
});

test("concurrent initial profiles and callable claims have one reservation winner in Firestore", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const prefix = `Race${Date.now()}`;
  const ids = [`${prefix}A`, `${prefix}B`, `${prefix}C`];
  for (const uid of ids) await db.doc(`usersv2/${uid}`).set({username: "", usernameCandidate: prefix});
  const createReal = async (uid: string) => onUserCreated.run({
    params: {uid}, data: await db.doc(`usersv2/${uid}`).get(),
  } as Parameters<typeof onUserCreated.run>[0]);
  const outcomes = await Promise.allSettled([
    createReal(ids[0]), createReal(ids[1]),
    claimUsername.run({auth: {uid: ids[2]}, data: {username: prefix}} as Parameters<typeof claimUsername.run>[0]),
  ]);
  assert.equal(outcomes[0].status, "fulfilled");
  assert.equal(outcomes[1].status, "fulfilled");
  const users = await Promise.all(ids.map(async (uid) => (await db.doc(`usersv2/${uid}`).get()).data()));
  const names = users.map((user) => user?.usernameLower).filter(Boolean);
  assert.equal(new Set(names).size, names.length);
  const reservation = await db.doc(`usernames/${prefix.toLowerCase()}`).get();
  const winner = users.findIndex((user) => user?.usernameLower === prefix.toLowerCase());
  assert.ok(winner >= 0);
  assert.equal(reservation.data()?.uid, ids[winner]);
  for (let i = 0; i < users.length; i++) {
    if (users[i]?.usernameLower) {
      assert.equal((await db.doc(`usernames/${users[i]?.usernameLower}`).get()).data()?.uid, ids[i]);
    }
  }
});
