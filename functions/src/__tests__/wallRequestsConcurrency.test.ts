import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {createHash, randomUUID} from "node:crypto";
import {db, utcDateString} from "../common";
import {closeCreatorProgressForDeletion} from "../creatorProgressDeletion";
import {
  createWallRequest,
  removeWallRequestsForAccount,
  requestTokens,
  setWallRequestVote,
  WALL_REQUESTS,
  REQUEST_RATE_DAILY,
  VOTE_RATE_DAILY,
} from "../wallRequests";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const digest = (value: string) => createHash("sha256").update(value).digest("hex");

async function fixture(t: TestContext) {
  const projectId = admin.app().options.projectId ?? process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  assert.equal(projectId, "demo-prism", "wall request concurrency tests require the demo-prism project");

  const prefix = `wr_${randomUUID().replace(/-/g, "")}`;
  const uids = new Set<string>();
  const refs = new Set<admin.firestore.DocumentReference>();
  const day = utcDateString();
  const user = async (suffix: string) => {
    const uid = `${prefix}_${suffix}`;
    uids.add(uid);
    const userRef = db.collection("usersv2").doc(uid);
    const profileRef = db.collection("profiles").doc(uid);
    refs.add(profileRef);
    await userRef.set({name: uid, profilePhoto: "", email: `${uid}@example.com`});
    await profileRef.set({name: uid, profilePhoto: ""});
    return uid;
  };
  const addRequest = (id: string) => {
    const ref = db.collection(WALL_REQUESTS).doc(id);
    refs.add(ref);
    return ref;
  };
  const addRate = (collection: string, uid: string) => {
    const ref = db.collection(collection).doc(`${uid}_${day}`);
    refs.add(ref);
    return ref;
  };
  const addLock = (text: string) => {
    const key = requestTokens(text).join(" ");
    const ref = db.collection("wallRequestKeyLocks").doc(digest(key));
    refs.add(ref);
    return ref;
  };

  t.after(async () => {
    for (const uid of uids) await db.recursiveDelete(db.collection("usersv2").doc(uid));
    for (const uid of uids) {
      const requests = await db.collection(WALL_REQUESTS).where("requesterUid", "==", uid).get();
      for (const request of requests.docs) await db.recursiveDelete(request.ref);
    }
    for (const collection of [REQUEST_RATE_DAILY, VOTE_RATE_DAILY]) {
      for (const uid of uids) {
        const rates = await db.collection(collection).where("uid", "==", uid).get();
        for (const rate of rates.docs) await rate.ref.delete();
      }
    }
    for (const ref of refs) {
      if (ref.parent.path === "wallRequests") await db.recursiveDelete(ref);
      else await ref.delete();
    }
  });

  return {prefix, day, user, addRequest, addRate, addLock, refs};
}

test("emulator: simultaneous exact requests create one document and charge one account", {
  skip: !enabled,
  timeout: 120000,
}, async (t) => {
  const ctx = await fixture(t);
  const [firstUid, secondUid] = await Promise.all([ctx.user("first"), ctx.user("second")]);
  const text = `Quiet mountain glow ${ctx.prefix}`;
  const key = requestTokens(text).join(" ");
  ctx.addLock(text);
  const results = await Promise.all([
    createWallRequest(firstUid, {text}),
    createWallRequest(secondUid, {text}),
  ]);

  assert.deepEqual(results.map((result) => result.status).sort(), ["created", "duplicate"]);
  const created = results.find((result) => result.status === "created");
  const duplicate = results.find((result) => result.status === "duplicate");
  if (!created || !duplicate || duplicate.status !== "duplicate") throw new Error("expected one create and one duplicate");
  assert.equal(duplicate.exact, true);
  const requests = await db.collection(WALL_REQUESTS).where("key", "==", key).get();
  assert.equal(requests.size, 1);
  ctx.refs.add(requests.docs[0].ref);

  const winner = results[0].status === "created" ? firstUid : secondUid;
  const loser = winner === firstUid ? secondUid : firstUid;
  const winnerRate = await db.collection(REQUEST_RATE_DAILY).doc(`${winner}_${ctx.day}`).get();
  const loserRate = await db.collection(REQUEST_RATE_DAILY).doc(`${loser}_${ctx.day}`).get();
  assert.equal(winnerRate.data()?.count, 1);
  assert.equal(loserRate.exists, false);
});

test("emulator: concurrent duplicate vote toggles keep the count equal to vote documents", {
  skip: !enabled,
  timeout: 120000,
}, async (t) => {
  const ctx = await fixture(t);
  const [requesterUid, firstUid, secondUid] = await Promise.all([
    ctx.user("requester"), ctx.user("first"), ctx.user("second"),
  ]);
  const requestRef = ctx.addRequest(`${ctx.prefix}_request`);
  await requestRef.set({requesterUid, text: "Quiet mountain glow", status: "open", hidden: false, voteCount: 0});

  await Promise.all([
    setWallRequestVote(firstUid, requestRef.id, true),
    setWallRequestVote(firstUid, requestRef.id, true),
    setWallRequestVote(secondUid, requestRef.id, true),
  ]);
  let [request, votes] = await Promise.all([requestRef.get(), requestRef.collection("votes").get()]);
  assert.equal(request.data()?.voteCount, votes.size);
  assert.equal(votes.size, 2);

  await Promise.all([
    setWallRequestVote(firstUid, requestRef.id, false),
    setWallRequestVote(firstUid, requestRef.id, false),
    setWallRequestVote(secondUid, requestRef.id, false),
  ]);
  [request, votes] = await Promise.all([requestRef.get(), requestRef.collection("votes").get()]);
  assert.equal(request.data()?.voteCount, votes.size);
  assert.equal(votes.size, 0);
  for (const uid of [firstUid, secondUid]) {
    const rate = await db.collection(VOTE_RATE_DAILY).doc(`${uid}_${ctx.day}`).get();
    assert.equal(rate.data()?.count, 2, uid);
  }
});

test("emulator: deletion barrier and cleanup reject later creates and votes without resurrecting data", {
  skip: !enabled,
  timeout: 120000,
}, async (t) => {
  const ctx = await fixture(t);
  const [deletingUid, requesterUid] = await Promise.all([ctx.user("deleting"), ctx.user("requester")]);
  const ownText = `Quiet ridge ${ctx.prefix}`;
  const targetText = `Blue valley ${ctx.prefix}`;
  ctx.addLock(ownText);
  ctx.addLock(targetText);
  const own = await createWallRequest(deletingUid, {text: ownText});
  const target = await createWallRequest(requesterUid, {text: targetText});
  if (own.status !== "created" || target.status !== "created") throw new Error("expected unique requests to be created");
  ctx.refs.add(db.collection(WALL_REQUESTS).doc(own.request.id));
  ctx.refs.add(db.collection(WALL_REQUESTS).doc(target.request.id));
  await setWallRequestVote(deletingUid, target.request.id, true);
  const requestRateRef = ctx.addRate(REQUEST_RATE_DAILY, deletingUid);
  const voteRateRef = ctx.addRate(VOTE_RATE_DAILY, deletingUid);

  await closeCreatorProgressForDeletion(deletingUid);
  const barrierRef = db.collection("creatorDeletionState").doc(deletingUid);
  ctx.refs.add(barrierRef);
  await removeWallRequestsForAccount(deletingUid);
  assert.equal((await requestRateRef.get()).exists, true);
  assert.equal((await voteRateRef.get()).exists, true);
  await Promise.all([requestRateRef.delete(), voteRateRef.delete()]);

  assert.equal((await db.collection(WALL_REQUESTS).doc(own.request.id).get()).exists, false);
  assert.equal((await db.collection(WALL_REQUESTS).doc(target.request.id).collection("votes").doc(deletingUid).get()).exists,
    false);
  assert.equal((await db.collection(WALL_REQUESTS).doc(target.request.id).get()).data()?.voteCount, 0);
  await assert.rejects(() => createWallRequest(deletingUid, {text: `Silver forest ${ctx.prefix}`}),
    {code: "failed-precondition"});
  await assert.rejects(() => setWallRequestVote(deletingUid, target.request.id, true),
    {code: "failed-precondition"});
  assert.equal((await db.collection(WALL_REQUESTS).where("requesterUid", "==", deletingUid).get()).size, 0);
  assert.equal((await db.collection(WALL_REQUESTS).doc(target.request.id).collection("votes").doc(deletingUid).get()).exists,
    false);
  assert.equal((await db.collection(REQUEST_RATE_DAILY).doc(`${deletingUid}_${ctx.day}`).get()).exists, false);
  assert.equal((await db.collection(VOTE_RATE_DAILY).doc(`${deletingUid}_${ctx.day}`).get()).exists, false);
});
