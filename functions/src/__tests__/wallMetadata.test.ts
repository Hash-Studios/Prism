import assert from "node:assert/strict";
import test from "node:test";
import {db} from "../common";
import {installFakeDb} from "./fakeDb";
import {editWallMetadata, getWallMetadataForEdit, listWallMetadataEdits, revertWallMetadata} from "../wallMetadata";
import * as admin from "firebase-admin";

const forbiddenFields = [
  "id", "category", "wallpaper_url", "wallpaper_thumb", "wallpaper_provider", "wallpaper_path", "wallpaper_sha",
  "wallpaper_source_kind", "thumb_path", "thumb_sha", "thumb_source_kind", "resolution", "size", "file_size",
  "createdAt", "uploadedBy", "by", "email", "creatorUid", "userPhoto", "credit", "coins", "money", "review",
  "premium", "collections", "dropReserved", "dropWeek", "boostedUntil", "depth", "spatial", "colors",
  "originalProtected", "originalObjectId", "moderation", "visionLabels", "searchTerms", "remixOf", "remixCount",
  "resubmitOf", "requestId", "wotd", "wallOfTheDay", "challenge", "challengeId", "is_streak_exclusive",
  "required_streak_days", "streak_shop_coin_cost", "aiMetadata", "isAiGenerated", "aiPrompt", "aiStylePreset",
  "aiModel", "origin", "title.x", "tags.0",
];

test("approved edit is a narrow audited transaction and replay does not charge again", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {name: "Maker"}, "walls/w1": {
    creatorUid: "maker", review: true, title: "Before", category: "Nature", coins: 77, collections: ["premium"],
    wallpaper_url: "asset", visionLabels: ["Tree"],
  }});
  const auth = {uid: "maker", token: {}};
  const get = () => getWallMetadataForEdit.run({auth, data: {wallDocId: "w1"}} as never);
  const loaded = await get();
  const data = {wallDocId: "w1", operationId: "one", expectedRevision: loaded.revision,
    metadata: {title: "After", desc: "Calm", tags: ["Forest"]}};
  const before = {...store.get("walls/w1")};
  const result = await editWallMetadata.run({auth, data} as never);
  assert.deepEqual(await editWallMetadata.run({auth, data} as never), result);
  assert.deepEqual(store.get("walls/w1"), {...before, title: "After", desc: "Calm", tags: ["forest"],
    searchTerms: ["after", "forest", "nature", "calm", "tree"]});
  assert.equal([...store.keys()].filter((p) => p.startsWith("wallMetadataEdits/")).length, 1);
  assert.equal([...store.values()].filter((d) => d.count === 1).length, 1);
  await assert.rejects(() => editWallMetadata.run({auth, data: {...data, metadata: {...data.metadata, title: "Other"}}} as never),
    {code: "already-exists"});
  const ref = db.doc("walls/w1");
  await ref.update({title: "ABA"});
  await ref.update({title: "After"});
  await assert.rejects(() => editWallMetadata.run({auth, data: {...data, operationId: "two"}} as never), {code: "aborted"});
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
  for (const key of forbiddenFields) {
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


test("admin revert rejects every supplied non-text field and restores only audited text", async (t) => {
  const wall = {creatorUid: "maker", review: true, title: "Before", desc: "Original", tags: ["old"],
    category: "Nature", coins: 99, premium: true, dropReserved: true, dropWeek: "next", wotd: true,
    challengeId: "challenge", credit: "Creator", wallpaper_url: "original", wallpaper_thumb: "thumbnail",
    collections: ["premium"], originalProtected: true, searchTerms: ["stale"]};
  const store = installFakeDb(t, {"usersv2/maker": {}, "usersv2/moderator": {}, "walls/w1": wall,
    "coinTransactions/untouched": {amount: 99}, "wall_of_the_day/untouched": {wallId: "w1"}});
  const owner = {uid: "maker", token: {}};
  const auth = {uid: "moderator", token: {admin: true}};
  const load = () => getWallMetadataForEdit.run({auth: owner, data: {wallDocId: "w1"}} as never);
  const saved = await editWallMetadata.run({auth: owner, data: {wallDocId: "w1", operationId: "edit",
    expectedRevision: (await load()).revision, metadata: {title: "After", desc: "Changed", tags: ["new"]}}} as never);
  const data = {wallDocId: "w1", auditId: saved.auditId, operationId: "revert", expectedRevision: (await load()).revision};
  const before = {...store.get("walls/w1")};
  for (const key of [...forbiddenFields, "metadata", "title", "desc", "tags", "before", "after"]) {
    await assert.rejects(() => revertWallMetadata.run({auth, data: {...data, [key]: {review: false}}} as never),
      {code: "invalid-argument"});
    assert.deepEqual(store.get("walls/w1"), before);
  }
  await revertWallMetadata.run({auth, data} as never);
  assert.deepEqual(store.get("walls/w1"), {...wall, searchTerms: ["before", "old", "nature", "original"]});
  assert.deepEqual(store.get("coinTransactions/untouched"), {amount: 99});
  assert.deepEqual(store.get("wall_of_the_day/untouched"), {wallId: "w1"});
  assert.equal([...store.keys()].filter((p) => p.startsWith("wallMetadataEdits/")).length, 2);
});
