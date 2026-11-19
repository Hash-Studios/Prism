'use strict';
// Run after seed.cjs. Turns on a 1,000-coin Creator fund, writes last week's fund events, and settles that week with
// the real backend job. `creator` qualifies and is paid; `other` gets one engaged user and does not qualify.
const {connect} = require('./local.cjs');
const DAY = 86_400_000;
const FANS = ['qa-fund-fan-1', 'qa-fund-fan-2', 'qa-fund-fan-3', 'qa-fund-fan-4'];
async function main() {
  const {admin, db} = connect();
  const events = require('./.runtime/fnlib/creatorFund/events.js');
  const load = require('./.runtime/fnlib/creatorFund/load.js');
  const settle = require('./.runtime/fnlib/creatorFund/settle.js');
  const status = require('./.runtime/fnlib/creatorFund/status.js');
  await db.doc('economyConfig/current').set({creatorFund: {pool: 1000, minDistinctUsers: 3, minPayout: 5,
    perCreatorCap: 1000, maxUserSharePercent: 50}}, {merge: true});
  // Fund actors must be 7 days old with a real provider. The Admin SDK cannot back-date an account, so import them.
  for (const uid of FANS) {
    await admin.auth().deleteUser(uid).catch((error) => {
      if (error.code !== 'auth/user-not-found') throw error;
    });
    const email = `${uid}@demo-prism.test`;
    const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/demo-prism/accounts:batchCreate', {
      method: 'POST', headers: {'Content-Type': 'application/json', Authorization: 'Bearer owner'},
      body: JSON.stringify({users: [{localId: uid, email, emailVerified: true, rawPassword: 'local-prism-qa-only',
        createdAt: String(Date.now() - 30 * DAY), providerUserInfo: [{providerId: 'password', email, rawId: email}]}]}),
    });
    if (!response.ok) throw new Error(await response.text());
    await db.doc(`usersv2/${uid}`).set({id: uid, email, name: uid, coins: 0}, {merge: true});
  }
  const week = load.previousWeek(Date.now());
  const at = load.weekRange(week).start + 2 * DAY;
  const plan = [
    ...FANS.map((uid) => ['QA-CREATOR', 'sets', uid]),
    ['QA-CREATOR', 'saves', FANS[0]], ['QA-CREATOR', 'remixes', FANS[1]], ['QA-CREATOR', 'downloads', FANS[2]],
    ['QA-CREATOR', 'sets', 'qa-stats-creator'],
    ['QA-OTHER', 'sets', FANS[0]],
  ];
  const batch = db.batch();
  for (const [wallId, metric, actor] of plan) {
    const event = events.fundEventWrite(wallId, metric, actor, at);
    batch.set(event.ref, event.data);
  }
  await batch.commit();
  const outcome = await settle.settleCreatorFundWeek(week);
  const creator = await status.creatorFundStatus('qa-stats-creator', Date.now());
  const other = await status.creatorFundStatus('qa-stats-other', Date.now());
  const ledger = await db.collection('coinTransactions').where('action', '==', 'creatorFund').get();
  console.log(JSON.stringify({week, outcome, creator, other, ledger: ledger.docs.map((doc) => ({id: doc.id,
    userId: doc.data().userId, delta: doc.data().delta}))}, null, 2));
  await admin.app().delete();
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
