import assert from "node:assert/strict";
import test from "node:test";
import {
  DEFAULT_ECONOMY,
  ECONOMY_CONFIG_DOC,
  grantXp,
  loadEconomy,
  parseEconomy,
  proPrice,
  rankFor,
  resetEconomyCache,
  seededPick,
  weekKey,
  weightedPick,
} from "../economy";
import {installFakeDb} from "./fakeDb";

const at = (iso: string) => Date.parse(iso);

test("parseEconomy: a missing or malformed doc gives the defaults", () => {
  for (const raw of [null, undefined, 7, "x", [], {}]) {
    assert.deepEqual(parseEconomy(raw), DEFAULT_ECONOMY, String(raw));
  }
});

test("parseEconomy: partial overrides keep every other default", () => {
  const config = parseEconomy({spend: {wallpaperDownload: 12}, flags: {drawEnabled: true}, unknown: 1});
  assert.equal(config.spend.wallpaperDownload, 12);
  assert.equal(config.spend.premiumWallpaperDownload, DEFAULT_ECONOMY.spend.premiumWallpaperDownload);
  assert.equal(config.flags.drawEnabled, true);
  assert.equal(config.flags.legacyPricingUntil, "2027-01-31T00:00:00Z");
  assert.equal("unknown" in config, false);
});

test("parseEconomy: does not change DEFAULT_ECONOMY", () => {
  const before = JSON.stringify(DEFAULT_ECONOMY);
  parseEconomy(null);
  parseEconomy({spend: {aiFast: -1}, xp: {ranks: [{id: "b", min: 5}, {id: "a", min: 0}]}});
  assert.equal(JSON.stringify(DEFAULT_ECONOMY), before);
});

test("parseEconomy: spend and shop prices are integers in 0..10000", () => {
  const config = parseEconomy({
    spend: {wallpaperDownload: -1, aiFast: 2.5, aiBalanced: 10_001, aiQuality: "100", dropWall: 0, dropPack: 10_000},
    shopPrices: {a: 150, b: -5, c: 1.5, d: 10_001, e: "9", f: 0},
  });
  assert.equal(config.spend.wallpaperDownload, DEFAULT_ECONOMY.spend.wallpaperDownload);
  assert.equal(config.spend.aiFast, DEFAULT_ECONOMY.spend.aiFast);
  assert.equal(config.spend.aiBalanced, DEFAULT_ECONOMY.spend.aiBalanced);
  assert.equal(config.spend.aiQuality, DEFAULT_ECONOMY.spend.aiQuality);
  assert.equal(config.spend.dropWall, 0);
  assert.equal(config.spend.dropPack, 10_000);
  assert.deepEqual(config.shopPrices, {a: 150, f: 0});
});

test("parseEconomy: integer awards are in 0..1000; the multiplier and chance keep their ranges", () => {
  const config = parseEconomy({award: {
    rewardedAd: 1001, referral: -1, questXp: 2.5, graceDownloads: 0,
    proStreakMultiplier: 0.5, questChestCosmeticChance: 2,
  }});
  assert.equal(config.award.rewardedAd, DEFAULT_ECONOMY.award.rewardedAd);
  assert.equal(config.award.referral, DEFAULT_ECONOMY.award.referral);
  assert.equal(config.award.questXp, DEFAULT_ECONOMY.award.questXp);
  assert.equal(config.award.graceDownloads, 0);
  assert.equal(config.award.proStreakMultiplier, DEFAULT_ECONOMY.award.proStreakMultiplier);
  assert.equal(config.award.questChestCosmeticChance, DEFAULT_ECONOMY.award.questChestCosmeticChance);
  assert.equal(parseEconomy({award: {proStreakMultiplier: 2}}).award.proStreakMultiplier, 2);
});

test("parseEconomy: a chest with min above max falls back to the default range", () => {
  const config = parseEconomy({award: {streakChestMin: 50, streakChestMax: 10, questChestMin: 9, questChestMax: 3}});
  assert.equal(config.award.streakChestMin, DEFAULT_ECONOMY.award.streakChestMin);
  assert.equal(config.award.streakChestMax, DEFAULT_ECONOMY.award.streakChestMax);
  assert.equal(config.award.questChestMin, DEFAULT_ECONOMY.award.questChestMin);
  assert.equal(config.award.questChestMax, DEFAULT_ECONOMY.award.questChestMax);
  const ok = parseEconomy({award: {questChestMin: 4, questChestMax: 4}});
  assert.equal(ok.award.questChestMin, 4);
  assert.equal(ok.award.questChestMax, 4);
});

test("parseEconomy: aiGeneration, dropWall and dropPack can never be bypassed", () => {
  const config = parseEconomy({proBypassActions: ["wallpaperDownload", "aiGeneration", "dropWall", "dropPack", 4]});
  assert.deepEqual(config.proBypassActions, ["wallpaperDownload"]);
  assert.deepEqual(parseEconomy({proDiscountActions: ["aiGeneration", null]}).proDiscountActions, ["aiGeneration"]);
});

test("parseEconomy: malformed arrays fall back to the defaults", () => {
  const bad = [
    {award: {streakDaily: [1, 2, 3]}},
    {award: {streakDaily: [1, 2, 3, 4, 5, 6, -7]}},
    {award: {streakDaily: [1, 2, 3, 4, 5, 6, 1.5]}},
    {award: {proSpin: []}},
    {award: {proSpin: [{coins: 10}]}},
    {award: {proSpin: [{coins: 10, weight: -1}, {coins: 20, weight: 5}]}},
    {award: {proSpin: [{coins: 10, weight: 0}, {coins: 20, weight: 0}]}},
    {award: {proSpin: [{coins: 5000, weight: 1}]}},
    {award: {proSpin: "nope"}},
  ];
  for (const raw of bad) {
    const config = parseEconomy(raw);
    assert.deepEqual(config.award.streakDaily, DEFAULT_ECONOMY.award.streakDaily, JSON.stringify(raw));
    assert.deepEqual(config.award.proSpin, DEFAULT_ECONOMY.award.proSpin, JSON.stringify(raw));
  }
  const zeroWeight = parseEconomy({award: {proSpin: [{coins: 10, weight: 0}, {coins: 20, weight: 1}]}});
  assert.deepEqual(zeroWeight.award.proSpin, [{coins: 10, weight: 0}, {coins: 20, weight: 1}]);
  assert.deepEqual(parseEconomy({xp: {ranks: [{id: "x"}]}}).xp.ranks, DEFAULT_ECONOMY.xp.ranks);
});

const SPEC_WHEEL = [
  {kind: "coins", coins: 10, weight: 18},
  {kind: "xp", xp: 25, weight: 22},
  {kind: "coins", coins: 5, weight: 30},
  {kind: "coins", coins: 100, weight: 1},
  {kind: "coins", coins: 20, weight: 8},
  {kind: "xp", xp: 50, weight: 12},
  {kind: "coins", coins: 50, weight: 3},
  {kind: "cosmetic", fallbackCoins: 50, weight: 6},
];

test("parseEconomy: the default wheel is the spec table and survives a Firestore round trip", () => {
  assert.deepEqual(DEFAULT_ECONOMY.award.spinWheel, SPEC_WHEEL);
  const stored = JSON.parse(JSON.stringify({award: {spinWheel: SPEC_WHEEL}, spend: {spinWheel: 10}}));
  const config = parseEconomy(stored);
  assert.deepEqual(config.award.spinWheel, SPEC_WHEEL);
  assert.equal(config.spend.spinWheel, 10);
  assert.equal(config.award.spinWheelMaxPerDay, 5);
});

test("parseEconomy: a valid custom wheel is kept in order with unknown keys dropped", () => {
  const config = parseEconomy({award: {spinWheel: [
    {kind: "xp", xp: 1000, weight: 0, junk: true},
    {kind: "cosmetic", fallbackCoins: 1, weight: 1000},
  ]}});
  assert.deepEqual(config.award.spinWheel, [
    {kind: "xp", xp: 1000, weight: 0},
    {kind: "cosmetic", fallbackCoins: 1, weight: 1000},
  ]);
  const twelve = Array.from({length: 12}, (_, i) => ({kind: "coins", coins: i + 1, weight: 1}));
  assert.equal(parseEconomy({award: {spinWheel: twelve}}).award.spinWheel.length, 12);
});

test("parseEconomy: a malformed wheel falls back to the whole default table", () => {
  const coins = (n: number) => ({kind: "coins", coins: n, weight: 1});
  const bad: unknown[] = [
    [coins(1), {kind: "jackpot", coins: 5, weight: 1}],
    [coins(1), {coins: 5, weight: 1}],
    [coins(1), coins(0)],
    [coins(1), coins(5000)],
    [coins(1), coins(1.5)],
    [coins(1), {kind: "coins", coins: "5", weight: 1}],
    [coins(1), {kind: "xp", xp: 0, weight: 1}],
    [coins(1), {kind: "xp", coins: 5, weight: 1}],
    [coins(1), {kind: "cosmetic", fallbackCoins: 0, weight: 1}],
    [coins(1), {kind: "cosmetic", fallbackCoins: 1001, weight: 1}],
    [coins(1), {kind: "coins", coins: 5, weight: 1001}],
    [coins(1), {kind: "coins", coins: 5, weight: -1}],
    [coins(1), {kind: "coins", coins: 5}],
    [coins(1), null],
    [coins(1)],
    [],
    Array.from({length: 13}, (_, i) => coins(i + 1)),
    [{...coins(1), weight: 0}, {...coins(2), weight: 0}],
    "nope",
    {kind: "coins", coins: 5, weight: 1},
    7,
  ];
  for (const spinWheel of bad) {
    const config = parseEconomy({award: {spinWheel}});
    assert.deepEqual(config.award.spinWheel, SPEC_WHEEL, JSON.stringify(spinWheel));
  }
});

test("parseEconomy: spend.spinWheel is an integer in 0..10000 and the daily cap an integer in 0..1000", () => {
  const price = (spinWheel: unknown) => parseEconomy({spend: {spinWheel}}).spend.spinWheel;
  assert.equal(price(0), 0);
  assert.equal(price(25), 25);
  assert.equal(price(10_000), 10_000);
  for (const bad of [-1, 10_001, 2.5, "12", null]) assert.equal(price(bad), 10, String(bad));
  const cap = (spinWheelMaxPerDay: unknown) => parseEconomy({award: {spinWheelMaxPerDay}}).award.spinWheelMaxPerDay;
  assert.equal(cap(0), 0);
  assert.equal(cap(3), 3);
  assert.equal(cap(1000), 1000);
  for (const bad of [-1, 1001, 1.5, "3"]) assert.equal(cap(bad), 5, String(bad));
});

test("parseEconomy: ranks are sorted by min", () => {
  const config = parseEconomy({xp: {ranks: [{id: "gold", min: 100}, {id: "bronze", min: 0}]}});
  assert.deepEqual(config.xp.ranks.map((r) => r.id), ["bronze", "gold"]);
});

test("parseEconomy: a rank table without unique ids, integer mins or a rank at 0 falls back", () => {
  const bad = [
    [{id: "a", min: 0}, {id: "a", min: 10}],
    [{id: "a", min: 0}, {id: "", min: 10}],
    [{id: "a", min: 0}, {id: 7, min: 10}],
    [{id: "a", min: 0}, {id: "b", min: 1.5}],
    [{id: "a", min: 0}, {id: "b", min: -1}],
    [{id: "a", min: 0}, {id: "b", min: Number.POSITIVE_INFINITY}],
    [{id: "a", min: 5}, {id: "b", min: 10}],
    [null, {id: "a", min: 0}],
  ];
  for (const ranks of bad) {
    assert.deepEqual(parseEconomy({xp: {ranks}}).xp.ranks, DEFAULT_ECONOMY.xp.ranks, JSON.stringify(ranks));
  }
});

test("parseEconomy: xp.perCoinEarned is kept in 0..10", () => {
  assert.equal(parseEconomy({xp: {perCoinEarned: 0}}).xp.perCoinEarned, 0);
  assert.equal(parseEconomy({xp: {perCoinEarned: 2.5}}).xp.perCoinEarned, 2.5);
  for (const perCoinEarned of [-1, 11, 1e9]) {
    assert.equal(parseEconomy({xp: {perCoinEarned}}).xp.perCoinEarned, 1, String(perCoinEarned));
  }
});

test("loadEconomy: reads the config doc and caches it for a minute", async (t) => {
  resetEconomyCache();
  t.after(resetEconomyCache);
  const store = installFakeDb(t, {[ECONOMY_CONFIG_DOC]: {spend: {wallpaperDownload: 7}}});
  assert.equal((await loadEconomy(1_000)).spend.wallpaperDownload, 7);
  store.set(ECONOMY_CONFIG_DOC, {spend: {wallpaperDownload: 8}});
  assert.equal((await loadEconomy(30_000)).spend.wallpaperDownload, 7);
  assert.equal((await loadEconomy(61_001)).spend.wallpaperDownload, 8);
});

test("weekKey: ISO weeks, Monday start, across the year boundary", () => {
  assert.equal(weekKey(at("2026-10-17T12:00:00Z")), "2026-W42");
  assert.equal(weekKey(at("2026-10-18T23:59:59Z")), "2026-W42");
  assert.equal(weekKey(at("2026-10-19T00:00:00Z")), "2026-W43");
  assert.equal(weekKey(at("2026-12-31T00:00:00Z")), "2026-W53");
  assert.equal(weekKey(at("2027-01-03T00:00:00Z")), "2026-W53");
  assert.equal(weekKey(at("2027-01-04T00:00:00Z")), "2027-W01");
});

test("proPrice: Pro pays half rounded up, never zero for a positive price", () => {
  assert.equal(proPrice(10, true), 5);
  assert.equal(proPrice(75, true), 38);
  assert.equal(proPrice(1, true), 1);
  assert.equal(proPrice(0, true), 0);
  assert.equal(proPrice(75, false), 75);
});

test("rankFor: current rank and the next one", () => {
  assert.deepEqual(rankFor(0, DEFAULT_ECONOMY), {id: "bronze", min: 0, next: {id: "silver", min: 500}});
  assert.deepEqual(rankFor(499, DEFAULT_ECONOMY).id, "bronze");
  assert.deepEqual(rankFor(500, DEFAULT_ECONOMY), {id: "silver", min: 500, next: {id: "gold", min: 2000}});
  assert.deepEqual(rankFor(10_000, DEFAULT_ECONOMY), {id: "prism", min: 6000, next: null});
});

test("grantXp: adds within the same week and resets the weekly count on a new week", () => {
  const monday = at("2026-10-19T08:00:00Z");
  const same = grantXp({xp: 100, xpWeek: {weekKey: "2026-W43", xp: 30}}, 20, monday);
  assert.deepEqual(same, {xp: 120, xpWeek: {weekKey: "2026-W43", xp: 50}});
  const next = grantXp({xp: 100, xpWeek: {weekKey: "2026-W42", xp: 30}}, 20, monday);
  assert.deepEqual(next, {xp: 120, xpWeek: {weekKey: "2026-W43", xp: 20}});
  assert.deepEqual(grantXp({}, 5.9, monday), {xp: 5, xpWeek: {weekKey: "2026-W43", xp: 5}});
  assert.deepEqual(grantXp({xp: 10}, -3, monday), {xp: 10, xpWeek: {weekKey: "2026-W43", xp: 0}});
});

test("grantXp: stays a safe integer for huge, negative or broken stored values", () => {
  const monday = at("2026-10-19T08:00:00Z");
  const max = Number.MAX_SAFE_INTEGER;
  assert.deepEqual(grantXp({xp: max, xpWeek: {weekKey: "2026-W43", xp: max}}, 10, monday),
    {xp: max, xpWeek: {weekKey: "2026-W43", xp: max}});
  assert.deepEqual(grantXp({xp: Number.NaN, xpWeek: {weekKey: "2026-W43", xp: -5}}, Number.POSITIVE_INFINITY, monday),
    {xp: 0, xpWeek: {weekKey: "2026-W43", xp: 0}});
  assert.deepEqual(grantXp({xp: -20}, 1e30, monday), {xp: max, xpWeek: {weekKey: "2026-W43", xp: max}});
});

test("seededPick: same seed same pick, distinct items, never more than the pool", () => {
  const pool = ["a", "b", "c", "d", "e", "f", "g", "h"];
  assert.deepEqual(seededPick("2026-10-17", 3, pool), seededPick("2026-10-17", 3, pool));
  assert.equal(new Set(seededPick("2026-10-17", 3, pool)).size, 3);
  assert.notDeepEqual(
    ["2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20"].map((seed) => seededPick(seed, 3, pool).join()),
    Array(4).fill(seededPick("2026-10-17", 3, pool).join()),
  );
  assert.equal(seededPick("x", 10, ["a", "b"]).length, 2);
  assert.deepEqual(pool, ["a", "b", "c", "d", "e", "f", "g", "h"]);
});

test("weightedPick: segment boundaries follow the weights", () => {
  const table = DEFAULT_ECONOMY.award.proSpin;
  assert.equal(weightedPick(table, () => 0), 0);
  assert.equal(weightedPick(table, () => 0.3999), 0);
  assert.equal(weightedPick(table, () => 0.4), 1);
  assert.equal(weightedPick(table, () => 0.65), 2);
  assert.equal(weightedPick(table, () => 0.85), 3);
  assert.equal(weightedPick(table, () => 0.95), 4);
  assert.equal(weightedPick(table, () => 0.999999), 4);
  assert.equal(weightedPick([{weight: 0}, {weight: 1}], () => 0), 1);
  assert.equal(weightedPick([{weight: 0}], () => 0.5), 0);
});
