import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {createStudioRun, parseRunInput, planStudioBatch, runStudioBatch} from "../studio/planRun";
import {STUDIO_SERIES} from "../studio/series";
import {type Doc, installFakeDb} from "./fakeDb";
import {seededRng} from "./studioTestUtil";

const NOW = Date.parse("2026-10-12T20:00:00Z");
const DAY_MS = 24 * 60 * 60 * 1000;
const IDENTITY = {by: "Prism Studio", email: "studio@prismwalls.com", userPhoto: ""};

function setup(t: TestContext, config: Doc = {}, seed: Record<string, Doc> = {}) {
  return installFakeDb(t, {"studioConfig/current": {generationEnabled: true, identity: IDENTITY, ...config}, ...seed});
}
const candidates = (store: Map<string, Doc>, runId: string) =>
  [...store.entries()].filter(([path]) => path.startsWith(`studioRuns/${runId}/candidates/`));
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const call = (request: Record<string, unknown>) => runStudioBatch.run(request as any);
const admin1 = {uid: "a1", token: {admin: true}};

test("a run writes the run doc, queued candidates, the day's counter and the subject use", async (t) => {
  const store = setup(t);
  const result = await createStudioRun({runId: "d20261012", source: "schedule", nowMs: NOW, rng: seededRng(1)});
  assert.deepEqual(result, {status: "created", runId: "d20261012", count: 10});

  const run = store.get("studioRuns/d20261012");
  assert.equal(run?.source, "schedule");
  assert.equal(run?.count, 10);
  assert.equal(run?.model, "fal-ai/bytedance/seedream/v4.5/text-to-image");
  const items = candidates(store, "d20261012");
  assert.deepEqual(items.map(([path]) => path.split("/").pop()).sort(),
    Array.from({length: 10}, (_, i) => `d20261012-${i}`).sort());
  for (const [, c] of items) {
    assert.equal(c.status, "queued");
    assert.equal(c.attempts, 0);
    assert.deepEqual([c.width, c.height], [1440, 3200]);
    assert.ok(typeof c.prompt === "string" && typeof c.seed === "number" && typeof c.subjectId === "string");
  }
  assert.equal(store.get("studioDaily/2026-10-12")?.count, 10);
  for (const [, c] of items) {
    const use = store.get(`studioSubjectUse/${c.subjectId}`);
    assert.equal((use?.lastUsedAt as admin.firestore.Timestamp).toMillis(), NOW);
    assert.equal(use?.lastRunId, "d20261012");
  }
});

test("the same run id again plans nothing", async (t) => {
  const store = setup(t);
  await createStudioRun({runId: "d20261012", source: "schedule", nowMs: NOW});
  const before = new Map(store);
  assert.deepEqual(await createStudioRun({runId: "d20261012", source: "schedule", nowMs: NOW}),
    {status: "exists", runId: "d20261012", count: 0});
  assert.deepEqual(store, before);
});

test("the day's cap counts every run and trims the last one", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 30});
  assert.equal((await createStudioRun({runId: "m1760300000001", count: 25, source: "manual", nowMs: NOW})).count, 25);
  assert.equal((await createStudioRun({runId: "m1760300000002", count: 10, source: "manual", nowMs: NOW})).count, 5);
  assert.deepEqual(await createStudioRun({runId: "m1760300000003", count: 1, source: "manual", nowMs: NOW}),
    {status: "daily_cap", runId: "m1760300000003", count: 0});
  assert.equal(store.get("studioDaily/2026-10-12")?.count, 30);
  assert.equal(store.has("studioRuns/m1760300000003"), false);
  assert.equal((await createStudioRun({runId: "m1760300000004", count: 2, source: "manual", nowMs: NOW + DAY_MS})).count, 2);
});

test("generation off plans nothing and writes nothing", async (t) => {
  const store = setup(t, {generationEnabled: false});
  assert.deepEqual(await createStudioRun({runId: "d20261012", source: "schedule", nowMs: NOW}),
    {status: "disabled", runId: "d20261012", count: 0});
  assert.deepEqual([...store.keys()], ["studioConfig/current"]);
});

test("subjects used inside the cooldown are skipped; older use is not a cooldown", async (t) => {
  const afterDark = STUDIO_SERIES[0];
  const uses: Record<string, Doc> = {};
  for (const s of afterDark.subjects) {
    const daysAgo = s.id === "eclipse" ? 30 : 1;
    uses[`studioSubjectUse/${s.id}`] = {lastUsedAt: admin.firestore.Timestamp.fromMillis(NOW - daysAgo * DAY_MS)};
  }
  const store = setup(t, {}, uses);
  await createStudioRun({runId: "m1760300000001", count: 1, seriesId: "after-dark", source: "manual", nowMs: NOW});
  const [[, c]] = candidates(store, "m1760300000001");
  assert.equal(c.subjectId, "eclipse");
  assert.equal(store.get("studioRuns/m1760300000001")?.seriesId, "after-dark");
});

test("the schedule names the run after the UTC day and runs once per day", async (t) => {
  const store = setup(t, {dailyCandidates: 4});
  const event = {jobName: "j", scheduleTime: "2026-10-12T20:00:00.000Z"};
  await planStudioBatch.run(event);
  await planStudioBatch.run(event);
  assert.equal(store.get("studioRuns/d20261012")?.count, 4);
  assert.equal(candidates(store, "d20261012").length, 4);
  assert.equal(store.get("studioDaily/2026-10-12")?.count, 4);
});

test("run input: count is a whole number from 1 to 30 and seriesId is a known series", () => {
  assert.deepEqual(parseRunInput({count: 5}), {count: 5});
  assert.deepEqual(parseRunInput({count: 30, seriesId: "paper-worlds"}), {count: 30, seriesId: "paper-worlds"});
  assert.deepEqual(parseRunInput({count: 1, seriesId: null}), {count: 1});
  for (const bad of [undefined, null, {}, {count: 0}, {count: 31}, {count: 2.5}, {count: "5"},
    {count: 2, seriesId: "nope"}, {count: 2, seriesId: 7}]) {
    assert.throws(() => parseRunInput(bad), {code: "invalid-argument"}, JSON.stringify(bad));
  }
});

test("runStudioBatch is for admins only and checks its input", async (t) => {
  setup(t, {}, {"config/adminNotifications": {emails: []}});
  await assert.rejects(call({data: {count: 2}}), {code: "unauthenticated"});
  await assert.rejects(call({auth: {uid: "u1", token: {email: "u@x.com", email_verified: true}}, data: {count: 2}}),
    {code: "permission-denied"});
  await assert.rejects(call({auth: admin1, data: {count: 0}}), {code: "invalid-argument"});
  await assert.rejects(call({auth: admin1, data: {count: 2, seriesId: "nope"}}), {code: "invalid-argument"});
});

test("runStudioBatch plans a manual run and reports when it cannot", async (t) => {
  const store = setup(t, {maxCandidatesPerDay: 3});
  const result = await call({auth: admin1, data: {count: 3, seriesId: "quiet-architecture"}});
  assert.match(result.runId, /^m\d+$/);
  assert.equal(result.count, 3);
  assert.equal(store.get(`studioRuns/${result.runId}`)?.source, "manual");
  assert.ok(candidates(store, result.runId).every(([, c]) => c.seriesId === "quiet-architecture"));
  await assert.rejects(call({auth: admin1, data: {count: 1}}), {code: "resource-exhausted"});

  setup(t, {generationEnabled: false});
  await assert.rejects(call({auth: admin1, data: {count: 1}}), {code: "failed-precondition"});
});
