import assert from "node:assert/strict";
import test, {beforeEach} from "node:test";
import {DEFAULT_ECONOMY, dayKey, resetEconomyCache, weekKey} from "../economy";
import {
  applyQuestEvent,
  buildQuestState,
  dailyQuestIds,
  QUEST_POOL,
  type QuestState,
} from "../questCatalog";
import {openQuestChest, progressQuest, progressQuestForUser} from "../quests";
import {installFakeDb, type Doc} from "./fakeDb";

const UID = "user-1";
const USER = `usersv2/${UID}`;
const PRIVATE = `${USER}/private/economy`;
const NOW = Date.UTC(2026, 9, 14, 12);

beforeEach(() => resetEconomyCache());

type Callable<T> = {run: (req: never) => Promise<T>};
const call = <T>(fn: unknown, data: Record<string, unknown>, uid = UID): Promise<T> =>
  (fn as Callable<T>).run({auth: {uid, token: {}}, data} as never);

const progress = (data: Record<string, unknown>) =>
  call<Doc & {quests: QuestState; awarded: Array<{id: string; coins: number; xp: number}>}>(progressQuest, data);

const chest = (data: Record<string, unknown> = {requestId: "chest-req-1"}) =>
  call<Doc & {quests: QuestState}>(openQuestChest, data);

const event = (name: string, n: number) => ({event: name, eventId: `${name}-event-${n}-xxxx`});

test("dailyQuestIds is deterministic, three pool items, bonus by plan", () => {
  const free = dailyQuestIds("2026-10-14", false);
  assert.deepEqual(free, dailyQuestIds("2026-10-14", false));
  assert.equal(new Set(free.items).size, 3);
  for (const id of free.items) assert.ok(QUEST_POOL.some((q) => q.id === id));
  assert.equal(free.bonus, "watch_ad");
  const pro = dailyQuestIds("2026-10-14", true);
  assert.deepEqual(pro.items, free.items);
  assert.equal(pro.bonus, "pro_spin");
});

test("a Pro flip mid-day keeps the stored bonus", () => {
  const state = buildQuestState(null, NOW, false);
  assert.equal(buildQuestState(state, NOW + 1000, true).bonus.id, "watch_ad");
});

test("a stale day rebuilds the daily set and keeps the weekly block", () => {
  const state = buildQuestState(null, NOW, false);
  const worked = {...state, weekly: {...state.weekly, progress: 3}, items: state.items.map((i) => ({...i, claimed: true}))};
  const next = buildQuestState(worked, NOW + 86_400_000, false);
  assert.equal(next.dayKey, dayKey(NOW + 86_400_000));
  assert.ok(next.items.every((i) => !i.claimed && i.progress === 0));
  assert.equal(next.weekly.progress, 3);
  assert.equal(next.chestOpened, false);
  const nextWeek = buildQuestState(worked, NOW + 7 * 86_400_000, false);
  assert.equal(nextWeek.weekKey, weekKey(NOW + 7 * 86_400_000));
  assert.equal(nextWeek.weekly.progress, 0);
});

test("applyQuestEvent caps progress at the target and pays an item once", () => {
  let state = buildQuestState(null, NOW, false);
  state = {...state, items: [{id: "download_2", event: "download", target: 2, progress: 0, claimed: false}, ...state.items.slice(1)]};
  let result = applyQuestEvent(state, "download", DEFAULT_ECONOMY);
  assert.equal(result.state.items[0].progress, 1);
  assert.deepEqual(result.completed, []);
  result = applyQuestEvent(result.state, "download", DEFAULT_ECONOMY);
  assert.equal(result.state.items[0].progress, 2);
  assert.equal(result.state.items[0].claimed, true);
  assert.equal(result.completed.length, 1);
  assert.equal(result.completed[0].coins, DEFAULT_ECONOMY.award.questCoins);
  result = applyQuestEvent(result.state, "download", DEFAULT_ECONOMY);
  assert.equal(result.state.items[0].progress, 2);
  assert.deepEqual(result.completed, []);
});

function seedState(patch: Partial<QuestState> = {}): QuestState {
  return {...buildQuestState(null, NOW, false), ...patch};
}

const userDoc = (extra: Doc = {}): Doc => ({coins: 100, premium: false, ...extra});

test("progressQuest rejects bad input and anonymous callers", async (t) => {
  installFakeDb(t, {[USER]: userDoc()});
  t.mock.method(Date, "now", () => NOW);
  await assert.rejects(call(progressQuest, {}, ""), /signed in/);
  await assert.rejects(progress({event: "nope"}), /event is invalid/);
  await assert.rejects(progress({event: "view_wotd", eventId: "short"}), /eventId is invalid/);
});

test("progressQuest auto-claims once and pays coins, xp and the ledger", async (t) => {
  const state = seedState({items: [
    {id: "wotd_view", event: "view_wotd", target: 1, progress: 0, claimed: false},
    {id: "set_wall", event: "set_wallpaper", target: 1, progress: 0, claimed: false},
    {id: "share_wall", event: "share", target: 1, progress: 0, claimed: false},
  ]});
  const store = installFakeDb(t, {[USER]: userDoc(), [PRIVATE]: {rev: 4, quests: state}});
  t.mock.method(Date, "now", () => NOW);

  const first = await progress(event("view_wotd", 1));
  assert.equal(first.success, true);
  assert.deepEqual(first.awarded, [{id: "wotd_view", coins: DEFAULT_ECONOMY.award.questCoins, xp: DEFAULT_ECONOMY.award.questXp}]);
  assert.equal(first.previousBalance, 100);
  assert.equal(first.currentBalance, 100 + DEFAULT_ECONOMY.award.questCoins);
  assert.equal(first.rev, 5);
  assert.equal(first.xpPolicyVersion, 1);
  assert.equal(first.xpAwarded, 25);
  assert.equal(first.xp, 25);
  const user = store.get(USER) as Doc;
  assert.equal(user.coins, first.currentBalance);
  assert.equal(user.xp, DEFAULT_ECONOMY.award.questXp);
  const txDoc = store.get(`coinTransactions/ctx_quest_${UID}_${dayKey(NOW)}_wotd_view`) as Doc;
  assert.equal(txDoc.action, "quest");
  assert.equal(txDoc.reason, "quest_wotd_view");
  assert.equal(txDoc.sourceTag, "quests.progress.callable");
  assert.equal((store.get(PRIVATE) as Doc).rev, 5);

  const second = await progress(event("view_wotd", 2));
  assert.deepEqual(second.awarded, []);
  assert.equal(second.currentBalance, first.currentBalance);
  assert.equal(second.rev, 5);
  assert.equal(second.xpAwarded, 0);
  assert.equal(second.xp, 25);
  assert.equal((store.get(USER) as Doc).coins, first.currentBalance);
});

test("progressQuestForUser feeds the weekly quest and pays it on the fifth set", async (t) => {
  const store = installFakeDb(t, {[USER]: userDoc()});
  for (let i = 0; i < 5; i += 1) await progressQuestForUser(UID, "set_wallpaper", `wall_${i}`, NOW);
  const quests = (store.get(PRIVATE) as {quests: QuestState}).quests;
  assert.equal(quests.weekly.progress, 5);
  assert.equal(quests.weekly.claimed, true);
  assert.ok(store.has(`coinTransactions/ctx_quest_${UID}_${weekKey(NOW)}_weekly_set_5`));
  const coins = (store.get(USER) as Doc).coins as number;
  await progressQuestForUser(UID, "set_wallpaper", "wall_5", NOW);
  assert.equal((store.get(USER) as Doc).coins, coins);
});

test("progressQuestForUser counts a repeated eventId once", async (t) => {
  const store = installFakeDb(t, {[USER]: userDoc()});
  await progressQuestForUser(UID, "set_wallpaper", "wall_a", NOW);
  await progressQuestForUser(UID, "set_wallpaper", "wall_a", NOW);
  assert.equal((store.get(PRIVATE) as {quests: QuestState}).quests.weekly.progress, 1);
});

test("progressQuestForUser never throws", async (t) => {
  installFakeDb(t);
  await progressQuestForUser("missing-user", "share", "share_1", NOW);
});

test("the callable takes only the client events and ignores the rest", async (t) => {
  installFakeDb(t, {[USER]: userDoc()});
  t.mock.method(Date, "now", () => NOW);
  for (const name of ["watch_ad", "pro_spin", "share", "download", "set_wallpaper", "favourite", "view_wallpaper"]) {
    const ignored = await progress(event(name, 1));
    assert.equal(ignored.reason, "quest_event_server_only");
    assert.equal(ignored.changed, false);
  }
  const counted = await progress(event("view_trending", 1));
  assert.match(counted.reason as string, /^quest_(progressed|completed)$/);
  const dup = await progress(event("view_trending", 1));
  assert.equal(dup.reason, "quest_event_duplicate");
});

test("progressQuest rate limits an event at twice its largest target", async (t) => {
  const store = installFakeDb(t, {[USER]: userDoc()});
  t.mock.method(Date, "now", () => NOW);
  for (let i = 0; i < 2; i += 1) {
    assert.notEqual((await progress(event("colour_search", i))).reason, "quest_event_rate_limited");
  }
  const limited = await progress(event("colour_search", 9));
  assert.equal(limited.success, true);
  assert.equal(limited.reason, "quest_event_rate_limited");
  const rate = store.get(`questEventRate/${UID}_${dayKey(NOW)}_colour_search`) as Doc;
  assert.equal(rate.count, 2);
  assert.ok(rate.expireAt);
});

test("progressQuest without an event only syncs and creates the private doc", async (t) => {
  const store = installFakeDb(t, {[USER]: userDoc()});
  t.mock.method(Date, "now", () => NOW);
  const synced = await progress({});
  assert.equal(synced.quests.dayKey, dayKey(NOW));
  assert.equal(synced.rev, 1);
  assert.equal((store.get(PRIVATE) as Doc).rev, 1);
  assert.equal((await progress({})).rev, 1);
});

const doneItems = (claimed = true) =>
  buildQuestState(null, NOW, false).items.map((i) => ({...i, progress: i.target, claimed}));

const chestConfig = {award: {questChestMin: 10, questChestMax: 10, questChestCosmeticChance: 0}};

test("the chest stays locked until all three items are claimed", async (t) => {
  installFakeDb(t, {[USER]: userDoc(), [PRIVATE]: {rev: 1, quests: seedState({items: doneItems().map((i, n) => ({...i, claimed: n < 2}))})}});
  t.mock.method(Date, "now", () => NOW);
  const locked = await chest();
  assert.equal(locked.success, false);
  assert.equal(locked.reason, "quest_chest_locked");
});

test("the chest pays once, replays the same result, and refuses a new request", async (t) => {
  const store = installFakeDb(t, {
    "economyConfig/current": chestConfig,
    [USER]: userDoc(),
    [PRIVATE]: {rev: 1, quests: seedState({items: doneItems()})},
  });
  t.mock.method(Date, "now", () => NOW);
  const opened = await chest();
  assert.equal(opened.success, true);
  assert.equal(opened.coins, 10);
  assert.equal(opened.itemId, null);
  assert.equal(opened.currentBalance, 110);
  assert.equal(opened.xpAwarded, 10);
  assert.equal((store.get(PRIVATE) as {quests: QuestState}).quests.chestOpened, true);
  const txDoc = store.get(`coinTransactions/ctx_questChest_${UID}_${dayKey(NOW)}`) as Doc;
  assert.equal(txDoc.coins, 10);

  store.set(USER, {...store.get(USER), coins: 150, xp: 900, xpWeek: {weekKey: weekKey(NOW), xp: 300}});
  const replay = await chest();
  assert.equal(replay.success, true);
  assert.equal(replay.coins, 10);
  assert.equal(replay.changed, false);
  assert.equal(replay.delta, 10);
  assert.equal(replay.previousBalance, 100);
  assert.equal(replay.currentBalance, 110);
  assert.equal((store.get(USER) as Doc).coins, 150);
  assert.equal(replay.xpAwarded, 0);
  assert.equal(replay.xp, 900);
  assert.deepEqual(replay.xpWeek, {weekKey: weekKey(NOW), xp: 300});

  const other = await chest({requestId: "chest-req-2"});
  assert.equal(other.success, false);
  assert.equal(other.reason, "quest_chest_already_opened");
  assert.equal(other.xpAwarded, 0);
  assert.equal(other.xp, 900);
});

test("a claimed bonus doubles the chest", async (t) => {
  const bonus = {...seedState().bonus, progress: 1, claimed: true};
  installFakeDb(t, {
    "economyConfig/current": chestConfig,
    [USER]: userDoc(),
    [PRIVATE]: {rev: 1, quests: seedState({items: doneItems(), bonus})},
  });
  t.mock.method(Date, "now", () => NOW);
  const opened = await chest();
  assert.equal(opened.coins, 20);
  assert.equal(opened.doubled, true);
  assert.equal(opened.quests.chestDoubled, true);
  assert.equal(opened.xpAwarded, 10);
  assert.equal(opened.xp, 10);
});

test("quest chest XP is fixed across random coins and ad/Pro doubled chests", async (t) => {
  for (const premium of [false, true]) {
    for (const doubled of [false, true]) {
      for (const random of [0, 0.999]) {
        await t.test(`${premium}/${doubled}/${random}`, async (sub) => {
          resetEconomyCache();
          sub.mock.method(Date, "now", () => NOW);
          sub.mock.method(Math, "random", () => random);
          const state = buildQuestState(null, NOW, premium);
          const store = installFakeDb(sub, {
            [USER]: userDoc({premium, xp: 499, xpWeek: {weekKey: weekKey(NOW), xp: 30}}),
            [PRIVATE]: {rev: 4, quests: {...state, items: doneItems(), bonus: {
              ...state.bonus, claimed: doubled, progress: doubled ? 1 : 0,
            }}, inventory: {owned: {theme_rose: 123}}},
            "economyConfig/current": {award: {questChestMin: 1, questChestMax: 100, questChestCosmeticChance: 0},
              xp: {perCoinEarned: 10}},
          });
          const result = await chest();
          const coins = (random === 0 ? 1 : 100) * (doubled ? 2 : 1);
          assert.equal(result.coins, coins);
          assert.equal(result.currentBalance, 100 + coins);
          assert.equal(result.xpPolicyVersion, 1);
          assert.equal(result.xpAwarded, 10);
          assert.equal(result.xp, 509);
          assert.deepEqual(result.xpWeek, {weekKey: weekKey(NOW), xp: 40});
          const inventory = store.get(PRIVATE)?.inventory as {owned: Record<string, number>};
          assert.equal(inventory.owned.theme_rose, 123);
          assert.ok(Object.keys(inventory.owned).length > 1);
          assert.equal(store.get(PRIVATE)?.rev, 5);
        });
      }
    }
  }
});

test("quest sync, ignored events and locked chest return current-week no-op XP without rewriting history", async (t) => {
  const oldWeek = {weekKey: "2026-W41", xp: 300};
  const store = installFakeDb(t, {[USER]: userDoc({xp: 6000, xpWeek: oldWeek})});
  t.mock.method(Date, "now", () => NOW);
  for (const result of [await progress({}), await progress(event("watch_ad", 1)), await chest()]) {
    assert.equal(result.xpPolicyVersion, 1);
    assert.equal(result.xpAwarded, 0);
    assert.equal(result.xp, 6000);
    assert.deepEqual(result.xpWeek, {weekKey: weekKey(NOW), xp: 0});
  }
  assert.deepEqual(store.get(USER)?.xpWeek, oldWeek);
});

test("a cosmetic drop writes inventory.owned and keeps existing items", async (t) => {
  const store = installFakeDb(t, {
    "economyConfig/current": {award: {questChestMin: 10, questChestMax: 10, questChestCosmeticChance: 1}},
    [USER]: userDoc(),
    [PRIVATE]: {rev: 1, quests: seedState({items: doneItems()}), inventory: {owned: {theme_rose: 5}}},
  });
  t.mock.method(Date, "now", () => NOW);
  const opened = await chest();
  assert.equal(typeof opened.itemId, "string");
  const owned = (store.get(PRIVATE) as {inventory: {owned: Record<string, number>}}).inventory.owned;
  assert.equal(owned.theme_rose, 5);
  assert.equal(owned[opened.itemId as string], NOW);
  assert.equal(Object.keys(owned).length, 2);

  const replay = await chest();
  assert.equal(replay.itemId, opened.itemId);
});
