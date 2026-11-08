process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {publicFolderDeps} from "../publicFolders";
import {
  addWallToSmartFolder,
  anchorFor,
  changesSmartKeys,
  createSmartFolder,
  matchesSmartRules,
  fillSmartFolder,
  findSmartMatches,
  onWallSmartFolders,
  onSmartFollowWritten,
  updateSmartFolderRules,
  parseSmartRules,
  removeOwnerSmartFolders,
  removeSmartFolder,
  syncWallSmartFolders,
  wallSmartKeys,
  type SmartRule,
} from "../smartFolders";
import {MOODS} from "../wallMoods";
import {PALETTE} from "../wallColors";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const THUMB = "https://img.prismwalls.com/previews/aaa.img";
const PREMIUM = ["abstract"];
const NOW = Date.now();
const BASE = 1_700_000_000_000;
const DESKTOP = {v: "0123456789abcdef", width: 2560, height: 1600, wideHeight: 1440, thumb: THUMB};
const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const keysUnder = (store: Map<string, Doc>, prefix: string) =>
  [...store.keys()].filter((key) => key.startsWith(prefix)).sort();
const itemIds = (store: Map<string, Doc>, folderId: string) =>
  keysUnder(store, `folders/${folderId}/items/`).map((key) => key.split("/").pop());

type BatchRef = {
  create: (data: Doc) => Promise<unknown>;
  set: (data: Doc, options?: {merge?: boolean}) => Promise<unknown>;
  delete: () => Promise<unknown>;
};

function fakeBatch() {
  const ops: Array<() => Promise<unknown>> = [];
  const batch = {
    create: (ref: BatchRef, data: Doc) => {
      ops.push(() => ref.create(data));
      return batch;
    },
    set: (ref: BatchRef, data: Doc, options?: {merge?: boolean}) => {
      ops.push(() => ref.set(data, options));
      return batch;
    },
    delete: (ref: BatchRef) => {
      ops.push(() => ref.delete());
      return batch;
    },
    commit: async () => {
      for (const op of ops) await op();
    },
  };
  return batch;
}

function setup(t: TestContext, seed: Record<string, Doc> = {}, observed?: Parameters<typeof installFakeDb>[2]) {
  t.mock.method(publicFolderDeps, "premium", async () => PREMIUM);
  t.mock.method(db, "batch", (() => fakeBatch()) as unknown as typeof db.batch);
  t.mock.method(db, "getAll", ((...refs: Array<{get: () => Promise<unknown>}>) =>
    Promise.all(refs.map((ref) => ref.get()))) as unknown as typeof db.getAll);
  return installFakeDb(t, seed, observed);
}

function gatedWall(overrides: Doc = {}): Doc {
  return {
    id: "w1", review: true, originalProtected: true, collections: ["nature"], wallpaper_thumb: THUMB,
    wallpaper_url: "https://secret/w1.jpg", createdAt: at(NOW - 3_600_000), colors: ["blue"], category: "Nature",
    creatorUid: "c1", ...overrides,
  };
}

function seedWall(docId: string, wall: Doc, withKeys = true): Record<string, Doc> {
  const seed: Record<string, Doc> = {[`walls/${docId}`]: wall};
  if (withKeys) {
    seed[`smartWallKeys/${docId}`] = {
      keys: wallSmartKeys(wall, PREMIUM), wallId: wall.id, thumb: wall.wallpaper_thumb, createdAt: wall.createdAt,
    };
  }
  return seed;
}

function smartFolderSeed(folderId: string, rules: SmartRule[], anchorKind: string, anchors: string[],
  ownerId = "u1"): Record<string, Doc> {
  return {
    [`folders/${folderId}`]: {ownerId, name: folderId, smartRules: rules, itemCount: 0, covers: []},
    [`smartFolderIndex/${folderId}`]: {ownerId, rules, anchorKind, anchors},
  };
}

function smartItemSeed(folderId: string, wallId: string, wallDocId: string): Record<string, Doc> {
  return {
    [`folders/${folderId}/items/prism_${wallId}`]: {
      id: wallId, ownerId: "u1", smart: true, wallpaperDocumentId: wallDocId, addedAt: at(BASE),
    },
  };
}

const callCreate = (uid: string | undefined, data: unknown) =>
  createSmartFolder.run({auth: uid ? {uid} : undefined, data} as Parameters<typeof createSmartFolder.run>[0]);

test("parseSmartRules sorts a valid set and refuses invalid sets", () => {
  assert.deepEqual(parseSmartRules([
    {kind: "colour", value: "blue"}, {kind: "category", value: "Nature"}, {kind: "creator", value: "c1"},
  ]), [
    {kind: "creator", value: "c1"}, {kind: "category", value: "Nature"}, {kind: "colour", value: "blue"},
  ], "rules must be sorted in SMART_KINDS order");
  assert.equal(parseSmartRules([]), null, "an empty rule list must be refused");
  assert.equal(parseSmartRules([{kind: "shade", value: "blue"}]), null, "an unknown kind must be refused");
  assert.equal(parseSmartRules([{kind: "colour", value: "mauve"}]), null, "an unknown colour must be refused");
  assert.equal(parseSmartRules([
    {kind: "creator", value: "c1"}, {kind: "category", value: "Nature"}, {kind: "colour", value: "blue"},
    {kind: "mood", value: "dreamy"},
  ]), null, "more than 3 kinds must be refused");
  assert.equal(parseSmartRules(
    ["red", "orange", "yellow", "green", "teal", "blue", "black"].map((value) => ({kind: "colour", value})),
  ), null, "more than 6 values in one kind must be refused");
  assert.deepEqual(parseSmartRules([
    {kind: "followed", value: "ignored"}, {kind: "desktop"}, {kind: "editorsChoice", value: "x"},
  ]), [
    {kind: "editorsChoice", value: ""}, {kind: "followed", value: ""}, {kind: "desktop", value: ""},
  ], "valueless kinds must drop their value");
});

test("wallSmartKeys gives keys only to a gated wall", () => {
  assert.deepEqual(wallSmartKeys(gatedWall({review: false}), PREMIUM), [], "a wall under review must have no keys");
  assert.deepEqual(wallSmartKeys(gatedWall({collections: ["abstract"]}), PREMIUM), [],
    "a premium-collection wall must have no keys");
  assert.deepEqual(wallSmartKeys(gatedWall({wallpaper_thumb: "https://evil.example/x.jpg"}), PREMIUM), [],
    "a non-preview thumb must have no keys");
  const keys = wallSmartKeys(gatedWall({editorsChoiceAt: at(NOW), desktopVariant: DESKTOP}), PREMIUM);
  for (const key of ["colour:blue", "category:Nature", "creator:c1", "editorsChoice", "desktop"]) {
    assert.ok(keys.includes(key), `gated wall keys must include ${key}, got ${keys.join(", ")}`);
  }
});

test("matchesSmartRules checks each kind, ANDs kinds and ORs values within a kind", () => {
  const rule = (kind: SmartRule["kind"], value = ""): SmartRule => ({kind, value});
  assert.equal(matchesSmartRules([rule("mood", "duo_reveal")], ["mood:duo_reveal"], false), true,
    "a mood rule must match its mood key");
  assert.equal(matchesSmartRules([rule("mood", "duo_reveal")], ["mood:dreamy"], false), false,
    "a mood rule must not match another mood");
  assert.equal(matchesSmartRules([rule("category", "Pastel")], ["category:Pastel"], false), true,
    "a category rule must match its category key");
  assert.equal(matchesSmartRules([rule("category", "Pastel")], ["category:Nature"], false), false,
    "a category rule must not match another category");
  assert.equal(matchesSmartRules([rule("colour", "blue")], ["colour:blue"], false), true,
    "a colour rule must match its colour key");
  assert.equal(matchesSmartRules([rule("colour", "blue")], ["colour:teal"], false), false,
    "a colour rule must not match another colour");
  assert.equal(matchesSmartRules([rule("creator", "c1")], ["creator:c1"], false), true,
    "a creator rule must match its creator key");
  assert.equal(matchesSmartRules([rule("creator", "c1")], ["creator:c2"], false), false,
    "a creator rule must not match another creator");
  assert.equal(matchesSmartRules([rule("followed")], ["creator:c1"], true), true,
    "a followed rule must match when the owner follows the creator");
  assert.equal(matchesSmartRules([rule("followed")], ["creator:c1"], false), false,
    "a followed rule must not match when the owner does not follow the creator");
  assert.equal(matchesSmartRules([rule("followed")], [], true), false,
    "a followed rule must not match a wall with no keys");
  assert.equal(matchesSmartRules([rule("desktop")], ["desktop"], false), true, "a desktop rule must match");
  assert.equal(matchesSmartRules([rule("desktop")], [], false), false, "a desktop rule must not match without the key");
  assert.equal(matchesSmartRules([rule("editorsChoice")], ["editorsChoice"], false), true,
    "an editorsChoice rule must match");
  assert.equal(matchesSmartRules([rule("editorsChoice")], [], false), false,
    "an editorsChoice rule must not match without the key");
  const andRules = [rule("colour", "blue"), rule("category", "Pastel")];
  assert.equal(matchesSmartRules(andRules, ["colour:blue", "category:Nature"], false), false,
    "two kinds must AND: one matching kind is not enough");
  assert.equal(matchesSmartRules(andRules, ["colour:blue", "category:Pastel"], false), true,
    "two kinds must pass when both match");
  assert.equal(matchesSmartRules([rule("colour", "blue"), rule("colour", "teal")], ["colour:teal"], false), true,
    "values within one kind must OR");
  assert.equal(matchesSmartRules([], ["colour:blue"], false), false, "an empty rule set must match nothing");
});

test("anchorFor picks the first kind in index order and one key per value", () => {
  assert.deepEqual(anchorFor([{kind: "colour", value: "blue"}, {kind: "creator", value: "c1"}], []),
    {kind: "creator", keys: ["creator:c1"]}, "creator must beat colour");
  assert.deepEqual(anchorFor([{kind: "followed", value: ""}], ["c1", "c2", "bad uid!"]),
    {kind: "followed", keys: ["creator:c1", "creator:c2"]},
    "followed must store one creator key per valid follow");
  assert.deepEqual(anchorFor([{kind: "category", value: "Nature"}, {kind: "editorsChoice", value: ""}], []),
    {kind: "editorsChoice", keys: ["editorsChoice"]}, "editorsChoice must beat category");
});

test("createSmartFolder fills the new folder with the matching walls only and refuses a guest or bad rules", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall({id: "w1", colors: ["blue"]})),
    ...seedWall("W2", gatedWall({id: "w2", colors: ["teal"]})),
    ...seedWall("W3", gatedWall({id: "w3", colors: ["blue", "black"], category: "Pastel", creatorUid: "c2"})),
    "usersv2/u1": {email: "u1@x.com"},
  });
  const created = await callCreate("u1", {name: "Blue", rules: [{kind: "colour", value: "blue"}]});
  const folderId = created.folderId;
  assert.deepEqual(store.get(`folders/${folderId}`)?.smartRules, [{kind: "colour", value: "blue"}],
    "the folder must store the parsed rules");
  assert.equal(store.get(`folders/${folderId}`)?.ownerId, "u1", "the folder owner must be the caller");
  assert.deepEqual(store.get(`smartFolderIndex/${folderId}`)?.anchors, ["colour:blue"],
    "the index must anchor on the colour key");
  assert.equal(store.get(`smartFolderIndex/${folderId}`)?.anchorKind, "colour", "the index anchor kind must be colour");
  assert.deepEqual(itemIds(store, folderId), ["prism_w1", "prism_w3"],
    "only the walls with the blue colour must become items");
  for (const id of ["prism_w1", "prism_w3"]) {
    const item = store.get(`folders/${folderId}/items/${id}`);
    assert.equal(item?.smart, true, `${id} must be marked smart`);
    assert.equal(item?.ownerId, "u1", `${id} must be owned by the folder owner`);
  }
  assert.equal(store.get(`folders/${folderId}/items/prism_w1`)?.wallpaperDocumentId, "W1",
    "the item must point at its wall document");
  assert.equal(created.count, 2, "the reported count must be the item count after the fill");
  await assert.rejects(callCreate(undefined, {name: "Blue", rules: [{kind: "colour", value: "blue"}]}),
    {code: "unauthenticated"}, "a guest must be refused");
  await assert.rejects(callCreate("u1", {name: "Blue", rules: [{kind: "shade", value: "blue"}]}),
    {code: "invalid-argument"}, "an unknown rule kind must be refused");
});

test("createSmartFolder returns the committed folder when its first fill fails, so a retry makes no duplicate", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall({id: "w1", colors: ["blue"]})),
    "usersv2/u1": {email: "u1@x.com"},
  });
  t.mock.method(publicFolderDeps, "premium", async () => {
    throw new Error("transient read failure");
  });
  const created = await callCreate("u1", {name: "Blue", rules: [{kind: "colour", value: "blue"}]});
  assert.equal(created.count, 0, "a failed fill reports no items");
  assert.equal(store.get(`folders/${created.folderId}`)?.ownerId, "u1", "the committed folder must be returned");
  assert.equal([...store.keys()].filter((key) => /^folders\/[^/]+$/.test(key)).length, 1, "one folder exists");
});

test("syncWallSmartFolders adds a new wall only to the folder whose anchor it matches, once", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall({id: "w1"}), false),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...smartFolderSeed("sf2", [{kind: "colour", value: "teal"}], "colour", ["colour:teal"]),
  });
  assert.deepEqual(await syncWallSmartFolders("W1"), {added: 1, checked: 1},
    "the first sync must add one wall to one candidate folder");
  assert.deepEqual(itemIds(store, "sf1"), ["prism_w1"], "the matching folder must hold the wall");
  assert.deepEqual(itemIds(store, "sf2"), [], "the non-matching folder must not hold the wall");
  assert.ok((store.get("smartWallKeys/W1")?.keys as string[]).includes("colour:blue"),
    "the sync must write the wall's smart keys");
  assert.deepEqual(await syncWallSmartFolders("W1"), {added: 0, checked: 1}, "a repeated sync must add nothing");
  assert.deepEqual(itemIds(store, "sf1"), ["prism_w1"], "a repeated sync must keep one item");
});

test("the followed rule adds a wall only for an owner who follows its creator", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall({id: "w1", creatorUid: "c1"}), false),
    ...smartFolderSeed("sf1", [{kind: "followed", value: ""}], "followed", ["creator:c1"], "u1"),
    ...smartFolderSeed("sf2", [{kind: "followed", value: ""}], "followed", ["creator:c1"], "u2"),
    "profiles/u1/following/c1": {},
  });
  assert.deepEqual(await syncWallSmartFolders("W1"), {added: 1, checked: 2},
    "only the owner with a follow edge must receive the wall");
  assert.deepEqual(itemIds(store, "sf1"), ["prism_w1"], "the followed owner must hold the wall");
  assert.deepEqual(itemIds(store, "sf2"), [], "an owner without a follow edge must not hold the wall");
});

test("addWallToSmartFolder keeps a full folder at 500 items by dropping the oldest", async (t) => {
  const seed: Record<string, Doc> = {
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...seedWall("W9", gatedWall({id: "w9"})),
  };
  for (let i = 0; i < 500; i++) {
    seed[`folders/sf1/items/old${i}`] = {
      id: `old${i}`, ownerId: "u1", wallpaperDocumentId: `OLD${i}`, addedAt: at(BASE + i * 1000),
    };
  }
  const store = setup(t, seed);
  assert.equal(await addWallToSmartFolder("sf1", "W9", PREMIUM), true, "the matching wall must be added");
  const ids = itemIds(store, "sf1");
  assert.equal(ids.length, 500, "the folder must stay at 500 items");
  assert.ok(!ids.includes("old0"), "the oldest item (lowest addedAt) must be dropped");
  assert.ok(ids.includes("prism_w9"), "the new wall must be in the folder");
  assert.equal(store.get("folders/sf1/items/prism_w9")?.smart, true, "the new item must be marked smart");
});

test("a rejected wall and a deleted wall are removed from smart folders on sync", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall({id: "w1"})),
    ...seedWall("W2", gatedWall({id: "w2"})),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...smartItemSeed("sf1", "w1", "W1"),
    ...smartItemSeed("sf1", "w2", "W2"),
  });
  store.set("walls/W1", gatedWall({id: "w1", review: false}));
  store.delete("walls/W2");
  assert.deepEqual(await syncWallSmartFolders("W1"), {added: 0, checked: 1}, "the rejected wall's item must be checked");
  assert.equal(store.has("folders/sf1/items/prism_w1"), false, "the rejected wall's item must be deleted");
  assert.equal(store.has("smartWallKeys/W1"), false, "the rejected wall's smart keys must be deleted");
  assert.deepEqual(await syncWallSmartFolders("W2"), {added: 0, checked: 1}, "the deleted wall's item must be checked");
  assert.equal(store.has("folders/sf1/items/prism_w2"), false, "the deleted wall's item must be deleted");
  assert.equal(store.has("smartWallKeys/W2"), false, "the deleted wall's smart keys must be deleted");
});

test("removeSmartFolder deletes the index entry and the smart items but keeps manual items", async (t) => {
  const store = setup(t, {
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...smartItemSeed("sf1", "w1", "W1"),
    "folders/sf1/items/manual1": {id: "manual1", ownerId: "u1", wallpaperDocumentId: "M1", addedAt: at(BASE)},
  });
  await removeSmartFolder("sf1");
  assert.equal(store.has("smartFolderIndex/sf1"), false, "the index entry must be deleted");
  assert.deepEqual(itemIds(store, "sf1"), ["manual1"], "only the smart item must be deleted");
});

test("removeOwnerSmartFolders deletes only the given owner's index entries", async (t) => {
  const store = setup(t, {
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"], "u1"),
    ...smartFolderSeed("sf2", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"], "u2"),
    "smartFolderOwners/u1": {ownerId: "u1"},
    "smartFolderOwners/u2": {ownerId: "u2"},
  });
  await removeOwnerSmartFolders("u1");
  assert.equal(store.has("smartFolderIndex/sf1"), false, "the owner's index entry must be deleted");
  assert.equal(store.has("smartFolderIndex/sf2"), true, "another owner's index entry must be kept");
  assert.equal(store.has("smartFolderOwners/u1"), false, "the owner's create lock must be deleted");
  assert.equal(store.has("smartFolderOwners/u2"), true, "another owner's create lock must be kept");
});

test("changesSmartKeys ignores counter-only writes and reacts to key fields and creates or deletes", () => {
  assert.equal(changesSmartKeys({views: 1, review: true}, {views: 2, review: true}), false,
    "a counter-only change must not change smart keys");
  assert.equal(changesSmartKeys({colors: ["blue"]}, {colors: ["teal"]}), true,
    "a colour change must change smart keys");
  assert.equal(changesSmartKeys(undefined, {review: true}), true, "a created wall must change smart keys");
  assert.equal(changesSmartKeys({review: true}, undefined), true, "a deleted wall must change smart keys");
});

test("counter-only trigger events do no database or premium reads", async (t) => {
  setup(t);
  t.mock.method(db, "collection", () => {
    throw new Error("unexpected read");
  });
  t.mock.method(publicFolderDeps, "premium", async () => {
    throw new Error("unexpected premium read");
  });
  const before = gatedWall({views: 1});
  await onWallSmartFolders.run({params: {wallId: "W1"}, data: {
    before: {data: () => before}, after: {data: () => ({...before, views: 2})},
  }} as unknown as Parameters<typeof onWallSmartFolders.run>[0]);
});

test("sync does not bill manual saves as held smart items and writes derived keys transactionally", async (t) => {
  const seed = {
    ...seedWall("W1", gatedWall()),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
  };
  for (let i = 0; i < 100; i++) seed[`folders/manual${i}/items/prism_w1`] = {wallpaperDocumentId: "W1"};
  const observed = {reads: 0, writes: 0, outsideReads: 0, outsideWrites: 0};
  const store = setup(t, seed, observed);
  await syncWallSmartFolders("W1");
  assert.ok(store.has("folders/sf1/items/prism_w1"));
  assert.ok(observed.outsideReads < 10, "manual saves must not increase approval reads");
  assert.equal(observed.outsideWrites, 0, "derived keys must commit against a transactionally read wall");
});

for (const change of ["rules", "reject", "delete"] as const) {
  test(`fill rechecks a ${change} change after candidate discovery`, async (t) => {
    const store = setup(t, {
      ...seedWall("W1", gatedWall()),
      ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    });
    const transact = db.runTransaction.bind(db);
    let first = true;
    t.mock.method(db, "runTransaction", ((callback: Parameters<typeof db.runTransaction>[0]) => {
      if (first) {
        first = false;
        if (change === "rules") store.set("folders/sf1", {ownerId: "u1", smartRules: [{kind: "colour", value: "teal"}]});
        if (change === "reject") store.set("walls/W1", gatedWall({review: false}));
        if (change === "delete") store.delete("folders/sf1");
      }
      return transact(callback);
    }) as typeof db.runTransaction);
    await fillSmartFolder("sf1");
    assert.deepEqual(itemIds(store, "sf1"), [], "stale fill candidates must not be written");
  });
}

test("fill does not delete a live matching item because its derived keys are stale", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall(), false),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...smartItemSeed("sf1", "w1", "W1"),
  });
  await fillSmartFolder("sf1");
  assert.deepEqual(itemIds(store, "sf1"), ["prism_w1"]);
  assert.equal((store.get("folders/sf1/items/prism_w1")?.addedAt as admin.firestore.Timestamp).toMillis(), BASE);
});

test("unfollow removes existing items even when followed is not the anchor", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall()),
    ...smartFolderSeed("sf1", [{kind: "creator", value: "c1"}, {kind: "followed", value: ""}], "creator", ["creator:c1"]),
    ...smartItemSeed("sf1", "w1", "W1"),
  });
  await onSmartFollowWritten.run({params: {uid: "u1", targetUid: "c1"}, data: {
    before: {exists: true}, after: {exists: false},
  }} as unknown as Parameters<typeof onSmartFollowWritten.run>[0]);
  assert.deepEqual(itemIds(store, "sf1"), []);
  assert.deepEqual(store.get("smartFolderIndex/sf1")?.anchors, ["creator:c1"]);
});

test("late follow events use the live edge and cannot mutate a rewritten anchor", async (t) => {
  const store = setup(t, {
    ...smartFolderSeed("sf1", [{kind: "followed", value: ""}], "followed", []),
  });
  const event = {params: {uid: "u1", targetUid: "c1"}, data: {before: {exists: false}, after: {exists: true}}};
  await onSmartFollowWritten.run(event as unknown as Parameters<typeof onSmartFollowWritten.run>[0]);
  assert.deepEqual(store.get("smartFolderIndex/sf1")?.anchors, [], "a late follow must not undo an unfollow");
  store.set("profiles/u1/following/c1", {});
  await onSmartFollowWritten.run({...event, data: {before: {exists: true}, after: {exists: false}}} as unknown as
    Parameters<typeof onSmartFollowWritten.run>[0]);
  assert.deepEqual(store.get("smartFolderIndex/sf1")?.anchors, ["creator:c1"], "a late unfollow must not undo a follow");
  const transact = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", ((callback: Parameters<typeof db.runTransaction>[0]) => {
    store.set("folders/sf1", {ownerId: "u1", smartRules: [{kind: "colour", value: "blue"}]});
    store.set("smartFolderIndex/sf1", {ownerId: "u1", anchorKind: "colour", anchors: ["colour:blue"]});
    return transact(callback);
  }) as typeof db.runTransaction);
  await onSmartFollowWritten.run(event as unknown as Parameters<typeof onSmartFollowWritten.run>[0]);
  assert.deepEqual(store.get("smartFolderIndex/sf1")?.anchors, ["colour:blue"]);
});

test("old fill candidates cannot evict more recently added items at the cap", async (t) => {
  const seed: Record<string, Doc> = {
    ...seedWall("W1", gatedWall({createdAt: at(BASE - 1000)})),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
  };
  for (let i = 0; i < 500; i++) {
    seed[`folders/sf1/items/old${i}`] = {
      id: `old${i}`, smart: true, wallpaperDocumentId: `OLD${i}`, addedAt: at(BASE + i),
    };
  }
  const store = setup(t, seed);
  const addWithTime: (folder: string, wall: string, premium: string[], at: admin.firestore.Timestamp) => Promise<boolean> =
    addWallToSmartFolder;
  assert.equal(await addWithTime("sf1", "W1", PREMIUM, at(BASE - 1000)), false);
  assert.equal(itemIds(store, "sf1").length, 500);
  assert.ok(store.has("folders/sf1/items/old0"));
});

test("missing preview configuration fails before creating a folder or deleting its items", async (t) => {
  const store = setup(t, {
    "usersv2/u1": {},
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...smartItemSeed("sf1", "w1", "W1"),
  });
  const base = process.env.R2_PREVIEW_BASE_URL;
  delete process.env.R2_PREVIEW_BASE_URL;
  try {
    await assert.rejects(callCreate("u1", {name: "Blue", rules: [{kind: "colour", value: "blue"}]}), /R2_PREVIEW_BASE_URL/);
    await assert.rejects(fillSmartFolder("sf1"), /R2_PREVIEW_BASE_URL/);
    assert.equal(keysUnder(store, "folders/").filter((key) => key.split("/").length === 2).length, 1);
    assert.ok(store.has("folders/sf1/items/prism_w1"));
  } finally {
    process.env.R2_PREVIEW_BASE_URL = base;
  }
});

test("simultaneous smart folder creation cannot exceed the owner limit", async (t) => {
  const seed: Record<string, Doc> = {"usersv2/u1": {}};
  for (let i = 0; i < 19; i++) {
    Object.assign(seed,
      smartFolderSeed(`sf${i}`, [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]));
  }
  const store = setup(t, seed);
  const result = await Promise.allSettled([1, 2].map(() =>
    callCreate("u1", {name: "Blue", rules: [{kind: "colour", value: "blue"}]})));
  assert.equal(result.filter((outcome) => outcome.status === "fulfilled").length, 1);
  assert.equal(keysUnder(store, "smartFolderIndex/").length, 20);
});

test("rule edits read follows in the same transaction as the rewritten anchor", async (t) => {
  const store = setup(t, {
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    "profiles/u1/following/c1": {},
  });
  const transact = db.runTransaction.bind(db);
  let transactions = 0;
  t.mock.method(db, "runTransaction", ((callback: Parameters<typeof db.runTransaction>[0]) => {
    if (++transactions === 2) store.delete("profiles/u1/following/c1");
    return transact(callback);
  }) as typeof db.runTransaction);
  await updateSmartFolderRules.run({auth: {uid: "u1"}, data: {folderId: "sf1", rules: [{kind: "followed"}]}} as
    Parameters<typeof updateSmartFolderRules.run>[0]);
  assert.deepEqual(store.get("smartFolderIndex/sf1")?.anchors, []);
});

test("canonical wall identity changes remove the old item and add its current identity", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall({id: "new"})),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
    ...smartItemSeed("sf1", "w1", "W1"),
  });
  await syncWallSmartFolders("W1");
  assert.deepEqual(itemIds(store, "sf1"), ["prism_new"]);
});

test("concurrent boundary adds share a folder write fence and retain 500 items", async (t) => {
  const seed: Record<string, Doc> = {
    ...seedWall("W1", gatedWall()), ...seedWall("W2", gatedWall({id: "w2"})),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
  };
  for (let i = 0; i < 500; i++) seed[`folders/sf1/items/old${i}`] = {addedAt: at(BASE + i)};
  const store = setup(t, seed);
  await Promise.all([addWallToSmartFolder("sf1", "W1", PREMIUM), addWallToSmartFolder("sf1", "W2", PREMIUM)]);
  assert.equal(itemIds(store, "sf1").length, 500);
  assert.equal(store.has("folders/sf1/items/old0"), false);
  assert.equal(store.has("folders/sf1/items/old1"), false);
  assert.ok(store.get("folders/sf1")?.updatedAt instanceof admin.firestore.Timestamp,
    "each add must write the folder that it read so concurrent adds conflict and retry");
});

test("all wall key kinds fit one array-contains-any and every matching anchor intersects", () => {
  assert.ok(MOODS.length + PALETTE.length + 4 <= 30, "all moods, colours, category, creator, desktop and choice must fit");
  const keys = wallSmartKeys(gatedWall({colors: PALETTE.map((colour) => colour.id),
    tags: ["duo"], spatial: {tier: "great"}, depth: {tier: "auto"}, desktopVariant: DESKTOP, editorsChoiceAt: at(NOW)}), PREMIUM);
  for (const rule of keys.map((key) => {
    const [kind, value = ""] = key.split(":");
    return {kind: kind as SmartRule["kind"], value};
  }).concat([{kind: "followed", value: ""}])) {
    const rules = [rule];
    assert.ok(matchesSmartRules(rules, keys, true));
    assert.ok(anchorFor(rules, ["c1"]).keys.some((key) => keys.includes(key)));
  }
});

for (const [reason, override] of Object.entries({
  premium: {collections: ["abstract"]}, drop: {dropReserved: true}, dropWeek: {dropWeek: "week"},
  streak: {is_streak_exclusive: true}, held: {originalProtected: false}, rejected: {review: false},
  badPreview: {wallpaper_thumb: "https://evil.example/a.jpg"},
})) {
  test(`${reason} walls leave smart folders and cannot be added`, async (t) => {
    const store = setup(t, {
      ...seedWall("W1", gatedWall(override)),
      ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
      ...smartItemSeed("sf1", "w1", "W1"),
    });
    await syncWallSmartFolders("W1");
    assert.deepEqual(itemIds(store, "sf1"), []);
    assert.equal(store.has("smartWallKeys/W1"), false);
    assert.equal(await addWallToSmartFolder("sf1", "W1", PREMIUM), false);
  });
}


test("a followed fill reports a truncated search even when the scanned creators have no matches", async (t) => {
  setup(t, seedWall("W1", gatedWall({creatorUid: "c300"})));
  const follows = Array.from({length: 301}, (_, i) => `c${i}`);
  assert.deepEqual(await findSmartMatches([{kind: "followed", value: ""}], follows, 100), {matches: [], more: true});
});

test("derived wall keys have no nontransactional writes that can overtake a newer event", async (t) => {
  const observed = {reads: 0, writes: 0, outsideWrites: 0};
  const store = setup(t, seedWall("W1", gatedWall(), false), observed);
  await syncWallSmartFolders("W1");
  assert.ok(store.has("smartWallKeys/W1"));
  assert.equal(observed.outsideWrites, 0);
});

test("account closure between validation and create prevents a late folder", async (t) => {
  const store = setup(t, {"usersv2/u1": {}});
  const transact = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", ((callback: Parameters<typeof db.runTransaction>[0]) => {
    store.set("creatorDeletionState/u1", {closed: true});
    return transact(callback);
  }) as typeof db.runTransaction);
  await assert.rejects(callCreate("u1", {name: "Blue", rules: [{kind: "colour", value: "blue"}]}),
    {code: "failed-precondition"});
  assert.deepEqual(keysUnder(store, "smartFolderIndex/"), []);
});

test("a failed fill transaction can be retried without losing matching items", async (t) => {
  const store = setup(t, {
    ...seedWall("W1", gatedWall()),
    ...smartFolderSeed("sf1", [{kind: "colour", value: "blue"}], "colour", ["colour:blue"]),
  });
  const transact = db.runTransaction.bind(db);
  let first = true;
  t.mock.method(db, "runTransaction", ((callback: Parameters<typeof db.runTransaction>[0]) => {
    if (first) {
      first = false;
      return Promise.reject(new Error("injected retryable failure"));
    }
    return transact(callback);
  }) as typeof db.runTransaction);
  await assert.rejects(fillSmartFolder("sf1"), /injected/);
  assert.deepEqual(itemIds(store, "sf1"), []);
  assert.equal(await fillSmartFolder("sf1"), 1);
  assert.deepEqual(itemIds(store, "sf1"), ["prism_w1"]);
});


test("creator and followed anchors include custom UIDs with hyphens and underscores", async (t) => {
  const uid = "creator-a_1";
  assert.deepEqual(parseSmartRules([{kind: "creator", value: uid}]), [{kind: "creator", value: uid}]);
  assert.deepEqual(anchorFor([{kind: "followed", value: ""}], [uid]), {kind: "followed", keys: [`creator:${uid}`]});
  assert.ok(wallSmartKeys(gatedWall({creatorUid: uid}), PREMIUM).includes(`creator:${uid}`));
  const store = setup(t, {
    ...seedWall("W1", gatedWall({creatorUid: uid})),
    ...smartFolderSeed("sf1", [{kind: "followed", value: ""}], "followed", [`creator:${uid}`]),
    [`profiles/u1/following/${uid}`]: {},
  });
  assert.deepEqual(await syncWallSmartFolders("W1"), {added: 1, checked: 1});
  assert.deepEqual(itemIds(store, "sf1"), ["prism_w1"]);
});
