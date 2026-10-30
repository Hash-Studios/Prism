import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import * as wotd from "../wallOfTheDay";
import {sendToUser} from "../notificationHelper";
import {onWallSubmitted} from "../onWallSubmitted";
import {installFakeDb, type Doc} from "./fakeDb";
import {
  onChallengeWallSubmitted, admitChallengeWall, admissionIdentity, challengeIo, compareTimestamp, dateKey, fallbackTheme, finalizeChallenge,
  getChallenge, getWeeklyChallenge, listWeeklyChallenges, mondayAt, notifyChallengeWinner, openChallengeSlot,
  reconcileChallengeWall, reservedChallengePick, runChallengeSchedule, scanClosedChallenge, setChallengeVote,
  voteChallenge, commitChallengeReservation, removeChallengeVotesForAccount, refreshPublishedChallengeAward,
} from "../weeklyChallenges";

const at = (n: number) => admin.firestore.Timestamp.fromMillis(n);
const WEEK = 604_800_000;
const CH = "2026-11-02";
const OPEN = Date.parse(`${CH}T00:00:00Z`);
const NOW = OPEN + 1234;
const challenge = (extra: Doc = {}) => ({theme: "Quiet horizons", state: "open", opensAt: at(0), closesAt: at(OPEN + WEEK),
  revision: 0, sealed: false, ...extra});
const wall = (extra: Doc = {}) => ({id: "logical", email: "maker@example.com", by: "Maker", challengeId: CH,
  review: false, originalProtected: true, collections: ["nature"], ...extra});
const path = (entry: string) => `weeklyChallenges/${CH}/entries/${entry}`;
const user = {email: "maker@example.com"};
function setup(t: TestContext, extra: Record<string, Doc> = {}) {
  t.mock.method(challengeIo, "owner", async (uid: string) => ({uid, email: `${uid}@example.com`}));
  t.mock.method(challengeIo, "premium", async () => ["space"]);
  t.mock.method(challengeIo, "ready", async (id: string) => {
    const wall = (await db.doc(`walls/${id}`).get()).data();
    return wall?.review === true && wall.originalProtected === true && !(wall.collections ?? []).includes("space");
  });
  return installFakeDb(t, {"usersv2/maker": user, "usersv2/voter": {email: "voter@example.com"},
    [`weeklyChallenges/${CH}`]: challenge(), ...extra});
}
async function admit(name = "w1") {
  const snap = await db.doc(`walls/${name}`).get();
  assert.ok(snap.createTime);
  const admitted = await admitChallengeWall(snap, "maker", "unknown");
  return {snap, admitted, key: admissionIdentity(CH, name, snap.createTime)};
}
async function approved(name = "w1", when = NOW) {
  const {snap, key} = await admit(name);
  await snap.ref.update({review: true});
  await reconcileChallengeWall(name, CH, at(when), snap.createTime);
  return key;
}

test("UTC Monday and full precision identities keep boundaries and incarnations distinct", () => {
  assert.equal(dateKey(mondayAt(Date.parse("2026-11-08T23:59:59Z"))), CH);
  assert.equal(mondayAt(OPEN), OPEN);
  const a = new admin.firestore.Timestamp(1, 1);
  const b = new admin.firestore.Timestamp(1, 2);
  assert.ok(compareTimestamp(a, b) < 0);
  assert.notEqual(admissionIdentity(CH, "w", a), admissionIdentity(CH, "w", b));
});

test("admission retains own link and retries consume a single lifetime place", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const first = await admit();
  assert.equal(first.admitted, true);
  assert.equal(await admitChallengeWall(first.snap, "maker", "unknown"), true);
  assert.equal(store.get(`weeklyChallenges/${CH}/members/maker`)?.count, 1);
  assert.equal(store.get("walls/w1")?.challengeId, CH);
  assert.equal(store.get(path(first.key))?.state, "pending");
  const result = await getChallenge(CH, "maker", "top");
  assert.deepEqual(result.myAdmittedWallIds, ["w1"]);
  assert.equal(result.myEntryCount, 1);
  assert.deepEqual(result.entries, []);
});

for (const [name, principal, kind, extra] of [
  ["missing auth", undefined, "unknown", {}], ["system", "maker", "system", {}], ["service account", "maker", "service_account", {}],
  ["spoofed owner", "voter", "unknown", {}], ["initially approved", "maker", "unknown", {review: true}],
  ["Studio", "maker", "unknown", {origin: "studio"}],
] as const) {
  test(`admission strips ${name} without consuming a place`, async (t) => {
    const store = setup(t, {"walls/w1": wall(extra)});
    assert.equal(await admitChallengeWall(await db.doc("walls/w1").get(), principal, kind), false);
    assert.equal(store.get("walls/w1")?.challengeId, undefined);
    assert.equal(store.has(`weeklyChallenges/${CH}/members/maker`), false);
  });
}

test("closed and out-of-window links strip using trusted create time instead of client createdAt", async (t) => {
  const store = setup(t, {[`weeklyChallenges/${CH}`]: challenge({opensAt: at(2)}),
    "walls/w1": wall({createdAt: at(NOW)})});
  assert.equal((await admit()).admitted, false);
  assert.equal(store.get("walls/w1")?.challengeId, undefined);
});

test("fourth upload remains ordinary and rejected or withdrawn entries do not refund places", async (t) => {
  const store = setup(t, Object.fromEntries([1, 2, 3, 4].map((n) => [`walls/w${n}`, wall()])));
  for (let n = 1; n <= 3; n++) assert.equal((await admit(`w${n}`)).admitted, true);
  await db.doc("walls/w1").delete();
  await reconcileChallengeWall("w1", CH);
  assert.equal((await admit("w4")).admitted, false);
  assert.equal(store.get("walls/w4")?.challengeId, undefined);
  assert.equal(store.get(`weeklyChallenges/${CH}/members/maker`)?.count, 3);
});

test("account deletion barrier refuses admission", async (t) => {
  setup(t, {"walls/w1": wall(), "creatorDeletionState/maker": {closed: true}});
  assert.equal((await admit()).admitted, false);
});

test("stale create event cannot strip or admit a recreated wall", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const old = await db.doc("walls/w1").get();
  await old.ref.delete();
  await old.ref.set(wall());
  assert.equal(await admitChallengeWall(old), false);
  assert.equal(store.get("walls/w1")?.challengeId, CH);
});

test("approval delivered before admission retains event time; reapproval never resets it", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const original = await db.doc("walls/w1").get();
  await original.ref.update({review: true});
  await reconcileChallengeWall("w1", CH, at(NOW), original.createTime);
  assert.equal(await admitChallengeWall(original, "maker", "unknown"), true);
  assert.ok(original.createTime);
  const key = admissionIdentity(CH, "w1", original.createTime);
  assert.ok((store.get(path(key))?.approvedAt as admin.firestore.Timestamp).isEqual(at(NOW)));
  await original.ref.update({review: false});
  await reconcileChallengeWall("w1", CH);
  await original.ref.update({review: true});
  await reconcileChallengeWall("w1", CH, at(NOW + 100), original.createTime);
  assert.ok((store.get(path(key))?.approvedAt as admin.firestore.Timestamp).isEqual(at(NOW)));
});

test("votes are deterministic, no-op retries do not change counts or rate, and self votes fail", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved();
  assert.deepEqual(await voteChallenge("voter", CH, key, true, () => NOW), {voted: true, voteCount: 1});
  assert.deepEqual(await voteChallenge("voter", CH, key, true, () => NOW), {voted: true, voteCount: 1});
  assert.equal(store.get(`challengeVoteRateDaily/voter_${CH}`)?.count, 1);
  await assert.rejects(voteChallenge("maker", CH, key, true, () => NOW), /own-entry/);
  assert.deepEqual(await voteChallenge("voter", CH, key, false, () => NOW), {voted: false, voteCount: 0});
  assert.equal(store.get(`challengeVoteRateDaily/voter_${CH}`)?.count, 2);
});

test("votes enforce bool input, closure at exact UTC cutoff, account barrier and daily 200", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved();
  await assert.rejects(voteChallenge("voter", CH, key, "true" as unknown as boolean, () => NOW), /vote must/);
  await assert.rejects(voteChallenge("voter", CH, key, true, () => OPEN + WEEK), /challenge-closed/);
  store.set(`challengeVoteRateDaily/voter_${CH}`, {uid: "voter", count: 200});
  await assert.rejects(voteChallenge("voter", CH, key, true, () => NOW), /daily-limit/);
  store.set("creatorDeletionState/voter", {closed: true});
  await assert.rejects(voteChallenge("voter", CH, key, true, () => NOW), /account-closed/);
});

for (const direction of ["maker/blockedUsers/voter", "voter/blockedUsers/maker"]) {
  test(`bilateral block ${direction} hides entries and refuses votes`, async (t) => {
    const store = setup(t, {"walls/w1": wall()});
    const key = await approved();
    store.set(`usersv2/${direction}`, {});
    await assert.rejects(voteChallenge("voter", CH, key, true, () => NOW), /entry-missing/);
    assert.deepEqual((await getChallenge(CH, "voter", "top")).entries, []);
  });
}

test("settlement waits indefinitely for pending reviews and missing authenticated create decisions", async (t) => {
  const store = setup(t, {"walls/w1": wall(), [`weeklyChallenges/${CH}`]: challenge({state: "voting_closed"})});
  assert.equal(await scanClosedChallenge(CH), null);
  await admit();
  assert.equal(await scanClosedChallenge(CH), null);
  assert.equal(await finalizeChallenge(CH, OPEN + 9 * 86_400_000), false);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.sealed, false);
});

test("late approval can win with zero votes, reserves next UTC date and grants one badge", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved("w1", OPEN + 9 * 86_400_000);
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  assert.equal(await finalizeChallenge(CH, Date.parse("2026-11-11T23:59:59Z")), true);
  const c = store.get(`weeklyChallenges/${CH}`);
  assert.ok(c);
  assert.equal(c.winnerEntryId, key);
  assert.equal(c.state, "winner_picked");
  assert.equal(c.reservedDate, "2026-11-12");
  assert.equal((store.get("usersv2/maker")?.badges as unknown[]).length, 1);
  assert.equal(await finalizeChallenge(CH), false);
});

test("full precision approval ties then entry ID determine Top and New; all candidates are considered", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/w2": wall(), "walls/w3": wall()});
  const a = await approved("w1");
  const b = await approved("w2");
  const c = await approved("w3");
  store.set(path(a), {...store.get(path(a)), approvedAt: new admin.firestore.Timestamp(100, 2), voteCount: 7});
  store.set(path(b), {...store.get(path(b)), approvedAt: new admin.firestore.Timestamp(100, 1), voteCount: 7});
  store.set(path(c), {...store.get(path(c)), approvedAt: new admin.firestore.Timestamp(100, 1), voteCount: 7});
  assert.deepEqual((await getChallenge(CH, "", "top")).entries.map((e) => e.id), [b, c].sort().concat(a));
  assert.equal((await getChallenge(CH, "", "new")).entries[0].id, a);
});

test("unready or premium leaders fall through, transient delivery errors retry", async (t) => {
  const store = setup(t, {"walls/w1": wall({collections: ["space"]}), "walls/w2": wall()});
  const a = await approved("w1");
  const b = await approved("w2");
  store.set(path(a), {...store.get(path(a)), voteCount: 99});
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  t.mock.method(challengeIo, "ready", async () => {
    throw new Error("temporary network error");
  });
  await assert.rejects(finalizeChallenge(CH, NOW), /temporary network/);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.sealed, false);
  t.mock.method(challengeIo, "ready", async (wallId: string) => wallId === "w2");
  assert.equal(await finalizeChallenge(CH, NOW), true);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.winnerEntryId, b);
});

test("revision change during readiness invalidates finalization", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  await approved();
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  t.mock.method(challengeIo, "ready", async () => {
    const c = store.get(`weeklyChallenges/${CH}`);
    assert.ok(c);
    store.set(`weeklyChallenges/${CH}`, {...c, revision: Number(c.revision) + 1});
    return true;
  });
  assert.equal(await finalizeChallenge(CH, NOW), false);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.sealed, false);
});

test("no entries archives with noWinner and no reservation", async (t) => {
  const store = setup(t, {[`weeklyChallenges/${CH}`]: challenge({state: "voting_closed"})});
  assert.equal(await finalizeChallenge(CH, NOW), true);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.noWinner, true);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.state, "archived");
  assert.equal([...store.keys()].some((k) => k.startsWith("challengeWotdReservations/")), false);
});

test("reservation collisions move to next available day; withdrawal falls through the settled ranking", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/w2": wall(),
    "challengeWotdReservations/2026-11-03": {challengeId: "other"}});
  const a = await approved("w1");
  await approved("w2");
  store.set(path(a), {...store.get(path(a)), voteCount: 2});
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  await finalizeChallenge(CH, NOW);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.reservedDate, "2026-11-04");
  await db.doc("walls/w1").delete();
  assert.deepEqual(await reservedChallengePick("2026-11-04", []), {wallId: "w2", reservation: "2026-11-04"});
  assert.equal(await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-04", "w2", [])), true);
  assert.equal(store.get("challengeWotdReservations/2026-11-04")?.state, "consumed");
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.state, "archived");
});

test("reservation rejects recreated wall and exhaustion archives normal WOTD outcome", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  await approved();
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  await finalizeChallenge(CH, NOW);
  await db.doc("walls/w1").delete();
  await db.doc("walls/w1").set(wall({review: true}));
  assert.equal(await reservedChallengePick("2026-11-03", []), null);
  assert.equal(await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", null, [])), true);
  assert.equal(store.get("challengeWotdReservations/2026-11-03")?.state, "exhausted");
});

test("empty queue uses prior UTC week with complete pagination and vote, time, ID ties", async (t) => {
  const seed: Record<string, Doc> = {};
  for (let n = 0; n < 205; n++) {
    seed[`wallRequests/r${String(n).padStart(3, "0")}`] = {
      text: "Quiet mountain light", requesterUid: "maker", status: "open", hidden: false, createdAt: at(OPEN - 1000), voteCount: n,
    };
  }
  seed["wallRequests/outside"] = {text: "Outside window", requesterUid: "maker", status: "open", createdAt: at(OPEN), voteCount: 999};
  const store = setup(t, seed);
  assert.deepEqual(await fallbackTheme(OPEN), {theme: "Quiet mountain light", sourceId: "r204"});
  store.delete(`weeklyChallenges/${CH}`);
  await openChallengeSlot(OPEN);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.sourceId, "r204");
});

test("empty queue without a request skips the week; stable queue opens once at the intended boundary", async (t) => {
  const store = setup(t);
  store.delete(`weeklyChallenges/${CH}`);
  await openChallengeSlot(OPEN);
  assert.equal(store.has(`weeklyChallenges/${CH}`), false);
  store.delete(`weeklyChallengeSlots/${CH}`);
  store.set("challengeThemes/second", {theme: "Second", order: 2});
  store.set("challengeThemes/first", {theme: "First", order: 1});
  await runChallengeSchedule(OPEN, OPEN);
  await runChallengeSchedule(OPEN, OPEN);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.theme, "First");
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.state, "open");
  assert.equal(store.get("challengeThemes/first")?.usedBy, CH);
  assert.equal(store.get("challengeThemes/second")?.usedBy, undefined);
});

test("winner notice is preference-aware and a repeated handler creates one effect", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "usersv2/maker/private/session": {postAlerts: false}});
  await approved();
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  await finalizeChallenge(CH, NOW);
  const calls: unknown[][] = [];
  t.mock.method(challengeIo, "send", async (...args: unknown[]) => {
    calls.push(args); return true;
  });
  await notifyChallengeWinner(CH);
  await notifyChallengeWinner(CH);
  assert.equal(calls.length, 1);
  assert.equal(calls[0][2], false);
  assert.equal((calls[0][0] as {docId: string}).docId, `challenge_winner_${CH}_maker`);
});

test("account deletion removes private votes and daily rates without resetting admission quota", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved();
  await voteChallenge("voter", CH, key, true, () => NOW);
  await removeChallengeVotesForAccount("voter");
  assert.equal(store.has(`${path(key)}/challengeVotes/voter`), false);
  assert.equal(store.get(path(key))?.voteCount, 0);
  assert.equal(store.get(`weeklyChallenges/${CH}/members/maker`)?.count, 1);
});

test("callable validation and region contract reject malformed inputs", async () => {
  assert.deepEqual(getWeeklyChallenge.__endpoint.callableTrigger, {});
  await assert.rejects(getWeeklyChallenge.run({data: {challengeId: CH, sort: "bad"}} as never), /Invalid sort/);
  await assert.rejects(listWeeklyChallenges.run({data: {kind: "bad"}} as never), /Invalid challenge kind/);
  await assert.rejects(setChallengeVote.run({data: {}} as never), /Sign in/);
});

test("repeated reconciliation does not drift revision or first approval", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved();
  const revision = store.get(`weeklyChallenges/${CH}`)?.revision;
  await reconcileChallengeWall("w1", CH);
  await reconcileChallengeWall("w1", CH);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.revision, revision);
  assert.ok((store.get(path(key))?.approvedAt as admin.firestore.Timestamp).isEqual(at(NOW)));
});

test("a post-settlement reapproval cannot join the frozen fallback ranking", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/w2": wall()});
  await approved("w1");
  await approved("w2");
  await db.doc("walls/w2").update({review: false, rejected: true});
  await reconcileChallengeWall("w2", CH);
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  await finalizeChallenge(CH, NOW);
  await db.doc("walls/w1").delete();
  await db.doc("walls/w2").update({review: true});
  await reconcileChallengeWall("w2", CH, at(NOW + 100), (await db.doc("walls/w2").get()).createTime);
  assert.equal(await reservedChallengePick("2026-11-03", []), null);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.noWinner, true);
});

test("live owner and identity changes hide an entry and winner even before reconciliation", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  await approved();
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  await finalizeChallenge(CH, NOW);
  await db.doc("walls/w1").update({email: "somebody@example.com"});
  const result = await getChallenge(CH, "voter", "top");
  assert.deepEqual(result.entries, []);
  assert.equal(result.challenge.winner, null);
});

test("newly available reservation forces an already-started normal WOTD publication to retry", async (t) => {
  setup(t, {"walls/w1": wall()});
  await approved();
  await db.doc(`weeklyChallenges/${CH}`).update({state: "voting_closed"});
  await finalizeChallenge(CH, NOW);
  assert.equal(await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", null, [])), false);
});

test("failed winner push retains a stable inbox receipt and retries without a new identity", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  await approved();
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  await finalizeChallenge(CH, NOW);
  t.mock.method(challengeIo, "send", async () => false);
  await assert.rejects(notifyChallengeWinner(CH), /notice failed/);
  const marker = store.get(`challengeNotices/winner_${CH}_maker`);
  assert.ok(marker);
  assert.equal(marker.inboxWritten, true);
  assert.equal(marker.pushState, "retry");
  t.mock.method(challengeIo, "send", async () => true);
  await notifyChallengeWinner(CH);
  assert.equal(store.get(`challengeNotices/winner_${CH}_maker`)?.sent, true);
});

test("a moderation write whose trigger is delayed still invalidates settlement", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/w2": wall()});
  await approved("w1");
  await approved("w2");
  await db.doc("walls/w2").update({review: false, rejected: true});
  await reconcileChallengeWall("w2", CH);
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  t.mock.method(challengeIo, "ready", async () => {
    await db.doc("walls/w2").update({review: true});
    return true;
  });
  assert.equal(await finalizeChallenge(CH, NOW), false);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.sealed, false);
});

test("admission accepts an API-key-labelled event only with the exact live Auth UID", async (t) => {
  setup(t, {"walls/w1": wall()});
  assert.equal(await admitChallengeWall(await db.doc("walls/w1").get(), "maker", "api_key"), true);
});

for (const owner of [null, {uid: "other", email: "maker@example.com"},
  {uid: "maker", email: "maker@example.com", disabled: true}]) {
  test(`admission rejects unresolved, mismatched or disabled Auth identity ${JSON.stringify(owner)}`, async (t) => {
    const store = setup(t, {"walls/w1": wall()});
    t.mock.method(challengeIo, "owner", async () => owner);
    assert.equal(await admitChallengeWall(await db.doc("walls/w1").get(), "maker", "api_key"), false);
    assert.equal(store.get("walls/w1")?.challengeId, undefined);
  });
}

for (const boundary of ["close", "day"]) {
  test(`transaction retry samples the clock again across UTC ${boundary}`, async (t) => {
    const store = setup(t, {"walls/w1": wall()});
    const key = await approved();
    const retryAt = boundary === "close" ? OPEN + WEEK : OPEN + 86_400_000;
    let now = retryAt - 1;
    const original = db.runTransaction.bind(db);
    t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
      await assert.rejects(original(async (tx) => {
        await callback(tx);
        throw new Error("retry-conflict");
      }), /retry-conflict/);
      now = retryAt;
      return original(callback);
    });
    if (boundary === "close") {
      await assert.rejects(voteChallenge("voter", CH, key, true, () => now), /challenge-closed/);
      assert.equal(store.get(path(key))?.voteCount, 0);
    } else {
      await voteChallenge("voter", CH, key, true, () => now);
      assert.equal(store.get(`challengeVoteRateDaily/voter_${dateKey(now)}`)?.count, 1);
    }
    assert.equal(store.has(`challengeVoteRateDaily/voter_${dateKey(retryAt - 1)}`), false);
  });
}

test("non-Monday ticks and stale Monday retries do not retroactively open a week", async (t) => {
  const store = setup(t, {"challengeThemes/one": {order: 1, theme: "Night"}});
  store.delete(`weeklyChallenges/${CH}`);
  await runChallengeSchedule(OPEN + 900_000, OPEN + 900_000);
  assert.equal(store.has(`weeklyChallenges/${CH}`), false);
  await runChallengeSchedule(OPEN, OPEN + WEEK);
  assert.equal(store.has(`weeklyChallenges/${CH}`), false);
});

test("deleting a voter changes live totals without changing sealed settlement order", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved();
  await voteChallenge("voter", CH, key, true, () => NOW);
  await db.doc(`weeklyChallenges/${CH}`).update({state: "voting_closed"});
  await finalizeChallenge(CH, NOW);
  const ranking = store.get(`weeklyChallenges/${CH}`)?.rankingId;
  await removeChallengeVotesForAccount("voter");
  assert.equal(store.get(path(key))?.voteCount, 0);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.rankingId, ranking);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.selectedWinnerEntryId, key);
});

test("a consumed reservation falls back after publication and cannot be stolen by a normal picker", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/w2": wall()});
  await approved("w1");
  const second = await approved("w2", NOW + 1);
  await db.doc(`weeklyChallenges/${CH}`).update({state: "voting_closed"});
  await finalizeChallenge(CH, NOW);
  await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", "w1", []));
  await db.doc("walls/w1").delete();
  assert.equal((await reservedChallengePick("2026-11-03", []))?.wallId, "w2");
  assert.equal(await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", null, [])), false);
  assert.equal(await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", "w2", [])), true);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.winnerEntryId, second);
});


test("public entry pages bound work and continue past a page hidden by bilateral blocks", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const key = await approved();
  const original = store.get(path(key));
  assert.ok(original);
  store.delete(path(key));
  for (let i = 0; i < 201; i++) store.set(path(`e${String(i).padStart(3, "0")}`), {...original});
  const first = await getChallenge(CH, "voter", "top");
  assert.equal(first.entries.length, 200);
  assert.equal(first.nextCursor, "e199");
  const second = await getChallenge(CH, "voter", "top", first.nextCursor ?? undefined);
  assert.deepEqual(second.entries.map((e) => e.id), ["e200"]);
  assert.equal(second.nextCursor, null);
  store.set("usersv2/maker/blockedUsers/voter", {});
  const hidden = await getChallenge(CH, "voter", "top");
  assert.equal(hidden.entries.length, 0);
  assert.equal(hidden.nextCursor, "e199");
});

test("past challenges use bounded pages and reject malformed cursors", async (t) => {
  const store = setup(t);
  for (let i = 0; i < 21; i++) store.set(`weeklyChallenges/p${i}`, challenge({state: "archived", opensAt: at(i)}));
  const first = await listWeeklyChallenges.run({data: {kind: "past"}} as never);
  assert.equal(first.challenges.length, 20);
  assert.equal(first.nextCursor, "p1");
  const second = await listWeeklyChallenges.run({data: {kind: "past", cursor: first.nextCursor}} as never);
  assert.deepEqual(second.challenges.map((c) => c.id), ["p0"]);
  await assert.rejects(listWeeklyChallenges.run({data: {kind: "past", cursor: "../x"}} as never), /Invalid/);
});


test("a rejected entry returned to pending blocks settlement before its trigger arrives", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/w2": wall()});
  await approved("w1");
  await approved("w2");
  await db.doc("walls/w2").update({review: false, rejected: true});
  await reconcileChallengeWall("w2", CH);
  await db.doc(`weeklyChallenges/${CH}`).update({state: "voting_closed"});
  t.mock.method(challengeIo, "ready", async () => {
    await db.doc("walls/w2").update({rejected: false});
    return true;
  });
  assert.equal(await finalizeChallenge(CH, NOW), false);
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.sealed, false);
  assert.equal(await scanClosedChallenge(CH), null);
});


test("the recurring schedule refreshes a published award whose challenge link was withdrawn", async (t) => {
  setup(t, {"walls/w1": wall()});
  await approved();
  await db.doc(`weeklyChallenges/${CH}`).update({state: "voting_closed"});
  await finalizeChallenge(CH, NOW);
  const day = Date.parse("2026-11-03T12:00:00Z");
  await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", "w1", []));
  await db.doc("wall_of_the_day/current").set({wallId: "w1", date: at(day)});
  let replacements = 0;
  t.mock.method(wotd, "pickWallOfTheDay", async (slot: number) => {
    assert.equal(slot, day); replacements++;
  });
  await refreshPublishedChallengeAward(day);
  assert.equal(replacements, 0);
  await db.doc("walls/w1").update({challengeId: admin.firestore.FieldValue.delete()});
  await refreshPublishedChallengeAward(day);
  assert.equal(replacements, 1);
});
test("authenticated challenge trigger forwards provenance and retries without duplicate admission", async (t) => {
  const store = setup(t, {"walls/w1": wall(), "walls/spoofed": wall()});
  const snap = await db.doc("walls/w1").get();
  const event = {data: snap, params: {wallId: "w1"}, authId: "maker", authType: "api_key"};
  await onChallengeWallSubmitted.run(event as Parameters<typeof onChallengeWallSubmitted.run>[0]);
  await onChallengeWallSubmitted.run(event as Parameters<typeof onChallengeWallSubmitted.run>[0]);
  assert.equal(store.get(`weeklyChallenges/${CH}/members/maker`)?.count, 1);
  assert.equal(store.get("walls/w1")?.challengeId, CH);
  await onChallengeWallSubmitted.run({
    ...event, data: await db.doc("walls/spoofed").get(), authId: "voter", params: {wallId: "spoofed"},
  } as Parameters<typeof onChallengeWallSubmitted.run>[0]);
  assert.equal(store.get("walls/spoofed")?.challengeId, undefined);
});

test("challenge admission has its own retrying auth trigger; legacy submission keeps its event type", () => {
  const trigger = onChallengeWallSubmitted.__endpoint.eventTrigger;
  assert.equal(trigger?.eventType, "google.cloud.firestore.document.v1.created.withAuthContext");
  assert.equal(trigger?.eventFilterPathPatterns?.document, "walls/{wallId}");
  assert.equal(trigger?.retry, true);
  assert.equal(onWallSubmitted.__endpoint.eventTrigger?.eventType, "google.cloud.firestore.document.v1.created");
  assert.notEqual(onWallSubmitted.__endpoint.eventTrigger?.retry, true);
});

test("challenge trigger propagates transient identity errors and admits on redelivery", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  const event = {data: await db.doc("walls/w1").get(), params: {wallId: "w1"}, authId: "maker", authType: "unknown"};
  let attempts = 0;
  t.mock.method(challengeIo, "owner", async (uid: string) => {
    if (++attempts === 1) throw new Error("identity-unavailable");
    return {uid, email: "maker@example.com"};
  });
  const run = () => onChallengeWallSubmitted.run(event as Parameters<typeof onChallengeWallSubmitted.run>[0]);
  await assert.rejects(run(), /identity-unavailable/);
  assert.equal(store.get("walls/w1")?.challengeId, CH);
  assert.equal(store.has(`weeklyChallenges/${CH}/members/maker`), false);
  await run();
  assert.equal(store.get(`weeklyChallenges/${CH}/members/maker`)?.count, 1);
});

test("scheduler aggregates actual push failures after later challenges and published recovery", async (t) => {
  const store = setup(t, {"walls/w1": wall()});
  await approved();
  store.set(`weeklyChallenges/${CH}`, challenge({state: "voting_closed"}));
  assert.equal(await finalizeChallenge(CH, NOW), true);
  const later = "2026-11-09";
  store.set(`weeklyChallenges/${later}`, challenge());
  store.set("walls/w2", wall({challengeId: later}));
  const secondWall = await db.doc("walls/w2").get();
  assert.ok(secondWall.createTime);
  assert.equal(await admitChallengeWall(secondWall, "maker", "unknown"), true);
  await secondWall.ref.update({review: true});
  await reconcileChallengeWall("w2", later, at(NOW), secondWall.createTime);
  await db.doc(`weeklyChallenges/${later}`).update({state: "winner_picked", sealed: true,
    winnerEntryId: admissionIdentity(later, "w2", secondWall.createTime)});
  const day = Date.parse("2026-11-03T12:00:00Z");
  assert.equal(await db.runTransaction((tx) => commitChallengeReservation(tx, "2026-11-03", "w1", [])), true);
  assert.equal(store.get("challengeWotdReservations/2026-11-03")?.state, "consumed");
  await db.doc("wall_of_the_day/current").set({wallId: "w1", date: at(day)});
  // The published wall becomes ineligible, but remains visible to the notice handler.
  t.mock.method(challengeIo, "ready", async () => false);
  store.set("usersv2/maker/private/session", {fcmToken: "fixture-token", fcmTokenBindingVersion: 1,
    fcmTokenBindingToken: "fixture-token"});
  let sends = 0;
  let failPush = true;
  t.mock.method(challengeIo, "send", sendToUser);
  t.mock.method(admin.messaging(), "send", async (message: admin.messaging.Message) => {
    assert.ok("token" in message && message.token === "fixture-token");
    sends++;
    if (failPush) throw new Error("FCM unavailable");
    return "fixture-message";
  });
  let recovery = 0;
  const recoveryError = new Error("replacement failed");
  t.mock.method(wotd, "pickWallOfTheDay", async () => {
    recovery++; throw recoveryError;
  });
  await assert.rejects(runChallengeSchedule(day, day), (error: unknown) => {
    assert.ok(error instanceof Error && "errors" in error && Array.isArray(error.errors));
    assert.equal(error.errors.length, 3);
    assert.equal(error.errors[2], recoveryError);
    return true;
  });
  assert.equal(sends, 2);
  assert.equal(recovery, 1);
  for (const id of [CH, later]) {
    assert.equal(store.get(`challengeNotices/winner_${id}_maker`)?.pushState, "retry");
  }
  failPush = false;
  t.mock.method(wotd, "pickWallOfTheDay", async () => {
    recovery++;
  });
  await runChallengeSchedule(day, day);
  await runChallengeSchedule(day, day);
  assert.equal(sends, 4);
  for (const id of [CH, later]) assert.equal(store.get(`challengeNotices/winner_${id}_maker`)?.sent, true);
});


test("theme opening failure still advances existing challenges and attempts published recovery", async (t) => {
  const store = setup(t, {[`weeklyChallenges/${CH}`]: challenge({state: "scheduled", closesAt: at(OPEN + 2 * WEEK)})});
  const collection = db.collection.bind(db);
  const themeError = new Error("theme queue unavailable");
  t.mock.method(db, "collection", (name: string) => {
    if (name === "challengeThemes") throw themeError;
    return collection(name);
  });
  const day = OPEN + WEEK;
  store.set(`challengeWotdReservations/${dateKey(day)}`, {state: "consumed", wallId: "gone", challengeId: CH, entryId: "gone"});
  store.set("wall_of_the_day/current", {wallId: "gone", date: at(day)});
  let recoveries = 0;
  t.mock.method(wotd, "pickWallOfTheDay", async () => {
    recoveries++;
  });
  await assert.rejects(runChallengeSchedule(day, day), (error: unknown) => {
    assert.ok(error instanceof Error && "errors" in error);
    assert.deepEqual(error.errors, [themeError]);
    return true;
  });
  assert.equal(store.get(`weeklyChallenges/${CH}`)?.state, "open");
  assert.equal(recoveries, 1);
});
