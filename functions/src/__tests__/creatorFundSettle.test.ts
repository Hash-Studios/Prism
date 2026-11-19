import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {type CreatorFundConfig, DEFAULT_ECONOMY} from "../economy";
import type {CreatorGate, FundEvent} from "../creatorFund/score";
import {creatorFundIo, settleCreatorFundWeek} from "../creatorFund/settle";
import {type Doc, installFakeDb} from "./fakeDb";

const WEEK = "2026-W46";
const WEEK_PATH = `creatorFund/${WEEK}`;
const START = Date.parse("2026-11-16T07:00:00Z");
const RULES: CreatorFundConfig = {...DEFAULT_ECONOMY.creatorFund, pool: 100, maxUserSharePercent: 100};
const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

type Sent = {payload: {title: string; docId: string}; recipient: unknown; push: boolean};

type Fixture = {
  rules?: Partial<CreatorFundConfig>;
  events?: FundEvent[];
  walls?: Record<string, string>;
  gates?: Record<string, CreatorGate>;
  seed?: Record<string, Doc>;
  options?: Parameters<typeof installFakeDb>[3];
  afterCompute?: (store: Map<string, Doc>) => void;
};

const defaultEvents: FundEvent[] = [
  ...["f1", "f2", "f3", "f4", "f5"].map((actorUid) => ({wallId: "w1", metric: "saves" as const, actorUid})),
  ...["f1", "f2", "f3", "f4", "f5"].map((actorUid) => ({wallId: "w2", metric: "sets" as const, actorUid})),
];

function setup(t: TestContext, fixture: Fixture = {}) {
  let nowMs = START;
  const walls = fixture.walls ?? {w1: "a", w2: "b"};
  const gates: Record<string, CreatorGate> = fixture.gates ?? {a: "ok", b: "ok"};
  const sent: Sent[] = [];
  const store = installFakeDb(t, {
    "usersv2/a": {coins: 10, email: "a@example.com"},
    "usersv2/b": {coins: 0, email: "b@example.com"},
    ...fixture.seed,
  }, undefined, fixture.options);
  const rules: CreatorFundConfig = {...RULES, ...fixture.rules};
  t.mock.method(creatorFundIo, "now", () => nowMs);
  t.mock.method(creatorFundIo, "economy", async () => rules);
  t.mock.method(creatorFundIo, "events", async () => fixture.events ?? defaultEvents);
  t.mock.method(creatorFundIo, "census", async () => ({
    wallCreators: new Map(Object.entries(walls)),
    struck: new Set<string>(),
  }));
  t.mock.method(creatorFundIo, "gates", async () => {
    const result = {
      creatorGates: new Map<string, CreatorGate>(Object.entries(gates)),
      excludedActors: new Set<string>(),
    };
    fixture.afterCompute?.(store);
    return result;
  });
  t.mock.method(creatorFundIo, "sendToUser", async (payload: Sent["payload"], recipient: unknown, push: boolean) => {
    sent.push({payload, recipient, push});
    return true;
  });
  return {
    store,
    sent,
    advance: (ms: number) => {
      nowMs += ms;
    },
  };
}

const ledgers = (store: Map<string, Doc>) =>
  [...store.entries()].filter(([path, doc]) => path.startsWith("coinTransactions/") && doc.action === "creatorFund");

test("a week with no pool and no week doc is off and writes nothing", async (t) => {
  const {store} = setup(t, {rules: {pool: 0}, events: []});
  assert.equal(await settleCreatorFundWeek(WEEK), "off");
  assert.equal([...store.keys()].some((path) => path.startsWith("creatorFund")), false);
  assert.equal(ledgers(store).length, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("coinTransactions/")), false);
});

test("a happy run pays each creator once, writes the ledger and notifies", async (t) => {
  const {store, sent} = setup(t, {seed: {"usersv2/a/private/session": {postAlerts: false}}});
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");

  assert.equal(store.get("usersv2/a")?.coins, 35);
  assert.equal(store.get("usersv2/b")?.coins, 75);
  const ledgerA = store.get("coinTransactions/ctx_creatorFund_a_2026-W46");
  assert.equal(ledgerA?.userId, "a");
  assert.equal(ledgerA?.action, "creatorFund");
  assert.equal(ledgerA?.delta, 25);
  assert.equal(ledgerA?.balanceBefore, 10);
  assert.equal(ledgerA?.balanceAfter, 35);
  assert.equal(ledgerA?.week, WEEK);
  assert.equal(store.get("coinTransactions/ctx_creatorFund_b_2026-W46")?.balanceAfter, 75);
  assert.equal(ledgers(store).length, 2);

  const week = store.get(WEEK_PATH);
  assert.equal(week?.state, "complete");
  assert.equal(week?.coinsPaid, 100);
  assert.equal(week?.paidCreators, 2);
  assert.equal(store.get(`${WEEK_PATH}/creators/a`)?.payState, "done");
  assert.equal(store.get(`${WEEK_PATH}/creators/b`)?.payState, "done");
  assert.equal(store.get(`${WEEK_PATH}/creators/a`)?.noticeState, "sent");

  assert.equal(sent.length, 2);
  const toA = sent.find((s) => s.payload.docId === "creator_fund_a_2026-W46");
  const toB = sent.find((s) => s.payload.docId === "creator_fund_b_2026-W46");
  assert.equal(toA?.payload.title, "You earned 25 coins from the Creator fund");
  assert.equal(toA?.push, false);
  assert.equal(toB?.payload.title, "You earned 75 coins from the Creator fund");
  assert.equal(toB?.push, true);
});

test("running a complete week again pays nothing", async (t) => {
  const {store, sent} = setup(t);
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  const balances = [store.get("usersv2/a")?.coins, store.get("usersv2/b")?.coins];
  const ledgerCount = ledgers(store).length;
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.deepEqual([store.get("usersv2/a")?.coins, store.get("usersv2/b")?.coins], balances);
  assert.equal(ledgers(store).length, ledgerCount);
  assert.equal(sent.length, 2);
});

test("a crash in the middle of payout resumes and pays every creator exactly once", async (t) => {
  const creators = Array.from({length: 150}, (_, i) => `c${String(i).padStart(3, "0")}`);
  const seed = Object.fromEntries(creators.map((uid) => [`usersv2/${uid}`, {coins: 0, email: `${uid}@example.com`}]));
  const walls = Object.fromEntries(creators.map((uid, i) => [`w${i}`, uid]));
  const gates = Object.fromEntries(creators.map((uid) => [uid, "ok" as const])) as Record<string, CreatorGate>;
  const events: FundEvent[] = creators.map((_, i) => ({wallId: `w${i}`, metric: "saves", actorUid: "fan"}));
  const {store, sent, advance} = setup(t, {
    rules: {pool: 15000, minDistinctUsers: 1},
    walls,
    gates,
    events,
    seed,
    options: {failCommitAt: 4},
  });

  await assert.rejects(settleCreatorFundWeek(WEEK), /injected transaction commit failure/);
  assert.equal(store.get(WEEK_PATH)?.state, "paying");
  assert.equal(ledgers(store).length, 100);

  advance(601_000);
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");

  for (const uid of creators) assert.equal(store.get(`usersv2/${uid}`)?.coins, 100);
  assert.equal(ledgers(store).length, 150);
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 15000);
  assert.equal(store.get(WEEK_PATH)?.paidCreators, 150);
  assert.equal(sent.length, 150);
  assert.equal(new Set(sent.map((s) => s.payload.docId)).size, 150);
});

test("a due row whose ledger already exists is marked done without paying again", async (t) => {
  const ledgerDoc = {
    id: "ctx_creatorFund_a_2026-W46",
    userId: "a",
    delta: 25,
    balanceBefore: 10,
    balanceAfter: 35,
    action: "creatorFund",
    week: WEEK,
  };
  const {store, sent} = setup(t, {
    seed: {
      [WEEK_PATH]: {state: "paying", rules: RULES, pool: 100, coinsPaid: 25, paidCreators: 1,
        lease: {token: "dead", until: ts(START - 1000)}},
      [`${WEEK_PATH}/creators/a`]: {status: "paid", coins: 25, payState: "due", noticeState: "due", scoreCenti: 500,
        distinctUsers: 5, capped: false, shareBps: 2500},
      [`${WEEK_PATH}/creators/b`]: {status: "paid", coins: 75, payState: "due", scoreCenti: 1500,
        distinctUsers: 5, capped: false, shareBps: 7500},
      "usersv2/a": {coins: 35, email: "a@example.com"},
      "coinTransactions/ctx_creatorFund_a_2026-W46": ledgerDoc,
    },
  });
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.get("usersv2/a")?.coins, 35);
  assert.equal(store.get("usersv2/b")?.coins, 75);
  assert.equal(store.get(`${WEEK_PATH}/creators/a`)?.payState, "done");
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 100);
  assert.deepEqual(sent.map((s) => s.payload.docId).sort(),
    ["creator_fund_a_2026-W46", "creator_fund_b_2026-W46"]);
});

test("a crashed compute starts over and drops rows from the earlier attempt", async (t) => {
  const {store} = setup(t, {
    seed: {
      [WEEK_PATH]: {state: "computing", rules: RULES, pool: 100, coinsPaid: 0, paidCreators: 0,
        lease: {token: "dead", until: ts(START - 1000)}},
      [`${WEEK_PATH}/creators/ghost`]: {status: "paid", coins: 50, payState: "due", scoreCenti: 900,
        distinctUsers: 9, capped: false, shareBps: 5000},
    },
  });
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.has(`${WEEK_PATH}/creators/ghost`), false);
  const rows = [...store.keys()].filter((path) => path.startsWith(`${WEEK_PATH}/creators/`)).sort();
  assert.deepEqual(rows, [`${WEEK_PATH}/creators/a`, `${WEEK_PATH}/creators/b`]);
  assert.equal(store.get("usersv2/a")?.coins, 35);
  assert.equal(store.get("usersv2/b")?.coins, 75);
});

test("a live lease held by another run makes this run return busy and change nothing", async (t) => {
  const {store, sent} = setup(t, {
    seed: {
      [WEEK_PATH]: {state: "paying", rules: RULES, pool: 100, coinsPaid: 0, paidCreators: 0,
        lease: {token: "other-run", until: ts(START + 60_000)}},
    },
  });
  const before = store.get(WEEK_PATH);
  assert.equal(await settleCreatorFundWeek(WEEK), "busy");
  assert.equal(store.get(WEEK_PATH), before);
  assert.equal((store.get(WEEK_PATH)?.lease as {token: string}).token, "other-run");
  assert.equal([...store.keys()].some((path) => path.startsWith(`${WEEK_PATH}/creators/`)), false);
  assert.equal(ledgers(store).length, 0);
  assert.equal(sent.length, 0);
});

test("a creator deleted between compute and payout is voided and not paid", async (t) => {
  const {store, sent} = setup(t, {
    afterCompute: (db) => db.set("usersv2/b", {coins: 0, email: "b@example.com", deleted: true}),
  });
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.get(`${WEEK_PATH}/creators/b`)?.payState, "void");
  assert.equal(store.get("usersv2/b")?.coins, 0);
  assert.equal(store.has("coinTransactions/ctx_creatorFund_b_2026-W46"), false);
  assert.equal(store.get("usersv2/a")?.coins, 35);
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 25);
  assert.deepEqual(sent.map((s) => s.payload.docId), ["creator_fund_a_2026-W46"]);
});
