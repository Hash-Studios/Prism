import assert from "node:assert/strict";
import test from "node:test";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";
import {editWallMetadata, getWallMetadataForEdit, listWallMetadataEdits, revertWallMetadata} from "../wallMetadata";
import * as admin from "firebase-admin";

test("approved edit is a narrow audited transaction and replay does not charge again", async (t) => {
  let feature: Record<string, {run: (request: unknown) => Promise<Record<string, unknown>>}> | undefined;
  try {
    feature = require("../wallMetadata");
  } catch {/* Feature not implemented yet. */}
  assert.ok(feature, "metadata callables are missing");
  const store = installFakeDb(t, {"usersv2/maker": {name: "Maker"}, "walls/w1": {
    creatorUid: "maker", review: true, title: "Before", category: "Nature", coins: 77, collections: ["premium"],
    wallpaper_url: "asset", visionLabels: ["Tree"],
  }});
  const auth = {uid: "maker", token: {}};
  const get = () => feature!.getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  const loaded = await get();
  const data = {wallDocId: "w1", operationId: "one", expectedRevision: loaded.revision,
    metadata: {title: "After", desc: "Calm", tags: ["Forest"]}};
  const before = {...store.get("walls/w1")};
  const result = await feature.editWallMetadata.run({auth, data} as never);
  assert.deepEqual(await feature.editWallMetadata.run({auth, data} as never), result);
  assert.deepEqual(store.get("walls/w1"), {...before, title: "After", desc: "Calm", tags: ["forest"],
    searchTerms: ["after", "forest", "nature", "calm", "tree"]});
  assert.equal([...store.keys()].filter((p) => p.startsWith("wallMetadataEdits/")).length, 1);
  assert.equal([...store.values()].filter((d) => d.count === 1).length, 1);
  await assert.rejects(() => feature!.editWallMetadata.run({auth, data: {...data, metadata: {...data.metadata, title: "Other"}}} as never),
    {code: "already-exists"});
  const ref = db.doc("walls/w1");
  await ref.update({title: "ABA"});
  await ref.update({title: "After"});
  await assert.rejects(() => feature!.editWallMetadata.run({auth, data: {...data, operationId: "two"}} as never), {code: "aborted"});
});

test("metadata callables refuse unauthenticated, foreign, pending, closed and conflicting UID callers", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {}, "usersv2/other": {}, "walls/w1": {
    creatorUid: "maker", email: "other@example.com", review: true, title: "Before", desc: "", tags: [],
  }});
  const auth = {uid: "maker", token: {}};
  const loaded = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  const input = {wallDocId: "w1", operationId: "edit", expectedRevision: loaded.revision,
    metadata: {title: "After", desc: "", tags: []}};
  await assert.rejects(() => editWallMetadata.run({data: input} as never), {code: "unauthenticated"});
  await assert.rejects(() => editWallMetadata.run({auth: {uid: "other", token: {}}, data: input} as never), {code: "permission-denied"});
  await assert.rejects(() => listWallMetadataEdits.run({auth, data: {wallDocId: "w1"}} as never), {code: "permission-denied"});
  await assert.rejects(() => revertWallMetadata.run({auth, data: {...input, auditId: "a"}} as never), {code: "permission-denied"});
  const wall = store.get("walls/w1")!;
  store.set("walls/w1", {...wall, review: false});
  await assert.rejects(() => editWallMetadata.run({auth, data: input} as never), {code: "failed-precondition"});
  store.set("walls/w1", wall);
  store.set("creatorDeletionState/maker", {closed: true});
  await assert.rejects(() => editWallMetadata.run({auth, data: input} as never), {code: "failed-precondition"});
  store.delete("creatorDeletionState/maker");
  store.set("usersv2/maker", {deleted: true});
  await assert.rejects(() => editWallMetadata.run({auth, data: input} as never), {code: "failed-precondition"});
  assert.equal([...store.keys()].some((key) => key.startsWith("wallMetadataEdits/")), false);
});

test("legacy ownership uses the admin mapping, never token or profile email", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {email: "forged@example.com"}, "usersv2/other": {},
    "legacyCreatorUids/legacy@example.com": {uid: "maker"}, "walls/w1": {email: "legacy@example.com", review: true},
  });
  const lookup = t.mock.method(admin.auth(), "getUserByEmail", async () => {
    throw new Error("mapping must win over Auth");
  });
  const auth = {uid: "maker", token: {email: "different@example.com"}};
  const loaded = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  await editWallMetadata.run({auth, data: {wallDocId: "w1", operationId: "legacy", expectedRevision: loaded.revision,
    metadata: {title: "Safe", desc: "", tags: []}}} as never);
  assert.equal(store.get("walls/w1")?.title, "Safe");
  assert.equal(lookup.mock.callCount(), 0);
  store.set("walls/w1", {...store.get("walls/w1"), creatorUid: "other"});
  await assert.rejects(() => getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never), {code: "permission-denied"});
});

test("unknown or dotted fields are rejected before any metadata mutation", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {}, "walls/w1": {creatorUid: "maker", review: true}});
  const auth = {uid: "maker", token: {}};
  const loaded = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  const metadata = {title: "Safe", desc: "", tags: []};
  const data = {wallDocId: "w1", expectedRevision: loaded.revision, operationId: "edit", metadata};
  for (const key of ["review", "category", "coins", "premium", "dropWeek", "collections", "wallpaper_url", "creatorUid", "requestId", "title.x"]) {
    await assert.rejects(() => editWallMetadata.run({auth, data: {...data, [key]: true}} as never), {code: "invalid-argument"});
    await assert.rejects(() => editWallMetadata.run({auth, data: {...data, metadata: {...metadata, [key]: true}}} as never),
      {code: "invalid-argument"});
  }
  assert.equal(store.size, 2);
});

test("admin privilege allows history and revert but never editing another creator's metadata", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {}, "usersv2/moderator": {},
    "walls/w1": {creatorUid: "maker", review: true, title: "Before"}});
  const auth = {uid: "moderator", token: {admin: true}};
  const loaded = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  await assert.rejects(() => editWallMetadata.run({auth, data: {wallDocId: "w1", operationId: "admin-edit",
    expectedRevision: loaded.revision, metadata: {title: "Changed", desc: "", tags: []}}} as never), {code: "permission-denied"});
  assert.equal(store.size, 3);
  assert.equal(store.get("walls/w1")?.title, "Before");
});

test("metadata revert refuses unsafe legacy text and a recreated wall incarnation", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {}, "usersv2/moderator": {},
    "walls/w1": {creatorUid: "maker", review: true, title: "p0rn"}});
  const auth = {uid: "maker", token: {}};
  const loaded = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  const saved = await editWallMetadata.run({auth, data: {wallDocId: "w1", operationId: "correct",
    expectedRevision: loaded.revision, metadata: {title: "Safe", desc: "", tags: []}}} as never);
  const adminAuth = {uid: "moderator", token: {admin: true}};
  const revert = {wallDocId: "w1", operationId: "undo-unsafe", expectedRevision: saved.revision, auditId: saved.auditId};
  const current = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  await assert.rejects(() => revertWallMetadata.run({auth: adminAuth, data: {...revert, expectedRevision: current.revision}} as never),
    {code: "invalid-argument"});
  const data = store.get("walls/w1")!;
  await db.doc("walls/w1").delete();
  await db.doc("walls/w1").set(data);
  const recreated = await getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  await assert.rejects(() => revertWallMetadata.run({auth: adminAuth, data: {...revert,
    operationId: "undo-recreated", expectedRevision: recreated.revision}} as never), {code: "aborted"});
  assert.equal(store.get("walls/w1")?.title, "Safe");
});
