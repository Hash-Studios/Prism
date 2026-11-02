import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {onWallSubmitted} from "../onWallSubmitted";
import {aspectOf, checkSubmittedVariantOf, onWallVariantWritten, sameCreator} from "../wallVariants";
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

for (const [name, update, reason] of [
  ["email", {email: "new@example.com"}, "not_owner"],
  ["creator UID", {creatorUid: "new-owner"}, "not_owner"],
  ["resolution", {resolution: "1000x1000"}, "aspect_ratio"],
] satisfies Array<[string, Doc, string]>) {
  test(`changing the root's ${name} removes it and preserves compatible survivors`, async (t) => {
    const store = setup(t, {"walls/v2": variant({creatorUid: "maker"})});
    await change(store, "walls/v1", variant({review: true, creatorUid: "maker"}));
    await change(store, "walls/v2", variant({review: true, creatorUid: "maker"}));
    await change(store, "walls/root", {...store.get("walls/root"), ...update});
    assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
    assert.equal(store.get("walls/root")?.variantGroupId, undefined);
    assert.equal(store.get("walls/root")?.variantLink, reason);
    await change(store, "walls/v1", {...store.get("walls/v1"), email: "Maker@Example.com"});
    assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
  });
}

test("survivors stay linked after root deletion and delayed creator UID assignment", async (t) => {
  const store = setup(t, {"walls/v2": variant()});
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  await change(store, "walls/root", undefined);
  await change(store, "walls/v1", {...store.get("walls/v1"), creatorUid: "maker"});
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
  assert.equal(store.get("walls/v1")?.variantLink, "linked");
});

test("a group records the creator UID when it is assigned after linking", async (t) => {
  const store = setup(t, {"walls/root": root({creatorUid: undefined})});
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/root", {...store.get("walls/root"), creatorUid: "maker"});
  assert.equal(store.get("wallVariantGroups/root")?.creatorUid, "maker");
});

test("a new variant cannot join different UIDs through a legacy target without a UID", async (t) => {
  const store = setup(t, {"walls/root": root({creatorUid: undefined})});
  await change(store, "walls/v1", variant({review: true, creatorUid: "maker"}));
  await change(store, "walls/v2", variant({review: true, creatorUid: "other"}));
  assert.equal(store.get("walls/v2")?.variantLink, "not_owner");
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1"]);
});

test("repairing a stale group does not steal or clear a wall in another group", async (t) => {
  const store = setup(t, {
    "walls/root": root({variantGroupId: "root", variantIndex: 0}),
    "walls/v1": variant({review: true, variantOf: "other", variantGroupId: "other", variantIndex: 1}),
    "walls/other": root({variantGroupId: "other", variantIndex: 0}),
    "wallVariantGroups/root": {walls: ["root", "v1"]},
    "wallVariantGroups/other": {walls: ["other", "v1"]},
  });
  await change(store, "walls/root", undefined);
  assert.equal(store.get("walls/v1")?.variantGroupId, "other");
  assert.equal(store.get("walls/v1")?.variantIndex, 1);
  assert.deepEqual(store.get("wallVariantGroups/other")?.walls, ["other", "v1"]);
});

test("submission counts live approved members while a removal trigger is pending", async (t) => {
  const store = setup(t, {
    "walls/root": root({variantGroupId: "root", variantIndex: 0}),
    "walls/a": variant({review: true, variantGroupId: "root", variantIndex: 1}),
    "walls/b": variant({review: true, variantGroupId: "root", variantIndex: 2}),
    "walls/c": variant({review: false, variantGroupId: "root", variantIndex: 3}),
    "wallVariantGroups/root": {walls: ["root", "a", "b", "c", "deleted"]},
  });
  await submit(store, "v1");
  assert.equal(store.get("walls/v1")?.variantOf, "root");
  assert.equal(store.get("walls/v1")?.variantLink, undefined);
});

test("sameCreator rejects empty emails and accepts normalized Studio emails without UIDs", () => {
  assert.equal(sameCreator({}, {}), false);
  assert.equal(sameCreator({email: " "}, {email: ""}), false);
  assert.equal(sameCreator({email: " STUDIO@Example.com "}, {email: "studio@example.com"}), true);
});

for (const stale of [{variantLink: "linked"}, {variantIndex: 3}, {variantGroupId: "missing", variantIndex: 4,
  variantLink: "linked"}]) {
  test(`restoring an unlinked wall clears stale fields ${JSON.stringify(stale)}`, async (t) => {
    const store = setup(t);
    await change(store, "walls/restored", root(stale));
    assert.equal(store.get("walls/restored")?.variantGroupId, undefined);
    assert.equal(store.get("walls/restored")?.variantIndex, undefined);
    assert.equal(store.get("walls/restored")?.variantLink, undefined);
  });
}

test("opposite-edge aspect variants remain linked when creator UIDs arrive later", async (t) => {
  const store = setup(t, {"walls/root": root({resolution: "1000x2000", creatorUid: undefined})});
  await change(store, "walls/v1", variant({review: true, resolution: "981x2000"}));
  await change(store, "walls/v2", variant({review: true, resolution: "1019x2000"}));
  await change(store, "walls/v1", {...store.get("walls/v1"), creatorUid: "maker"});
  await change(store, "walls/root", {...store.get("walls/root"), creatorUid: "maker"});
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1", "v2"]);
});

test("a deleted root restored by another owner cannot absorb the surviving group", async (t) => {
  const store = setup(t);
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  const archived = store.get("walls/root");
  await change(store, "walls/root", undefined);
  await change(store, "walls/root", {...archived, email: "other@example.com", creatorUid: "other"});
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
  assert.equal(store.get("walls/root")?.variantGroupId, undefined);
  await change(store, "walls/new", variant({review: true, email: "other@example.com", creatorUid: "other"}));
  assert.equal(store.get("walls/new")?.variantLink, "not_owner");
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
});

test("withdrawal followed by reapproval joins once and delayed withdrawal replay preserves it", async (t) => {
  const store = setup(t);
  await change(store, "walls/v1", variant({review: true}));
  const linked = store.get("walls/v1");
  const withdrawn = {...linked, review: false};
  await change(store, "walls/v1", withdrawn);
  await change(store, "walls/v1", {...store.get("walls/v1"), review: true});
  await fire("v1", linked, withdrawn);
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "v1"]);
  assert.equal(store.get("walls/v1")?.variantLink, "linked");
});

for (const [id, action] of [["root", "delete"], ["root", "withdraw"], ["a", "delete"], ["a", "withdraw"]]) {
  test(`a concurrent ${id === "root" ? "target" : "other member"} ${action} retries approval against fresh reads`, async (t) => {
    const store = setup(t);
    if (id === "a") {
      await change(store, "walls/a", variant({review: true}));
      await change(store, "walls/b", variant({review: true}));
    }
    const path = `walls/${id}`;
    const runTransaction = db.runTransaction.bind(db);
    let attempts = 0;
    let conflicted = false;
    t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
      while (true) {
        try {
          return await runTransaction(async (tx) => {
            attempts++;
            const reads = new Map<string, Doc | undefined>();
            const get = tx.get.bind(tx);
            t.mock.method(tx, "get", async (ref: admin.firestore.DocumentReference) => {
              const snap = await get(ref);
              reads.set(ref.path, snap.data());
              return snap;
            });
            const update = tx.update.bind(tx);
            const set = tx.set.bind(tx);
            const remove = tx.delete.bind(tx);
            t.mock.method(tx, "update", (ref: admin.firestore.DocumentReference, data: Doc) => {
              assert.ok(reads.has(ref.path), `update without transaction read: ${ref.path}`);
              return update(ref, data);
            });
            t.mock.method(tx, "set", (ref: admin.firestore.DocumentReference, data: Doc) => {
              assert.ok(reads.has(ref.path), `set without transaction read: ${ref.path}`);
              return set(ref, data);
            });
            t.mock.method(tx, "delete", (ref: admin.firestore.DocumentReference) => {
              assert.ok(reads.has(ref.path), `delete without transaction read: ${ref.path}`);
              return remove(ref);
            });
            const result = await callback(tx);
            if (!conflicted) {
              conflicted = true;
              assert.ok(reads.has(path));
              assert.ok(reads.has("wallVariantGroups/root"));
              if (action === "delete") store.delete(path);
              else store.set(path, {...store.get(path), review: false});
              assert.notDeepEqual(reads.get(path), store.get(path));
              throw new Error("test-read-conflict");
            }
            return result;
          });
        } catch (error) {
          if (!(error instanceof Error) || error.message !== "test-read-conflict") throw error;
        }
      }
    });
    await change(store, "walls/v1", variant({review: true}));
    assert.equal(attempts, 2);
    if (id === "root") {
      assert.equal(store.get("walls/v1")?.variantLink, action === "delete" ? "not_found" : "not_approved");
      assert.equal(store.get("walls/v1")?.variantGroupId, undefined);
      assert.equal(store.has("wallVariantGroups/root"), false);
    } else {
      assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["root", "b", "v1"]);
      ["root", "b", "v1"].forEach((member, index) => assert.equal(store.get(`walls/${member}`)?.variantIndex, index));
      if (action === "delete") assert.equal(store.has(path), false);
      else assert.equal(store.get(path)?.variantGroupId, undefined);
    }
  });
}

test("a delayed submission check does not reject an already-linked surviving variant", async (t) => {
  const store = setup(t);
  const snapshot = await db.doc("walls/v1").get();
  await change(store, "walls/v1", variant({review: true}));
  await change(store, "walls/v2", variant({review: true}));
  await change(store, "walls/root", undefined);
  await checkSubmittedVariantOf(snapshot);
  assert.equal(store.get("walls/v1")?.variantLink, "linked");
  assert.deepEqual(store.get("wallVariantGroups/root")?.walls, ["v1", "v2"]);
});
