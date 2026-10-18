import assert from "node:assert/strict";
import test from "node:test";
import {DEFAULT_ECONOMY} from "../economy";

const award = DEFAULT_ECONOMY.award;
const mean = (values: number[]) => values.reduce((sum, n) => sum + n, 0) / values.length;
const streakDaily = mean(award.streakDaily);
const streakChestPerDay = (award.streakChestMin + award.streakChestMax) / 2 / 7;
const questsPerDay = 3 * award.questCoins;
const weeklyPerDay = award.weeklyQuestCoins / 7;
// Coins per spin of the wheel. A cosmetic or XP slice pays no coins, so it counts 0 (a cosmetic's fallback only
// pays once every common item is owned).
const wheelTotalWeight = award.spinWheel.reduce((sum, s) => sum + s.weight, 0);
const wheelCoinEv = award.spinWheel.reduce((sum, s) => sum + (s.kind === "coins" ? s.coins * s.weight : 0), 0) /
  wheelTotalWeight;

// Coins per daily chest. An XP slot pays no coins and a cosmetic slot counts 0 (its fallback only pays once every
// common item is owned). The engaged personas finish the three quests, so their chest is free; the bonus quest would
// double it, which the personas leave out.
const chestTotalWeight = award.dailyChest.reduce((sum, s) => sum + s.weight, 0);
const chestCoinEv = award.dailyChest.reduce((sum, s) => sum + (s.kind === "coins" ? s.coins * s.weight : 0), 0) /
  chestTotalWeight;

const personas = {
  casual: streakDaily + streakChestPerDay,
  engagedFree: streakDaily + streakChestPerDay + questsPerDay + chestCoinEv + award.rewardedAdFirstOfDay + weeklyPerDay,
  engagedPro: (streakDaily + streakChestPerDay) * award.proStreakMultiplier + questsPerDay + chestCoinEv + wheelCoinEv +
    weeklyPerDay,
};

test("economy sim: coins a day per persona on DEFAULT_ECONOMY", () => {
  console.table(Object.fromEntries(Object.entries(personas).map(([name, perDay]) =>
    [name, {perDay: Number(perDay.toFixed(1)), perWeek: Math.round(perDay * 7)}])));
  assert.ok(personas.casual <= 15, `casual ${personas.casual}`);
  // Revision 3 defaults give about 50.6 a day (the spec cohort budget, about 350 a week), above the 45 target.
  assert.ok(personas.engagedFree <= 55, `engaged free ${personas.engagedFree}`);
  assert.ok(personas.engagedPro <= 75, `engaged Pro ${personas.engagedPro}`);
});

test("economy sim: a paid wheel spin pays back less than it costs, so the wheel is a sink", () => {
  assert.equal(Number(wheelCoinEv.toFixed(2)), 7.4);
  assert.ok(wheelCoinEv < DEFAULT_ECONOMY.spend.spinWheel, `wheel EV ${wheelCoinEv}`);
  const maxNetPerDay = award.spinWheelMaxPerDay * (wheelCoinEv - DEFAULT_ECONOMY.spend.spinWheel);
  assert.equal(Number(maxNetPerDay.toFixed(1)), -13);
});

test("economy sim: a paid daily chest pays back a little more than it costs, and the bonus doubles it", () => {
  assert.equal(Number(chestCoinEv.toFixed(2)), 10.4);
  const net = chestCoinEv - DEFAULT_ECONOMY.spend.dailyChest;
  assert.equal(Number(net.toFixed(1)), 2.4);
  assert.ok(net > 0 && net <= 5, `paid chest net ${net}`);
  assert.equal(Number((chestCoinEv * 2).toFixed(1)), 20.8);
});
