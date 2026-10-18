import assert from "node:assert/strict";
import test, {beforeEach} from "node:test";
import {
  awardCoins,
  claimProSpin,
  planWheelSpin,
  readWheelDay,
  resolveWheelPrize,
  type SpinWheelReply,
  spinWheel,
  wheelStatus,
} from "../coinsCallables";
import {DEFAULT_ECONOMY, ECONOMY_CONFIG_DOC, resetEconomyCache, weekKey} from "../economy";
import {buildQuestState} from "../questCatalog";
import {SHOP_CATALOG} from "../shopCatalog";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 18, 12, 0, 0);
const DAY_MS = 86_400_000;
const TODAY = "2026-10-18";
const YESTERDAY = "2026-10-17";
const USER = "usersv2/user-1";
const PRIVATE = `${USER}/private/economy`;
const LEDGER = "coinTransactions/ctx_spinWheel_user-1_";
const FRESH = {dayKey: "", paid: 0, freeUsed: false};

beforeEach(() => resetEconomyCache());

const day = (over: Partial<Parameters<typeof wheelStatus>[0]> = {}) => ({
  isPro: false, today: TODAY, coinState: {}, wheelState: FRESH, config: DEFAULT_ECONOMY, ...over,
});
const plan = (over: Partial<Parameters<typeof planWheelSpin>[0]> = {}) =>
  planWheelSpin({...day(), balance: 100, maxCost: 10, ...over});

test("planWheelSpin: a Pro member's first spin of the day is free and does not touch the paid count", () => {
  assert.deepEqual(plan({isPro: true, balance: 0, maxCost: 0}),
    {ok: true, free: true, cost: 0, next: {dayKey: TODAY, paid: 0, freeUsed: true}});
  const capped = plan({isPro: true, wheelState: {dayKey: TODAY, paid: 5, freeUsed: false}, maxCost: 0});
  assert.deepEqual(capped, {ok: true, free: true, cost: 0, next: {dayKey: TODAY, paid: 5, freeUsed: true}});
});

test("planWheelSpin: a Pro member pays once the free spin is used", () => {
  const used = plan({isPro: true, wheelState: {dayKey: TODAY, paid: 0, freeUsed: true}});
  assert.deepEqual(used, {ok: true, free: false, cost: 10, next: {dayKey: TODAY, paid: 1, freeUsed: true}});
});

test("planWheelSpin: a legacy Pro spin or daily bonus today uses up the free spin", () => {
  for (const coinState of [{proSpinDate: TODAY}, {proDailyBonusDate: TODAY}]) {
    assert.deepEqual(plan({isPro: true, coinState}),
      {ok: true, free: false, cost: 10, next: {dayKey: TODAY, paid: 1, freeUsed: false}});
    assert.deepEqual(plan({isPro: true, coinState, maxCost: 0}), {ok: false, reason: "spin_wheel_price_changed"});
  }
  const yesterday = {proSpinDate: YESTERDAY, proDailyBonusDate: YESTERDAY};
  assert.deepEqual(plan({isPro: true, coinState: yesterday, maxCost: 0}),
    {ok: true, free: true, cost: 0, next: {dayKey: TODAY, paid: 0, freeUsed: true}});
});

test("planWheelSpin: a free user pays and is counted", () => {
  assert.deepEqual(plan({wheelState: {dayKey: TODAY, paid: 2, freeUsed: false}}),
    {ok: true, free: false, cost: 10, next: {dayKey: TODAY, paid: 3, freeUsed: false}});
  assert.deepEqual(plan({balance: 10, maxCost: 10}),
    {ok: true, free: false, cost: 10, next: {dayKey: TODAY, paid: 1, freeUsed: false}});
});

test("planWheelSpin: the fifth paid spin is the last of the day", () => {
  const fourth = plan({wheelState: {dayKey: TODAY, paid: 4, freeUsed: false}});
  assert.equal(fourth.ok, true);
  const capped = {dayKey: TODAY, paid: 5, freeUsed: false};
  assert.deepEqual(plan({wheelState: capped}), {ok: false, reason: "spin_wheel_daily_limit"});
  assert.deepEqual(plan({isPro: true, wheelState: {...capped, freeUsed: true}}),
    {ok: false, reason: "spin_wheel_daily_limit"});
  const custom = {...DEFAULT_ECONOMY, award: {...DEFAULT_ECONOMY.award, spinWheelMaxPerDay: 0}};
  assert.deepEqual(plan({config: custom}), {ok: false, reason: "spin_wheel_daily_limit"});
});

test("planWheelSpin: refuses when the real cost is above maxCost and accepts when it is equal", () => {
  assert.deepEqual(plan({maxCost: 9}), {ok: false, reason: "spin_wheel_price_changed"});
  assert.equal(plan({maxCost: 10}).ok, true);
  const dearer = {...DEFAULT_ECONOMY, spend: {...DEFAULT_ECONOMY.spend, spinWheel: 25}};
  assert.deepEqual(plan({config: dearer, maxCost: 10}), {ok: false, reason: "spin_wheel_price_changed"});
  assert.deepEqual(plan({config: dearer, maxCost: 25}),
    {ok: true, free: false, cost: 25, next: {dayKey: TODAY, paid: 1, freeUsed: false}});
});

test("planWheelSpin: refuses a short balance, and checks price and cap first", () => {
  assert.deepEqual(plan({balance: 9}), {ok: false, reason: "spin_wheel_insufficient_balance"});
  assert.deepEqual(plan({balance: 9, maxCost: 5}), {ok: false, reason: "spin_wheel_price_changed"});
  const capped = {dayKey: TODAY, paid: 5, freeUsed: false};
  assert.deepEqual(plan({balance: 0, maxCost: 0, wheelState: capped}), {ok: false, reason: "spin_wheel_daily_limit"});
  assert.deepEqual(plan({isPro: true, balance: 0, maxCost: 0}),
    {ok: true, free: true, cost: 0, next: {dayKey: TODAY, paid: 0, freeUsed: true}});
});

test("planWheelSpin: a new UTC day resets the paid count and the free spin", () => {
  const yesterday = {dayKey: YESTERDAY, paid: 5, freeUsed: true};
  assert.deepEqual(plan({wheelState: yesterday}),
    {ok: true, free: false, cost: 10, next: {dayKey: TODAY, paid: 1, freeUsed: false}});
  assert.deepEqual(plan({isPro: true, wheelState: yesterday, maxCost: 0}),
    {ok: true, free: true, cost: 0, next: {dayKey: TODAY, paid: 0, freeUsed: true}});
});

test("planWheelSpin: a price of 0 still counts against the daily cap", () => {
  const cheap = {...DEFAULT_ECONOMY, spend: {...DEFAULT_ECONOMY.spend, spinWheel: 0}};
  assert.deepEqual(plan({config: cheap, maxCost: 0, balance: 0}),
    {ok: true, free: false, cost: 0, next: {dayKey: TODAY, paid: 1, freeUsed: false}});
});

test("wheelStatus: a free user sees the price and five paid spins", () => {
  assert.deepEqual(wheelStatus(day()), {freeSpinAvailable: false, paidSpinsLeft: 5, price: 10});
});

test("wheelStatus: a Pro member sees the free spin until any client uses it", () => {
  assert.deepEqual(wheelStatus(day({isPro: true})), {freeSpinAvailable: true, paidSpinsLeft: 5, price: 10});
  const used = {dayKey: TODAY, paid: 0, freeUsed: true};
  assert.equal(wheelStatus(day({isPro: true, wheelState: used})).freeSpinAvailable, false);
  assert.equal(wheelStatus(day({isPro: true, coinState: {proSpinDate: TODAY}})).freeSpinAvailable, false);
  assert.equal(wheelStatus(day({isPro: true, coinState: {proDailyBonusDate: TODAY}})).freeSpinAvailable, false);
  assert.equal(wheelStatus(day({isPro: true, wheelState: {...used, dayKey: YESTERDAY}})).freeSpinAvailable, true);
});

test("wheelStatus: paid spins left count down to 0 and reset on a new day", () => {
  const left = (paid: number, dayKey = TODAY) => wheelStatus(day({wheelState: {dayKey, paid, freeUsed: false}}));
  assert.equal(left(3).paidSpinsLeft, 2);
  assert.equal(left(5).paidSpinsLeft, 0);
  assert.equal(left(9).paidSpinsLeft, 0);
  assert.equal(left(5, YESTERDAY).paidSpinsLeft, 5);
  const custom = {...DEFAULT_ECONOMY,
    spend: {...DEFAULT_ECONOMY.spend, spinWheel: 25},
    award: {...DEFAULT_ECONOMY.award, spinWheelMaxPerDay: 3}};
  assert.deepEqual(wheelStatus(day({config: custom})), {freeSpinAvailable: false, paidSpinsLeft: 3, price: 25});
});

test("readWheelDay: stored garbage reads as an empty day", () => {
  assert.deepEqual(readWheelDay({dayKey: TODAY, paid: 3, freeUsed: true}), {dayKey: TODAY, paid: 3, freeUsed: true});
  assert.deepEqual(readWheelDay({dayKey: 5, paid: -2, freeUsed: "yes"}), FRESH);
  for (const raw of [undefined, null, "x", [], 7]) assert.deepEqual(readWheelDay(raw), FRESH);
});

const commonIds = SHOP_CATALOG.filter((item) => item.common).map((item) => item.id);

test("resolveWheelPrize: coin and XP slices pay their own amount", () => {
  assert.deepEqual(resolveWheelPrize({kind: "coins", coins: 20, weight: 1}, []),
    {kind: "coins", coins: 20, xp: 0, itemId: null});
  assert.deepEqual(resolveWheelPrize({kind: "xp", xp: 50, weight: 1}, []),
    {kind: "xp", coins: 0, xp: 50, itemId: null});
});

test("resolveWheelPrize: a cosmetic slice picks an unowned common item, else pays the fallback", () => {
  const slice = {kind: "cosmetic", fallbackCoins: 50, weight: 1} as const;
  assert.deepEqual(resolveWheelPrize(slice, [], () => 0), {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_rose"});
  assert.deepEqual(resolveWheelPrize(slice, ["theme_rose"], () => 0),
    {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_cotton_blue"});
  assert.deepEqual(resolveWheelPrize(slice, ["theme_rose"], () => 0.99),
    {kind: "cosmetic", coins: 0, xp: 0, itemId: "glow_ocean"});
  assert.deepEqual(resolveWheelPrize(slice, commonIds, () => 0), {kind: "cosmetic", coins: 50, xp: 0, itemId: null});
});

const asUser = (data: Record<string, unknown>) => ({auth: {uid: "user-1"}, data});
const request = (data: Record<string, unknown>) => asUser(data) as unknown as Parameters<typeof spinWheel.run>[0];
const legacySpin = () =>
  claimProSpin.run(asUser({requestId: "legacy_request"}) as unknown as Parameters<typeof claimProSpin.run>[0]);
const award = (data: Record<string, unknown>) =>
  awardCoins.run(asUser({sourceTag: "test", ...data}) as unknown as Parameters<typeof awardCoins.run>[0]);
const spin = (requestId = "spin_request_1", maxCost = 10, extra: Record<string, unknown> = {}) =>
  spinWheel.run(request({requestId, maxCost, ...extra}));

function won(reply: SpinWheelReply): Extract<SpinWheelReply, {success: true}> {
  if (!reply.success) assert.fail(`refused: ${reply.reason}`);
  return reply;
}

function setup(t: test.TestContext, user: Doc, priv?: Doc, extra: Record<string, Doc> = {}) {
  t.mock.method(Date, "now", () => NOW);
  return installFakeDb(t, {[USER]: user, ...(priv ? {[PRIVATE]: priv} : {}), ...extra});
}

/** Rolls that land on a slice of the default table. The weights sum to 100, so a roll is a percentage point. */
const ROLL = {coins10: 0.1, xp25: 0.3, coins5: 0.5, coins20: 0.75, xp50: 0.85, cosmetic: 0.95};

function rolls(t: test.TestContext, ...values: number[]): void {
  const queue = [...values];
  t.mock.method(Math, "random", () => queue.shift() ?? 0);
}

const ledger = (store: ReturnType<typeof installFakeDb>) =>
  [...store.keys()].filter((path) => path.startsWith(LEDGER));

test("spinWheel: a Pro member's free spin pays the prize, writes both shared dates and progresses the Pro quest", async (t) => {
  rolls(t, ROLL.coins10);
  const quests = buildQuestState(undefined, NOW, true);
  const store = setup(t, {coins: 10, premium: true}, {rev: 1, quests});
  const reply = await spin("spin_request_1", 0);
  assert.deepEqual(reply, {
    success: true,
    changed: true,
    previousBalance: 10,
    currentBalance: 20,
    delta: 10,
    reason: "spin_wheel",
    transactionId: "ctx_spinWheel_user-1_spin_request_1",
    insufficientBalance: false,
    status: {freeSpinAvailable: false, paidSpinsLeft: 5, price: 10},
    cost: 0,
    free: true,
    segment: 0,
    prize: {kind: "coins", coins: 10, xp: 0, itemId: null},
    segments: DEFAULT_ECONOMY.award.spinWheel,
  });
  const user = store.get(USER) ?? {};
  assert.equal(user.coins, 20);
  assert.equal(user.xp, 10);
  assert.deepEqual(user.coinState, {proSpinDate: TODAY, proDailyBonusDate: TODAY});
  const priv = store.get(PRIVATE) ?? {};
  assert.equal(priv.rev, 2);
  assert.deepEqual(priv.spinWheel, {dayKey: TODAY, paid: 0, freeUsed: true});
  assert.equal((priv.quests as {bonus: {claimed: boolean}}).bonus.claimed, true);
  const receipt = store.get("coinTransactions/ctx_spinWheel_user-1_spin_request_1") ?? {};
  assert.equal(receipt.action, "spinWheel");
  assert.equal(receipt.type, "credit");
  assert.equal(receipt.delta, 10);
  assert.equal(receipt.balanceBefore, 10);
  assert.equal(receipt.balanceAfter, 20);
  assert.equal(receipt.cost, 0);
  assert.equal(receipt.free, true);
  assert.equal(receipt.segment, 0);
  assert.deepEqual(receipt.prize, {kind: "coins", coins: 10, xp: 0, itemId: null});
  assert.equal(receipt.sourceTag, "coins.spin_wheel.callable");
});

test("spinWheel: a paid spin debits the cost, pays the prize and leaves a net ledger entry", async (t) => {
  rolls(t, ROLL.coins5);
  const quests = buildQuestState(undefined, NOW, false);
  const store = setup(t, {coins: 25}, {rev: 4, quests});
  const reply = won(await spin("spin_request_1", 10, {sourceTag: "rewards.wheel"}));
  assert.equal(reply.cost, 10);
  assert.equal(reply.free, false);
  assert.equal(reply.segment, 2);
  assert.deepEqual(reply.prize, {kind: "coins", coins: 5, xp: 0, itemId: null});
  assert.equal(reply.previousBalance, 25);
  assert.equal(reply.currentBalance, 20);
  assert.equal(reply.delta, -5);
  assert.deepEqual(reply.status, {freeSpinAvailable: false, paidSpinsLeft: 4, price: 10});
  const user = store.get(USER) ?? {};
  assert.equal(user.coins, 20);
  assert.equal(user.xp, 5);
  assert.deepEqual(user.xpWeek, {weekKey: weekKey(NOW), xp: 5});
  assert.equal(user.coinState, undefined);
  const priv = store.get(PRIVATE) ?? {};
  assert.deepEqual(priv.spinWheel, {dayKey: TODAY, paid: 1, freeUsed: false});
  assert.equal(priv.rev, 5);
  assert.deepEqual(priv.quests, quests);
  const receipt = store.get("coinTransactions/ctx_spinWheel_user-1_spin_request_1") ?? {};
  assert.equal(receipt.type, "debit");
  assert.equal(receipt.delta, -5);
  assert.equal(receipt.balanceBefore, 25);
  assert.equal(receipt.balanceAfter, 20);
  assert.equal(receipt.cost, 10);
  assert.equal(receipt.free, false);
  assert.equal(receipt.sourceTag, "rewards.wheel");
});

test("spinWheel: a Pro member who used the free spin pays and does not progress the Pro quest again", async (t) => {
  rolls(t, ROLL.coins20);
  const quests = buildQuestState(undefined, NOW, true);
  const store = setup(t, {coins: 30, premium: true, coinState: {proSpinDate: TODAY, proDailyBonusDate: TODAY}},
    {rev: 1, quests});
  const reply = won(await spin());
  assert.equal(reply.free, false);
  assert.equal(reply.cost, 10);
  assert.equal(reply.currentBalance, 40);
  assert.equal(reply.delta, 10);
  assert.deepEqual(store.get(PRIVATE)?.quests, quests);
  assert.deepEqual(store.get(PRIVATE)?.spinWheel, {dayKey: TODAY, paid: 1, freeUsed: false});
});

test("spinWheel: an XP prize adds XP and the cost is the only coin change", async (t) => {
  rolls(t, ROLL.xp25);
  const store = setup(t, {coins: 50, xp: 100});
  const reply = won(await spin());
  assert.equal(reply.segment, 1);
  assert.deepEqual(reply.prize, {kind: "xp", coins: 0, xp: 25, itemId: null});
  assert.equal(reply.delta, -10);
  assert.equal(reply.currentBalance, 40);
  const user = store.get(USER) ?? {};
  assert.equal(user.coins, 40);
  assert.equal(user.xp, 125);
  assert.deepEqual(user.xpWeek, {weekKey: weekKey(NOW), xp: 25});
});

test("spinWheel: a cosmetic prize is written to the inventory next to what the user owns", async (t) => {
  rolls(t, ROLL.cosmetic, 0);
  const store = setup(t, {coins: 50}, {rev: 2, inventory: {owned: {glow_ember: 5}}});
  const reply = won(await spin());
  assert.equal(reply.segment, 7);
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_rose"});
  assert.equal(reply.currentBalance, 40);
  assert.equal(store.get(USER)?.xp, 0);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {glow_ember: 5, theme_rose: NOW}});
});

test("spinWheel: a cosmetic slice pays its fallback coins when every common item is owned", async (t) => {
  rolls(t, ROLL.cosmetic);
  const owned = Object.fromEntries(commonIds.map((id) => [id, 1]));
  const store = setup(t, {coins: 50}, {rev: 2, inventory: {owned}});
  const reply = won(await spin());
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 50, xp: 0, itemId: null});
  assert.equal(reply.delta, 40);
  assert.equal(reply.currentBalance, 90);
  assert.equal(store.get(USER)?.xp, 50);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned});
});

test("spinWheel: the reply carries the table the server spun, not the default one", async (t) => {
  rolls(t, 0.9);
  const table = [{kind: "coins", coins: 7, weight: 1}, {kind: "xp", xp: 9, weight: 3}];
  const store = setup(t, {coins: 50}, undefined, {[ECONOMY_CONFIG_DOC]: {award: {spinWheel: table}}});
  const reply = won(await spin());
  assert.equal(reply.segment, 1);
  assert.deepEqual(reply.segments, table);
  assert.deepEqual(reply.prize, {kind: "xp", coins: 0, xp: 9, itemId: null});
  assert.deepEqual(store.get("coinTransactions/ctx_spinWheel_user-1_spin_request_1")?.prize,
    {kind: "xp", coins: 0, xp: 9, itemId: null});
});

test("spinWheel: a retried request returns the original reply and charges once", async (t) => {
  rolls(t, ROLL.coins20);
  const store = setup(t, {coins: 50}, {rev: 1});
  const first = await spin();
  rolls(t, 0.99);
  const retry = await spin("spin_request_1", 0);
  assert.deepEqual(retry, first);
  assert.equal(store.get(USER)?.coins, 60);
  assert.equal(store.get(USER)?.xp, 20);
  assert.equal(ledger(store).length, 1);
  assert.deepEqual(store.get(PRIVATE)?.spinWheel, {dayKey: TODAY, paid: 1, freeUsed: false});
  assert.equal(store.get(PRIVATE)?.rev, 2);
});

test("spinWheel: a replay on a later day still returns the original reply and changes nothing", async (t) => {
  let now = NOW;
  t.mock.method(Date, "now", () => now);
  rolls(t, ROLL.coins10, ROLL.xp50);
  const store = installFakeDb(t, {[USER]: {coins: 30}});
  const first = await spin();
  now = NOW + DAY_MS;
  resetEconomyCache();
  assert.deepEqual(await spin(), first);
  assert.equal(store.get(USER)?.coins, 30);
  assert.equal(ledger(store).length, 1);
});

test("spinWheel: a refused request writes nothing, so the same id works after the user tops up", async (t) => {
  rolls(t, ROLL.coins10);
  const store = setup(t, {coins: 9}, {rev: 1});
  const refused = await spin();
  assert.equal(refused.success, false);
  assert.equal(ledger(store).length, 0);
  store.set(USER, {coins: 30});
  const reply = won(await spin());
  assert.equal(reply.currentBalance, 30);
  assert.equal(store.get(USER)?.coins, 30);
  assert.equal(ledger(store).length, 1);
});

test("spinWheel: after the legacy claimProSpin, a client that showed 'free' is refused and not charged", async (t) => {
  rolls(t, ROLL.coins10);
  const store = setup(t, {coins: 40, premium: true});
  const legacy = await legacySpin();
  assert.equal(legacy.success, true);
  const balance = store.get(USER)?.coins;
  const refused = await spin("spin_request_1", 0);
  assert.deepEqual(refused, {
    success: false,
    changed: false,
    previousBalance: balance,
    currentBalance: balance,
    delta: 0,
    reason: "spin_wheel_price_changed",
    transactionId: "",
    insufficientBalance: false,
    status: {freeSpinAvailable: false, paidSpinsLeft: 5, price: 10},
  });
  assert.equal(store.get(USER)?.coins, balance);
  assert.equal(ledger(store).length, 0);
  assert.equal(store.get(PRIVATE)?.spinWheel, undefined);
  const paid = won(await spin("spin_request_2", 10));
  assert.equal(paid.cost, 10);
  assert.equal(paid.free, false);
});

test("spinWheel: the wheel's free spin blocks the legacy Pro spin and daily bonus the same day", async (t) => {
  rolls(t, ROLL.coins10);
  const store = setup(t, {coins: 0, premium: true});
  won(await spin("spin_request_1", 0));
  const coins = store.get(USER)?.coins;
  assert.equal((await legacySpin()).reason, "pro_spin_already_claimed");
  assert.equal((await award({action: "proDailyBonus"})).reason, "pro_bonus_already_claimed");
  assert.equal(store.get(USER)?.coins, coins);
});

test("spinWheel: the sixth paid spin of a UTC day is refused and the next day opens five more", async (t) => {
  let now = NOW;
  t.mock.method(Date, "now", () => now);
  rolls(t, ...Array(10).fill(ROLL.coins5));
  const store = installFakeDb(t, {[USER]: {coins: 100}});
  for (let i = 1; i <= 5; i += 1) {
    const reply = won(await spin(`spin_request_${i}`));
    assert.equal(reply.status.paidSpinsLeft, 5 - i);
  }
  assert.equal(store.get(USER)?.coins, 75);
  const sixth = await spin("spin_request_6");
  assert.equal(sixth.success, false);
  assert.equal(sixth.reason, "spin_wheel_daily_limit");
  assert.deepEqual(sixth.status, {freeSpinAvailable: false, paidSpinsLeft: 0, price: 10});
  assert.equal(store.get(USER)?.coins, 75);
  assert.equal(ledger(store).length, 5);
  now = NOW + DAY_MS;
  const nextDay = won(await spin("spin_request_7"));
  assert.equal(nextDay.status.paidSpinsLeft, 4);
  assert.deepEqual(store.get(PRIVATE)?.spinWheel, {dayKey: "2026-10-19", paid: 1, freeUsed: false});
});

test("spinWheel: a short balance is refused with insufficientBalance and the balance stays", async (t) => {
  const store = setup(t, {coins: 9}, {rev: 3});
  const refused = await spin();
  assert.deepEqual(refused, {
    success: false,
    changed: false,
    previousBalance: 9,
    currentBalance: 9,
    delta: 0,
    reason: "spin_wheel_insufficient_balance",
    transactionId: "",
    insufficientBalance: true,
    status: {freeSpinAvailable: false, paidSpinsLeft: 5, price: 10},
  });
  assert.equal(store.get(USER)?.coins, 9);
  assert.equal(store.get(USER)?.xp, undefined);
  assert.equal(store.get(PRIVATE)?.rev, 3);
  assert.equal(ledger(store).length, 0);
});

test("spinWheel: a Pro member with no coins still gets the free spin", async (t) => {
  rolls(t, ROLL.xp50);
  const store = setup(t, {coins: 0, premium: true});
  const reply = won(await spin("spin_request_1", 0));
  assert.equal(reply.free, true);
  assert.equal(reply.currentBalance, 0);
  assert.equal(store.get(USER)?.xp, 50);
});

test("spinWheel: a raised price is refused above maxCost and charged exactly when maxCost covers it", async (t) => {
  rolls(t, ROLL.xp25);
  const store = setup(t, {coins: 100}, undefined, {[ECONOMY_CONFIG_DOC]: {spend: {spinWheel: 25}}});
  const refused = await spin("spin_request_1", 10);
  assert.equal(refused.reason, "spin_wheel_price_changed");
  assert.deepEqual(refused.status, {freeSpinAvailable: false, paidSpinsLeft: 5, price: 25});
  assert.equal(store.get(USER)?.coins, 100);
  const reply = won(await spin("spin_request_2", 25));
  assert.equal(reply.cost, 25);
  assert.equal(store.get(USER)?.coins, 75);
});

test("spinWheel: a Pro member's free spin costs nothing even when maxCost is above zero", async (t) => {
  rolls(t, ROLL.xp25);
  const store = setup(t, {coins: 5, premium: true});
  const reply = won(await spin("spin_request_1", 10));
  assert.equal(reply.cost, 0);
  assert.equal(store.get(USER)?.coins, 5);
});

test("spinWheel: a spin ledger entry cannot be refunded back into coins", async (t) => {
  rolls(t, ROLL.xp25);
  const store = setup(t, {coins: 50});
  const reply = won(await spin());
  await assert.rejects(() => award({action: "refund", transactionId: reply.transactionId}),
    {code: "failed-precondition"});
  assert.equal(store.get(USER)?.coins, 40);
});

test("spinWheel: bad requestId or maxCost is invalid-argument and writes nothing", async (t) => {
  const store = setup(t, {coins: 100, premium: true}, {rev: 1});
  for (const requestId of [undefined, 12345678, "short", "bad/path_123", "x".repeat(65)]) {
    await assert.rejects(() => spinWheel.run(request({requestId, maxCost: 10})), {code: "invalid-argument"},
      String(requestId));
  }
  for (const maxCost of [undefined, null, -1, 10_001, 1.5, "10", Number.NaN, Infinity, [10]]) {
    await assert.rejects(() => spinWheel.run(request({requestId: "spin_request_1", maxCost})),
      {code: "invalid-argument"}, String(maxCost));
  }
  assert.equal(store.get(USER)?.coins, 100);
  assert.equal(store.get(PRIVATE)?.rev, 1);
  assert.equal(ledger(store).length, 0);
});

test("spinWheel: needs a signed-in user with a profile", async (t) => {
  setup(t, {coins: 100});
  const data = {requestId: "spin_request_1", maxCost: 10};
  await assert.rejects(() => spinWheel.run({data} as unknown as Parameters<typeof spinWheel.run>[0]),
    {code: "unauthenticated"});
  await assert.rejects(() => spinWheel.run({auth: {uid: "ghost"}, data} as unknown as Parameters<typeof spinWheel.run>[0]),
    {code: "not-found"});
});
