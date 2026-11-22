'use strict';
// Run after the buyer unlocked "Neon rain" in the app. Prints both balances and the ledger, then retries the purchase
// through the real unlockCreatorWall callable: once with the app's own requestId and once with a new one. Neither may
// move a coin.
const assert = require('node:assert/strict');
const {connect} = require('./local.cjs');

async function idToken(account) {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo',
    {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: `${account}@demo-prism.test`, password: 'local-prism-qa-only', returnSecureToken: true})});
  const body = await response.json();
  if (!response.ok) throw new Error(JSON.stringify(body));
  return body.idToken;
}

async function unlock(token, data) {
  const response = await fetch('http://127.0.0.1:5001/demo-prism/us-central1/unlockCreatorWall', {method: 'POST',
    headers: {'Content-Type': 'application/json', Authorization: `Bearer ${token}`}, body: JSON.stringify({data})});
  const body = await response.json();
  if (!response.ok) throw new Error(JSON.stringify(body));
  return body.result;
}

async function snapshot(db) {
  const [ava, ben, ledger, marker, sales, wall] = await Promise.all([
    db.doc('usersv2/qa-stats-creator').get(), db.doc('usersv2/qa-stats-other').get(),
    db.collection('coinTransactions').where('wallId', '==', 'qa-creator').get(),
    db.doc('usersv2/qa-stats-other/creatorWallUnlocks/qa-creator').get(), db.doc('creatorSales/qa-stats-creator').get(),
    db.doc('walls/qa-creator').get(),
  ]);
  return {price: wall.data().creatorPrice, ava: ava.data().coins, ben: ben.data().coins,
    ledger: ledger.docs.map((doc) => ({id: doc.id, userId: doc.data().userId, action: doc.data().action,
      delta: doc.data().delta, balanceBefore: doc.data().balanceBefore, balanceAfter: doc.data().balanceAfter})),
    marker: marker.exists, sales: sales.data() ? {count: sales.data().count, coins: sales.data().coins} : null};
}

async function main() {
  const {admin, db} = connect();
  const before = await snapshot(db);
  console.log('After the in-app unlock:', JSON.stringify(before, null, 2));
  const price = before.price;
  const share = Math.floor(price * 70 / 100);
  const buy = before.ledger.find((row) => row.action === 'creatorWallUnlock');
  const sale = before.ledger.find((row) => row.action === 'creatorWallSale');
  assert.ok(buy && sale && before.marker, 'the app unlock is missing');
  assert.equal(before.ledger.length, 2);
  assert.equal(buy.delta, -price);
  assert.equal(sale.delta, share);
  assert.equal(before.ben, buy.balanceAfter);
  assert.equal(before.ava, sale.balanceAfter);

  const token = await idToken('other');
  const requestId = buy.id.replace(/^ctx_cwbuy_[^_]+_/, '');
  const replay = await unlock(token, {wallId: 'qa-creator', expectedPrice: price, requestId});
  const fresh = await unlock(token, {wallId: 'qa-creator', expectedPrice: price, requestId: 'qa-retry-0001'});
  console.log('Retry with the app requestId:', JSON.stringify(replay));
  console.log('Retry with a new requestId:', JSON.stringify(fresh));
  const after = await snapshot(db);
  assert.equal(replay.success, true);
  assert.equal(fresh.reason, 'already_unlocked');
  assert.deepEqual({ava: after.ava, ben: after.ben, ledger: after.ledger.length, sales: after.sales},
    {ava: before.ava, ben: before.ben, ledger: 2, sales: before.sales});
  console.log(`PASS: Ben paid ${price} once, Ava got ${share}, Prism kept ${price - share}. Both retries moved no coins.`);
  await admin.app().delete();
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
