process.env.R2_PREVIEW_BASE_URL = "https://img.prismwalls.com";

import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {backfillSmartWallKeys, parseArgs} from "../scripts/backfillSmartWallKeys";
import {publicFolderDeps} from "../publicFolders";
import {wallSmartKeys} from "../smartFolders";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const THUMB = "https://img.prismwalls.com/previews/aaa.img";
const at = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const gated = {id: "w3", review: true, originalProtected: true, collections: ["nature"], wallpaper_thumb: THUMB,
  colors: ["blue"], createdAt: at(3000)};
const seedWalls: Record<string, Doc> = {
  "walls/w1": {id: "w1", review: true, originalProtected: true, collections: ["nature"], wallpaper_thumb: THUMB,
    colors: ["blue"], createdAt: at(1000)},
  "walls/w2": {id: "w2", review: false, originalProtected: true, collections: ["nature"], wallpaper_thumb: THUMB,
    colors: ["blue"], createdAt: at(2000)},
  "walls/w3": gated,
};

function setup(t: TestContext) {
  t.mock.method(publicFolderDeps, "premium", async () => ["abstract"]);
  return installFakeDb(t, {
    ...seedWalls,
    "smartWallKeys/w2": {keys: ["colour:blue"], wallId: "w2", thumb: THUMB, createdAt: at(2000)},
    // Correct for w3: built with the same gate and premium list the backfill uses.
    "smartWallKeys/w3": {keys: wallSmartKeys(gated, ["abstract"]), wallId: "w3", thumb: THUMB, createdAt: at(3000)},
    "folders/f1": {ownerId: "a", name: "Night", public: true, itemCount: 0, covers: []},
  });
}

test("dry run counts and writes nothing", async (t) => {
  const store = setup(t);
  const before = new Map(store);

  const counts = await backfillSmartWallKeys({apply: false}, () => undefined);

  assert.deepEqual(counts, {scanned: 3, write: 1, unchanged: 1, delete: 1, skipped: 0});
  assert.deepEqual(new Map(store), before);
});

test("apply writes the w1 doc, deletes the stale w2 doc, and leaves folders alone", async (t) => {
  const store = setup(t);
  const folderBefore = store.get("folders/f1");

  const counts = await backfillSmartWallKeys({apply: true}, () => undefined);

  assert.deepEqual(counts, {scanned: 3, write: 1, unchanged: 1, delete: 1, skipped: 0});
  const w1 = store.get("smartWallKeys/w1");
  assert.deepEqual(w1?.keys, wallSmartKeys(seedWalls["walls/w1"], ["abstract"]));
  assert.ok((w1?.keys as string[]).length > 0);
  assert.equal(w1?.wallId, "w1");
  assert.equal(w1?.thumb, THUMB);
  assert.equal((w1?.createdAt as admin.firestore.Timestamp).toMillis(), 1000);
  assert.equal(store.has("smartWallKeys/w2"), false);
  assert.equal(store.has("smartWallKeys/w3"), true);
  assert.equal(store.get("folders/f1"), folderBefore);
});

test("argument parsing rejects unknown and duplicate flags", () => {
  assert.deepEqual(parseArgs([]), {help: false, apply: false, concurrency: 1});
  assert.deepEqual(parseArgs(["--apply"]), {help: false, apply: true, concurrency: 1});
  assert.deepEqual(parseArgs(["--help"]), {help: true, apply: false, concurrency: 1});
  assert.deepEqual(parseArgs(["--concurrency=4"]), {help: false, apply: false, concurrency: 4});
  assert.throws(() => parseArgs(["--apply", "--apply"]));
  assert.throws(() => parseArgs(["--dry-run"]));
  assert.throws(() => parseArgs(["--help", "--apply"]));
});
