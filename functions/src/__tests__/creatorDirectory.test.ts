import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {
  creatorDirectoryDeps,
  FOLLOWING_SCAN_CAP,
  followedBy,
  planCandidates,
  rebuildCreatorDirectory,
  similarCreators,
  type FollowEdge,
  type WallRow,
} from "../creatorDirectory";
import type {Doc} from "./fakeDb";
import {installFakeDb} from "./fakeDb";

const NOW = Date.parse("2026-10-31T12:00:00Z");
const DAY = 86_400_000;
const TODAY = "20261031";
const ALLOWED_KEYS = ["uid", "name", "username", "profilePhoto", "followerCount", "walls", "categories", "similar",
  "rank", "updatedAt"];

type Seed = Record<string, Doc>;

const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
const seedOf = (...parts: Seed[]): Seed => Object.assign({}, ...parts);

function wall(id: string, creatorUid: string, ageDays: number, extra: Doc = {}): Seed {
  return {
    [`walls/${id}`]: {
      id, creatorUid, review: true, originalProtected: true, collections: ["community"],
      wallpaper_thumb: `https://img.example.com/${id.toLowerCase()}.jpg`, category: "Nature",
      createdAt: ts(NOW - ageDays * DAY), ...extra,
    },
  };
}

/** Walls `${prefix}1`, `${prefix}2`, ... for one creator, one per age in days. */
function walls(prefix: string, creatorUid: string, ages: number[]): Seed {
  return seedOf(...ages.map((age, i) => wall(`${prefix}${i + 1}`, creatorUid, age)));
}

/** A listed creator: usersv2 doc plus a public profile with private-ish fields that must never be copied. */
function creator(uid: string, user: Doc = {}): Seed {
  return {
    [`usersv2/${uid}`]: user,
    [`profiles/${uid}`]: {
      name: `Name ${uid}`, username: `user_${uid}`, profilePhoto: `https://img.example.com/${uid}.jpg`,
      followerCount: 7, bio: "private-ish", links: {site: "https://example.com"},
    },
  };
}

function stubSeams(t: TestContext, {premium = [], disabled = []}: {premium?: string[]; disabled?: string[]} = {}) {
  t.mock.method(creatorDirectoryDeps, "premium", async () => premium);
  t.mock.method(creatorDirectoryDeps, "disabledUids", async () => new Set<string>(disabled));
}

const listedIds = (store: Map<string, Doc>) =>
  [...store.keys()].filter((k) => k.startsWith("creatorDirectory/")).map((k) => k.slice("creatorDirectory/".length)).sort();

const row = (id: string, creatorUid: string, ageDays: number, category = "Nature"): WallRow =>
  ({id, creatorUid, thumb: `https://img.example.com/${id.toLowerCase()}.jpg`, category, createdMs: NOW - ageDays * DAY});

test("only eligible creators are listed", async (t) => {
  stubSeams(t, {disabled: ["banned"]});
  const store = installFakeDb(t, seedOf(
    walls("G", "good", [10, 11, 12]), creator("good"),
    walls("T", "two", [10, 11]), creator("two"),
    walls("S", "stale", [62, 63, 64]), creator("stale"),
    walls("D", "deleted", [10, 11, 12]), creator("deleted", {deleted: true}),
    walls("O", "optout", [10, 11, 12]), creator("optout", {creatorDirectoryOptOut: true}),
    walls("B", "banned", [10, 11, 12]), creator("banned"),
    walls("C", "closed", [10, 11, 12]), creator("closed"), {"creatorDeletionState/closed": {closed: true}},
    walls("N", "noprofile", [10, 11, 12]), {"usersv2/noprofile": {}},
  ));

  assert.deepEqual(await rebuildCreatorDirectory(NOW), {listed: 1, removed: 0});
  assert.deepEqual(listedIds(store), ["good"]);
});

test("walls that are not public do not count toward the minimum", async (t) => {
  stubSeams(t, {premium: ["pro"]});
  const bad: Array<[string, Doc]> = [
    ["origin", {originalProtected: false}],
    ["drop", {dropReserved: true}],
    ["streak", {is_streak_exclusive: true}],
    ["premium", {collections: ["pro"]}],
  ];
  const mixed = bad.map(([name, extra]) => seedOf(
    wall(`${name}-1`, `k-${name}`, 10), wall(`${name}-2`, `k-${name}`, 11),
    wall(`${name}-3`, `k-${name}`, 12, extra), creator(`k-${name}`),
  ));
  const store = installFakeDb(t, seedOf(walls("C", "ctl", [10, 11, 12]), creator("ctl"), ...mixed));

  assert.deepEqual(await rebuildCreatorDirectory(NOW), {listed: 1, removed: 0});
  assert.deepEqual(listedIds(store), ["ctl"]);
});

test("planCandidates scores new creators, old creators, and recent follows", () => {
  const old = [row("O1", "old", 40), row("O2", "old", 41), row("O3", "old", 42)];
  const fresh = [row("N1", "new", 5), row("N2", "new", 2), row("N3", "new", 1)];
  const scored = (candidates: ReturnType<typeof planCandidates>, uid: string) =>
    candidates.find((c) => c.uid === uid)?.score;

  const noActivity = planCandidates({walls: [...old, ...fresh], daily: [], edges: [], nowMs: NOW});
  assert.equal(scored(noActivity, "new"), 3);
  assert.equal(scored(noActivity, "old"), 0);

  const active = planCandidates({
    walls: fresh,
    daily: [{wallId: "N1", day: TODAY, favs: 4, sets: 0}],
    edges: [],
    nowMs: NOW,
  });
  assert.equal(scored(active, "new"), 13);

  const followed: FollowEdge[] = [{followerUid: "x", targetUid: "old", createdMs: NOW}];
  const withFollow = planCandidates({walls: old, daily: [], edges: followed, nowMs: NOW});
  assert.equal(scored(withFollow, "old"), 4);
});

test("creators with more recent activity rank first", async (t) => {
  stubSeams(t);
  const store = installFakeDb(t, seedOf(
    walls("RA", "rankA", [40, 41, 42]), creator("rankA"),
    walls("RB", "rankB", [40, 41, 42]), creator("rankB"),
    {[`wallpaper_stats_daily/${TODAY}_RA1`]: {wallId: "RA1", day: TODAY, favs: 3, sets: 1}},
  ));

  assert.deepEqual(await rebuildCreatorDirectory(NOW), {listed: 2, removed: 0});
  assert.equal(store.get("creatorDirectory/rankA")?.rank, 1);
  assert.equal(store.get("creatorDirectory/rankB")?.rank, 2);
});

test("a creator lists the top four walls by today's saves and sets, then newest", async (t) => {
  stubSeams(t);
  const store = installFakeDb(t, seedOf(
    walls("T", "top", [20, 19, 18, 17, 16, 15]), creator("top"),
    {[`wallpaper_stats_daily/${TODAY}_T3`]: {wallId: "T3", day: TODAY, favs: 5, sets: 0}},
    {[`wallpaper_stats_daily/${TODAY}_T1`]: {wallId: "T1", day: TODAY, favs: 3, sets: 0}},
    {[`wallpaper_stats_daily/${TODAY}_T5`]: {wallId: "T5", day: TODAY, favs: 1, sets: 2}},
  ));

  await rebuildCreatorDirectory(NOW);
  const doc = store.get("creatorDirectory/top");
  assert.deepEqual(doc?.walls, [
    {id: "T3", thumb: "https://img.example.com/t3.jpg"},
    {id: "T5", thumb: "https://img.example.com/t5.jpg"},
    {id: "T1", thumb: "https://img.example.com/t1.jpg"},
    {id: "T6", thumb: "https://img.example.com/t6.jpg"},
  ]);
});

test("the directory doc keeps only public fields, with the top three categories", async (t) => {
  stubSeams(t);
  const categories = ["Nature", "Nature", "Nature", "Space", "Space", "Abstract", "Abstract", "Flat"];
  const fieldWalls = seedOf(...categories.map((category, i) => wall(`F${i + 1}`, "fields", i + 1, {category})));
  const store = installFakeDb(t, seedOf(
    fieldWalls,
    creator("fields", {email: "fields@example.com", coins: 5, xp: 9}),
  ));

  await rebuildCreatorDirectory(NOW);
  const doc = store.get("creatorDirectory/fields") as Doc;
  assert.ok(Object.keys(doc).every((key) => ALLOWED_KEYS.includes(key)), Object.keys(doc).join(","));
  for (const hidden of ["bio", "links", "email", "coins", "xp"]) assert.equal(doc[hidden], undefined, hidden);
  assert.equal(doc.uid, "fields");
  assert.equal(doc.name, "Name fields");
  assert.equal(doc.username, "user_fields");
  assert.equal(doc.profilePhoto, "https://img.example.com/fields.jpg");
  assert.equal(doc.followerCount, 7);
  assert.deepEqual(doc.categories, ["Nature", "Abstract", "Space"]);
});

test("a stale directory doc for a creator that is no longer eligible is deleted", async (t) => {
  stubSeams(t);
  const store = installFakeDb(t, {"creatorDirectory/old": {uid: "old", name: "Old"}});

  assert.deepEqual(await rebuildCreatorDirectory(NOW), {listed: 0, removed: 1});
  assert.equal(store.has("creatorDirectory/old"), false);
});

test("with no walls the rebuild writes nothing", async (t) => {
  stubSeams(t);
  const store = installFakeDb(t);

  assert.deepEqual(await rebuildCreatorDirectory(NOW), {listed: 0, removed: 0});
  assert.equal(store.size, 0);
});

test("similarCreators ranks co-followed creators above shared categories", () => {
  const entries = [
    {uid: "A", categories: ["Nature"]},
    {uid: "B", categories: ["Nature"]},
    {uid: "C", categories: ["Space"]},
  ];
  const edges: FollowEdge[] = [
    {followerUid: "x", targetUid: "A", createdMs: NOW},
    {followerUid: "x", targetUid: "C", createdMs: NOW},
    {followerUid: "y", targetUid: "A", createdMs: NOW},
    {followerUid: "y", targetUid: "C", createdMs: NOW},
    {followerUid: "x", targetUid: "Z", createdMs: NOW},
    {followerUid: "y", targetUid: "Z", createdMs: NOW},
  ];
  const similar = similarCreators(entries, edges);

  assert.deepEqual(similar.get("A"), ["C", "B"]);
  assert.deepEqual(similar.get("B"), ["A"]);
  assert.deepEqual(similar.get("C"), ["A"]);
  for (const [uid, list] of similar) {
    assert.equal(list.includes("Z"), false);
    assert.equal(list.includes(uid), false);
  }

  const apart = similarCreators([{uid: "D", categories: ["Art"]}, {uid: "E", categories: ["Music"]}], []);
  assert.deepEqual(apart.get("D"), []);
  assert.deepEqual(apart.get("E"), []);
});

test("followedBy counts only people the viewer follows and returns names and photos", async (t) => {
  installFakeDb(t, {
    "profiles/v/following/a": {targetUid: "a", createdAt: ts(NOW - DAY)},
    "profiles/v/following/b": {targetUid: "b", createdAt: ts(NOW - 2 * DAY)},
    "profiles/c/followers/a": {followerUid: "a", createdAt: ts(NOW)},
    "profiles/c/followers/z": {followerUid: "z", createdAt: ts(NOW)},
    "profiles/c/followers/b": {followerUid: "b", createdAt: ts(NOW)},
    "profiles/a": {name: "Ann", username: "ann", profilePhoto: "https://img.example.com/a.jpg"},
    "profiles/b": {name: "Ben", username: "ben"},
    "profiles/z": {name: "Zed", username: "zed"},
  });

  const result = await followedBy("v", "c", NOW);
  assert.deepEqual(Object.keys(result).sort(), ["count", "people"]);
  assert.equal(result.count, 2);
  assert.deepEqual(result.people, [
    {name: "Ann", photo: "https://img.example.com/a.jpg"},
    {name: "Ben", photo: ""},
  ]);
  for (const person of result.people) assert.deepEqual(Object.keys(person).sort(), ["name", "photo"]);
  assert.equal(JSON.stringify(result).includes("Zed"), false);
});

test("followedBy scans only the viewer's newest follows", async (t) => {
  const following: Seed = {};
  for (let i = 0; i <= FOLLOWING_SCAN_CAP; i++) {
    following[`profiles/v/following/u${i}`] = {targetUid: `u${i}`, createdAt: ts(NOW - i * 1000)};
  }
  installFakeDb(t, seedOf(following, {
    [`profiles/c/followers/u${FOLLOWING_SCAN_CAP}`]: {followerUid: `u${FOLLOWING_SCAN_CAP}`, createdAt: ts(NOW)},
  }));

  assert.equal(FOLLOWING_SCAN_CAP, 500);
  assert.deepEqual(await followedBy("v", "c", NOW), {count: 0, people: []});
});

test("followedBy caches its result for a day", async (t) => {
  const store = installFakeDb(t, {
    "profiles/v/following/a": {targetUid: "a", createdAt: ts(NOW)},
    "profiles/a": {name: "Ann"},
  });

  assert.deepEqual(await followedBy("v", "c", NOW), {count: 0, people: []});
  assert.equal((store.get("followedByCache/v_c")?.expireAt as admin.firestore.Timestamp).toMillis(), NOW + DAY);

  store.set("profiles/c/followers/a", {followerUid: "a", createdAt: ts(NOW)});
  assert.deepEqual(await followedBy("v", "c", NOW + 1000), {count: 0, people: []});
  assert.deepEqual(await followedBy("v", "c", NOW + DAY + 1), {
    count: 1,
    people: [{name: "Ann", photo: ""}],
  });
});

test("followedBy returns zero when the viewer follows nobody", async (t) => {
  installFakeDb(t);

  assert.deepEqual(await followedBy("v", "c", NOW), {count: 0, people: []});
});
