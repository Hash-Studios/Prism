import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {type CreatorFundConfig, DEFAULT_ECONOMY} from "../economy";
import {creatorFundStatus, getCreatorFundStatus} from "../creatorFund/status";
import {creatorFundIo} from "../creatorFund/settle";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = Date.parse("2026-11-18T10:00:00Z");
const WEEK = "2026-W46";
const WEEK_PATH = `creatorFund/${WEEK}`;
const RULES: CreatorFundConfig = {...DEFAULT_ECONOMY.creatorFund, pool: 100, maxUserSharePercent: 100};
const base = {schemaVersion: 1, week: WEEK, minDistinctUsers: 5, minPayout: 5};

function setup(t: TestContext, seed: Record<string, Doc> = {}, pool = 100) {
  const store = installFakeDb(t, seed);
  t.mock.method(creatorFundIo, "economy", async () => ({...RULES, pool}));
  return store;
}

const weekDoc = (state: string) => ({[WEEK_PATH]: {state, rules: RULES, pool: 100, coinsPaid: 0, paidCreators: 0}});

test("no week doc and a zero pool gives off", async (t) => {
  setup(t, {}, 0);
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 0, state: "off"});
});

test("no week doc and a live pool gives pending", async (t) => {
  setup(t);
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 0, state: "pending"});
});

test("a computing week gives pending even when the caller has a row", async (t) => {
  setup(t, {...weekDoc("computing"), [`${WEEK_PATH}/creators/a`]: {status: "paid", coins: 25, shareBps: 2500,
    distinctUsers: 5, payState: "due"}});
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 0, state: "pending"});
});

test("a paid row gives paid with its coins and share", async (t) => {
  setup(t, {...weekDoc("complete"), [`${WEEK_PATH}/creators/a`]: {status: "paid", coins: 25, shareBps: 2500,
    distinctUsers: 5, payState: "done", scoreCenti: 500, capped: false}});
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 5, state: "paid", coins: 25,
    shareBps: 2500});
});

for (const reason of ["fewUsers", "smallShare", "moderation", "team"]) {
  test(`a stored ${reason} row gives notQualified with that reason`, async (t) => {
    setup(t, {...weekDoc("complete"), [`${WEEK_PATH}/creators/a`]: {status: "notQualified", reason, coins: 0,
      payState: "none", shareBps: 40, distinctUsers: 6, scoreCenti: 300, capped: false}});
    assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 6, state: "notQualified", reason,
      shareBps: 40});
  });
}

test("an unknown stored reason falls back to noActivity", async (t) => {
  setup(t, {...weekDoc("complete"), [`${WEEK_PATH}/creators/a`]: {status: "notQualified", reason: "closed",
    payState: "none", shareBps: 0, distinctUsers: 0}});
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 0, state: "notQualified",
    reason: "noActivity", shareBps: 0});
});

test("a complete week with no row for the caller gives notQualified noActivity", async (t) => {
  setup(t, {...weekDoc("complete"), [`${WEEK_PATH}/creators/other`]: {status: "paid", coins: 75, shareBps: 7500,
    distinctUsers: 5, payState: "done"}});
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 0, state: "notQualified",
    reason: "noActivity", shareBps: 0});
});

test("the callable returns the status for the signed-in caller", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  setup(t, {...weekDoc("complete"), [`${WEEK_PATH}/creators/a`]: {status: "paid", coins: 25, shareBps: 2500,
    distinctUsers: 5, payState: "done"}});
  const result = await getCreatorFundStatus.run({auth: {uid: "a", token: {}}, data: {}} as never);
  assert.deepEqual(result, {...base, distinctUsers: 5, state: "paid", coins: 25, shareBps: 2500});
});

test("the callable refuses a signed-out caller and a non-empty payload", async (t) => {
  setup(t);
  await assert.rejects(getCreatorFundStatus.run({data: {}} as never),
    (err: HttpsError) => err.code === "unauthenticated");
  await assert.rejects(getCreatorFundStatus.run({auth: {uid: "a", token: {}}, data: {week: WEEK}} as never),
    (err: HttpsError) => err.code === "invalid-argument");
});

test("the week used is the last complete ISO week before now", async (t) => {
  setup(t, {"creatorFund/2026-W45": {state: "complete", rules: RULES, pool: 100},
    "creatorFund/2026-W45/creators/a": {status: "paid", coins: 10, shareBps: 1000, distinctUsers: 5,
      payState: "done"}});
  const status = await creatorFundStatus("a", Date.UTC(2026, 10, 16, 6));
  assert.equal(status.week, "2026-W46");
  assert.equal(status.state, "pending");
});

test("an unpaid allocation stays pending until its ledger transaction commits", async (t) => {
  setup(t, {...weekDoc("paying"), [`${WEEK_PATH}/creators/a`]: {status: "paid", payState: "due", coins: 25}});
  assert.deepEqual(await creatorFundStatus("a", NOW), {...base, distinctUsers: 0, state: "pending"});
});

test("the displayed share of the fund reflects the coins actually credited after a cap", async (t) => {
  setup(t, {...weekDoc("complete"), [`${WEEK_PATH}/creators/a`]: {status: "paid", payState: "done", coins: 5, shareBps: 10000}});
  const status = await creatorFundStatus("a", NOW);
  assert.equal(status.state === "paid" && status.shareBps, 500);
});
