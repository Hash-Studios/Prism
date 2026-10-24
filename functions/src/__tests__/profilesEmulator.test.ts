import assert from "node:assert/strict";
import test from "node:test";
import {db} from "../common";
import {applyFollowEdge, setFollow, syncPublicProfile} from "../profiles";

test("Firestore emulator keeps followerCount exact under concurrent follows", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const suffix = `${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const alice = `profile_alice_${suffix}`;
  const bob = `profile_bob_${suffix}`;
  const paths = [`usersv2/${alice}`, `usersv2/${bob}`, `profiles/${alice}`, `profiles/${bob}`];
  try {
    await Promise.all([
      db.doc(`usersv2/${alice}`).set({name: "Alice", email: "private@example.com", coins: 10}),
      db.doc(`usersv2/${bob}`).set({name: "Bob", email: "bob@example.com"}),
    ]);
    await Promise.all([syncPublicProfile(alice), syncPublicProfile(bob)]);
    assert.equal("email" in ((await db.doc(`profiles/${alice}`).get()).data() ?? {}), false);

    const call = (following: boolean) => setFollow.run({
      auth: {uid: alice}, data: {targetUid: bob, following},
    } as Parameters<typeof setFollow.run>[0]);
    await Promise.all(Array.from({length: 8}, () => call(true)));
    assert.equal((await db.doc(`profiles/${bob}`).get()).data()?.followerCount, 1);

    await db.doc(`usersv2/${bob}/blockedUsers/${alice}`).set({blockedUid: alice});
    await assert.rejects(() => applyFollowEdge({followerUid: alice, targetUid: bob, follow: true}), {code: "failed-precondition"});
    await Promise.all(Array.from({length: 4}, () => call(false)));
    assert.equal((await db.doc(`profiles/${bob}`).get()).data()?.followerCount, 0);
  } finally {
    await Promise.all(paths.map((path) => db.recursiveDelete(db.doc(path))));
    await db.recursiveDelete(db.doc(`usersv2/${bob}/blockedUsers/${alice}`));
  }
});
