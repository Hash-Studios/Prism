import assert from "node:assert/strict";
import test from "node:test";
import {onUserCreated} from "../onUserCreated";
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
