import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {computeTrending, popularWallIds, trendingDays, trendingWallIds} from "../trending";
import {installFakeDb} from "./fakeDb";

const NOW = new Date("2026-01-10T12:00:00Z");

test("the trending window is the last 7 UTC days, newest first", () => {
  assert.deepEqual(trendingDays(NOW.getTime()), [
    "20260110", "20260109", "20260108", "20260107", "20260106", "20260105", "20260104",
  ]);
});

test("a day scores sets x3, downloads x2, favs x2, shares x2 and views, and older days count 0.8 per day", () => {
  const days = trendingDays(NOW.getTime());
  const ids = trendingWallIds([
    {wallId: "A", day: "20260110", sets: 1}, // 3
    {wallId: "B", day: "20260110", downloads: 1}, // 2
    {wallId: "B", day: "20260109", sets: 1, views: 2}, // (3 + 2) * 0.8 = 4, so B = 6
    {wallId: "C", day: "20260110", favs: 1, shares: 1, views: 1}, // 5
    {wallId: "D", day: "20260103", sets: 100}, // outside the window
    {wallId: "E", day: "20260110"}, // no score
  ], days);
  assert.deepEqual(ids, ["B", "C", "A"]);
});

test("an old burst loses to steady recent activity", () => {
  const days = trendingDays(NOW.getTime());
  const ids = trendingWallIds([
    {wallId: "OLD", day: "20260104", sets: 3}, // 9 * 0.8^6 = 2.36
    {wallId: "NEW", day: "20260110", sets: 1}, // 3
  ], days);
  assert.deepEqual(ids, ["NEW", "OLD"]);
});

test("the trending list holds at most 100 ids and ignores bad docs", () => {
  const days = trendingDays(NOW.getTime());
  const docs: Array<Record<string, unknown>> = Array.from({length: 150}, (_, i) => ({
    wallId: `W${i}`, day: "20260110", sets: i + 1,
  }));
  docs.push({day: "20260110", sets: 999}, {wallId: "X", day: "20260110", sets: "many"});
  const ids = trendingWallIds(docs, days);
  assert.equal(ids.length, 100);
  assert.equal(ids[0], "W149");
});

test("popular ranks all-time sets x3, downloads x2, favs x2 and views", () => {
  const ids = popularWallIds([
    {id: "A", data: {views: 10}},
    {id: "B", data: {views: 1, sets: 2, downloads: 1}}, // 1 + 6 + 2 = 9
    {id: "C", data: {views: "30"}}, // legacy string views
    {id: "D", data: {favs: 4}}, // 8
    {id: "E", data: {}},
  ]);
  assert.deepEqual(ids, ["C", "A", "B", "D"]);
});

test("computeTrending writes trending/current and popular/current from the stats docs", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: NOW});
  const store = installFakeDb(t, {
    "wallpaper_stats_daily/20260110_A": {wallId: "A", day: "20260110", sets: 2},
    "wallpaper_stats_daily/20260109_B": {wallId: "B", day: "20260109", downloads: 1},
    "wallpaper_stats_daily/20260101_Z": {wallId: "Z", day: "20260101", sets: 50},
    "wallpaper_stats/A": {views: 5, sets: 2},
    "wallpaper_stats/B": {views: 50},
    "wallpaper_stats/Z": {views: 1, sets: 50},
  });
  await computeTrending.run({jobName: "t", scheduleTime: NOW.toISOString()});
  const trending = store.get("trending/current");
  assert.deepEqual(trending?.wallIds, ["A", "B"]);
  assert.ok(trending?.updatedAt instanceof admin.firestore.Timestamp);
  assert.deepEqual(store.get("popular/current")?.wallIds, ["Z", "B", "A"]);
});
