import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  categoryCollection,
  collectionFor,
  fileWallInCollection,
  isCommunityOnly,
  refreshCollectionCovers,
} from "../wallCollections";
import {type Doc, installFakeDb} from "./fakeDb";

const at = (iso: string) => admin.firestore.Timestamp.fromDate(new Date(iso));

/** Remote Config is not reachable in tests, so the premium list falls back to the app defaults. */
function noRemoteConfig(t: TestContext) {
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => {
    throw new Error("no remote config in tests");
  });
}

test("a category maps to its collection, and anything else maps to none", () => {
  assert.equal(categoryCollection("Nature"), "landscapes");
  assert.equal(categoryCollection("Anime"), "illustrations");
  assert.equal(categoryCollection("General"), null);
  assert.equal(categoryCollection("constructor"), null);
  assert.equal(categoryCollection(42), null);
});

test("collection covers never fall back to an original URL", async (t) => {
  const store = installFakeDb(t, {
    "collections/nature": {name: "nature", thumb1: "https://preview.test/retained.jpg"},
    "walls/w1": {review: true, collections: ["nature"], createdAt: at("2026-10-19T00:00:00Z"),
      wallpaper_thumb: "", wallpaper_url: "https://original.test/private.jpg"},
  });
  assert.deepEqual(await refreshCollectionCovers(), []);
  assert.equal(store.get("collections/nature")?.thumb1, "https://preview.test/retained.jpg");
});

test("only a wall whose every collection is community is community-only", () => {
  assert.equal(isCommunityOnly(["community"]), true);
  assert.equal(isCommunityOnly(["community ", "Community"]), true);
  assert.equal(isCommunityOnly(["community", "stock"]), false);
  assert.equal(isCommunityOnly([]), false);
  assert.equal(isCommunityOnly(undefined), false);
});

test("only an approved community-only wall gets a collection", () => {
  assert.equal(collectionFor({review: true, collections: ["community"], category: "Dark"}), "amoled");
  assert.equal(collectionFor({review: false, collections: ["community"], category: "Dark"}), null);
  assert.equal(collectionFor({review: true, collections: ["community", "stock"], category: "Dark"}), null);
  assert.equal(collectionFor({review: true, collections: ["community"], category: "Cars"}), null);
  assert.equal(collectionFor(undefined), null);
});

async function file(t: TestContext, wall: Doc) {
  const store = installFakeDb(t, {"walls/w1": wall});
  noRemoteConfig(t);
  const filed = await fileWallInCollection(db.collection("walls").doc("w1"));
  return {filed, collections: store.get("walls/w1")?.collections};
}

test("an approved community-only wall is filed into the collection of its category", async (t) => {
  const result = await file(t, {review: true, collections: ["community"], category: "Nature"});
  assert.deepEqual(result, {filed: "landscapes", collections: ["community", "landscapes"]});
});

test("a premium collection is never a target, so free walls stay free", async (t) => {
  const result = await file(t, {review: true, collections: ["community"], category: "Space"});
  assert.deepEqual(result, {filed: null, collections: ["community"]});
});

test("a pending wall and a wall already in another collection stay as they are", async (t) => {
  assert.deepEqual(await file(t, {review: false, collections: ["community"], category: "Nature"}),
    {filed: null, collections: ["community"]});
  assert.deepEqual(await file(t, {review: true, collections: ["community", "stock"], category: "Nature"}),
    {filed: null, collections: ["community", "stock"]});
});

test("no ref files nothing", async () => {
  assert.equal(await fileWallInCollection(undefined), null);
});

test("a collection takes the cover and time of its newest approved wall when that wall is newer", async (t) => {
  const store = installFakeDb(t, {
    "collections/c1": {name: "Landscapes", thumb1: "old", lastEditTime: at("2021-12-27T00:00:00Z")},
    "collections/c2": {name: "Flat", thumb1: "flat", lastEditTime: at("2021-12-27T16:50:00Z")},
    "collections/c3": {name: "Empty", thumb1: "empty", lastEditTime: at("2021-01-01T00:00:00Z")},
    "walls/w1": {review: true, collections: ["community", "landscapes"], createdAt: at("2026-10-01T00:00:00Z"),
      wallpaper_thumb: "t1"},
    "walls/w2": {review: true, collections: ["landscapes"], createdAt: at("2026-09-01T00:00:00Z"),
      wallpaper_thumb: "t2"},
    "walls/w3": {review: false, collections: ["landscapes"], createdAt: at("2026-10-10T00:00:00Z"),
      wallpaper_thumb: "t3"},
    "walls/w4": {review: true, collections: ["flat"], createdAt: at("2021-12-27T16:09:00Z"), wallpaper_thumb: "t4"},
  });

  assert.deepEqual(await refreshCollectionCovers(), ["landscapes"]);
  assert.equal(store.get("collections/c1")?.thumb1, "t1");
  assert.equal((store.get("collections/c1")?.lastEditTime as admin.firestore.Timestamp).toMillis(),
    at("2026-10-01T00:00:00Z").toMillis());
  assert.equal(store.get("collections/c2")?.thumb1, "flat");
  assert.equal(store.get("collections/c3")?.thumb1, "empty");
});
