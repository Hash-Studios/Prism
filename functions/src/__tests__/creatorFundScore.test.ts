import assert from "node:assert/strict";
import test from "node:test";
import {type CreatorFundConfig, type CreatorFundMetric, DEFAULT_ECONOMY} from "../economy";
import {computeCreatorFund, type CreatorGate, type FundEvent} from "../creatorFund/score";

const RULES: CreatorFundConfig = {...DEFAULT_ECONOMY.creatorFund, pool: 100, maxUserSharePercent: 100};

const ev = (wallId: string, metric: CreatorFundMetric, actorUid: string): FundEvent => ({wallId, metric, actorUid});

function input(events: FundEvent[], options: {walls: Record<string, string>; gates?: Record<string, CreatorGate>;
  excluded?: string[]; rules?: Partial<CreatorFundConfig>}) {
  const gates = options.gates ?? Object.fromEntries(Object.values(options.walls).map((uid) => [uid, "ok"]));
  return {
    events,
    wallCreators: new Map(Object.entries(options.walls)),
    creatorGates: new Map<string, CreatorGate>(Object.entries(gates)),
    excludedActors: new Set(options.excluded ?? []),
    rules: {...RULES, ...options.rules},
  };
}

test("weights add per actor in hundredths", () => {
  const events = ["a1", "a2", "a3", "a4", "a5"].map((uid) => ev("w1", "sets", uid));
  const result = computeCreatorFund(input(events, {walls: {w1: "creator"}}));
  assert.equal(result.rows.length, 1);
  assert.equal(result.rows[0].uid, "creator");
  assert.equal(result.rows[0].scoreCenti, 1500);
  assert.equal(result.rows[0].distinctUsers, 5);
  assert.equal(result.rows[0].capped, false);
});

test("a repeat of the same wall, metric and actor counts once", () => {
  const events = [ev("w1", "saves", "fan"), ev("w1", "saves", "fan"), ev("w1", "sets", "fan")];
  const result = computeCreatorFund(input(events, {walls: {w1: "creator"}, rules: {minDistinctUsers: 1}}));
  assert.equal(result.rows[0].scoreCenti, 400);
  assert.equal(result.rows[0].distinctUsers, 1);
});

test("self actions, excluded actors and walls outside wallCreators do not count", () => {
  const events = [
    ev("w1", "saves", "creator"),
    ev("w1", "saves", "team1"),
    ev("w1", "saves", "fan"),
    ev("gone", "saves", "fan"),
  ];
  const result = computeCreatorFund(input(events, {walls: {w1: "creator"}, excluded: ["team1"],
    rules: {minDistinctUsers: 1}}));
  assert.equal(result.rows.length, 1);
  assert.equal(result.rows[0].uid, "creator");
  assert.equal(result.rows[0].scoreCenti, 100);
  assert.equal(result.rows[0].distinctUsers, 1);
});

test("the per-user cap limits a heavy actor to its share of the raw score", () => {
  const walls = Object.fromEntries([...Array.from({length: 10}, (_, i) => [`w${i}`, "creator"]), ["wx", "creator"]]);
  const events: FundEvent[] = Array.from({length: 10}, (_, i) => ev(`w${i}`, "saves", "heavy"));
  for (let i = 1; i <= 9; i++) events.push(ev("wx", "saves", `light${i}`));
  const result = computeCreatorFund(input(events, {walls, rules: {maxUserSharePercent: 10}}));
  const row = result.rows[0];
  assert.equal(row.distinctUsers, 10);
  assert.equal(row.scoreCenti, 190 + 900);
  assert.equal(row.capped, true);
});

test("fewer distinct users than the minimum does not qualify", () => {
  const events = ["a1", "a2", "a3", "a4"].map((uid) => ev("w1", "saves", uid));
  const result = computeCreatorFund(input(events, {walls: {w1: "creator"}}));
  assert.deepEqual(result.rows.map((row) => [row.uid, row.status, row.status === "notQualified" && row.reason]),
    [["creator", "notQualified", "fewUsers"]]);
  assert.equal(result.totals.qualified, 0);
  assert.equal(result.totals.paid, 0);
  assert.equal(result.totals.coins, 0);
  assert.equal(result.totals.unpaid, 100);
});

test("team and moderation gates give notQualified rows and a closed gate gives no row", () => {
  const events = ["a1", "a2", "a3", "a4", "a5"].flatMap((uid) =>
    ["mod", "team", "closed"].map((creator) => ev(`w-${creator}`, "saves", uid)));
  const result = computeCreatorFund(input(events, {
    walls: {"w-mod": "mod", "w-team": "team", "w-closed": "closed"},
    gates: {mod: "moderation", team: "team", closed: "closed"},
  }));
  assert.deepEqual(result.rows.map((row) => [row.uid, row.status, row.status === "notQualified" && row.reason]), [
    ["mod", "notQualified", "moderation"],
    ["team", "notQualified", "team"],
  ]);
  assert.equal(result.totals.creators, 2);
  assert.equal(result.totals.qualified, 0);
});

test("floor, per-creator cap and minimum payout", () => {
  const five = (wallId: string, uid: string, metric: CreatorFundMetric = "saves") =>
    ["a1", "a2", "a3", "a4", "a5"].map((actor) => ev(wallId, metric, `${uid}-${actor}`));

  const even = computeCreatorFund(input(
    [...five("w1", "x"), ...five("w2", "y"), ...five("w3", "z")],
    {walls: {w1: "x", w2: "y", w3: "z"}, rules: {pool: 100}},
  ));
  assert.deepEqual(even.rows.map((row) => row.status === "paid" && row.coins), [33, 33, 33]);
  assert.equal(even.totals.coins, 99);
  assert.equal(even.totals.unpaid, 1);

  const mixed = computeCreatorFund(input(
    [
      ...["h1", "h2", "h3"].map((actor) => ev("wh", "remixes", actor)),
      ...["f1", "f2", "f3"].map((actor) => ev("wf", "saves", actor)),
      ev("wl", "saves", "l1"),
    ],
    {walls: {wh: "high", wf: "floor", wl: "low"}, rules: {pool: 50, perCreatorCap: 20, minDistinctUsers: 1}},
  ));
  assert.deepEqual(mixed.rows.map((row) => [row.uid, row.status, row.status === "paid" ? row.coins :
    row.status === "notQualified" && row.reason]), [
    ["floor", "paid", 7],
    ["high", "paid", 20],
    ["low", "notQualified", "smallShare"],
  ]);
  assert.equal(mixed.totals.paid, 2);
  assert.equal(mixed.totals.coins, 27);
  assert.equal(mixed.totals.unpaid, 23);
});

test("a zero pool leaves every qualified creator below the minimum payout", () => {
  const events = ["a1", "a2", "a3", "a4", "a5"].map((uid) => ev("w1", "saves", uid));
  const result = computeCreatorFund(input(events, {walls: {w1: "creator"}, rules: {pool: 0}}));
  assert.deepEqual(result.rows.map((row) => [row.status, row.status === "notQualified" && row.reason]),
    [["notQualified", "smallShare"]]);
  assert.equal(result.totals.qualified, 1);
  assert.equal(result.totals.paid, 0);
  assert.equal(result.totals.coins, 0);
  assert.equal(result.totals.unpaid, 0);
});

test("rows come out sorted by uid and the same input gives the same result", () => {
  const actors = ["a1", "a2", "a3", "a4", "a5"];
  const events = [
    ...actors.map((uid) => ev("wz", "saves", uid)),
    ...actors.map((uid) => ev("wa", "saves", uid)),
    ...actors.map((uid) => ev("wm", "saves", uid)),
  ].reverse();
  const walls = {wz: "z", wa: "a", wm: "m"};
  const first = computeCreatorFund(input(events, {walls}));
  assert.deepEqual(first.rows.map((row) => row.uid), ["a", "m", "z"]);
  assert.deepEqual(computeCreatorFund(input(events, {walls})), first);
});
