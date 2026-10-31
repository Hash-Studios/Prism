'use strict';
const assert = require('node:assert/strict');
const {connect} = require('./local.cjs');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitForQueue(db, id, timeoutMs = 30000) {
  const ref = db.collection('creatorStatsDailyQueue').doc(id);
  const until = Date.now() + timeoutMs;
  while (Date.now() < until) {
    const snap = await ref.get();
    if (snap.exists) return snap;
    await pause(100);
  }
  throw new Error(`Timed out waiting for daily queue item ${id}`);
}
async function main() {
  const {admin, db, backend, history: h, daily} = connect();
  const uid = 'qa-stats-capacity';
  assert.equal((await db.collection('walls').where('creatorUid', '==', uid).limit(1).get()).empty, true,
    'Run capacity proof once per fresh dedicated emulator session.');
  await db.doc(`usersv2/${uid}`).set({email: 'capacity@demo-prism.test'});
  const batch = db.batch();
  for (let i = 0; i < 500; i++) batch.set(db.doc(`walls/qa-capacity-${i}`), {
    creatorUid: uid, review: true, id: `QA-CAPACITY-${i}`, title: `Capacity ${i}`, remixCount: 0,
  });
  await batch.commit();
  const counters = db.batch();
  for (let i = 0; i < 500; i++) counters.set(db.doc(`wallpaper_stats/QA-CAPACITY-${i}`), {views: 1});
  await counters.commit();
  let attempts = 0;
  const reads = [];
  const writes = [];
  const run = db.runTransaction.bind(db);
  db.runTransaction = (fn, options) => run(tx => {
    const attempt = attempts++;
    reads[attempt] = 0;
    writes[attempt] = 0;
    const get = tx.get.bind(tx);
    tx.get = async target => {
      const result = await get(target);
      reads[attempt] += result.docs ? Math.max(1, result.size) : 1;
      return result;
    };
    for (const method of ['set', 'create', 'update', 'delete']) {
      const write = tx[method].bind(tx);
      tx[method] = (...args) => {
        writes[attempt]++;
        return write(...args);
      };
    }
    return fn(tx);
  }, options);
  const now = Date.now();
  const cold = await backend.readCreatorStats(uid, {}, now);
  assert.equal(cold.walls.length, 500);
  assert.equal(cold.totals.views, 500);
  const coldAttempts = attempts;
  const coldReads = [...reads];
  reads.length = 0;
  attempts = 0;
  const warm = await backend.readCreatorStats(uid, {}, now + 1);
  assert.deepEqual(warm.walls, cold.walls);
  const warmAttempts = attempts;
  const warmReads = [...reads];
  reads.length = 0;
  attempts = 0;
  const races = await Promise.all(Array.from({length: 4}, () => backend.readCreatorStats(uid, {}, now + 300001)));
  assert.ok(races.every(result => result.walls.length === 500 && result.totals.views === 500));
  const raceAttempts = attempts;
  await db.doc('walls/qa-capacity-alias').set({id: '  qA-cApaCity-499 ', creatorUid: 'qa-foreign', review: false});
  assert.equal((await backend.readCreatorStats(uid, {}, now + 300002)).totals.views, null);
  await db.doc('walls/qa-capacity-499').update({review: false});
  assert.equal((await backend.readCreatorStats(uid, {}, now + 300002)).walls.length, 499);
  const existing = (await db.collection('walls').select('id').get()).size;
  const limit = 20000;
  for (let offset = 0; offset < limit - existing; offset += 500) {
    const fill = db.batch();
    for (let i = offset; i < Math.min(offset + 500, limit - existing); i++) {
      fill.set(db.doc(`walls/qa-global-${i}`), {id: `QA-GLOBAL-${i}`, creatorUid: 'qa-foreign', review: false,
        title: 'Projection must omit this payload: ' + 'x'.repeat(1000)});
    }
    await fill.commit();
  }
  assert.equal((await backend.readCreatorStats(uid, {}, now + 600003)).walls.length, 499);
  await db.doc('walls/qa-global-overflow').set({id: 'QA-OVERFLOW', creatorUid: 'qa-foreign', review: false});
  await assert.rejects(backend.readCreatorStats(uid, {}, now + 600004), error => error.code === 'resource-exhausted');

  await db.doc('walls/qa-global-overflow').delete();
  const day = new Date(now).toISOString().slice(0, 10).replaceAll('-', '');
  const sources = [];
  for (let i = 0; i < 100; i++) {
    const id = `QA-CAPACITY-${i}`;
    const source = db.doc(`wallpaper_stats_daily/qa-capacity-batch-${i}`);
    sources.push(source);
    await source.set({wallId: id, day, views: i + 1, favs: 0, sets: 0, downloads: 0, shares: 0});
  }
  const queueIds = [];
  for (let i = 0; i < sources.length; i++) {
    const snapshot = await sources[i].get();
    const key = h.hash(`${sources[i].path}:${h.incarnation(snapshot)}`);
    queueIds.push(key);
    await waitForQueue(db, key);
  }
  attempts = 0;
  reads.length = 0;
  writes.length = 0;
  await daily.processCreatorStatsDailyQueue();
  const dailyAttempts = attempts;
  const dailyReads = reads.reduce((sum, count) => sum + count, 0);
  const dailyWrites = writes.reduce((sum, count) => sum + count, 0);
  assert.equal(dailyReads, 20307, '100-item batch formula plus acquire/release and empty terminal batch');
  assert.equal(dailyWrites, 302, '100 queue deletes, 100 checkpoints, 100 histories, and lease acquire/release');
  assert.equal((await db.collection('creatorStatsDailyQueue').get()).size, 0,
    'the processor must consume a full 100-item batch at 20,000 identity rows');
  for (let i = 0; i < 100; i++) {
    const wall = await db.doc(`walls/qa-capacity-${i}`).get();
    const history = (await h.historyRef(wall).get()).data();
    assert.equal(history.weeks[h.isoWeek(now)].views, i + 1, `capacity batch contribution ${i}`);
    assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(queueIds[i]).get()).data().counters.views, i + 1);
  }

  const overflowSources = [];
  const overflowKeys = [];
  const overflowItems = [];
  for (let i = 0; i < 100; i++) {
    const source = db.doc(`wallpaper_stats_daily/qa-capacity-overflow-${i}`);
    overflowSources.push(source);
    await source.set({wallId: 'QA-CAPACITY-0', day, views: i + 1, favs: 0, sets: 0, downloads: 0, shares: 0});
    const snapshot = await source.get();
    const key = h.hash(`${source.path}:${h.incarnation(snapshot)}`);
    overflowKeys.push(key);
    overflowItems.push((await waitForQueue(db, key)).data());
  }
  for (const source of overflowSources) await source.delete();
  await db.doc('walls/qa-global-overflow').set({id: 'QA-OVERFLOW', creatorUid: 'qa-foreign', review: false});
  await daily.processCreatorStatsDailyQueue();
  for (let i = 0; i < overflowKeys.length; i++) {
    const key = overflowKeys[i];
    assert.deepEqual((await db.collection('creatorStatsDailyQueue').doc(key).get()).data(), overflowItems[i]);
    assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(key).get()).exists, false);
  }
  const processorState = await db.doc('creatorStatsProcessorState/daily').get();
  assert.ok(processorState.data().notBefore.toMillis() >= Date.now() + 14 * 60 * 1000,
    'capacity stop must set a 15-minute cooldown');
  await db.doc('walls/qa-global-overflow').delete();
  await db.doc('creatorStatsProcessorState/daily').update({notBefore: admin.firestore.Timestamp.fromMillis(Date.now() - 1)});
  await daily.processCreatorStatsDailyQueue();
  for (let i = 0; i < overflowKeys.length; i++) {
    const key = overflowKeys[i];
    assert.equal((await db.collection('creatorStatsDailyQueue').doc(key).get()).exists, false);
    assert.equal((await db.collection('creatorStatsDailyCheckpoints').doc(key).get()).data().counters.views, i + 1);
  }
  const final = (await h.historyRef(await db.doc('walls/qa-capacity-0').get()).get()).data();
  assert.equal(final.weeks[h.isoWeek(now)].views, 5051);
  await db.doc('walls/qa-global-overflow').set({id: 'QA-OVERFLOW', creatorUid: 'qa-foreign', review: false});
  assert.equal((await db.collection('walls').count().get()).data().count, limit + 1,
    'the dedicated capacity session must finish over capacity');

  console.log(JSON.stringify({passed: true, walls: 500, globalLimit: limit, coldAttempts, warmAttempts, raceAttempts, coldReads, warmReads,
    dailyAttempts, dailyReads, dailyWrites, dailyBatch: 100, identityRows: limit, overflowRetention: 100,
    cooldownRecovery: 'notBefore advanced by QA',
    responseBytes: Buffer.byteLength(JSON.stringify(cold))}));
  await admin.app().delete();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
