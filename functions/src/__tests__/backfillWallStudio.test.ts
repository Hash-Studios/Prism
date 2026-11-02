import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {db} from "../common";
import {backfillWallStudio, parseStudioBackfillArgs} from "../scripts/backfillWallStudio";
import {STUDIO_ACCOUNT} from "../studio/account";
import {type Doc, installFakeDb} from "./fakeDb";

const studio = (extra: Doc): Doc => ({origin: "studio", email: STUDIO_ACCOUNT.email, review: true, ...extra});

const SEED: Record<string, Doc> = {
  "walls/s1": studio({studioRunId: "run1", studioCandidateId: "c1", title: "Proven"}),
  "walls/s2": studio({studioRunId: "run1", studioCandidateId: "c2", title: "Candidate points elsewhere"}),
  "walls/s3": studio({studioRunId: "run1", studioCandidateId: "c3", byStudio: true, title: "Already stamped"}),
  "walls/creator": {origin: "creator", email: "artist@example.com", review: true, title: "Creator"},
  "studioRuns/run1/candidates/c1": {wallId: "s1"},
  "studioRuns/run1/candidates/c2": {wallId: "somewhere-else"},
  "studioRuns/run1/candidates/c3": {wallId: "s3"},
};

function setup(t: TestContext) {
  return installFakeDb(t, structuredClone(SEED));
}

const run = (apply: boolean) => backfillWallStudio(db, {apply}, () => undefined);

test("the Studio backfill is a dry run by default: it counts the match and writes nothing", async (t) => {
  const store = setup(t);
  const before = JSON.stringify([...store.entries()]);
  const counts = await run(parseStudioBackfillArgs([]).apply);
  assert.deepEqual(counts, {scanned: 3, matched: 1, updated: 0, dryRun: true});
  assert.equal(JSON.stringify([...store.entries()]), before);
});

test("--apply stamps byStudio on the proven Studio wall only", async (t) => {
  const store = setup(t);
  const counts = await run(parseStudioBackfillArgs(["--apply"]).apply);
  assert.deepEqual(counts, {scanned: 3, matched: 1, updated: 1, dryRun: false});
  assert.deepEqual(store.get("walls/s1"), {...SEED["walls/s1"], byStudio: true});
  assert.deepEqual(store.get("walls/s2"), SEED["walls/s2"]);
  assert.deepEqual(store.get("walls/creator"), SEED["walls/creator"]);
});

test("a Studio wall whose candidate doc does not point back is skipped", async (t) => {
  const store = setup(t);
  await run(true);
  assert.equal("byStudio" in (store.get("walls/s2") ?? {}), false);
});

test("a Studio wall already marked byStudio is skipped and not counted as a match", async (t) => {
  const store = setup(t);
  const counts = await run(true);
  assert.equal(counts.matched, 1);
  assert.deepEqual(store.get("walls/s3"), SEED["walls/s3"]);
});

test("Studio backfill arguments default to a dry run", () => {
  assert.deepEqual(parseStudioBackfillArgs([]), {apply: false});
  assert.deepEqual(parseStudioBackfillArgs(["--apply"]), {apply: true});
});
