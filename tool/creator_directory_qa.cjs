#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, PORTS, guardEnvironment} = require('./weekly_challenge_qa/backend.cjs');
const repo = path.resolve(__dirname, '..');
const guardDir = path.join(__dirname, 'weekly_challenge_qa');
const args = process.argv.slice(2);
const command = args.shift();
let runtime = '/tmp/prism-creators-qa';
while (args.length) {
  const option = args.shift();
  const value = args.shift();
  if (option === '--root' && value) runtime = path.resolve(value);
  else if (option === '--project' && value === PROJECT) continue;
  else throw Error('Use COMMAND [--root /tmp/prism-creators-qa] [--project demo-prism]; refusing other projects/options');
}
if (!runtime.startsWith('/tmp/prism-creators-qa')) throw Error('Runtime must be /tmp/prism-creators-qa*');

const DAY_MS = 24 * 60 * 60 * 1000;
const PASSWORD = 'local-demo-only-password';
const IMAGE_BASE = 'https://localhost:19375/covers/';
const FIXTURE_COUNT = 24;
const COVER_NAME = /^[A-Za-z0-9_-]+\.webp$/;
const SYNTHETIC_KEY = 'AIzaSy000000000000000000000000000000000';
const MAKER_NAMES = ['Aria Bloom', 'Kai Nakamura', 'Noor Haddad', 'Elio Santos', 'Mira Patel', 'Jonas Berg',
  'Sana Iqbal', 'Theo Laurent', 'Ivy Moreau'];
const CAST = [
  {uid: 'qa-viewer', name: 'Riya QA'},
  {uid: 'qa-friend-1', name: 'Maya Chen'},
  {uid: 'qa-friend-2', name: 'Arjun Mehta'},
  {uid: 'qa-friend-3', name: 'Lena Fischer'},
  {uid: 'qa-friend-4', name: 'Tom Okafor'},
  ...MAKER_NAMES.map((name, i) => ({uid: `qa-maker-${i + 1}`, name})),
];
const VIEWER = 'qa-viewer';
const FRIENDS = ['qa-friend-1', 'qa-friend-2', 'qa-friend-3', 'qa-friend-4'];
const FRIEND_NAMES = CAST.filter((p) => FRIENDS.includes(p.uid)).map((p) => p.name);
const MAKERS = CAST.filter((p) => p.uid.startsWith('qa-maker-')).map((p) => p.uid);
const BLOCKED = 'qa-maker-8';
const OPT_OUT = 'qa-maker-6';
const STAT_MAKERS = [2, 4, 7];
const ALLOWED_KEYS = new Set(['uid', 'name', 'username', 'profilePhoto', 'followerCount', 'walls', 'categories',
  'similar', 'rank', 'updatedAt']);
// [follower, target, minutes ago]. Viewer's own follows are ordered so friend-1 and friend-2 come first in "Followed by".
const FOLLOWS = [
  ['qa-viewer', 'qa-friend-1', 1], ['qa-viewer', 'qa-friend-2', 2], ['qa-viewer', 'qa-friend-3', 3],
  ['qa-viewer', 'qa-friend-4', 4], ['qa-viewer', 'qa-maker-1', 5],
  ['qa-friend-1', 'qa-maker-2', 60], ['qa-friend-2', 'qa-maker-2', 60], ['qa-friend-3', 'qa-maker-2', 60],
  ['qa-friend-4', 'qa-maker-2', 60],
  ['qa-friend-1', 'qa-maker-3', 60], ['qa-friend-2', 'qa-maker-3', 60],
  ['qa-friend-1', 'qa-maker-4', 60],
  ['qa-friend-1', 'qa-maker-5', 60], ['qa-friend-2', 'qa-maker-5', 60], ['qa-friend-3', 'qa-maker-5', 60],
];

function write(name, value) { fs.writeFileSync(path.join(runtime, name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n'); }
function read(name) { return JSON.parse(fs.readFileSync(path.join(runtime, name))); }
function sha256(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
function run(binary, argv, options = {}) {
  const result = cp.spawnSync(binary, argv, {stdio: 'inherit', ...options});
  if (result.error || result.status !== 0) throw result.error || Error(`${binary} exited ${result.status}`);
}
function available(port) {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => server.close(resolve));
  });
}
function coverNames() {
  return fs.readdirSync(path.join(repo, 'assets/images/covers')).filter((n) => n.endsWith('.webp')).sort().slice(0, FIXTURE_COUNT);
}
function fixtureNames() {
  const names = fs.readdirSync(path.join(runtime, 'fixtures')).sort();
  assert.equal(names.length, FIXTURE_COUNT, 'Run prepare first: 24 fixture covers are required');
  for (const name of names) assert.match(name, COVER_NAME);
  return names;
}
// Seeded wall ages in days. Makers 6 and 8 are older creators (35 to 55 days) with no activity, so the new-creator
// bonus of maker-9 (first wall 3 days old) is visible in the ranks. The rest spread over the last 20 days.
function wallAgeDays(k, w) {
  if (k === 6 || k === 8) return [55, 50, 45, 40, 35][w - 1];
  return k === 9 ? [3, 2.5, 2, 1, 0.5][w - 1] : 0.5 + ((k - 1) * 5 + (w - 1)) * 0.4;
}
function categoriesFor(k) {
  return k <= 3 ? ['Nature', 'Space'] : k <= 6 ? ['Abstract', 'Neon'] : ['Space', 'Minimal'];
}
function makerNumber(uid) { return Number(uid.split('-')[2]); }
function inbound(uid) { return FOLLOWS.filter(([, target]) => target === uid).length; }

function validateAndroid(bytes) {
  const config = JSON.parse(bytes);
  assert.equal(config.project_info?.project_id, PROJECT, 'Refusing non-demo native config');
  assert.equal(config.client?.[0]?.api_key?.[0]?.current_key, SYNTHETIC_KEY, 'Refusing non-synthetic native key');
}
function validateIos(bytes) {
  const text = bytes.toString('utf8');
  assert.ok(text.includes(`<string>${SYNTHETIC_KEY}</string>`) && text.includes(`<string>${PROJECT}</string>`),
    'Refusing non-synthetic iOS config');
}

async function preflight() {
  guardEnvironment();
  const androidConfig = path.join(repo, 'android/app/google-services.json');
  if (fs.existsSync(androidConfig)) {
    const config = JSON.parse(fs.readFileSync(androidConfig));
    if (config.project_info?.project_id !== PROJECT || config.client?.[0]?.api_key?.[0]?.current_key !== SYNTHETIC_KEY) {
      throw Error('Real Android Firebase config present. Use isolated synthetic build inputs first.');
    }
  }
  const iosConfig = path.join(repo, 'ios/Runner/GoogleService-Info.plist');
  if (fs.existsSync(iosConfig) && !fs.readFileSync(iosConfig, 'utf8').includes(`<string>${SYNTHETIC_KEY}</string>`)) {
    throw Error('Real iOS Firebase config present. Use isolated synthetic build inputs first.');
  }
  if (Number(process.versions.node.split('.')[0]) < 24) throw Error('Local QA requires Node 24 or newer.');
  console.log(`Local runtime Node ${process.versions.node}; production Functions target Node 24. Runtime parity is a separate gate.`);
  for (const port of [...PORTS, 19376, 19377, 19378, 19379]) await available(port);
  for (const file of ['functions/node_modules/firebase-admin/package.json', 'functions/lib/creatorDirectory.js',
    'functions/lib/profiles.js', 'firestore.rules', 'firestore.indexes.json', 'tool/weekly_challenge_qa/backend.cjs',
    'tool/weekly_challenge_qa/cli_network_guard.cjs', 'tool/weekly_challenge_qa/AndroidManifest.xml']) {
    if (!fs.existsSync(path.join(repo, file))) throw Error(`Missing ${file}; no install or build is performed by this helper.`);
  }
  if (coverNames().length < FIXTURE_COUNT) throw Error(`Need ${FIXTURE_COUNT} covers in assets/images/covers.`);
  for (const binary of ['firebase', 'openssl', 'java']) run(binary, binary === 'java' ? ['-version'] : binary === 'firebase' ? ['--version'] : ['version']);
  console.log('Ports free and local prerequisites found. No emulators started.');
}

async function prepare() {
  await preflight();
  fs.mkdirSync(runtime, {recursive: false}); // refuse stale or peer-owned directories
  fs.mkdirSync(path.join(runtime, 'fixtures'));
  const covers = coverNames();
  for (const name of covers) {
    assert.match(name, COVER_NAME);
    fs.copyFileSync(path.join(repo, 'assets/images/covers', name), path.join(runtime, 'fixtures', name));
  }
  fs.mkdirSync(path.join(runtime, 'functions'));
  fs.cpSync(path.join(repo, 'functions/lib'), path.join(runtime, 'functions/lib'), {recursive: true});
  fs.symlinkSync(path.join(repo, 'functions/node_modules'), path.join(runtime, 'functions/node_modules'), 'dir');
  fs.copyFileSync(path.join(guardDir, 'backend.cjs'), path.join(runtime, 'backend.cjs'));
  fs.copyFileSync(path.join(repo, 'firestore.rules'), path.join(runtime, 'firestore.rules'));
  fs.copyFileSync(path.join(repo, 'firestore.indexes.json'), path.join(runtime, 'firestore.indexes.json'));
  write('functions/package.json', {name: 'prism-local-creators-qa', private: true, main: 'index.cjs', engines: {node: '24'}});
  write('functions/index.cjs', `'use strict';\nif (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');\n` +
    `const {guardEnvironment} = require('../backend.cjs');\nguardEnvironment();\n` +
    `const fs = require('node:fs');\nconst admin = require('firebase-admin');\n` +
    `if (!admin.apps.length) admin.initializeApp({projectId: '${PROJECT}', credential: admin.credential.cert({projectId: '${PROJECT}', ` +
    `clientEmail: 'local-qa@${PROJECT}.iam.gserviceaccount.com', privateKey: fs.readFileSync(require('node:path').join(__dirname, '../key.pem'), 'utf8')})});\n` +
    `exports.getFollowedBy = require('./lib/creatorDirectory.js').getFollowedBy;\n` +
    `exports.setFollow = require('./lib/profiles.js').setFollow;\n`);
  write('firebase.json', {functions: [{source: 'functions', codebase: 'local-qa'}],
    firestore: {rules: 'firestore.rules', indexes: 'firestore.indexes.json'},
    emulators: {auth: {host: '127.0.0.1', port: 19371}, firestore: {host: '127.0.0.1', port: 19372, websocketPort: 19377},
      functions: {host: '127.0.0.1', port: 19373}, hub: {host: '127.0.0.1', port: 19374},
      eventarc: {host: '127.0.0.1', port: 19378}, tasks: {host: '127.0.0.1', port: 19379},
      ui: {enabled: false}, logging: {host: '127.0.0.1', port: 19376}, singleProjectMode: true}});
  run('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', path.join(runtime, 'key.pem'),
    '-out', path.join(runtime, 'cert.pem'), '-days', '7', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost']);
  fs.chmodSync(path.join(runtime, 'key.pem'), 0o600);
  run('openssl', ['x509', '-in', path.join(runtime, 'cert.pem'), '-outform', 'DER', '-out', path.join(runtime, 'cert.der')]);
  write('manifest.json', {project: PROJECT, runtime: fs.realpathSync(runtime),
    fixtures: covers.map((name) => ({file: name, sha256: sha256(path.join(runtime, 'fixtures', name))})),
    compiledSha256: sha256(path.join(runtime, 'functions/lib/creatorDirectory.js')),
    proof: 'ADMIN SEEDED creator directory fixtures; local backend only', nodeVersion: process.versions.node,
    productionNodeTarget: '24', preparedAt: new Date().toISOString()});
  write('dart-defines.json', {PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: 'viewer',
    PRISM_LOCAL_QA_CERTIFICATE: fs.readFileSync(path.join(runtime, 'cert.der')).toString('base64')});
  // Synthetic native configuration is an explicit build input. Never overwrite a real file.
  fs.mkdirSync(path.join(runtime, 'native'));
  write('native/google-services.json', {project_info: {project_number: '1234567890', project_id: PROJECT, storage_bucket: `${PROJECT}.appspot.com`},
    client: [{client_info: {mobilesdk_app_id: '1:1234567890:android:0123456789abcdef', android_client_info: {package_name: 'com.hash.prism'}},
      api_key: [{current_key: SYNTHETIC_KEY}]}], configuration_version: '1'});
  write('native/GoogleService-Info.plist', `<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>API_KEY</key><string>${SYNTHETIC_KEY}</string><key>GCM_SENDER_ID</key><string>1234567890</string>
<key>GOOGLE_APP_ID</key><string>1:1234567890:ios:0123456789abcdef</string><key>PROJECT_ID</key><string>${PROJECT}</string>
<key>BUNDLE_ID</key><string>com.hash.prism</string><key>IS_ANALYTICS_ENABLED</key><false/>
<key>IS_GCM_ENABLED</key><false/><key>PLIST_VERSION</key><string>1</string></dict></plist>\n`);
  run('python3', ['-c', `import plistlib,sys
from pathlib import Path
p=plistlib.loads(Path(sys.argv[1]).read_bytes())
p['FirebaseAnalyticsCollectionEnabled']=False
p['FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED']=True
p['FirebaseMessagingAutoInitEnabled']=False
p['FirebaseAppDelegateProxyEnabled']=False
p['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
Path(sys.argv[2]).write_bytes(plistlib.dumps(p))`, path.join(repo, 'ios/Runner/Info.plist'), path.join(runtime, 'native/Info-LocalQA.plist')]);
  console.log(`Prepared ${runtime}. No native repo config was changed. Start serve and Firebase in separate terminals.`);
}

async function emulators() {
  guardEnvironment();
  assert.equal(read('manifest.json').project, PROJECT);
  const config = path.join(runtime, 'cli-config');
  fs.mkdirSync(config, {recursive: true});
  run('firebase', ['emulators:start', '--project', PROJECT, '--config', 'firebase.json', '--only', 'auth,firestore,functions'], {
    cwd: runtime,
    env: {...process.env, TMPDIR: '/tmp', XDG_CONFIG_HOME: config, CI: '1', FIREBASE_CLI_DISABLE_TELEMETRY: '1', METADATA_SERVER_DETECTION: 'none',
      NODE_OPTIONS: `--require=${path.join(guardDir, 'cli_network_guard.cjs')}`},
  });
}

function checkDefines() {
  const defines = read('dart-defines.json');
  assert.equal(defines.PRISM_LOCAL_QA, 'true', 'QA build must explicitly enable isolation');
  assert.ok(['viewer', 'creator', 'guest'].includes(defines.PRISM_LOCAL_QA_USER), 'Unknown QA identity');
  assert.ok(Object.keys(defines).every((key) => ['PRISM_LOCAL_QA', 'PRISM_LOCAL_QA_USER', 'PRISM_LOCAL_QA_CERTIFICATE'].includes(key)), 'Unexpected QA build define');
  const certificate = fs.readFileSync(path.join(runtime, 'cert.der'));
  assert.equal(defines.PRISM_LOCAL_QA_CERTIFICATE, certificate.toString('base64'), 'QA certificate mismatch');
}

// Swaps each destination for its replacement, runs build(), then restores originals. `check` validates both.
function withBuildInputs(pairs, build) {
  const originals = [];
  const errors = [];
  try {
    for (const {source, destination, check} of pairs) {
      const target = path.join(repo, destination);
      const original = fs.existsSync(target) ? fs.readFileSync(target) : null;
      if (original && check) check(original);
      const replacement = fs.readFileSync(source);
      if (check) check(replacement);
      originals.push({target, original, replacement});
      fs.writeFileSync(target, replacement);
    }
    build();
  } catch (error) {
    errors.push(error);
  }
  const buildFailed = errors.length > 0;
  for (const {target, original, replacement} of originals.reverse()) {
    try {
      if (!fs.readFileSync(target).equals(replacement)) throw Error('Build input changed concurrently; refusing overwrite: ' + target);
      if (original) fs.writeFileSync(target, original);
      else fs.unlinkSync(target);
    } catch (error) {
      errors.push(error);
    }
  }
  if (errors.length > (buildFailed ? 1 : 0)) {
    throw new AggregateError(errors, 'QA build or input restoration failed: ' + errors.map((e) => e.message).join('; '));
  }
  if (buildFailed) throw errors[0];
}

async function buildApk() {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  checkDefines();
  withBuildInputs([
    {source: path.join(runtime, 'native/google-services.json'), destination: 'android/app/google-services.json', check: validateAndroid},
    {source: path.join(guardDir, 'AndroidManifest.xml'), destination: 'android/app/src/debug/AndroidManifest.xml'},
  ], () => run('fvm', ['flutter', 'build', 'apk', '--debug', '--no-pub', '--target-platform=android-x64',
    '--dart-define-from-file=' + path.join(runtime, 'dart-defines.json')],
  {cwd: repo, env: {...process.env, GRADLE_OPTS: `${process.env.GRADLE_OPTS || ''} -Dorg.gradle.workers.max=2`}}));
}

async function buildIos() {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  checkDefines();
  withBuildInputs([
    {source: path.join(runtime, 'native/GoogleService-Info.plist'), destination: 'ios/Runner/GoogleService-Info.plist', check: validateIos},
    {source: path.join(runtime, 'native/Info-LocalQA.plist'), destination: 'ios/Runner/Info.plist'},
  ], () => run('fvm', ['flutter', 'build', 'ios', '--simulator', '--debug', '--no-pub',
    '--dart-define-from-file=' + path.join(runtime, 'dart-defines.json')], {cwd: repo}));
}

async function serve() {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  await available(19375);
  const server = https.createServer({key: fs.readFileSync(path.join(runtime, 'key.pem')), cert: fs.readFileSync(path.join(runtime, 'cert.pem'))}, (req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify(manifest));
      return;
    }
    const match = req.method === 'GET' ? /^\/covers\/([A-Za-z0-9_-]+\.webp)$/.exec(req.url ?? '') : null;
    const file = match && path.join(runtime, 'fixtures', match[1]);
    if (!file || !fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
    res.setHeader('content-type', 'image/webp');
    res.end(fs.readFileSync(file));
  });
  server.listen(19375, '127.0.0.1', () => console.log('Local fixture HTTPS on 127.0.0.1:19375. Ctrl-C stops only this server.'));
}

function loadBackend() {
  guardEnvironment();
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime), 'Wrong QA runtime manifest');
  const base = path.join(runtime, 'functions');
  const admin = require(path.join(base, 'node_modules/firebase-admin'));
  if (!admin.apps.length) admin.initializeApp({projectId: PROJECT, credential: admin.credential.cert({
    projectId: PROJECT,
    clientEmail: 'local-qa@demo-prism.iam.gserviceaccount.com',
    privateKey: fs.readFileSync(path.join(runtime, 'key.pem'), 'utf8'),
  })});
  const creatorDirectory = require(path.join(base, 'lib/creatorDirectory.js'));
  const profiles = require(path.join(base, 'lib/profiles.js'));
  // Remote Config premium collections are outside the fake database. Auth disabled-user lookup stays real.
  creatorDirectory.creatorDirectoryDeps.premium = async () => [];
  return {admin, db: admin.firestore(), creatorDirectory, profiles};
}

async function seed() {
  const {admin, db, creatorDirectory, profiles} = loadBackend();
  assert.equal((await db.collection('creatorDirectory').limit(1).get()).empty, true, 'Refusing to overwrite existing creatorDirectory data');
  const fixtures = fixtureNames();
  const image = (index) => IMAGE_BASE + fixtures[index % fixtures.length];
  const stamp = admin.firestore.Timestamp.fromMillis;
  const now = Date.now();
  const today = new Date(now).toISOString().slice(0, 10).replaceAll('-', '');
  const sources = new Map();
  for (const [index, {uid, name}] of CAST.entries()) {
    const email = `${uid}@example.test`;
    const username = uid.replaceAll('-', '');
    try { await admin.auth().createUser({uid, email, password: PASSWORD, displayName: name, emailVerified: true}); }
    catch (e) {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
      assert.equal((await admin.auth().getUser(uid)).email, email);
    }
    const source = {id: uid, email, username, name, loggedIn: true, createdAt: new Date(now).toISOString(),
      lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free', links: {},
      profilePhoto: image(index), coverPhoto: image(index), bio: 'Local QA fixture', badges: [], subPrisms: [],
      coins: 0, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}};
    sources.set(uid, source);
    await db.doc(`usersv2/${uid}`).set(source);
    await db.doc(`usersv2/${uid}/private/session`).set({postAlerts: false});
    await db.doc(`usernames/${username.toLowerCase()}`).set({uid});
  }
  // Both edges, the way applyFollowEdge writes them. Counts come from these edges, never from usersv2.
  const followingCount = new Map();
  const followerCount = new Map();
  const bump = (map, uid) => map.set(uid, (map.get(uid) ?? 0) + 1);
  for (const [follower, target, minutes] of FOLLOWS) {
    const createdAt = stamp(now - minutes * 60000);
    await db.doc(`profiles/${follower}/following/${target}`).set({targetUid: target, createdAt, notify: false});
    await db.doc(`profiles/${target}/followers/${follower}`).set({followerUid: follower, createdAt, notify: false});
    bump(followingCount, follower);
    bump(followerCount, target);
  }
  for (const {uid} of CAST) {
    await db.doc(`profiles/${uid}`).set(profiles.projectedProfile(sources.get(uid), followerCount.get(uid) ?? 0, followingCount.get(uid) ?? 0));
  }
  let slot = 0;
  for (let k = 1; k <= 9; k++) {
    const uid = `qa-maker-${k}`;
    const source = sources.get(uid);
    const [main, odd] = categoriesFor(k);
    for (let w = 1; w <= 5; w++, slot++) {
      const id = `${uid}-w${w}`;
      const category = w === 5 ? odd : main;
      const createdMs = now - Math.round(wallAgeDays(k, w) * DAY_MS);
      await db.doc(`walls/${id}`).set({id, creatorUid: uid, email: `${uid}@example.test`, by: uid, uploadedBy: uid,
        userPhoto: source.profilePhoto, title: `${source.name} ${w}`, desc: 'ADMIN SEEDED creator directory fixture',
        wallpaper_thumb: image(slot), wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
        wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'],
        category, tags: [category.toLowerCase()], colors: [], review: true, rejected: false, resolution: '250x500',
        size: 'Local fixture', createdAt: stamp(createdMs), qaFixture: 'ADMIN SEEDED'});
      if (STAT_MAKERS.includes(k)) {
        const WALL = id.toUpperCase();
        await db.doc(`wallpaper_stats_daily/${today}_${WALL}`).set({wallId: WALL, day: today, favs: k * 7 + w * 3, sets: k + w});
      }
    }
  }
  await db.doc(`usersv2/${VIEWER}/blockedUsers/${BLOCKED}`).set({blockedUsername: 'qamaker8', createdAt: stamp(now)});
  const rebuilt = await creatorDirectory.rebuildCreatorDirectory(Date.now());
  write('state.json', {project: PROJECT, proof: 'ADMIN SEEDED creator directory fixtures; not device proof',
    seededAt: new Date().toISOString(), today, rebuilt,
    cast: {viewer: VIEWER, friends: FRIENDS, makers: MAKERS, blocked: BLOCKED, optOut: OPT_OUT},
    expected: {listed: MAKERS.length, hiddenFromDirectory: [VIEWER, ...FRIENDS],
      followedBy: {'qa-maker-2': 4, 'qa-maker-3': 2, 'qa-maker-6': 0}}});
  console.log(`Seeded ${CAST.length} users and ${MAKERS.length * 5} walls. Rebuilt directory: ${JSON.stringify(rebuilt)}. Run assert next.`);
}

async function callFollowedBy(db, creatorDirectory) {
  const signIn = await fetch('http://127.0.0.1:19371/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake', {
    method: 'POST', headers: {'content-type': 'application/json'}, signal: AbortSignal.timeout(30000),
    body: JSON.stringify({email: `${VIEWER}@example.test`, password: PASSWORD, returnSecureToken: true})});
  const identity = await signIn.json();
  assert.equal(identity.localId, VIEWER, 'Auth emulator sign-in failed');
  // The direct check cached this pair. Drop it so the HTTP call recomputes.
  await db.doc(`${creatorDirectory.FOLLOWED_BY_CACHE}/${VIEWER}_qa-maker-2`).delete();
  const response = await fetch(`http://127.0.0.1:19373/${PROJECT}/us-central1/getFollowedBy`, {
    method: 'POST', headers: {'content-type': 'application/json', authorization: `Bearer ${identity.idToken}`},
    signal: AbortSignal.timeout(30000), body: JSON.stringify({data: {creatorUid: 'qa-maker-2'}})});
  return {status: response.status, body: await response.json()};
}

async function evidence() {
  const {db, creatorDirectory} = loadBackend();
  const state = read('state.json');
  const checks = [];
  const check = (name, fn) => {
    try { fn(); checks.push({name, ok: true}); } catch (error) { checks.push({name, ok: false, detail: error.message}); }
  };
  const docs = Object.fromEntries((await db.collection('creatorDirectory').get()).docs.map((d) => [d.id, d.data()]));
  const ids = Object.keys(docs).sort();
  check('nine makers listed (blocked maker-8 included, viewer and friends absent)', () => assert.deepEqual(ids, [...MAKERS].sort()));
  check('every doc has only allowed keys', () => {
    for (const [id, data] of Object.entries(docs)) for (const key of Object.keys(data)) assert.ok(ALLOWED_KEYS.has(key), `${id} has ${key}`);
  });
  check('every doc has exactly 4 walls', () => {
    for (const [id, data] of Object.entries(docs)) assert.equal(data.walls.length, 4, id);
  });
  check('ranks are 1..9', () => assert.deepEqual(ids.map((id) => docs[id].rank).sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7, 8, 9]));
  // Zero activity means no daily wall stats and no inbound follows. Old enough means first wall older than 30 days.
  const zeroActivity = MAKERS.filter((uid) => !STAT_MAKERS.includes(makerNumber(uid)) && inbound(uid) === 0);
  const oldestAge = (uid) => Math.max(...[1, 2, 3, 4, 5].map((w) => wallAgeDays(makerNumber(uid), w)));
  const older = zeroActivity.filter((uid) => oldestAge(uid) > 30);
  check('new creator qa-maker-9 ranks above an older zero-activity creator', () => {
    assert.ok(older.length > 0, `no zero-activity creator older than 30 days in this seed (zero-activity: ${zeroActivity.join(', ')}); ` +
      'the 30-day new-creator bonus cannot be separated from the seed data');
    for (const uid of older) assert.ok(docs['qa-maker-9'].rank < docs[uid].rank, `qa-maker-9 not above ${uid}`);
  });
  const followedBy = {};
  for (const creator of ['qa-maker-2', 'qa-maker-3', 'qa-maker-6']) followedBy[creator] = await creatorDirectory.followedBy(VIEWER, creator);
  check('followedBy qa-maker-2: count 4 with 3 friend names', () => {
    assert.equal(followedBy['qa-maker-2'].count, 4);
    assert.equal(followedBy['qa-maker-2'].people.length, 3);
    for (const p of followedBy['qa-maker-2'].people) assert.ok(FRIEND_NAMES.includes(p.name), p.name);
  });
  check('followedBy qa-maker-3: count 2', () => assert.equal(followedBy['qa-maker-3'].count, 2));
  check('followedBy qa-maker-6: count 0', () => assert.equal(followedBy['qa-maker-6'].count, 0));
  const callable = await callFollowedBy(db, creatorDirectory);
  check('HTTP getFollowedBy(qa-maker-2) returns count 4 and only count/people', () => {
    assert.equal(callable.status, 200, JSON.stringify(callable.body.error ?? {}));
    assert.equal(callable.body.result.count, 4);
    assert.deepEqual(Object.keys(callable.body.result).sort(), ['count', 'people']);
    for (const p of callable.body.result.people) assert.deepEqual(Object.keys(p).sort(), ['name', 'photo']);
  });
  const failed = checks.filter((c) => !c.ok);
  write('evidence.json', {project: PROJECT, proof: state.proof, checkedAt: new Date().toISOString(), passed: failed.length === 0,
    checks, listed: ids.map((id) => ({uid: id, rank: docs[id].rank, followerCount: docs[id].followerCount, categories: docs[id].categories})),
    followedBy: Object.fromEntries(Object.entries(followedBy).map(([k, v]) => [k, {count: v.count, names: v.people.map((p) => p.name)}])),
    callable: {status: callable.status, count: callable.body.result?.count, names: callable.body.result?.people.map((p) => p.name)}});
  if (failed.length) throw Error(`${failed.length} check(s) failed; see evidence.json: ${failed.map((c) => c.name).join('; ')}`);
  console.log(`All ${checks.length} checks passed; evidence at ${runtime}/evidence.json. This is backend fixture evidence, not device proof.`);
}

async function optOut() {
  const {db, creatorDirectory} = loadBackend();
  await db.doc(`usersv2/${OPT_OUT}`).update({creatorDirectoryOptOut: true});
  const rebuilt = await creatorDirectory.rebuildCreatorDirectory(Date.now());
  assert.equal(rebuilt.listed, MAKERS.length - 1, 'Opt-out must leave eight listed makers');
  assert.equal((await db.doc(`creatorDirectory/${OPT_OUT}`).get()).exists, false, 'Opt-out must remove the directory doc');
  write('opt-out.json', {uid: OPT_OUT, rebuilt, checkedAt: new Date().toISOString()});
  console.log(`Opted out ${OPT_OUT}; directory doc removed. See opt-out.json.`);
}

const commands = {preflight, prepare, emulators, 'build-apk': buildApk, 'build-ios': buildIos, serve, seed, assert: evidence, 'opt-out': optOut};
if (!commands[command]) throw Error('Commands: preflight, prepare, emulators, build-apk, build-ios, serve, seed, assert, opt-out');
commands[command]().catch((error) => { console.error(error.stack); process.exitCode = 1; });
