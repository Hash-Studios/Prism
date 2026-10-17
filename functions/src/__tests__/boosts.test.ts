import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {boostWall} from "../boosts";
import {resetEconomyCache} from "../economy";
import {mergeBoosted} from "../trending";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");
const DAY = 86_400_000;
const REQ = "request_0001";

function setup(t: TestContext, seed: Record<string, Doc> = {}) {
  resetEconomyCache();
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  return installFakeDb(t, {
    "usersv2/u1": {coins: 500, email: "Owner@Example.com"},
    "walls/WALL1": {id: "WALL1", review: true, email: "owner@example.com"},
    ...seed,
  });
}

const run = (data: Record<string, unknown>, uid = "u1") =>
  boostWall.run({auth: {uid, token: {}}, data} as never);

test("mergeBoosted puts upper-case boosted ids first, drops repeats and keeps 100", () => {
  assert.deepEqual(mergeBoosted(["b", "a"], ["C", "A", "D"]), ["B", "A", "C", "D"]);
  const scored = Array.from({length: 120}, (_, i) => `W${i}`);
  const merged = mergeBoosted(["W5", "NEW"], scored);
  assert.equal(merged.length, 100);
  assert.deepEqual(merged.slice(0, 3), ["W5", "NEW", "W0"]);
  assert.equal(merged.filter((id) => id === "W5").length, 1);
});

test("boostWall needs a valid wallId and requestId", async (t) => {
  setup(t);
  await assert.rejects(run({wallId: "", requestId: REQ}), {code: "invalid-argument"});
  await assert.rejects(run({wallId: "a/b", requestId: REQ}), {code: "invalid-argument"});
  await assert.rejects(run({wallId: "WALL1", requestId: "short"}), {code: "invalid-argument"});
  await assert.rejects(boostWall.run({data: {wallId: "WALL1", requestId: REQ}} as never), {code: "unauthenticated"});
});

test("boostWall refuses a missing wall, an unapproved wall, a stranger and a studio wall", async (t) => {
  const store = setup(t, {
    "walls/PENDING": {review: false, email: "owner@example.com"},
    "walls/OTHER": {review: true, email: "someone@example.com"},
    "walls/STUDIO": {review: true, email: "owner@example.com", origin: "studio"},
  });
  await assert.rejects(run({wallId: "NOPE", requestId: REQ}),
    (err: HttpsError) => err.code === "not-found" && err.message === "boost_wall_not_found");
  const pending = await run({wallId: "PENDING", requestId: REQ});
  assert.equal(pending.success, false);
  assert.equal(pending.reason, "boost_wall_not_approved");
  for (const wallId of ["OTHER", "STUDIO"]) {
    await assert.rejects(run({wallId, requestId: REQ}),
      (err: HttpsError) => err.code === "permission-denied" && err.message === "boost_not_owner");
  }
  assert.equal(store.get("usersv2/u1")?.coins, 500);
  assert.equal(store.has("boosts/PENDING"), false);
});

test("boostWall refuses when the balance is short", async (t) => {
  const store = setup(t, {"usersv2/u1": {coins: 99, email: "owner@example.com"}});
  const result = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(result.success, false);
  assert.equal(result.insufficientBalance, true);
  assert.equal(result.reason, "boostWall_insufficient_balance");
  assert.equal(store.get("usersv2/u1")?.coins, 99);
});

test("boostWall debits, writes the boost and boostedUntil, and puts the wall first in trending", async (t) => {
  const store = setup(t, {"trending/current": {wallIds: ["X", "WALL1", "Y"]}});
  const result = await run({wallId: "WALL1", requestId: REQ});
  const endsAt = NOW.getTime() + DAY;
  assert.equal(result.success, true);
  assert.equal(result.endsAt, endsAt);
  assert.equal(result.previousBalance, 500);
  assert.equal(result.currentBalance, 400);
  assert.equal(result.delta, -100);
  assert.equal(result.transactionId, `ctx_boost_u1_${REQ}`);
  assert.equal(store.get("usersv2/u1")?.coins, 400);
  assert.deepEqual(store.get("boosts/WALL1"), {wallId: "WALL1", uid: "u1", startsAt: NOW.getTime(), endsAt});
  assert.equal(store.get("walls/WALL1")?.boostedUntil, endsAt);
  assert.deepEqual(store.get("trending/current")?.wallIds, ["WALL1", "X", "Y"]);
  const ledger = store.get(`coinTransactions/ctx_boost_u1_${REQ}`);
  assert.equal(ledger?.action, "boostWall");
  assert.equal(ledger?.reason, "boost_WALL1");
  assert.equal(ledger?.sourceTag, "boosts.purchase.callable");
  assert.equal(ledger?.delta, -100);
});

test("boostWall creates trending/current when it is missing", async (t) => {
  const store = setup(t);
  await run({wallId: "WALL1", requestId: REQ});
  assert.deepEqual(store.get("trending/current")?.wallIds, ["WALL1"]);
});

test("a Pro caller pays the full price", async (t) => {
  const store = setup(t, {"usersv2/u1": {coins: 500, email: "owner@example.com", premium: true}});
  const result = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(result.delta, -100);
  assert.equal(store.get("usersv2/u1")?.coins, 400);
});

test("a replay returns the stored result and charges once", async (t) => {
  const store = setup(t);
  const first = await run({wallId: "WALL1", requestId: REQ});
  const replay = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(replay.success, true);
  assert.equal(replay.endsAt, first.endsAt);
  assert.equal(replay.currentBalance, 400);
  assert.equal(replay.transactionId, first.transactionId);
  assert.equal(store.get("usersv2/u1")?.coins, 400);
});

test("boostWall refuses a wall that is already boosted", async (t) => {
  const store = setup(t, {"boosts/WALL1": {wallId: "WALL1", uid: "u1", startsAt: 1, endsAt: NOW.getTime() + 1000}});
  const result = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(result.reason, "boost_active");
  assert.equal(store.get("usersv2/u1")?.coins, 500);
});

test("an expired boost can be bought again", async (t) => {
  const store = setup(t, {"boosts/WALL1": {wallId: "WALL1", uid: "u1", startsAt: 1, endsAt: NOW.getTime() - 1}});
  const result = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(result.success, true);
  assert.equal(store.get("boosts/WALL1")?.endsAt, NOW.getTime() + DAY);
});

test("boostWall refuses when 10 boosts are active", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let i = 0; i < 10; i += 1) {
    seed[`boosts/B${i}`] = {wallId: `B${i}`, uid: `x${i}`, startsAt: 1, endsAt: NOW.getTime() + 1000 + i};
  }
  const store = setup(t, seed);
  const result = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(result.success, false);
  assert.equal(result.reason, "boost_slots_full");
  assert.equal(result.nextFreeAt, NOW.getTime() + 1000);
  assert.equal(store.get("usersv2/u1")?.coins, 500);
  assert.equal(store.has("boosts/WALL1"), false);
});

test("expired boosts do not take a slot", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let i = 0; i < 10; i += 1) {
    seed[`boosts/B${i}`] = {wallId: `B${i}`, uid: `x${i}`, startsAt: 1, endsAt: NOW.getTime() - 1};
  }
  setup(t, seed);
  const result = await run({wallId: "WALL1", requestId: REQ});
  assert.equal(result.success, true);
});
