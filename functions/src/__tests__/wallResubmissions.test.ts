import * as admin from "firebase-admin";
import assert from "node:assert/strict";
import test from "node:test";
import {installFakeDb} from "./fakeDb";
import {getWallResubmissionContext, rejectWallForReview, undoWallRejection} from "../wallResubmissions";

test("admin rejection reasons can name NSFW content without applying wallpaper vocabulary policy", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {}, "usersv2/moderator": {},
    "walls/w1": {creatorUid: "maker", id: "wall1", review: false}});
  const auth = {uid: "moderator", token: {admin: true}};
  const {contexts} = await getWallResubmissionContext.run({auth, data: {wallDocIds: ["w1"]}} as never);
  await rejectWallForReview.run({auth, data: {wallDocId: "w1", expectedWallRevision: contexts.w1.wallRevision,
    expectedReview: false, rejectionOperationId: "reject", reason: "NSFW / sexual content or nudity"}} as never);
  assert.equal(store.get("rejectedWalls/w1")?.rejectionReason, "NSFW / sexual content or nudity");
});

test("a closed admin account cannot create a new moderation operation ledger", async (t) => {
  const store = installFakeDb(t, {"usersv2/maker": {}, "usersv2/moderator": {},
    "creatorDeletionState/moderator": {closed: true}, "walls/w1": {creatorUid: "maker", id: "wall1", review: false}});
  const auth = {uid: "moderator", token: {admin: true}};
  const {contexts} = await getWallResubmissionContext.run({auth, data: {wallDocIds: ["w1"]}} as never);
  await assert.rejects(() => rejectWallForReview.run({auth, data: {wallDocId: "w1", expectedWallRevision: contexts.w1.wallRevision,
    expectedReview: false, rejectionOperationId: "reject", reason: "Better crop"}} as never), {code: "failed-precondition"});
  assert.equal(store.has("walls/w1"), true);
  assert.equal([...store.keys()].some((key) => key.startsWith("wallResubmissionOperations/")), false);
});

test("linked resubmission admission and bounded admin context are exported", () => {
  let feature: Record<string, unknown> = {};
  try {
    feature = require("../wallResubmissions");
  } catch {/* Feature not implemented yet. */}
  assert.ok(feature.submitWallResubmission, "transactional admission is missing");
  assert.ok(feature.getWallResubmissionContext, "verified context is missing");
  assert.ok(feature.undoWallRejection, "guarded undo is missing");
});

for (const [label, wall, users] of [
  ["Studio", {email: "studio@prismwalls.com", origin: "studio"}, {"usersv2/prism-studio": {}}],
  ["unmapped legacy", {email: "legacy@example.com"}, {}],
  ["missing profile", {creatorUid: "missing", email: "missing@example.com"}, {}],
  ["anonymized deleted owner", {email: "", by: "Deleted user"}, {}],
] as const) {
  test(`admins can reject and undo ${label} walls without granting creator authority`, async (t) => {
    const store = installFakeDb(t, {"usersv2/moderator": {}, ...users,
      "walls/w1": {id: "wall1", review: true, title: "Keep", ...wall}});
    t.mock.method(admin.auth(), "getUserByEmail", async () => {
      throw Object.assign(new Error("missing"), {code: "auth/user-not-found"});
    });
    const auth = {uid: "moderator", token: {admin: true}};
    const context = () => getWallResubmissionContext.run({auth, data: {wallDocIds: ["w1"]}} as never);
    const before = {...store.get("walls/w1")};
    await rejectWallForReview.run({auth, data: {wallDocId: "w1", expectedWallRevision: (await context()).contexts.w1.wallRevision,
      expectedReview: true, rejectionOperationId: "reject", reason: "Remove"}} as never);
    assert.equal(store.has("walls/w1"), false);
    await undoWallRejection.run({auth, data: {wallDocId: "w1",
      expectedRejectionRevision: (await context()).contexts.w1.rejectionRevision, operationId: "undo"}} as never);
    assert.deepEqual(store.get("walls/w1"), before);
  });
}

test("moderation cannot archive an identifiable owner after the deletion barrier closes", async (t) => {
  const store = installFakeDb(t, {"usersv2/moderator": {}, "usersv2/maker": {},
    "creatorDeletionState/maker": {closed: true},
    "walls/w1": {creatorUid: "maker", email: "maker@example.com", review: true}});
  const auth = {uid: "moderator", token: {admin: true}};
  const {contexts} = await getWallResubmissionContext.run({auth, data: {wallDocIds: ["w1"]}} as never);
  await assert.rejects(() => rejectWallForReview.run({auth, data: {wallDocId: "w1",
    expectedWallRevision: contexts.w1.wallRevision, expectedReview: true, rejectionOperationId: "reject", reason: "Remove"}} as never),
  {code: "failed-precondition"});
  assert.equal(store.has("rejectedWalls/w1"), false);
});
