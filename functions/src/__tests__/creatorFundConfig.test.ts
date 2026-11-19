import assert from "node:assert/strict";
import test from "node:test";
import {DEFAULT_ECONOMY, parseEconomy} from "../economy";
import {previousWeek, weekRange} from "../creatorFund/load";
import {fundEventWrite} from "../creatorFund/events";
import {parseDryArgs} from "../scripts/creatorFundDry";

const DEFAULTS = DEFAULT_ECONOMY.creatorFund;
const fund = (creatorFund: unknown) => parseEconomy({creatorFund}).creatorFund;

test("a missing creatorFund block gives the default config", () => {
  assert.deepEqual(parseEconomy(null).creatorFund, DEFAULTS);
  assert.deepEqual(parseEconomy({}).creatorFund, DEFAULTS);
  assert.equal(DEFAULTS.pool, 0);
});

test("a bad pool falls back to 0 so a broken config never pays", () => {
  for (const pool of [-1, 1.5, "100", 200000, null]) {
    assert.equal(fund({...DEFAULTS, pool}).pool, 0);
  }
  assert.equal(fund({...DEFAULTS, pool: 100000}).pool, 100000);
  assert.equal(fund({...DEFAULTS, pool: 5000}).pool, 5000);
});

test("a bad weight falls back to the default for that metric only", () => {
  const parsed = fund({...DEFAULTS, pool: 10, weights: {saves: -1, sets: 7, downloads: "2", remixes: 101,
    folderAdds: 4}});
  assert.deepEqual(parsed.weights, {saves: 1, sets: 7, downloads: 2, remixes: 5, folderAdds: 4});
});

test("minPayout above perCreatorCap falls back to the default", () => {
  const parsed = fund({...DEFAULTS, perCreatorCap: 3, minPayout: 4});
  assert.equal(parsed.perCreatorCap, 3);
  assert.equal(parsed.minPayout, 3);
  const ok = fund({...DEFAULTS, perCreatorCap: 50, minPayout: 9});
  assert.equal(ok.minPayout, 9);
  const bad = fund({...DEFAULTS, perCreatorCap: 50, minPayout: 60});
  assert.equal(bad.minPayout, DEFAULTS.minPayout);
});

test("excludedUids keeps only valid unique ID strings", () => {
  const parsed = fund({...DEFAULTS, excludedUids: ["team1", 7, null, "bad/id", "", "team1", "a b", "ok_Two-3"]});
  assert.deepEqual(parsed.excludedUids, ["team1", "ok_Two-3"]);
});

test("percent and distinct-user fields keep valid values and reject out of range ones", () => {
  const parsed = fund({...DEFAULTS, maxUserSharePercent: 150, minDistinctUsers: 0});
  assert.equal(parsed.maxUserSharePercent, DEFAULTS.maxUserSharePercent);
  assert.equal(parsed.minDistinctUsers, DEFAULTS.minDistinctUsers);
  assert.equal(fund({...DEFAULTS, maxUserSharePercent: 25}).maxUserSharePercent, 25);
});

test("weekRange gives Monday to next Monday in UTC", () => {
  assert.equal(weekRange("2026-W46").start, Date.UTC(2026, 10, 9));
  assert.equal(weekRange("2026-W46").end, Date.UTC(2026, 10, 16));
});

test("weekRange rejects a week that does not exist and a malformed key", () => {
  assert.throws(() => weekRange("2026-W54"), /Bad week key/);
  assert.throws(() => weekRange("bad"), /Bad week key/);
});

test("previousWeek gives the ISO week before the given time", () => {
  assert.equal(previousWeek(Date.UTC(2026, 10, 16, 6)), "2026-W46");
  assert.equal(previousWeek(Date.UTC(2026, 10, 15, 23, 59)), "2026-W45");
});

test("fundEventWrite gives one document per week, wall, metric and actor", () => {
  const monday = Date.UTC(2026, 10, 10, 9);
  const sameWeek = Date.UTC(2026, 10, 14, 20);
  const nextWeek = Date.UTC(2026, 10, 16, 9);
  const a = fundEventWrite("W1", "saves", "fan", monday);
  assert.equal(a.ref.id, fundEventWrite("W1", "saves", "fan", sameWeek).ref.id);
  assert.notEqual(a.ref.id, fundEventWrite("W1", "saves", "fan", nextWeek).ref.id);
  assert.notEqual(a.ref.id, fundEventWrite("W2", "saves", "fan", monday).ref.id);
  assert.notEqual(a.ref.id, fundEventWrite("W1", "sets", "fan", monday).ref.id);
  assert.notEqual(a.ref.id, fundEventWrite("W1", "saves", "other", monday).ref.id);
  assert.equal(a.data.week, "2026-W46");
  assert.equal(a.data.wallId, "W1");
  assert.equal(a.data.expireAt.toMillis(), monday + 63 * 86_400_000);
});

test("parseDryArgs reads the flags", () => {
  const now = Date.UTC(2026, 10, 18, 10);
  assert.deepEqual(parseDryArgs(["--week", "2026-W45", "--source", "legacy", "--pool", "1000,5000", "--top", "3"], now), {
    week: "2026-W45", source: "legacy", pools: [1000, 5000], top: 3,
  });
  assert.deepEqual(parseDryArgs([], now), {week: "2026-W46", source: "auto", pools: null, top: 20});
  assert.deepEqual(parseDryArgs(["--week=2026-W44"], now).week, "2026-W44");
});

test("parseDryArgs rejects an unknown source and bad pools", () => {
  const now = Date.UTC(2026, 10, 18, 10);
  assert.throws(() => parseDryArgs(["--source", "x"], now), /--source must be/);
  assert.throws(() => parseDryArgs(["--pool", "100001"], now), /--pool must be/);
  assert.throws(() => parseDryArgs(["--pool", "1.5"], now), /--pool must be/);
});
