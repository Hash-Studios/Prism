import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {createHash, randomUUID} from "node:crypto";
import {db} from "../common";
import {onCreatorWallWritten, onCreatorFavouriteCreated} from "../creatorProgress";
import {deleteAccount} from "../deleteAccount";
import {dayKey} from "../economy";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const digest = (value: string) => createHash("sha256").update(value).digest("hex");
const uploadId = (path: string, sha: string) => `file_${digest(`creator-test-walls\0${path}\0${sha}`)}`;

async function fixture(t: TestContext) {
  const prefix = `cp_${randomUUID().replace(/-/g, "")}`;
  const creatorUid = `${prefix}_creator`;
  const memberUid = `${prefix}_member`;
  const refs = new Set<admin.firestore.DocumentReference>();
  const roots = new Set<string>();
  const users = new Map<string, admin.auth.UserRecord>();
  const oldOwner = process.env.GH_USERNAME;
  const oldRepo = process.env.GH_REPO_WALLS;
  process.env.GH_USERNAME = "hash";
  process.env.GH_REPO_WALLS = "creator-test-walls";
  t.after(async () => {
    for (const uid of roots) {
      await db.recursiveDelete(db.collection("usersv2").doc(uid));
      await db.collection("creatorDeletionState").doc(uid).delete();
      const rates = await db.collection("creatorMemberRateDaily").where("memberUid", "==", uid).get();
      await Promise.all(rates.docs.map((doc) => doc.ref.delete()));
    }
    await Promise.all([...refs].map((ref) => ref.delete()));
    if (oldOwner === undefined) delete process.env.GH_USERNAME;
    else process.env.GH_USERNAME = oldOwner;
    if (oldRepo === undefined) delete process.env.GH_REPO_WALLS;
    else process.env.GH_REPO_WALLS = oldRepo;
  });
  t.mock.method(admin.auth(), "getUser", async (uid: string) => {
    const user = users.get(uid);
    if (!user) throw Object.assign(new Error("missing"), {code: "auth/user-not-found"});
    return user;
  });
  t.mock.method(admin.auth(), "deleteUser", async (uid: string) => {
    users.delete(uid);
  });
  async function seedUser(uid: string) {
    roots.add(uid);
    users.set(uid, {uid, email: `${uid}@example.com`, disabled: false, emailVerified: true,
      providerData: [{providerId: "password"}],
      metadata: {creationTime: new Date(Date.now() - 8 * 86400000).toISOString()},
    } as admin.auth.UserRecord);
    await db.collection("usersv2").doc(uid).set({email: `${uid}@example.com`, xp: 10});
  }
  await seedUser(creatorUid); await seedUser(memberUid);
  async function seedWall(suffix = "one", owner = creatorUid) {
    const id = `${prefix}_${suffix}`;
    const ref = db.collection("walls").doc(`wall_${id}`);
    refs.add(ref); refs.add(db.collection("creatorWallCredits").doc(digest(id)));
    const path = `${id}.jpg`;
    const thumbPath = `thumb_${id}.jpg`;
    const sha = "a".repeat(40);
    const thumbSha = "b".repeat(40);
    const data = {id, review: true, wallpaper_provider: "Prism", email: `${owner}@example.com`,
      wallpaper_path: path, wallpaper_sha: sha, thumb_path: thumbPath, thumb_sha: thumbSha,
      wallpaper_url: `https://raw.githubusercontent.com/hash/creator-test-walls/main/${path}`,
      wallpaper_thumb: `https://raw.githubusercontent.com/hash/creator-test-walls/main/${thumbPath}`};
    await ref.set(data);
    for (const [path, sha] of [[data.wallpaper_path, data.wallpaper_sha], [data.thumb_path, data.thumb_sha]]) {
      const upload = db.collection("githubUploads").doc(uploadId(path, sha));
      refs.add(upload);
      await upload.set({repo: "creator-test-walls", path, sha, uid: owner});
      const intent = db.collection("githubUploadIntents").doc(`path_${digest(`creator-test-walls\0${path}`)}`);
      refs.add(intent);
      await intent.set({uid: owner, repo: "creator-test-walls", path, blobSha: sha, status: "complete",
        response: {content: {path, sha, download_url: `https://raw.githubusercontent.com/hash/creator-test-walls/main/${path}`}}});
    }
    return {id, ref, snapshot: await ref.get(), data};
  }
  async function approve(wall: Awaited<ReturnType<typeof seedWall>>) {
    return onCreatorWallWritten.run({params: {wallId: wall.ref.id}, data: {
      before: {data: () => ({review: false})}, after: wall.snapshot,
    }} as unknown as Parameters<typeof onCreatorWallWritten.run>[0]);
  }
  async function favouriteSource(wall: Awaited<ReturnType<typeof seedWall>>, member = memberUid) {
    const ref = db.collection("usersv2").doc(member).collection("images").doc(wall.id);
    await ref.set({id: wall.id, provider: "Prism"});
    return {params: {uid: member, wallId: wall.id}, data: await ref.get()} as unknown as
      Parameters<typeof onCreatorFavouriteCreated.run>[0];
  }
  async function removeAccount(uid: string) {
    return deleteAccount.run({auth: {uid, token: {auth_time: Math.floor(Date.now() / 1000)}}, data: {}} as unknown as
      Parameters<typeof deleteAccount.run>[0]);
  }
  return {prefix, creatorUid, memberUid, seedUser, seedWall, approve, favouriteSource, removeAccount, refs,
    privateRef: db.collection("usersv2").doc(creatorUid).collection("private").doc("economy")};
}

test("emulator: concurrent approval deliveries cross finite thresholds exactly once", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t);
  const walls = await Promise.all(["one", "two", "three", "four", "five"].map((suffix) => ctx.seedWall(suffix)));
  const events = [...walls, walls[0], walls[0]];
  const results = await Promise.allSettled(events.map(ctx.approve));
  // A platform retry after any contention limit must preserve exactly-once domain effects.
  for (let i = 0; i < results.length; i++) if (results[i].status === "rejected") await ctx.approve(events[i]);
  await ctx.approve(walls[0]);
  const root = (await db.collection("usersv2").doc(ctx.creatorUid).get()).data();
  const snapshot = (await ctx.privateRef.get()).data();
  assert.equal(root?.xp, 160);
  assert.equal(snapshot?.creator.approvedWalls, 5);
  assert.equal(snapshot?.rev, 5);
  assert.deepEqual(snapshot?.creator.awardedIds, ["approvedWalls_1", "approvedWalls_5"]);
});

test("emulator: concurrent favourites make a creator-wide union and one rate charge", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t);
  const walls = await Promise.all([ctx.seedWall("one"), ctx.seedWall("two")]);
  const events = await Promise.all(walls.map((wall) => ctx.favouriteSource(wall)));
  await Promise.all(events.map((event) => onCreatorFavouriteCreated.run(event)));
  await onCreatorFavouriteCreated.run(events[0]);
  const snapshot = (await ctx.privateRef.get()).data();
  assert.equal(snapshot?.creator.uniqueMembers, 1);
  assert.equal(snapshot?.creator.approvedWalls, 0);
  assert.equal((await db.collection("usersv2").doc(ctx.creatorUid).get()).data()?.xp, 35);
  assert.equal((await db.collection("creatorMemberRateDaily").doc(`${ctx.memberUid}_${dayKey(Date.now())}`).get()).data()?.count, 1);
  assert.equal((await ctx.privateRef.collection("creatorMembers").get()).size, 1);
});

test("emulator: daily relationship cap is atomic across different creators", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t);
  const other = `${ctx.prefix}_other`;
  await ctx.seedUser(other);
  const walls = await Promise.all([ctx.seedWall("one"), ctx.seedWall("two", other)]);
  const events = await Promise.all(walls.map((wall) => ctx.favouriteSource(wall)));
  const rate = db.collection("creatorMemberRateDaily").doc(`${ctx.memberUid}_${dayKey(Date.now())}`);
  await rate.set({memberUid: ctx.memberUid, day: dayKey(Date.now()), count: 19});
  await Promise.all(events.map((event) => onCreatorFavouriteCreated.run(event)));
  assert.equal((await rate.get()).data()?.count, 20);
  const recipients = await Promise.all([ctx.creatorUid, other].map((uid) => db.collection("usersv2").doc(uid).get()));
  assert.equal(recipients.reduce((sum, row) => sum + row.data()?.xp, 0), 45);
});

test("emulator: inside-transaction canonical ambiguity rejects a preflight match", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t); const wall = await ctx.seedWall();
  const runTransaction = db.runTransaction.bind(db);
  let first = true;
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    if (first) {
      first = false;
      const duplicate = db.collection("walls").doc(`${ctx.prefix}_duplicate`);
      ctx.refs.add(duplicate); await duplicate.set(wall.data);
    }
    return runTransaction(callback);
  });
  await ctx.approve(wall);
  assert.equal((await ctx.privateRef.get()).exists, false);
});

test("emulator: delete/recreate favourite incarnation rejects a delayed source", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t); const wall = await ctx.seedWall();
  const source = await ctx.favouriteSource(wall);
  assert.ok(source.data);
  const ref = source.data.ref;
  await ref.delete(); await ref.create({id: wall.id, provider: "Prism"});
  await onCreatorFavouriteCreated.run(source);
  assert.equal((await ctx.privateRef.get()).exists, false);
});

test("emulator: concurrent creator deletion closes receipts and prevents every later delivery", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t); const wall = await ctx.seedWall();
  const source = await ctx.favouriteSource(wall);
  await Promise.all([ctx.approve(wall), onCreatorFavouriteCreated.run(source), ctx.removeAccount(ctx.creatorUid)]);
  await ctx.approve(wall); await onCreatorFavouriteCreated.run(source);
  assert.equal((await ctx.privateRef.get()).exists, false);
  assert.equal((await db.collection("usersv2").doc(ctx.creatorUid).get()).data()?.deleted, true);
  assert.equal((await db.collection("creatorDeletionState").doc(ctx.creatorUid).get()).exists, true);
  const receipt = (await db.collection("creatorWallCredits").doc(digest(wall.id)).get()).data();
  if (receipt) assert.deepEqual(receipt, {closed: true, approvalCredited: true});
});

test("emulator: grants before member/creator deletion retain history and erase identifying receipts", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t); const wall = await ctx.seedWall();
  await ctx.approve(wall);
  const source = await ctx.favouriteSource(wall);
  await onCreatorFavouriteCreated.run(source);
  await ctx.removeAccount(ctx.memberUid);
  assert.equal((await ctx.privateRef.get()).data()?.creator.uniqueMembers, 1);
  assert.equal((await ctx.privateRef.collection("creatorMembers").get()).size, 0);
  assert.equal((await db.collection("usersv2").doc(ctx.creatorUid).get()).data()?.xp, 85);
  await onCreatorFavouriteCreated.run(source);
  assert.equal((await ctx.privateRef.get()).data()?.creator.uniqueMembers, 1);
  await ctx.removeAccount(ctx.creatorUid);
  assert.deepEqual((await db.collection("creatorWallCredits").doc(digest(wall.id)).get()).data(),
    {closed: true, approvalCredited: true});
  assert.equal((await ctx.privateRef.get()).exists, false);
});

test("emulator: deletion after Auth/preflight but before transaction blocks the delayed grant", {skip: !enabled, timeout: 120000}, async (t) => {
  const ctx = await fixture(t); const wall = await ctx.seedWall();
  const runTransaction = db.runTransaction.bind(db);
  let enter: () => void = () => undefined;
  let release: () => void = () => undefined;
  const entered = new Promise<void>((resolve) => {
    enter = resolve;
  });
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  t.mock.method(db, "runTransaction", async (callback: (tx: admin.firestore.Transaction) => Promise<unknown>) => {
    enter(); await gate;
    return runTransaction(callback);
  });
  const incoming = ctx.approve(wall);
  await entered;
  await ctx.removeAccount(ctx.creatorUid);
  release(); await incoming;
  assert.equal((await ctx.privateRef.get()).exists, false);
  assert.equal((await db.collection("creatorWallCredits").doc(digest(wall.id)).get()).exists, false);
});
