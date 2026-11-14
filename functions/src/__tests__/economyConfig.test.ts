import assert from "node:assert/strict";
import test from "node:test";

import {DEFAULT_ECONOMY} from "../economy";
import {parseConfigArgs, parseValue, planConfig} from "../scripts/economyConfig";

test("parseValue reads numbers, booleans and JSON arrays, and keeps other text as a string", () => {
  assert.equal(parseValue("10"), 10);
  assert.equal(parseValue("true"), true);
  assert.deepEqual(parseValue("[3,3,5,5,8,8,10]"), [3, 3, 5, 5, 8, 8, 10]);
  assert.equal(parseValue("2026-12-01T00:00:00Z"), "2026-12-01T00:00:00Z");
});

test("parseConfigArgs reads repeated --set pairs and the flags", () => {
  const args = parseConfigArgs(["--set", "spend.wallpaperDownload=8", "--set=flags.drawEnabled=true", "--apply"]);
  assert.deepEqual(args.sets, [["spend.wallpaperDownload", 8], ["flags.drawEnabled", true]]);
  assert.equal(args.apply, true);
  assert.equal(args.init, false);
  assert.throws(() => parseConfigArgs(["--set", "novalue"]));
});

test("planConfig applies an override onto the live doc and prints a diff", () => {
  const plan = planConfig({spend: {aiFast: 12}}, [["spend.wallpaperDownload", 8]]);
  assert.equal(plan.next.spend.wallpaperDownload, 8);
  assert.equal(plan.next.spend.aiFast, 12);
  assert.deepEqual(plan.overrides, {spend: {wallpaperDownload: 8}});
  assert.deepEqual(plan.diff, [`spend.wallpaperDownload: ${DEFAULT_ECONOMY.spend.wallpaperDownload} -> 8`]);
});

test("planConfig rejects unknown keys, wrong types and prototype paths", () => {
  assert.throws(() => planConfig(null, [["spend.nope", 1]]), /Rejected/);
  assert.throws(() => planConfig(null, [["spend.aiFast", "ten"]]), /Rejected/);
  assert.throws(() => planConfig(null, [["award.streakDaily", [1, 2]]]), /Rejected/);
  assert.throws(() => planConfig(null, [["__proto__.x", 1]]), /Bad path/);
});

test("planConfig reports no change when the value already matches", () => {
  assert.deepEqual(planConfig(null, [["flags.dropsEnabled", true]]).diff, []);
});

test("planConfig sets coin events in any key order and rejects a bad one", () => {
  const event = {id: "launch", startsAtMs: 1, endsAtMs: 1000, multiplier: 2, actions: ["rewardedAd"], label: "event"};
  assert.deepEqual(planConfig(null, [["events", [event]]]).overrides, {events: [event]});
  const weekly = {id: "weekend", startDay: 6, startMinute: 0, durationMinutes: 2880, multiplier: 2,
    actions: ["rewardedAd"], label: "weekend"};
  assert.deepEqual(planConfig(null, [["weeklyEvent", weekly]]).next.weeklyEvent, weekly);
  assert.throws(() => planConfig(null, [["events", [{...event, multiplier: 5}]]]), /Rejected/);
  assert.throws(() => planConfig(null, [["weeklyEvent", {...weekly, startDay: 8}]]), /Rejected/);
});
