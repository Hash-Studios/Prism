import assert from "node:assert/strict";
import test from "node:test";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import * as admin from "firebase-admin";
import {db} from "../common";
import {loadLegacyEvents} from "../creatorFund/legacy";
import {removeFundData} from "../deleteAccount";
import {fundEventWrite, fundWallStamp} from "../creatorFund/events";
import {onFavouriteWritten, recordWallpaperAction} from "../wallStats";
import {dryConfig, dryRules} from "../scripts/creatorFundDry";
import {holdWallAfterReports} from "../onContentReportCreated";
import {countFolderCreation} from "../creatorStatsHistory";
import {onWallRemixWritten, syncRemixCredit} from "../wallRemix";
import {loadAccounts, loadFundGates, loadWallCensus, MIN_ACTOR_AGE_MS, weekRange} from "../creatorFund/load";
import {installFakeDb} from "./fakeDb";

for (const smart of [false, true]) {
  test(smart ? "automatic smart-folder items are not user engagement" : "shared folder engagement belongs to the adding member", async (t) => {
    const store = installFakeDb(t, {
      "usersv2/owner": {}, "usersv2/member": {}, "usersv2/creator": {},
      "walls/w": {id: "W", creatorUid: "creator", review: true, wallpaper_provider: "prism"},
      "folders/f": {ownerId: "owner", ...(smart ? {smartRules: []} : {})},
      "folders/f/items/prism_W": {ownerId: "owner", id: "W", provider: "prism", wallpaperDocumentId: "w",
        ...(smart ? {} : {addedBy: "member"})},
    });
    const source = await db.doc("folders/f/items/prism_W").get();
    await countFolderCreation(source);
    assert.deepEqual([...store].filter(([p]) => p.startsWith("creatorFundEvents/")).map(([, d]) => d.actorUid),
      smart ? [] : ["member"]);
  });
}

test("only verified, old, linked accounts can contribute, including across Auth batches", async (t) => {
  const ids = Array.from({length: 102}, (_, i) => String(i));
  const store = installFakeDb(t, Object.fromEntries(ids.map((id) => [`usersv2/${id}`, {}])));
  store.set("creatorDeletionState/6", {closed: true});
  const batches: number[] = [];
  t.mock.method(admin.auth(), "getUsers", async (part: {uid: string}[]) => {
    batches.push(part.length);
    return {users: part.filter(({uid}) => uid !== "5").map(({uid}) => ({
      uid, disabled: uid === "4", emailVerified: uid !== "1", providerData: uid === "2" ? [] : [{providerId: "password"}],
      metadata: {creationTime: new Date(uid === "3" ? 1000 : 0).toISOString()},
    }))};
  });
  const result = await loadAccounts(db, admin.auth(), ids, MIN_ACTOR_AGE_MS);
  assert.deepEqual(result.untrusted, new Set(["1", "2", "3"]));
  assert.deepEqual(result.closed, new Set(["4", "5", "6"]));
  assert.deepEqual(batches, [100, 2]);
});

test("the wall census excludes Studio and all aliases of a shared ID, and keeps held creators", async (t) => {
  const wall = {id: "W", creatorUid: "a", review: true, wallpaper_provider: "prism"};
  installFakeDb(t, {"walls/a": wall, "walls/b": {...wall, id: " w ", review: false},
    "walls/c": {...wall, id: "ST", origin: "studio"}, "walls/d": {...wall, id: "OK"},
    "walls/e": {...wall, id: "held", review: false, creatorUid: "b", heldAt: admin.firestore.Timestamp.fromMillis(10)}});
  const census = await loadWallCensus(db, {start: 0, end: 20});
  assert.deepEqual(census.wallCreators, new Map([["OK", "a"]]));
  assert.deepEqual(census.struck, new Set(["b"]));
});

test("account deletion pages through actor events and erases only the user's fund rows, notices and strikes", async (t) => {
  const store = installFakeDb(t, {
    ...Object.fromEntries(Array.from({length: 405}, (_, i) => [`creatorFundEvents/e${i}`, {actorUid: "a"}])),
    "creatorFundEvents/keep": {actorUid: "ab"},
    "creatorFund/week": {state: "complete"}, "creatorFund/week/creators/a": {status: "paid"}, "creatorFund/week/fundPairs/p": {uid: "a"},
    "creatorFund/week/creators/ab": {uid: "ab"}, "notifications/creator_fund_a_week": {},
    "other/week/creators/a": {uid: "a"}, "creatorDeletionState/a/fundStrikes/week": {},
    "creatorDeletionState/a": {closed: true},
  });
  await removeFundData("a");
  await removeFundData("a");
  assert.deepEqual([...store.keys()].sort(), ["creatorDeletionState/a", "creatorFund/week", "creatorFund/week/creators/ab",
    "creatorFundEvents/keep", "other/week/creators/a"]);
});

test("legacy actions commit the count, rate claim and bound event together; a failed write can be retried", async (t) => {
  const at = Date.parse("2026-11-13T12:00:00Z");
  t.mock.timers.enable({apis: ["Date"], now: at});
  const store = installFakeDb(t, {"usersv2/fan": {}, "walls/one": {
    id: "w", creatorUid: "maker", wallpaper_provider: "prism", review: true,
  }}, undefined, {failCommits: 1});
  const call = () => recordWallpaperAction.run({auth: {uid: "fan"}, data: {wallId: "W", action: "set"}} as never);
  await assert.rejects(call(), /commit failure/);
  assert.equal(store.has("wallActionRate/fan_W_set"), false);
  assert.equal((await call()).counted, true);
  assert.equal((await call()).counted, false);
  const event = store.get(fundEventWrite("W", "sets", "fan", at).ref.path);
  assert.equal(event?.wallStamp, fundWallStamp(await db.doc("walls/one").get()));
  assert.equal(store.get("wallpaper_stats/W")?.sets, 1);
});

test("a delayed save keeps its server creation week, and a deletion barrier rejects a late save", async (t) => {
  const at = Date.parse("2026-11-15T23:59:59Z");
  t.mock.timers.enable({apis: ["Date"], now: at + 2000});
  const path = "usersv2/fan/images/W";
  const fav = {id: "W", provider: "prism"};
  const store = installFakeDb(t, {"maintenance/favouriteAggregation": {phase: "ready", epoch: "e"},
    "walls/one": {id: "W", creatorUid: "maker", wallpaper_provider: "prism", review: true},
    [path]: fav}, undefined, {createTimes: {[path]: admin.firestore.Timestamp.fromMillis(at)}});
  const snap = await db.doc(path).get();
  const fire = () => onFavouriteWritten.run({time: new Date(at).toISOString(), params: {uid: "fan", wallId: "W"},
    data: {before: {data: () => undefined}, after: snap}} as never);
  await fire();
  const event = fundEventWrite("W", "saves", "fan", at);
  assert.equal(store.get(event.ref.path)?.week, "2026-W46");
  store.set("creatorDeletionState/fan", {closed: true});
  await removeFundData("fan");
  store.delete("wallpaper_stats/W/favouriteContributions/fan");
  await fire();
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorFundEvents/")), false);
});

test("dry run uses frozen rules without disclosing team UIDs", async (t) => {
  installFakeDb(t, {"creatorFund/w": {rules: {pool: 120, excludedUids: ["private-team-uid"]}},
    "economyConfig/current": {creatorFund: {pool: 999}}});
  const config = await dryConfig("w");
  assert.equal(config.pool, 120);
  assert.equal(JSON.stringify(dryRules(config)).includes("private-team-uid"), false);
});

test("a report strike survives removal of the held wall, but an old reapproved wall is not a permanent strike", async (t) => {
  const range = weekRange("2026-W46");
  t.mock.timers.enable({apis: ["Date"], now: range.start});
  const wall = {id: "W", creatorUid: "maker", review: true, wallpaper_provider: "prism"};
  const store = installFakeDb(t, {"walls/w": wall, "usersv2/maker": {}, "usersv2/fan": {},
    "walls/next": {...wall, id: "NEXT", heldAt: admin.firestore.Timestamp.fromMillis(1), heldForReview: true},
    ...Object.fromEntries(["x", "y", "z"].map((id) => [`contentReports/${id}`,
      {contentType: "wall", targetFirestoreDocId: "w", reporterUid: id}]))});
  t.mock.method(admin.auth(), "getUser", async () => ({metadata: {creationTime: new Date(0).toISOString()}}));
  t.mock.method(admin.auth(), "getUsers", async (ids: {uid: string}[]) => ({users: ids.map(({uid}) => ({
    uid, emailVerified: true, providerData: [{providerId: "password"}], metadata: {creationTime: new Date(0).toISOString()},
  }))}));
  assert.equal(await holdWallAfterReports("w"), true);
  store.delete("walls/w");
  const census = await loadWallCensus(db, range);
  assert.equal(census.struck.size, 0);
  const gates = await loadFundGates(db, admin.auth(), [{wallId: "NEXT", actorUid: "fan", metric: "sets"}], census, [], range.end);
  assert.equal(gates.creatorGates.get("maker"), "moderation");
});

test("legacy remix estimates page through equal credit timestamps without losing the next page", async (t) => {
  const at = admin.firestore.Timestamp.fromMillis(5);
  const n = 53;
  installFakeDb(t, {"walls/original": {id: "W"},
    ...Object.fromEntries(Array.from({length: n}, (_, i) => [`walls/r${i}`, {creatorUid: `m${i}`}])),
    ...Object.fromEntries(Array.from({length: n}, (_, i) => [`wallRemixes/r${i}`, {remixId: `r${i}`, originalId: "original", creditedAt: at}])),
  });
  const result = await loadLegacyEvents(db, {start: 0, end: 10});
  assert.equal(result.events.length, n);
  assert.equal(new Set(result.events.map((e) => e.actorUid)).size, n);
});

test("wall-owner rule guards protect both report hold fields on create and update", () => {
  const rules = readFileSync(resolve(__dirname, "../../../firestore.rules"), "utf8");
  for (const guard of ["wallServerKeysAbsent", "wallServerKeysUntouched"]) {
    const body = rules.split(`function ${guard}()`)[1].split("}")[0];
    assert.match(body, /'heldAt'/);
    assert.match(body, /'heldForReview'/);
  }
});

test("a late server-assigned remixer UID completes the first credit in its original week once", async (t) => {
  const range = weekRange("2026-W46");
  t.mock.timers.enable({apis: ["Date"], now: range.end - 1000});
  const original = {id: "W", creatorUid: "maker", email: "m@example.com", wallpaper_provider: "prism",
    review: true, isAiGenerated: true, aiPrompt: "sky"};
  const remix = {...original, id: "R", creatorUid: "", email: "r@example.com", remixOf: "w"};
  const store = installFakeDb(t, {"walls/w": original, "walls/r": remix, "usersv2/maker": {}, "usersv2/fan": {}});
  await syncRemixCredit("r");
  assert.equal([...store.keys()].some((p) => p.startsWith("creatorFundEvents/")), false);
  const stamped = {...remix, creatorUid: "fan"};
  store.set("walls/r", stamped);
  t.mock.timers.setTime(range.end + 1000);
  const fire = () => onWallRemixWritten.run({params: {wallId: "r"}, data: {
    before: {data: () => remix}, after: {data: () => stamped},
  }} as never);
  await fire();
  await fire();
  const events = [...store].filter(([p]) => p.startsWith("creatorFundEvents/"));
  assert.deepEqual(events.map(([, d]) => [d.week, d.actorUid, d.wallId]), [["2026-W46", "fan", "W"]]);
});
