import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";

import {buildBlockContentReportDoc, isSameTargetCooldownActive} from "../userBlockCallables";

test("keeps the same-target cooldown for repeated block actions", () => {
  assert.equal(isSameTargetCooldownActive(10_000, 10_500), true);
  assert.equal(isSameTargetCooldownActive(10_000, 70_000), false);
  assert.equal(isSameTargetCooldownActive(undefined, 10_500), false);
});

test("builds a block content report doc matching submitContentReport's shape", () => {
  const now = admin.firestore.Timestamp.now();
  const doc = buildBlockContentReportDoc({blockedUid: "blocked-uid", callerUid: "caller-uid", now});

  assert.deepEqual(doc, {
    contentType: "user",
    targetFirestoreDocId: "blocked-uid",
    targetCollection: "usersv2",
    reason: "blocked",
    reporterUid: "caller-uid",
    status: "open",
    createdAt: now,
  });
});
