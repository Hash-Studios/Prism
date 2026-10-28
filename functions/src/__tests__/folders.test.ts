import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {isFolderItemPath, onFolderItemWritten, onFolderWritten, repairFolder} from "../folders";
import {installFakeDb} from "./fakeDb";

const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const folderSnapshot = (data: Record<string, unknown> | undefined) => ({
  exists: data !== undefined,
  data: () => data,
});

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

test("repair clears a stale count and covers when the folder has no items", async (t) => {
  const store = installFakeDb(t, {
    "folders/f1": {ownerId: "u1", itemCount: 3, covers: ["gone"]},
  });
  await repairFolder("f1");
  assert.equal(store.get("folders/f1")?.itemCount, 0);
  assert.deepEqual(store.get("folders/f1")?.covers, []);
});

test("repair counts a legacy item with no thumb and omits it from covers", async (t) => {
  const store = installFakeDb(t, {
    "folders/f1": {ownerId: "u1", itemCount: 0, covers: ["stale"]},
    "folders/f1/items/prism_legacy": {ownerId: "u1", addedAt: at(2)},
    "folders/f1/items/prism_current": {ownerId: "u1", thumb: "A", addedAt: at(1)},
  });
  await repairFolder("f1");
  assert.equal(store.get("folders/f1")?.itemCount, 2);
  assert.deepEqual(store.get("folders/f1")?.covers, ["A"]);
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

test("a stale count decrement repairs the folder even when its item delete was a no-op", async (t) => {
  const store = installFakeDb(t, {
    "folders/f1": {ownerId: "u1", itemCount: 0, covers: []},
    "folders/f1/items/prism_b": {ownerId: "u1", thumb: "B", addedAt: at(1)},
  });
  const transactions = t.mock.method(db, "runTransaction", db.runTransaction);
  await onFolderWritten.run({params: {folderId: "f1"}, data: {
    before: folderSnapshot({ownerId: "u1", itemCount: 1, covers: ["A"]}),
    after: folderSnapshot({ownerId: "u1", itemCount: 0, covers: []}),
  }} as unknown as Parameters<typeof onFolderWritten.run>[0]);
  assert.equal(store.get("folders/f1")?.itemCount, 1);
  assert.deepEqual(store.get("folders/f1")?.covers, ["B"]);

  await onFolderWritten.run({params: {folderId: "f1"}, data: {
    before: folderSnapshot({ownerId: "u1", itemCount: 0, covers: []}),
    after: folderSnapshot(store.get("folders/f1")),
  }} as unknown as Parameters<typeof onFolderWritten.run>[0]);
  assert.equal(transactions.mock.callCount(), 1);
});

test("folder writes that cannot be stale decrements are ignored", async (t) => {
  const store = installFakeDb(t, {"folders/f1": {ownerId: "u1", itemCount: 1, covers: ["B"]}});
  const transactions = t.mock.method(db, "runTransaction", db.runTransaction);
  const events = [
    {before: folderSnapshot({ownerId: "u1", itemCount: 1}), after: folderSnapshot({ownerId: "u1", itemCount: 2})},
    {before: folderSnapshot({ownerId: "u1", itemCount: 1, name: "Before"}),
      after: folderSnapshot({ownerId: "u1", itemCount: 1, name: "After"})},
    {before: folderSnapshot({ownerId: "u1", itemCount: 1}), after: folderSnapshot(undefined)},
    {before: folderSnapshot(undefined), after: folderSnapshot({ownerId: "u1", itemCount: 1})},
  ];
  for (const data of events) {
    await onFolderWritten.run({params: {folderId: "f1"}, data} as unknown as Parameters<typeof onFolderWritten.run>[0]);
  }
  assert.equal(transactions.mock.callCount(), 0);
  assert.deepEqual(store.get("folders/f1"), {ownerId: "u1", itemCount: 1, covers: ["B"]});
});

test("reprocessing a corrective folder decrement is idempotent", async (t) => {
  const store = installFakeDb(t, {
    "folders/f1": {ownerId: "u1", itemCount: 1, covers: ["B"]},
    "folders/f1/items/prism_b": {ownerId: "u1", thumb: "B", addedAt: at(1)},
  });
  const staleDecrement = {params: {folderId: "f1"}, data: {
    before: folderSnapshot({ownerId: "u1", itemCount: 2, covers: ["A", "B"]}),
    after: folderSnapshot({ownerId: "u1", itemCount: 1, covers: ["B"]}),
  }};
  await onFolderWritten.run(staleDecrement as unknown as Parameters<typeof onFolderWritten.run>[0]);
  const repaired = store.get("folders/f1");
  assert.equal(repaired?.itemCount, 1);
  assert.deepEqual(repaired?.covers, ["B"]);

  await onFolderWritten.run(staleDecrement as unknown as Parameters<typeof onFolderWritten.run>[0]);
  assert.equal(store.get("folders/f1"), repaired);
});

test("only folders/{id}/items/{key} paths are folder items", () => {
  assert.equal(isFolderItemPath("folders/f1/items/prism_a"), true);
  assert.equal(isFolderItemPath("other/p/items/prism_a"), false);
  assert.equal(isFolderItemPath("items/d1"), false);
  assert.equal(isFolderItemPath("a/folders/f1/items/prism_a"), false);
});
