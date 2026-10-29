import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {readCreatorStats, deliverCreatorWeek, sendCreatorWeeklyStats} from "../creatorStats";
import {addHistory, atOrAfter, countFolderCreation, historyRef, isoWeek, MAX_IDENTITY_WALLS, projectDailyStats, weekWindows} from "../creatorStatsHistory";
import {syncRemixCredit} from "../wallRemix";
import {nativeNotificationLocalization, renderNotificationCopy} from "../notificationCatalog";
import {installFakeDb, type Doc} from "./fakeDb";

const NOW = Date.parse("2026-10-26T09:00:00Z");
const wall = (extra: Doc = {}): Doc => ({id: "WALL", creatorUid: "alice", review: true, title: "Dunes",
  wallpaper_thumb: "https://example.com/wall.jpg", remixCount: 2, ...extra});
const seed = (extra: Record<string, Doc> = {}) => ({"usersv2/alice": {email: "alice@example.com"},
  "usersv2/bob": {email: "bob@example.com"}, "walls/wall": wall(),
  "wallpaper_stats/WALL": {views: 10, favs: 3, sets: 4, downloads: 5, shares: 6}, ...extra});
const fails = (code: string) => (err: unknown) => !!err && typeof err === "object" && "code" in err && err.code === code;
async function putHistory(metrics: {views?: number; remixes?: number}, ms = NOW - 7 * 86400000) {
  const snap = await db.doc("walls/wall").get();
  await historyRef(snap).set(addHistory(snap, undefined, metrics, ms, ms));
}

test("creator stats rejects unauthenticated callers and all identity overrides", async (t) => {
  installFakeDb(t, seed());
  await assert.rejects(readCreatorStats("", {}, NOW), fails("unauthenticated"));
  for (const input of [null, [], "", {uid: "bob"}, {creatorUid: "bob"}, {email: "alice@example.com"}, {wallId: "WALL"}]) {
    await assert.rejects(readCreatorStats("alice", input, NOW), fails("invalid-argument"));
  }
});
test("only approved UID-owned walls contribute, with totals and eight weeks per wall", async (t) => {
  installFakeDb(t, seed({"walls/bob": wall({id: "BOB", creatorUid: "bob"}),
    "walls/draft": wall({id: "DRAFT", review: false}), "walls/legacy": wall({id: "OLD", creatorUid: undefined, email: "alice@example.com"})}));
  await putHistory({views: 7});
  const stats = await readCreatorStats("alice", {}, NOW);
  assert.equal(stats.approvedWallCount, 1);
  assert.deepEqual(stats.totals, {views: 10, saves: 3, sets: 4, downloads: 5, shares: 6, folderAdds: 0, remixes: 2});
  assert.equal(stats.weeks.length, 8);
  assert.equal(stats.weeks[6].week, "2026-W43");
  assert.equal(stats.weeks[6].metrics.views, 7);
  assert.equal(stats.weeks[0].metrics.views, null);
  assert.equal(stats.walls[0].wallId, "wall");
  assert.deepEqual(stats.walls[0].weeks.map((w) => w.start), stats.weeks.map((w) => w.start));
  assert.equal(stats.coverage.saves.totalBasis, "currentMembership");
  assert.equal(stats.coverage.folderAdds.totalBasis, "since");
  assert.equal("uid" in stats, false);
});
test("ISO UTC weeks handle Sunday, Monday, and ISO year boundaries", () => {
  assert.equal(isoWeek(Date.parse("2021-01-01T00:00:00Z")), "2020-W53");
  assert.equal(isoWeek(Date.parse("2021-01-03T23:59:59Z")), "2020-W53");
  assert.equal(isoWeek(Date.parse("2021-01-04T00:00:00Z")), "2021-W01");
  const weeks = weekWindows(Date.parse("2024-12-30T00:00:00Z"));
  assert.equal(weeks[7].week, "2025-W01");
  assert.equal(weeks[7].endExclusive, "2025-01-06T00:00:00.000Z");
});
test("missing history remains null during wall and creator aggregation", async (t) => {
  installFakeDb(t, seed({"walls/second": wall({id: "SECOND"})}));
  await putHistory({views: 7});
  const stats = await readCreatorStats("alice", {}, NOW);
  assert.equal(stats.weeks[6].metrics.views, null);
  assert.equal(stats.totals.folderAdds, null);
  assert.equal(stats.coverage.views.weeklyFrom, null);
});
test("empty creator has zero totals, eight weeks, and no walls", async (t) => {
  installFakeDb(t, seed());
  const result = await readCreatorStats("bob", {}, NOW);
  assert.equal(result.approvedWallCount, 0);
  assert.deepEqual(result.walls, []);
  assert.equal(result.totals.views, 0);
  assert.equal(result.weeks.length, 8);
});
test("warm caches recheck ownership, approval, deletion, and account existence", async (t) => {
  const store = installFakeDb(t, seed());
  await readCreatorStats("alice", {}, NOW);
  store.set("walls/wall", wall({creatorUid: "bob"}));
  assert.equal((await readCreatorStats("alice", {}, NOW + 1)).approvedWallCount, 0);
  assert.equal((await readCreatorStats("bob", {}, NOW + 1)).approvedWallCount, 1);
  store.set("walls/wall", wall({review: false}));
  assert.equal((await readCreatorStats("alice", {}, NOW + 2)).approvedWallCount, 0);
  store.set("creatorDeletionState/alice", {closed: true});
  await assert.rejects(readCreatorStats("alice", {}, NOW + 3), fails("failed-precondition"));
  store.delete("creatorDeletionState/alice");
  store.delete("usersv2/alice");
  await assert.rejects(readCreatorStats("alice", {}, NOW + 4), fails("failed-precondition"));
});
test("duplicate logical IDs never share aggregate counters, including warm cache changes", async (t) => {
  const store = installFakeDb(t, seed());
  assert.equal((await readCreatorStats("alice", {}, NOW)).totals.views, 10);
  store.set("walls/bob", wall({creatorUid: "bob"}));
  assert.equal((await readCreatorStats("alice", {}, NOW + 1)).totals.views, null);
  assert.equal((await readCreatorStats("bob", {}, NOW + 1)).totals.views, null);
});
test("recreated walls cannot use the previous incarnation cache, history, or old lifetime stats", async (t) => {
  const store = installFakeDb(t, seed());
  await putHistory({views: 7});
  await readCreatorStats("alice", {}, NOW);
  store.delete("walls/wall");
  store.set("walls/wall", wall());
  const result = await readCreatorStats("alice", {}, NOW + 1);
  assert.equal(result.weeks[6].metrics.views, null);
  assert.equal(result.totals.views, null);
});
test("500 walls are complete with bounded cold and warm reads and cache documents", async (t) => {
  const docs: Record<string, Doc> = {"usersv2/alice": {email: "alice@example.com"}};
  for (let i = 0; i < 500; i++) {
    docs[`walls/w${i}`] = wall({id: `W${i}`});
    docs[`wallpaper_stats/W${i}`] = {views: 1};
  }
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, docs, observed);
  const cold = await readCreatorStats("alice", {}, NOW);
  assert.equal(cold.walls.length, 500);
  assert.equal(cold.totals.views, 500);
  assert.equal(observed.reads, 2502);
  assert.equal(observed.writes, 500);
  for (const [path, data] of store) if (path.startsWith("creatorStatsCache/")) assert.ok(Buffer.byteLength(JSON.stringify(data)) < 12000);
  observed.reads = 0; observed.writes = 0;
  const warm = await readCreatorStats("alice", {}, NOW + 1);
  assert.equal(warm.walls.length, 500);
  assert.equal(observed.reads, 1502);
  assert.equal(observed.writes, 0);
  assert.ok(Buffer.byteLength(JSON.stringify(cold)) < 3 * 1024 * 1024);
});
test("501 walls and over-size wall metadata return explicit capacity errors", async (t) => {
  const store = installFakeDb(t, seed());
  for (let i = 0; i < 500; i++) store.set(`walls/w${i}`, wall({id: `W${i}`}));
  await assert.rejects(readCreatorStats("alice", {}, NOW), fails("resource-exhausted"));
  for (let i = 0; i < 500; i++) store.delete(`walls/w${i}`);
  store.set("walls/wall", wall({title: "x".repeat(12000)}));
  await assert.rejects(readCreatorStats("alice", {}, NOW), fails("resource-exhausted"));
});
test("cache expires at five minutes and at a new UTC week", async (t) => {
  const store = installFakeDb(t, seed());
  await readCreatorStats("alice", {}, NOW);
  store.set("wallpaper_stats/WALL", {views: 20});
  assert.equal((await readCreatorStats("alice", {}, NOW + 299999)).totals.views, 10);
  assert.equal((await readCreatorStats("alice", {}, NOW + 300000)).totals.views, 20);
  const sunday = Date.parse("2026-11-01T23:59:59Z");
  await readCreatorStats("alice", {}, sunday);
  const monday = await readCreatorStats("alice", {}, sunday + 1000);
  assert.equal(monday.weeks[7].week, "2026-W45");
});
test("concurrent cold calls return complete results without shared cache mutation", async (t) => {
  installFakeDb(t, seed());
  const results = await Promise.all(Array.from({length: 10}, () => readCreatorStats("alice", {}, NOW)));
  assert.ok(results.every((result) => result.totals.views === 10 && result.walls.length === 1));
});

test("daily projection uses latest source, counts retries once, and preserves history after TTL deletion", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 3, favs: 2}}));
  await projectDailyStats(path, NOW);
  await projectDailyStats(path, NOW);
  store.set(path, {wallId: "WALL", day: "20261025", views: 5, favs: 2});
  await projectDailyStats(path, NOW);
  store.delete(path);
  await projectDailyStats(path, NOW);
  const snap = await db.doc("walls/wall").get();
  const history = (await historyRef(snap).get()).data();
  assert.equal(history?.weeks["2026-W43"].views, 5);
  assert.equal(history?.weeks["2026-W43"].saves, 2);
  assert.equal([...store.keys()].filter((p) => p.startsWith("creatorStatsDailyCheckpoints/")).length, 1);
});
test("daily source recreation is a new incarnation, lower snapshots cannot subtract history", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 5}}));
  await projectDailyStats(path, NOW);
  store.set(path, {wallId: "WALL", day: "20261025", views: 2});
  await projectDailyStats(path, NOW);
  store.delete(path);
  store.set(path, {wallId: "WALL", day: "20261025", views: 1});
  await projectDailyStats(path, NOW);
  const snap = await db.doc("walls/wall").get();
  assert.equal((await historyRef(snap).get()).data()?.weeks["2026-W43"].views, 6);
});
test("history map prunes to nine weeks and ignores old daily sources", async (t) => {
  installFakeDb(t, seed());
  const snap = await db.doc("walls/wall").get();
  let history = addHistory(snap, undefined, {views: 1}, NOW, NOW);
  for (let i = 1; i < 20; i++) history = addHistory(snap, history, {views: 1}, NOW + i * 7 * 86400000, NOW + i * 7 * 86400000);
  assert.equal(Object.keys(history.weeks).length, 9);
  const next = addHistory(snap, history, {views: 100}, NOW, NOW + 19 * 7 * 86400000);
  assert.equal(Object.keys(next.weeks).length, 9);
  assert.equal(next.weeks["2026-W44"], undefined);
});
test("daily projection fails closed for shared stats ID or deleted creator", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 5}, "walls/other": wall({creatorUid: "bob"})}));
  await projectDailyStats(path, NOW);
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsHistory/")), false);
  store.delete("walls/other"); store.set("creatorDeletionState/alice", {closed: true});
  await projectDailyStats(path, NOW);
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsHistory/")), false);
});

async function folderSource() {
  return db.doc("folders/f/items/item").get();
}
const item = {id: "WALL", ownerId: "bob", provider: "Prism", wallpaperDocumentId: "wall"};
test("folder source creation counts once per path and creation incarnation without decrement", async (t) => {
  const store = installFakeDb(t, seed({"folders/f": {ownerId: "bob"}, "folders/f/items/item": item}));
  const source = await folderSource();
  await countFolderCreation(source, NOW); await countFolderCreation(source, NOW);
  store.delete("folders/f/items/item");
  await countFolderCreation(source, NOW);
  store.set("folders/f/items/item", item);
  await countFolderCreation(await folderSource(), NOW);
  const snap = await db.doc("walls/wall").get();
  assert.equal((await historyRef(snap).get()).data()?.folderAdds, 2);
});
test("folder rejects wrong owner, provider, canonical wall, and deletion barriers", async (t) => {
  const store = installFakeDb(t, seed({"folders/f": {ownerId: "bob"}, "folders/f/items/item": item}));
  for (const bad of [{...item, ownerId: "alice"}, {...item, provider: "Pexels"}, {...item, id: "OTHER"},
    {...item, wallpaperDocumentId: "missing"}]) {
    store.set("folders/f/items/item", bad);
    await countFolderCreation(await folderSource(), NOW);
  }
  store.set("folders/f/items/item", item); store.set("creatorDeletionState/bob", {closed: true});
  await countFolderCreation(await folderSource(), NOW);
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsFolderMarkers/")), false);
});

test("remix first credit survives withdrawal, replay, and reapproval while live count changes", async (t) => {
  const store = installFakeDb(t, seed({"walls/wall": wall({isAiGenerated: true, aiPrompt: "Dunes", email: "alice@example.com", remixCount: 0}),
    "walls/remix": wall({id: "REMIX", creatorUid: "bob", email: "bob@example.com", isAiGenerated: true, remixOf: "wall"})}));
  await syncRemixCredit("remix"); await syncRemixCredit("remix");
  assert.equal(store.get("walls/wall")?.remixCount, 1);
  store.set("walls/remix", {...store.get("walls/remix"), review: false});
  await syncRemixCredit("remix");
  assert.equal(store.get("walls/wall")?.remixCount, 0);
  store.set("walls/remix", {...store.get("walls/remix"), review: true});
  await syncRemixCredit("remix");
  const snap = await db.doc("walls/wall").get();
  const weeks = (await historyRef(snap).get()).data()?.weeks;
  assert.equal(Object.values(weeks).reduce((n: number, row) => n + Number((row as Doc).remixes ?? 0), 0), 1);
  assert.equal(store.get("walls/wall")?.remixCount, 1);
});
test("Monday inbox has atomic UID/week dedupe, no recency filter, no push, and the copy contract", async (t) => {
  const store = installFakeDb(t, seed({"usersv2/alice": {email: "alice@example.com", lastAppOpenAt: "2000-01-01"}}));
  await putHistory({views: 2});
  assert.equal(await deliverCreatorWeek("alice", NOW), true);
  assert.equal(await deliverCreatorWeek("alice", NOW), false);
  const notifications = [...store].filter(([p]) => p.startsWith("notifications/"));
  assert.equal(notifications.length, 1);
  assert.deepEqual(notifications[0][1].message, {kind: "creatorStatsWeekly", args: {week: "2026-W43"}});
  assert.equal(notifications[0][1].modifier, "alice@example.com");
  assert.equal(notifications[0][1].pushHandled, true);
  assert.deepEqual(notifications[0][1].notification, {title: "Your walls this week", body: "See how your walls did in 2026-W43."});
  assert.equal((notifications[0][1].data as Doc).url, "prism://creator-stats");
  assert.equal(nativeNotificationLocalization(renderNotificationCopy({kind: "creatorStatsWeekly", week: "2026-W43"})), null);
});
test("weekly inbox skips opt-out, no activity, withdrawal, and account deletion", async (t) => {
  const store = installFakeDb(t, seed());
  assert.equal(await deliverCreatorWeek("alice", NOW), false);
  await putHistory({views: 2});
  store.set("usersv2/alice/private/session", {postAlerts: false});
  assert.equal(await deliverCreatorWeek("alice", NOW), false);
  store.delete("usersv2/alice/private/session"); store.set("walls/wall", wall({review: false}));
  assert.equal(await deliverCreatorWeek("alice", NOW), false);
  store.set("walls/wall", wall()); store.set("creatorDeletionState/alice", {closed: true});
  assert.equal(await deliverCreatorWeek("alice", NOW), false);
});
test("Monday job scans approved creators without account recency or duplicate inboxes", async (t) => {
  const store = installFakeDb(t, seed());
  await putHistory({views: 2});
  await sendCreatorWeeklyStats(NOW); await sendCreatorWeeklyStats(NOW);
  assert.equal([...store.keys()].filter((p) => p.startsWith("notifications/")).length, 1);
});

test("replaying a credit accepted before instrumentation does not invent weekly remix history", async (t) => {
  const store = installFakeDb(t, seed({"walls/wall": wall({isAiGenerated: true, aiPrompt: "Dunes", email: "alice@example.com", remixCount: 1}),
    "walls/remix": wall({id: "REMIX", creatorUid: "bob", email: "bob@example.com", isAiGenerated: true, remixOf: "wall"}),
    "wallRemixes/remix": {originalId: "wall"}, "wallRemixNotices/remix": {sent: true}}));
  await syncRemixCredit("remix");
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsHistory/")), false);
  store.set("walls/remix", {...store.get("walls/remix"), review: false}); await syncRemixCredit("remix");
  store.set("walls/remix", {...store.get("walls/remix"), review: true}); await syncRemixCredit("remix");
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsHistory/")), false);
  assert.equal(store.get("walls/wall")?.remixCount, 1);
});
test("weekly inbox finds activity on wall 500 and dedupes concurrent deliveries", async (t) => {
  const docs: Record<string, Doc> = {"usersv2/alice": {email: "alice@example.com"}};
  for (let i = 0; i < 500; i++) docs[`walls/w${i}`] = wall({id: `W${i}`});
  const store = installFakeDb(t, docs);
  const snap = await db.doc("walls/w499").get();
  await historyRef(snap).set(addHistory(snap, undefined, {shares: 1}, NOW - 86400000, NOW - 86400000));
  const outcomes = await Promise.all([deliverCreatorWeek("alice", NOW), deliverCreatorWeek("alice", NOW)]);
  assert.deepEqual(outcomes, [true, false]);
  assert.equal([...store.keys()].filter((p) => p.startsWith("notifications/")).length, 1);
});

test("daily projection retries an aborted write without committing a checkpoint alone", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 3}}));
  const collection = db.collection.bind(db);
  let fail = true;
  t.mock.method(db, "collection", (name: string) => {
    const result = collection(name);
    if (name === "creatorStatsHistory") {
      const doc = result.doc.bind(result);
      t.mock.method(result, "doc", (id: string) => {
        const ref = doc(id);
        const set = ref.set.bind(ref);
        t.mock.method(ref, "set", async (data: Doc) => {
          if (fail) {
            fail = false; throw new Error("injected write failure");
          }
          return set(data);
        });
        return ref;
      });
    }
    return result;
  });
  await assert.rejects(projectDailyStats(path, NOW), /injected write failure/);
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsDailyCheckpoints/")), false);
  await projectDailyStats(path, NOW);
  await projectDailyStats(path, NOW);
  const snap = await db.doc("walls/wall").get();
  assert.equal((await historyRef(snap).get()).data()?.weeks["2026-W43"].views, 3);
});
test("legacy numeric totals are parsed while invalid totals remain unavailable", async (t) => {
  installFakeDb(t, seed({"wallpaper_stats/WALL": {views: "17", favs: "bad", downloads: -1}}));
  const result = await readCreatorStats("alice", {}, NOW);
  assert.equal(result.totals.views, 17);
  assert.equal(result.totals.saves, null);
  assert.equal(result.totals.downloads, null);
});

test("creation order compares nanoseconds without rounding to milliseconds", () => {
  const older = new admin.firestore.Timestamp(1800000000, 1);
  const newer = new admin.firestore.Timestamp(1800000000, 2);
  assert.equal(atOrAfter(older, newer), false);
  assert.equal(atOrAfter(newer, older), true);
});

test("a delayed daily update after TTL deletion retains its recorded after-image exactly once", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 2}}));
  const older = await db.doc(path).get();
  store.set(path, {wallId: "WALL", day: "20261025", views: 7});
  const latest = await db.doc(path).get();
  store.delete(path);
  await projectDailyStats(path, NOW, latest);
  await projectDailyStats(path, NOW, older);
  await projectDailyStats(path, NOW, latest);
  const snap = await db.doc("walls/wall").get();
  assert.equal((await historyRef(snap).get()).data()?.weeks["2026-W43"].views, 7);
});
test("daily delivery after source recreation preserves both source incarnations", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 7}}));
  const older = await db.doc(path).get();
  store.delete(path);
  store.set(path, {wallId: "WALL", day: "20261025", views: 2});
  const latest = await db.doc(path).get();
  await projectDailyStats(path, NOW, latest);
  await projectDailyStats(path, NOW, older);
  await projectDailyStats(path, NOW, older);
  const snap = await db.doc("walls/wall").get();
  assert.equal((await historyRef(snap).get()).data()?.weeks["2026-W43"].views, 9);
});

test("missing individual lifetime fields and remix counters stay unavailable beside genuine zero", async (t) => {
  installFakeDb(t, seed({"walls/wall": wall({remixCount: undefined}),
    "wallpaper_stats/WALL": {views: 0, favs: "0"}}));
  const result = await readCreatorStats("alice", {}, NOW);
  assert.deepEqual(result.totals, {views: 0, saves: 0, sets: null, downloads: null, shares: null,
    folderAdds: null, remixes: null});
});


test("normalized mixed-case and whitespace aliases invalidate warm counters and block daily projection", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 5}}));
  assert.equal((await readCreatorStats("alice", {}, NOW)).totals.views, 10);
  for (const alias of ["wall", "WaLl", " WALL ", "\twall\n"]) {
    store.set("walls/alias", wall({id: alias, creatorUid: "bob", review: false}));
    assert.equal((await readCreatorStats("alice", {}, NOW + 1)).totals.views, null);
    await projectDailyStats(path, NOW);
    assert.equal([...store.keys()].some((p) => p.startsWith("creatorStatsHistory/")), false);
  }
  store.delete("walls/alias");
  await projectDailyStats(path, NOW);
  const snap = await db.doc("walls/wall").get();
  assert.equal((await historyRef(snap).get()).data()?.weeks["2026-W43"].views, 5);
});

test("500 caller walls share one census with foreign aliases and warm invalidation", async (t) => {
  const docs: Record<string, Doc> = {"usersv2/alice": {email: "alice@example.com"}};
  for (let i = 0; i < 500; i++) {
    docs[`walls/w${i}`] = wall({id: `W${i}`});
    docs[`wallpaper_stats/W${i}`] = {views: 1};
  }
  const observed = {reads: 0, writes: 0};
  const store = installFakeDb(t, docs, observed);
  assert.equal((await readCreatorStats("alice", {}, NOW)).totals.views, 500);
  store.set("walls/foreign", wall({id: "  w499 ", creatorUid: "bob"}));
  observed.reads = 0;
  const warm = await readCreatorStats("alice", {}, NOW + 1);
  assert.equal(warm.walls.length, 500);
  assert.equal(warm.totals.views, null);
  assert.equal(warm.walls.find((row) => row.wallId === "w499")?.totals.views, null);
  assert.equal(observed.reads, 1504);
});

test("global census capacity is explicit on warm reads and shared daily projection", async (t) => {
  const path = "wallpaper_stats_daily/20261025_WALL";
  const store = installFakeDb(t, seed({[path]: {wallId: "WALL", day: "20261025", views: 5}}));
  await readCreatorStats("alice", {}, NOW);
  for (let i = 0; i < MAX_IDENTITY_WALLS; i++) store.set(`walls/foreign${i}`, wall({id: `X${i}`, creatorUid: "bob"}));
  await assert.rejects(readCreatorStats("alice", {}, NOW + 1), fails("resource-exhausted"));
  await assert.rejects(projectDailyStats(path, NOW), fails("resource-exhausted"));
});

test("rollout weeks preserve recorded partial values and never invent pre-coverage zeroes", async (t) => {
  installFakeDb(t, seed());
  const observed = Date.parse("2026-10-21T12:00:00Z");
  await putHistory({views: 4}, observed);
  const result = await readCreatorStats("alice", {}, NOW);
  assert.equal(result.weeks[6].metrics.views, 4);
  assert.equal(result.weeks[6].metrics.shares, null);
  assert.equal(result.weeks[7].metrics.shares, 0);
  assert.equal(result.coverage.views.weeklyFrom, new Date(observed).toISOString());
  assert.equal(result.coverage.folderAdds.totalFrom, new Date(observed).toISOString());
});


test("a uniquely identified lowercase wall uses normalized lifetime and explicit folder identity", async (t) => {
  installFakeDb(t, seed({"walls/wall": wall({id: "  wAll ", remixCount: 0}),
    "folders/f": {ownerId: "bob"}, "folders/f/items/item": {...item, id: "wall"}}));
  await countFolderCreation(await folderSource(), NOW);
  const result = await readCreatorStats("alice", {}, NOW);
  assert.equal(result.totals.views, 10);
  assert.equal(result.totals.folderAdds, 1);
});
