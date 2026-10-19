import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {DEFAULT_ECONOMY, resetEconomyCache} from "../economy";
import {giftIo, giftPremiumPass} from "../gifts";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");
const DAY = 86_400_000;
const REQ = "request_0001";
const PRICE = DEFAULT_ECONOMY.spend.giftPremiumPass;
const WEEK = 7 * DAY;

function setup(t: TestContext, seed: Record<string, Doc> = {}) {
  resetEconomyCache();
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  t.mock.method(giftIo, "accountCreatedMs", async () => NOW.getTime() - WEEK);
  const sent: Array<{ payload: unknown; recipient: unknown }> = [];
  t.mock.method(
    giftIo,
    "notify",
    async (payload: unknown, recipient: unknown) => {
      sent.push({payload, recipient});
      return true;
    },
  );
  const store = installFakeDb(t, {
    "usersv2/u1": {coins: 200, name: "Asha", username: "asha"},
    "usersv2/u2": {coins: 0, email: "friend@example.com"},
    ...seed,
  });
  return {store, sent};
}

const run = (data: Record<string, unknown>, uid = "u1") =>
  giftPremiumPass.run({auth: {uid, token: {}}, data} as never);

test("giftPremiumPass validates its input", async (t) => {
  setup(t);
  await assert.rejects(
    run({recipientUid: "u1", requestId: REQ}),
    (err: HttpsError) =>
      err.code === "invalid-argument" && err.message === "gift_self",
  );
  await assert.rejects(run({recipientUid: "", requestId: REQ}), {
    code: "invalid-argument",
  });
  await assert.rejects(run({recipientUid: "u2", requestId: "x"}), {
    code: "invalid-argument",
  });
  await assert.rejects(
    giftPremiumPass.run({
      data: {recipientUid: "u2", requestId: REQ},
    } as never),
    {code: "unauthenticated"},
  );
});

test("giftPremiumPass refuses a missing or deleted recipient", async (t) => {
  const {store, sent} = setup(t, {
    "usersv2/gone": {coins: 0, deleted: true},
  });
  for (const recipientUid of ["nobody", "gone"]) {
    await assert.rejects(
      run({recipientUid, requestId: REQ}),
      (err: HttpsError) =>
        err.code === "not-found" && err.message === "gift_recipient_not_found",
    );
  }
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(sent.length, 0);
});

test("giftPremiumPass refuses when the balance is short", async (t) => {
  const {store, sent} = setup(t, {"usersv2/u1": {coins: PRICE - 1}});
  const result = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(result.success, false);
  assert.equal(result.insufficientBalance, true);
  assert.equal(result.reason, "giftPremiumPass_insufficient_balance");
  assert.equal(store.get("usersv2/u1")?.coins, PRICE - 1);
  assert.equal(sent.length, 0);
});

test("giftPremiumPass debits the sender, writes the recipient pass and notifies once", async (t) => {
  const {store, sent} = setup(t);
  const result = await run({recipientUid: "u2", requestId: REQ});
  const expiresAt = NOW.getTime() + DAY;
  assert.equal(result.success, true);
  assert.equal(result.expiresAt, expiresAt);
  assert.equal(result.previousBalance, 200);
  assert.equal(result.currentBalance, 200 - PRICE);
  assert.equal(result.delta, -PRICE);
  assert.equal(result.transactionId, `ctx_gift_u1_${REQ}`);
  assert.equal(store.get("usersv2/u1")?.coins, 200 - PRICE);
  assert.equal(store.get("usersv2/u2")?.coins, 0);
  const economy = store.get("usersv2/u2/private/economy");
  assert.deepEqual(economy?.passes, {premiumPassUntil: expiresAt});
  assert.equal(economy?.rev, 1);
  const ledger = store.get(`coinTransactions/ctx_gift_u1_${REQ}`);
  assert.equal(ledger?.action, "giftPremiumPass");
  assert.equal(ledger?.reason, "gift_to_u2");
  assert.equal(ledger?.sourceTag, "gifts.pass.callable");
  assert.equal(ledger?.description, "Gift: 24 h Pro pass");
  assert.equal(store.get("giftRateDaily/u1_2026-01-10")?.count, 1);
  assert.deepEqual(sent, [
    {
      payload: {
        title: "Asha sent you a 24-hour Pro pass",
        body: "Premium collections and premium walls are open until tomorrow.",
        message: {
          kind: "giftReceived",
          args: {senderName: "Asha"},
          title: "Asha sent you a 24-hour Pro pass",
          body: "Premium collections and premium walls are open until tomorrow.",
        },
        data: {route: "rewards"},
        modifier: "friend@example.com",
        channelId: "gifts",
        docId: `gift_u1_${REQ}`,
      },
      recipient: {uid: "u2", email: "friend@example.com"},
    },
  ]);
});

test("a gift to a recipient with no email falls back to the uid as the inbox modifier", async (t) => {
  const {sent} = setup(t, {"usersv2/u2": {coins: 0}});
  await run({recipientUid: "u2", requestId: REQ});
  assert.equal((sent[0].payload as { modifier: string }).modifier, "u2");
  assert.deepEqual(sent[0].recipient, {uid: "u2", email: ""});
});

test("a gift sets the pass to 24 h from now, never longer, and keeps the other passes and the rev", async (t) => {
  const until = NOW.getTime() + 5 * 3_600_000;
  const {store} = setup(t, {
    "usersv2/u2/private/economy": {
      rev: 4,
      passes: {premiumPassUntil: until, autoRotatePassUntil: 77},
    },
  });
  const result = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(result.expiresAt, NOW.getTime() + DAY);
  const economy = store.get("usersv2/u2/private/economy");
  assert.deepEqual(economy?.passes, {
    premiumPassUntil: NOW.getTime() + DAY,
    autoRotatePassUntil: 77,
  });
  assert.equal(economy?.rev, 5);
});

test("giftPremiumPass refuses a premium recipient, a recipient who blocked the sender and a second gift a day", async (t) => {
  const {store, sent} = setup(t, {
    "usersv2/pro": {coins: 0, premium: true},
    "usersv2/blocker": {coins: 0},
    "usersv2/blocker/blockedUsers/u1": {blockedAt: 1},
    "usersv2/u3": {coins: 0},
    "giftRateDaily/recv_u3_2026-01-10": {day: "2026-01-10", count: 1},
  });
  const reasons: Record<string, string> = {
    pro: "gift_recipient_premium",
    blocker: "gift_blocked",
    u3: "gift_recipient_limit",
  };
  for (const [recipientUid, reason] of Object.entries(reasons)) {
    const result = await run({recipientUid, requestId: REQ});
    assert.equal(result.success, false);
    assert.equal(result.reason, reason);
  }
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(sent.length, 0);
});

test("a gift marks the recipient as gifted for the day", async (t) => {
  const {store} = setup(t);
  await run({recipientUid: "u2", requestId: REQ});
  assert.equal(store.get("giftRateDaily/recv_u2_2026-01-10")?.count, 1);
  const again = await run({recipientUid: "u2", requestId: "request_0002"});
  assert.equal(again.reason, "gift_recipient_limit");
});

test("giftPremiumPass refuses a sender account younger than 7 days", async (t) => {
  const {store, sent} = setup(t);
  t.mock.method(
    giftIo,
    "accountCreatedMs",
    async () => NOW.getTime() - WEEK + 1,
  );
  const result = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(result.success, false);
  assert.equal(result.reason, "gift_sender_too_new");
  assert.equal(store.get("usersv2/u1")?.coins, 200);
  assert.equal(sent.length, 0);
});

test("the sender name falls back to the username, then to a default", async (t) => {
  const first = setup(t, {"usersv2/u1": {coins: 200, username: "asha"}});
  await run({recipientUid: "u2", requestId: REQ});
  assert.equal(
    (first.sent[0].payload as { title: string }).title,
    "asha sent you a 24-hour Pro pass",
  );
});

test("the sender name defaults to A Prism user", async (t) => {
  const {sent} = setup(t, {"usersv2/u1": {coins: 200}});
  await run({recipientUid: "u2", requestId: REQ});
  assert.equal(
    (sent[0].payload as { title: string }).title,
    "A Prism user sent you a 24-hour Pro pass",
  );
});

test("a replay returns the stored result, charges once and does not notify again", async (t) => {
  const {store, sent} = setup(t);
  const first = await run({recipientUid: "u2", requestId: REQ});
  const replay = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(replay.success, true);
  assert.equal(replay.expiresAt, first.expiresAt);
  assert.equal(replay.currentBalance, 200 - PRICE);
  assert.equal(store.get("usersv2/u1")?.coins, 200 - PRICE);
  assert.equal(store.get("giftRateDaily/u1_2026-01-10")?.count, 1);
  assert.equal(sent.length, 1);
});

test("a sender may gift 3 passes a UTC day", async (t) => {
  const {store, sent} = setup(t, {
    "usersv2/u1": {coins: 1000},
    "giftRateDaily/u1_2026-01-10": {day: "2026-01-10", count: 3},
  });
  const result = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(result.success, false);
  assert.equal(result.reason, "gift_daily_limit");
  assert.equal(store.get("usersv2/u1")?.coins, 1000);
  assert.equal(store.has("usersv2/u2/private/economy"), false);
  assert.equal(sent.length, 0);
});

test("the daily count from another day does not block a gift", async (t) => {
  const {store} = setup(t, {
    "giftRateDaily/u1_2026-01-10": {day: "2026-01-09", count: 3},
  });
  const result = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(result.success, true);
  assert.equal(store.get("giftRateDaily/u1_2026-01-10")?.count, 1);
});

test("a failed notification does not fail the gift", async (t) => {
  const {store} = setup(t);
  t.mock.method(giftIo, "notify", async () => {
    throw new Error("fcm down");
  });
  const result = await run({recipientUid: "u2", requestId: REQ});
  assert.equal(result.success, true);
  assert.equal(store.get("usersv2/u1")?.coins, 200 - PRICE);
});
