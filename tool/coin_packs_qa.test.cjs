'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const {seed} = require('./coin_packs_qa.cjs');

function fakeDb(initialDocuments) {
  const documents = new Map(Object.entries(initialDocuments));
  const commits = [];
  const standaloneSets = [];
  const ref = (documentPath) => ({path: documentPath});
  const snapshot = (documentPath) => ({
    id: documentPath.split('/').at(-1),
    ref: ref(documentPath),
    get: (field) => documents.get(documentPath)?.[field],
  });
  const db = {
    collection: (name) => ({
      where: (field, op, value) => {
        assert.deepEqual([field, op, value], ['userId', '==', 'qa-viewer']);
        return {get: async () => ({docs: [...documents.keys()]
          .filter((documentPath) => documentPath.startsWith(`${name}/`) && documents.get(documentPath)?.[field] === value)
          .map(snapshot)})};
      },
    }),
    doc: (documentPath) => ({
      path: documentPath,
      set: async (value) => {
        standaloneSets.push({path: documentPath, value});
        documents.set(documentPath, value);
      },
      get: async () => ({get: (field) => documents.get(documentPath)?.[field]}),
    }),
    batch: () => {
      const operations = [];
      return {
        delete: (documentRef) => operations.push({type: 'delete', path: documentRef.path}),
        set: (documentRef, value) => operations.push({type: 'set', path: documentRef.path, value}),
        commit: async () => {
          commits.push(operations);
          for (const operation of operations) {
            if (operation.type === 'delete') documents.delete(operation.path);
            else documents.set(operation.path, operation.value);
          }
        },
      };
    },
  };
  return {db, documents, commits, standaloneSets};
}

test('seed resets its viewer atomically and preserves other users and non-pack records', async () => {
  const {db, documents, commits, standaloneSets} = fakeDb({
    'usersv2/qa-viewer': {coins: 320},
    'coinPackReceipts/viewer-tx': {userId: 'qa-viewer'},
    'coinPackReceipts/other-tx': {userId: 'other-user'},
    'coinTransactions/ctx_coinpack_viewer-tx': {userId: 'qa-viewer'},
    'coinTransactions/ctx_coinpack_refund_viewer-tx': {userId: 'qa-viewer'},
    'coinTransactions/ctx_coinpack_other-tx': {userId: 'other-user'},
    'coinTransactions/ctx_misc_viewer-tx': {userId: 'qa-viewer'},
    'coinPackVerifyThrottle/qa-viewer': {count: 5},
    'coinPackVerifyThrottle/other-user': {count: 7},
  });
  const admin = {auth: () => ({createUser: async () => ({uid: 'qa-viewer'})})};
  let rcState = {
    users: {'qa-viewer': [{transactionId: 'viewer-tx'}], 'other-user': [{transactionId: 'other-tx'}]},
    ledger: [
      {transactionId: 'viewer-tx', appUserId: 'qa-viewer'},
      {transactionId: 'other-tx', appUserId: 'other-user'},
    ],
  };

  await seed({admin, db, readRcState: () => rcState, writeRcState: (value) => { rcState = value; }});

  assert.equal(documents.get('usersv2/qa-viewer').coins, 50);
  assert.equal(commits.length, 1);
  assert.ok(commits[0].some((operation) => operation.type === 'set' && operation.path === 'usersv2/qa-viewer'));
  assert.deepEqual(standaloneSets.map(({path}) => path), [
    'usersv2/qa-viewer/private/session', 'profiles/qa-viewer', 'usernames/qaviewer',
  ]);
  assert.equal(documents.has('coinPackReceipts/viewer-tx'), false);
  assert.equal(documents.has('coinTransactions/ctx_coinpack_viewer-tx'), false);
  assert.equal(documents.has('coinTransactions/ctx_coinpack_refund_viewer-tx'), false);
  assert.equal(documents.has('coinPackVerifyThrottle/qa-viewer'), false);
  assert.equal(documents.has('coinPackReceipts/other-tx'), true);
  assert.equal(documents.has('coinTransactions/ctx_coinpack_other-tx'), true);
  assert.equal(documents.has('coinTransactions/ctx_misc_viewer-tx'), true);
  assert.equal(documents.has('coinPackVerifyThrottle/other-user'), true);
  assert.equal(rcState.users['qa-viewer'], undefined);
  assert.deepEqual(rcState.users['other-user'], [{transactionId: 'other-tx'}]);
  assert.deepEqual(rcState.ledger, [{transactionId: 'other-tx', appUserId: 'other-user'}]);
});
