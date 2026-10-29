'use strict';
const path = require('node:path');
const {createRequire} = require('node:module');
const requireFunctions = createRequire(path.resolve(__dirname, '../../functions/package.json'));
function connect() {
  if (process.argv[2] !== 'demo-prism' || process.argv.length !== 3) throw new Error('Expected exactly: demo-prism');
  for (const key of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']) {
    if (process.env[key] && process.env[key] !== 'demo-prism') throw new Error(`${key} must be demo-prism`);
    process.env[key] = 'demo-prism';
  }
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
  process.env.FIREBASE_CONFIG = JSON.stringify({projectId: 'demo-prism'});
  delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const admin = requireFunctions('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({projectId: 'demo-prism', credential: admin.credential.cert({projectId: 'demo-prism',
    clientEmail: 'local-only@demo-prism.iam.gserviceaccount.com',
    privateKey: require('node:crypto').generateKeyPairSync('rsa', {modulusLength: 2048,
      privateKeyEncoding: {type: 'pkcs8', format: 'pem'}, publicKeyEncoding: {type: 'spki', format: 'pem'}}).privateKey})});
  return {admin, db: admin.firestore(), backend: require('./.runtime/lib/creatorStats.js'),
    history: require('./.runtime/lib/creatorStatsHistory.js')};
}
async function token(account) {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-prism-local-only', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: `${account}@demo-prism.test`, password: 'local-prism-qa-only', returnSecureToken: true}),
  });
  const result = await response.json();
  if (!result.idToken) throw new Error(JSON.stringify(result));
  return result;
}
async function callable(account, data = {}) {
  const auth = await token(account);
  const response = await fetch('http://127.0.0.1:5001/demo-prism/us-central1/getCreatorStats', {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${auth.idToken}`},
    body: JSON.stringify({data}),
  });
  const result = await response.json();
  if (!response.ok || result.error) throw new Error(JSON.stringify(result));
  return result.result ?? result.data;
}
module.exports = {connect, token, callable, requireFunctions};
