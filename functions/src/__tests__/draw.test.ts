import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {buyDrawTicket, drawIo, nextCloseMs, pickWinner, runSettleDraw} from "../draw";
import {resetEconomyCache, weekKey} from "../economy";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 14, 12);
const KEY = weekKey(NOW);
const CLOSES = Date.UTC(2026, 9, 19);
const SETTLE_AT = Date.UTC(2026, 9, 19, 0, 10);
const LAST_KEY = weekKey(SETTLE_AT - 86_400_000);
const NEW_KEY = weekKey(SETTLE_AT);

function setup(t: TestContext, seed: Record<string, Doc> = {}, enabled = true) {
  resetEconomyCache();
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  return installFakeDb(t, {
    "economyConfig/current": {flags: {drawEnabled: enabled}},
    "usersv2/u1": {coins: 100},
    ...seed,
  });
}

const buy = (uid: string, requestId = "req-00000001") => buyDrawTicket.run({
  auth: {uid, token: {}}, data: {requestId},
} as unknown as Parameters<typeof buyDrawTicket.run>[0]) as Promise<Record<string, unknown>>;

test("nextCloseMs is the next Monday 00:00 UTC", () => {
  assert.equal(nextCloseMs(NOW), CLOSES);
  assert.equal(nextCloseMs(CLOSES), Date.UTC(2026, 9, 26));
  assert.equal(nextCloseMs(CLOSES - 1), CLOSES);
});

test("pickWinner follows the ticket weights with a fixed random", () => {
  const tickets = [{uid: "b", count: 3}, {uid: "a", count: 1}, {uid: "c", count: 0}];
  assert.equal(pickWinner(tickets, () => 0.1), "a");
  assert.equal(pickWinner(tickets, () => 0.5), "b");
  assert.equal(pickWinner(tickets, () => 0.99), "b");
  assert.equal(pickWinner([], () => 0.5), null);
  assert.equal(pickWinner([{uid: "a", count: 0}], () => 0.5), null);
});

test("buying is refused while the draw flag is off", async (t) => {
  const store = setup(t, {}, false);
  const result = await buy("u1");
  assert.equal(result.success, false);
  assert.equal(result.reason, "draw_disabled");
  assert.equal(store.get("usersv2/u1")?.coins, 100);
  assert.equal(store.has(`draws/${KEY}`), false);
});

test("the first ticket creates the draw, debits, and stores the ticket and the transaction", async (t) => {
  const store = setup(t);
  const result = await buy("u1");
  assert.equal(result.success, true);
  assert.equal(result.changed, true);
  assert.equal(result.tickets, 1);
  assert.equal(result.weekKey, KEY);
  assert.equal(result.closesAt, CLOSES);
  assert.equal(result.previousBalance, 100);
  assert.equal(result.currentBalance, 80);
  assert.equal(result.delta, -20);
  assert.equal(result.transactionId, "ctx_draw_u1_req-00000001");
  assert.equal(store.get("usersv2/u1")?.coins, 80);
  assert.deepEqual(store.get(`draws/${KEY}`), {
    weekKey: KEY, status: "open", closesAt: CLOSES, tickets: 1, participants: 1,
    prize: {proMonths: 1, itemId: "frame_prism"},
  });
  assert.deepEqual(store.get(`drawTickets/${KEY}_u1`), {weekKey: KEY, uid: "u1", count: 1});
  const txDoc = store.get("coinTransactions/ctx_draw_u1_req-00000001");
  assert.equal(txDoc?.action, "drawTicket");
  assert.equal(txDoc?.reason, `draw_${KEY}`);
  assert.equal(txDoc?.sourceTag, "draw.ticket.callable");
  assert.equal(txDoc?.delta, -20);
});

test("more tickets add to the pot, and participants grow only for a new holder", async (t) => {
  const store = setup(t, {"usersv2/u2": {coins: 100}});
  await buy("u1", "req-00000001");
  await buy("u1", "req-00000002");
  const other = await buy("u2", "req-00000003");
  assert.equal(other.tickets, 1);
  assert.equal(store.get(`draws/${KEY}`)?.tickets, 3);
  assert.equal(store.get(`draws/${KEY}`)?.participants, 2);
  assert.equal(store.get(`drawTickets/${KEY}_u1`)?.count, 2);
  assert.equal(store.get("usersv2/u1")?.coins, 60);
});

test("a sixth ticket in a week is refused and costs nothing", async (t) => {
  const store = setup(t, {"usersv2/u1": {coins: 500}});
  for (let i = 1; i <= 5; i += 1) await buy("u1", `req-0000000${i}`);
  const result = await buy("u1", "req-00000006");
  assert.equal(result.success, false);
  assert.equal(result.reason, "draw_ticket_limit");
  assert.equal(store.get("usersv2/u1")?.coins, 400);
  assert.equal(store.get(`drawTickets/${KEY}_u1`)?.count, 5);
  assert.equal(store.has("coinTransactions/ctx_draw_u1_req-00000006"), false);
});

test("a replayed request returns the stored result and charges once", async (t) => {
  const store = setup(t);
  await buy("u1", "req-00000001");
  const again = await buy("u1", "req-00000001");
  assert.equal(again.success, true);
  assert.equal(again.tickets, 1);
  assert.equal(again.weekKey, KEY);
  assert.equal(again.closesAt, CLOSES);
  assert.equal(again.delta, -20);
  assert.equal(again.transactionId, "ctx_draw_u1_req-00000001");
  assert.equal(store.get("usersv2/u1")?.coins, 80);
  assert.equal(store.get(`draws/${KEY}`)?.tickets, 1);
});

test("a short balance is refused without a debit", async (t) => {
  const store = setup(t, {"usersv2/u1": {coins: 19}});
  const result = await buy("u1");
  assert.equal(result.success, false);
  assert.equal(result.insufficientBalance, true);
  assert.equal(result.reason, "drawTicket_insufficient_balance");
  assert.equal(store.get("usersv2/u1")?.coins, 19);
  assert.equal(store.has(`draws/${KEY}`), false);
});

test("a settled or expired draw takes no tickets", async (t) => {
  const store = setup(t, {[`draws/${KEY}`]: {weekKey: KEY, status: "settled", closesAt: CLOSES, tickets: 1}});
  assert.equal((await buy("u1")).reason, "draw_closed");
  store.set(`draws/${KEY}`, {weekKey: KEY, status: "open", closesAt: NOW - 1, tickets: 1});
  assert.equal((await buy("u1", "req-00000002")).reason, "draw_closed");
  assert.equal(store.get("usersv2/u1")?.coins, 100);
});

test("a premium user cannot buy a ticket", async (t) => {
  const store = setup(t, {"usersv2/u1": {coins: 100, premium: true}});
  const result = await buy("u1");
  assert.equal(result.success, false);
  assert.equal(result.reason, "draw_pro_not_eligible");
  assert.equal(store.get("usersv2/u1")?.coins, 100);
  assert.equal(store.has(`draws/${KEY}`), false);
});

test("a bad requestId and a missing sign-in are refused", async (t) => {
  setup(t);
  await assert.rejects(() => buy("u1", "short"), {code: "invalid-argument"});
  await assert.rejects(() => buyDrawTicket.run({data: {requestId: "req-00000001"}} as unknown as
    Parameters<typeof buyDrawTicket.run>[0]), {code: "unauthenticated"});
});

function settleSeed(extra: Doc = {}): Record<string, Doc> {
  return {
    [`draws/${LAST_KEY}`]: {
      weekKey: LAST_KEY, status: "open", closesAt: SETTLE_AT - 600_000, tickets: 4, participants: 2,
      prize: {proMonths: 1, itemId: "frame_prism"}, ...extra,
    },
    [`drawTickets/${LAST_KEY}_a`]: {weekKey: LAST_KEY, uid: "a", count: 1},
    [`drawTickets/${LAST_KEY}_b`]: {weekKey: LAST_KEY, uid: "b", count: 3},
    [`drawTickets/${NEW_KEY}_a`]: {weekKey: NEW_KEY, uid: "a", count: 5},
    "usersv2/a": {name: "Ann", email: "ann@example.com"},
    "usersv2/b": {name: "", username: "bea", email: "bea@example.com"},
  };
}

function mockIo(t: TestContext, options: {proFails?: boolean} = {}) {
  const calls = {pro: [] as string[], starts: [] as number[], notified: [] as string[], modifiers: [] as string[]};
  const state = {proFails: options.proFails ?? false};
  t.mock.method(drawIo, "grantPro", async (uid: string, startMs: number) => {
    calls.pro.push(uid);
    calls.starts.push(startMs);
    if (state.proFails) throw new Error("RevenueCat answered 500");
  });
  t.mock.method(drawIo, "notify", async (payload: {modifier: string}, recipient: {uid: string}) => {
    calls.notified.push(recipient.uid);
    calls.modifiers.push(payload.modifier);
    return true;
  });
  return Object.assign(calls, {state});
}

test("settling picks the weighted winner, writes the prize and notifies once", async (t) => {
  const store = setup(t, settleSeed());
  const calls = mockIo(t);
  await runSettleDraw(SETTLE_AT, () => 0.5);
  const draw = store.get(`draws/${LAST_KEY}`);
  assert.equal(draw?.status, "settled");
  assert.equal(draw?.winnerUid, "b");
  assert.equal(draw?.winnerName, "bea");
  assert.equal(draw?.settledAt, SETTLE_AT);
  assert.equal(draw?.prizeItemGranted, true);
  assert.equal(draw?.prizeProGranted, true);
  assert.equal(draw?.winnerNotified, true);
  assert.equal(draw?.prizeGrantError, undefined);
  assert.deepEqual(store.get("usersv2/b/private/economy"), {rev: 1, inventory: {owned: {frame_prism: SETTLE_AT}}});
  assert.deepEqual(calls.pro, ["b"]);
  assert.deepEqual(calls.notified, ["b"]);
  assert.equal(store.get(`draws/${NEW_KEY}`), undefined);
});

test("the same ticket odds pick the other holder with a low roll", async (t) => {
  const store = setup(t, settleSeed());
  mockIo(t);
  await runSettleDraw(SETTLE_AT, () => 0.1);
  assert.equal(store.get(`draws/${LAST_KEY}`)?.winnerUid, "a");
  assert.equal(store.get(`draws/${LAST_KEY}`)?.winnerName, "Ann");
});

test("the item joins the owned map and bumps rev on an existing economy doc", async (t) => {
  const store = setup(t, {
    ...settleSeed(),
    "usersv2/b/private/economy": {rev: 4, inventory: {owned: {glow_ember: 7}}},
  });
  mockIo(t);
  await runSettleDraw(SETTLE_AT, () => 0.5);
  assert.deepEqual(store.get("usersv2/b/private/economy"), {
    rev: 5, inventory: {owned: {glow_ember: 7, frame_prism: SETTLE_AT}},
  });
});

test("settling again changes and grants nothing", async (t) => {
  const store = setup(t, settleSeed());
  const calls = mockIo(t);
  await runSettleDraw(SETTLE_AT, () => 0.5);
  const before = JSON.stringify(store.get(`draws/${LAST_KEY}`));
  await runSettleDraw(SETTLE_AT + 3_600_000, () => 0.1);
  assert.equal(JSON.stringify(store.get(`draws/${LAST_KEY}`)), before);
  assert.deepEqual(calls.pro, ["b"]);
  assert.deepEqual(calls.notified, ["b"]);
  assert.equal(store.get("usersv2/b/private/economy")?.rev, 1);
});

test("settlement counts the ticket docs, not the draw counters", async (t) => {
  const store = setup(t, settleSeed({tickets: 0, participants: 0}));
  mockIo(t);
  await runSettleDraw(SETTLE_AT, () => 0.5);
  assert.equal(store.get(`draws/${LAST_KEY}`)?.winnerUid, "b");
});

test("a draw with no ticket docs is left alone", async (t) => {
  const store = setup(t, {
    [`draws/${LAST_KEY}`]: {weekKey: LAST_KEY, status: "open", closesAt: SETTLE_AT, tickets: 3, participants: 1},
  });
  const calls = mockIo(t);
  await runSettleDraw(SETTLE_AT, () => 0.5);
  assert.equal(store.get(`draws/${LAST_KEY}`)?.status, "open");
  assert.deepEqual(calls.pro, []);
});

test("a RevenueCat failure keeps the item, records the error, and a later run finishes the rest", async (t) => {
  const store = setup(t, settleSeed());
  const calls = mockIo(t, {proFails: true});
  await runSettleDraw(SETTLE_AT, () => 0.5);
  let draw = store.get(`draws/${LAST_KEY}`);
  assert.equal(draw?.status, "settled");
  assert.equal(draw?.winnerUid, "b");
  assert.equal(draw?.prizeItemGranted, true);
  assert.equal(draw?.prizeProGranted, undefined);
  assert.equal(draw?.winnerNotified, undefined);
  assert.match(String(draw?.prizeGrantError), /prizeProGranted: RevenueCat answered 500/);
  assert.deepEqual(calls.notified, []);

  calls.state.proFails = false;
  await runSettleDraw(SETTLE_AT + 7 * 86_400_000, () => 0.1);
  draw = store.get(`draws/${LAST_KEY}`);
  assert.equal(draw?.winnerUid, "b");
  assert.equal(draw?.prizeProGranted, true);
  assert.equal(draw?.winnerNotified, true);
  assert.equal(draw?.prizeGrantError, undefined);
  assert.deepEqual(calls.pro, ["b", "b"]);
  assert.deepEqual(calls.starts, [SETTLE_AT, SETTLE_AT]);
  assert.equal(draw?.prizeProStartMs, SETTLE_AT);
  assert.deepEqual(calls.notified, ["b"]);
  assert.equal(store.get("usersv2/b/private/economy")?.rev, 1);
});

test("the winner notice goes to the inbox by email", async (t) => {
  const calls = mockIo(t);
  setup(t, settleSeed());
  await runSettleDraw(SETTLE_AT, () => 0.5);
  assert.deepEqual(calls.modifiers, ["bea@example.com"]);
});

test("a winner with no email gets the notice by uid", async (t) => {
  const calls = mockIo(t);
  setup(t, {...settleSeed(), "usersv2/b": {name: "Bea"}});
  await runSettleDraw(SETTLE_AT, () => 0.5);
  assert.deepEqual(calls.modifiers, ["b"]);
});

test("grantPro asks RevenueCat for one month from the stored start", async (t) => {
  process.env.REVENUECAT_SECRET_KEY = "test_key";
  t.after(() => delete process.env.REVENUECAT_SECRET_KEY);
  const sent: Array<{url: string; body: unknown}> = [];
  t.mock.method(globalThis, "fetch", async (url: string, init: {body: string}) => {
    sent.push({url, body: JSON.parse(init.body)});
    return new Response("{}", {status: 201});
  });
  await drawIo.grantPro("b", 1234);
  assert.deepEqual(sent, [{
    url: "https://api.revenuecat.com/v1/subscribers/b/entitlements/prism_v3_pro_access/promotional",
    body: {duration: "monthly", start_time_ms: 1234},
  }]);
});
