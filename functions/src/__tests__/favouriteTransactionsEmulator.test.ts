import assert from "node:assert/strict";
import test from "node:test";
import {randomUUID} from "node:crypto";
import * as admin from "firebase-admin";
import {db} from "../common";
import {backfillFavouriteContributions} from "../backfillFavouriteContributions";
import {dayKey} from "../economy";
import {progressQuestForUser} from "../quests";
import {FAVOURITE_AGGREGATION_GATE, onFavouriteWritten} from "../wallStats";
import {writeWallCategorization} from "../wallCategorizationWrite";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
// The rollout worker scans every images collection and owns a singleton gate. Give it a private emulator project.
if (enabled) db.settings({projectId: `demo-fixture-${randomUUID().replace(/-/g, "").slice(0, 16)}`});

test.after(async () => {
  if (enabled) await db.terminate();
});

const favourite = (id: string, provider = "Prism") => ({id, provider});
const bootstrap = (maxPages = 100) => backfillFavouriteContributions({
  apply: true, epoch: "emulator-v1", favouritesFrozen: true, pageSize: 1, maxPages,
});

test("emulator: bootstrap resumes reference cursors and current favourite transactions award once", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const day = dayKey(Date.now());
  const paths = [FAVOURITE_AGGREGATION_GATE, "usersv2/a", "usersv2/b", "usersv2/live",
    "wallpaper_stats/W1", "wallpaper_stats/EMPTY", "wallpaper_stats/NEW", "wallpaper_stats/STALE",
    `wallpaper_stats_daily/${day.replace(/-/g, "")}_NEW`,
    `wallpaper_stats_daily/${day.replace(/-/g, "")}_STALE`, `questEventRate/live_${day}_favourite`];
  t.after(async () => {
    await Promise.all(paths.map((path) => db.recursiveDelete(db.doc(path))));
    const receipts = await db.collection("coinTransactions").where("userId", "==", "live").get();
    await Promise.all(receipts.docs.map((doc) => doc.ref.delete()));
  });
  // b deliberately has no parent profile; the scan must still see its subcollection.
  await Promise.all([
    db.doc("usersv2/a/images/W1").set(favourite("W1", "wall_of_the_day")),
    db.doc("usersv2/a/images/w1").set(favourite("w1")),
    db.doc("usersv2/b/images/w1").set(favourite("w1")),
    db.doc("wallpaper_stats/W1").set({favs: 99, views: 7}),
    db.doc("wallpaper_stats/EMPTY").set({favs: 4, downloads: 8}),
    db.doc("usersv2/live").set({coins: 0}),
  ]);
  assert.equal((await bootstrap(1)).phase, "scanning");
  assert.equal((await db.doc(FAVOURITE_AGGREGATION_GATE).get()).data()?.cursor, "usersv2/a/images/W1");
  // This executes orderBy(documentId()).startAfter(DocumentReference), including across absent parents.
  assert.equal((await bootstrap()).phase, "ready");
  assert.equal((await db.doc("wallpaper_stats/W1").get()).data()?.favs, 2);
  assert.equal((await db.doc("wallpaper_stats/W1").get()).data()?.views, 7);
  assert.equal((await db.doc("wallpaper_stats/EMPTY").get()).data()?.favs, 0);
  assert.equal((await db.doc("wallpaper_stats/EMPTY").get()).data()?.downloads, 8);
  assert.equal((await db.doc("usersv2/b").get()).exists, false);
  assert.equal((await db.collection("wallpaper_stats_daily").get()).empty, true);
  assert.equal((await db.collection("questEventRate").get()).empty, true);

  const sourceRef = db.doc("usersv2/live/images/new");
  const before = await sourceRef.get();
  const started = Date.now();
  await sourceRef.create(favourite("new"));
  const after = await sourceRef.get();
  assert.ok(after.createTime instanceof admin.firestore.Timestamp);
  assert.ok(after.updateTime instanceof admin.firestore.Timestamp);
  const event = {id: "current-create", time: new Date().toISOString(), params: {uid: "live", wallId: "new"},
    data: {before, after}} as unknown as Parameters<typeof onFavouriteWritten.run>[0];
  await Promise.all([onFavouriteWritten.run(event), onFavouriteWritten.run(event)]);
  const stats = db.doc("wallpaper_stats/NEW");
  const contribution = (await stats.collection("favouriteContributions").doc("live").get()).data();
  assert.equal((await stats.get()).data()?.favs, 1);
  assert.equal(contribution?.sequence, 1);
  assert.equal(contribution?.questSequence, 1);
  assert.ok(contribution?.acceptedAt instanceof admin.firestore.Timestamp);
  assert.ok(contribution.acceptedAt.toMillis() >= started);
  assert.ok(contribution.acceptedAt.toMillis() <= Date.now());
  assert.equal((await db.doc(`questEventRate/live_${day}_favourite`).get()).data()?.count, 1);
  assert.equal((await db.doc(`wallpaper_stats_daily/${day.replace(/-/g, "")}_NEW`).get()).data()?.favs, 1);
  assert.equal((await stats.collection("favouriteContributions").doc("live").collection("pendingQuests").get()).empty, true);
  const economy = (await db.doc("usersv2/live/private/economy").get()).data();
  await onFavouriteWritten.run(event);
  assert.deepEqual((await db.doc("usersv2/live/private/economy").get()).data(), economy);

  // Only the new incarnation may earn this wall's quest, even though an old delivery can reconcile its membership.
  const staleRef = db.doc("usersv2/live/images/stale");
  const missing = await staleRef.get();
  await staleRef.create(favourite("stale"));
  const oldSource = await staleRef.get();
  await staleRef.delete();
  await staleRef.create(favourite("stale"));
  const recreated = await staleRef.get();
  assert.ok(oldSource.createTime && recreated.createTime && !recreated.createTime.isEqual(oldSource.createTime));
  const staleEvent = {...event, id: "stale-create", params: {uid: "live", wallId: "stale"},
    data: {before: missing, after: oldSource}};
  await onFavouriteWritten.run(staleEvent);
  assert.equal((await db.doc("wallpaper_stats/STALE").get()).data()?.favs, 1);
  assert.equal((await db.doc(`questEventRate/live_${day}_favourite`).get()).data()?.count, 1);
  await onFavouriteWritten.run({...staleEvent, id: "recreated-current", data: {before: missing, after: recreated}});
  assert.equal((await db.doc("wallpaper_stats/STALE").get()).data()?.favs, 1);
  assert.equal((await db.doc(`questEventRate/live_${day}_favourite`).get()).data()?.count, 2);
});

test("emulator: a closed deletion barrier consumes pending recovery without recreating private state", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  const day = dayKey(Date.now());
  const user = db.doc("usersv2/closed");
  const barrier = db.doc("creatorDeletionState/closed");
  const stats = db.doc("wallpaper_stats/CLOSED");
  const rate = db.doc(`questEventRate/closed_${day}_favourite`);
  const pending = stats.collection("favouriteContributions").doc("closed").collection("pendingQuests").doc("1");
  t.after(async () => {
    await Promise.all([db.recursiveDelete(user), db.recursiveDelete(stats), barrier.delete(), rate.delete()]);
  });
  const profile = {coins: 5, xp: 0};
  await Promise.all([user.set(profile), barrier.set({closed: true}),
    pending.create({acceptedAt: admin.firestore.Timestamp.now()})]);
  assert.equal(await progressQuestForUser("closed", "favourite", "closed_CLOSED_1", Date.now(), pending), true);
  assert.equal((await pending.get()).exists, false);
  assert.equal((await user.collection("private").doc("economy").get()).exists, false);
  assert.equal((await rate.get()).exists, false);
  assert.deepEqual((await user.get()).data(), profile);
});

test("emulator: categorization commits current snapshots with server time and rejects recreated walls", {
  skip: !enabled, timeout: 120000,
}, async (t) => {
  t.mock.method(admin.remoteConfig(), "getTemplate", async () => ({
    parameters: {premiumCollections: {defaultValue: {value: "[\"premium\"]"}}},
  }));
  const ref = db.doc("walls/current-trigger");
  t.after(async () => {
    await ref.delete();
  });
  const wall = {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png", review: true};
  await ref.create(wall);
  const initial = await ref.get();
  const started = Date.now();
  assert.deepEqual(await writeWallCategorization({wallId: ref.id, initial, category: "Nature",
    colors: ["blue"], labels: ["Mountain"]}), {category: "Nature"});
  const saved = (await ref.get()).data();
  assert.equal(saved?.category, "Nature");
  assert.equal(saved?.aiCategorized, true);
  assert.deepEqual(saved?.colors, ["blue"]);
  assert.deepEqual(saved?.collections, ["community", "landscapes"]);
  assert.ok(saved?.categorizedAt instanceof admin.firestore.Timestamp);
  assert.ok(saved.categorizedAt.toMillis() >= started);
  assert.ok(saved.categorizedAt.toMillis() <= Date.now());
  await ref.delete();
  await ref.create(wall);
  assert.equal(await writeWallCategorization({wallId: ref.id, initial, category: "Space", colors: ["red"]}), null);
  assert.deepEqual((await ref.get()).data(), wall);
});
