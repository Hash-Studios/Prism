'use strict';
const assert = require('node:assert/strict');
const {connect, callable, token} = require('./local.cjs');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitForQueue(ref, timeoutMs = 20000) {
  const until = Date.now() + timeoutMs;
  while (Date.now() < until) {
    const snap = await ref.get();
    if (snap.exists) return snap;
    await pause(100);
  }
  throw new Error(`Timed out waiting for real daily enqueue: ${ref.path}`);
}
async function main() {
  const {admin, db, history: h, backend, daily} = connect();
  const now = Date.now();
  const windows = h.weekWindows(now);
  const results = await Promise.all(['creator', 'other', 'empty'].map(account => callable(account)));
  for (const [i, result] of results.entries()) {
    assert.equal(result.schemaVersion, 1);
    assert.equal(result.timezone, 'UTC');
    assert.equal(result.approvedWallCount, i === 2 ? 0 : 1);
    assert.deepEqual(result.weeks.map(({week, start, endExclusive}) => ({week, start, endExclusive})), windows);
    assert.deepEqual(result.walls.map(w => w.wallId), i === 2 ? [] : [`qa-${i === 0 ? 'creator' : 'other'}`]);
    if (i === 2) assert.ok(Object.values(result.totals).every(value => value === 0));
    else {
      assert.equal(result.totals.views, 12000 * (i + 1));
      assert.equal(result.walls[0].weeks.length, 8);
      for (const week of result.weeks) for (const metric of h.METRICS) assert.ok(Number.isSafeInteger(week.metrics[metric]));
    }
  }
  await assert.rejects(callable('creator', {uid: 'qa-stats-other'}));
  const unauth = await fetch('http://127.0.0.1:5001/demo-prism/us-central1/getCreatorStats', {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{"data":{}}',
  });
  assert.equal(unauth.status, 401);
  const wall = await db.doc('walls/qa-other').get();
  const ref = h.historyRef(wall);
  const before = (await ref.get()).data();
  const day = new Date(now).toISOString().slice(0, 10).replaceAll('-', '');
  const week = h.isoWeek(now);
  const source = db.doc(`wallpaper_stats_daily/QA-OTHER_${day}_qa`);
  const previous = (await source.get()).data()?.views ?? 0;
  const delta = 11;
  await source.set({wallId: 'QA-OTHER', day, views: previous + delta, favs: 0, sets: 0, downloads: 0, shares: 0});
  const queued = await waitForQueue(db.collection('creatorStatsDailyQueue').doc(
    h.hash(`${source.path}:${h.incarnation(await source.get())}`)));
  const sourceSnapshot = await source.get();
  assert.equal(queued.data().counters.views, previous + delta);
  const queueOnly = (await ref.get()).data();
  assert.deepEqual(queueOnly, before, 'trigger enqueue must not write history');
  await Promise.all([
    ...Array.from({length: 4}, () => daily.enqueueCreatorStatsDaily(sourceSnapshot, now)),
    ...Array.from({length: 4}, () => daily.processCreatorStatsDailyQueue()),
  ]);
  const projected = (await ref.get()).data();
  assert.equal(projected.weeks[week].views, before.weeks[week].views + delta);
  assert.equal((await db.collection('creatorStatsDailyQueue').doc(queued.id).get()).exists, false);
  const checkpointRef = db.doc(`creatorStatsDailyCheckpoints/${queued.id}`);
  const checkpoint = (await checkpointRef.get()).data();
  assert.equal(checkpoint.counters.views, previous + delta);
  assert.equal(checkpoint.sourcePath, source.path);
  await daily.enqueueCreatorStatsDaily(sourceSnapshot, now);
  await daily.processCreatorStatsDailyQueue();
  assert.deepEqual((await ref.get()).data(), projected, 'checkpoint replay is exactly once');

  const deletedSource = db.doc(`wallpaper_stats_daily/qa-delete-before-process-${day}`);
  await deletedSource.set({wallId: 'QA-OTHER', day, views: 13, favs: 0, sets: 0, downloads: 0, shares: 0});
  const deletedQueue = await waitForQueue(db.collection('creatorStatsDailyQueue').doc(
    h.hash(`${deletedSource.path}:${h.incarnation(await deletedSource.get())}`)));
  await deletedSource.delete();
  await daily.processCreatorStatsDailyQueue();
  assert.equal((await ref.get()).data().weeks[week].views, projected.weeks[week].views + 13);
  assert.equal((await db.collection('creatorStatsDailyQueue').doc(deletedQueue.id).get()).exists, false);

  await deletedSource.set({wallId: 'QA-OTHER', day, views: 3, favs: 0, sets: 0, downloads: 0, shares: 0});
  const recreatedQueue = await waitForQueue(db.collection('creatorStatsDailyQueue').doc(
    h.hash(`${deletedSource.path}:${h.incarnation(await deletedSource.get())}`)));
  assert.notEqual(recreatedQueue.id, deletedQueue.id);
  await daily.processCreatorStatsDailyQueue();
  assert.equal((await ref.get()).data().weeks[week].views, projected.weeks[week].views + 16);

  const approvalSource = db.doc(`wallpaper_stats_daily/qa-approval-before-process-${day}`);
  await approvalSource.set({wallId: 'QA-OTHER', day, views: 17, favs: 0, sets: 0, downloads: 0, shares: 0});
  const approvalQueue = await waitForQueue(db.collection('creatorStatsDailyQueue').doc(
    h.hash(`${approvalSource.path}:${h.incarnation(await approvalSource.get())}`)));
  await db.doc('walls/qa-other').update({review: false});
  await daily.processCreatorStatsDailyQueue();
  assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(approvalQueue.id).get()).exists, false);
  assert.equal((await db.collection('creatorStatsDailyQueue').doc(approvalQueue.id).get()).exists, false);
  await db.doc('walls/qa-other').update({review: true});
  await approvalSource.update({views: 18});
  await waitForQueue(db.collection('creatorStatsDailyQueue').doc(approvalQueue.id));
  await daily.processCreatorStatsDailyQueue();
  assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(approvalQueue.id).get()).data().counters.views, 18);
  assert.equal((await ref.get()).data().weeks[week].views, projected.weeks[week].views + 16 + 18);

  const aliasSource = db.doc(`wallpaper_stats_daily/qa-alias-before-process-${day}`);
  await aliasSource.set({wallId: 'QA-OTHER', day, views: 19, favs: 0, sets: 0, downloads: 0, shares: 0});
  const aliasQueue = await waitForQueue(db.collection('creatorStatsDailyQueue').doc(
    h.hash(`${aliasSource.path}:${h.incarnation(await aliasSource.get())}`)));
  const aliasHistoryBefore = (await ref.get()).data();
  await db.doc('walls/qa-other-alias').set({id: '  qA-oThEr ', creatorUid: 'qa-foreign', review: false});
  await daily.processCreatorStatsDailyQueue();
  assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(aliasQueue.id).get()).exists, false);
  assert.equal((await db.collection('creatorStatsDailyQueue').doc(aliasQueue.id).get()).exists, false);
  assert.deepEqual((await ref.get()).data(), aliasHistoryBefore);
  await db.doc('walls/qa-other-alias').delete();
  await aliasSource.update({views: 20});
  await waitForQueue(db.collection('creatorStatsDailyQueue').doc(aliasQueue.id));
  await daily.processCreatorStatsDailyQueue();
  assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(aliasQueue.id).get()).data().counters.views, 20);
  assert.equal((await ref.get()).data().weeks[week].views, aliasHistoryBefore.weeks[week].views + 20);
  await db.doc('folders/qa-stats').set({ownerId: 'qa-stats-creator', name: 'QA stats folder'});
  const itemRef = db.collection('folders/qa-stats/items').doc();
  await itemRef.create({ownerId: 'qa-stats-creator', provider: 'prism', id: 'QA-OTHER', wallpaperDocumentId: 'qa-other'});
  const item = await itemRef.get();
  await Promise.all(Array.from({length: 4}, () => h.countFolderCreation(item, now)));
  const added = (await ref.get()).data();
  assert.equal(added.folderAdds, projected.folderAdds + 1);
  await h.countFolderCreation(item, now);
  assert.deepEqual((await ref.get()).data(), added);
  const notification = db.doc(`notifications/creator_stats_${h.hash(`qa-stats-creator:${h.isoWeek(h.weekStart(now) - 7 * 86400000)}`)}`);
  const noticeBefore = await notification.get();
  assert.ok(noticeBefore.exists);
  assert.equal(noticeBefore.data().modifier, 'creator@demo-prism.test');
  assert.equal(noticeBefore.data().pushHandled, true);
  assert.equal(noticeBefore.data().data.route, 'creator_stats');
  const delivery = await Promise.all(Array.from({length: 4}, () => backend.deliverCreatorWeek('qa-stats-creator', now)));
  assert.deepEqual(delivery, [false, false, false, false]);
  assert.deepEqual((await notification.get()).data(), noticeBefore.data());
  const previousWeek = h.isoWeek(h.weekStart(now) - 7 * 86400000);
  const otherNotice = db.doc(`notifications/creator_stats_${h.hash(`qa-stats-other:${previousWeek}`)}`);
  const alreadyDelivered = (await otherNotice.get()).exists;
  const firstRace = await Promise.all(Array.from({length: 4}, () => backend.deliverCreatorWeek('qa-stats-other', now)));
  assert.equal(firstRace.filter(Boolean).length, alreadyDelivered ? 0 : 1);
  assert.equal((await otherNotice.get()).data().modifier, 'other@demo-prism.test');
  const auth = await token('creator');
  for (const collection of ['creatorStatsHistory', 'creatorStatsCache', 'creatorStatsDailyCheckpoints',
    'creatorStatsFolderMarkers', 'creatorStatsRemixMarkers', 'creatorStatsWeeklyMarkers',
    'creatorStatsDailyQueue', 'creatorStatsProcessorState']) {
    const probe = db.doc(`${collection}/qa-private-probe`);
    await probe.set({creatorUid: 'qa-stats-creator', ownerId: 'qa-stats-creator', uid: 'qa-stats-creator'});
    const url = `http://127.0.0.1:8080/v1/projects/demo-prism/databases/(default)/documents/${probe.path}`;
    for (const credential of [auth.idToken, null]) {
      const headers = credential ? {Authorization: `Bearer ${credential}`} : {};
      assert.equal((await fetch(url, {headers})).status, 403, `${collection} private read`);
    }
    assert.equal((await fetch(url, {method: 'PATCH', headers: {Authorization: `Bearer ${auth.idToken}`,
      'Content-Type': 'application/json'}, body: JSON.stringify({fields: {counted: {booleanValue: true}}})})).status,
    403, `${collection} server-only write`);
    await probe.delete();
  }
  console.log('PASS: authenticated callable, isolation, eight weeks, empty account, real daily enqueue and exactly-once checkpoints, concurrent processors, deleted/recreated source, approval/alias rechecks, folder retries, inbox dedupe, eight private collection rules.');
  await admin.app().delete();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
