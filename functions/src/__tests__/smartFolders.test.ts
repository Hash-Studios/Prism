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
  parseSmartRules,
  removeOwnerSmartFolders,
  removeSmartFolder,
  syncWallSmartFolders,
  wallSmartKeys,
  type SmartRule,
} from "../smartFolders";
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

function setup(t: TestContext, seed: Record<string, Doc> = {}) {
  t.mock.method(publicFolderDeps, "premium", async () => PREMIUM);
  t.mock.method(db, "batch", (() => fakeBatch()) as unknown as typeof db.batch);
  t.mock.method(db, "getAll", ((...refs: Array<{get: () => Promise<unknown>}>) =>
    Promise.all(refs.map((ref) => ref.get()))) as unknown as typeof db.getAll);
  return installFakeDb(t, seed);
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
  });
  await removeOwnerSmartFolders("u1");
  assert.equal(store.has("smartFolderIndex/sf1"), false, "the owner's index entry must be deleted");
  assert.equal(store.has("smartFolderIndex/sf2"), true, "another owner's index entry must be kept");
});

test("changesSmartKeys ignores counter-only writes and reacts to key fields and creates or deletes", () => {
  assert.equal(changesSmartKeys({views: 1, review: true}, {views: 2, review: true}), false,
    "a counter-only change must not change smart keys");
  assert.equal(changesSmartKeys({colors: ["blue"]}, {colors: ["teal"]}), true,
    "a colour change must change smart keys");
  assert.equal(changesSmartKeys(undefined, {review: true}), true, "a created wall must change smart keys");
  assert.equal(changesSmartKeys({review: true}, undefined), true, "a deleted wall must change smart keys");
});
