import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {
  capPerOwner,
  discoveryRefusal,
  DISCOVERY_LIMITS,
  folderDiscoveryDeps,
  folderScores,
  type OwnerAccount,
  rebuildFolderDiscovery,
  setDiscoveryHidden,
} from "../folderDiscovery";
import {countFolderSignal, folderSignalDeps} from "../folderSignals";
import {trendingDays} from "../trending";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = Date.parse("2026-11-08T12:00:00Z");
const DAY = 86_400_000;
const TODAY = "20261108";
const YESTERDAY = "20261107";
const OK_OWNER: OwnerAccount = {createdMs: NOW - 30 * DAY, disabled: false};

type Seed = Record<string, Doc>;
type Listing = {
  trending: Array<{id: string; ownerName?: string; itemCount?: number}>;
  new: Array<{id: string}>;
};

const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const seedOf = (...parts: Seed[]): Seed => Object.assign({}, ...parts);
const ids = (rows: Array<{id: string}>) => rows.map((row) => row.id);

function header(id: string, ownerId: string, extra: Doc = {}): Seed {
  return {
    [`publicFolders/${id}`]: {
      ownerId, name: "Night skies", itemCount: 8, covers: ["https://img.example.com/a.jpg"], followerCount: 3, ...extra,
    },
  };
}

function daily(folderId: string, day: string, counts: Doc = {}): Seed {
  return {[`folderStatsDaily/${day}_${folderId}`]: {folderId, day, follows: 0, saves: 0, opens: 0, ...counts}};
}

function stubOwners(t: TestContext) {
  t.mock.method(folderDiscoveryDeps, "owners", async (uids: string[]) =>
    new Map<string, OwnerAccount>(uids.map((uid) => [uid, OK_OWNER])));
}

function readListing(store: Map<string, Doc>): Listing {
  return store.get("folderTrending/current") as unknown as Listing;
}

test("folderScores weights recent activity by day and drops days outside the window", () => {
  const days = trendingDays(NOW);
  const scores = folderScores([
    {folderId: "a", day: TODAY, follows: 1, saves: 1, opens: 1},
    {folderId: "a", day: YESTERDAY, follows: 0, saves: 0, opens: 5},
    {folderId: "b", day: "20261031", follows: 10, saves: 0, opens: 0},
  ], days);
  assert.ok(Math.abs((scores.get("a") ?? NaN) - 10) < 1e-9);
  assert.equal(scores.has("b"), false);
});

test("discoveryRefusal applies each rule and passes a good folder", () => {
  const good = {ownerId: "o", name: "Night skies", itemCount: 8};
  const ctx = (owners: Array<[string, OwnerAccount]> = [["o", OK_OWNER]]) =>
    ({nowMs: NOW, owners: new Map(owners), reported: new Set<string>()});

  assert.equal(discoveryRefusal(good, ctx(), "f1"), null);
  assert.equal(discoveryRefusal(undefined, ctx(), "f1"), "private");
  assert.equal(discoveryRefusal({...good, discoveryHidden: true}, ctx(), "f1"), "hidden");
  assert.equal(discoveryRefusal(good, {...ctx(), reported: new Set(["f1"])}, "f1"), "reported");
  assert.equal(discoveryRefusal({...good, itemCount: 7}, ctx(), "f1"), "size");
  assert.equal(discoveryRefusal({...good, name: "sexy walls"}, ctx(), "f1"), "name");
  assert.equal(discoveryRefusal({...good, name: ""}, ctx(), "f1"), "name");
  assert.equal(discoveryRefusal(good, ctx([["o", {createdMs: NOW - 6 * DAY, disabled: false}]]), "f1"), "owner");
  assert.equal(discoveryRefusal(good, ctx([["o", {createdMs: NOW - 30 * DAY, disabled: true}]]), "f1"), "owner");
  assert.equal(discoveryRefusal(good, ctx([]), "f1"), "owner");
});

test("rebuild rechecks the current name before publishing a candidate", async (t) => {
  const store = installFakeDb(t, seedOf(header("f1", "o1"), daily("f1", TODAY, {opens: 9})));
  t.mock.method(folderDiscoveryDeps, "owners", async () => {
    // Simulate a rename after candidate selection, while the job is assembling its listing.
    store.set("publicFolders/f1", {...store.get("publicFolders/f1"), name: "s.e.x wallpapers"});
    return new Map([["o1", OK_OWNER]]);
  });

  await rebuildFolderDiscovery(NOW);
  assert.deepEqual(ids(readListing(store).trending), []);
});

test("rebuild rechecks current size before publishing a candidate", async (t) => {
  const store = installFakeDb(t, seedOf(header("f1", "o1"), daily("f1", TODAY, {opens: 9})));
  t.mock.method(folderDiscoveryDeps, "owners", async () => {
    store.set("publicFolders/f1", {...store.get("publicFolders/f1"), itemCount: 7});
    return new Map([["o1", OK_OWNER]]);
  });

  await rebuildFolderDiscovery(NOW);
  assert.deepEqual(ids(readListing(store).trending), []);
});

test("rebuild does not publish a replacement folder generation", async (t) => {
  const createdAt = ts(NOW - DAY);
  const store = installFakeDb(t, seedOf(
    header("f1", "o1", {generation: "old", sourceCreatedAt: createdAt}),
    daily("f1", TODAY, {opens: 9}),
  ));
  t.mock.method(folderDiscoveryDeps, "owners", async () => {
    store.set("publicFolders/f1", {...store.get("publicFolders/f1"), generation: "new"});
    return new Map([["o1", OK_OWNER]]);
  });

  await rebuildFolderDiscovery(NOW);
  assert.deepEqual(ids(readListing(store).trending), []);
});

test("an open report for a candidate is found past 1000 unrelated reports", async (t) => {
  const seed = seedOf(header("target", "o1"), daily("target", TODAY, {opens: 9}));
  for (let i = 0; i < 1000; i++) {
    Object.assign(seed, {[`contentReports/unrelated${i.toString().padStart(4, "0")}`]: {
      contentType: "folder", targetFirestoreDocId: `other${i}`, status: "open",
    }});
  }
  Object.assign(seed, {"contentReports/zTarget": {
    contentType: "folder", targetFirestoreDocId: "target", status: "open",
  }});
  const observed = {reads: 0, writes: 0, outsideReads: 0};
  const store = installFakeDb(t, seed, observed);
  stubOwners(t);

  await rebuildFolderDiscovery(NOW);

  assert.deepEqual(ids(readListing(store).trending), []);
  assert.ok(observed.outsideReads <= 10, `bounded candidate reads expected, got ${observed.outsideReads}`);
});

test("capPerOwner keeps order and stops at the size limit", () => {
  const items = [{id: "1", ownerId: "x"}, {id: "2", ownerId: "x"}, {id: "3", ownerId: "x"}, {id: "4", ownerId: "y"}];
  assert.deepEqual(ids(capPerOwner(items, 10)), ["1", "2", "4"]);
  assert.deepEqual(ids(capPerOwner(items, 2)), ["1", "2"]);
});

test("rebuild lists the best folders, at most two per owner, with the owner's name", async (t) => {
  stubOwners(t);
  const store = installFakeDb(t, seedOf(
    header("f1", "o1"), header("f2", "o1"), header("f3", "o1"), header("f4", "o2"),
    daily("f1", TODAY, {opens: 9}), daily("f2", TODAY, {opens: 8}),
    daily("f3", TODAY, {opens: 7}), daily("f4", TODAY, {opens: 1}),
    {"profiles/o1": {name: "Ana", username: "ana"}, "profiles/o2": {name: "Bo"}},
  ));

  assert.deepEqual(await rebuildFolderDiscovery(NOW), {trending: 3, fresh: 0});
  const listing = readListing(store);
  assert.deepEqual(ids(listing.trending), ["f1", "f2", "f4"]);
  assert.equal(listing.trending[0].ownerName, "Ana");
  assert.equal(listing.trending[2].ownerName, "Bo");
  assert.equal(listing.trending[0].itemCount, 8);
  assert.deepEqual(listing.new, []);
});

test("rebuild drops hidden and reported folders, but not reviewed reports", async (t) => {
  stubOwners(t);
  const store = installFakeDb(t, seedOf(
    header("f1", "o1", {discoveryHidden: true}), header("f2", "o2"), header("f3", "o3"),
    daily("f1", TODAY, {opens: 9}), daily("f2", TODAY, {opens: 8}), daily("f3", TODAY, {opens: 7}),
    {"contentReports/r1": {contentType: "folder", targetFirestoreDocId: "f3", status: "open"}},
  ));

  await rebuildFolderDiscovery(NOW);
  assert.deepEqual(ids(readListing(store).trending), ["f2"]);

  for (const [path, doc] of Object.entries(seedOf(
    header("f5", "o5"), daily("f5", TODAY, {opens: 2}),
    {"contentReports/r2": {contentType: "folder", targetFirestoreDocId: "f5", status: "reviewed"}},
  ))) store.set(path, doc);
  await rebuildFolderDiscovery(NOW);
  assert.deepEqual(ids(readListing(store).trending), ["f2", "f5"]);
});

test("rebuild lists recently eligible folders as new, and not old ones", async (t) => {
  stubOwners(t);
  const store = installFakeDb(t, seedOf(
    header("f6", "o6", {discoveryEligibleAt: ts(NOW - 2 * DAY)}),
    header("f7", "o7", {discoveryEligibleAt: ts(NOW - 9 * DAY)}),
  ));

  await rebuildFolderDiscovery(NOW);
  const listing = readListing(store);
  assert.deepEqual(ids(listing.new), ["f6"]);
  assert.deepEqual(listing.trending, []);
});

test("setDiscoveryHidden removes a folder from every list and rebuild keeps it out", async (t) => {
  stubOwners(t);
  const store = installFakeDb(t, seedOf(
    {"folders/f1": {ownerId: "o1", public: true}},
    header("f1", "o1"), header("f2", "o2"),
    daily("f1", TODAY, {opens: 9}), daily("f2", TODAY, {opens: 8}),
    {
      "folderTrending/current": {trending: [{id: "f1"}, {id: "f2"}], new: [{id: "f1"}]},
      "webPages/folders": {kind: "folders", trending: [{id: "f1"}], new: []},
    },
  ));

  await setDiscoveryHidden("f1", true);
  assert.equal(store.get("folders/f1")?.discoveryHidden, true);
  assert.equal(store.get("publicFolders/f1")?.discoveryHidden, true);
  const listing = readListing(store);
  assert.deepEqual(ids(listing.trending), ["f2"]);
  assert.deepEqual(listing.new, []);
  assert.deepEqual((store.get("webPages/folders") as {trending: unknown[]}).trending, []);

  await rebuildFolderDiscovery(NOW);
  assert.deepEqual(ids(readListing(store).trending), ["f2"]);
});

test("countFolderSignal skips own, repeated, and young-account signals, and counts the rest", async (t) => {
  const created = new Map<string, number>([["young", NOW - 2 * DAY]]);
  const store = installFakeDb(t, {"publicFolders/f1": {ownerId: "o1", itemCount: 8}});
  t.mock.method(folderSignalDeps, "accountCreatedMs", async (uid: string) => {
    if (uid === "racer") store.delete("publicFolders/f1");
    return created.get(uid) ?? NOW - 30 * DAY;
  });

  assert.equal(await countFolderSignal("o1", "f1", "o1", "open", NOW), false);
  assert.equal(store.has(`folderStatsDaily/${TODAY}_f1`), false);

  assert.equal(await countFolderSignal("u1", "f1", "o1", "open", NOW), true);
  assert.equal(store.get(`folderStatsDaily/${TODAY}_f1`)?.opens, 1);

  assert.equal(await countFolderSignal("u1", "f1", "o1", "open", NOW + 60 * 60 * 1000), false);
  assert.equal(store.get(`folderStatsDaily/${TODAY}_f1`)?.opens, 1);

  assert.equal(await countFolderSignal("u1", "f1", "o1", "open", NOW + 8 * DAY), true);
  assert.equal(store.get("folderStatsDaily/20261116_f1")?.opens, 1);

  assert.equal(await countFolderSignal("young", "f1", "o1", "open", NOW), false);
  assert.equal(store.get(`folderStatsDaily/${TODAY}_f1`)?.opens, 1);
  assert.equal(store.has("folderSignalRate/young_f1_open"), false);
  assert.equal(await countFolderSignal("young", "f1", "o1", "open", NOW + 8 * DAY), true);

  assert.equal(await countFolderSignal("racer", "f1", "o1", "open", NOW), false);
  assert.equal(store.has("folderSignalRate/racer_f1_open"), false);
  store.set("publicFolders/f1", {ownerId: "o1", itemCount: 8});

  assert.equal(await countFolderSignal("u2", "f1", "o1", "follow", NOW), true);
  assert.equal(await countFolderSignal("u3", "f1", "o1", "save", NOW), true);
  assert.equal(store.get(`folderStatsDaily/${TODAY}_f1`)?.follows, 1);
  assert.equal(store.get(`folderStatsDaily/${TODAY}_f1`)?.saves, 1);
});

test("rebuild reads past 300 high-scored ineligible folders to fill Trending", async (t) => {
  stubOwners(t);
  const seed: Seed = {};
  for (let i = 0; i < 310; i++) {
    Object.assign(seed, header(`h${i}`, `ho${i}`, {discoveryHidden: true}), daily(`h${i}`, TODAY, {opens: 50}));
  }
  Object.assign(seed, header("ok", "o-ok"), daily("ok", TODAY, {opens: 1}));
  const store = installFakeDb(t, seed);

  await rebuildFolderDiscovery(NOW);

  assert.deepEqual(ids(readListing(store).trending), ["ok"]);
});

test("countFolderSignal skips folders that cannot be listed: under 8 walls or hidden from discovery", async (t) => {
  t.mock.method(folderSignalDeps, "accountCreatedMs", async () => NOW - 30 * DAY);
  const store = installFakeDb(t, {
    "publicFolders/small": {ownerId: "o1", itemCount: 7},
    "publicFolders/hidden": {ownerId: "o1", itemCount: 12, discoveryHidden: true},
  });

  assert.equal(await countFolderSignal("u1", "small", "o1", "open", NOW), false);
  assert.equal(await countFolderSignal("u1", "hidden", "o1", "follow", NOW), false);
  assert.equal(store.has(`folderStatsDaily/${TODAY}_small`), false);
  assert.equal(store.has(`folderStatsDaily/${TODAY}_hidden`), false);
  assert.equal(store.has("folderSignalRate/u1_small_open"), false);
});

test("failed Auth and transaction commits do not spend a signal claim; duplicates skip Auth", async (t) => {
  const authCalls: string[] = [];
  t.mock.method(folderSignalDeps, "accountCreatedMs", async (uid: string) => {
    authCalls.push(uid);
    if (uid === "auth-fails") throw new Error("Auth unavailable");
    return NOW - 30 * DAY;
  });
  const store = installFakeDb(t, {"publicFolders/f1": {ownerId: "o1", itemCount: 8}}, undefined, {failCommits: 1});

  await assert.rejects(countFolderSignal("auth-fails", "f1", "o1", "open", NOW), /Auth unavailable/);
  assert.equal(store.has("folderSignalRate/auth-fails_f1_open"), false);
  assert.equal(store.has(`folderStatsDaily/${TODAY}_f1`), false);

  await assert.rejects(countFolderSignal("retry", "f1", "o1", "open", NOW), /injected transaction commit failure/);
  assert.equal(store.has("folderSignalRate/retry_f1_open"), false);
  assert.equal(store.has(`folderStatsDaily/${TODAY}_f1`), false);
  assert.equal(await countFolderSignal("retry", "f1", "o1", "open", NOW), true);
  assert.equal(await countFolderSignal("retry", "f1", "o1", "open", NOW), false);
  assert.deepEqual(authCalls, ["auth-fails", "retry", "retry"]);
  assert.equal(store.get(`folderStatsDaily/${TODAY}_f1`)?.opens, 1);
});

test("a rebuild reads a bounded number of documents and writes only the list doc", async (t) => {
  stubOwners(t);
  const days = trendingDays(NOW);
  assert.equal(days.length, 7);
  const seed: Seed = {};
  for (let i = 0; i < 40; i++) {
    const id = `c${i}`;
    const owner = `o${i % 20}`;
    Object.assign(seed, header(id, owner), ...days.map((day) => daily(id, day, {opens: 1})));
    for (let j = 0; j < 12; j++) {
      Object.assign(seed, {
        [`publicFolders/${id}/items/w${j}`]: {wallpaperDocumentId: `${id}w${j}`, addedAt: ts(NOW - j * DAY)},
        [`walls/${id}w${j}`]: {category: "Nature"},
      });
    }
  }
  for (let k = 0; k < 20; k++) Object.assign(seed, {[`profiles/o${k}`]: {name: `Owner ${k}`}});
  for (let j = 0; j < 5; j++) {
    Object.assign(seed, {[`contentReports/q${j}`]: {contentType: "folder", targetFirestoreDocId: `x${j}`, status: "open"}});
  }

  const observed = {reads: 0, writes: 0, outsideReads: 0};
  const store = installFakeDb(t, seed, observed);
  await rebuildFolderDiscovery(NOW);

  assert.equal(readListing(store).trending.length, DISCOVERY_LIMITS.listSize);
  assert.equal(observed.writes, 1);
  // Reads outside a transaction are in outsideReads, reads inside one are in reads. An empty query counts as one.
  const bound =
    40 * days.length + // daily docs
    40 + // header gets for candidates
    40 + // one open-report lookup per candidate
    20 + // one profile per owner
    DISCOVERY_LIMITS.listSize * (12 + 12) + // 12 items and 12 walls per listed folder
    DISCOVERY_LIMITS.listSize + // transaction header rereads
    1; // the empty new-folder query
  assert.ok(observed.reads + observed.outsideReads <= bound,
    `reads ${observed.reads + observed.outsideReads} > bound ${bound}`);
  assert.deepEqual(DISCOVERY_LIMITS, {
    listSize: 30, dailyDocs: 50000, trendingScan: 1000, newCandidates: 300,
  });
});
