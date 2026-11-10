import assert from "node:assert/strict";
import {test} from "node:test";
import {RESET_VALUE} from "firebase-functions/v2/options";
import {processCreatorStatsDailyQueueScheduled} from "../creatorStatsDaily";

test("creator stats queue keeps its full-CPU, one-minute schedule and at least one instance", () => {
  const endpoint = processCreatorStatsDailyQueueScheduled.__endpoint;
  assert.equal(endpoint.scheduleTrigger?.schedule, "every 1 minutes");
  assert.equal(endpoint.timeoutSeconds, 540);
  assert.equal(endpoint.scheduleTrigger?.retryConfig?.retryCount, 0);
  assert.ok(endpoint.cpu == null || Object.is(endpoint.cpu, RESET_VALUE) ||
    (typeof endpoint.cpu === "number" && endpoint.cpu >= 1));
  assert.ok(typeof endpoint.maxInstances === "number" && endpoint.maxInstances >= 1);
});
