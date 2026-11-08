import assert from "node:assert/strict";
import test from "node:test";
import {db} from "../common";
import {planFavouriteKey, qualifyFavouriteKeys} from "../scripts/qualifyFavouriteKeys";
import {type Doc, installFakeDb} from "./fakeDb";

const SEED: Record<string, Doc> = {
  "usersv2/u1/images/AB1C": {id: "AB1C", provider: "Prism"},
  "usersv2/u1/images/abc123": {id: "abc123", provider: "WallHaven"},
  "usersv2/u1/images/777": {id: "777", provider: "Pexels", pinnedAt: "p"},
  "usersv2/u1/images/pexels_777": {id: "777", provider: "Pexels"},
  "usersv2/u2/images/wallhaven_x1": {id: "x1", provider: "WallHaven"},
  "usersv2/u2/images/alias": {id: "other", provider: "Pexels"},
  "walls/abc123": {id: "abc123"},
};

test("planFavouriteKey qualifies only raw Wallhaven and Pexels docs", () => {
  assert.deepEqual(planFavouriteKey("abc123", {id: "abc123", provider: "WallHaven"}), {target: "wallhaven_abc123"});
  assert.deepEqual(planFavouriteKey("777", {id: "777", provider: "Pexels"}), {target: "pexels_777"});
  assert.equal(planFavouriteKey("AB1C", {id: "AB1C", provider: "Prism"}), "keep");
  assert.equal(planFavouriteKey("pexels_777", {id: "777", provider: "Pexels"}), "qualified");
  assert.equal(planFavouriteKey("alias", {id: "other", provider: "Pexels"}), "odd");
});

test("the favourite key migration is a dry run by default and writes nothing", async (t) => {
  const store = installFakeDb(t, SEED);
  const before = JSON.stringify([...store.entries()]);
  const logs: string[] = [];
  const counts = await qualifyFavouriteKeys(db, {apply: false}, (line) => logs.push(line));

  assert.deepEqual(counts, {scanned: 6, rawKept: 1, alreadyQualified: 2, toMove: 2, collisions: 1, odd: 1, moved: 0,
    failed: 0, bySource: {pexels: 1, wallhaven: 1}, samples: ["u1…/777 -> pexels_777 (key exists)",
      "u1…/abc123 -> wallhaven_abc123"]});
  assert.equal(JSON.stringify([...store.entries()]), before);
  assert.ok(logs.at(-1)?.startsWith("done scanned=6"));
});

test("--apply moves raw docs, keeps an existing key doc, and a second run changes nothing", async (t) => {
  const store = installFakeDb(t, SEED);
  const counts = await qualifyFavouriteKeys(db, {apply: true}, () => undefined);

  assert.equal(counts.moved, 2);
  assert.deepEqual(store.get("usersv2/u1/images/wallhaven_abc123"), {id: "abc123", provider: "WallHaven"});
  assert.equal(store.get("usersv2/u1/images/abc123"), undefined);
  assert.deepEqual(store.get("usersv2/u1/images/pexels_777"), {id: "777", provider: "Pexels", pinnedAt: "p"});
  assert.equal(store.get("usersv2/u1/images/777"), undefined);
  assert.deepEqual(store.get("usersv2/u1/images/AB1C"), {id: "AB1C", provider: "Prism"});

  const again = await qualifyFavouriteKeys(db, {apply: true}, () => undefined);
  assert.equal(again.toMove, 0);
  assert.equal(again.moved, 0);
});

test("collision preserves source pin and favourite timestamps without overwriting target timestamps", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1/images/777": {id: "777", provider: "Pexels", pinnedAt: "source-pin", favouritedAt: "source-fav"},
    "usersv2/u1/images/pexels_777": {id: "777", provider: "Pexels", pinnedAt: "target-pin"},
  });

  await qualifyFavouriteKeys(db, {apply: true}, () => undefined);

  assert.deepEqual(store.get("usersv2/u1/images/pexels_777"), {id: "777", provider: "Pexels",
    pinnedAt: "target-pin", favouritedAt: "source-fav"});
  assert.equal(store.has("usersv2/u1/images/777"), false);
});

test("collision with a different logical favourite leaves the raw document untouched", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1/images/777": {id: "777", provider: "Pexels", favouritedAt: "source-fav"},
    "usersv2/u1/images/pexels_777": {id: "other", provider: "Pexels", pinnedAt: "other-pin"},
  });

  await qualifyFavouriteKeys(db, {apply: true}, () => undefined);

  assert.deepEqual(store.get("usersv2/u1/images/777"), {id: "777", provider: "Pexels", favouritedAt: "source-fav"});
  assert.deepEqual(store.get("usersv2/u1/images/pexels_777"), {id: "other", provider: "Pexels", pinnedAt: "other-pin"});
});

test("transaction rechecks the raw document after a concurrent key update", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/u1/images/777": {id: "777", provider: "Pexels", favouritedAt: "source-fav"},
  });
  const transaction = db.runTransaction.bind(db);
  t.mock.method(db, "runTransaction", (callback: Parameters<typeof db.runTransaction>[0]) => {
    store.set("usersv2/u1/images/777", {id: "777", provider: "Prism", favouritedAt: "source-fav"});
    return transaction(callback);
  });

  await qualifyFavouriteKeys(db, {apply: true}, () => undefined);

  assert.deepEqual(store.get("usersv2/u1/images/777"), {id: "777", provider: "Prism", favouritedAt: "source-fav"});
  assert.equal(store.has("usersv2/u1/images/pexels_777"), false);
});
