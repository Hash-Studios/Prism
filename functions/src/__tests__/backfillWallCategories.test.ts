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
function installBulkWriter(t: TestContext, options: {failWrites?: boolean; staleWrites?: boolean} = {}):
  {writes: Write[]; creations: {count: number}} {
  const writes: Write[] = [];
  const creations = {count: 0};
  const pending: Array<Promise<unknown>> = [];
  t.mock.method(db, "bulkWriter", () => {
    creations.count += 1;
    return {
      update: (ref: Ref, data: Doc, precondition?: unknown) => {
        writes.push({ref, data, precondition});
        const write = options.failWrites ? Promise.reject(new Error("write rejected")) : options.staleWrites ?
          ref.update({concurrentChange: true}).then(() => ref.update(data, precondition)) : ref.update(data, precondition);
        pending.push(write);
        return write;
      },
      flush: async () => {
        await Promise.allSettled(pending);
      },
      close: async () => {
        await Promise.allSettled(pending);
      },
    };
  });
  return {writes, creations};
}

const SEED: Record<string, Doc> = {
  "walls/a": {review: true, category: "Anime", aiCategorized: true, visionLabels: ["Fictional character", "PC game"]},
  "walls/b": {review: true, category: "General", visionLabels: ["Pastel"]},
  "walls/c": {review: true, category: "Nature", aiCategorized: true, visionLabels: ["Mountain"]},
  "walls/d": {review: true, category: "Architecture", visionLabels: ["Pastel"]},
};

test("planCategoryChange moves any classifier-owned wall the current rules place elsewhere", () => {
  assert.deepEqual(planCategoryChange({aiCategorized: true, category: "Anime",
    visionLabels: ["Astronaut", "Astronomical object", "Outer space", "Illustration"]}), {from: "Anime", to: "Space"});
  assert.deepEqual(planCategoryChange({aiCategorized: true, category: "Nature", visionLabels: ["Flower", "Petal"]}),
    {from: "Nature", to: "Flowers"});
});

test("planCategoryChange never moves a wall out of Gaming or Pastel", () => {
  assert.equal(planCategoryChange({aiCategorized: true, category: "Gaming", visionLabels: ["Anime", "PC game"]}), null);
  assert.equal(planCategoryChange({aiCategorized: true, category: "Pastel", visionLabels: ["Mountain"]}), null);
});

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
  const {writes, creations} = installBulkWriter(t);
  const before = JSON.stringify([...store.entries()]);
  const logs: string[] = [];
  const counts = await backfillWallCategories(db, parseWallCategoryArgs([]), (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 4, studio: 0, noLabels: 0, creatorPicked: 1, changed: 2, unclassified: 1, written: 0, failed: 0,
    moves: {"Anime -> Gaming": 1, "General -> Pastel": 1}, samples: ["a", "b"]});
  assert.equal(writes.length, 0);
  assert.equal(creations.count, 0, "dry run must not create a bulk writer");
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.deepEqual(logs, [
    "a Anime -> Gaming",
    "b General -> Pastel",
    "move Anime -> Gaming: 1",
    "move General -> Pastel: 1",
    "samples: a b",
    "done scanned=4 studio=0 noLabels=0 creatorPicked=1 changed=2 unclassified=1 written=0 failed=0 applied=false",
  ]);
});

test("the category backfill with --apply writes the new category with a precondition", async (t) => {
  const store = installFakeDb(t, SEED);
  const {writes} = installBulkWriter(t);
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

test("the category backfill rerun is idempotent after the first apply", async (t) => {
  installFakeDb(t, SEED);
  const {writes} = installBulkWriter(t);

  const first = await backfillWallCategories(db, parseWallCategoryArgs(["--apply"]), () => undefined);
  const second = await backfillWallCategories(db, parseWallCategoryArgs(["--apply"]), () => undefined);

  assert.equal(first.written, 2);
  assert.equal(second.changed, 0);
  assert.equal(writes.length, 2);
});

test("the category backfill paginates all approved walls without creating a writer in dry-run mode", async (t) => {
  const seed = Object.fromEntries(Array.from({length: 301}, (_, i) => [`walls/${String(i).padStart(3, "0")}`,
    {review: true, category: "General", visionLabels: ["PC game"]}]));
  installFakeDb(t, seed);
  const {writes, creations} = installBulkWriter(t);
  const counts = await backfillWallCategories(db, parseWallCategoryArgs([]), () => undefined);

  assert.equal(counts.scanned, 301);
  assert.equal(counts.changed, 301);
  assert.equal(counts.samples.length, 10);
  assert.equal(writes.length, 0);
  assert.equal(creations.count, 0);
});

test("the category backfill rejects after logging failed apply writes", async (t) => {
  installFakeDb(t, SEED);
  const {writes} = installBulkWriter(t, {failWrites: true});
  const logs: string[] = [];

  await assert.rejects(backfillWallCategories(db, parseWallCategoryArgs(["--apply"]), (line) => logs.push(line)),
    /2 category writes failed/);
  assert.equal(writes.length, 2);
  assert.ok(logs.includes("done scanned=4 studio=0 noLabels=0 creatorPicked=1 changed=2 unclassified=1 written=0 failed=2 applied=true"));
});

test("the category backfill does not overwrite walls changed since the scan", async (t) => {
  const store = installFakeDb(t, SEED);
  installBulkWriter(t, {staleWrites: true});

  await assert.rejects(backfillWallCategories(db, parseWallCategoryArgs(["--apply"]), () => undefined),
    /2 category writes failed/);
  assert.equal(store.get("walls/a")?.category, "Anime");
  assert.equal(store.get("walls/b")?.category, "General");
  assert.equal(store.get("walls/a")?.concurrentChange, true);
  assert.equal(store.get("walls/b")?.concurrentChange, true);
});

test("--classified-only leaves General walls the classifier never set", async (t) => {
  installFakeDb(t, SEED);
  const {writes} = installBulkWriter(t);
  const counts = await backfillWallCategories(db, parseWallCategoryArgs(["--apply", "--classified-only"]), () => undefined);

  assert.equal(counts.changed, 1);
  assert.equal(counts.unclassified, 1);
  assert.deepEqual(writes.map((w) => w.ref.id), ["a"]);
});

test("planCategoryChange skips Studio walls, picked categories and walls with no labels", () => {
  assert.equal(planCategoryChange({origin: "studio", category: "General", visionLabels: ["Sports car", "Sky"]}), "studio");
  assert.equal(planCategoryChange({origin: "studio", aiCategorized: true, category: "Nature",
    visionLabels: ["Sports car", "Sky"]}), "studio");
  assert.equal(planCategoryChange({category: "Nature", visionLabels: ["Sports car", "Sky"]}), "creatorPicked");
  assert.equal(planCategoryChange({aiCategorized: true, category: "Nature", visionLabels: []}), "noLabels");
  assert.equal(planCategoryChange({aiCategorized: true, category: "Nature", visionLabels: [3]}), "noLabels");
  assert.deepEqual(planCategoryChange({aiCategorized: true, category: "Nature", visionLabels: ["Sports car", "Sky"]}),
    {from: "Nature", to: "Cars"});
});

test("a dry run over every skip case writes nothing and counts each skip", async (t) => {
  const seed: Record<string, Doc> = {
    "walls/car": {review: true, category: "Nature", aiCategorized: true, visionLabels: ["Sports car", "Sky"]},
    "walls/picked": {review: true, category: "Nature", visionLabels: ["Sports car", "Sky"]},
    "walls/studio": {review: true, category: "General", origin: "studio", visionLabels: ["Sports car", "Sky"]},
    "walls/unlabelled": {review: true, category: "Nature", aiCategorized: true},
    "walls/pending": {review: false, category: "Nature", aiCategorized: true, visionLabels: ["Sports car"]},
  };
  const store = installFakeDb(t, seed);
  const {writes, creations} = installBulkWriter(t);
  const before = JSON.stringify([...store.entries()]);
  const counts = await backfillWallCategories(db, parseWallCategoryArgs([]), () => undefined);

  assert.deepEqual(counts, {scanned: 4, studio: 1, noLabels: 1, creatorPicked: 1, changed: 1, unclassified: 0,
    written: 0, failed: 0, moves: {"Nature -> Cars": 1}, samples: ["car"]});
  assert.equal(writes.length, 0);
  assert.equal(creations.count, 0);
  assert.equal(JSON.stringify([...store.entries()]), before);
});

test("the summary lists the 20 most common moves, most common first", async (t) => {
  const seed: Record<string, Doc> = {};
  const labels = ["Sports car", "Video game", "Tower", "Coral", "Petal", "Galaxy", "Neon", "Darkness", "Geometric",
    "CGI", "Plain", "Gradient", "Generated", "Robot", "Retro", "Desert", "Milky Way", "Pastel", "Anime", "Mountain",
    "Anime"];
  labels.forEach((label, i) => {
    for (let n = 0; n <= i; n += 1) {
      seed[`walls/${String(i).padStart(2, "0")}-${n}`] = i === 20 ?
        {review: true, category: "Nature", aiCategorized: true, visionLabels: [label]} :
        {review: true, category: "General", visionLabels: [label]};
    }
  });
  installFakeDb(t, seed);
  installBulkWriter(t);
  const logs: string[] = [];
  await backfillWallCategories(db, parseWallCategoryArgs([]), (line) => logs.push(line));

  const moves = logs.filter((line) => line.startsWith("move "));
  assert.equal(moves.length, 20);
  assert.equal(moves[0], "move Nature -> Anime: 21");
  assert.equal(moves[19], "move General -> Gaming: 2");
});

test("parseWallCategoryArgs reads --apply", () => {
  assert.equal(parseWallCategoryArgs(["--apply"]).apply, true);
  assert.equal(parseWallCategoryArgs([]).apply, false);
});
