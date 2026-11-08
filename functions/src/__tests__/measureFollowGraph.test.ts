import assert from "node:assert/strict";
import test from "node:test";

import {percentile, summarizeCounts, utf8Bytes} from "../scripts/measureFollowGraph";

test("percentile uses nearest rank on a sorted list", () => {
  const ten = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  assert.equal(percentile(ten, 0.5), 5);
  assert.equal(percentile(ten, 0.9), 9);
  assert.equal(percentile(ten, 0.99), 10);
  assert.equal(percentile([], 0.5), 0);
});

test("summarizeCounts counts docs, non-empty arrays, thresholds and percentiles", () => {
  assert.deepEqual(summarizeCounts([6000, 0, 600, 3, 0, 1200]), {
    docs: 6,
    nonEmpty: 4,
    max: 6000,
    p50: 3,
    p90: 6000,
    p99: 6000,
    over500: 3,
    over1000: 2,
    over5000: 1,
  });
});

test("utf8Bytes sums UTF-8 bytes of string elements only", () => {
  assert.equal(utf8Bytes(["a", "é", "😀", 7]), 7);
});
