import assert from "node:assert/strict";
import test from "node:test";
import {needsSpatial, parseSpatialBackfillArgs} from "../scripts/backfillWallSpatial";

test("dry run is the default and --apply writes", () => {
  assert.equal(parseSpatialBackfillArgs([]).apply, false);
  assert.equal(parseSpatialBackfillArgs(["--apply"]).apply, true);
});

test("--map-prefix sets the R2 folder for a dry run and cannot be combined with --apply", () => {
  assert.equal(parseSpatialBackfillArgs(["--map-prefix=spatial-test/v1"]).mapPrefix, "spatial-test/v1");
  assert.equal(parseSpatialBackfillArgs([]).mapPrefix, undefined);
  assert.throws(() => parseSpatialBackfillArgs(["--apply", "--map-prefix=x"]), /--map-prefix is for dry runs only/);
});

test("batch size and limit fall back to safe defaults", () => {
  assert.equal(parseSpatialBackfillArgs([]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--batch=500"]).batchSize, 500);
  assert.equal(parseSpatialBackfillArgs(["--batch=501"]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--batch=0"]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--batch=abc"]).batchSize, 100);
  assert.equal(parseSpatialBackfillArgs(["--limit=0"]).limit, undefined);
  assert.equal(parseSpatialBackfillArgs(["--limit=50"]).limit, 50);
});

test("needsSpatial skips only walls already at the current version unless forced", () => {
  assert.equal(needsSpatial(undefined, false), true);
  assert.equal(needsSpatial({v: 0}, false), true);
  assert.equal(needsSpatial({v: 1}, false), false);
  assert.equal(needsSpatial({v: 1}, true), true);
});
