process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import * as pushGallery from "../pushGallery";
import {db} from "../common";
import {
  publicFolderDeps,
  publicFolderName,
  removeFolderFollowsBetween,
  removeOwnerPublicFolders,
  refreshWallInPublicFolders,
  removePublicFolder,
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
  t.mock.method(publicFolderDeps, "premium", async () => ["abstract"]);
  return installFakeDb(t, {
    "walls/W1": {id: "w1", review: true, wallpaper_thumb: THUMB, wallpaper_url: "https://secret/original.jpg",
      collections: ["nature"], originalProtected: true},
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

// Inject changes before a transaction starts, not between its reads and commit: the fake does not model retries.
function transactionSchedule(t: TestContext, before: () => void, after: () => void = () => undefined) {
  const run = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", ((callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    before();
    return run(callback).then((result) => {
      after(); return result;
    });
  }) as typeof db.runTransaction);
}

function afterDocumentRead(t: TestContext, path: string, hook: () => void) {
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", ((name: string) => {
    const original = collection(name);
    const doc = original.doc.bind(original);
    return {...original, doc: (id: string) => {
      const ref = doc(id);
      if (ref.path !== path) return ref;
      const get = ref.get.bind(ref);
      ref.get = async () => {
        const snapshot = await get(); hook(); return snapshot;
      };
      return ref;
    }};
  }) as typeof db.collection);
}

function afterQueryRead(t: TestContext, path: string, hook: () => void) {
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", ((name: string) => {
    const original = collection(name);
    if (name !== path) return original;
    const where = original.where.bind(original);
    const get = original.get.bind(original);
    return {...original,
      get: async () => {
        const snapshot = await get(); hook(); return snapshot;
      },
      where: (...args: Parameters<typeof original.where>) => {
        const query = where(...args);
        const queryGet = query.get.bind(query);
        query.get = async () => {
          const snapshot = await queryGet(); hook(); return snapshot;
        };
        return query;
      },
    };
  }) as typeof db.collection);
}

test("a full sync never publishes after a concurrent make-private commits", async (t) => {
  const store = setup(t);
  let exposed = false;
  transactionSchedule(t, () => {
    store.set("folders/f1", {...store.get("folders/f1"), public: false});
  }, () => {
    exposed ||= store.has("publicFolders/f1");
  });
  await syncPublicFolder("f1");
  assert.equal(exposed, false, "even a transient header exposes a private folder");
  assert.deepEqual(keysUnder(store, "publicFolders/"), []);
});

test("full and item sync never commit a deleted source item", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 0, followerCount: 0, covers: []});
  let exposed = false;
  transactionSchedule(t, () => {
    store.delete("folders/f1/items/prism_w1");
  }, () => {
    exposed ||= store.has("publicFolders/f1/items/prism_w1");
  });
  await syncPublicFolderItem("f1", "prism_w1");
  await syncPublicFolder("f1");
  assert.equal(exposed, false, "an old computation must not commit after source deletion");
});

test("follow refuses stale public headers, deleted users and suspended owners", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", followerCount: 0});
  store.set("folders/f1", {...store.get("folders/f1"), public: false});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});
  store.set("folders/f1", {...store.get("folders/f1"), public: true});
  store.set("usersv2/a", {deleted: true});
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});
  store.set("usersv2/a", {});
  t.mock.method(publicFolderDeps, "authDisabled", async (uid: string) => uid === "a");
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});
});

test("unfollow cleans a private or deleted folder even at the daily cap", async (t) => {
  const store = setup(t);
  store.set(`folderFollowRateDaily/b_${TODAY}`, {day: TODAY, count: 200});
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});
  store.delete("folders/f1");
  assert.deepEqual(await followCall("b", {folderId: "f1", following: false}), {following: false});
  assert.equal(store.has("publicFolders/f1/followers/b"), false);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), false);
});

test("an invalid-name snapshot cannot make a concurrent valid rename private", async (t) => {
  const store = setup(t);
  store.set("folders/f1", {...store.get("folders/f1"), name: "bad\u202ename"});
  afterDocumentRead(t, "folders/f1", () => {
    store.set("folders/f1", {...store.get("folders/f1"), name: "Valid rename"});
  });
  await syncPublicFolder("f1");
  assert.equal(store.get("folders/f1")?.public, true);
  assert.equal(store.get("publicFolders/f1")?.name, "Valid rename");
});

test("a delayed owner cleanup cannot remove a newly transferred header", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", followerCount: 0});
  afterQueryRead(t, "publicFolders", () => {
    store.set("folders/f1", {...store.get("folders/f1"), ownerId: "b"});
    store.set("publicFolders/f1", {ownerId: "b", name: "New owner", followerCount: 1});
    store.set("publicFolders/f1/items/new", {id: "new"});
    store.set("publicFolders/f1/followers/c", {uid: "c"});
    store.set("usersv2/c/followedFolders/f1", {folderId: "f1", ownerId: "b"});
  });
  await removeOwnerPublicFolders("a");
  assert.equal(store.get("publicFolders/f1")?.ownerId, "b");
  assert.equal(store.has("publicFolders/f1/items/new"), true);
  assert.equal(store.has("usersv2/c/followedFolders/f1"), true);
});

test("cleanup resumed after another cleanup and republish cannot erase the new generation", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});
  let resumed = false;
  // Pause after A captured the old children, then let B finish removal and republish before A resumes.
  const collection = db.collection.bind(db);
  t.mock.method(db, "collection", ((name: string) => {
    const original = collection(name);
    if (name !== "publicFolders") return original;
    const doc = original.doc.bind(original);
    return {...original, doc: (id: string) => {
      const header = doc(id);
      const childCollection = header.collection.bind(header);
      header.collection = ((child: string) => {
        const children = childCollection(child);
        if (child !== "followers") return children;
        const get = children.get.bind(children);
        children.get = async () => {
          const snapshot = await get();
          republish();
          return snapshot;
        };
        return children;
      }) as typeof header.collection;
      return header;
    }};
  }) as typeof db.collection);
  const republish = () => {
    if (resumed) return;
    resumed = true;
    // Another remover completed the old generation, then a current sync and follow recreated these paths.
    store.set("publicFolderState/f1", {generation: "republished", deleting: false});
    store.set("publicFolders/f1", {generation: "republished", ownerId: "a", followerCount: 1});
    store.set("publicFolders/f1/items/prism_w1", {id: "current"});
  };
  await removePublicFolder("f1");
  assert.equal(resumed, true);
  assert.equal(store.get("publicFolders/f1")?.generation, "republished");
  assert.equal(store.get("publicFolders/f1/items/prism_w1")?.id, "current");
  assert.equal(store.has("publicFolders/f1/followers/b"), true);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), true);
});

test("owner cleanup resumes a failed fenced deletion after its header is gone", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});
  let fail = true;
  transactionSchedule(t, () => {
    if (fail && !store.has("publicFolders/f1") && store.get("publicFolderState/f1")?.deleting === true) {
      throw new Error("temporary cleanup failure");
    }
  });
  await assert.rejects(() => removeOwnerPublicFolders("a"), /temporary cleanup failure/);
  assert.equal(store.has("publicFolders/f1"), false);
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), true);
  fail = false;
  await removeOwnerPublicFolders("a");
  assert.deepEqual(keysUnder(store, "publicFolders/f1/"), []);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), false);
  assert.equal(store.get("publicFolderState/f1")?.deleting, false);
});

test("a retry after an item commit repairs lastAddedAt even if the header refresh failed", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("publicFolders/f1", {...store.get("publicFolders/f1"), lastAddedAt: at(1)});
  store.set("walls/W2", {id: "w2", review: true, wallpaper_thumb: THUMB, collections: ["nature"], originalProtected: true});
  store.set("folders/f1/items/prism_w2", {ownerId: "a", id: "w2", provider: "Prism", wallpaperDocumentId: "W2"});
  let fail = true;
  transactionSchedule(t, () => {
    if (fail && store.has("publicFolders/f1/items/prism_w2")) throw new Error("header refresh failed");
  });
  await assert.rejects(() => syncPublicFolderItem("f1", "prism_w2"), /header refresh failed/);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 1);
  fail = false;
  await syncPublicFolderItem("f1", "prism_w2");
  const projectedAt = store.get("publicFolders/f1/items/prism_w2")?.projectedAt as admin.firestore.Timestamp;
  const lastAddedAt = store.get("publicFolders/f1")?.lastAddedAt as admin.firestore.Timestamp;
  assert.ok(lastAddedAt.toMillis() >= projectedAt.toMillis());
  assert.equal(store.get("publicFolders/f1")?.itemCount, 2);
});

test("an already committed follow retries successfully at the daily cap without count drift", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", followerCount: 1});
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});
  store.set(`folderFollowRateDaily/b_${TODAY}`, {day: TODAY, count: 200});
  assert.deepEqual(await followCall("b", {folderId: "f1", following: true}), {following: true});
  assert.equal(store.get("publicFolders/f1")?.followerCount, 1);
  assert.equal(store.get(`folderFollowRateDaily/b_${TODAY}`)?.count, 200);
});

test("same-owner folder ID reuse clears the old incarnation's followers", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  store.set("publicFolders/f1/followers/b", {uid: "b"});
  store.set("usersv2/b/followedFolders/f1", {folderId: "f1", ownerId: "a"});
  store.delete("folders/f1");
  store.set("folders/f1", {ownerId: "a", name: "New folder", public: true});
  await syncPublicFolder("f1");
  assert.equal(store.get("publicFolders/f1")?.name, "New folder");
  assert.equal(store.get("publicFolders/f1")?.followerCount, 0);
  assert.equal(store.has("publicFolders/f1/followers/b"), false);
  assert.equal(store.has("usersv2/b/followedFolders/f1"), false);
});

test("follow checks current account lifecycle gates inside its transaction", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", followerCount: 0});
  transactionSchedule(t, () => {
    store.delete("usersv2/b");
    store.set("creatorDeletionState/b", {closed: true});
  });
  await assert.rejects(() => followCall("b", {folderId: "f1", following: true}), {code: "failed-precondition"});
  assert.equal(store.has("publicFolders/f1/followers/b"), false);
  assert.equal(store.get("publicFolders/f1")?.followerCount, 0);
});

test("a stale header refresh cannot restore an old name", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  transactionSchedule(t, () => {
    store.set("folders/f1", {...store.get("folders/f1"), name: "Current name"});
  });
  await syncPublicFolderItem("f1", "prism_w1");
  assert.equal(store.get("publicFolders/f1")?.name, "Current name");
});

test("a gallery finishing after a same-cover republish cannot update the new header", async (t) => {
  const store = setup(t);
  t.mock.method(pushGallery, "buildPushGallery", async () => {
    store.set("publicFolderState/f1", {generation: "new-generation", deleting: false});
    store.set("publicFolders/f1", {...store.get("publicFolders/f1"), generation: "new-generation"});
    return {stripUrl: "https://img.prismwalls.com/push-gallery/v1/stale.jpg", heroUrl: THUMB,
      wallIds: ["w1", "w2"], count: 2, thumbIndex: 0, tags: []};
  });
  await syncPublicFolder("f1");
  assert.equal(store.get("publicFolders/f1")?.shareImage, undefined);
});

test("a gallery finishing after its current wall becomes gated is discarded", async (t) => {
  const store = setup(t);
  t.mock.method(pushGallery, "buildPushGallery", async () => {
    store.set("walls/W1", {...store.get("walls/W1"), dropReserved: true});
    return {stripUrl: "https://img.prismwalls.com/push-gallery/v1/stale.jpg", heroUrl: THUMB,
      wallIds: ["w1", "w2"], count: 2, thumbIndex: 0, tags: []};
  });
  await syncPublicFolder("f1");
  assert.equal(store.get("publicFolders/f1")?.shareImage, undefined);
});

test("original and signed thumbnail URLs never enter a public projection", async (t) => {
  const store = setup(t);
  for (const thumb of ["https://secret/original.jpg", `${THUMB}?token=secret`]) {
    store.set("walls/W1", {...store.get("walls/W1"), wallpaper_thumb: thumb});
    await syncPublicFolder("f1");
    assert.equal(store.has("publicFolders/f1/items/prism_w1"), false);
    assert.deepEqual(store.get("publicFolders/f1")?.covers, []);
  }
});

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
  store.set("walls/WR", {id: "wr", review: false, wallpaper_thumb: THUMB, collections: ["nature"],
    originalProtected: true});
  store.set("walls/WD", {id: "wd", review: true, dropReserved: true, wallpaper_thumb: THUMB,
    collections: ["nature"], originalProtected: true});
  store.set("walls/WS", {id: "ws", review: true, is_streak_exclusive: true, wallpaper_thumb: THUMB,
    collections: ["nature"], originalProtected: true});
  store.set("walls/WW", {id: "ww", review: true, dropWeek: "2026-W40", wallpaper_thumb: THUMB,
    collections: ["nature"], originalProtected: true});
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
    collections: ["nature"], originalProtected: true});
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

test("an item sync restores the full source when the public header is missing", async (t) => {
  const store = setup(t);
  store.set("walls/W2", {id: "w2", review: true, wallpaper_thumb: THUMB, collections: ["nature"], originalProtected: true});
  store.set("folders/f1/items/prism_w2", {ownerId: "a", id: "w2", provider: "Prism", wallpaperDocumentId: "W2"});
  await syncPublicFolderItem("f1", "prism_w2");
  assert.equal(store.get("publicFolders/f1")?.itemCount, 2);
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), true);
  assert.equal(store.has("publicFolders/f1/items/prism_w2"), true);
});

test("an older item-add sync cannot resurrect an item deleted during its write", async (t) => {
  const store = setup(t);
  store.set("publicFolders/f1", {ownerId: "a", name: "Night", itemCount: 0, followerCount: 0, covers: []});
  let ownerChecks = 0;
  t.mock.method(publicFolderDeps, "authDisabled", async () => {
    ownerChecks++;
    if (ownerChecks === 2) store.delete("folders/f1/items/prism_w1");
    return false;
  });

  await syncPublicFolderItem("f1", "prism_w1");

  assert.equal(store.has("folders/f1/items/prism_w1"), false);
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), false);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 0);
});

test("a full sync retries when a source item changes during projection", async (t) => {
  const store = setup(t);
  let ownerChecks = 0;
  t.mock.method(publicFolderDeps, "authDisabled", async () => {
    ownerChecks++;
    if (ownerChecks === 2) store.delete("folders/f1/items/prism_w1");
    return false;
  });

  await syncPublicFolder("f1");

  assert.equal(store.has("folders/f1/items/prism_w1"), false);
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), false);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 0);
});

test("a missing share image is retried even when the covers did not change", async (t) => {
  const store = setup(t);
  store.set("walls/W2", {id: "w2", review: true, wallpaper_thumb: "https://img.prismwalls.com/previews/bbb.img"});
  store.set("folders/f1/items/prism_w2", {ownerId: "a", id: "w2", provider: "Prism", wallpaperDocumentId: "W2"});
  let attempts = 0;
  t.mock.method(pushGallery, "buildPushGallery", async () => {
    attempts++;
    return attempts === 1 ? null : {
      stripUrl: "https://img.prismwalls.com/push-gallery/v1/test.jpg", heroUrl: THUMB, wallIds: ["w1", "w2"],
      count: 2, thumbIndex: 0, tags: [],
    };
  });

  await syncPublicFolder("f1");
  await syncPublicFolder("f1");

  assert.equal(attempts, 2);
  assert.equal(store.get("publicFolders/f1")?.shareImage, "https://img.prismwalls.com/push-gallery/v1/test.jpg");
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

test("a wall in a premium collection stays out of the projection, like the free gallery gate", async (t) => {
  const store = setup(t);
  store.set("walls/W1", {...store.get("walls/W1"), collections: ["abstract"]});
  await syncPublicFolder("f1");
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), false);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 0);
});

test("a projected wall that is held for review leaves every public folder", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), true);
  const before = store.get("walls/W1");
  const after = {...before, review: false, heldForReview: true};
  store.set("walls/W1", after);
  await refreshWallInPublicFolders("W1", before, after);
  assert.equal(store.has("publicFolders/f1/items/prism_w1"), false);
  assert.equal(store.get("publicFolders/f1")?.itemCount, 0);
  assert.deepEqual(store.get("publicFolders/f1")?.covers, []);
  assert.equal(store.has("folders/f1/items/prism_w1"), true);
});

test("a wall write that keeps it public changes no public folder", async (t) => {
  const store = setup(t);
  await syncPublicFolder("f1");
  const header = store.get("publicFolders/f1");
  const before = store.get("walls/W1");
  await refreshWallInPublicFolders("W1", before, {...before, views: 10});
  assert.deepEqual(store.get("publicFolders/f1"), header);
});

test("an item write in a private folder makes no Auth call", async (t) => {
  const store = setup(t);
  store.set("folders/f1", {...store.get("folders/f1"), public: false});
  let authCalls = 0;
  t.mock.method(publicFolderDeps, "authDisabled", async () => {
    authCalls++;
    return false;
  });
  await syncPublicFolderItem("f1", "prism_w1");
  assert.equal(authCalls, 0);
  assert.equal(store.has("publicFolders/f1"), false);
});
