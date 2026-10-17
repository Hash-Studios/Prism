import assert from "node:assert/strict";
import test from "node:test";
import {isDropLive, packPrice, planWeeklyDrop, releaseOldDrops, snapshotWall, unlockDrop} from "../drops";
import {resetEconomyCache, weekBounds, weekKey} from "../economy";
import {installFakeDb, type Doc} from "./fakeDb";

const MONDAY = Date.UTC(2026, 9, 19, 0, 30);
const KEY = weekKey(MONDAY);
const {start, end} = weekBounds(MONDAY);

const wall = (n: number, extra: Doc = {}): Doc => ({
  id: `W${n}`,
  title: `Wall ${n}`,
  wallpaper_thumb: `https://img/t${n}.jpg`,
  wallpaper_url: `https://img/f${n}.jpg`,
  resolution: "1440x3200",
  by: "Prism Studio",
  seriesId: "dusk",
  origin: "studio",
  review: false,
  dropReserved: true,
  createdAt: n,
  ...extra,
});

const reservedWalls = (count: number, extra: Doc = {}): Record<string, Doc> =>
  Object.fromEntries(Array.from({length: count}, (_, i) => [`walls/W${i + 1}`, wall(i + 1, extra)]));

async function plan(t: test.TestContext) {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  await planWeeklyDrop.run({jobName: "t", scheduleTime: new Date(MONDAY).toISOString()});
}

test("snapshotWall keeps the thumb and drops the full url", () => {
  const snap = snapshotWall({id: "W1", data: () => wall(1)});
  assert.deepEqual(snap, {
    id: "W1", title: "Wall 1", thumb: "https://img/t1.jpg", resolution: "1440x3200", by: "Prism Studio",
    seriesId: "dusk",
  });
});

test("packPrice never exceeds the cost of the walls left", () => {
  assert.equal(packPrice(30, 150, 10), 150);
  assert.equal(packPrice(30, 150, 6), 150);
  assert.equal(packPrice(30, 150, 5), 150);
  assert.equal(packPrice(30, 150, 4), 120);
  assert.equal(packPrice(30, 150, 1), 30);
});

test("isDropLive is true from the start and false from the end", () => {
  const drop = {startsAt: 100, endsAt: 200};
  assert.equal(isDropLive(drop, 99), false);
  assert.equal(isDropLive(drop, 100), true);
  assert.equal(isDropLive(drop, 199), true);
  assert.equal(isDropLive(drop, 200), false);
  assert.equal(isDropLive({}, 150), false);
});

test("the planner does nothing when the week already has a drop", async (t) => {
  const store = installFakeDb(t, {[`drops/${KEY}`]: {weekKey: KEY, title: "Old"}, ...reservedWalls(5)});
  await plan(t);
  assert.equal(store.get(`drops/${KEY}`)?.title, "Old");
  assert.equal(store.get("walls/W1")?.dropReserved, true);
});

test("the planner skips under four studio walls", async (t) => {
  const seed = {...reservedWalls(3), "walls/W9": wall(9, {origin: "user"}), "walls/W8": wall(8, {review: true})};
  const store = installFakeDb(t, seed);
  await plan(t);
  assert.equal(store.has(`drops/${KEY}`), false);
  assert.equal(store.get("walls/W1")?.dropReserved, true);
});

test("the planner writes snapshots, prices and flips the wall flags", async (t) => {
  const store = installFakeDb(t, {
    ...reservedWalls(12),
    "walls/X1": wall(99, {dropReserved: false}),
    "studioConfig/current": {dropTitles: {[KEY]: "Neon nights"}},
  });
  resetEconomyCache();
  await plan(t);
  const drop = store.get(`drops/${KEY}`) as Doc;
  assert.equal(drop.weekKey, KEY);
  assert.equal(drop.title, "Neon nights");
  assert.equal(drop.startsAt, start);
  assert.equal(drop.endsAt, end);
  assert.equal(drop.priceWall, 30);
  assert.equal(drop.pricePack, 150);
  assert.equal(drop.count, 10);
  const walls = drop.walls as Doc[];
  assert.deepEqual(walls.map((w) => w.id), Array.from({length: 10}, (_, i) => `W${i + 1}`));
  assert.equal("url" in walls[0], false);
  assert.equal(walls[0].thumb, "https://img/t1.jpg");
  assert.deepEqual([store.get("walls/W1")?.dropReserved, store.get("walls/W1")?.dropWeek], [false, KEY]);
  assert.equal(store.get("walls/W11")?.dropReserved, true);
  assert.equal(store.get("walls/X1")?.dropWeek, undefined);
});

test("the planner falls back to the default title", async (t) => {
  const store = installFakeDb(t, reservedWalls(4));
  await plan(t);
  assert.equal(store.get(`drops/${KEY}`)?.title, `Drop ${KEY}`);
});

test("old drops release their walls to the feed once", async (t) => {
  const day = 86_400_000;
  const store = installFakeDb(t, {
    "drops/2026-W30": {endsAt: MONDAY - 31 * day, walls: [{id: "W1"}, {id: "W2"}, {id: "GONE"}]},
    "drops/2026-W36": {endsAt: MONDAY - 29 * day, walls: [{id: "W3"}]},
    "drops/2026-W20": {endsAt: MONDAY - 90 * day, released: true, walls: [{id: "W4"}]},
    "walls/W1": wall(1, {dropReserved: false, dropWeek: "2026-W30"}),
    "walls/W2": wall(2, {dropReserved: false, dropWeek: "2026-W30"}),
    "walls/W3": wall(3, {dropReserved: false, dropWeek: "2026-W36"}),
    "walls/W4": wall(4, {dropReserved: false, dropWeek: "2026-W20"}),
  });
  assert.equal(await releaseOldDrops(MONDAY), 1);
  assert.equal(store.get("walls/W1")?.review, true);
  assert.equal(store.get("walls/W1")?.dropWeek, "2026-W30");
  assert.equal(store.get("walls/W2")?.review, true);
  assert.equal(store.get("walls/W3")?.review, false);
  assert.equal(store.get("walls/W4")?.review, false);
  assert.equal(store.get("drops/2026-W30")?.released, true);
  assert.equal(await releaseOldDrops(MONDAY), 0);
});

test("the planner releases old drops even when it plans nothing", async (t) => {
  const store = installFakeDb(t, {
    "drops/2026-W30": {endsAt: MONDAY - 40 * 86_400_000, walls: [{id: "W1"}]},
    "walls/W1": wall(1, {dropReserved: false}),
  });
  await plan(t);
  assert.equal(store.get("walls/W1")?.review, true);
  assert.equal(store.has(`drops/${KEY}`), false);
});

const live = {
  weekKey: KEY,
  title: "Neon nights",
  startsAt: Date.now() - 1000,
  endsAt: Date.now() + 86_400_000,
  priceWall: 30,
  pricePack: 150,
  count: 6,
  walls: Array.from({length: 6}, (_, i) => ({id: `W${i + 1}`, title: `Wall ${i + 1}`})),
};

const seedUnlock = (user: Doc = {}, priv?: Doc, drop: Doc = live): Record<string, Doc> => ({
  "usersv2/u1": {coins: 500, premium: false, ...user},
  [`drops/${KEY}`]: drop,
  ...Object.fromEntries(Array.from({length: 6}, (_, i) => [`walls/W${i + 1}`, wall(i + 1)])),
  ...(priv ? {"usersv2/u1/private/economy": priv} : {}),
});

const call = (data: Doc, uid = "u1") =>
  unlockDrop.run({auth: {uid, token: {}}, data} as Parameters<typeof unlockDrop.run>[0]) as Promise<Doc>;

const REQ = "req-00000001";

test("unlockDrop refuses bad input", async (t) => {
  installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await assert.rejects(call({weekKey: KEY, requestId: "short"}), {code: "invalid-argument"});
  await assert.rejects(call({weekKey: "nope", requestId: REQ}), {code: "invalid-argument"});
  await assert.rejects(call({weekKey: KEY, wallId: 5, requestId: REQ}), {code: "invalid-argument"});
  await assert.rejects(
    unlockDrop.run({data: {weekKey: KEY, requestId: REQ}} as Parameters<typeof unlockDrop.run>[0]),
    {code: "unauthenticated"},
  );
});

test("unlockDrop refuses when drops are off, not live, or the wall is not in the drop", async (t) => {
  const store = installFakeDb(t, {...seedUnlock(), "economyConfig/current": {flags: {dropsEnabled: false}}});
  resetEconomyCache();
  assert.equal((await call({weekKey: KEY, wallId: "W1", requestId: REQ})).reason, "drops_disabled");

  store.set("economyConfig/current", {flags: {dropsEnabled: true}});
  resetEconomyCache();
  assert.equal((await call({weekKey: KEY, wallId: "W99", requestId: REQ})).reason, "drop_wall_unknown");
  assert.equal((await call({weekKey: "2020-W01", wallId: "W1", requestId: REQ})).reason, "drop_not_live");

  store.set(`drops/${KEY}`, {...live, startsAt: Date.now() + 5000, endsAt: Date.now() + 9000});
  assert.equal((await call({weekKey: KEY, wallId: "W1", requestId: REQ})).reason, "drop_not_live");
  store.set(`drops/${KEY}`, {...live, startsAt: Date.now() - 9000, endsAt: Date.now() - 5000});
  assert.equal((await call({weekKey: KEY, requestId: REQ})).reason, "drop_not_live");
  assert.equal(store.get("usersv2/u1")?.coins, 500);
});

test("unlocking one wall debits the wall price and stores the url on the private doc", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  const res = await call({weekKey: KEY, wallId: "W2", requestId: REQ});
  assert.equal(res.success, true);
  assert.equal(res.changed, true);
  assert.equal(res.currentBalance, 470);
  assert.equal(res.delta, -30);
  assert.deepEqual(res.unlocked, [{id: "W2", url: "https://img/f2.jpg"}]);
  assert.equal(store.get("usersv2/u1")?.coins, 470);
  const priv = store.get("usersv2/u1/private/economy") as Doc;
  assert.equal(priv.rev, 1);
  assert.deepEqual((priv.drops as Doc).unlocked, {W2: {weekKey: KEY, url: "https://img/f2.jpg"}});
  const tx = store.get(`coinTransactions/ctx_drop_u1_${REQ}`) as Doc;
  assert.equal(tx.action, "dropWall");
  assert.equal(tx.reason, `drop_${KEY}`);
  assert.equal(tx.sourceTag, "drops.unlock.callable");
  assert.equal(tx.delta, -30);
});

test("unlocking a wall twice charges once", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await call({weekKey: KEY, wallId: "W2", requestId: REQ});
  const again = await call({weekKey: KEY, wallId: "W2", requestId: "req-00000002"});
  assert.equal(again.success, true);
  assert.equal(again.changed, false);
  assert.equal(again.reason, "drop_wall_already_unlocked");
  assert.equal(store.get("usersv2/u1")?.coins, 470);
});

test("the pack unlocks every wall left at the pack price", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  const res = await call({weekKey: KEY, requestId: REQ});
  assert.equal(res.delta, -150);
  assert.equal((res.unlocked as Doc[]).length, 6);
  assert.equal(store.get("usersv2/u1")?.coins, 350);
  assert.equal(Object.keys(((store.get("usersv2/u1/private/economy") as Doc).drops as Doc).unlocked as Doc).length, 6);
  assert.equal((store.get(`coinTransactions/ctx_drop_u1_${REQ}`) as Doc).action, "dropPack");
});

test("the pack costs only the walls left when you own some", async (t) => {
  const owned = Object.fromEntries(["W1", "W2"].map((id) => [id, {weekKey: KEY, url: `u-${id}`}]));
  const store = installFakeDb(t, seedUnlock({}, {rev: 4, drops: {unlocked: owned}}));
  resetEconomyCache();
  const res = await call({weekKey: KEY, requestId: REQ});
  assert.equal(res.delta, -120);
  assert.deepEqual((res.unlocked as Doc[]).map((w) => w.id), ["W3", "W4", "W5", "W6"]);
  const priv = store.get("usersv2/u1/private/economy") as Doc;
  assert.equal(priv.rev, 5);
  assert.equal(Object.keys((priv.drops as Doc).unlocked as Doc).length, 6);
});

test("the pack is refused when nothing is left", async (t) => {
  const owned = Object.fromEntries(live.walls.map((w) => [w.id, {weekKey: KEY, url: `u-${w.id}`}]));
  const store = installFakeDb(t, seedUnlock({}, {rev: 1, drops: {unlocked: owned}}));
  resetEconomyCache();
  const res = await call({weekKey: KEY, requestId: REQ});
  assert.equal(res.success, true);
  assert.equal(res.changed, false);
  assert.equal(res.reason, "drop_pack_nothing_left");
  assert.equal(store.get("usersv2/u1")?.coins, 500);
});

test("Pro pays half for a wall and for the pack", async (t) => {
  const store = installFakeDb(t, seedUnlock({premium: true}));
  resetEconomyCache();
  assert.equal((await call({weekKey: KEY, wallId: "W1", requestId: REQ})).delta, -15);
  const pack = await call({weekKey: KEY, requestId: "req-00000002"});
  assert.equal(pack.delta, -75);
  assert.equal(store.get("usersv2/u1")?.coins, 500 - 15 - 75);
});

test("an unlock is refused when the balance is too low", async (t) => {
  const store = installFakeDb(t, seedUnlock({coins: 20}));
  resetEconomyCache();
  const res = await call({weekKey: KEY, wallId: "W1", requestId: REQ});
  assert.equal(res.success, false);
  assert.equal(res.insufficientBalance, true);
  assert.equal(res.reason, "dropWall_insufficient_balance");
  assert.equal(store.get("usersv2/u1")?.coins, 20);
  assert.equal(store.has("usersv2/u1/private/economy"), false);
});

test("a wall with no url is not sold", async (t) => {
  const store = installFakeDb(t, {...seedUnlock(), "walls/W1": wall(1, {wallpaper_url: ""})});
  resetEconomyCache();
  const res = await call({weekKey: KEY, wallId: "W1", requestId: REQ});
  assert.equal(res.reason, "drop_wall_unavailable");
  assert.equal(store.get("usersv2/u1")?.coins, 500);
});

test("a replayed request returns the stored unlock and charges nothing", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await call({weekKey: KEY, wallId: "W3", requestId: REQ});
  store.set(`drops/${KEY}`, {...live, startsAt: 1, endsAt: 2});
  const replay = await call({weekKey: KEY, wallId: "W3", requestId: REQ});
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "duplicate");
  assert.equal(replay.currentBalance, 470);
  assert.deepEqual(replay.unlocked, [{id: "W3", url: "https://img/f3.jpg"}]);
  assert.equal(store.get("usersv2/u1")?.coins, 470);
});
