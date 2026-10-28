import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {isFolderItemPath, onFolderItemWritten, repairFolder} from "../folders";
import {installFakeDb} from "./fakeDb";

const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

test("repair sets the count and the newest covers from the owner's items", async (t) => {
  const store = installFakeDb(t, {
    // Drifted: two devices both counted one save, and the covers still show a removed wall.
    "folders/f1": {ownerId: "u1", name: "Night", itemCount: 5, covers: ["removed"]},
    "folders/f1/items/prism_a": {ownerId: "u1", thumb: "A", addedAt: at(1)},
    "folders/f1/items/prism_b": {ownerId: "u1", thumb: "B", addedAt: at(3)},
    "folders/f1/items/prism_c": {ownerId: "u1", thumb: "C", addedAt: at(2)},
    "folders/f1/items/prism_d": {ownerId: "u1", thumb: "D", addedAt: at(4)},
    "folders/f1/items/prism_e": {ownerId: "u1", thumb: "E", addedAt: at(5)},
    // A former owner's item in a reused folder id is not part of this folder.
    "folders/f1/items/prism_x": {ownerId: "u2", thumb: "X", addedAt: at(9)},
  });
  await repairFolder("f1");
  assert.deepEqual(store.get("folders/f1"), {ownerId: "u1", name: "Night", itemCount: 5, covers: ["E", "D", "B", "C"]});

  store.delete("folders/f1/items/prism_e");
  await repairFolder("f1");
  assert.equal(store.get("folders/f1")?.itemCount, 4);
  assert.deepEqual(store.get("folders/f1")?.covers, ["D", "B", "C", "A"]);
});

test("repair does not bring back a deleted folder", async (t) => {
  const store = installFakeDb(t, {"folders/gone/items/prism_a": {ownerId: "u1", thumb: "A", addedAt: at(1)}});
  await repairFolder("gone");
  assert.equal(store.has("folders/gone"), false);
});

test("repair does not write a folder that is already right", async (t) => {
  const store = installFakeDb(t, {
    "folders/f1": {ownerId: "u1", itemCount: 1, covers: ["A"]},
    "folders/f1/items/prism_a": {ownerId: "u1", thumb: "A", addedAt: at(1)},
  });
  const before = store.get("folders/f1");
  await repairFolder("f1");
  assert.equal(store.get("folders/f1"), before);
});

test("an item write repairs its folder", async (t) => {
  const store = installFakeDb(t, {
    "folders/f1": {ownerId: "u1", itemCount: 0, covers: []},
    "folders/f1/items/prism_a": {ownerId: "u1", thumb: "A", addedAt: at(1)},
  });
  await onFolderItemWritten.run({params: {folderId: "f1", itemKey: "prism_a"}} as unknown as
    Parameters<typeof onFolderItemWritten.run>[0]);
  assert.equal(store.get("folders/f1")?.itemCount, 1);
  assert.deepEqual(store.get("folders/f1")?.covers, ["A"]);
});

test("only folders/{id}/items/{key} paths are folder items", () => {
  assert.equal(isFolderItemPath("folders/f1/items/prism_a"), true);
  assert.equal(isFolderItemPath("other/p/items/prism_a"), false);
  assert.equal(isFolderItemPath("items/d1"), false);
  assert.equal(isFolderItemPath("a/folders/f1/items/prism_a"), false);
});
