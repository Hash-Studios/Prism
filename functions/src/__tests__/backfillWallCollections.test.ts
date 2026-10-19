import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {
  backfillWallCollections,
  type CollectionBackfillDeps,
  keptCategory,
  parseCollectionBackfillArgs,
} from "../scripts/backfillWallCollections";
import {type Doc, installFakeDb} from "./fakeDb";

const url = (id: string) => `https://raw.githubusercontent.com/o/r/main/${id}.jpg`;
const community = (id: string, extra: Doc = {}): Doc =>
  ({review: true, collections: ["community"], wallpaper_url: url(id), ...extra});

/** A fake bulkWriter that applies each update to the fake store with its precondition. */
function installBulkWriter(t: TestContext) {
  const pending: Array<Promise<unknown>> = [];
  type Ref = {update: (data: Doc, precondition?: unknown) => Promise<void>};
  t.mock.method(db, "bulkWriter", () => ({
    update: (ref: Ref, data: Doc, precondition?: unknown) => {
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
}

function fakeDeps(labels: Record<string, string[]>, premium: string[] = ["space"]) {
  const detected: string[] = [];
  let refreshed = 0;
  const deps: CollectionBackfillDeps = {
    detect: async (imageUrl) => {
      detected.push(imageUrl);
      const found = labels[imageUrl];
      if (!found) throw new Error("vision failed");
      return found;
    },
    premium: async () => premium,
    refreshCovers: async () => {
      refreshed += 1;
      return ["landscapes"];
    },
  };
  return {deps, detected, refreshed: () => refreshed};
}

const SEED: Record<string, Doc> = {
  "walls/a": community("a", {category: "General"}),
  "walls/b": community("b", {category: "Dark"}),
  "walls/c": {...community("c", {category: "General"}), collections: ["community", "stock"]},
  "walls/d": {...community("d", {category: "General"}), review: false},
  "walls/e": community("e", {category: "General", aiCategorized: true}),
  "walls/f": community("f"),
  "walls/g": {review: true, collections: ["community "], category: "General"},
};
const LABELS = {[url("a")]: ["Mountain"], [url("f")]: ["Space"]};

test("the collection backfill is a dry run by default and reports what it would file", async (t) => {
  const store = installFakeDb(t, SEED);
  const before = JSON.stringify([...store.entries()]);
  const {deps, detected, refreshed} = fakeDeps(LABELS);
  const logs: string[] = [];
  const counts = await backfillWallCollections(db, parseCollectionBackfillArgs([]), deps, (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 6, communityOnly: 5, detected: 2, kept: 2, failed: 1, premiumSkipped: 1,
    filed: 2, written: 0, categories: {Nature: 1, Dark: 1, General: 1, Space: 1},
    collections: {landscapes: 1, amoled: 1}});
  assert.deepEqual(detected.sort(), [url("a"), url("f")]);
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.equal(refreshed(), 0);
  assert.deepEqual(logs.filter((l) => /^[a-g] /.test(l)).sort(),
    ["a Nature landscapes", "b Dark amoled", "e General -", "f Space -", "g failed"]);
  assert.match(logs[logs.length - 1], /^done scanned=6 communityOnly=5 .*applied=false$/);
});

test("the collection backfill with --apply files walls, keeps creator categories and skips premium targets",
  async (t) => {
    const store = installFakeDb(t, SEED);
    installBulkWriter(t);
    const {deps, detected, refreshed} = fakeDeps(LABELS);
    const logs: string[] = [];
    const counts = await backfillWallCollections(db, parseCollectionBackfillArgs(["--apply"]), deps,
      (line) => logs.push(line));

    assert.equal(counts.written, 3);
    assert.deepEqual(detected.sort(), [url("a"), url("f")]);

    const a = store.get("walls/a");
    assert.deepEqual(a?.collections, ["community", "landscapes"]);
    assert.equal(a?.category, "Nature");
    assert.equal(a?.aiCategorized, true);
    assert.ok(a?.categorizedAt instanceof admin.firestore.Timestamp);

    assert.deepEqual(store.get("walls/b"), {...SEED["walls/b"], collections: ["community", "amoled"]});

    const f = store.get("walls/f");
    assert.equal(f?.category, "Space");
    assert.equal(f?.aiCategorized, true);
    assert.deepEqual(f?.collections, ["community"]);

    for (const id of ["c", "d", "e", "g"]) {
      assert.deepEqual(store.get(`walls/${id}`), SEED[`walls/${id}`], id);
    }
    assert.equal(refreshed(), 1);
    assert.ok(logs.includes("covers refreshed: landscapes"));
    assert.match(logs[logs.length - 1], /written=3 .*applied=true$/);
  });

test("the collection backfill stops after --limit Vision calls", async (t) => {
  const ids = ["v1", "v2", "v3", "v4", "v5"];
  const store = installFakeDb(t, Object.fromEntries(ids.map((id) => [`walls/${id}`, community(id)])));
  installBulkWriter(t);
  const {deps, detected} = fakeDeps(Object.fromEntries(ids.map((id) => [url(id), ["Mountain"]])));
  const counts = await backfillWallCollections(db, parseCollectionBackfillArgs(["--apply", "--limit=2"]), deps,
    () => undefined);

  assert.equal(detected.length, 2);
  assert.equal(counts.detected, 2);
  assert.equal(counts.written, 2);
  assert.deepEqual(ids.filter((id) => store.get(`walls/${id}`)?.category === "Nature"), ["v1", "v2"]);
});

test("keptCategory keeps creator and Vision categories and asks Vision for the rest", () => {
  assert.equal(keptCategory({category: "Dark"}), "Dark");
  assert.equal(keptCategory({category: "General", aiCategorized: true}), "General");
  assert.equal(keptCategory({category: "Nature", aiCategorized: true}), "Nature");
  assert.equal(keptCategory({aiCategorized: true}), "General");
  assert.equal(keptCategory({category: "General"}), null);
  assert.equal(keptCategory({category: " "}), null);
  assert.equal(keptCategory({}), null);
});

test("parseCollectionBackfillArgs reads --apply and a positive --limit", () => {
  assert.deepEqual(parseCollectionBackfillArgs([]), {apply: false, limit: undefined});
  assert.deepEqual(parseCollectionBackfillArgs(["--apply", "--limit=25"]), {apply: true, limit: 25});
  assert.deepEqual(parseCollectionBackfillArgs(["--limit=0"]), {apply: false, limit: undefined});
  assert.deepEqual(parseCollectionBackfillArgs(["--limit=abc"]), {apply: false, limit: undefined});
});
