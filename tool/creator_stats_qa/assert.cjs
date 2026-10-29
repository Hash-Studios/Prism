'use strict';
const assert = require('node:assert/strict');
const {connect, callable, token} = require('./local.cjs');
async function main() {
  const {admin, db, history: h, backend} = connect();
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
  const source = db.doc(`wallpaper_stats_daily/QA-OTHER_${day}_qa`);
  const previous = (await source.get()).data()?.views ?? 0;
  const delta = 11;
  await source.set({wallId: 'QA-OTHER', day, views: previous + delta, favs: 0, sets: 0, downloads: 0, shares: 0});
  // The real trigger may race these direct retries. All use the same real emulator transaction.
  await Promise.all(Array.from({length: 4}, () => h.projectDailyStats(source.path, now)));
  const projected = (await ref.get()).data();
  const week = h.isoWeek(now);
  assert.equal(projected.weeks[week].views, before.weeks[week].views + delta);
  await h.projectDailyStats(source.path, now);
  assert.deepEqual((await ref.get()).data(), projected);
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
    'creatorStatsFolderMarkers', 'creatorStatsRemixMarkers', 'creatorStatsWeeklyMarkers']) {
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
  }
  console.log('PASS: authenticated callable, isolation, eight weeks, empty account, daily/folder concurrent retries, inbox dedupe, six private collection rules.');
  await admin.app().delete();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
