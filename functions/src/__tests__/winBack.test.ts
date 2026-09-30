import assert from "node:assert/strict";
import test from "node:test";
import {WIN_BACK_STEPS, winBackStepFor} from "../winBack";

const NOW = 1_700_000_000_000;
const DAY = 24 * 60 * 60 * 1000;
const MIN = 60 * 1000;
const idle = (ms: number) => winBackStepFor(NOW, NOW - ms, undefined);

test("each step fires at exactly N days and just under N+1 days", () => {
  for (const n of WIN_BACK_STEPS) {
    assert.equal(idle(n * DAY), n);
    assert.equal(idle((n + 1) * DAY - MIN), n);
  }
});

test("N days minus 1 minute is the previous step or none", () => {
  assert.equal(idle(3 * DAY - MIN), null);
  assert.equal(idle(7 * DAY - MIN), null);
  assert.equal(idle(30 * DAY - MIN), null);
});

test("N+1 days is outside the window", () => {
  assert.equal(idle(4 * DAY), null);
  assert.equal(idle(8 * DAY), null);
  assert.equal(idle(15 * DAY), null);
  assert.equal(idle(31 * DAY), null);
});

test("0 to 2 days and over 61 days return null", () => {
  assert.equal(idle(0), null);
  assert.equal(idle(2 * DAY + 23 * 60 * MIN), null);
  assert.equal(idle(61 * DAY), null);
  assert.equal(idle(90 * DAY), null);
});

test("same inactivity period already sent is deduped", () => {
  const last = NOW - 7 * DAY;
  assert.equal(winBackStepFor(NOW, last, {step: 7, claimAtMs: last}), null);
  assert.equal(winBackStepFor(NOW, last, {step: 14, claimAtMs: last}), null);
  assert.equal(winBackStepFor(NOW, last, {step: 3, claimAtMs: last}), 7);
});

test("newer activity after an earlier send resets dedupe", () => {
  const last = NOW - 3 * DAY;
  assert.equal(winBackStepFor(NOW, last, {step: 60, claimAtMs: NOW - 200 * DAY}), 3);
});
