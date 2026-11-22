#!/usr/bin/env node
'use strict';
// Coin packs local QA on top of the weekly challenge QA runtime. Commands: prepare, emulators, serve, seed, hold-on,
// hold-off, cancel-next, webhook <tx>, webhook-bad <tx>, refund <tx>, refund-unsigned <tx>, verify <tx>, ledger,
// build-ios, run-ios <udid>. Every webhook is signed with RevenueCat's HMAC header, except refund-unsigned.
//
// The real verifyCoinPurchase callable and revenueCatWebhook HTTPS function run in the Functions emulator. Their
// RevenueCat REST read (REVENUECAT_API_BASE, emulator only) goes to the relay in `serve`, which keeps the fake
// RevenueCat customer records in <root>/rc-state.json. Only RevenueCat's REST API and the store are faked. The app's
// purchase leg posts to the same relay (/rc/purchase) instead of StoreKit or Play Billing.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const https = require('node:https');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {PROJECT, load, guardEnvironment} = require('./weekly_challenge_qa/backend.cjs');

const runtime = '/tmp/prism-weekly-qa-coin-packs';
const VIEWER = 'qa-viewer';
const API_KEY = 'AIzaSy000000000000000000000000000000000';
const RC_SECRET = 'qa-rc-secret';
const WEBHOOK_AUTH = 'Bearer qa-webhook-secret';
const SIGNING_SECRET = 'qa-signing-secret';
const PRODUCTS = ['prism_coins_100', 'prism_coins_300', 'prism_coins_700', 'prism_coins_1600'];
const TRANSACTION_ID = /^[A-Za-z0-9._:-]{1,128}$/;
const file = (name) => path.join(runtime, name);
const readJson = (name, fallback) => (fs.existsSync(file(name)) ? JSON.parse(fs.readFileSync(file(name))) : fallback);
const writeJson = (name, value) => fs.writeFileSync(file(name), JSON.stringify(value, null, 2) + '\n');
const emptyRc = () => ({users: {}, ledger: []});

function guardDemoAdmin(admin, project) {
  for (const app of admin.apps) {
    if (app.options.projectId !== project) throw Error('Refusing a pre-existing non-demo Firebase Admin app');
  }
}

function validateCommandArgs(command, args) {
  if (!Object.hasOwn(commands, command)) throw Error(`Commands: ${Object.keys(commands).join(', ')}`);
  if (['webhook', 'webhook-bad', 'refund', 'refund-unsigned', 'verify'].includes(command)) {
    assert.ok(args.length === 1 && TRANSACTION_ID.test(args[0]), `Use ${command} <transactionId>`);
    return;
  }
  if (command === 'run-ios') {
    assert.ok(args.length === 1 && /^[0-9A-F-]{36}$/i.test(args[0]), 'Use run-ios <simulator udid>');
    return;
  }
  if (args.length !== 0) throw Error(`${command} does not accept arguments`);
}

function loadDemoRuntime(root = runtime) {
  const admin = require(path.join(root, 'functions/node_modules/firebase-admin'));
  guardDemoAdmin(admin, PROJECT);
  return load(root);
}

function validateIosBuildInputs(root = runtime) {
  const read = (name) => fs.readFileSync(path.join(root, name));
  const readJsonFile = (name) => JSON.parse(read(name));
  const manifest = readJsonFile('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(root));
  const defines = readJsonFile('dart-defines.json');
  assert.equal(defines.PRISM_LOCAL_QA, 'true');
  assert.ok(Object.keys(defines).every((key) =>
    ['PRISM_LOCAL_QA', 'PRISM_LOCAL_QA_USER', 'PRISM_LOCAL_QA_CERTIFICATE'].includes(key)), 'Unexpected QA build define');
  assert.ok(['viewer', 'creator', 'admin', 'guest'].includes(defines.PRISM_LOCAL_QA_USER), 'Unknown QA identity');
  const certificate = read('cert.der');
  assert.ok(certificate.length, 'Missing QA certificate');
  assert.equal(defines.PRISM_LOCAL_QA_CERTIFICATE, certificate.toString('base64'), 'QA certificate mismatch');
  const plist = cp.spawnSync('python3', ['-c',
    `import json, plistlib, sys, xml.etree.ElementTree as ET
def read(path):
    with open(path, "rb") as source:
        raw = source.read()
    for dictionary in ET.fromstring(raw).iter("dict"):
        keys = [item.text for item in dictionary if item.tag == "key"]
        if len(keys) != len(set(keys)):
            raise ValueError("Duplicate plist key")
    return plistlib.loads(raw)
print(json.dumps([read(path) for path in sys.argv[1:]]))`,
    path.join(root, 'native/GoogleService-Info.plist'), path.join(root, 'native/Info-LocalQA.plist')], {encoding: 'utf8'});
  assert.equal(plist.status, 0, 'Unable to parse synthetic iOS plists');
  const [firebase, info] = JSON.parse(plist.stdout);
  assert.deepEqual(firebase, {
    API_KEY,
    GCM_SENDER_ID: '1234567890',
    GOOGLE_APP_ID: '1:1234567890:ios:0123456789abcdef',
    PROJECT_ID: PROJECT,
    BUNDLE_ID: 'com.hash.prism',
    IS_ANALYTICS_ENABLED: false,
    IS_GCM_ENABLED: false,
    PLIST_VERSION: '1',
  }, 'Unexpected synthetic Firebase plist');
  for (const [key, value] of Object.entries({FirebaseAnalyticsCollectionEnabled: false,
    FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED: true, FirebaseMessagingAutoInitEnabled: false,
    FirebaseAppDelegateProxyEnabled: false})) {
    assert.equal(info[key], value, `Unsafe QA Info.plist setting: ${key}`);
  }
  assert.deepEqual(info.NSAppTransportSecurity, {NSAllowsLocalNetworking: true}, 'Unsafe QA network settings');
}

async function swapBuildFiles(swaps, build) {
  const installed = [];
  const errors = [];
  try {
    for (const swap of swaps) {
      swap.original = fs.existsSync(swap.target) ? fs.readFileSync(swap.target) : null;
      fs.writeFileSync(swap.target, swap.replacement);
      installed.push(swap);
    }
    await build();
  } catch (error) {
    errors.push(error);
  }
  const buildFailed = errors.length > 0;
  for (const {target, original, replacement} of installed.reverse()) {
    try {
      if (!fs.existsSync(target) || !fs.readFileSync(target).equals(replacement)) {
        throw Error(`Build input changed concurrently; refusing overwrite: ${target}`);
      }
      if (original) fs.writeFileSync(target, original);
      else fs.rmSync(target, {force: true});
    } catch (error) {
      errors.push(error);
    }
  }
  if (errors.length > (buildFailed ? 1 : 0)) {
    throw new AggregateError(errors, 'QA build or input restoration failed: ' + errors.map((error) => error.message).join('; '));
  }
  if (buildFailed) throw errors[0];
}

function weekly(command) {
  const result = cp.spawnSync('node', [path.join(__dirname, 'weekly_challenge_qa.cjs'), command, '--root', runtime],
    {stdio: 'inherit'});
  if (result.status !== 0) throw Error(`weekly_challenge_qa ${command} exited ${result.status}`);
}

async function prepare() {
  for (const name of ['coinPacks.js', 'economy.js']) {
    assert.ok(fs.existsSync(path.join(__dirname, '../functions/lib', name)), 'Run npm run build in functions first');
  }
  weekly('prepare');
  // Only the two coin pack functions. The weekly wrapper's challenge exports and triggers are not needed here.
  fs.writeFileSync(file('functions/index.cjs'), `'use strict';
if (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');
(${guardDemoAdmin.toString()})(require('firebase-admin'), 'demo-prism');
require('../backend.cjs').load(require('node:path').resolve(__dirname, '..'));
const coin = require('./lib/coinPacks.js');
exports.verifyCoinPurchase = coin.verifyCoinPurchase;
exports.revenueCatWebhook = coin.revenueCatWebhook;
`);
  // The functions read these secrets. Without local values the emulator asks Secret Manager, which this runtime blocks.
  fs.writeFileSync(file('functions/.secret.local'),
    'REVENUECAT_SECRET_KEY=qa-rc-secret\nREVENUECAT_WEBHOOK_AUTH=Bearer qa-webhook-secret\n' +
    `REVENUECAT_WEBHOOK_SIGNING_SECRET=${SIGNING_SECRET}\n`);
  // Params read by the emulator. REVENUECAT_API_BASE is honoured only when FUNCTIONS_EMULATOR is "true".
  fs.writeFileSync(file('functions/.env.local'),
    'COIN_PACKS_ALLOW_SANDBOX=true\nREVENUECAT_API_BASE=https://localhost:19375\n');
  writeJson('rc-state.json', emptyRc());
  console.log(`Prepared ${runtime}. Next: emulators, serve, seed.`);
}

async function emulators() {
  // The functions' fetch to the RevenueCat relay (REST read) trusts the runtime certificate through this variable.
  // weekly_challenge_qa.cjs passes the environment through to the Firebase CLI and its functions runtime.
  process.env.NODE_EXTRA_CA_CERTS = file('cert.pem');
  weekly('emulators');
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString()));
    req.on('error', reject);
  });
}

function sendJson(res, status, body) {
  res.writeHead(status, {'content-type': 'application/json'});
  res.end(JSON.stringify(body));
}

/** The app's purchase leg. Records the store charge first, so a hold leaves a purchase that only the webhook can grant. */
function purchase(raw, res) {
  let body = null;
  try { body = JSON.parse(raw); } catch { body = null; }
  if (typeof body?.appUserId !== 'string' || !PRODUCTS.includes(body?.productId)) {
    sendJson(res, 400, {error: 'appUserId and a known productId are required'});
    return;
  }
  if (fs.existsSync(file('cancel-next'))) {
    fs.rmSync(file('cancel-next'), {force: true});
    sendJson(res, 409, {error: 'purchase cancelled by user'});
    return;
  }
  const state = readJson('rc-state.json', emptyRc());
  const txn = {transactionId: `qa-${Date.now()}-${crypto.randomBytes(2).toString('hex')}`, productId: body.productId,
    appUserId: body.appUserId, store: 'app_store', is_sandbox: true, purchase_date: new Date().toISOString()};
  state.users[body.appUserId] = [...(state.users[body.appUserId] ?? []), txn];
  state.ledger.push(txn);
  writeJson('rc-state.json', state);
  // The store charged. The app is killed before it hears the answer.
  if (fs.existsSync(file('hold'))) return;
  sendJson(res, 200, {transactionId: txn.transactionId});
}

/** RevenueCat v1 customer record, the shape the functions read: non_subscriptions keyed by product id. */
function subscriber(state, uid) {
  const nonSubscriptions = {};
  for (const txn of state.users[uid] ?? []) {
    (nonSubscriptions[txn.productId] ??= []).push({id: `rc-${txn.transactionId}`, store_transaction_id: txn.transactionId,
      is_sandbox: true, store: txn.store, purchase_date: txn.purchase_date});
  }
  return {subscriber: {non_subscriptions: nonSubscriptions}};
}

async function serve() {
  const manifest = readJson('manifest.json');
  assert.equal(manifest.project, PROJECT);
  https.createServer({key: fs.readFileSync(file('key.pem')), cert: fs.readFileSync(file('cert.pem'))}, (req, res) => {
    readBody(req).then((raw) => {
      const route = req.url.split('?')[0];
      if (req.method === 'GET' && route === '/health') { sendJson(res, 200, manifest); return; }
      if (req.method === 'GET' && route === '/wallpaper.jpg') {
        res.setHeader('content-type', 'image/jpeg');
        res.end(fs.readFileSync(file('wallpaper.jpg')));
        return;
      }
      if (req.method === 'POST' && route === '/rc/purchase') { purchase(raw, res); return; }
      const customer = /^\/v1\/subscribers\/([^/]+)$/.exec(route);
      if (req.method === 'GET' && customer) {
        if (req.headers.authorization !== `Bearer ${RC_SECRET}`) { sendJson(res, 401, {error: 'Invalid API key'}); return; }
        sendJson(res, 200, subscriber(readJson('rc-state.json', emptyRc()), decodeURIComponent(customer[1])));
        return;
      }
      res.writeHead(404);
      res.end();
    }).catch((error) => {
      console.error(error);
      res.writeHead(502);
      res.end();
    });
  }).listen(19375, '127.0.0.1', () => console.log('Coin packs fixtures and RevenueCat relay on https://127.0.0.1:19375.'));
}

/** The viewer with 50 coins, so one 300-coin pack and one 100-coin pack can be checked against exact balances. */
async function seed(overrides = {}) {
  const {admin, db} = overrides.db ? overrides : loadDemoRuntime();
  try {
    await admin.auth().createUser({uid: VIEWER, email: `${VIEWER}@example.test`, password: 'local-demo-only-password',
      displayName: VIEWER, emailVerified: true});
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
  }
  const now = new Date().toISOString();
  const image = 'https://localhost:19375/wallpaper.jpg';
  const profile = {id: VIEWER, email: `${VIEWER}@example.test`, username: 'qaviewer', name: 'QA viewer', loggedIn: true,
    createdAt: now, lastLoginAt: now, premium: false, subscriptionTier: 'free', links: {}, followers: [], following: [],
    profilePhoto: image, coverPhoto: image, bio: 'Local QA fixture', badges: [], subPrisms: [], coins: 50, transactions: [],
    interestCategories: ['Nature'], onboardingV2: {completed: true}};
  // A balance reset without the purchase history would leave granted receipts behind, so a later refund would take
  // coins the reset already removed. Seed resets both.
  const previousRcState = overrides.readRcState ? overrides.readRcState() : readJson('rc-state.json', emptyRc());
  const rcUsers = {...previousRcState.users};
  delete rcUsers[VIEWER];
  const rcState = {...previousRcState, users: rcUsers,
    ledger: previousRcState.ledger.filter((txn) => txn.appUserId !== VIEWER)};
  if (overrides.writeRcState) overrides.writeRcState(rcState);
  else writeJson('rc-state.json', rcState);
  const receipts = await db.collection('coinPackReceipts').where('userId', '==', VIEWER).get();
  const rows = await db.collection('coinTransactions').where('userId', '==', VIEWER).get();
  const batch = db.batch();
  for (const doc of receipts.docs) batch.delete(doc.ref);
  for (const doc of rows.docs) {
    if (doc.id.startsWith('ctx_coinpack_')) batch.delete(doc.ref);
  }
  batch.delete(db.doc(`coinPackVerifyThrottle/${VIEWER}`));
  batch.set(db.doc(`usersv2/${VIEWER}`), profile);
  await batch.commit();
  await db.doc(`usersv2/${VIEWER}/private/session`).set({postAlerts: false});
  await db.doc(`profiles/${VIEWER}`).set({...profile, followersCount: 0, followingCount: 0});
  await db.doc('usernames/qaviewer').set({uid: VIEWER});
  const balance = (await db.doc(`usersv2/${VIEWER}`).get()).get('coins');
  assert.equal(balance, 50);
  console.log(`Seeded ${VIEWER}. Coins balance: ${balance}. Coin pack receipts, ledger rows and RevenueCat state cleared.`);
}

function setFlag(name, on) {
  assert.ok(fs.existsSync(runtime), 'Run prepare first');
  if (on) fs.writeFileSync(file(name), '');
  else fs.rmSync(file(name), {force: true});
  console.log(`${name} ${on ? 'set' : 'cleared'}.`);
}

/** The relay's purchase record for one transaction id. */
function rcTransaction(transactionId) {
  const txn = readJson('rc-state.json', emptyRc()).ledger.find((t) => t.transactionId === transactionId);
  assert.ok(txn, `No RevenueCat purchase ${transactionId} in rc-state.json`);
  return txn;
}

/** RevenueCat's HMAC header: t=<unix seconds>,v1=hex(HMAC-SHA256(secret, "<t>.<raw body>")). */
function signature(payload) {
  const t = Math.floor(Date.now() / 1000);
  return `t=${t},v1=${crypto.createHmac('sha256', SIGNING_SECRET).update(`${t}.${payload}`).digest('hex')}`;
}

function postWebhook(authorization, body, signed = true) {
  const payload = JSON.stringify(body);
  const headers = {'content-type': 'application/json', 'content-length': Buffer.byteLength(payload), authorization};
  if (signed) headers['x-revenuecat-webhook-signature'] = signature(payload);
  return new Promise((resolve, reject) => {
    const req = http.request({host: '127.0.0.1', port: 19373, path: `/${PROJECT}/us-central1/revenueCatWebhook`,
      method: 'POST', timeout: 70000,
      headers}, (res) => {
      res.resume();
      res.on('end', () => resolve(res.statusCode));
    });
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('webhook timeout')));
    req.end(payload);
  });
}

/** Sends one RevenueCat-shaped event to the real revenueCatWebhook function. The body only names the transaction. */
async function webhook(transactionId, type, authorization, signed = true) {
  guardEnvironment();
  const txn = rcTransaction(transactionId);
  const status = await postWebhook(authorization, {api_version: '1.0', event: {type, product_id: txn.productId,
    transaction_id: txn.transactionId, app_user_id: txn.appUserId, store: 'APP_STORE', environment: 'SANDBOX'}}, signed);
  console.log(`${type} ${transactionId}: HTTP ${status}`);
}

/** Signs in as the viewer on the Auth emulator, then calls the real verifyCoinPurchase callable. */
async function verify(transactionId) {
  guardEnvironment();
  const signIn = await fetch(`http://127.0.0.1:19371/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST', headers: {'content-type': 'application/json'}, signal: AbortSignal.timeout(30000),
    body: JSON.stringify({email: `${VIEWER}@example.test`, password: 'local-demo-only-password', returnSecureToken: true})});
  const identity = await signIn.json();
  assert.equal(identity.localId, VIEWER, 'Auth emulator sign-in failed');
  const response = await fetch(`http://127.0.0.1:19373/${PROJECT}/us-central1/verifyCoinPurchase`, {
    method: 'POST', headers: {'content-type': 'application/json', authorization: `Bearer ${identity.idToken}`},
    signal: AbortSignal.timeout(30000), body: JSON.stringify({data: {transactionId}})});
  const body = await response.json();
  console.log(`verifyCoinPurchase ${transactionId}: HTTP ${response.status}`);
  console.log(JSON.stringify(body, null, 2));
}

async function ledger() {
  const {db} = loadDemoRuntime();
  const coinTransactions = (await db.collection('coinTransactions').get()).docs
    .filter((doc) => doc.id.startsWith('ctx_coinpack_'))
    .map((doc) => ({id: doc.id, delta: doc.get('delta'), balanceAfter: doc.get('balanceAfter'), action: doc.get('action')}));
  const coinPackReceipts = (await db.collection('coinPackReceipts').get()).docs
    .map((doc) => ({id: doc.id, state: doc.get('state'), userId: doc.get('userId'), coins: doc.get('coins')}));
  const report = {coins: (await db.doc(`usersv2/${VIEWER}`).get()).get('coins'), coinTransactions, coinPackReceipts};
  writeJson('ledger.json', report);
  console.log(JSON.stringify(report, null, 2));
}

/** Runs [flutterArgs] with the synthetic iOS config swapped in, then restores the real files, also on Ctrl-C. */
async function withIosQaConfig(flutterArgs) {
  validateIosBuildInputs();
  const repo = path.resolve(__dirname, '..');
  const swaps = [['native/GoogleService-Info.plist', 'ios/Runner/GoogleService-Info.plist'],
    ['native/Info-LocalQA.plist', 'ios/Runner/Info.plist']].map(([from, to]) => {
    const target = path.join(repo, to);
    return {target, replacement: fs.readFileSync(file(from))};
  });
  // lib/main.dart imports the gitignored lib/firebase_options.dart. Local QA never reads it, so a stub is enough; the
  // script keeps a real file.
  const stub = cp.spawnSync('tool/write_firebase_options_stub.sh', [], {cwd: repo, stdio: 'inherit'});
  if (stub.status !== 0) throw Error('Could not write the lib/firebase_options.dart stub');
  // Ctrl-C goes to flutter, which exits; swapBuildFiles then restores the real files.
  const ignore = () => {};
  process.on?.('SIGINT', ignore);
  try {
    await swapBuildFiles(swaps, async () => {
      const result = cp.spawnSync('fvm', ['flutter', ...flutterArgs, '--no-pub',
        `--dart-define-from-file=${file('dart-defines.json')}`], {cwd: repo, stdio: 'inherit'});
      if (result.status !== 0 && result.signal !== 'SIGINT') throw Error(`flutter ${flutterArgs[0]} exited ${result.status}`);
    });
  } finally {
    process.off?.('SIGINT', ignore);
  }
}

const buildIos = async () => withIosQaConfig(['build', 'ios', '--debug', '--simulator']);

/** `flutter run` on one simulator, so Dart startup errors print in this terminal. */
async function runIos() {
  await withIosQaConfig(['run', '-d', process.argv[3], '--debug']);
}

const commands = {
  prepare, emulators, serve, seed, ledger, 'build-ios': buildIos, 'run-ios': runIos,
  'hold-on': () => setFlag('hold', true), 'hold-off': () => setFlag('hold', false),
  'cancel-next': () => setFlag('cancel-next', true),
  webhook: () => webhook(process.argv[3], 'NON_RENEWING_PURCHASE', WEBHOOK_AUTH),
  'webhook-bad': () => webhook(process.argv[3], 'NON_RENEWING_PURCHASE', 'Bearer wrong'),
  refund: () => webhook(process.argv[3], 'CANCELLATION', WEBHOOK_AUTH),
  'refund-unsigned': () => webhook(process.argv[3], 'CANCELLATION', WEBHOOK_AUTH, false),
  verify: () => verify(process.argv[3]),
};
const command = process.argv[2];
if (require.main === module) {
  validateCommandArgs(command, process.argv.slice(3));
  Promise.resolve(commands[command]()).catch((error) => { console.error(error.stack); process.exitCode = 1; });
}

module.exports = {seed};
