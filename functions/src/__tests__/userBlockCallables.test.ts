import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";

import {buildBlockContentReportDoc, isSameTargetCooldownActive} from "../userBlockCallables";

test("allows immediate unblock after a recent block action", () => {
  assert.equal(
    isSameTargetCooldownActive({
      action: "unblock",
      lastAtMs: 10_000,
      nowMs: 10_500,
    }),
    false,
  );
});

test("keeps the same-target cooldown for repeated block actions", () => {
  assert.equal(
    isSameTargetCooldownActive({
      action: "block",
      lastAtMs: 10_000,
      nowMs: 10_500,
    }),
    true,
  );
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
