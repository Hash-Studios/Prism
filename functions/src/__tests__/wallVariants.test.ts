import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onWallSubmitted} from "../onWallSubmitted";
import {aspectOf, onWallVariantWritten, sameCreator} from "../wallVariants";
import {type Doc, installFakeDb} from "./fakeDb";

const RES = "1440x3040";
const root = (extra: Doc = {}): Doc => ({email: "maker@example.com", review: true, resolution: RES, creatorUid: "maker", ...extra});
const variant = (extra: Doc = {}): Doc => ({email: "maker@example.com", review: false, resolution: RES, variantOf: "root", ...extra});

function setup(t: TestContext, seed: Record<string, Doc> = {}) {
  const store = installFakeDb(t, {"walls/root": root(), "walls/v1": variant(), ...seed});
  t.mock.method(admin.messaging(), "send", async () => "id");
  return store;
}

const fire = (wallId: string, before: Doc | undefined, after: Doc | undefined) => onWallVariantWritten.run({
  params: {wallId},
  data: {before: {data: () => before}, after: {data: () => after}},
} as unknown as Parameters<typeof onWallVariantWritten.run>[0]);

/** Writes `after` to the store, then fires the trigger with the stored state before the write, like Firestore. */
async function change(store: Map<string, Doc>, path: string, after: Doc | undefined) {
  const before = store.get(path);
  if (after === undefined) store.delete(path);
  else store.set(path, after);
  await fire(path.split("/")[1], before, after);
}

/** Fires onWallSubmitted for a wall already in the store, with a snapshot taken from the store like Firestore. */
async function submit(store: Map<string, Doc>, wallId: string) {
  const snapshot = await db.doc(`walls/${wallId}`).get();
  return onWallSubmitted.run({
    params: {wallId},
    data: {...snapshot, data: () => store.get(`walls/${wallId}`)},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
}

test("a submitted variant of another creator's approved wall loses variantOf with not_owner", async (t) => {
  const store = setup(t, {"walls/w1": {email: "other@example.com", review: false, resolution: RES, variantOf: "root"}});
  await submit(store, "w1");
  assert.equal(store.get("walls/w1")?.variantOf, undefined);
  assert.equal(store.get("walls/w1")?.variantLink, "not_owner");
  assert.equal(store.has("walls/w1"), true);
});

test("a submitted variant of an unapproved wall loses variantOf with not_approved", async (t) => {
  const store = setup(t, {"walls/root": root({review: false}), "walls/w1": variant()});
  await submit(store, "w1");
  assert.equal(store.get("walls/w1")?.variantOf, undefined);
  assert.equal(store.get("walls/w1")?.variantLink, "not_approved");
  assert.equal(store.has("walls/w1"), true);
});

test("a submitted variant of a missing wall loses variantOf with not_found", async (t) => {
  const store = setup(t, {"walls/w1": variant({variantOf: "missing"})});
  await submit(store, "w1");
  assert.equal(store.get("walls/w1")?.variantOf, undefined);
  assert.equal(store.get("walls/w1")?.variantLink, "not_found");
  assert.equal(store.has("walls/w1"), true);
});

test("a submitted variant of a full group loses variantOf with group_full", async (t) => {
  const store = setup(t, {
    "walls/root": root({variantGroupId: "root", variantIndex: 0}),
    "walls/a": variant({review: true, variantGroupId: "root", variantIndex: 1}),
    "walls/b": variant({review: true, variantGroupId: "root", variantIndex: 2}),
    "walls/c": variant({review: true, variantGroupId: "root", variantIndex: 3}),
    "walls/d": variant({review: true, variantGroupId: "root", variantIndex: 4}),
    "wallVariantGroups/root": {walls: ["root", "a", "b", "c", "d"]},
    "walls/w1": variant(),
  });
  await submit(store, "w1");
  assert.equal(store.get("walls/w1")?.variantOf, undefined);
  assert.equal(store.get("walls/w1")?.variantLink, "group_full");
});

test("a submitted variant with a resolution off by more than the tolerance loses variantOf with aspect_ratio", async (t) => {
  const store = setup(t, {"walls/w1": variant({resolution: "1440x2560"})});
  await submit(store, "w1");
  assert.equal(store.get("walls/w1")?.variantOf, undefined);
  assert.equal(store.get("walls/w1")?.variantLink, "aspect_ratio");
});

test("a submitted variant within the aspect tolerance keeps variantOf and gets no variantLink", async (t) => {
  const store = setup(t, {"walls/w1": variant({resolution: "1440x3050"})});
  await submit(store, "w1");
  assert.equal(store.get("walls/w1")?.variantOf, "root");
  assert.equal("variantLink" in (store.get("walls/w1") ?? {}), false);
});

test("approving a variant links it to the root group with literal indexes", async (t) => {
  const store = setup(t);
  await change(store, "walls/v1", variant({review: true}));
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1"]);
  assert.equal(store.get("walls/root")?.variantGroupId, "root");
  assert.equal(store.get("walls/root")?.variantIndex, 0);
  assert.equal(store.get("walls/v1")?.variantGroupId, "root");
  assert.equal(store.get("walls/v1")?.variantIndex, 1);
  assert.equal(store.get("walls/v1")?.variantLink, "linked");
});

test("replaying the same approval event gives the same state", async (t) => {
  const store = setup(t);
  const pending = variant();
  const approved = variant({review: true});
  await change(store, "walls/v1", approved);
  const group = store.get("wallVariantGroups/root");
  const root1 = store.get("walls/root");
  const v1 = store.get("walls/v1");

  await fire("v1", pending, approved);

  assert.deepEqual(store.get("wallVariantGroups/root"), group);
  assert.deepEqual(store.get("walls/root"), root1);
  assert.deepEqual(store.get("walls/v1"), v1);
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1"]);
});

test("two variants approved at the same time both join the group once, with matching indexes", async (t) => {
  const store = setup(t, {"walls/v2": variant()});
  await Promise.all([
    change(store, "walls/v1", variant({review: true})),
    change(store, "walls/v2", variant({review: true})),
  ]);
  const walls = store.get("wallVariantGroups/root")?.walls as string[];
  assert.ok(walls.toString() === ["root", "v1", "v2"].toString() || walls.toString() === ["root", "v2", "v1"].toString(),
    `unexpected group ${walls.toString()}`);
  assert.equal(new Set(walls).size, 3);
  walls.forEach((id, index) => assert.equal(store.get(`walls/${id}`)?.variantIndex, index));
  assert.equal(store.get("walls/root")?.variantIndex, 0);
});

test("two variants approved into a nearly full group: exactly one joins, the other is group_full", async (t) => {
  const store = setup(t, {
    "walls/root": root({variantGroupId: "root", variantIndex: 0}),
    "walls/a": variant({review: true, variantGroupId: "root", variantIndex: 1}),
    "walls/b": variant({review: true, variantGroupId: "root", variantIndex: 2}),
    "walls/c": variant({review: true, variantGroupId: "root", variantIndex: 3}),
    "wallVariantGroups/root": {walls: ["root", "a", "b", "c"]},
    "walls/v2": variant(),
  });
  await Promise.all([
    change(store, "walls/v1", variant({review: true})),
    change(store, "walls/v2", variant({review: true})),
  ]);
  const winner = store.get("walls/v1")?.variantLink === "linked" ? "v1" : "v2";
  const loser = winner === "v1" ? "v2" : "v1";
  assert.equal(store.get(`walls/${winner}`)?.variantLink, "linked");
  assert.equal(store.get(`walls/${loser}`)?.variantLink, "group_full");
  assert.equal(store.get(`walls/${loser}`)?.variantOf, undefined);
  assert.equal((store.get("wallVariantGroups/root")?.walls as string[]).length, 5);
  assert.ok((store.get("wallVariantGroups/root")?.walls as string[]).includes(winner));
  assert.equal((store.get("wallVariantGroups/root")?.walls as string[]).includes(loser), false);
});

test("deleting a linked variant removes it from the group and renumbers the rest", async (t) => {
  const store = setup(t, {"walls/v2": variant()});
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  await change(store, "walls/v1", undefined);
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v2"]);
  assert.equal(store.get("walls/v2")?.variantIndex, 1);
});

test("rejecting a linked variant (the wall moves to rejectedWalls) repairs the group like a delete", async (t) => {
  const store = setup(t, {"walls/v2": variant()});
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  store.set("rejectedWalls/v1", variant({review: false}));
  await change(store, "walls/v1", undefined);
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v2"]);
  assert.equal(store.get("walls/v2")?.variantIndex, 1);
});

test("withdrawing a linked variant (review true to false) removes its group fields and variantLink", async (t) => {
  const store = setup(t, {"walls/v2": variant()});
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  await change(store, "walls/v2", {...store.get("walls/v2"), review: false});
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1"]);
  assert.equal("variantGroupId" in (store.get("walls/v2") ?? {}), false);
  assert.equal("variantIndex" in (store.get("walls/v2") ?? {}), false);
  assert.equal("variantLink" in (store.get("walls/v2") ?? {}), false);
});

test("deleting the only other variant dissolves the group and clears the root's group fields", async (t) => {
  const store = setup(t);
  await change(store, "walls/v1", variant({review: true}));
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1"]);
  await change(store, "walls/v1", undefined);
  assert.equal(store.has("wallVariantGroups/root"), false);
  assert.equal("variantGroupId" in (store.get("walls/root") ?? {}), false);
  assert.equal("variantIndex" in (store.get("walls/root") ?? {}), false);
});

test("deleting the root of a three-wall group leaves the two variants with indexes 0 and 1", async (t) => {
  const store = setup(t, {"walls/v2": variant()});
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  await change(store, "walls/root", undefined);
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
  assert.equal(store.get("walls/v1")?.variantIndex, 0);
  assert.equal(store.get("walls/v2")?.variantIndex, 1);
});

test("a wall write that changes only title does not touch the group", async (t) => {
  const store = setup(t);
  await change(store, "walls/v1", variant({review: true}));
  const group = store.get("wallVariantGroups/root");
  const root1 = store.get("walls/root");
  const v1 = store.get("walls/v1");

  await change(store, "walls/v1", {...v1, title: "Renamed"});

  assert.deepEqual(store.get("wallVariantGroups/root"), group);
  assert.deepEqual(store.get("walls/root"), root1);
  assert.deepEqual(store.get("walls/v1"), {...v1, title: "Renamed"});
});

test("aspectOf reads WxH and rejects a bad resolution", () => {
  const aspect = aspectOf("1440x3040");
  assert.ok(aspect !== null && Math.abs(aspect - 1440 / 3040) < 1e-12);
  assert.equal(aspectOf("bad"), null);
});

test("sameCreator ignores email case and fails when both creatorUid values differ", () => {
  assert.equal(sameCreator({email: "Maker@Example.com"}, {email: "maker@example.com"}), true);
  assert.equal(sameCreator({email: "maker@example.com", creatorUid: "u1"}, {email: "maker@example.com", creatorUid: "u2"}), false);
});
