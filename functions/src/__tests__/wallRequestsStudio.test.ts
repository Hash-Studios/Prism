import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {createStudioRun} from "../studio/planRun";
import {type Doc, installFakeDb} from "./fakeDb";
import {seededRng} from "./studioTestUtil";

const NOW = Date.parse("2026-10-12T20:00:00Z");
const DAY_MS = 24 * 60 * 60 * 1000;
const IDENTITY = {by: "Prism Studio", email: "studio@prismwalls.com", userPhoto: ""};

function setup(t: TestContext, config: Doc = {}, seed: Record<string, Doc> = {}) {
  return installFakeDb(t, {"studioConfig/current": {generationEnabled: true, identity: IDENTITY, ...config}, ...seed});
}
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const candidate = (store: Map<string, Doc>, runId: string, index: number) =>
  store.get(`studioRuns/${runId}/candidates/${runId}-${index}`);
const candidateCount = (store: Map<string, Doc>, runId: string) =>
  [...store.keys()].filter((path) => path.startsWith(`studioRuns/${runId}/candidates/`)).length;

const request = (voteCount: number, extra: Doc = {}): Doc => ({
  text: "Dark minimal mountains", tags: ["Dark"], status: "open", hidden: false, voteCount,
  createdAt: ts(NOW - DAY_MS), requesterUid: "requester", ...extra,
});
const requestSeed = (): Record<string, Doc> => ({
  "wallRequests/r1": request(9),
  "wallRequests/r2": request(5),
  "wallRequests/r3": request(3),
  "wallRequests/r4": request(2),
  "wallRequests/r5": request(8, {hidden: true}),
  "wallRequests/r6": request(7, {createdAt: ts(NOW - 31 * DAY_MS)}),
  "wallRequests/r7": request(6, {studioQueuedAt: ts(NOW - 2 * DAY_MS)}),
});

test("a schedule run gives its first slots to the most voted requests and marks them", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 30}, requestSeed());
  const before = new Map(store);
  const result = await createStudioRun({runId: "d20261012", count: 10, source: "schedule", nowMs: NOW,
    rng: seededRng(1)});
  assert.deepEqual(result, {status: "created", runId: "d20261012", count: 10});
  assert.equal(store.get("studioRuns/d20261012")?.count, 10);

  for (const [index, requestId] of ["r1", "r2", "r3"].entries()) {
    const c = candidate(store, "d20261012", index);
    assert.equal(c?.requestId, requestId);
    assert.equal(c?.seriesId, "request");
    assert.equal(c?.subjectId, `request_${requestId}`);
    assert.ok(String(c?.prompt).startsWith("Dark minimal mountains. "));
    assert.equal(c?.category, "Dark");
    assert.ok((c?.tags as string[]).includes("request"));
  }
  for (let index = 3; index < 10; index++) {
    assert.equal(candidate(store, "d20261012", index)?.requestId, undefined);
  }

  for (const requestId of ["r1", "r2", "r3"]) {
    const r = store.get(`wallRequests/${requestId}`);
    assert.equal(r?.studioRunId, "d20261012");
    assert.equal((r?.studioQueuedAt as admin.firestore.Timestamp).toMillis(), NOW);
  }
  for (const requestId of ["r4", "r5", "r6", "r7"]) {
    assert.deepEqual(store.get(`wallRequests/${requestId}`), before.get(`wallRequests/${requestId}`));
  }
  assert.equal(store.has("studioSubjectUse/request_r1"), false);
});

test("a request takes the category of its first category tag, or General without one", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 30}, {
    "wallRequests/a1": request(9, {text: "Black wallpaper glow", tags: ["AMOLED"]}),
    "wallRequests/f1": request(8, {text: "Forest dawn light", tags: ["Forest"]}),
    "wallRequests/n1": request(7, {text: "Quiet stone bridge", tags: []}),
  });
  await createStudioRun({runId: "d20261012", count: 3, source: "schedule", nowMs: NOW, rng: seededRng(2)});
  assert.equal(candidate(store, "d20261012", 0)?.requestId, "a1");
  assert.equal(candidate(store, "d20261012", 0)?.category, "Dark");
  assert.equal(candidate(store, "d20261012", 1)?.requestId, "f1");
  assert.equal(candidate(store, "d20261012", 1)?.category, "Nature");
  assert.equal(candidate(store, "d20261012", 2)?.requestId, "n1");
  assert.equal(candidate(store, "d20261012", 2)?.category, "General");
});

test("the daily cap leaves room for only two candidates, both from requests", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 30}, {
    ...requestSeed(),
    "studioDaily/2026-10-12": {day: "2026-10-12", count: 28},
  });
  const result = await createStudioRun({runId: "d20261012", count: 10, source: "schedule", nowMs: NOW,
    rng: seededRng(3)});
  assert.deepEqual(result, {status: "created", runId: "d20261012", count: 2});
  assert.equal(candidateCount(store, "d20261012"), 2);
  assert.equal(candidate(store, "d20261012", 0)?.requestId, "r1");
  assert.equal(candidate(store, "d20261012", 1)?.requestId, "r2");
  assert.equal(store.get("studioDaily/2026-10-12")?.count, 30);
});

test("a manual run takes no requests and changes none", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 30}, requestSeed());
  const before = new Map(store);
  const result = await createStudioRun({runId: "m1760300000001", count: 10, source: "manual", nowMs: NOW,
    rng: seededRng(4)});
  assert.deepEqual(result, {status: "created", runId: "m1760300000001", count: 10});
  assert.equal(candidateCount(store, "m1760300000001"), 10);
  for (let index = 0; index < 10; index++) {
    assert.equal(candidate(store, "m1760300000001", index)?.requestId, undefined);
  }
  for (const requestId of ["r1", "r2", "r3", "r4", "r5", "r6", "r7"]) {
    assert.deepEqual(store.get(`wallRequests/${requestId}`), before.get(`wallRequests/${requestId}`));
  }
});

test("the same schedule run id again changes no request and keeps studioQueuedAt", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 30}, requestSeed());
  await createStudioRun({runId: "d20261012", count: 10, source: "schedule", nowMs: NOW, rng: seededRng(1)});
  const before = new Map(store);
  assert.equal((store.get("wallRequests/r1")?.studioQueuedAt as admin.firestore.Timestamp).toMillis(), NOW);
  assert.deepEqual(await createStudioRun({runId: "d20261012", count: 10, source: "schedule", nowMs: NOW,
    rng: seededRng(1)}), {status: "exists", runId: "d20261012", count: 0});
  assert.deepEqual(store, before);
});
