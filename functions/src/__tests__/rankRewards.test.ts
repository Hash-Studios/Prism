import assert from "node:assert/strict";
import test, {beforeEach} from "node:test";
import {badgeIo, checkBadges} from "../badges";
import {awardCoins, claimProSpin, spinWheel} from "../coinsCallables";
import {DEFAULT_ECONOMY, resetEconomyCache, weekKey} from "../economy";
import {buildQuestState} from "../questCatalog";
import {openQuestChest, progressQuest} from "../quests";
import {rankRewardsFor, reconcileRankRewards} from "../rankRewards";
import {equipCosmetic, purchaseShopItem} from "../shop";
import {claimDailyStreak} from "../streak";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.parse("2026-10-14T12:00:00Z");
const USER = "usersv2/u1";
const PRIVATE = `${USER}/private/economy`;
const REWARDS = ["frame_gold", "glow_aurora", "glow_prism"];
const call = <T>(fn: {run: (request: never) => Promise<T>}, data: Doc = {}) =>
  fn.run({auth: {uid: "u1", token: {email: "u1@example.com"}}, data} as never);
const owned = (store: Map<string, Doc>) =>
  (store.get(PRIVATE) as {inventory: {owned: Record<string, number>}}).inventory.owned;

beforeEach(() => resetEconomyCache());

test("rank rewards grant exact configured thresholds, all crossed milestones, and preserve purchases", () => {
  assert.deepEqual(rankRewardsFor(499, {}, DEFAULT_ECONOMY, NOW).added, []);
  assert.deepEqual(rankRewardsFor(500, {}, DEFAULT_ECONOMY, NOW).added, ["glow_aurora"]);
  assert.deepEqual(rankRewardsFor(1999, {}, DEFAULT_ECONOMY, NOW).added, ["glow_aurora"]);
  assert.deepEqual(rankRewardsFor(2000, {}, DEFAULT_ECONOMY, NOW).added, ["frame_gold", "glow_aurora"]);
  const bought = {glow_aurora: 17, frame_ring: 23};
  const plan = rankRewardsFor(6000, bought, DEFAULT_ECONOMY, NOW);
  assert.deepEqual(plan.added, ["frame_gold", "glow_prism"]);
  assert.deepEqual(plan.owned, {...bought, frame_gold: NOW, glow_prism: NOW});
  assert.deepEqual(rankRewardsFor(0, plan.owned, DEFAULT_ECONOMY, NOW + 1).owned, plan.owned);
});

test("reward eligibility follows configured rank IDs and thresholds without inventing custom rewards", () => {
  const config = {...DEFAULT_ECONOMY, xp: {...DEFAULT_ECONOMY.xp,
    ranks: [{id: "bronze", min: 0}, {id: "silver", min: 25}, {id: "custom", min: 30}, {id: "prism", min: 40}]}};
  assert.deepEqual(rankRewardsFor(24, {}, config, NOW).added, []);
  assert.deepEqual(rankRewardsFor(30, {}, config, NOW).added, ["glow_aurora"]);
  assert.deepEqual(rankRewardsFor(40, {}, config, NOW).added, ["glow_aurora", "glow_prism"]);
  assert.deepEqual(rankRewardsFor(Number.NaN, {}, config, NOW).added, []);
});

test("reconcile repairs an older account once, preserving all other state and writing no receipts", async (t) => {
  t.mock.method(Date, "now", () => NOW);
  const user = {coins: 0, xp: 6000, xpWeek: {weekKey: "old", xp: 7}, cosmetics: {frame: "frame_ring"}};
  const privateState = {rev: 8, quests: {chestOpened: true}, passes: {premiumPassUntil: 123},
    inventory: {owned: {glow_aurora: 12, theme_rose: 16}}};
  const store = installFakeDb(t, {[USER]: user, [PRIVATE]: privateState});
  const result = await call(reconcileRankRewards, {sourceTag: "coins.rank_rewards.reconcile"});
  assert.deepEqual(result.added, ["frame_gold", "glow_prism"]);
  assert.equal(result.inventoryChanged, true);
  assert.equal(result.rev, 9);
  assert.equal(result.xp, 6000);
  assert.deepEqual(result.xpWeek, {weekKey: weekKey(NOW), xp: 0});
  assert.deepEqual(store.get(USER), user);
  assert.equal(owned(store).glow_aurora, 12);
  assert.deepEqual(store.get(PRIVATE)?.quests, privateState.quests);
  assert.deepEqual(store.get(PRIVATE)?.passes, privateState.passes);
  const replay = await call(reconcileRankRewards);
  assert.equal(replay.inventoryChanged, false);
  assert.equal(replay.rev, 9);
  assert.deepEqual(replay.added, []);
  assert.deepEqual([...store.keys()], [USER, PRIVATE]);
});

test("reconcile creates missing inventory only when eligible and validates its boundary", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 0, xp: 499}});
  assert.equal((await call(reconcileRankRewards)).rev, 0);
  assert.equal(store.has(PRIVATE), false);
  store.set(USER, {coins: 0, xp: 500});
  assert.equal((await call(reconcileRankRewards)).rev, 1);
  assert.deepEqual(Object.keys(owned(store)), ["glow_aurora"]);
  await assert.rejects(() => call(reconcileRankRewards, {xp: 6000}), {code: "invalid-argument"});
  await assert.rejects(() => reconcileRankRewards.run({data: {}} as never), {code: "unauthenticated"});
});

test("old-client reward purchases never charge or create spend receipts, including config price overrides", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 0, xp: 6000},
    "economyConfig/current": {shopPrices: {glow_prism: 9999, frame_gold: 9999}}});
  const result = await call(purchaseShopItem, {itemId: "frame_gold", requestId: "reward-request-1"});
  assert.equal(result.success, false);
  assert.equal(result.reason, "shop_item_owned");
  assert.equal(result.inventoryChanged, true);
  assert.equal(result.delta, 0);
  assert.equal(result.currentBalance, 0);
  assert.deepEqual(result.owned.sort(), REWARDS);
  assert.equal(store.get(USER)?.coins, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("coinTransactions/")), false);
  const replay = await call(purchaseShopItem, {itemId: "frame_gold", requestId: "reward-request-1"});
  assert.equal(replay.inventoryChanged, false);
  assert.equal(replay.rev, 1);
});

test("placeholder-priced Prism reward remains locked below its milestone", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 10000, xp: 5999}});
  const result = await call(purchaseShopItem, {itemId: "glow_prism", requestId: "reward-request-1"});
  assert.equal(result.reason, "shop_item_rank_locked");
  assert.equal(result.delta, 0);
  assert.equal(owned(store).glow_prism, undefined);
  assert.equal(store.get(USER)?.coins, 10000);
});

test("a paid purchase merges rank rewards in one revision without dropping its own item or prior timestamps", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 500, xp: 6000},
    [PRIVATE]: {rev: 7, inventory: {owned: {glow_aurora: 23}}}});
  const result = await call(purchaseShopItem, {itemId: "frame_ring", requestId: "paid-request-1"});
  assert.equal(result.success, true);
  assert.equal(result.currentBalance, 380);
  assert.equal(result.rev, 8);
  assert.deepEqual(result.owned.sort(), ["frame_gold", "frame_ring", "glow_aurora", "glow_prism"]);
  assert.equal(owned(store).glow_aurora, 23);
  assert.equal(store.get(PRIVATE)?.rev, 8);
  assert.equal([...store.keys()].filter((path) => path.startsWith("coinTransactions/")).length, 1);
});

test("a historical paid reward replay returns its original debit and does not refund or regrant", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 350, xp: 6000},
    [PRIVATE]: {rev: 4, inventory: {owned: {glow_aurora: 12}}},
    "coinTransactions/ctx_shop_u1_reward-request-1": {itemId: "glow_aurora", balanceBefore: 550, balanceAfter: 350, delta: -200}});
  const result = await call(purchaseShopItem, {itemId: "glow_aurora", requestId: "reward-request-1"});
  assert.equal(result.reason, "duplicate");
  assert.equal(result.delta, -200);
  assert.equal(result.previousBalance, 550);
  assert.equal(result.currentBalance, 350);
  assert.equal(result.inventoryChanged, false);
  assert.equal(owned(store).glow_aurora, 12);
  assert.equal(store.get(PRIVATE)?.rev, 4);
});

test("equip reconciles a rank reward, preserves the other slot, and keeps Pro frame restrictions", async (t) => {
  const store = installFakeDb(t, {[USER]: {coins: 0, xp: 6000, cosmetics: {frame: "frame_ring"}},
    [PRIVATE]: {rev: 2, inventory: {owned: {frame_prism: 15, frame_ring: 16}}}});
  const result = await call(equipCosmetic, {slot: "nameGlow", itemId: "glow_prism"});
  assert.equal(result.success, true);
  assert.equal(result.rev, 3);
  assert.equal(result.inventoryChanged, true);
  assert.deepEqual(store.get(USER)?.cosmetics, {frame: "frame_ring", nameGlow: "glow_prism"});
  assert.equal((await call(equipCosmetic, {slot: "frame", itemId: "frame_prism"})).reason, "equip_pro_required");
  assert.equal(owned(store).frame_prism, 15);
});

test("fixed activity XP paths persist newly crossed rank rewards with their existing state", async (t) => {
  for (const path of ["award", "streak", "badge", "quest", "chest"] as const) {
    await t.test(path, async (sub) => {
      resetEconomyCache();
      sub.mock.timers.enable({apis: ["Date"], now: NOW});
      sub.mock.method(Math, "random", () => 0);
      let quests = buildQuestState(null, NOW, false);
      if (path === "quest") {
        quests = {...quests, items: [
          {id: "wotd_view", event: "view_wotd", target: 1, progress: 0, claimed: false}, ...quests.items.slice(1),
        ]};
      }
      if (path === "chest") quests = {...quests, items: quests.items.map((item) => ({...item, claimed: true, progress: item.target}))};
      const store = installFakeDb(sub, {[USER]: {coins: 100, xp: 499,
        coinState: path === "badge" ? {streakBest: 7, streakCount: 7} : {},
        ...(path === "award" ? {username: "artist", bio: "bio", profilePhoto: "photo", links: {site: "site"}} : {})},
      [PRIVATE]: {rev: 5, quests, passes: {premiumPassUntil: 123}, inventory: {owned: {frame_ring: 17}}},
      "economyConfig/current": {award: {questChestCosmeticChance: 1}}});
      if (path === "badge") sub.mock.method(badgeIo, "accountCreatedMs", async () => NOW);
      if (path === "award") await call(awardCoins, {action: "profileCompletion", sourceTag: "test.rank_reward", reason: "test"});
      if (path === "streak") await call(claimDailyStreak, {timezoneOffsetMinutes: 0, reminderEnabled: false});
      if (path === "badge") await call(checkBadges);
      if (path === "quest") await call(progressQuest, {event: "view_wotd", eventId: "quest-event-1"});
      if (path === "chest") await call(openQuestChest, {requestId: "chest-request-1"});
      const expectedXp = {award: 25, streak: 5, badge: 25, quest: 25, chest: 10}[path];
      assert.equal(store.get(USER)?.xp, 499 + expectedXp, path);
      assert.deepEqual(store.get(USER)?.xpWeek, {weekKey: weekKey(NOW), xp: expectedXp}, path);
      assert.equal(owned(store).glow_aurora, NOW, path);
      assert.equal(owned(store).frame_ring, 17, path);
      assert.equal(store.get(PRIVATE)?.rev, 6, path);
      assert.deepEqual(store.get(PRIVATE)?.passes, {premiumPassUntil: 123}, path);
      assert.ok(store.get(PRIVATE)?.quests, path);
      if (path === "chest") assert.equal(Object.keys(owned(store)).length, 3);
    });
  }
});

test("ad, Pro spin, wheel and legacy bonus keep coins and quest progress without XP or rank grants", async (t) => {
  for (const path of ["ad", "spin", "wheel", "legacy"] as const) {
    for (const xp of [499, 6000]) {
      await t.test(`${path}/${xp}`, async (sub) => {
        resetEconomyCache();
        sub.mock.timers.enable({apis: ["Date"], now: NOW});
        sub.mock.method(Math, "random", () => 0);
        const quests = buildQuestState(null, NOW, path === "spin" || path === "wheel");
        const xpWeek = {weekKey: weekKey(NOW), xp: 100};
        const inventory = {owned: {frame_ring: 17}};
        const store = installFakeDb(sub, {
          [USER]: {coins: 100, xp, xpWeek, premium: true},
          [PRIVATE]: {rev: 5, quests, passes: {premiumPassUntil: 123}, inventory},
          "economyConfig/current": {xp: {perCoinEarned: 10}},
        });
        const result = path === "wheel" ? await call(spinWheel, {requestId: "wheel-request-1", maxCost: 0}) :
          path === "spin" ? await call(claimProSpin, {requestId: "spin-request-1"}) :
            await call(awardCoins, {action: path === "ad" ? "rewardedAd" : "proDailyBonus",
              requestId: "award-request-1", sourceTag: "test.rank_reward", reason: "test"});
        const coins = path === "wheel" ? DEFAULT_ECONOMY.award.spinWheel[0] : null;
        const delta = coins?.kind === "coins" ? coins.coins : 20;
        assert.equal(result.delta, delta);
        assert.equal(store.get(USER)?.coins, 100 + delta);
        assert.equal(result.xpAwarded, 0);
        assert.equal(result.xp, xp);
        assert.equal(store.get(USER)?.xp, xp);
        assert.deepEqual(store.get(USER)?.xpWeek, xpWeek);
        assert.deepEqual(store.get(PRIVATE)?.inventory, inventory);
        assert.equal(store.get(PRIVATE)?.rev, path === "legacy" ? 5 : 6);
        assert.deepEqual(store.get(PRIVATE)?.passes, {premiumPassUntil: 123});
        if (path !== "legacy") {
          const state = store.get(PRIVATE)?.quests as typeof quests;
          assert.equal(state.bonus.claimed, true);
        }
      });
    }
  }
});
