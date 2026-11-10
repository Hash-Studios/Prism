import assert from "node:assert/strict";
import {test} from "node:test";
import * as functions from "../index";

interface Endpoint {
  callableTrigger?: unknown;
  region?: unknown;
  cpu?: unknown;
  maxInstances?: unknown;
  concurrency?: unknown;
}

// These handlers require admin authority on every authorized path. Creator/owner alternatives are user callables.
const ADMIN_ONLY = new Set([
  "createPromoCode", "getWallResubmissionContext", "listPromoCodes", "listWallMetadataEdits",
  "registerReviewLiveActivity", "rejectWallForReview", "revertWallMetadata", "reviewDesktopSubmission",
  "runStudioBatch", "setCommentHidden", "setDropTitle", "setEditorsChoice", "setFolderDiscoveryHidden",
  "setFolderHidden", "setPromoCodeDisabled", "setWallRequestHidden", "undoWallRejection",
]);

// Observed regional instance peaks supplied for this change. All other user callables peaked at one instance.
const USER_PEAKS: Record<string, number> = {
  checkBadges: 2,
  createWallRequest: 2,
  getRewardedSession: 2,
  listWallRequests: 2,
  listWeeklyChallenges: 2,
  progressQuest: 2,
  reconcileRankRewards: 2,
  recordWallpaperView: 2,
  setFollow: 3,
  spendCoins: 2,
  syncSubscription: 3,
};

const endpoints: Record<string, Endpoint> = Object.fromEntries(Object.entries(functions as Record<string, {__endpoint: Endpoint}>)
  .map(([name, fn]) => [name, fn.__endpoint]));
const callables: Record<string, Endpoint> = Object.fromEntries(Object.entries(endpoints)
  .filter(([, endpoint]) => Object.prototype.hasOwnProperty.call(endpoint, "callableTrigger")));
const users = Object.entries(callables).filter(([name]) => !ADMIN_ONLY.has(name));

test("every user callable keeps full CPU and concurrent request handling", () => {
  assert.ok(users.length > 60, "expected the complete exported user-callable inventory");
  const serialized = users.filter(([, endpoint]) => endpoint.cpu === "gcf_gen1" ||
    typeof endpoint.cpu === "number" && endpoint.cpu < 1 ||
    typeof endpoint.concurrency === "number" && endpoint.concurrency < 2);
  assert.deepEqual(serialized.map(([name]) => name), []);
});

test("every user callable can reach its observed instance peak", () => {
  for (const name of Object.keys(USER_PEAKS)) assert.ok(callables[name], `unknown peak callable: ${name}`);
  const capped = users.filter(([name, endpoint]) => typeof endpoint.maxInstances !== "number" ||
    !Number.isInteger(endpoint.maxInstances) || endpoint.maxInstances < (USER_PEAKS[name] ?? 1));
  assert.deepEqual(capped.map(([name]) => name), []);
});

test("true admin callables retain their measured one-instance peak after all shared option spreads", () => {
  for (const name of ADMIN_ONLY) {
    const endpoint = callables[name];
    assert.ok(endpoint, `unknown admin callable: ${name}`);
    assert.equal(endpoint.cpu, "gcf_gen1", `${name} CPU`);
    assert.equal(endpoint.maxInstances, 1, `${name} maxInstances`);
  }
});

test("callables retain their configured regions, including US-only rewarded sessions", () => {
  const usOnly = new Set(["beginRewardedSession", "getRewardedSession"]);
  for (const [name, endpoint] of Object.entries(callables)) {
    assert.deepEqual(endpoint.region, usOnly.has(name) ? ["us-central1"] : ["asia-south1", "us-central1"], name);
  }
});

test("AdMob reward callbacks retain full CPU, concurrency and observed capacity in the US", () => {
  const endpoint = endpoints.admobRewardedSsv;
  assert.notEqual(endpoint.cpu, "gcf_gen1");
  if (typeof endpoint.cpu === "number") assert.ok(endpoint.cpu >= 1);
  if (typeof endpoint.concurrency === "number") assert.ok(endpoint.concurrency >= 2);
  assert.ok(typeof endpoint.maxInstances === "number" && Number.isInteger(endpoint.maxInstances) &&
    endpoint.maxInstances >= 1);
  assert.deepEqual(endpoint.region, ["us-central1"]);
});

test("wallpaperPreview retains its measured serving capacity", () => {
  const endpoint = endpoints.wallpaperPreview;
  assert.equal(endpoint.cpu, 1);
  assert.equal(endpoint.concurrency, 8);
  assert.equal(endpoint.maxInstances, 10);
  assert.deepEqual(endpoint.region, ["asia-south1", "us-central1"]);
});
