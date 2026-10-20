import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import test, {type TestContext} from "node:test";
import {db} from "../common";
import {onWallSearchTerms, searchTermsOf, wallSearchTermsFor} from "../wallSearchTerms";
import {type Doc, installFakeDb} from "./fakeDb";

type Fixture = {
  text: Array<{text: string; terms: string[]}>;
  wall: Array<{wall: Doc; terms: string[]}>;
};

const repoRoot = process.env.PRISM_REPO_ROOT ?? join(__dirname, "../../..");
const fixture = JSON.parse(readFileSync(join(repoRoot, "test/fixtures/wall_search_terms.json"), "utf8")) as Fixture;

test("searchTermsOf matches every text case of the shared fixture", () => {
  assert.ok(fixture.text.length > 0);
  for (const {text, terms} of fixture.text) {
    assert.deepEqual(searchTermsOf(text), terms, JSON.stringify(text));
  }
});

test("wallSearchTermsFor matches every wall case of the shared fixture", () => {
  assert.ok(fixture.wall.length > 0);
  for (const {wall, terms} of fixture.wall) {
    assert.deepEqual(wallSearchTermsFor(wall), terms, JSON.stringify(wall));
  }
});

test("a wall with 100 distinct tags keeps the first 64 terms", () => {
  const tags = Array.from({length: 100}, (_, i) => `tag${i}`);
  const terms = wallSearchTermsFor({tags});
  assert.equal(terms.length, 64);
  assert.equal(terms[0], "tag0");
  assert.equal(terms[63], "tag63");
});

function written(t: TestContext, seed: Doc | undefined) {
  const store = installFakeDb(t, seed ? {"walls/w1": seed} : {});
  const ref = db.collection("walls").doc("w1");
  const update = t.mock.method(ref, "update");
  const run = (after: Doc | undefined) => onWallSearchTerms.run({
    params: {wallId: "w1"},
    data: {
      before: {exists: true, data: () => ({})},
      after: {exists: after !== undefined, ref, data: () => after},
    },
  } as unknown as Parameters<typeof onWallSearchTerms.run>[0]);
  return {store, update, run};
}

test("a written wall with a title gets its search terms", async (t) => {
  const wall = {title: "Lone Lighthouse", tags: ["Night"]};
  const {store, update, run} = written(t, wall);
  await run(wall);
  assert.deepEqual(store.get("walls/w1"), {...wall, searchTerms: ["lone", "lighthouse", "night"]});
  assert.equal(update.mock.callCount(), 1);
});

test("a wall whose stored search terms already match is not updated", async (t) => {
  const wall = {title: "Lone Lighthouse", searchTerms: ["lone", "lighthouse"]};
  const {store, update, run} = written(t, wall);
  await run(wall);
  assert.equal(update.mock.callCount(), 0);
  assert.deepEqual(store.get("walls/w1"), wall);
});

test("stored search terms in another order are replaced", async (t) => {
  const wall = {title: "Lone Lighthouse", searchTerms: ["lighthouse", "lone"]};
  const {store, run} = written(t, wall);
  await run(wall);
  assert.deepEqual(store.get("walls/w1")?.searchTerms, ["lone", "lighthouse"]);
});

test("the write of the trigger settles: its own change writes nothing more", async (t) => {
  const {store, update, run} = written(t, {title: "Boats at Sunset"});
  await run({title: "Boats at Sunset"});
  await run(store.get("walls/w1"));
  assert.equal(update.mock.callCount(), 1);
  assert.deepEqual(store.get("walls/w1")?.searchTerms, ["boat", "sunset"]);
});

test("a deleted wall is left alone", async (t) => {
  const {store, update, run} = written(t, undefined);
  await run(undefined);
  await onWallSearchTerms.run({params: {wallId: "w1"}, data: undefined} as unknown as
    Parameters<typeof onWallSearchTerms.run>[0]);
  assert.equal(update.mock.callCount(), 0);
  assert.equal(store.size, 0);
});
