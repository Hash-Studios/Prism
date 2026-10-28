import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {MAX_MOOD_WALLS, MOODS, type MoodRule, matchesMood, moodLists, refreshMoods} from "../wallMoods";
import {installFakeDb} from "./fakeDb";

const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

const mood = (id: string): MoodRule => {
  const rule = MOODS.find((m) => m.id === id);
  assert.ok(rule, id);
  return rule;
};

/** An approved, protected, non-premium wall that no mood rule excludes by default. */
const eligible = (over: admin.firestore.DocumentData = {}): admin.firestore.DocumentData => ({
  review: true,
  originalProtected: true,
  collections: ["community"],
  createdAt: ts(1),
  ...over,
});

test("dreamy matches a pastel sky wall and rejects a near miss and a wall with missing fields", () => {
  const rule = mood("dreamy");
  assert.equal(matchesMood(rule, {colors: ["pink", "white"], visionLabels: ["Sunset"]}), true);
  assert.equal(matchesMood(rule, {colors: ["grey", "white"], visionLabels: ["Sunset"]}), false);
  assert.equal(matchesMood(rule, {visionLabels: ["Sunset"]}), false);
  assert.equal(matchesMood(rule, {colors: ["pink"]}), false);
});

test("dark_quiet matches a dark night wall and rejects a near miss and a wall with missing fields", () => {
  const rule = mood("dark_quiet");
  assert.equal(matchesMood(rule, {colors: ["black", "grey"], visionLabels: ["Night"]}), true);
  assert.equal(matchesMood(rule, {colors: ["black", "grey", "blue"], visionLabels: ["Night"]}), false);
  assert.equal(matchesMood(rule, {colors: ["black", "grey"]}), false);
  assert.equal(matchesMood(rule, {visionLabels: ["Night"]}), false);
  assert.equal(matchesMood(rule, {colors: ["black", "purple"], visionLabels: ["Silhouette", "Sunset"]}), false);
});

test("bright_bold matches a warm wall and rejects a near miss and a wall with missing fields", () => {
  const rule = mood("bright_bold");
  assert.equal(matchesMood(rule, {colors: ["red", "orange", "white"]}), true);
  assert.equal(matchesMood(rule, {colors: ["red", "orange", "black"]}), false);
  assert.equal(matchesMood(rule, {visionLabels: ["sky"]}), false);
});

test("minimal matches a minimal collection and rejects a near miss and a wall with missing fields", () => {
  const rule = mood("minimal");
  assert.equal(matchesMood(rule, {collections: ["minimal"], visionLabels: ["sky"]}), true);
  assert.equal(matchesMood(rule, {collections: ["minimal"], visionLabels: ["Pattern"]}), false);
  assert.equal(matchesMood(rule, {visionLabels: ["sky"]}), false);
  assert.equal(matchesMood(rule, {category: "Minimal"}), true);
});

test("spatial_ready matches a great spatial tier and rejects a near miss and a missing spatial", () => {
  const rule = mood("spatial_ready");
  assert.equal(matchesMood(rule, {spatial: {tier: "great"}}), true);
  assert.equal(matchesMood(rule, {spatial: {tier: "ok"}}), false);
  assert.equal(matchesMood(rule, {colors: ["red"]}), false);
});

test("depth_ready matches an auto or menu depth tier and rejects a near miss and a missing depth", () => {
  const rule = mood("depth_ready");
  assert.equal(matchesMood(rule, {depth: {tier: "menu"}}), true);
  assert.equal(matchesMood(rule, {depth: {tier: "none"}}), false);
  assert.equal(matchesMood(rule, {colors: ["red"]}), false);
});

test("label and collection matching ignores case and surrounding spaces", () => {
  assert.equal(matchesMood(mood("dark_quiet"), {colors: ["black"], visionLabels: ["NIGHT"]}), true);
  assert.equal(matchesMood(mood("minimal"), {collections: [" Minimal "]}), true);
});

test("a mood with 11 matching walls is dropped and with 12 it is kept", () => {
  const walls = (n: number) => Array.from({length: n}, (_, i) => ({
    id: `w${i}`,
    data: eligible({id: `W${i}`, spatial: {tier: "great"}, createdAt: ts(i + 1)}),
  }));
  assert.equal(moodLists(walls(11), []).find((l) => l.id === "spatial_ready"), undefined);
  assert.equal(moodLists(walls(12), []).find((l) => l.id === "spatial_ready")?.wallIds.length, 12);
});

test("a mood lists at most 60 wall ids, newest first", () => {
  const walls = Array.from({length: 61}, (_, i) => ({
    id: `w${i + 1}`,
    data: eligible({id: `W${i + 1}`, spatial: {tier: "great"}, createdAt: ts(i + 1)}),
  }));
  const [list] = moodLists(walls, []).filter((l) => l.id === "spatial_ready");
  assert.equal(list.wallIds.length, MAX_MOOD_WALLS);
  assert.equal(list.wallIds[0], "W61");
  assert.equal(list.wallIds[MAX_MOOD_WALLS - 1], "W2");
});

test("duplicate logical ids are removed before the 60-wall cap", () => {
  const walls = Array.from({length: 61}, (_, i) => ({
    id: `doc${i}`,
    data: eligible({id: `W${i + 1}`, spatial: {tier: "great"}, createdAt: ts(i + 1)}),
  }));
  walls.push({id: "newerDuplicate", data: eligible({id: "W61", spatial: {tier: "great"}, createdAt: ts(62)})});
  const [list] = moodLists(walls, []).filter((entry) => entry.id === "spatial_ready");
  assert.equal(list.wallIds.length, MAX_MOOD_WALLS);
  assert.equal(list.wallIds[0], "W61");
  assert.equal(list.wallIds[MAX_MOOD_WALLS - 1], "W2");
  assert.equal(new Set(list.wallIds).size, MAX_MOOD_WALLS);
});

test("walls with the same createdAt are ordered by id", () => {
  const walls = Array.from({length: 12}, (_, i) => ({
    id: `w${i + 1}`,
    data: eligible({id: `W${i + 1}`, spatial: {tier: "great"}, createdAt: ts(5)}),
  }));
  const [list] = moodLists(walls, []);
  assert.deepEqual(list.wallIds, [...list.wallIds].sort());
});

test("the wall id is the id field when set, not the document id", () => {
  const walls = [
    {id: "docA", data: eligible({id: "0CFI", spatial: {tier: "great"}})},
    ...Array.from({length: 11}, (_, i) => ({
      id: `doc${i}`,
      data: eligible({id: `W${i}`, spatial: {tier: "great"}, createdAt: ts(i + 2)}),
    })),
  ];
  const [list] = moodLists(walls, []);
  assert.equal(list.wallIds.includes("0CFI"), true);
  assert.equal(list.wallIds.includes("docA"), false);
});

test("a missing logical id is not replaced with the document id the app cannot query", () => {
  const walls = Array.from({length: 11}, (_, i) => ({
    id: `wall${i}`,
    data: eligible({id: `W${i}`, spatial: {tier: "great"}}),
  }));
  walls.push({id: "legacyDoc", data: eligible({spatial: {tier: "great"}})});
  assert.equal(moodLists(walls, []).find((list) => list.id === "spatial_ready"), undefined);
});

test("noncanonical and invalid logical ids do not count toward the mood minimum", () => {
  const valid = Array.from({length: 11}, (_, i) => ({
    id: `wall${i}`,
    data: eligible({id: `W${i}`, spatial: {tier: "great"}}),
  }));
  const invalid = [
    {id: "whitespace", data: eligible({id: " W11 ", spatial: {tier: "great"}})},
    {id: "slash", data: eligible({id: "W11/invalid", spatial: {tier: "great"}})},
    {id: "missing", data: eligible({spatial: {tier: "great"}})},
  ];
  for (const wall of invalid) {
    assert.equal(moodLists([...valid, wall], []).find((list) => list.id === "spatial_ready"), undefined, wall.id);
  }
});

test("duplicate logical ids do not inflate the minimum mood wall count", () => {
  const walls = Array.from({length: 11}, (_, i) => ({
    id: `wall${i}`,
    data: eligible({id: `W${i}`, spatial: {tier: "great"}}),
  }));
  walls.push({id: "duplicateDoc", data: eligible({id: "W0", spatial: {tier: "great"}})});
  assert.equal(moodLists(walls, []).find((list) => list.id === "spatial_ready"), undefined);
});

test("walls that are reserved, dropped, streak exclusive, premium or unprotected never appear", () => {
  const good = Array.from({length: 12}, (_, i) => ({
    id: `good${i}`,
    data: eligible({id: `good${i}`, spatial: {tier: "great"}}),
  }));
  const excluded = [
    {id: "dropReserved", data: eligible({id: "dropReserved", spatial: {tier: "great"}, dropReserved: true})},
    {id: "dropWeek", data: eligible({id: "dropWeek", spatial: {tier: "great"}, dropWeek: "2026-W42"})},
    {id: "streak", data: eligible({id: "streak", spatial: {tier: "great"}, is_streak_exclusive: true})},
    {id: "premium", data: eligible({id: "premium", spatial: {tier: "great"}, collections: ["space"]})},
    {id: "unprotected", data: eligible({id: "unprotected", spatial: {tier: "great"}, originalProtected: false})},
  ];
  const [list] = moodLists([...good, ...excluded], ["space"]);
  assert.deepEqual([...list.wallIds].sort(), good.map((w) => w.id).sort());
});

test("walls with review false never appear", () => {
  const good = Array.from({length: 12}, (_, i) => ({
    id: `good${i}`,
    data: eligible({id: `good${i}`, spatial: {tier: "great"}}),
  }));
  const unreviewed = {id: "unreviewed", data: eligible({id: "unreviewed", spatial: {tier: "great"}, review: false})};
  const [list] = moodLists([...good, unreviewed], []);
  assert.deepEqual([...list.wallIds].sort(), good.map((w) => w.id).sort());
});

test("refreshMoods queries protected walls and writes only the eligible logical ids", async (t: TestContext) => {
  const protectedWall = (id: string, over: admin.firestore.DocumentData = {}) => eligible({
    id,
    spatial: {tier: "great"},
    wallpaper_url: "",
    wallpaper_path: "",
    wallpaper_sha: "",
    thumb_path: "",
    thumb_sha: "",
    ...over,
  });
  const seed = Object.fromEntries([
    ...Array.from({length: 12}, (_, i) => [`walls/doc${i}`, protectedWall(`W${i}`)] as const),
    ["walls/unprotected", protectedWall("UNPROTECTED", {originalProtected: false})],
    ["walls/publicOriginal", protectedWall("PUBLIC", {wallpaper_url: "https://example.com/original.jpg"})],
  ]);
  const store = installFakeDb(t, seed);
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({parameters: {}}));

  assert.deepEqual(await refreshMoods(), {spatial_ready: 12});
  assert.deepEqual(store.get("moods/current")?.moods, [{id: "spatial_ready", wallIds: Array.from({length: 12}, (_, i) => `W${i}`).sort()}]);
});
