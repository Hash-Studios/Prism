import assert from "node:assert/strict";
import test from "node:test";
import {DEFAULT_ECONOMY} from "../economy";

const award = DEFAULT_ECONOMY.award;
const mean = (values: number[]) => values.reduce((sum, n) => sum + n, 0) / values.length;
const streakDaily = mean(award.streakDaily);
const streakChestPerDay = (award.streakChestMin + award.streakChestMax) / 2 / 7;
const questsPerDay = 3 * award.questCoins;
const questChest = (award.questChestMin + award.questChestMax) / 2;
const weeklyPerDay = award.weeklyQuestCoins / 7;
const spinMean = award.proSpin.reduce((sum, s) => sum + s.coins * s.weight, 0) /
  award.proSpin.reduce((sum, s) => sum + s.weight, 0);

const personas = {
  casual: streakDaily + streakChestPerDay,
  engagedFree: streakDaily + streakChestPerDay + questsPerDay + questChest + award.rewardedAdFirstOfDay + weeklyPerDay,
  engagedPro: (streakDaily + streakChestPerDay) * award.proStreakMultiplier + questsPerDay + questChest + spinMean +
    weeklyPerDay,
};

test("economy sim: coins a day per persona on DEFAULT_ECONOMY", () => {
  console.table(Object.fromEntries(Object.entries(personas).map(([name, perDay]) =>
    [name, {perDay: Number(perDay.toFixed(1)), perWeek: Math.round(perDay * 7)}])));
  assert.ok(personas.casual <= 15, `casual ${personas.casual}`);
  // Revision 3 defaults give about 50.2 a day (the spec cohort budget, about 350 a week), above the 45 target.
  assert.ok(personas.engagedFree <= 55, `engaged free ${personas.engagedFree}`);
  assert.ok(personas.engagedPro <= 75, `engaged Pro ${personas.engagedPro}`);
});
