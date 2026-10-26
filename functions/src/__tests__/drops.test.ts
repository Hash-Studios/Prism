import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import * as notificationHelper from "../notificationHelper";
import {
  duePushKinds,
  type DropDoc,
  isDropLive,
  normalizeDropTitle,
  packPrice,
  planWeeklyDrop,
  releaseOldDrops,
  setDropTitle,
  sendDropPushes,
  snapshotWall,
  unlockDrop,
} from "../drops";
import {resetEconomyCache, weekBounds, weekKey} from "../economy";
import {db} from "../common";
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
  Object.fromEntries(
    Array.from({length: count}, (_, i) => [
      `walls/W${i + 1}`,
      wall(i + 1, extra),
    ]),
  );

async function plan(t: test.TestContext) {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  await planWeeklyDrop.run({
    jobName: "t",
    scheduleTime: new Date(MONDAY).toISOString(),
  });
}

test("snapshotWall keeps the thumb and drops the full url", () => {
  const snap = snapshotWall({id: "W1", data: () => wall(1)});
  assert.deepEqual(snap, {
    id: "W1",
    title: "Wall 1",
    thumb: "https://img/t1.jpg",
    resolution: "1440x3200",
    by: "Prism Studio",
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
  const store = installFakeDb(t, {
    [`drops/${KEY}`]: {weekKey: KEY, title: "Old"},
    ...reservedWalls(5),
  });
  await plan(t);
  assert.equal(store.get(`drops/${KEY}`)?.title, "Old");
  assert.equal(store.get("walls/W1")?.dropReserved, true);
});

test("the planner skips under four studio walls", async (t) => {
  const seed = {
    ...reservedWalls(3),
    "walls/W9": wall(9, {origin: "user"}),
    "walls/W8": wall(8, {review: true}),
  };
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
  assert.deepEqual(
    walls.map((w) => w.id),
    Array.from({length: 10}, (_, i) => `W${i + 1}`),
  );
  assert.equal("url" in walls[0], false);
  assert.equal(walls[0].thumb, "https://img/t1.jpg");
  assert.deepEqual(
    [store.get("walls/W1")?.dropReserved, store.get("walls/W1")?.dropWeek],
    [false, KEY],
  );
  assert.equal(store.get("walls/W11")?.dropReserved, true);
  assert.equal(store.get("walls/X1")?.dropWeek, undefined);
});

test("the planner falls back to a mood name when no title is set", async (t) => {
  const store = installFakeDb(t, reservedWalls(4));
  await plan(t);
  assert.equal(store.get(`drops/${KEY}`)?.title, "Daydream");
});

test("the planner ignores malformed titles in recent drops", async (t) => {
  const store = installFakeDb(t, {
    ...reservedWalls(4),
    "drops/2026-W42": {startsAt: start - 7 * 86_400_000, title: {toString: "not callable"}},
  });
  await plan(t);
  assert.equal(store.get(`drops/${KEY}`)?.title, "Daydream");
});

test("the planner uses a rename made after its initial reads", async (t) => {
  const store = installFakeDb(t, reservedWalls(4));
  const runTransaction = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    store.set("studioConfig/current", {dropTitles: {[KEY]: "Renamed before commit"}});
    return runTransaction(callback);
  });
  await plan(t);
  assert.equal(store.get(`drops/${KEY}`)?.title, "Renamed before commit");
});

const renameDrop = (data: Doc, auth: Doc = {uid: "admin", token: {admin: true}}) =>
  setDropTitle.run({auth, data} as unknown as Parameters<typeof setDropTitle.run>[0]);

test("setDropTitle renames an existing ended drop in the transaction", async (t) => {
  const store = installFakeDb(t, {"drops/2020-W53": {endsAt: 1, title: "Old title"}});
  const result = await renameDrop({weekKey: "2020-W53", title: "  New   title  "});
  assert.deepEqual(result, {title: "New title", applied: "drop"});
  assert.equal(store.get("drops/2020-W53")?.title, "New title");
});

test("setDropTitle saves a title for a drop that is not planned yet", async (t) => {
  const store = installFakeDb(t, {"studioConfig/current": {generationEnabled: true}});
  const result = await renameDrop({weekKey: KEY, title: "Future title"});
  assert.deepEqual(result, {title: "Future title", applied: "planned"});
  assert.deepEqual(store.get("studioConfig/current"), {
    generationEnabled: true,
    dropTitles: {[KEY]: "Future title"},
  });
});

test("setDropTitle rejects non-admin callers and invalid inputs without writes", async (t) => {
  const store = installFakeDb(t);
  await assert.rejects(renameDrop({weekKey: KEY, title: "Title"}, {uid: "user", token: {}}), {
    code: "permission-denied",
  });
  await assert.rejects(renameDrop({weekKey: "2026-W99", title: "Title"}), {code: "invalid-argument"});
  await assert.rejects(renameDrop({weekKey: KEY, title: "  "}), {code: "invalid-argument"});
  await assert.rejects(renameDrop({weekKey: KEY, title: "x".repeat(41)}), {code: "invalid-argument"});
  await assert.rejects(renameDrop({weekKey: KEY, title: 12}), {code: "invalid-argument"});
  await assert.rejects(renameDrop({weekKey: "2026-W00", title: "Title"}), {code: "invalid-argument"});
  await assert.rejects(renameDrop({weekKey: "2021-W53", title: "Title"}), {code: "invalid-argument"});
  assert.equal(store.size, 0);
});

test("old drops release their walls to the feed once", async (t) => {
  const day = 86_400_000;
  const store = installFakeDb(t, {
    "drops/2026-W30": {
      endsAt: MONDAY - 31 * day,
      walls: [{id: "W1"}, {id: "W2"}, {id: "GONE"}],
    },
    "drops/2026-W36": {endsAt: MONDAY - 29 * day, walls: [{id: "W3"}]},
    "drops/2026-W20": {
      endsAt: MONDAY - 90 * day,
      released: true,
      walls: [{id: "W4"}],
    },
    "walls/W1": wall(1, {dropReserved: false, dropWeek: "2026-W30"}),
    "walls/W2": wall(2, {dropReserved: false, dropWeek: "2026-W30"}),
    "walls/W3": wall(3, {dropReserved: false, dropWeek: "2026-W36"}),
    "walls/W4": wall(4, {dropReserved: false, dropWeek: "2026-W20"}),
  });
  assert.equal(await releaseOldDrops(MONDAY), 1);
  assert.equal(store.get("walls/W1")?.review, true);
  assert.equal(store.get("walls/W1")?.dropWeek, undefined, "a released wall must not keep the drop marker");
  assert.equal(store.get("walls/W1")?.dropReserved, undefined);
  assert.equal(store.get("walls/W2")?.review, true);
  assert.equal(store.get("walls/W2")?.dropWeek, undefined);
  assert.equal(store.get("walls/W3")?.review, false);
  assert.equal(store.get("walls/W4")?.review, false);
  assert.equal(store.get("drops/2026-W30")?.released, true);
  assert.equal(await releaseOldDrops(MONDAY), 0);
});

test("the planner releases old drops even when it plans nothing", async (t) => {
  const store = installFakeDb(t, {
    "drops/2026-W30": {
      endsAt: MONDAY - 40 * 86_400_000,
      walls: [{id: "W1"}],
    },
    "walls/W1": wall(1, {dropReserved: false, dropWeek: "2026-W30"}),
  });
  await plan(t);
  assert.equal(store.get("walls/W1")?.review, true);
  assert.equal(store.has(`drops/${KEY}`), false);
});

test("releasing an old snapshot cannot publish a wall reassigned to a pending drop or recreated without markers", async (t) => {
  const store = installFakeDb(t, {
    "drops/2026-W30": {endsAt: MONDAY - 40 * 86_400_000, walls: [{id: "W1"}, {id: "W2"}]},
    "walls/W1": wall(1, {dropWeek: KEY, dropReserved: true}),
    "walls/W2": wall(2, {dropReserved: false}),
  });
  assert.equal(await releaseOldDrops(MONDAY), 1);
  assert.equal(store.get("walls/W1")?.review, false);
  assert.equal(store.get("walls/W1")?.dropWeek, KEY);
  assert.equal(store.get("walls/W1")?.dropReserved, true);
  assert.equal(store.get("walls/W2")?.review, false);
  assert.equal(store.get("drops/2026-W30")?.released, true);
});

const live = {
  weekKey: KEY,
  title: "Neon nights",
  startsAt: Date.now() - 1000,
  endsAt: Date.now() + 86_400_000,
  priceWall: 30,
  pricePack: 150,
  count: 6,
  walls: Array.from({length: 6}, (_, i) => ({
    id: `W${i + 1}`,
    title: `Wall ${i + 1}`,
  })),
};

const seedUnlock = (
  user: Doc = {},
  priv?: Doc,
  drop: Doc = live,
): Record<string, Doc> => ({
  "usersv2/u1": {coins: 500, premium: false, ...user},
  [`drops/${KEY}`]: drop,
  ...Object.fromEntries(
    Array.from({length: 6}, (_, i) => [`walls/W${i + 1}`, wall(i + 1)]),
  ),
  ...(priv ? {"usersv2/u1/private/economy": priv} : {}),
});

const call = (data: Doc, uid = "u1") =>
  unlockDrop.run({auth: {uid, token: {}}, data} as Parameters<
    typeof unlockDrop.run
  >[0]) as Promise<Doc>;

const REQ = "req-00000001";

test("unlockDrop refuses bad input", async (t) => {
  installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await assert.rejects(call({weekKey: KEY, requestId: "short"}), {
    code: "invalid-argument",
  });
  await assert.rejects(call({weekKey: "nope", requestId: REQ}), {
    code: "invalid-argument",
  });
  await assert.rejects(call({weekKey: KEY, wallId: 5, requestId: REQ}), {
    code: "invalid-argument",
  });
  await assert.rejects(
    unlockDrop.run({data: {weekKey: KEY, requestId: REQ}} as Parameters<
      typeof unlockDrop.run
    >[0]),
    {code: "unauthenticated"},
  );
});

test("unlockDrop refuses when drops are off, not live, or the wall is not in the drop", async (t) => {
  const store = installFakeDb(t, {
    ...seedUnlock(),
    "economyConfig/current": {flags: {dropsEnabled: false}},
  });
  resetEconomyCache();
  assert.equal(
    (await call({weekKey: KEY, wallId: "W1", requestId: REQ})).reason,
    "drops_disabled",
  );

  store.set("economyConfig/current", {flags: {dropsEnabled: true}});
  resetEconomyCache();
  assert.equal(
    (await call({weekKey: KEY, wallId: "W99", requestId: REQ})).reason,
    "drop_wall_unknown",
  );
  assert.equal(
    (await call({weekKey: "2020-W01", wallId: "W1", requestId: REQ})).reason,
    "drop_not_live",
  );

  store.set(`drops/${KEY}`, {
    ...live,
    startsAt: Date.now() + 5000,
    endsAt: Date.now() + 9000,
  });
  assert.equal(
    (await call({weekKey: KEY, wallId: "W1", requestId: REQ})).reason,
    "drop_not_live",
  );
  store.set(`drops/${KEY}`, {
    ...live,
    startsAt: Date.now() - 9000,
    endsAt: Date.now() - 5000,
  });
  assert.equal(
    (await call({weekKey: KEY, requestId: REQ})).reason,
    "drop_not_live",
  );
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
  assert.deepEqual((priv.drops as Doc).unlocked, {
    W2: {weekKey: KEY, url: "https://img/f2.jpg"},
  });
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
  const again = await call({
    weekKey: KEY,
    wallId: "W2",
    requestId: "req-00000002",
  });
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
  assert.equal(
    Object.keys(
      ((store.get("usersv2/u1/private/economy") as Doc).drops as Doc)
        .unlocked as Doc,
    ).length,
    6,
  );
  assert.equal(
    (store.get(`coinTransactions/ctx_drop_u1_${REQ}`) as Doc).action,
    "dropPack",
  );
});

test("the pack costs only the walls left when you own some", async (t) => {
  const owned = Object.fromEntries(
    ["W1", "W2"].map((id) => [id, {weekKey: KEY, url: `u-${id}`}]),
  );
  const store = installFakeDb(
    t,
    seedUnlock({}, {rev: 4, drops: {unlocked: owned}}),
  );
  resetEconomyCache();
  const res = await call({weekKey: KEY, requestId: REQ});
  assert.equal(res.delta, -120);
  assert.deepEqual(
    (res.unlocked as Doc[]).map((w) => w.id),
    ["W3", "W4", "W5", "W6"],
  );
  const priv = store.get("usersv2/u1/private/economy") as Doc;
  assert.equal(priv.rev, 5);
  assert.equal(Object.keys((priv.drops as Doc).unlocked as Doc).length, 6);
});

test("the pack is refused when nothing is left", async (t) => {
  const owned = Object.fromEntries(
    live.walls.map((w) => [w.id, {weekKey: KEY, url: `u-${w.id}`}]),
  );
  const store = installFakeDb(
    t,
    seedUnlock({}, {rev: 1, drops: {unlocked: owned}}),
  );
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
  assert.equal(
    (await call({weekKey: KEY, wallId: "W1", requestId: REQ})).delta,
    -15,
  );
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
  const store = installFakeDb(t, {
    ...seedUnlock(),
    "walls/W1": wall(1, {wallpaper_url: ""}),
  });
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
  store.set("usersv2/u1", {...store.get("usersv2/u1"), coins: 900});
  const replay = await call({weekKey: KEY, wallId: "W3", requestId: REQ});
  assert.equal(replay.success, true);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "duplicate");
  assert.equal(replay.previousBalance, 500);
  assert.equal(replay.currentBalance, 470);
  assert.equal(replay.delta, -30);
  assert.deepEqual(replay.unlocked, [{id: "W3", url: "https://img/f3.jpg"}]);
  assert.equal(store.get("usersv2/u1")?.coins, 900);
});

const collectors = (store: Map<string, Doc>) =>
  store.get(`drops/${KEY}`)?.collectors;

test("collectors counts a user once per drop, on the first charged unlock", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await call({weekKey: KEY, wallId: "W1", requestId: REQ});
  assert.equal(collectors(store), 1);
  await call({weekKey: KEY, wallId: "W2", requestId: "req-00000002"});
  assert.equal(collectors(store), 1);
  await call({weekKey: KEY, requestId: "req-00000003"});
  assert.equal(collectors(store), 1);
});

test("collectors counts a pack bought as the first purchase", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await call({weekKey: KEY, requestId: REQ});
  assert.equal(collectors(store), 1);
});

test("collectors counts a second user and ignores walls owned from another drop", async (t) => {
  const store = installFakeDb(t, {
    ...seedUnlock(
      {},
      {
        rev: 1,
        drops: {unlocked: {OLD: {weekKey: "2020-W01", url: "u"}}},
      },
    ),
    "usersv2/u2": {coins: 500, premium: false},
  });
  resetEconomyCache();
  await call({weekKey: KEY, wallId: "W1", requestId: REQ});
  await call({weekKey: KEY, wallId: "W1", requestId: REQ}, "u2");
  assert.equal(collectors(store), 2);
});

test("collectors ignores replays, repeats, and a balance that is too low", async (t) => {
  const store = installFakeDb(t, seedUnlock());
  resetEconomyCache();
  await call({weekKey: KEY, wallId: "W3", requestId: REQ});
  await call({weekKey: KEY, wallId: "W3", requestId: REQ});
  await call({weekKey: KEY, wallId: "W3", requestId: "req-00000002"});
  assert.equal(collectors(store), 1);

  const poor = installFakeDb(t, seedUnlock({coins: 20}));
  resetEconomyCache();
  await call({weekKey: KEY, wallId: "W1", requestId: REQ});
  assert.equal(collectors(poor), undefined);
});

const H = 3_600_000;
const drop = (extra: Partial<DropDoc> = {}): DropDoc => ({
  weekKey: KEY,
  title: "Neon nights",
  startsAt: 1_000_000,
  endsAt: 1_000_000 + 168 * H,
  priceWall: 30,
  pricePack: 150,
  count: 6,
  walls: [],
  ...extra,
});

test("duePushKinds follows the live and last call windows", () => {
  const d = drop();
  assert.deepEqual(duePushKinds(d, d.startsAt), []);
  assert.deepEqual(duePushKinds(d, d.startsAt + 4 * H - 1), []);
  assert.deepEqual(duePushKinds(d, d.startsAt + 4 * H), ["live"]);
  assert.deepEqual(duePushKinds(d, d.endsAt - 12 * H - 1), ["live"]);
  assert.deepEqual(duePushKinds(d, d.endsAt - 12 * H), ["lastCall"]);
  assert.deepEqual(duePushKinds(d, d.endsAt - 1), ["lastCall"]);
});

test("duePushKinds skips a kind that was sent", () => {
  const sentLive = drop({pushes: {live: 5}});
  assert.deepEqual(duePushKinds(sentLive, sentLive.startsAt + 5 * H), []);
  assert.deepEqual(duePushKinds(sentLive, sentLive.endsAt - 12 * H), [
    "lastCall",
  ]);
  const sentBoth = drop({pushes: {live: 5, lastCall: 6}});
  assert.deepEqual(duePushKinds(sentBoth, sentBoth.endsAt - H), []);
});

test("a late run sends only the last call", () => {
  const d = drop();
  assert.deepEqual(duePushKinds(d, d.endsAt - 2 * H), ["lastCall"]);
});

const pushDrop = (extra: Partial<DropDoc> = {}): Doc => {
  const now = Date.now();
  return {
    ...drop({
      startsAt: now - 5 * H,
      endsAt: now + 100 * H,
      walls: [
        {
          id: "W1",
          title: "Wall 1",
          thumb: "https://img/t1.jpg",
          resolution: "",
          by: "",
          seriesId: "",
        },
      ],
      ...extra,
    }),
  };
};

const runPushes = (t: test.TestContext) => {
  const send = t.mock.method(
    notificationHelper,
    "sendNotification",
    async () => true,
  );
  return {
    send,
    run: () =>
      sendDropPushes.run({
        jobName: "t",
        scheduleTime: new Date().toISOString(),
      }),
  };
};

test("sendDropPushes sends the live push once with the full payload", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  const store = installFakeDb(t, {[`drops/${KEY}`]: pushDrop()});
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  await run();
  assert.equal(send.mock.callCount(), 1);
  assert.deepEqual(send.mock.calls[0].arguments[0], {
    title: "A new Drop is live",
    body: "6 walls, this week only. Preview them before they are gone.",
    message: {
      kind: "dropLive",
      args: {wallCount: 6},
      title: "A new Drop is live",
      body: "6 walls, this week only. Preview them before they are gone.",
    },
    data: {route: "drops", week_key: KEY},
    imageUrl: "https://img/t1.jpg",
    modifier: "all",
    channelId: "drops",
    fcmTarget: {topic: "drops"},
    collapseKey: `drop_live_${KEY}`,
    docId: `drop_live_${KEY}`,
    scoreKind: "drop",
  });
  assert.equal((store.get(`drops/${KEY}`)?.pushes as Doc).live, MONDAY);
});

test("sendDropPushes sends the last call text near the end", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  installFakeDb(t, {
    [`drops/${KEY}`]: pushDrop({
      endsAt: MONDAY + 12 * H,
      pushes: {live: 1},
    }),
  });
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  assert.equal(send.mock.callCount(), 1);
  const payload = send.mock.calls[0].arguments[0] as {
    title: string;
    body: string;
    docId: string;
  };
  assert.equal(payload.title, "Last call on this week's Drop");
  assert.equal(
    payload.body,
    "Neon nights ends in 12 hours. Then these walls are gone for a month.",
  );
  assert.equal(payload.docId, `drop_lastCall_${KEY}`);
});

test("sendDropPushes does nothing when drops are off or the drop is not live", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  const store = installFakeDb(t, {
    [`drops/${KEY}`]: pushDrop(),
    "economyConfig/current": {flags: {dropsEnabled: false}},
  });
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  store.set("economyConfig/current", {flags: {dropsEnabled: true}});
  resetEconomyCache();
  store.set(
    `drops/${KEY}`,
    pushDrop({startsAt: MONDAY + H, endsAt: MONDAY + 100 * H}),
  );
  await run();
  assert.equal(send.mock.callCount(), 0);
});

test("a failed send frees the claim and throws so the scheduler retries", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  const store = installFakeDb(t, {[`drops/${KEY}`]: pushDrop()});
  resetEconomyCache();
  const send = t.mock.method(
    notificationHelper,
    "sendNotification",
    async () => false,
  );
  const run = async () =>
    sendDropPushes.run({
      jobName: "t",
      scheduleTime: new Date().toISOString(),
    });
  await assert.rejects(run(), /push failed/);
  assert.equal(
    (store.get(`drops/${KEY}`)?.pushes as Doc | undefined)?.live,
    undefined,
  );
  assert.equal(
    (store.get(`drops/${KEY}`)?.pushClaims as Doc | undefined)?.live,
    undefined,
  );
  send.mock.mockImplementation(async () => true);
  await run();
  assert.equal(send.mock.callCount(), 2);
  assert.equal((store.get(`drops/${KEY}`)?.pushes as Doc).live, MONDAY);
});

const lastCallBody = async (t: test.TestContext, leftMs: number) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  installFakeDb(t, {
    [`drops/${KEY}`]: pushDrop({
      endsAt: MONDAY + leftMs,
      pushes: {live: 1},
    }),
  });
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  return (send.mock.calls[0].arguments[0] as { body: string }).body;
};

test("the last call body states the real hours left", async (t) => {
  assert.equal(
    await lastCallBody(t, 5 * H + 30 * 60 * 1000),
    "Neon nights ends in 5 hours. Then these walls are gone for a month.",
  );
});

test("the last call body says 1 hour in the singular", async (t) => {
  assert.equal(
    await lastCallBody(t, 30 * 60 * 1000),
    "Neon nights ends in 1 hour. Then these walls are gone for a month.",
  );
});

test("a stale in-flight claim is retried and sent", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  const store = installFakeDb(t, {
    [`drops/${KEY}`]: pushDrop({
      pushClaims: {live: MONDAY - 16 * 60 * 1000},
    }),
  });
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  assert.equal(send.mock.callCount(), 1);
  assert.equal((store.get(`drops/${KEY}`)?.pushes as Doc).live, MONDAY);
  assert.equal(
    (store.get(`drops/${KEY}`)?.pushClaims as Doc | undefined)?.live,
    undefined,
  );
});

test("a fresh in-flight claim blocks the send", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  installFakeDb(t, {
    [`drops/${KEY}`]: pushDrop({
      pushClaims: {live: MONDAY - 5 * 60 * 1000},
    }),
  });
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  assert.equal(send.mock.callCount(), 0);
});

test("a sent marker blocks even with a stale claim", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  installFakeDb(t, {
    [`drops/${KEY}`]: pushDrop({
      pushes: {live: 1},
      pushClaims: {live: MONDAY - H},
    }),
  });
  resetEconomyCache();
  const {send, run} = runPushes(t);
  await run();
  assert.equal(send.mock.callCount(), 0);
});

test("a failed send frees only its own claim", async (t) => {
  t.mock.timers.enable({apis: ["Date"], now: MONDAY});
  const store = installFakeDb(t, {[`drops/${KEY}`]: pushDrop()});
  resetEconomyCache();
  const send = t.mock.method(
    notificationHelper,
    "sendNotification",
    async () => {
      const doc = store.get(`drops/${KEY}`) as Doc;
      (doc.pushClaims as Doc).live = MONDAY + 1;
      return false;
    },
  );
  const run = async () =>
    sendDropPushes.run({
      jobName: "t",
      scheduleTime: new Date().toISOString(),
    });
  await assert.rejects(run(), /push failed/);
  assert.equal(send.mock.callCount(), 1);
  assert.equal((store.get(`drops/${KEY}`)?.pushClaims as Doc).live, MONDAY + 1);
});

test("normalizeDropTitle trims and collapses spaces", () => {
  assert.equal(normalizeDropTitle("  Night   Swim "), "Night Swim");
});

test("normalizeDropTitle rejects an empty title", () => {
  assert.equal(normalizeDropTitle(""), null);
});

test("normalizeDropTitle rejects a 41 character title", () => {
  assert.equal(normalizeDropTitle("a".repeat(41)), null);
});

test("normalizeDropTitle keeps a 40 character title", () => {
  const title = "a".repeat(40);
  assert.equal(normalizeDropTitle(title), title);
});

test("normalizeDropTitle rejects a number", () => {
  assert.equal(normalizeDropTitle(12), null);
});
