import assert from "node:assert/strict";
import test, {beforeEach} from "node:test";
import {DEFAULT_ECONOMY, ECONOMY_CONFIG_DOC, resetEconomyCache} from "../economy";
import {buildQuestState, type QuestState} from "../questCatalog";
import {
  dailyChestStatus,
  type DailyChestReply,
  type DailyChestWin,
  openDailyChest,
  openQuestChest,
  planDailyChest,
  rollDailyChest,
  storedDailyChestWin,
} from "../quests";
import {SHOP_CATALOG} from "../shopCatalog";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = Date.UTC(2026, 9, 18, 12, 0, 0);
const DAY_MS = 86_400_000;
const USER = "usersv2/user-1";
const PRIVATE = `${USER}/private/economy`;
const RECEIPT = "coinTransactions/ctx_questChest_user-1_2026-10-18";
const TABLE = DEFAULT_ECONOMY.award.dailyChest;
const commonIds = SHOP_CATALOG.filter((item) => item.common).map((item) => item.id);
const WEEK = "2026-W42";
const NEXT_WEEK = "2026-W43";
/** The XP receipt every reply carries: `xp` and `xpWeek` are the user's totals after the call. */
const xpFields = (xp: number, weekXp: number, xpAwarded: number, weekKey = WEEK) =>
  ({xpPolicyVersion: 1, xp, xpWeek: {weekKey, xp: weekXp}, xpAwarded});
const xpOf = (reply: DailyChestReply) =>
  ({xpPolicyVersion: reply.xpPolicyVersion, xp: reply.xp, xpWeek: reply.xpWeek, xpAwarded: reply.xpAwarded});

beforeEach(() => resetEconomyCache());

const fresh = (): QuestState => buildQuestState(undefined, NOW, false);
const claimed = (item: QuestState["bonus"]) => ({...item, progress: item.target, claimed: true});
/** The three daily items claimed, so the chest is free. */
const itemsDone = (over: Partial<QuestState> = {}): QuestState => {
  const state = fresh();
  return {...state, items: state.items.map(claimed), ...over};
};
const withBonus = (state: QuestState): QuestState => ({...state, bonus: claimed(state.bonus)});

const day = (over: Partial<Parameters<typeof dailyChestStatus>[0]> = {}) =>
  ({quests: fresh(), receipt: undefined, config: DEFAULT_ECONOMY, ...over});
const plan = (over: Partial<Parameters<typeof planDailyChest>[0]> = {}) =>
  planDailyChest({...day(), balance: 100, maxCost: 8, ...over});

test("dailyChestStatus: a fresh day is closed, paid and priced at 8", () => {
  assert.deepEqual(dailyChestStatus(day()), {opened: false, free: false, price: 8});
});

test("dailyChestStatus: it is free only when all three items are claimed, and the bonus does not count", () => {
  assert.equal(dailyChestStatus(day({quests: itemsDone()})).free, true);
  const two = itemsDone();
  two.items[2] = {...two.items[2], claimed: false};
  assert.equal(dailyChestStatus(day({quests: two})).free, false);
  assert.equal(dailyChestStatus(day({quests: withBonus(fresh())})).free, false);
});

test("dailyChestStatus: a chestOpened flag or any receipt marks it opened", () => {
  assert.equal(dailyChestStatus(day({quests: {...fresh(), chestOpened: true}})).opened, true);
  assert.equal(dailyChestStatus(day({receipt: {requestId: "legacy_request", coins: 9}})).opened, true);
});

test("dailyChestStatus: the price follows the config", () => {
  const dearer = {...DEFAULT_ECONOMY, spend: {...DEFAULT_ECONOMY.spend, dailyChest: 25}};
  assert.equal(dailyChestStatus(day({config: dearer})).price, 25);
});

test("planDailyChest: all three items claimed makes it free, even with no coins and maxCost 0", () => {
  assert.deepEqual(plan({quests: itemsDone(), balance: 0, maxCost: 0}), {ok: true, free: true, cost: 0});
});

test("planDailyChest: otherwise it costs the price, and an exact balance and maxCost are enough", () => {
  assert.deepEqual(plan(), {ok: true, free: false, cost: 8});
  assert.deepEqual(plan({balance: 8, maxCost: 8}), {ok: true, free: false, cost: 8});
  assert.deepEqual(plan({balance: 8, maxCost: 10_000}), {ok: true, free: false, cost: 8});
});

test("planDailyChest: refuses when the real cost is above maxCost", () => {
  assert.deepEqual(plan({maxCost: 7}), {ok: false, reason: "daily_chest_price_changed"});
  assert.deepEqual(plan({maxCost: 0}), {ok: false, reason: "daily_chest_price_changed"});
  const dearer = {...DEFAULT_ECONOMY, spend: {...DEFAULT_ECONOMY.spend, dailyChest: 25}};
  assert.deepEqual(plan({config: dearer, maxCost: 8}), {ok: false, reason: "daily_chest_price_changed"});
  assert.deepEqual(plan({config: dearer, maxCost: 25}), {ok: true, free: false, cost: 25});
});

test("planDailyChest: a free chest ignores a higher price and a lower balance", () => {
  const dearer = {...DEFAULT_ECONOMY, spend: {...DEFAULT_ECONOMY.spend, dailyChest: 500}};
  assert.deepEqual(plan({config: dearer, quests: itemsDone(), balance: 0, maxCost: 0}),
    {ok: true, free: true, cost: 0});
});

test("planDailyChest: refuses a short balance, and checks the price first", () => {
  assert.deepEqual(plan({balance: 7}), {ok: false, reason: "daily_chest_insufficient_balance"});
  assert.deepEqual(plan({balance: 7, maxCost: 5}), {ok: false, reason: "daily_chest_price_changed"});
});

test("planDailyChest: a price of 0 is a paid chest that costs nothing", () => {
  const cheap = {...DEFAULT_ECONOMY, spend: {...DEFAULT_ECONOMY.spend, dailyChest: 0}};
  assert.deepEqual(plan({config: cheap, balance: 0, maxCost: 0}), {ok: true, free: false, cost: 0});
});

test("planDailyChest: an opened chest is refused before price and balance are looked at", () => {
  const opened = {...itemsDone(), chestOpened: true};
  assert.deepEqual(plan({quests: opened}), {ok: false, reason: "daily_chest_already_opened"});
  assert.deepEqual(plan({quests: opened, balance: 0, maxCost: 0}), {ok: false, reason: "daily_chest_already_opened"});
  assert.deepEqual(plan({receipt: {requestId: "another_request"}, balance: 0, maxCost: 0}),
    {ok: false, reason: "daily_chest_already_opened"});
});

test("storedDailyChestWin: only the request that wrote the receipt gets its win back", () => {
  const win = {success: true, prize: {kind: "coins", coins: 5, xp: 0, itemId: null}};
  const receipt = {requestId: "chest_request_1", replay: win};
  assert.deepEqual(storedDailyChestWin(receipt, "chest_request_1"), win);
  assert.equal(storedDailyChestWin(receipt, "chest_request_2"), null);
  assert.equal(storedDailyChestWin(undefined, "chest_request_1"), null);
  assert.equal(storedDailyChestWin({requestId: "chest_request_1", coins: 5, doubled: false}, "chest_request_1"), null);
});

test("rollDailyChest: the roll picks the slot and the prize from the table", () => {
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, fresh(), [], () => 0.1),
    {slot: 0, doubled: false, prize: {kind: "coins", coins: 5, xp: 0, itemId: null}});
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, fresh(), [], () => 0.5),
    {slot: 1, doubled: false, prize: {kind: "coins", coins: 8, xp: 0, itemId: null}});
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, fresh(), [], () => 0.7),
    {slot: 2, doubled: false, prize: {kind: "coins", coins: 12, xp: 0, itemId: null}});
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, fresh(), [], () => 0.995),
    {slot: 6, doubled: false, prize: {kind: "coins", coins: 100, xp: 0, itemId: null}});
});

test("rollDailyChest: a claimed bonus doubles the coins and no prize carries XP", () => {
  const quests = withBonus(fresh());
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, quests, [], () => 0.5),
    {slot: 1, doubled: true, prize: {kind: "coins", coins: 16, xp: 0, itemId: null}});
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, quests, [], () => 0.995),
    {slot: 6, doubled: true, prize: {kind: "coins", coins: 200, xp: 0, itemId: null}});
});

/** A random source that returns `values` in order, then 0. */
const sequence = (...values: number[]) => {
  const queue = [...values];
  return () => queue.shift() ?? 0;
};

test("rollDailyChest: a cosmetic stays one item when doubled, and its fallback coins double", () => {
  const quests = withBonus(fresh());
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, quests, [], sequence(0.9, 0)),
    {slot: 4, doubled: true, prize: {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_rose"}});
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, quests, commonIds, () => 0.9),
    {slot: 4, doubled: true, prize: {kind: "cosmetic", coins: 50, xp: 0, itemId: null}});
  assert.deepEqual(rollDailyChest(DEFAULT_ECONOMY, fresh(), commonIds, () => 0.9),
    {slot: 4, doubled: false, prize: {kind: "cosmetic", coins: 25, xp: 0, itemId: null}});
});

const request = (data: Record<string, unknown>) =>
  ({auth: {uid: "user-1"}, data}) as unknown as Parameters<typeof openDailyChest.run>[0];
const open = (requestId = "chest_request_1", maxCost = 8, extra: Record<string, unknown> = {}) =>
  openDailyChest.run(request({requestId, maxCost, ...extra}));
const legacyOpen = (requestId = "legacy_request") =>
  openQuestChest.run(request({requestId}) as unknown as Parameters<typeof openQuestChest.run>[0]);

function won(reply: DailyChestReply): DailyChestReply & DailyChestWin {
  if (!reply.success) assert.fail(`refused: ${reply.reason}`);
  return reply as DailyChestReply & DailyChestWin;
}

function setup(t: test.TestContext, user: Doc, priv?: Doc, extra: Record<string, Doc> = {}) {
  t.mock.method(Date, "now", () => NOW);
  return installFakeDb(t, {[USER]: user, ...(priv ? {[PRIVATE]: priv} : {}), ...extra});
}

/** Rolls that land on a slot of the default table. The weights sum to 100, so a roll is a percentage point. */
const ROLL = {coins5: 0.1, coins8: 0.5, coins12: 0.7, coins20: 0.8, cosmetic: 0.9, coins40: 0.97, coins100: 0.995};

function rolls(t: test.TestContext, ...values: number[]): void {
  const queue = [...values];
  t.mock.method(Math, "random", () => queue.shift() ?? 0);
}

const ledger = (store: ReturnType<typeof installFakeDb>) =>
  [...store.keys()].filter((path) => path.startsWith("coinTransactions/ctx_questChest_"));

test("openDailyChest: with all three quests claimed the chest is free and pays the whole prize", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 0}, {rev: 3, quests: itemsDone()});
  const reply = await open("chest_request_1", 0);
  assert.deepEqual(reply, {
    success: true,
    changed: true,
    previousBalance: 0,
    currentBalance: 8,
    delta: 8,
    reason: "daily_chest",
    transactionId: "ctx_questChest_user-1_2026-10-18",
    insufficientBalance: false,
    status: {opened: true, free: true, price: 8},
    cost: 0,
    free: true,
    doubled: false,
    slot: 1,
    prize: {kind: "coins", coins: 8, xp: 0, itemId: null},
    slots: TABLE,
    quests: {...itemsDone(), chestOpened: true, chestDoubled: false},
    rev: 4,
    ...xpFields(10, 10, 10),
  });
  const user = store.get(USER) ?? {};
  assert.equal(user.coins, 8);
  assert.equal(user.xp, 10);
  assert.deepEqual(user.xpWeek, {weekKey: WEEK, xp: 10});
  const priv = store.get(PRIVATE) ?? {};
  assert.equal(priv.rev, 4);
  assert.deepEqual(priv.quests, {...itemsDone(), chestOpened: true, chestDoubled: false});
});

test("openDailyChest: an unfinished day costs 8, debits it, pays the prize and marks the chest opened", async (t) => {
  rolls(t, ROLL.coins5);
  const store = setup(t, {coins: 25}, {rev: 4, quests: fresh()});
  const reply = won(await open("chest_request_1", 8, {sourceTag: "rewards.chest"}));
  assert.equal(reply.cost, 8);
  assert.equal(reply.free, false);
  assert.equal(reply.slot, 0);
  assert.deepEqual(reply.prize, {kind: "coins", coins: 5, xp: 0, itemId: null});
  assert.equal(reply.previousBalance, 25);
  assert.equal(reply.currentBalance, 22);
  assert.equal(reply.delta, -3);
  assert.deepEqual(reply.status, {opened: true, free: false, price: 8});
  assert.equal(reply.quests.chestOpened, true);
  assert.equal(reply.quests.chestDoubled, false);
  assert.equal(reply.rev, 5);
  const user = store.get(USER) ?? {};
  assert.equal(user.coins, 22);
  assert.equal(user.xp, 10);
  const priv = store.get(PRIVATE) ?? {};
  assert.equal(priv.rev, 5);
  assert.equal((priv.quests as QuestState).chestOpened, true);
  assert.deepEqual((priv.quests as QuestState).items, fresh().items);
  assert.equal(priv.inventory, undefined);
});

test("openDailyChest: every prize, paid or free, grants the chest's 10 XP and nothing else", async (t) => {
  const prizeCoins = {coins5: 5, coins8: 8, coins12: 12, coins20: 20, cosmetic: 0, coins40: 40, coins100: 100};
  for (const [name, roll] of Object.entries(ROLL)) {
    for (const free of [false, true]) {
      await t.test(`${name} ${free ? "free" : "paid"}`, async (sub) => {
        resetEconomyCache();
        rolls(sub, roll, 0);
        const store = setup(sub, {coins: 50, xp: 100, xpWeek: {weekKey: WEEK, xp: 20}},
          {rev: 1, quests: free ? itemsDone() : fresh()});
        const reply = won(await open("chest_request_1", free ? 0 : 8));
        const coins = prizeCoins[name as keyof typeof prizeCoins];
        assert.equal(reply.prize.coins, coins);
        assert.equal(reply.currentBalance, 50 - (free ? 0 : 8) + coins);
        assert.deepEqual(xpOf(reply), xpFields(110, 30, 10));
        assert.equal(store.get(USER)?.xp, 110);
        assert.deepEqual(store.get(USER)?.xpWeek, {weekKey: WEEK, xp: 30});
      });
    }
  }
});

test("openDailyChest: the XP is the configured chest activity, whatever the prize or the coin rate", async (t) => {
  for (const questChest of [0, 25]) {
    await t.test(`xp.activities.questChest ${questChest}`, async (sub) => {
      resetEconomyCache();
      rolls(sub, ROLL.coins100);
      const store = setup(sub, {coins: 0, xp: 40}, {rev: 1, quests: withBonus(itemsDone())},
        {[ECONOMY_CONFIG_DOC]: {xp: {perCoinEarned: 10, activities: {questChest}}}});
      const reply = won(await open("chest_request_1", 0));
      assert.equal(reply.prize.coins, 200);
      assert.equal(reply.xpAwarded, questChest);
      assert.equal(reply.xp, 40 + questChest);
      assert.equal(store.get(USER)?.xp, 40 + questChest);
    });
  }
});

test("openDailyChest: the ledger doc is the receipt the 3.6.0 chest reads, with the new fields on top", async (t) => {
  rolls(t, ROLL.coins20);
  const store = setup(t, {coins: 25}, {rev: 1});
  won(await open("chest_request_1", 8, {sourceTag: "rewards.chest"}));
  assert.deepEqual(ledger(store), [RECEIPT]);
  const receipt = store.get(RECEIPT) ?? {};
  assert.equal(receipt.id, "ctx_questChest_user-1_2026-10-18");
  assert.equal(receipt.userId, "user-1");
  assert.equal(receipt.action, "questChest");
  assert.equal(receipt.reason, "daily_chest");
  assert.equal(receipt.sourceTag, "rewards.chest");
  assert.equal(receipt.description, "Daily chest (+12)");
  assert.equal(receipt.type, "credit");
  assert.equal(receipt.status, "completed");
  assert.equal(receipt.delta, 12);
  assert.equal(receipt.balanceBefore, 25);
  assert.equal(receipt.balanceAfter, 37);
  assert.equal(receipt.requestId, "chest_request_1");
  assert.equal(receipt.cost, 8);
  assert.equal(receipt.free, false);
  assert.equal(receipt.doubled, false);
  assert.equal(receipt.slot, 3);
  assert.deepEqual(receipt.prize, {kind: "coins", coins: 20, xp: 0, itemId: null});
  assert.equal(receipt.coins, 20);
  assert.equal(receipt.itemId, null);
  assert.deepEqual(receipt.replay, {
    success: true,
    changed: true,
    previousBalance: 25,
    currentBalance: 37,
    delta: 12,
    reason: "daily_chest",
    transactionId: "ctx_questChest_user-1_2026-10-18",
    insufficientBalance: false,
    status: {opened: true, free: false, price: 8},
    cost: 8,
    free: false,
    doubled: false,
    slot: 3,
    prize: {kind: "coins", coins: 20, xp: 0, itemId: null},
    slots: TABLE,
  });
});

test("openDailyChest: a net loss reads as a debit and the default source tag names the callable", async (t) => {
  rolls(t, ROLL.coins5);
  const store = setup(t, {coins: 25}, {rev: 1});
  await open();
  const receipt = store.get(RECEIPT) ?? {};
  assert.equal(receipt.description, "Daily chest (-3)");
  assert.equal(receipt.type, "debit");
  assert.equal(receipt.delta, -3);
  assert.equal(receipt.balanceAfter, 22);
  assert.equal(receipt.sourceTag, "quests.daily_chest.callable");
});

test("openDailyChest: a free cosmetic chest has a zero coin delta and still pays the XP", async (t) => {
  rolls(t, ROLL.cosmetic, 0);
  const store = setup(t, {coins: 4}, {rev: 1, quests: itemsDone()});
  const reply = won(await open("chest_request_1", 0));
  assert.equal(reply.delta, 0);
  assert.equal(reply.currentBalance, 4);
  assert.equal(reply.xpAwarded, 10);
  assert.equal(store.get(USER)?.xp, 10);
  const receipt = store.get(RECEIPT) ?? {};
  assert.equal(receipt.description, "Daily chest (+0)");
  assert.equal(receipt.delta, 0);
});

test("openDailyChest: the reply carries the table the server rolled, not the default one", async (t) => {
  rolls(t, 0.9);
  const table = [{kind: "coins", coins: 7, weight: 1}, {kind: "coins", coins: 9, weight: 3}];
  const store = setup(t, {coins: 50}, undefined, {[ECONOMY_CONFIG_DOC]: {award: {dailyChest: table}}});
  const reply = won(await open());
  assert.equal(reply.slot, 1);
  assert.deepEqual(reply.slots, table);
  assert.deepEqual(reply.prize, {kind: "coins", coins: 9, xp: 0, itemId: null});
  assert.deepEqual(store.get(RECEIPT)?.prize, {kind: "coins", coins: 9, xp: 0, itemId: null});
});

test("openDailyChest: a configured table with an XP slot falls back to the default table and pays no prize XP", async (t) => {
  rolls(t, ROLL.coins12);
  const table = [{kind: "coins", coins: 7, weight: 1}, {kind: "xp", xp: 9, weight: 3}];
  const store = setup(t, {coins: 50}, undefined, {[ECONOMY_CONFIG_DOC]: {award: {dailyChest: table}}});
  const reply = won(await open());
  assert.deepEqual(reply.slots, TABLE);
  assert.equal(reply.slot, 2);
  assert.deepEqual(reply.prize, {kind: "coins", coins: 12, xp: 0, itemId: null});
  assert.equal(reply.xpAwarded, 10);
  assert.equal(store.get(USER)?.xp, 10);
});

test("openDailyChest: a claimed bonus doubles the coins, not the XP", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 100}, {rev: 1, quests: withBonus(itemsDone())});
  const reply = won(await open("chest_request_1", 0));
  assert.equal(reply.doubled, true);
  assert.deepEqual(reply.prize, {kind: "coins", coins: 16, xp: 0, itemId: null});
  assert.equal(reply.delta, 16);
  assert.equal(reply.currentBalance, 116);
  assert.equal(reply.quests.chestDoubled, true);
  assert.equal(reply.xpAwarded, 10);
  assert.equal(reply.xp, 10);
  assert.equal(store.get(USER)?.xp, 10);
  const receipt = store.get(RECEIPT) ?? {};
  assert.equal(receipt.doubled, true);
  assert.equal(receipt.coins, 16);
  assert.deepEqual((store.get(PRIVATE)?.quests as QuestState).chestDoubled, true);
});

test("openDailyChest: a doubled paid chest doubles the coins, still costs 8 and pays 10 XP", async (t) => {
  rolls(t, ROLL.coins12);
  const store = setup(t, {coins: 20}, {rev: 1, quests: withBonus(fresh())});
  const reply = won(await open());
  assert.deepEqual(reply.prize, {kind: "coins", coins: 24, xp: 0, itemId: null});
  assert.equal(reply.delta, 16);
  assert.equal(store.get(USER)?.coins, 36);
  assert.equal(store.get(USER)?.xp, 10);
  assert.deepEqual(store.get(USER)?.xpWeek, {weekKey: WEEK, xp: 10});
});

test("openDailyChest: an unclaimed bonus leaves the prize as rolled", async (t) => {
  rolls(t, ROLL.coins40);
  const store = setup(t, {coins: 100}, {rev: 1, quests: itemsDone()});
  const reply = won(await open("chest_request_1", 0));
  assert.equal(reply.doubled, false);
  assert.deepEqual(reply.prize, {kind: "coins", coins: 40, xp: 0, itemId: null});
  assert.equal(store.get(USER)?.coins, 140);
});

test("openDailyChest: a cosmetic prize is written to the inventory next to what the user owns", async (t) => {
  rolls(t, ROLL.cosmetic, 0);
  const store = setup(t, {coins: 50}, {rev: 2, inventory: {owned: {glow_ember: 5}}});
  const reply = won(await open());
  assert.equal(reply.slot, 4);
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_rose"});
  assert.equal(reply.delta, -8);
  assert.equal(reply.currentBalance, 42);
  assert.equal(store.get(USER)?.xp, 10);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {glow_ember: 5, theme_rose: NOW}});
  const receipt = store.get(RECEIPT) ?? {};
  assert.equal(receipt.itemId, "theme_rose");
  assert.equal(receipt.coins, 0);
});

test("openDailyChest: a doubled cosmetic is still one item", async (t) => {
  rolls(t, ROLL.cosmetic, 0);
  const store = setup(t, {coins: 50}, {rev: 2, quests: withBonus(itemsDone())});
  const reply = won(await open("chest_request_1", 0));
  assert.equal(reply.doubled, true);
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_rose"});
  assert.equal(reply.currentBalance, 50);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {theme_rose: NOW}});
});

test("openDailyChest: a cosmetic slot pays its fallback coins when every common item is owned", async (t) => {
  rolls(t, ROLL.cosmetic);
  const owned = Object.fromEntries(commonIds.map((id) => [id, 1]));
  const store = setup(t, {coins: 50}, {rev: 2, inventory: {owned}});
  const reply = won(await open());
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 25, xp: 0, itemId: null});
  assert.equal(reply.delta, 17);
  assert.equal(reply.currentBalance, 67);
  assert.equal(store.get(USER)?.xp, 10);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned});
});

test("openDailyChest: the fallback coins double with the bonus", async (t) => {
  rolls(t, ROLL.cosmetic);
  const owned = Object.fromEntries(commonIds.map((id) => [id, 1]));
  const store = setup(t, {coins: 50}, {rev: 2, quests: withBonus(itemsDone()), inventory: {owned}});
  const reply = won(await open("chest_request_1", 0));
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 50, xp: 0, itemId: null});
  assert.equal(reply.currentBalance, 100);
  assert.equal(store.get(USER)?.xp, 10);
});

test("openDailyChest: the 10 XP that crosses a rank lands the rank reward in inventory.owned with the purchases", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 50, xp: 495}, {rev: 2, inventory: {owned: {glow_ember: 5}}});
  const reply = won(await open());
  assert.equal(reply.xp, 505);
  assert.equal(reply.rev, 3);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {glow_ember: 5, glow_aurora: NOW}});
  assert.equal(store.get(PRIVATE)?.rev, 3);
});

test("openDailyChest: a rank reward and a cosmetic prize land together, and the prize skips the reward", async (t) => {
  rolls(t, ROLL.cosmetic, 0);
  const store = setup(t, {coins: 50, xp: 495}, {rev: 2, inventory: {owned: {glow_ember: 5}}});
  const reply = won(await open());
  assert.deepEqual(reply.prize, {kind: "cosmetic", coins: 0, xp: 0, itemId: "theme_rose"});
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {glow_ember: 5, glow_aurora: NOW, theme_rose: NOW}});
});

test("openDailyChest: a rank reward the user already owns keeps its original date", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 50, xp: 495}, {rev: 2, inventory: {owned: {glow_aurora: 7}}});
  won(await open());
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {glow_aurora: 7}});
});

test("openDailyChest: a price above maxCost is refused and writes nothing, then works at the new price", async (t) => {
  rolls(t, ROLL.coins12);
  const store = setup(t, {coins: 100}, {rev: 1, quests: fresh()},
    {[ECONOMY_CONFIG_DOC]: {spend: {dailyChest: 25}}});
  const refused = await open("chest_request_1", 8);
  assert.deepEqual(refused, {
    success: false,
    changed: false,
    previousBalance: 100,
    currentBalance: 100,
    delta: 0,
    reason: "daily_chest_price_changed",
    transactionId: "",
    insufficientBalance: false,
    status: {opened: false, free: false, price: 25},
    quests: fresh(),
    rev: 1,
    ...xpFields(0, 0, 0),
  });
  assert.equal(store.get(USER)?.coins, 100);
  assert.equal(store.get(PRIVATE)?.rev, 1);
  assert.equal(ledger(store).length, 0);
  const reply = won(await open("chest_request_1", 25));
  assert.equal(reply.cost, 25);
  assert.equal(store.get(USER)?.coins, 87);
  assert.equal(store.get(USER)?.xp, 10);
});

test("openDailyChest: a client that showed 'free' is refused, not charged, when a quest is not claimed", async (t) => {
  const store = setup(t, {coins: 100}, {rev: 1, quests: fresh()});
  const refused = await open("chest_request_1", 0);
  assert.equal(refused.success, false);
  assert.equal(refused.reason, "daily_chest_price_changed");
  assert.equal(store.get(USER)?.coins, 100);
  assert.equal(ledger(store).length, 0);
});

test("openDailyChest: a client that showed the price pays nothing when the chest became free", async (t) => {
  rolls(t, ROLL.coins5);
  const store = setup(t, {coins: 100}, {rev: 1, quests: itemsDone()});
  const reply = won(await open("chest_request_1", 8));
  assert.equal(reply.cost, 0);
  assert.equal(reply.free, true);
  assert.equal(reply.currentBalance, 105);
  assert.equal(store.get(USER)?.coins, 105);
});

test("openDailyChest: a balance under the price is refused with insufficientBalance and nothing changes", async (t) => {
  const store = setup(t, {coins: 7}, {rev: 3, quests: fresh()});
  const refused = await open();
  assert.deepEqual(refused, {
    success: false,
    changed: false,
    previousBalance: 7,
    currentBalance: 7,
    delta: 0,
    reason: "daily_chest_insufficient_balance",
    transactionId: "",
    insufficientBalance: true,
    status: {opened: false, free: false, price: 8},
    quests: fresh(),
    rev: 3,
    ...xpFields(0, 0, 0),
  });
  assert.equal(store.get(USER)?.coins, 7);
  assert.equal(store.get(USER)?.xp, undefined);
  assert.equal(store.get(PRIVATE)?.rev, 3);
  assert.equal(ledger(store).length, 0);
});

test("openDailyChest: a refused request leaves the id free, so it works after the user tops up", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 7}, {rev: 1});
  assert.equal((await open()).success, false);
  store.set(USER, {coins: 30});
  const reply = won(await open());
  assert.equal(reply.currentBalance, 30);
  assert.equal(reply.xpAwarded, 10);
  assert.equal(ledger(store).length, 1);
});

test("openDailyChest: a second request id on the same day is refused and charged nothing", async (t) => {
  rolls(t, ROLL.coins8, ROLL.coins100);
  const store = setup(t, {coins: 50}, {rev: 1});
  const first = won(await open("chest_request_1"));
  const second = await open("chest_request_2");
  assert.equal(second.success, false);
  assert.equal(second.reason, "daily_chest_already_opened");
  assert.equal(second.insufficientBalance, false);
  assert.deepEqual(second.status, {opened: true, free: false, price: 8});
  assert.equal(second.previousBalance, first.currentBalance);
  assert.equal(second.currentBalance, first.currentBalance);
  assert.equal(second.delta, 0);
  assert.deepEqual(xpOf(second), xpFields(10, 10, 0));
  assert.equal(store.get(USER)?.coins, 50);
  assert.equal(store.get(USER)?.xp, 10);
  assert.equal(ledger(store).length, 1);
  assert.equal(store.get(PRIVATE)?.rev, 2);
});

test("openDailyChest: a free second request is refused too, even with a lower maxCost than the price", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 0}, {rev: 1, quests: itemsDone()});
  won(await open("chest_request_1", 0));
  const second = await open("chest_request_2", 0);
  assert.equal(second.reason, "daily_chest_already_opened");
  assert.equal(second.xpAwarded, 0);
  assert.equal(store.get(USER)?.coins, 8);
  assert.equal(store.get(USER)?.xp, 10);
});

test("openDailyChest: a refusal grants no XP and carries the live receipt of the current week", async (t) => {
  const oldWeek = {weekKey: "2026-W41", xp: 300};
  const user = {coins: 7, xp: 6000, xpWeek: oldWeek};
  const store = setup(t, user, {rev: 1, quests: fresh()});
  const live = xpFields(6000, 0, 0);

  const short = await open();
  assert.equal(short.reason, "daily_chest_insufficient_balance");
  assert.deepEqual(xpOf(short), live);

  const dearer = await open("chest_request_1", 5);
  assert.equal(dearer.reason, "daily_chest_price_changed");
  assert.deepEqual(xpOf(dearer), live);

  store.set(PRIVATE, {rev: 1, quests: {...fresh(), chestOpened: true}});
  const opened = await open();
  assert.equal(opened.reason, "daily_chest_already_opened");
  assert.deepEqual(xpOf(opened), live);

  assert.deepEqual(store.get(USER), user);
  assert.equal(ledger(store).length, 0);
});

test("openDailyChest: after the 3.6.0 openQuestChest the same day is refused and the balance stays", async (t) => {
  const store = setup(t, {coins: 40}, {rev: 1, quests: itemsDone()});
  const legacy = await legacyOpen();
  assert.equal(legacy.success, true);
  const balance = store.get(USER)?.coins;
  assert.equal(store.get(USER)?.xp, 10);
  const refused = await open("chest_request_1", 0);
  assert.equal(refused.success, false);
  assert.equal(refused.reason, "daily_chest_already_opened");
  assert.deepEqual(refused.status, {opened: true, free: true, price: 8});
  assert.deepEqual(xpOf(refused), xpFields(10, 10, 0));
  assert.equal(store.get(USER)?.coins, balance);
  assert.equal(store.get(USER)?.xp, 10);
  assert.equal(ledger(store).length, 1);
  const again = await open("legacy_request", 0);
  assert.equal(again.reason, "daily_chest_already_opened");
  assert.equal(store.get(USER)?.coins, balance);
  assert.equal(store.get(USER)?.xp, 10);
});

test("openDailyChest: after this callable, the 3.6.0 openQuestChest refuses and the balance and XP stay", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 40}, {rev: 1, quests: itemsDone()});
  won(await open("chest_request_1", 0));
  const balance = store.get(USER)?.coins;
  const refused = await legacyOpen("legacy_request");
  assert.equal(refused.success, false);
  assert.equal(refused.reason, "quest_chest_already_opened");
  assert.equal(refused.xpAwarded, 0);
  assert.equal(store.get(USER)?.coins, balance);
  assert.equal(store.get(USER)?.xp, 10);
  assert.equal(ledger(store).length, 1);
});

test("openDailyChest: after a paid open, the 3.6.0 openQuestChest still refuses as already opened", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 40}, {rev: 1, quests: fresh()});
  won(await open());
  const balance = store.get(USER)?.coins;
  const refused = await legacyOpen("legacy_request");
  assert.equal(refused.reason, "quest_chest_already_opened");
  assert.equal(store.get(USER)?.coins, balance);
  assert.equal(store.get(USER)?.xp, 10);
});

test("openDailyChest: a retried request returns the same prize with the live balance, delta 0 and no second charge", async (t) => {
  rolls(t, ROLL.coins20);
  const store = setup(t, {coins: 50}, {rev: 1});
  const first = won(await open());
  assert.equal(first.currentBalance, 62);
  assert.deepEqual(xpOf(first), xpFields(10, 10, 10));
  store.set(USER, {...store.get(USER), coins: 55});
  rolls(t, ROLL.coins100);
  const retry = await open("chest_request_1", 0);
  assert.deepEqual(retry, {
    ...first,
    previousBalance: 55,
    currentBalance: 55,
    delta: 0,
    status: {opened: true, free: false, price: 8},
    xpAwarded: 0,
  });
  assert.deepEqual(retry.success && retry.prize, {kind: "coins", coins: 20, xp: 0, itemId: null});
  assert.equal(store.get(USER)?.coins, 55);
  assert.equal(store.get(USER)?.xp, 10);
  assert.equal(ledger(store).length, 1);
  assert.equal(store.get(PRIVATE)?.rev, 2);
});

test("openDailyChest: a replay grants no second XP and reports the live XP, not the stored one", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 50}, {rev: 1});
  won(await open());
  store.set(USER, {...store.get(USER), xp: 900, xpWeek: {weekKey: WEEK, xp: 300}});
  const retry = won(await open());
  assert.deepEqual(xpOf(retry), xpFields(900, 300, 0));
  assert.equal(store.get(USER)?.xp, 900);
  assert.deepEqual(store.get(USER)?.xpWeek, {weekKey: WEEK, xp: 300});
  store.set(USER, {...store.get(USER), xpWeek: {weekKey: "2026-W41", xp: 300}});
  assert.deepEqual(xpOf(won(await open())), xpFields(900, 0, 0));
  assert.deepEqual(store.get(USER)?.xpWeek, {weekKey: "2026-W41", xp: 300});
});

test("openDailyChest: a replay reports today's quest state and rev, so the client adopts them", async (t) => {
  rolls(t, ROLL.coins8);
  const store = setup(t, {coins: 50}, {rev: 1});
  const first = won(await open());
  const progressed: QuestState = {...first.quests, weekly: {...first.quests.weekly, progress: 2}};
  store.set(PRIVATE, {...store.get(PRIVATE), rev: 6, quests: progressed});
  const retry = await open();
  assert.equal(retry.rev, 6);
  assert.deepEqual(retry.quests, progressed);
  assert.equal(retry.success && retry.prize.coins, 8);
});

test("openDailyChest: a replay of a doubled cosmetic returns the same item and writes nothing", async (t) => {
  rolls(t, ROLL.cosmetic, 0);
  const store = setup(t, {coins: 50}, {rev: 2, quests: withBonus(itemsDone())});
  const first = won(await open("chest_request_1", 0));
  rolls(t, ROLL.coins100);
  const retry = won(await open("chest_request_1", 0));
  assert.deepEqual(retry.prize, first.prize);
  assert.equal(retry.doubled, true);
  assert.equal(retry.delta, 0);
  assert.equal(retry.xpAwarded, 0);
  assert.equal(store.get(USER)?.xp, 10);
  assert.deepEqual(store.get(PRIVATE)?.inventory, {owned: {theme_rose: NOW}});
  assert.equal(ledger(store).length, 1);
});

test("openDailyChest: a new UTC day opens a new chest even after yesterday's", async (t) => {
  let now = NOW;
  t.mock.method(Date, "now", () => now);
  rolls(t, ROLL.coins8, ROLL.coins5);
  const store = installFakeDb(t, {[USER]: {coins: 50}});
  const first = won(await open("chest_request_1"));
  assert.equal(first.currentBalance, 50);
  now = NOW + DAY_MS;
  resetEconomyCache();
  const next = won(await open("chest_request_2"));
  assert.equal(next.transactionId, "ctx_questChest_user-1_2026-10-19");
  assert.equal(next.previousBalance, 50);
  assert.equal(next.currentBalance, 47);
  assert.equal(next.quests.dayKey, "2026-10-19");
  assert.deepEqual(xpOf(next), xpFields(20, 10, 10, NEXT_WEEK));
  assert.deepEqual(store.get(USER)?.xpWeek, {weekKey: NEXT_WEEK, xp: 10});
  assert.deepEqual(ledger(store).sort(), [
    "coinTransactions/ctx_questChest_user-1_2026-10-18",
    "coinTransactions/ctx_questChest_user-1_2026-10-19",
  ]);
});

test("openDailyChest: bad requestId or maxCost is invalid-argument and writes nothing", async (t) => {
  const store = setup(t, {coins: 100}, {rev: 1});
  for (const requestId of [undefined, 12345678, "short", "bad/path_123", "x".repeat(65)]) {
    await assert.rejects(() => openDailyChest.run(request({requestId, maxCost: 8})), {code: "invalid-argument"},
      String(requestId));
  }
  for (const maxCost of [undefined, null, -1, 10_001, 1.5, "8", Number.NaN, Infinity, [8]]) {
    await assert.rejects(() => openDailyChest.run(request({requestId: "chest_request_1", maxCost})),
      {code: "invalid-argument"}, String(maxCost));
  }
  assert.equal(store.get(USER)?.coins, 100);
  assert.equal(store.get(PRIVATE)?.rev, 1);
  assert.equal(ledger(store).length, 0);
});

test("openDailyChest: needs a signed-in user with a profile", async (t) => {
  setup(t, {coins: 100});
  const data = {requestId: "chest_request_1", maxCost: 8};
  await assert.rejects(() => openDailyChest.run({data} as unknown as Parameters<typeof openDailyChest.run>[0]),
    {code: "unauthenticated"});
  await assert.rejects(
    () => openDailyChest.run({auth: {uid: "ghost"}, data} as unknown as Parameters<typeof openDailyChest.run>[0]),
    {code: "not-found"});
});
