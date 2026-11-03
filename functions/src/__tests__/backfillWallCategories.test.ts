import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  backfillWallCategories,
  parseWallCategoryArgs,
  planCategoryChange,
} from "../scripts/backfillWallCategories";
import {type Doc, installFakeDb} from "./fakeDb";

type Ref = {id: string; update: (data: Doc, precondition?: unknown) => Promise<void>};
type Write = {ref: Ref; data: Doc; precondition: unknown};

/** A fake bulkWriter that records each update and applies it to the fake store with its precondition. */
function installBulkWriter(t: TestContext): Write[] {
  const writes: Write[] = [];
  const pending: Array<Promise<unknown>> = [];
  t.mock.method(db, "bulkWriter", () => ({
    update: (ref: Ref, data: Doc, precondition?: unknown) => {
      writes.push({ref, data, precondition});
      const write = ref.update(data, precondition);
      pending.push(write);
      return write;
    },
    flush: async () => {
      await Promise.allSettled(pending);
    },
    close: async () => {
      await Promise.allSettled(pending);
    },
  }));
  return writes;
}

const SEED: Record<string, Doc> = {
  "walls/a": {review: true, category: "Anime", aiCategorized: true, visionLabels: ["Fictional character", "PC game"]},
  "walls/b": {review: true, category: "General", visionLabels: ["Pastel"]},
  "walls/c": {review: true, category: "Nature", aiCategorized: true, visionLabels: ["Mountain"]},
  "walls/d": {review: true, category: "Architecture", visionLabels: ["Pastel"]},
};

test("planCategoryChange moves only classifier-owned walls into the new categories", () => {
  assert.deepEqual(planCategoryChange({aiCategorized: true, category: "Anime",
    visionLabels: ["Fictional character", "PC game"]}), {from: "Anime", to: "Gaming"});
  assert.deepEqual(planCategoryChange({category: "General", visionLabels: ["Pastel"]}),
    {from: "General", to: "Pastel"});
  assert.deepEqual(planCategoryChange({visionLabels: ["Pastel"]}), {from: "General", to: "Pastel"});
  assert.equal(planCategoryChange({category: "Architecture", visionLabels: ["Pastel"]}), "creatorPicked");
  assert.equal(planCategoryChange({aiCategorized: true, category: "Anime"}), "noLabels");
  assert.equal(planCategoryChange({aiCategorized: true, category: "Nature", visionLabels: ["Mountain"]}), null);
  assert.equal(planCategoryChange({aiCategorized: true, category: "Gaming", visionLabels: ["PC game"]}), null);
});

test("the category backfill is a dry run by default and writes nothing", async (t) => {
  const store = installFakeDb(t, SEED);
  const writes = installBulkWriter(t);
  const before = JSON.stringify([...store.entries()]);
  const logs: string[] = [];
  const counts = await backfillWallCategories(db, parseWallCategoryArgs([]), (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 4, noLabels: 0, creatorPicked: 1, changed: 2, written: 0, failed: 0,
    moves: {"Anime -> Gaming": 1, "General -> Pastel": 1}, samples: ["a", "b"]});
  assert.equal(writes.length, 0);
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.deepEqual(logs, [
    "a Anime -> Gaming",
    "b General -> Pastel",
    "move Anime -> Gaming: 1",
    "move General -> Pastel: 1",
    "samples: a b",
    "done scanned=4 noLabels=0 creatorPicked=1 changed=2 written=0 failed=0 applied=false",
  ]);
});

test("the category backfill with --apply writes the new category with a precondition", async (t) => {
  const store = installFakeDb(t, SEED);
  const writes = installBulkWriter(t);
  const updateTime = (await db.collection("walls").doc("a").get()).updateTime;
  const counts = await backfillWallCategories(db, parseWallCategoryArgs(["--apply"]), () => undefined);

  assert.equal(counts.written, 2);
  const anime = writes.find((w) => w.ref.id === "a");
  assert.ok(anime);
  assert.deepEqual(anime.data, {
    category: "Gaming",
    aiCategorized: true,
    categorizedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  assert.deepEqual(anime.precondition, {lastUpdateTime: updateTime});
  assert.equal(store.get("walls/a")?.category, "Gaming");
  assert.deepEqual(store.get("walls/c"), SEED["walls/c"]);
});

test("parseWallCategoryArgs reads --apply", () => {
  assert.equal(parseWallCategoryArgs(["--apply"]).apply, true);
  assert.equal(parseWallCategoryArgs([]).apply, false);
});
