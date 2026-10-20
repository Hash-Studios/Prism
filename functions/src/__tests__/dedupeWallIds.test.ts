import assert from "node:assert/strict";
import test from "node:test";
import {db} from "../common";
import {dedupeWallIds, duplicateGroups, favouriteTarget, toWallRow} from "../scripts/dedupeWallIds";
import {type Doc, installFakeDb} from "./fakeDb";

const wall = (id: string, name: string, extra: Doc = {}): Doc => ({
  id,
  review: true,
  createdAt: "2021-01-01T00:00:00Z",
  wallpaper_url: `https://img/${name}.jpg`,
  wallpaper_thumb: `https://img/thumb_${name}.jpg`,
  ...extra,
});
const fav = (name: string, id = "AML9"): Doc =>
  ({id, provider: "Prism", url: `https://img/${name}.jpg`, thumb: `https://img/thumb_${name}.jpg`});

test("duplicateGroups keeps the approved wall first, then the oldest", () => {
  const rows = [
    toWallRow("a", wall("AML9", "a", {createdAt: "2021-03-01T00:00:00Z"})),
    toWallRow("b", wall("AML9", "b", {createdAt: "2021-01-01T00:00:00Z", review: false})),
    toWallRow("c", wall("AML9", "c", {createdAt: "2021-02-01T00:00:00Z"})),
    toWallRow("d", wall("UNIQ", "d")),
  ];
  assert.deepEqual(duplicateGroups(rows).map((group) => group.map((row) => row.docId)), [["c", "a", "b"]]);
});

test("a wall without a usable createdAt sorts last and does not break the log", async (t) => {
  const rows = [toWallRow("a", wall("AML9", "a", {createdAt: undefined})), toWallRow("b", wall("AML9", "b"))];
  assert.deepEqual(duplicateGroups(rows)[0].map((row) => row.docId), ["b", "a"]);
  assert.equal(toWallRow("n", wall("X", "n", {createdAt: 5})).createdAtMs, 5);
  installFakeDb(t, {"walls/a": wall("AML9", "a", {createdAt: "not a date"}), "walls/b": wall("AML9", "b")});
  const lines: string[] = [];
  await dedupeWallIds(db, {apply: false}, (line) => lines.push(line));
  assert.ok(lines.some((line) => line.includes("rename walls/a") && line.includes("createdAt=unknown")));
});

test("favouriteTarget matches by url or thumb and refuses ambiguity", () => {
  const group = [toWallRow("a", wall("AML9", "a")), toWallRow("b", wall("AML9", "b"))];
  assert.equal(favouriteTarget(fav("b"), group)?.docId, "b");
  assert.equal(favouriteTarget({thumb: "https://img/thumb_a.jpg"}, group)?.docId, "a");
  assert.equal(favouriteTarget({url: "https://img/other.jpg"}, group), undefined);
  assert.equal(favouriteTarget({url: "https://img/a.jpg", thumb: "https://img/thumb_b.jpg"}, group), undefined);
});

test("a dry run writes nothing", async (t) => {
  const store = installFakeDb(t, {
    "walls/old": wall("AML9", "old"),
    "walls/new": wall("AML9", "new", {createdAt: "2022-01-01T00:00:00Z"}),
    "usersv2/u1": {},
    "usersv2/u1/images/AML9": fav("new"),
  });
  const before = JSON.stringify([...store]);
  const counts = await dedupeWallIds(db, {apply: false}, () => undefined);
  assert.deepEqual(counts, {groups: 1, renamed: 0, favouritesMoved: 1, favouritesAmbiguous: 0});
  assert.equal(JSON.stringify([...store]), before);
});

test("--apply renames the newer wall and moves only its favourites", async (t) => {
  const store = installFakeDb(t, {
    "walls/old": wall("AML9", "old"),
    "walls/new": wall("AML9", "new", {createdAt: "2022-01-01T00:00:00Z"}),
    "walls/other": wall("UNIQ", "other"),
    "usersv2/u1": {},
    "usersv2/u1/images/AML9": fav("new"),
    "usersv2/u2": {},
    "usersv2/u2/images/AML9": fav("old"),
    "usersv2/u3": {},
    "usersv2/u3/images/AML9": fav("gone"),
  });
  const counts = await dedupeWallIds(db, {apply: true}, () => undefined);
  assert.deepEqual(counts, {groups: 1, renamed: 1, favouritesMoved: 1, favouritesAmbiguous: 1});

  assert.equal(store.get("walls/old")?.id, "AML9");
  const next = store.get("walls/new")?.id as string;
  assert.match(next, /^[A-Z]*[0-9][A-Z]*$/);
  assert.equal(next.length, 10);
  assert.equal(store.get("walls/other")?.id, "UNIQ");

  assert.equal(store.has("usersv2/u1/images/AML9"), false);
  assert.deepEqual(store.get(`usersv2/u1/images/${next}`), {...fav("new"), id: next});
  assert.deepEqual(store.get("usersv2/u2/images/AML9"), fav("old"));
  assert.deepEqual(store.get("usersv2/u3/images/AML9"), fav("gone"));
});

test("a rerun after a stop between the favourite moves and the wall rename finishes the job", async (t) => {
  const seed = {
    "walls/old": wall("AML9", "old"),
    "walls/new": wall("AML9", "new", {createdAt: "2022-01-01T00:00:00Z"}),
    "usersv2/u1": {},
    "usersv2/u1/images/AML9": fav("new"),
  };
  const first = installFakeDb(t, {...seed});
  await dedupeWallIds(db, {apply: true}, () => undefined);
  const next = first.get("walls/new")?.id as string;

  // The same state just before the wall rename: favourite already moved, wall not renamed.
  const store = installFakeDb(t, {...seed});
  store.delete("usersv2/u1/images/AML9");
  store.set(`usersv2/u1/images/${next}`, {...fav("new"), id: next});
  const counts = await dedupeWallIds(db, {apply: true}, () => undefined);
  assert.deepEqual(counts, {groups: 1, renamed: 1, favouritesMoved: 0, favouritesAmbiguous: 0});
  assert.equal(store.get("walls/new")?.id, next);
  assert.deepEqual(store.get(`usersv2/u1/images/${next}`), {...fav("new"), id: next});
});
