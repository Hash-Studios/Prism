import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {admissionIdentity, admitChallengeWall, challengeIo, voteChallenge, finalizeChallenge, reconcileChallengeWall,
  scanClosedChallenge, reservedChallengePick, notifyChallengeWinner} from "../weeklyChallenges";
import {commitWotdPick} from "../wallOfTheDay";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
async function fixture(t: TestContext) {
  assert.equal(admin.app().options.projectId ?? process.env.GCLOUD_PROJECT, "demo-prism");
  const key = `challenge_${randomUUID().replace(/-/g, "")}`;
  const uid = `${key}_maker`;
  const voter = `${key}_voter`;
  const ref = db.doc(`weeklyChallenges/${key}`);
  const refs: admin.firestore.DocumentReference[] = [];
  const now = Date.now();
  await ref.set({theme: "Quiet horizons", state: "open", revision: 0, sealed: false,
    opensAt: admin.firestore.Timestamp.fromMillis(now - 86_400_000), closesAt: admin.firestore.Timestamp.fromMillis(now + 86_400_000)});
  for (const user of [uid, voter]) {
    const userRef = db.doc(`usersv2/${user}`);
    refs.push(userRef);
    await userRef.set({email: `${user}@example.com`});
  }
  t.mock.method(challengeIo, "owner", async (user: string) => ({uid: user, email: `${user}@example.com`}));
  const wall = async (suffix: string) => {
    const r = db.doc(`walls/${key}_${suffix}`);
    refs.push(r);
    await r.set({id: r.id, email: `${uid}@example.com`, challengeId: key, review: false,
      originalProtected: true, collections: ["nature"]});
    return r.get();
  };
  t.after(async () => {
    const reservations = await db.collection("challengeWotdReservations").where("challengeId", "==", key).get();
    for (const row of reservations.docs) await row.ref.delete();
    const notices = await db.collection("challengeNotices").where("uid", "==", uid).get();
    for (const row of notices.docs) await row.ref.delete();
    await db.recursiveDelete(ref);
    for (const r of refs) await db.recursiveDelete(r);
    const rates = await db.collection("challengeVoteRateDaily").where("uid", "==", voter).get();
    for (const row of rates.docs) await row.ref.delete();
  });
  return {key, uid, voter, ref, wall};
}

test("emulator: four concurrent admissions admit exactly three; retries and withdrawals do not refund", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const f = await fixture(t);
  const walls = await Promise.all(["a", "b", "c", "d"].map(f.wall));
  const results = await Promise.all(walls.map((w) => admitChallengeWall(w, f.uid, "unknown")));
  assert.equal(results.filter(Boolean).length, 3);
  const quota = await f.ref.collection("members").doc(f.uid).get();
  assert.equal(quota.data()?.count, 3);
  const admitted = walls.filter((_, i) => results[i]);
  await Promise.all(admitted.map((w) => admitChallengeWall(w, f.uid, "unknown")));
  assert.equal((await quota.ref.get()).data()?.count, 3);
  await admitted[0].ref.delete();
  const next = await f.wall("e");
  assert.equal(await admitChallengeWall(next, f.uid, "unknown"), false);
  assert.equal((await next.ref.get()).data()?.challengeId, undefined);
  assert.equal((await f.ref.collection("entries").get()).size, 3);
});

test("emulator: duplicate concurrent votes charge once and match deterministic UID documents", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const f = await fixture(t);
  const w = await f.wall("a");
  await admitChallengeWall(w, f.uid, "unknown");
  await w.ref.update({review: true});
  const approved = await w.ref.get();
  await reconcileChallengeWall(w.id, f.key, approved.updateTime, w.createTime);
  assert.ok(w.createTime);
  const entry = admissionIdentity(f.key, w.id, w.createTime);
  await Promise.all([1, 2, 3].map(() => voteChallenge(f.voter, f.key, entry, true)));
  const r = f.ref.collection("entries").doc(entry);
  assert.equal((await r.get()).data()?.voteCount, 1);
  assert.equal((await r.collection("challengeVotes").get()).size, 1);
  await Promise.all([1, 2].map(() => voteChallenge(f.voter, f.key, entry, false)));
  assert.equal((await r.get()).data()?.voteCount, 0);
});

test("emulator: closed scan sees unresolved create events; concurrent admission invalidates settlement", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const f = await fixture(t);
  const w = await f.wall("a");
  await f.ref.update({state: "voting_closed"});
  assert.equal(await scanClosedChallenge(f.key), null);
  await admitChallengeWall(w, f.uid, "unknown");
  assert.equal(await scanClosedChallenge(f.key), null);
  await w.ref.delete();
  await reconcileChallengeWall(w.id, f.key);
  t.mock.method(challengeIo, "premium", async () => []);
  assert.equal(await finalizeChallenge(f.key), true);
  const late = await f.wall("late");
  assert.equal(await admitChallengeWall(late, f.uid, "unknown"), false);
  assert.equal((await late.ref.get()).data()?.challengeId, undefined);
});

test("emulator: concurrent WOTD publications cannot overwrite the same intended date", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  assert.equal(admin.app().options.projectId ?? process.env.GCLOUD_PROJECT, "demo-prism");
  const current = db.doc("wall_of_the_day/current");
  const before = await current.get();
  await current.delete();
  t.after(async () => {
    if (before.exists) await current.set(before.data() ?? {}); else await current.delete();
  });
  const slot = Date.parse("2099-01-02T03:30:00Z");
  const result = await Promise.all([commitWotdPick(slot, "normal-a", [], false), commitWotdPick(slot, "normal-b", [], false)]);
  assert.equal(result.filter(Boolean).length, 1);
  assert.equal((await current.get()).data()?.wallId, result[0] ? "normal-a" : "normal-b");
});


test("emulator: a stale normal picker cannot consume or overwrite a valid challenge reservation", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const f = await fixture(t);
  const w = await f.wall("a");
  await admitChallengeWall(w, f.uid, "unknown");
  await w.ref.update({review: true});
  const approved = await w.ref.get();
  await reconcileChallengeWall(w.id, f.key, approved.updateTime, w.createTime);
  await f.ref.update({state: "voting_closed"});
  t.mock.method(challengeIo, "premium", async () => []);
  t.mock.method(challengeIo, "ready", async () => true);
  const now = Date.parse("2099-01-01T12:00:00Z");
  assert.equal(await finalizeChallenge(f.key, now), true);
  const current = db.doc("wall_of_the_day/current");
  const before = await current.get();
  await current.delete();
  t.after(async () => {
    if (before.exists) await current.set(before.data() ?? {}); else await current.delete();
  });
  const slot = Date.parse("2099-01-02T03:30:00Z");
  assert.equal((await reservedChallengePick("2099-01-02", []))?.wallId, w.id);
  const results = await Promise.allSettled([commitWotdPick(slot, "normal", [], false), commitWotdPick(slot, w.id, [], true)]);
  assert.equal(results[1].status, "fulfilled");
  assert.equal((await current.get()).data()?.wallId, w.id);
  assert.equal((await db.doc("challengeWotdReservations/2099-01-02").get()).data()?.state, "consumed");
});

test("emulator: concurrent notice handlers claim one inbox and push attempt", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const f = await fixture(t);
  const w = await f.wall("a");
  await admitChallengeWall(w, f.uid, "unknown");
  await w.ref.update({review: true});
  const approved = await w.ref.get();
  await reconcileChallengeWall(w.id, f.key, approved.updateTime, w.createTime);
  assert.ok(w.createTime);
  const entry = admissionIdentity(f.key, w.id, w.createTime);
  await f.ref.update({winnerEntryId: entry});
  let calls = 0;
  t.mock.method(challengeIo, "send", async () => {
    calls++; return true;
  });
  await Promise.all([notifyChallengeWinner(f.key), notifyChallengeWinner(f.key), notifyChallengeWinner(f.key)]);
  assert.equal(calls, 1);
});

test("emulator: withdrawal after publication replaces the consumed award only once", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const f = await fixture(t);
  const walls = await Promise.all([f.wall("a"), f.wall("b")]);
  for (const w of walls) {
    await admitChallengeWall(w, f.uid, "unknown");
    await w.ref.update({review: true});
    const approved = await w.ref.get();
    await reconcileChallengeWall(w.id, f.key, approved.updateTime, w.createTime);
  }
  await f.ref.update({state: "voting_closed"});
  t.mock.method(challengeIo, "premium", async () => []);
  t.mock.method(challengeIo, "ready", async () => true);
  const now = Date.parse("2099-01-01T12:00:00Z");
  assert.equal(await finalizeChallenge(f.key, now), true);
  const current = db.doc("wall_of_the_day/current");
  const before = await current.get();
  await current.delete();
  t.after(async () => {
    if (before.exists) await current.set(before.data() ?? {}); else await current.delete();
  });
  const slot = Date.parse("2099-01-02T03:30:00Z");
  const winner = await reservedChallengePick("2099-01-02", []);
  assert.ok(winner);
  assert.equal(await commitWotdPick(slot, winner.wallId, [], true), true);
  const observed = await current.get();
  await db.doc(`walls/${winner.wallId}`).delete();
  const replacement = await reservedChallengePick("2099-01-02", []);
  assert.ok(replacement);
  assert.notEqual(replacement.wallId, winner.wallId);
  const commits = await Promise.all([1, 2].map(() => commitWotdPick(slot, replacement.wallId, [], true, observed)));
  assert.equal(commits.filter(Boolean).length, 1);
  assert.equal((await current.get()).data()?.wallId, replacement.wallId);
  assert.equal((await db.doc("challengeWotdReservations/2099-01-02").get()).data()?.wallId, replacement.wallId);
});
