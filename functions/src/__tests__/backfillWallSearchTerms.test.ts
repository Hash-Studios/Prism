import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {db} from "../common";
import {backfillWallSearchTerms, parseSearchTermsArgs} from "../scripts/backfillWallSearchTerms";
import {type Doc, installFakeDb} from "./fakeDb";

const url = (id: string) => `https://raw.githubusercontent.com/o/r/main/${id}.jpg`;

function installBulkWriter(t: TestContext) {
  const pending: Array<Promise<unknown>> = [];
  type Ref = {update: (data: Doc) => Promise<void>};
  t.mock.method(db, "bulkWriter", () => ({
    update: (ref: Ref, data: Doc) => {
      const write = ref.update(data);
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

const SEED: Record<string, Doc> = {
  "walls/a": {review: true, title: "Lone Lighthouse", wallpaper_url: url("a")},
  "walls/b": {review: false, title: "Hidden", wallpaper_url: url("b")},
  "walls/c": {review: true, title: "Protected", wallpaper_url: "", wallpaper_thumb: url("c-thumb")},
  "walls/d": {review: true, title: "Done", visionLabels: ["Sea"], searchTerms: ["done", "sea"], wallpaper_url: url("d")},
};

function setup(t: TestContext, labels: Record<string, string[]> = {}) {
  const store = installFakeDb(t, SEED);
  installBulkWriter(t);
  const detected: string[] = [];
  const detect = async (imageUrl: string) => {
    detected.push(imageUrl);
    const found = labels[imageUrl];
    if (!found) throw new Error("vision failed");
    return found;
  };
  return {store, detected, detect};
}

const run = (t: TestContext, args: string[], detect: (imageUrl: string) => Promise<string[]>) =>
  backfillWallSearchTerms(db, parseSearchTermsArgs(args), detect, () => undefined);

test("the search terms backfill is a dry run by default and writes nothing", async (t) => {
  const {store, detected, detect} = setup(t);
  const before = JSON.stringify([...store.entries()]);
  const counts = await run(t, [], detect);
  assert.deepEqual(counts, {scanned: 3, changed: 2, labelled: 0, failed: 0, written: 0});
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.deepEqual(detected, []);
});

test("a --labels dry run counts the walls that need labels and asks Vision for nothing", async (t) => {
  const {store, detected, detect} = setup(t, {[url("a")]: ["Lighthouse"], [url("c-thumb")]: ["Mountain"]});
  const before = JSON.stringify([...store.entries()]);
  const counts = await run(t, ["--labels"], detect);
  assert.deepEqual(counts, {scanned: 3, changed: 2, labelled: 2, failed: 0, written: 0});
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.deepEqual(detected, []);
});

test("--apply writes the terms of a wall that has only a title, with no Vision call", async (t) => {
  const {store, detected, detect} = setup(t);
  const counts = await run(t, ["--apply"], detect);
  assert.deepEqual(counts, {scanned: 3, changed: 2, labelled: 0, failed: 0, written: 2});
  assert.deepEqual(store.get("walls/a"), {...SEED["walls/a"], searchTerms: ["lone", "lighthouse"]});
  assert.deepEqual(store.get("walls/c"), {...SEED["walls/c"], searchTerms: ["protected"]});
  assert.deepEqual(store.get("walls/b"), SEED["walls/b"]);
  assert.deepEqual(store.get("walls/d"), SEED["walls/d"]);
  assert.deepEqual(detected, []);
});

test("--labels --apply fetches labels for walls without them and uses the thumbnail of a protected wall",
  async (t) => {
    const {store, detected, detect} = setup(t, {
      [url("a")]: ["Lighthouse", "Sea"],
      [url("c-thumb")]: ["Mountain"],
    });
    const counts = await run(t, ["--labels", "--apply"], detect);
    assert.deepEqual(counts, {scanned: 3, changed: 2, labelled: 2, failed: 0, written: 2});
    assert.deepEqual(detected.sort(), [url("a"), url("c-thumb")]);
    assert.deepEqual(store.get("walls/a"), {
      ...SEED["walls/a"],
      visionLabels: ["Lighthouse", "Sea"],
      searchTerms: ["lone", "lighthouse", "sea"],
    });
    assert.deepEqual(store.get("walls/c"), {
      ...SEED["walls/c"],
      visionLabels: ["Mountain"],
      searchTerms: ["protected", "mountain"],
    });
    assert.deepEqual(store.get("walls/d"), SEED["walls/d"]);
  });

test("a second run writes nothing and asks Vision for nothing", async (t) => {
  const {store, detected, detect} = setup(t, {[url("a")]: ["Lighthouse"], [url("c-thumb")]: []});
  await run(t, ["--labels", "--apply"], detect);
  const after = JSON.stringify([...store.entries()]);
  detected.length = 0;
  const counts = await run(t, ["--labels", "--apply"], detect);
  assert.deepEqual(counts, {scanned: 3, changed: 0, labelled: 0, failed: 0, written: 0});
  assert.equal(JSON.stringify([...store.entries()]), after);
  assert.deepEqual(detected, []);
  assert.deepEqual(store.get("walls/c")?.visionLabels, []);
});

test("a Vision failure still writes the terms, writes no labels, and the next run asks again", async (t) => {
  const {store, detected, detect} = setup(t, {[url("c-thumb")]: ["Mountain"]});
  const counts = await run(t, ["--labels", "--apply"], detect);
  assert.deepEqual(counts, {scanned: 3, changed: 2, labelled: 1, failed: 1, written: 2});
  assert.deepEqual(store.get("walls/a"), {...SEED["walls/a"], searchTerms: ["lone", "lighthouse"]});
  detected.length = 0;
  await run(t, ["--labels", "--apply"], detect);
  assert.deepEqual(detected, [url("a")]);
});

test("a wall with no image address counts as a label failure and is not sent to Vision", async (t) => {
  const store = installFakeDb(t, {"walls/e": {review: true, title: "No image"}});
  installBulkWriter(t);
  const detect = t.mock.fn(async (): Promise<string[]> => ["Sea"]);
  const counts = await run(t, ["--labels", "--apply"], detect);
  assert.deepEqual(counts, {scanned: 1, changed: 1, labelled: 0, failed: 1, written: 1});
  assert.equal(detect.mock.callCount(), 0);
  assert.deepEqual(store.get("walls/e")?.searchTerms, ["no", "image"]);
});

test("search terms backfill arguments fall back to safe values", () => {
  assert.deepEqual(parseSearchTermsArgs([]), {apply: false, labels: false, batchSize: 100, startAfter: undefined});
  assert.deepEqual(parseSearchTermsArgs(["--apply", "--labels", "--batch=250", "--start-after=abc"]),
    {apply: true, labels: true, batchSize: 250, startAfter: "abc"});
  assert.equal(parseSearchTermsArgs(["--batch=9999"]).batchSize, 100);
  assert.equal(parseSearchTermsArgs(["--batch=0"]).batchSize, 100);
  assert.equal(parseSearchTermsArgs(["--start-after="]).startAfter, undefined);
});
