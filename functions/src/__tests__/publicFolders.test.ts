process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {
  publicFolderDeps,
  publicFolderName,
  removeFolderFollowsBetween,
  removeOwnerPublicFolders,
  setFolderFollow,
  setFolderHidden,
  setFolderPublic,
  syncPublicFolder,
  syncPublicFolderItem,
} from "../publicFolders";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const THUMB = "https://img.prismwalls.com/previews/aaa.img";
const TODAY = new Date().toISOString().slice(0, 10);
const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const keysUnder = (store: Map<string, Doc>, prefix: string) => [...store.keys()].filter((k) => k.startsWith(prefix));

function setup(t: TestContext) {
  t.mock.method(publicFolderDeps, "authDisabled", async () => false);
  return installFakeDb(t, {
    "walls/W1": {id: "w1", review: true, wallpaper_thumb: THUMB, wallpaper_url: "https://secret/original.jpg",
      collections: ["abstract"], originalProtected: true},
    "usersv2/a": {email: "a@x.com"},
    "usersv2/b": {email: "b@x.com"},
    "folders/f1": {ownerId: "a", name: "Night", public: true, itemCount: 1, covers: []},
    "folders/f1/items/prism_w1": {ownerId: "a", id: "w1", provider: "Prism", wallpaperDocumentId: "W1",
      url: "https://secret/original.jpg", thumb: "https://evil.example/x.jpg", addedAt: at(Date.now() - 60_000)},
  });
}

const publicCall = (uid: string | undefined, data: unknown) =>
  setFolderPublic.run({auth: uid ? {uid} : undefined, data} as Parameters<typeof setFolderPublic.run>[0]);
const followCall = (uid: string | undefined, data: unknown) =>
  setFolderFollow.run({auth: uid ? {uid} : undefined, data} as Parameters<typeof setFolderFollow.run>[0]);

test("projection keeps only the allowlisted item fields and the server thumb", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");

  const item = store.get("publicFolders/f1/items/prism_w1");
  assert.deepEqual(Object.keys(item ?? {}).sort(), [
    "addedAt", "id", "projectedAt", "provider", "thumb", "wallpaperDocumentId",
  ]);
  assert.equal(item?.thumb, THUMB);
  for (const [path, doc] of store) {
    if (path.startsWith("publicFolders/")) assert.equal("url" in doc, false, path);
  }
  const header = store.get("publicFolders/f1");
  assert.equal(header?.ownerId, "a");
  assert.equal(header?.name, "Night");
  assert.equal(header?.itemCount, 1);
  assert.equal(header?.followerCount, 0);
  assert.deepEqual(header?.covers, [THUMB]);
});

test("gated items are left out of the projection", async (t) => {
  const store = setup(t);
  store.delete("folders/f1/items/prism_w1");
  store.set("walls/WR", {id: "wr", review: false, wallpaper_thumb: THUMB, collections: ["abstract"],
    originalProtected: true});
  store.set("walls/WD", {id: "wd", review: true, dropReserved: true, wallpaper_thumb: THUMB,
    collections: ["abstract"], originalProtected: true});
  store.set("walls/WS", {id: "ws", review: true, is_streak_exclusive: true, wallpaper_thumb: THUMB,
    collections: ["abstract"], originalProtected: true});
  store.set("walls/WW", {id: "ww", review: true, dropWeek: "2026-W40", wallpaper_thumb: THUMB,
    collections: ["abstract"], originalProtected: true});
  const addedAt = at(Date.now() - 60_000);
  store.set("folders/f1/items/prism_r", {ownerId: "a", id: "wr", provider: "Prism", wallpaperDocumentId: "WR", addedAt});
  store.set("folders/f1/items/prism_d", {ownerId: "a", id: "wd", provider: "Prism", wallpaperDocumentId: "WD", addedAt});
  store.set("folders/f1/items/prism_s", {ownerId: "a", id: "ws", provider: "Prism", wallpaperDocumentId: "WS", addedAt});
  store.set("folders/f1/items/prism_k", {ownerId: "a", id: "ww", provider: "Prism", wallpaperDocumentId: "WW", addedAt});
  store.set("folders/f1/items/prism_m", {ownerId: "a", id: "gone", provider: "Prism", wallpaperDocumentId: "NOPE",
    addedAt});
  store.set("folders/f1/items/prism_h", {ownerId: "a", id: "w1", provider: "Wallhaven", wallpaperDocumentId: "W1",
    addedAt});

  await syncPublicFolder("f1");

  assert.deepEqual(keysUnder(store, "publicFolders/f1/items/"), []);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 0);
});

test("a private folder projects nothing", async (t) => {
  const store = setup(t);
  store.set("folders/f1", {ownerId: "a", name: "Night", itemCount: 1, covers: []});

  await syncPublicFolder("f1");

  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
});

test("turning a folder private removes the header, items and follow edges both ways", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("folders/f1", {ownerId: "a", name: "Night", public: false, itemCount: 1, covers: []});
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});

  await syncPublicFolder("f1");

  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), false);
});

test("deleting the private folder removes its projection", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.delete("folders/f1");

  await syncPublicFolder("f1");

  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
});

test("a closed, deleted or suspended owner has no projection", async (t) => {
  const store = setup(t);
  const disabled = t.mock.method(publicFolderDeps, "authDisabled", async () => false);
  await syncPublicFolder("f1");
  assert.equal(store.has("publicFolders/f1"), true);

  store.set("usersv2/a", {email: "a@x.com", deleted: true});
  await syncPublicFolder("f1");
  assert.deepEqual(keysUnder(store, "publicFolders/"), []);

  store.set("usersv2/a", {email: "a@x.com"});
  store.set("creatorDeletionState/a", {closed: true});
  await syncPublicFolder("f1");
  assert.deepEqual(keysUnder(store, "publicFolders/"), []);

  store.delete("creatorDeletionState/a");
  await syncPublicFolder("f1");
  assert.equal(store.has("publicFolders/f1"), true);

  disabled.mock.mockImplementation(async () => true);
  await syncPublicFolder("f1");
  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
});

test("a moderation-hidden folder has no projection", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("folders/f1", {ownerId: "a", name: "Night", public: true, moderationHidden: true, itemCount: 1, covers: []});

  await syncPublicFolder("f1");

  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
});

test("a name that may not be public makes the folder private", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("folders/f1", {ownerId: "a", name: "bad‮name", public: true, itemCount: 1, covers: []});

  await syncPublicFolder("f1");

  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
  assert.equal(store.get("folders/f1")?.public, false);
});

test("publicFolderName trims and collapses spaces and rejects hidden or long names", () => {
  assert.equal(publicFolderName("  Night  sky "), "Night sky");
  assert.equal(publicFolderName(""), null);
  assert.equal(publicFolderName("a".repeat(51)), null);
  assert.equal(publicFolderName("a​b"), null);
});

test("syncPublicFolderItem adds and removes one projected item", async (t) => {
  const store = setup(t);
  store.set("walls/W2", {id: "w2", review: true, wallpaper_thumb: "https://img.prismwalls.com/previews/bbb.img",
    collections: ["abstract"], originalProtected: true});
  await syncPublicFolder("f1");

  store.set("folders/f1/items/prism_w2", {ownerId: "a", id: "w2", provider: "Prism", wallpaperDocumentId: "W2",
    addedAt: at(Date.now() - 1000)});
  await syncPublicFolderItem("f1", "prism_w2");

  assert.ok(store.get("publicFolders/f1/items/prism_w2")?.projectedAt);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 2);
  assert.ok(store.get("publicFolders/f1")?.lastAddedAt);

  store.delete("folders/f1/items/prism_w2");
  await syncPublicFolderItem("f1", "prism_w2");

  assert.equal(store.has("publicFolders/f1/items/prism_w2"), false);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 1);
});

test("removeOwnerPublicFolders removes only that owner's headers", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 0, followerCount: 0});
  store.set("publicFolders/f2", {ownerId: "a", name: "Day", itemCount: 0, followerCount: 0});
  store.set("publicFolders/z1", {ownerId: "z", name: "Zed", itemCount: 0, followerCount: 0});

  await removeOwnerPublicFolders("a");

  assert.equal(store.has("publicFolders/f1"), false);
  assert.equal(store.has("publicFolders/f2"), false);
  assert.equal(store.has("publicFolders/z1"), true);
});

test("removeFolderFollowsBetween drops follows both ways and keeps other owners' follows", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 0, followerCount: 1});
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});
  store.set("publicFolders/f9", {ownerId: "c", name: "Other", itemCount: 0, followerCount: 1});
  store.set("publicFolders/f9/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f9", {folderId: "f9", ownerId: "c"});

  await removeFolderFollowsBetween("a", "b");

  assert.equal(store.has("publicFolders/f1/followers/b"), false);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), false);
  assert.equal(store.get("publicFolders/f1")?.followerCount, 0);
  assert.equal(store.has("publicFolders/f9/followers/b"), true);
  assert.equal(store.has("usersv2/b/followedFolders/f9"), true);
});

test("setFolderPublic checks input, ownership, hidden folders and the daily limit", async (t) => {
  const store = setup(t);
  await assert.rejects(() => publicCall(undefined, {folderId: "f1", public: true}), {code: "unauthenticated"});
  await assert.rejects(() => publicCall("a", {folderId: "../x", public: true}), {code: "invalid-argument"});
  await assert.rejects(() => publicCall("a", {folderId: "f1", public: "yes"}), {code: "invalid-argument"});
  await assert.rejects(() => publicCall("b", {folderId: "f1", public: true}), {code: "not-found"});

  store.set("folders/f1", {ownerId: "a", name: "Night", public: false, itemCount: 1, covers: []});
  assert.deepEqual(await publicCall("a", {folderId: "f1", public: true}), {public: true});
  assert.equal(store.has("publicFolders/f1"), true);

  store.set("folders/f1", {ownerId: "a", name: "Night", public: false, itemCount: 1, covers: []});
  store.set(`folderVisibilityRateDaily/a_${TODAY}`, {day: TODAY, count: 30});
  await assert.rejects(() => publicCall("a", {folderId: "f1", public: true}), {code: "resource-exhausted"});

  store.delete(`folderVisibilityRateDaily/a_${TODAY}`);
  store.set("folders/f1", {ownerId: "a", name: "Night", public: false, moderationHidden: true, itemCount: 1,
    covers: []});
  await assert.rejects(() => publicCall("a", {folderId: "f1", public: true}), {code: "failed-precondition"});
});

test("setFolderFollow checks input, self-follow, private folders and blocks", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 1, followerCount: 0, covers: []});
  await assert.rejects(() => followCall(undefined, {folderId: "f1", following: true}), {code: "unauthenticated"});
  await assert.rejects(() => followCall("b", {folderId: "../x", following: true}), {code: "invalid-argument"});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: "yes"}), {code: "invalid-argument"});
  await assert.rejects(() => followCall("a", {folderId: "f1", following: true}), {code: "invalid-argument"});

  store.delete("publicFolders/f1");
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});

  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 1, followerCount: 0, covers: []});
  store.set("usersv2/b/blockedUsers/a", {});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});
  store.delete("usersv2/b/blockedUsers/a");
  store.set("usersv2/a/blockedUsers/b", {});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});
});

test("setFolderFollow follows and unfollows with a correct follower count", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 1, followerCount: 0, covers: []});

  assert.deepEqual(await followCall("b", {folderId: "f1", following: true}), {following: true});
  assert.equal(store.has("publicFolders/f1/followers/b"), true);
  assert.equal(store.get("usersv2/b/followedFolders/f1")?.ownerId, "a");
  assert.equal(store.get("publicFolders/f1")?.followerCount, 1);

  await followCall("b", {folderId: "f1", following: true});
  assert.equal(store.get("publicFolders/f1")?.followerCount, 1);

  assert.deepEqual(await followCall("b", {folderId: "f1", following: false}), {following: false});
  assert.equal(store.has("publicFolders/f1/followers/b"), false);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), false);
  assert.equal(store.get("publicFolders/f1")?.followerCount, 0);
});

test("setFolderFollow stops at the daily action limit and the followed-folder cap", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 1, followerCount: 0, covers: []});

  store.set(`folderFollowRateDaily/b_${TODAY}`, {day: TODAY, count: 200});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "resource-exhausted"});
  store.delete(`folderFollowRateDaily/b_${TODAY}`);

  for (let i = 0; i < 500; i++) store.set(`usersv2/b/followedFolders/x${i}`, {folderId: `x${i}`, ownerId: "c"});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "resource-exhausted"});
});

test("setFolderHidden refuses a non-admin caller", async (t) => {
  setup(t);
  await assert.rejects(() => setFolderHidden.run({auth: {uid: "b"}, data: {folderId: "f1", hidden: true}} as
    Parameters<typeof setFolderHidden.run>[0]), {code: "permission-denied"});
});
