import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {promoCodeId, promoIo, redeemCode, type RedeemResponse} from "../promoCodes";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
// A private emulator project per run, so documents left by another run cannot change these counts.
if (enabled) db.settings({projectId: `demo-fixture-${randomUUID().replace(/-/g, "").slice(0, 16)}`});

const DAY = 86_400_000;
const CODE = "FASTLANE27";
const REQ = "request_0001";

test.after(async () => {
  if (enabled) await db.terminate();
});

const callerOf = (uid: string) => ({
  uid,
  token: {email: `${uid}@example.com`, email_verified: true, firebase: {sign_in_provider: "google.com"}},
});

async function seedCode(maxRedemptions: number) {
  const ref = db.collection("promoCodes").doc(promoCodeId(CODE));
  await ref.set({
    code: CODE,
    reward: {type: "coins", coins: 100},
    maxRedemptions,
    redemptionCount: 0,
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * DAY),
    minAccountAgeDays: 0,
    newUsersOnlyDays: null,
    disabled: false,
  });
  return ref;
}

function redeemAs(uid: string, requestId: string, ip: string) {
  return redeemCode.run({
    auth: callerOf(uid),
    data: {code: CODE, requestId, platform: "android"},
    rawRequest: {headers: {"x-forwarded-for": ip}},
  } as never) as Promise<RedeemResponse>;
}

test("emulator: exactly one of many racing users wins the last redemption", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  t.mock.method(promoIo, "accountCreatedMs", async () => Date.now() - 365 * DAY);
  const uids = Array.from({length: 8}, (_, i) => `r${i}`);
  const codeRef = await seedCode(1);
  await Promise.all(uids.map((uid) => db.doc(`usersv2/${uid}`).set({coins: 0})));
  t.after(async () => {
    await Promise.all([
      db.recursiveDelete(codeRef),
      ...uids.map((uid) => db.doc(`usersv2/${uid}`).delete()),
      ...uids.map((uid) => db.doc(`coinTransactions/ctx_promo_${promoCodeId(CODE)}_${uid}`).delete()),
      ...(await db.collection("promoRedeemRate").get()).docs.map((doc) => doc.ref.delete()),
    ]);
  });

  const responses = await Promise.all(uids.map((uid, i) => redeemAs(uid, REQ, `198.51.100.${i + 10}`)));

  assert.equal(responses.filter((r) => r.ok).length, 1);
  for (const response of responses) {
    if (!response.ok) assert.ok(response.reason === "limit_reached" || response.reason === "busy", response.reason);
  }
  assert.equal((await codeRef.get()).data()?.redemptionCount, 1);
  assert.equal((await codeRef.collection("redemptions").get()).size, 1);
  const balances = await Promise.all(uids.map((uid) => db.doc(`usersv2/${uid}`).get()));
  assert.equal(balances.reduce((sum, snap) => sum + Number(snap.data()?.coins ?? 0), 0), 100);
});

test("emulator: one user's concurrent retries credit the coins once", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  t.mock.method(promoIo, "accountCreatedMs", async () => Date.now() - 365 * DAY);
  const uid = "rep";
  const codeRef = await seedCode(10);
  await db.doc(`usersv2/${uid}`).set({coins: 0});
  t.after(async () => {
    await Promise.all([
      db.recursiveDelete(codeRef),
      db.doc(`usersv2/${uid}`).delete(),
      db.doc(`coinTransactions/ctx_promo_${promoCodeId(CODE)}_${uid}`).delete(),
      ...(await db.collection("promoRedeemRate").get()).docs.map((doc) => doc.ref.delete()),
    ]);
  });

  const responses = await Promise.all(Array.from({length: 4}, () => redeemAs(uid, REQ, "198.51.100.200")));

  for (const response of responses) {
    assert.ok(
      (response.ok && typeof response.replayed === "boolean") || (!response.ok && response.reason === "busy"),
      JSON.stringify(response),
    );
  }
  assert.equal(responses.filter((r) => r.ok && r.replayed === false).length, 1);
  assert.equal((await db.doc(`usersv2/${uid}`).get()).data()?.coins, 100);
  assert.equal((await codeRef.collection("redemptions").get()).size, 1);
});
