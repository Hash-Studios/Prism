import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {db} from "../common";
import {backfillDesktopCompanions, parseDesktopBackfillArgs} from "../scripts/backfillDesktopCompanions";
import type {DesktopOutcome} from "../studio/desktop";
import {STUDIO_COMPOSITION} from "../studio/series";
import {type Doc, installFakeDb} from "./fakeDb";

const PREVIEW = "https://images.example.com";
const MODEL = "openai/gpt-image-2.5/sunburst/text-to-image";
const AI_PROMPT = `a lighthouse, ember light. Calm style. ${STUDIO_COMPOSITION}`;

function setEnv(t: TestContext) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {R2_PREVIEW_BASE_URL: PREVIEW});
}

const wall = (id: string, extra: Doc = {}): Doc => ({id, review: true, origin: "studio", aiModel: MODEL,
  aiPrompt: AI_PROMPT, tags: [], ...extra});

function seed(t: TestContext) {
  setEnv(t);
  return installFakeDb(t, {
    "walls/A1": wall("A1"),
    "walls/A2": wall("A2"),
    "walls/A3": wall("A3", {desktopVariant: {v: "0123456789abcdef", width: 2560, height: 1600, wideHeight: 1440,
      thumb: `${PREVIEW}/previews/desktop-${"cd".repeat(32)}.jpg`}}),
    "walls/A4": wall("A4", {tags: ["duo"]}),
    "walls/A5": wall("A5"),
    "desktopCompanions/A5": {status: "ready"},
  });
}

const isStudio = async () => true;
const quiet = () => undefined;

test("dry run plans the first eligible wall with its cost and makes nothing", async (t) => {
  seed(t);
  const make = t.mock.fn(async (): Promise<DesktopOutcome> => "ready");
  const lines: string[] = [];

  const report = await backfillDesktopCompanions(db, {apply: false, limit: 1}, {make, isStudio},
    (line) => lines.push(line));

  assert.deepEqual(report.planned.map((plan) => plan.id), ["A1"]);
  assert.equal(report.costUsd, 0.0745);
  assert.equal(make.mock.callCount(), 0);
  assert.ok(lines.includes("would make A1 model=openai/gpt-image-2.5/sunburst/text-to-image cost=$0.0745"));
});

test("dry run with a higher limit plans every eligible wall and counts each skip", async (t) => {
  seed(t);
  const make = t.mock.fn(async (): Promise<DesktopOutcome> => "ready");

  const report = await backfillDesktopCompanions(db, {apply: false, limit: 10}, {make, isStudio}, quiet);

  assert.deepEqual(report.planned.map((plan) => plan.id), ["A1", "A2"]);
  assert.equal(report.costUsd, 0.149);
  assert.deepEqual(report.skipped, {exists: 1, duo: 1, manifest_ready: 1});
  assert.equal(make.mock.callCount(), 0);
});

test("apply stops at the first deferred wall, even with more eligible walls", async (t) => {
  const store = seed(t);
  store.set("walls/A6", wall("A6"));
  const outcomes: DesktopOutcome[] = ["ready", "deferred"];
  const made: string[] = [];
  const make = t.mock.fn(async (wallPath: string): Promise<DesktopOutcome> => {
    made.push(wallPath);
    return outcomes.shift() ?? "failed";
  });

  const report = await backfillDesktopCompanions(db, {apply: true, limit: 25}, {make, isStudio}, quiet);

  assert.equal(make.mock.callCount(), 2);
  assert.deepEqual(made, ["walls/A1", "walls/A2"]);
  assert.deepEqual(report.outcomes, {ready: 1, deferred: 1});
});

test("parseDesktopBackfillArgs refuses a limit below 1 and reads the flags", () => {
  assert.throws(() => parseDesktopBackfillArgs(["--limit=0"]), /--limit must be 1 to 1000/);
  assert.deepEqual(parseDesktopBackfillArgs([]), {apply: false, limit: 25, startAfter: undefined});
  assert.deepEqual(parseDesktopBackfillArgs(["--apply", "--limit=3", "--start-after=X"]),
    {apply: true, limit: 3, startAfter: "X"});
});
