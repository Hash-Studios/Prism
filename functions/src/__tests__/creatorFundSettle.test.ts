import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {type CreatorFundConfig, DEFAULT_ECONOMY} from "../economy";
import {computeCreatorFund, type CreatorGate, type FundEvent} from "../creatorFund/score";
import {fundEventWrite, fundWallStamp} from "../creatorFund/events";
import {db} from "../common";
import {computePage} from "../creatorFund/compute";
import {creatorFundIo, scheduledWeek, settleCreatorFundWeek} from "../creatorFund/settle";
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
  duringCompute?: (store: Map<string, Doc>) => void;
  afterCompute?: (store: Map<string, Doc>) => void;
};

const defaultEvents: FundEvent[] = [
  ...["f1", "f2", "f3", "f4", "f5"].map((actorUid) => ({wallId: "w1", metric: "saves" as const, actorUid})),
  ...["f1", "f2", "f3", "f4", "f5"].map((actorUid) => ({wallId: "w2", metric: "sets" as const, actorUid})),
];

function setup(t: TestContext, fixture: Fixture = {}) {
  let nowMs = START;
  const walls = fixture.walls ?? {w1: "a", w2: "b"};
  const events = fixture.events ?? defaultEvents;
  const sent: Sent[] = [];

  const store = installFakeDb(t, {
    "usersv2/a": {coins: 10, email: "a@example.com"},
    "usersv2/b": {coins: 0, email: "b@example.com"},
    ...Object.fromEntries(events.map(({actorUid}) => [`usersv2/${actorUid}`, {}])),
    ...Object.fromEntries(Object.entries(walls).map(([id, uid]) => [`walls/${id}`, {
      id: id.toUpperCase(), creatorUid: uid, review: true, wallpaper_provider: "prism",
    }])),
    ...fixture.seed,
  }, undefined, fixture.options);
  const rules: CreatorFundConfig = {...RULES, ...fixture.rules};
  t.mock.method(creatorFundIo, "now", () => nowMs);
  t.mock.method(creatorFundIo, "economy", async () => rules);
  for (const {wallId, actorUid, metric} of events) {
    const event = fundEventWrite(wallId.toUpperCase(), metric, actorUid, START - 86400000);
    store.set(event.ref.path, event.data);
  }
  t.mock.method(admin.auth(), "getUsers", async (ids: {uid: string}[]) => ({
    users: ids.map(({uid}) => ({uid, emailVerified: true, providerData: [{providerId: "password"}],
      metadata: {creationTime: new Date(0).toISOString()}})),
  }));
  const run = db.runTransaction.bind(db);
  let fired = false;
  t.mock.method(db, "runTransaction", (body: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    if (store.get(WEEK_PATH)?.phase === "events") fixture.duringCompute?.(store);
    if (!fired && store.get(WEEK_PATH)?.state === "paying") {
      fired = true; fixture.afterCompute?.(store);
    }
    return run(body);
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

  });

  const run = db.runTransaction.bind(db);
  let crash = true;
  t.mock.method(db, "runTransaction", (body: (tx: admin.firestore.Transaction) => Promise<unknown>) =>
    run(async (tx) => {
      const result = await body(tx);
      if (crash && ledgers(store).length === 75) {
        crash = false; throw new Error("injected transaction commit failure");
      }
      return result;
    }));
  await assert.rejects(settleCreatorFundWeek(WEEK), /injected transaction commit failure/);
  assert.equal(store.get(WEEK_PATH)?.state, "paying");
  assert.equal(ledgers(store).length, 75);

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

test("an existing week never depends on reading live config again", async (t) => {
  const {store} = setup(t, {seed: {[WEEK_PATH]: {state: "computing", rules: RULES, pool: 100}}});
  t.mock.method(creatorFundIo, "economy", () => {
    throw new Error("config unavailable");
  });
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 100);
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
});

test("a newly disabled creator and a creator held after compute receive no coins", async (t) => {
  const {store, sent} = setup(t, {afterCompute: (store) => {
    store.set("walls/reported", {creatorUid: "a", heldForReview: true, review: false});
  }});
  const getUsers = admin.auth().getUsers.bind(admin.auth());
  t.mock.method(admin.auth(), "getUsers", (ids: admin.auth.UserIdentifier[]) => store.get(WEEK_PATH)?.state === "paying" ?
    Promise.resolve({users: [{uid: "a"}, {uid: "b", disabled: true}]}) : getUsers(ids));
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 0);
  assert.equal(store.get(`${WEEK_PATH}/creators/a`)?.reason, "moderation");
  assert.equal(sent.length, 0);
});

test("an unsafe balance is never overwritten or recorded as a successful credit", async (t) => {
  const {store, advance} = setup(t, {seed: {"usersv2/a": {coins: Number.MAX_SAFE_INTEGER}}});
  await assert.rejects(settleCreatorFundWeek(WEEK), /Unsafe balance/);
  assert.equal(store.get("usersv2/a")?.coins, Number.MAX_SAFE_INTEGER);
  assert.equal(store.has("coinTransactions/ctx_creatorFund_a_2026-W46"), false);
  advance(601_000);
  store.set("usersv2/a", {coins: 10});
  await settleCreatorFundWeek(WEEK);
  assert.equal(store.get("usersv2/a")?.coins, 35);
});

test("a push failure leaves the paid creator's inbox item intact", async (t) => {
  const {store} = setup(t);
  t.mock.method(creatorFundIo, "sendToUser", async () => {
    throw new Error("push unavailable");
  });
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.get("notifications/creator_fund_a_2026-W46")?.modifier, "a@example.com");
});

test("notification work yields between recipients when the soft budget expires", async (t) => {
  const {store, advance} = setup(t);
  t.mock.method(creatorFundIo, "sendToUser", async () => {
    advance(241_000); return true;
  });
  assert.equal(await settleCreatorFundWeek(WEEK), "partial");
  assert.equal([...store.values()].filter((doc) => doc.noticeState === "due").length, 1);
});

test("a deletion barrier closed during compute prevents resurrecting the creator row", async (t) => {
  const {store} = setup(t, {duringCompute: (s) => s.set("creatorDeletionState/b", {closed: true})});
  await settleCreatorFundWeek(WEEK);
  assert.equal(store.has(`${WEEK_PATH}/creators/b`), false);
});


test("compute yields after a page and an hourly run resumes the same week after Monday", async (t) => {
  const {store, advance} = setup(t, {duringCompute: () => advance(241_000)});
  assert.equal(await settleCreatorFundWeek(WEEK), "partial");
  assert.equal(store.get(WEEK_PATH)?.state, "computing");
  assert.equal(ledgers(store).length, 0);
  assert.equal(await scheduledWeek(Date.UTC(2026, 10, 17)), WEEK);
  advance(601_000);
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 100);
  assert.equal(await scheduledWeek(Date.UTC(2026, 10, 17)), null);
});

test("a replacement wall cannot inherit engagement on an earlier wall with the same logical ID", async (t) => {
  const {store} = setup(t);
  const before = await db.doc("walls/w1").get();
  for (const [path, data] of store) {
    if (path.startsWith("creatorFundEvents/") && data.wallId === "W1") store.set(path, {...data, wallStamp: fundWallStamp(before)});
  }
  store.delete("walls/w1");
  store.set("walls/replacement", {...before.data(), creatorUid: "b"});
  await settleCreatorFundWeek(WEEK);
  assert.equal(store.get(`${WEEK_PATH}/creators/b`)?.scoreCenti, 1500);
});

test("a repaired due row uses the actual ledger amount and does not repeat an already claimed notice", async (t) => {
  const {store, sent} = setup(t, {seed: {
    [WEEK_PATH]: {state: "paying", rules: RULES, coinsPaid: 25, paidCreators: 1},
    [`${WEEK_PATH}/creators/a`]: {status: "paid", payState: "due", coins: 99},
    "coinTransactions/ctx_creatorFund_a_2026-W46": {delta: 25},
    "notifications/creator_fund_a_2026-W46": {modifier: "a@example.com"},
  }});
  await settleCreatorFundWeek(WEEK);
  assert.equal(store.get(`${WEEK_PATH}/creators/a`)?.coins, 25);
  assert.equal(sent.length, 0);
  assert.equal(store.get("usersv2/a")?.coins, 10);
});

test("a due batch that exceeds the remaining pool cannot change balances or ledger", async (t) => {
  const {store} = setup(t, {seed: {[WEEK_PATH]: {state: "paying", rules: RULES, coinsPaid: 99},
    [`${WEEK_PATH}/creators/a`]: {status: "paid", payState: "due", coins: 25}}});
  await assert.rejects(settleCreatorFundWeek(WEEK), /exceed the frozen pool/);
  assert.equal(store.get("usersv2/a")?.coins, 10);
  assert.equal(ledgers(store).length, 0);
});

test("paged allocation agrees with the pure engine across wall, actor, cap and 400-row boundaries", async (t) => {
  const walls: Record<string, string> = {};
  const events: FundEvent[] = [];
  const seed: Record<string, Doc> = {};
  for (let i = 0; i < 405; i++) {
    const uid = `c${i}`;
    seed[`usersv2/${uid}`] = {coins: 0};
    walls[`w${i}`] = uid;
    events.push({wallId: `w${i}`, actorUid: "fan", metric: "sets"});
  }
  for (let i = 0; i < 50; i++) {
    walls[`x${i}`] = "c0";
    events.push({wallId: `x${i}`, actorUid: "fan", metric: "saves"},
      {wallId: `x${i}`, actorUid: `actor${i}`, metric: "sets"});
  }
  const rules = {...RULES, minDistinctUsers: 2, maxUserSharePercent: 7, perCreatorCap: 23};
  const {store} = setup(t, {walls, events, rules, seed});
  const result = computeCreatorFund({events, wallCreators: new Map(Object.entries(walls)), excludedActors: new Set(),
    creatorGates: new Map(Object.values(walls).map((uid) => [uid, "ok"])), rules});
  assert.equal(await settleCreatorFundWeek(WEEK), "complete");
  assert.deepEqual(store.get(WEEK_PATH)?.totals, result.totals);
  for (const row of result.rows) {
    const actual = store.get(`${WEEK_PATH}/creators/${row.uid}`);
    for (const [key, value] of Object.entries(row)) assert.equal(actual?.[key], value, `${row.uid}.${key}`);
  }
  assert.equal([...store.keys()].some((p) => /\/fund(Index|Pairs)\//.test(p)), false);
});

for (const phase of ["clear", "walls", "events", "caps", "sum", "allocate", "prune", "paying", "notifying", "claim", "complete"]) {
  test(`lost commit acknowledgement at ${phase} resumes without duplicate coins, inbox or push`, async (t) => {
    const {store, sent, advance} = setup(t);
    const run = db.runTransaction.bind(db);
    let crash = true;
    t.mock.method(db, "runTransaction", async (body: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
      const value = await run(body);
      const week = store.get(WEEK_PATH);
      const current = week?.phase ?? (week?.state === "computing" ? "clear" :
        week?.state === "notifying" && store.has("notifications/creator_fund_a_2026-W46") ? "claim" : week?.state);
      if (crash && current === phase) {
        crash = false; throw new Error("lost ack");
      }
      return value;
    });
    await assert.rejects(settleCreatorFundWeek(WEEK), /lost ack/);
    advance(601_000);
    assert.equal(await settleCreatorFundWeek(WEEK), "complete");
    assert.equal(ledgers(store).length, 2);
    assert.equal(store.get(WEEK_PATH)?.coinsPaid, 100);
    assert.equal(store.get("usersv2/a")?.coins, 35);
    assert.equal(store.get("usersv2/b")?.coins, 75);
    assert.equal([...store.keys()].filter((p) => p.startsWith("notifications/")).length, 2);
    assert.equal(new Set(sent.map(({payload}) => payload.docId)).size, sent.length);
  });
}

test("a duplicate ledger payload under a different key never contributes twice", async (t) => {
  const {store} = setup(t, {seed: {"creatorFundEvents/not-the-server-id": {wallId: "W1", actorUid: "f1", metric: "saves", week: WEEK}}});
  await settleCreatorFundWeek(WEEK);
  assert.equal(store.get(`${WEEK_PATH}/creators/a`)?.scoreCenti, 500);
  assert.equal(store.get("usersv2/a")?.coins, 35);
});

test("two overlapping invocations acquire one lease, pay once and notify once", async (t) => {
  const {store, sent} = setup(t);
  assert.deepEqual((await Promise.all([settleCreatorFundWeek(WEEK), settleCreatorFundWeek(WEEK)])).sort(), ["busy", "complete"]);
  assert.equal(store.get(WEEK_PATH)?.coinsPaid, 100);
  assert.equal(sent.length, 2);
});

test("an expired or replaced compute lease cannot clear pending rows", async (t) => {
  const {store} = setup(t, {seed: {[WEEK_PATH]: {state: "computing", rules: RULES, lease: {until: ts(START), token: "a"}},
    [`${WEEK_PATH}/creators/ghost`]: {coins: 40}}});
  const ref = db.doc(WEEK_PATH);
  await assert.rejects(computePage(ref, "a", RULES, () => START), /lease lost/);
  await assert.rejects(computePage(ref, "b", RULES, () => START - 10), /lease lost/);
  assert.ok(store.has(`${WEEK_PATH}/creators/ghost`));
});

test("a normalized-only action on an old mixed-case ID requires an unchanged wall at event time", async (t) => {
  const {store} = setup(t, {events: [], rules: {minDistinctUsers: 1}});
  store.set("usersv2/fan", {});
  store.set("walls/w1", {id: " wOnE ", creatorUid: "a", review: true, wallpaper_provider: "prism"});
  store.set("walls/w2", {id: " tWo ", creatorUid: "b", review: true, wallpaper_provider: "prism"});
  for (const [id, at] of [["WONE", START - 86400000], ["TWO", START - 86400000]] as const) {
    const event = fundEventWrite(id, "sets", "fan", at);
    store.set(event.ref.path, {...event.data, resolveAt: at});
  }
  // Firestore's updateTime is server-owned. The fake versions are milliseconds 0, 1, ... .
  const changed = fundEventWrite("TWO", "sets", "fan", START - 86400000);
  store.set(changed.ref.path, {...changed.data, resolveAt: 0});
  await db.doc("walls/w2").update({title: "changed"});
  await settleCreatorFundWeek(WEEK);
  assert.equal(store.get("usersv2/a")?.coins, 110);
  assert.equal(store.get("usersv2/b")?.coins, 0);
});

test("settlement refuses to allocate from a partially expired event ledger", async (t) => {
  const {store, advance} = setup(t);
  advance(63 * 86400000);
  await assert.rejects(settleCreatorFundWeek(WEEK), /source events may have expired/);
  assert.equal(ledgers(store).length, 0);
  assert.equal(store.get(WEEK_PATH)?.state, "computing");
});

test("a failed older week cannot monopolize every hourly continuation", async (t) => {
  setup(t, {seed: {
    "creatorFund/2026-W44": {state: "computing", lease: {until: ts(START + 600000)}},
    "creatorFund/2026-W45": {state: "paying", lease: {until: ts(START - 1)}},
  }});
  assert.equal(await scheduledWeek(Date.UTC(2026, 10, 17)), "2026-W45");
});
