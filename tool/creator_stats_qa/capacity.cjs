'use strict';
const assert = require('node:assert/strict');
const {connect} = require('./local.cjs');
async function main() {
  const {admin, db, backend} = connect();
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
  const run = db.runTransaction.bind(db);
  db.runTransaction = (fn, options) => run(tx => {
    const attempt = attempts++;
    reads[attempt] = 0;
    const get = tx.get.bind(tx);
    tx.get = async target => {
      const result = await get(target);
      reads[attempt] += result.docs ? Math.max(1, result.size) : 1;
      return result;
    };
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
  console.log(JSON.stringify({passed: true, walls: 500, globalLimit: limit, coldAttempts, warmAttempts, raceAttempts, coldReads, warmReads,
    responseBytes: Buffer.byteLength(JSON.stringify(cold))}));
  await admin.app().delete();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
