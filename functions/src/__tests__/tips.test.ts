import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {db} from "../common";
import {refundableDelta} from "../coinsCallables";
import {readCreatorStats} from "../creatorStats";
import {hash} from "../creatorStatsHistory";
import {nativeNotificationLocalization, renderNotificationCopy} from "../notificationCatalog";
import {TIP_COINS_RECEIVED_PER_DAY, TIPS_SENT_PER_DAY, tipCreator, tipIo} from "../tips";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = new Date("2026-10-28T12:00:00Z");
const DAY = 86_400_000;
const WEEK = 7 * DAY;
const REQ = "request_0001";

type Sent = {payload: {title: string; body: string; message: {kind: string}; docId: string; modifier: string;
  data: Record<string, string>}; recipient: unknown; push: boolean};

function setup(t: TestContext, seed: Record<string, Doc> = {}, now = NOW) {
  t.mock.timers.enable({apis: ["Date"], now});
  t.mock.method(tipIo, "sender", async () => ({createdMs: now.getTime() - WEEK, verified: true}));
  const disabled = new Set<string>();
  t.mock.method(tipIo, "creatorDisabled", async (uid: string) => disabled.has(uid));
  const sent: Sent[] = [];
  t.mock.method(tipIo, "notify", async (payload: Sent["payload"], recipient: unknown, push: boolean) => {
    sent.push({payload, recipient, push});
    return true;
  });
  const store = installFakeDb(t, {
    "usersv2/fan": {coins: 200, name: "Ava"},
    "usersv2/fan2": {coins: 200, name: "Ben"},
    "usersv2/maker": {coins: 5, email: "maker@example.com"},
    "walls/neon": {id: "NEON", creatorUid: "maker", review: true, wallpaper_provider: "prism", title: "Neon rain"},
    ...seed,
  });
  return {store, sent, disabled};
}

const run = (data: Record<string, unknown>, uid = "fan") =>
  tipCreator.run({auth: {uid, token: {}}, data} as never);
const tip = (extra: Record<string, unknown> = {}, uid = "fan") =>
  run({creatorUid: "maker", amount: 25, requestId: REQ, ...extra}, uid);
const coins = (store: Map<string, Doc>, uid: string) => store.get(`usersv2/${uid}`)?.coins;

test("tipCreator refuses a caller who is not signed in", async (t) => {
  setup(t);
  await assert.rejects(
    tipCreator.run({data: {creatorUid: "maker", amount: 25, requestId: REQ}} as never),
    {code: "unauthenticated"},
  );
});

test("tipCreator refuses a tip to self and bad input", async (t) => {
  const {store} = setup(t);
  await assert.rejects(tip({creatorUid: "fan"}),
    (err: HttpsError) => err.code === "invalid-argument" && err.message === "tip_self");
  for (const bad of [{creatorUid: ""}, {creatorUid: "a/b"}, {requestId: "x"}, {wallId: "a/b"}, {wallId: 7}]) {
    await assert.rejects(tip(bad), {code: "invalid-argument"});
  }
  assert.equal(coins(store, "fan"), 200);
});

test("each fixed amount moves exactly that many coins, and other amounts are refused", async (t) => {
  const {store} = setup(t, {"usersv2/fan": {coins: 1000, name: "Ava"}});
  for (const amount of [0, 1, 11, 24.5, 100, -10, "25", null]) {
    await assert.rejects(tip({amount}), {code: "invalid-argument"});
  }
  let fan = 1000;
  for (const [i, amount] of [10, 25, 50].entries()) {
    const creatorUid = `maker${i}`;
    store.set(`usersv2/${creatorUid}`, {coins: 5});
    store.set(`walls/w${i}`, {id: `W${i}`, creatorUid, review: true, wallpaper_provider: "prism"});
    const result = await tip({creatorUid, amount, requestId: `request_000${i + 2}`});
    assert.equal(result.success, true);
    assert.equal(result.amount, amount);
    fan -= amount;
    assert.equal(coins(store, "fan"), fan);
    assert.equal(coins(store, creatorUid), 5 + amount);
  }
});

test("a sender younger than 7 days cannot tip", async (t) => {
  const {store, sent} = setup(t);
  t.mock.method(tipIo, "sender", async () => ({createdMs: NOW.getTime() - WEEK + 1, verified: true}));
  const result = await tip();
  assert.equal(result.success, false);
  assert.equal(result.reason, "tip_sender_too_new");
  assert.equal(coins(store, "fan"), 200);
  assert.equal(sent.length, 0);
});

test("a guest or unverified sender cannot tip", async (t) => {
  const {store} = setup(t);
  t.mock.method(tipIo, "sender", async () => ({createdMs: 0, verified: false}));
  assert.equal((await tip()).reason, "tip_sender_ineligible");
  assert.equal(coins(store, "fan"), 200);
});

test("a tip is never refundable", () => {
  assert.throws(() => refundableDelta({userId: "fan", type: "debit", status: "completed", action: "tipSent",
    delta: -25, createdAt: Timestamp.fromMillis(NOW.getTime())}, "fan", NOW.getTime()), {code: "failed-precondition"});
});

test("a banned, deleted, missing or wall-less creator cannot get tips", async (t) => {
  const {store, disabled, sent} = setup(t, {
    "usersv2/banned": {coins: 0},
    "walls/b": {id: "B", creatorUid: "banned", review: true, wallpaper_provider: "prism"},
    "usersv2/gone": {coins: 0, deleted: true},
    "walls/g": {id: "G", creatorUid: "gone", review: true, wallpaper_provider: "prism"},
    "usersv2/closing": {coins: 0},
    "creatorDeletionState/closing": {closed: true},
    "walls/c": {id: "C", creatorUid: "closing", review: true, wallpaper_provider: "prism"},
    "usersv2/nowalls": {coins: 0},
    "walls/draft": {id: "D", creatorUid: "nowalls", review: false},
    "usersv2/studioonly": {coins: 0},
    "walls/s": {id: "S", creatorUid: "studioonly", review: true, wallpaper_provider: "prism", origin: "studio"},
  });
  disabled.add("banned");
  for (const creatorUid of ["banned", "gone", "closing", "nowalls", "studioonly", "nobody"]) {
    const result = await tip({creatorUid});
    assert.equal(result.success, false, creatorUid);
    assert.equal(result.reason, "tip_creator_unavailable", creatorUid);
  }
  assert.equal(coins(store, "fan"), 200);
  assert.equal(sent.length, 0);
});

test("a short balance moves no coins and says so", async (t) => {
  const {store, sent} = setup(t, {"usersv2/fan": {coins: 24, name: "Ava"}});
  const result = await tip();
  assert.equal(result.success, false);
  assert.equal(result.insufficientBalance, true);
  assert.equal(result.reason, "tip_insufficient_balance");
  assert.equal(result.currentBalance, 24);
  assert.equal(coins(store, "fan"), 24);
  assert.equal(coins(store, "maker"), 5);
  assert.equal(sent.length, 0);
});

test("a tip debits the sender, credits the creator and writes both ledger entries with one tipId", async (t) => {
  const {store} = setup(t);
  const result = await tip({wallId: "neon"});
  assert.deepEqual(result, {
    success: true,
    changed: true,
    previousBalance: 200,
    currentBalance: 175,
    delta: -25,
    amount: 25,
    reason: "tip_to_maker",
    transactionId: `ctx_tip_fan_${REQ}`,
    tipId: `tip_fan_${REQ}`,
    insufficientBalance: false,
  });
  assert.equal(coins(store, "fan"), 175);
  assert.equal(coins(store, "maker"), 30);
  const out = store.get(`coinTransactions/ctx_tip_fan_${REQ}`);
  const into = store.get(`coinTransactions/ctx_tipin_fan_${REQ}`);
  assert.deepEqual(
    [out?.userId, out?.action, out?.delta, out?.balanceBefore, out?.balanceAfter, out?.type, out?.tipId,
      out?.counterpartyUid, out?.wallId],
    ["fan", "tipSent", -25, 200, 175, "debit", `tip_fan_${REQ}`, "maker", "neon"],
  );
  assert.deepEqual(
    [into?.userId, into?.action, into?.delta, into?.balanceBefore, into?.balanceAfter, into?.type, into?.tipId,
      into?.counterpartyUid, into?.wallId],
    ["maker", "tipReceived", 25, 5, 30, "credit", `tip_fan_${REQ}`, "fan", "neon"],
  );
});

test("a retry with the same requestId debits once, credits once and notifies once", async (t) => {
  const {store, sent} = setup(t);
  const first = await tip();
  const again = await tip();
  const third = await tip({amount: 50});
  assert.deepEqual(again, first);
  assert.equal(third.amount, 25);
  assert.equal(coins(store, "fan"), 175);
  assert.equal(coins(store, "maker"), 30);
  assert.equal(store.get("tipRateDaily/fan_2026-10-28")?.count, 1);
  assert.equal(sent.length, 1);
});

test("a retry still returns the stored tip after the creator is banned", async (t) => {
  const {disabled} = setup(t);
  const first = await tip();
  disabled.add("maker");
  assert.deepEqual(await tip(), first);
});

test("concurrent tips against one balance spend it at most once", async (t) => {
  const {store} = setup(t, {
    "usersv2/fan": {coins: 30, name: "Ava"},
    "usersv2/other": {coins: 0},
    "walls/o": {id: "O", creatorUid: "other", review: true, wallpaper_provider: "prism"},
  });
  const results = await Promise.all([
    tip({requestId: "request_000a"}),
    tip({creatorUid: "other", requestId: "request_000b"}),
  ]);
  assert.deepEqual(results.map((r) => r.success).sort(), [false, true]);
  assert.equal(results.find((r) => !r.success)?.reason, "tip_insufficient_balance");
  assert.equal(coins(store, "fan"), 5);
  assert.equal((coins(store, "maker") as number) + (coins(store, "other") as number), 30);
});

test("the wallId must be an approved wall of the creator", async (t) => {
  const {store} = setup(t, {
    "walls/draft": {id: "DRAFT", creatorUid: "maker", review: false},
    "walls/theirs": {id: "THEIRS", creatorUid: "fan2", review: true, wallpaper_provider: "prism"},
  });
  for (const wallId of ["draft", "theirs", "missing"]) {
    const result = await tip({wallId});
    assert.equal(result.reason, "tip_wall_invalid", wallId);
  }
  assert.equal(coins(store, "fan"), 200);
  assert.equal((await tip({wallId: "neon"})).success, true);
});

test("a block either way refuses the tip", async (t) => {
  setup(t, {"usersv2/maker/blockedUsers/fan": {blockedAt: 1}, "usersv2/fan2/blockedUsers/maker": {blockedAt: 1}});
  assert.equal((await tip()).reason, "tip_blocked");
  assert.equal((await tip({}, "fan2")).reason, "tip_blocked");
});

test("a sender may send 5 tips a UTC day and tip one creator once a day", async (t) => {
  const seed: Record<string, Doc> = {"usersv2/fan": {coins: 1000, name: "Ava"}};
  for (let i = 0; i <= TIPS_SENT_PER_DAY; i++) {
    seed[`usersv2/c${i}`] = {coins: 0};
    seed[`walls/c${i}`] = {id: `C${i}`, creatorUid: `c${i}`, review: true, wallpaper_provider: "prism"};
  }
  const {store} = setup(t, seed);
  assert.equal((await tip({creatorUid: "c0", requestId: "request_p000"})).success, true);
  assert.equal((await tip({creatorUid: "c0", requestId: "request_p001"})).reason, "tip_pair_limit");
  for (let i = 1; i < TIPS_SENT_PER_DAY; i++) {
    assert.equal((await tip({creatorUid: `c${i}`, requestId: `request_s00${i}`, amount: 10})).success, true);
  }
  const over = await tip({creatorUid: `c${TIPS_SENT_PER_DAY}`, requestId: "request_s999", amount: 10});
  assert.equal(over.reason, "tip_daily_limit");
  assert.equal(coins(store, "fan"), 1000 - 25 - 10 * (TIPS_SENT_PER_DAY - 1));
});

test("a creator gets at most 100 tip coins a UTC day", async (t) => {
  const {store} = setup(t, {
    "tipRateDaily/recv_maker_2026-10-28": {day: "2026-10-28", count: 6, coins: TIP_COINS_RECEIVED_PER_DAY - 20},
  });
  const over = await tip();
  assert.equal(over.reason, "tip_creator_limit");
  const fits = await tip({amount: 10, requestId: "request_0002"});
  assert.equal(fits.success, true);
  assert.deepEqual(store.get("tipRateDaily/recv_maker_2026-10-28"),
    {day: "2026-10-28", count: 7, coins: TIP_COINS_RECEIVED_PER_DAY - 10, creatorUid: "maker"});
});

test("the caps reset at 00:00 UTC and not before", async (t) => {
  const late = new Date("2026-10-28T23:59:59.999Z");
  const {store} = setup(t, {
    "tipRateDaily/fan_2026-10-28": {day: "2026-10-28", count: TIPS_SENT_PER_DAY},
    "tipRateDaily/recv_maker_2026-10-28": {day: "2026-10-28", count: 12, coins: TIP_COINS_RECEIVED_PER_DAY},
  }, late);
  assert.equal((await tip()).reason, "tip_daily_limit");
  t.mock.timers.setTime(late.getTime() + 1);
  const next = await tip({requestId: "request_0002"});
  assert.equal(next.success, true);
  assert.equal(store.get("tipRateDaily/fan_2026-10-29")?.count, 1);
  assert.deepEqual(store.get("tipRateDaily/recv_maker_2026-10-29"), {day: "2026-10-29", count: 1, coins: 25, creatorUid: "maker"});
});

test("the first tip of the day pushes and later tips only rewrite the same inbox item", async (t) => {
  const {sent} = setup(t);
  await tip({wallId: "neon"});
  await tip({amount: 50, requestId: "request_0002"}, "fan2");
  assert.equal(sent.length, 2);
  assert.deepEqual(sent.map((s) => s.push), [true, false]);
  assert.equal(sent[0].payload.title, "Ava tipped you 25 coins for Neon rain");
  assert.equal(sent[0].payload.message.kind, "tipReceived");
  assert.equal(sent[1].payload.title, "You got 2 tips today");
  assert.equal(sent[1].payload.body, "75 coins in all. See them in your creator stats.");
  assert.equal(sent[0].payload.docId, sent[1].payload.docId);
  assert.equal(sent[0].payload.docId, `tips_${hash("maker:2026-10-28").slice(0, 32)}`);
  assert.equal(sent[0].payload.modifier, "maker@example.com");
  assert.deepEqual(sent[0].payload.data,
    {route: "creator_stats", url: "prism://creator-stats", notification_kind: "tip_received"});
  assert.deepEqual(sent[0].recipient, {uid: "maker", email: "maker@example.com"});
});

test("a failed push does not fail the tip", async (t) => {
  const {store} = setup(t);
  t.mock.method(tipIo, "notify", async () => {
    throw new Error("fcm down");
  });
  assert.equal((await tip()).success, true);
  assert.equal(coins(store, "maker"), 30);
});

test("the tip push localizes natively and the daily summary never pushes", () => {
  assert.deepEqual(
    nativeNotificationLocalization(renderNotificationCopy(
      {kind: "tipReceived", senderName: "Ava", amount: 25, wallTitle: "Neon rain"})),
    {titleKey: "notif_push_tip_received_title", titleArgs: ["Ava", "25", "Neon rain"],
      bodyKey: "notif_push_tip_received_body", bodyArgs: []},
  );
  assert.equal(
    nativeNotificationLocalization(renderNotificationCopy(
      {kind: "tipReceived", senderName: "Ava", amount: 25, wallTitle: ""}))?.titleKey,
    "notif_push_tip_received_title_untitled",
  );
  assert.equal(nativeNotificationLocalization(renderNotificationCopy({kind: "tipsReceived", tipCount: 2, coins: 35})),
    null);
});

test("Tipped by counts each sender once per wall", async (t) => {
  const {store} = setup(t, {"wallpaper_stats/NEON": {sets: 4}});
  await tip({wallId: "neon"});
  t.mock.timers.setTime(NOW.getTime() + DAY);
  await tip({wallId: "neon", requestId: "request_0002"});
  assert.deepEqual(store.get("wallpaper_stats/NEON"), {sets: 4, tippers: 1});
  await tip({wallId: "neon", requestId: "request_0003"}, "fan2");
  assert.equal(store.get("wallpaper_stats/NEON")?.tippers, 2);
  await tip({requestId: "request_0004"}, "fan2");
  assert.equal(store.get("wallpaper_stats/NEON")?.tippers, 2);
});

test("creator stats show tips per week and per approved wall", async (t) => {
  setup(t, {"walls/other": {id: "OTHER", creatorUid: "maker", review: true, wallpaper_provider: "prism", title: "Dunes"}});
  await tip({wallId: "neon"});
  await tip({amount: 10, requestId: "request_0002"}, "fan2");
  const stats = await readCreatorStats("maker", {}, NOW.getTime());
  assert.equal(stats.tips.count, 2);
  assert.equal(stats.tips.coins, 35);
  assert.equal(stats.tips.weeks.length, 8);
  assert.deepEqual(stats.tips.weeks[7], {week: "2026-W44", start: "2026-10-26T00:00:00.000Z", count: 2, coins: 35});
  assert.equal(stats.tips.weeks[6].count, 0);
  assert.deepEqual(stats.tips.walls, [{wallId: "neon", count: 1, coins: 25}]);
});

test("profile tips find an approved wall after more than 20 Studio walls", async (t) => {
  const {store} = setup(t);
  store.delete("walls/neon");
  for (let i = 0; i < 20; i++) {
    store.set(`walls/studio${String(i).padStart(2, "0")}`, {creatorUid: "maker", review: true, wallpaper_provider: "prism", origin: "studio"});
  }
  store.set("walls/z_real", {id: "REAL", creatorUid: "maker", review: true, wallpaper_provider: "prism"});
  assert.equal((await tip()).success, true);
});

test("the transaction uses the current UTC day after eligibility crosses midnight", async (t) => {
  const late = new Date("2026-10-28T23:59:59.999Z");
  const {store} = setup(t, {}, late);
  t.mock.method(tipIo, "creatorDisabled", async () => {
    t.mock.timers.setTime(late.getTime() + 1);
    return false;
  });
  assert.equal((await tip()).success, true);
  assert.equal(store.get("tipRateDaily/fan_2026-10-29")?.count, 1);
  assert.equal(store.has("tipRateDaily/fan_2026-10-28"), false);
});

test("a delayed first push cannot overwrite the newer inbox total", async (t) => {
  const {store} = setup(t);
  let release!: () => void;
  let started!: () => void;
  const waiting = new Promise<void>((resolve) => {
    started = resolve;
  });
  const blocked = new Promise<void>((resolve) => {
    release = resolve;
  });
  t.mock.method(tipIo, "notify", async (payload: {docId: string; pushOnly?: boolean; title: string},
    _recipient: unknown, push: boolean) => {
    if (push) {
      started(); await blocked;
    }
    if (!payload.pushOnly) store.set(`notifications/${payload.docId}`, {notification: {title: payload.title}});
    return true;
  });
  const first = tip();
  await waiting;
  await tip({requestId: "request_0002"}, "fan2");
  release();
  await first;
  const inbox = store.get(`notifications/tips_${hash("maker:2026-10-28").slice(0, 32)}`);
  assert.equal((inbox?.notification as Doc)?.title, "You got 2 tips today");
});

test("a sender whose account deletion has started cannot transfer coins", async (t) => {
  const {store} = setup(t, {"creatorDeletionState/fan": {closed: true}});
  await assert.rejects(tip(), {code: "not-found"});
  assert.equal(coins(store, "maker"), 5);
});

test("sender IDs and request IDs cannot alias another sender's ledger", async (t) => {
  const {store} = setup(t, {"usersv2/fan_request": {coins: 200}});
  await tip({requestId: "request_request_0001"});
  const result = await tip({requestId: "request_0001"}, "fan_request");
  assert.equal(result.success, true);
  assert.equal(coins(store, "fan_request"), 175);
  assert.equal(coins(store, "maker"), 55);
});

test("duplicate wall documents do not count one sender twice on the same public wall", async (t) => {
  const {store} = setup(t, {
    "walls/duplicate": {id: "NEON", creatorUid: "maker", review: true, wallpaper_provider: "prism"},
  });
  await tip({wallId: "neon"});
  t.mock.timers.setTime(NOW.getTime() + DAY);
  await tip({wallId: "duplicate", requestId: "request_0002"});
  assert.equal(store.get("wallpaper_stats/NEON")?.tippers, 1);
});

test("a retried transaction crossing midnight charges the new day's cap", async (t) => {
  const late = new Date("2026-10-28T23:59:59.999Z");
  const {store} = setup(t, {}, late);
  const original = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => {
    await callback({
      get: (ref: {get: () => Promise<unknown>}) => ref.get(),
      set: () => undefined,
      update: () => undefined,
      create: () => undefined,
    });
    t.mock.timers.setTime(late.getTime() + 1);
    return original(callback);
  });
  assert.equal((await tip()).success, true);
  assert.equal(store.has("tipRateDaily/fan_2026-10-28"), false);
  assert.equal(store.get("tipRateDaily/fan_2026-10-29")?.count, 1);
});

test("a sender ID cannot alias the receiver daily cap", async (t) => {
  const {store} = setup(t, {"usersv2/recv_maker": {coins: 200}});
  assert.equal((await tip({}, "recv_maker")).success, true);
  assert.equal(store.get("tipRateDaily/recv%5Fmaker_2026-10-28")?.senderUid, "recv_maker");
  assert.equal(store.get("tipRateDaily/recv_maker_2026-10-28")?.coins, 25);
});

test("concurrent senders cannot exceed the creator receive cap", async (t) => {
  const {store} = setup(t, {
    "tipRateDaily/recv_maker_2026-10-28": {day: "2026-10-28", count: 2, coins: 75},
  });
  const results = await Promise.all([tip(), tip({}, "fan2")]);
  assert.deepEqual(results.map((result) => result.success).sort(), [false, true]);
  assert.equal(results.find((result) => !result.success)?.reason, "tip_creator_limit");
  assert.equal(coins(store, "maker"), 30);
  assert.equal(store.get("tipRateDaily/recv_maker_2026-10-28")?.coins, 100);
});

test("concurrent same-key retries debit once even when the amount changes", async (t) => {
  const {store} = setup(t);
  const results = await Promise.all([tip(), tip({amount: 50})]);
  assert.deepEqual(results[0], results[1]);
  assert.equal(coins(store, "fan"), 175);
  assert.equal(coins(store, "maker"), 30);
});

test("stale daily tallies do not consume today's caps", async (t) => {
  setup(t, {
    "tipRateDaily/fan_2026-10-28": {day: "2026-10-27", count: 5},
    "tipRateDaily/recv_maker_2026-10-28": {day: "2026-10-27", count: 10, coins: 100},
    "tipRateDaily/pair_fan_maker_2026-10-28": {day: "2026-10-27", count: 1},
  });
  assert.equal((await tip()).success, true);
});
