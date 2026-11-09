#!/usr/bin/env node
/*
 * Scheduled release local QA. ADMIN SEEDED fixtures on the demo-prism emulators only. Not device proof on its own.
 *
 * Command order:
 *   1. preflight                        checks ports and prerequisites; starts nothing
 *   2. prepare                          writes the runtime under /tmp/prism-scheduled-release-qa*
 *   3. emulators                        separate shell or background job; runs until Ctrl-C
 *   4. seed                             users creator, admin, follower; 6 live walls; 2 pending walls
 *   5. schedule [--minutes N]           creator sets releaseAt (default 20); a 5-minute try must be refused by rules
 *   6. approve                          admin writes releaseApprovedAt; admin review:true must be refused
 *   7. check-hidden                     follower query and get must not see the 2 scheduled walls
 *   8. build-apk | build-ios --user creator|admin|follower
 *   9. serve                            separate shell; fixture HTTPS on 19375
 *  10. release [--advance-minutes N]    releaseDueWalls(now + N); captures FCM sends; asserts one creator inbox doc
 *  11. check-visible                    follower query and get now see both walls
 *  12. evidence                         prints a JSON summary
 *
 * The app signs in as qa-creator-a, qa-admin or qa-viewer (lib/core/debug/local_qa_runtime.dart). The follower is
 * qa-viewer, so `build-apk --user follower` sends PRISM_LOCAL_QA_USER=viewer. FCM sends are captured, never sent.
 */
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
const BUILD_USERS = ['creator', 'admin', 'follower'];
const APP_USER = {creator: 'creator', admin: 'admin', follower: 'viewer'};
let runtime = '/tmp/prism-scheduled-release-qa';
let user = null;
let minutes = null;
let advanceMinutes = null;
const USAGE = 'Use COMMAND [--root /tmp/prism-scheduled-release-qa] [--user creator|admin|follower] [--minutes N] ' +
  '[--advance-minutes N] [--project demo-prism]; refusing other projects/options';
const whole = (value) => (/^[1-9]\d{0,5}$/.test(value ?? '') ? Number(value) : null);
while (args.length) {
  const option = args.shift();
  const value = args.shift();
  if (option === '--root' && value) runtime = path.resolve(value);
  else if (option === '--user' && BUILD_USERS.includes(value)) user = value;
  else if (option === '--minutes' && whole(value) !== null) minutes = whole(value);
  else if (option === '--advance-minutes' && whole(value) !== null) advanceMinutes = whole(value);
  else if (option === '--project' && value === PROJECT) continue;
  else throw Error(USAGE);
}
if (!/^\/tmp\/prism-scheduled-release-qa[^/]*$/.test(runtime)) throw Error('Runtime must be /tmp/prism-scheduled-release-qa*');
if (/^build-/.test(command) && !user) throw Error(`${command} needs --user creator, admin or follower`);
if (user && !/^build-/.test(command)) throw Error('--user applies only to build-apk and build-ios');
if (minutes !== null && command !== 'schedule') throw Error('--minutes applies only to schedule');
if (advanceMinutes !== null && command !== 'release') throw Error('--advance-minutes applies only to release');

const PASSWORD = 'local-demo-only-password';
// Fixtures are served under /previews/ so the functions accept them as R2 preview URLs.
const PREVIEW_BASE = 'https://localhost:19375';
const IMAGE_BASE = `${PREVIEW_BASE}/previews/`;
const FIXTURE_COUNT = 8;
const COVER_NAME = /^[A-Za-z0-9_-]+\.webp$/;
const SYNTHETIC_KEY = 'AIzaSy000000000000000000000000000000000';
const ANDROID_CONFIG = {project_info: {project_number: '1234567890', project_id: PROJECT, storage_bucket: `${PROJECT}.appspot.com`},
  client: [{client_info: {mobilesdk_app_id: '1:1234567890:android:0123456789abcdef', android_client_info: {package_name: 'com.hash.prism'}},
    api_key: [{current_key: SYNTHETIC_KEY}]}], configuration_version: '1'};
const IOS_CONFIG = `<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>API_KEY</key><string>${SYNTHETIC_KEY}</string><key>GCM_SENDER_ID</key><string>1234567890</string>
<key>GOOGLE_APP_ID</key><string>1:1234567890:ios:0123456789abcdef</string><key>PROJECT_ID</key><string>${PROJECT}</string><key>STORAGE_BUCKET</key><string>${PROJECT}.appspot.com</string>
<key>BUNDLE_ID</key><string>com.hash.prism</string><key>IS_ANALYTICS_ENABLED</key><false/>
<key>IS_GCM_ENABLED</key><false/><key>PLIST_VERSION</key><string>1</string></dict></plist>\n`;
const AUTH_URL = 'http://127.0.0.1:19371';
const FIRESTORE_URL = 'http://127.0.0.1:19372';
const DOCS = `projects/${PROJECT}/databases/(default)/documents`;
// The app hard-codes these uids for its QA identities, so the seed uses them too.
const CREATOR = 'qa-creator-a';
const ADMIN = 'qa-admin';
const FOLLOWER = 'qa-viewer';
const CREATOR_EMAIL = `${CREATOR}@example.test`;
const CAST = [
  {uid: CREATOR, name: 'Ana QA'},
  {uid: ADMIN, name: 'Mod QA'},
  {uid: FOLLOWER, name: 'Riya QA'},
];
const LIVE_COUNT = 6;
const PENDING = ['qa-release-1', 'qa-release-2'];
const TITLES = {'qa-release-1': 'Dune Set 1', 'qa-release-2': 'Dune Set 2'};
// Throwaway wall for the 5-minute refusal. The rules must refuse a release time less than 15 minutes ahead.
const BAD = 'qa-release-bad';
const DEFAULT_MINUTES = 20;
const DEFAULT_ADVANCE_MINUTES = 30;
// onWallApproved sends the release pushes. The FCM stub in functions/index.cjs captures every send.
const EXPORTS = [
  ['./lib/onWallApproved.js', ['onWallApproved']],
];

function checkedPath(file, root) {
  const relative = path.relative(root, file);
  assert.ok(relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative), 'Refusing outside path');
  for (let current = file; current !== root; current = path.dirname(current)) {
    try {
      assert.ok(!fs.lstatSync(current).isSymbolicLink(), `Refusing symlink path: ${current}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  return file;
}
function runtimeFile(name) {
  assert.ok(!fs.lstatSync(runtime).isSymbolicLink(), 'Refusing symlink runtime');
  assert.equal(fs.realpathSync(runtime), path.join(fs.realpathSync('/tmp'), path.basename(runtime)), 'Wrong runtime path');
  return checkedPath(path.resolve(runtime, name), runtime);
}
function write(name, value) { fs.writeFileSync(runtimeFile(name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n'); }
function read(name) { return JSON.parse(fs.readFileSync(runtimeFile(name))); }
// Each command adds its own result here, so `evidence` can print the whole pass.
function record(key, value) {
  const file = runtimeFile('results.json');
  const results = fs.existsSync(file) ? read('results.json') : {};
  results[key] = value;
  write('results.json', results);
}
function sha256(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
function run(binary, argv, options = {}) {
  const result = cp.spawnSync(binary, argv, {stdio: 'inherit', ...options});
  if (result.error || result.status !== 0) throw result.error || Error(`${binary} exited ${result.status}`);
}
function available(port) {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', () => reject(Error(`Port ${port} is busy. Stop the process that uses it.`)));
    server.listen(port, '127.0.0.1', () => server.close(resolve));
  });
}
function coverNames() {
  return fs.readdirSync(path.join(repo, 'assets/images/covers')).filter((n) => n.endsWith('.webp')).sort().slice(0, FIXTURE_COUNT);
}
function fixtureNames() {
  const names = fs.readdirSync(path.join(runtime, 'fixtures')).sort();
  assert.equal(names.length, FIXTURE_COUNT, 'Run prepare first: 8 fixture covers are required');
  for (const name of names) assert.match(name, COVER_NAME);
  return names;
}
const imageFor = (fixtures, index) => IMAGE_BASE + fixtures[index % fixtures.length];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function validateAndroid(bytes) {
  assert.deepEqual(JSON.parse(bytes), ANDROID_CONFIG, 'Refusing non-synthetic Android config');
}
function validateIos(bytes) {
  assert.equal(bytes.toString('utf8'), IOS_CONFIG, 'Refusing non-synthetic iOS config');
}

async function preflight() {
  guardEnvironment();
  const androidConfig = path.join(repo, 'android/app/google-services.json');
  if (fs.existsSync(androidConfig)) {
    validateAndroid(fs.readFileSync(androidConfig));
  }
  const iosConfig = path.join(repo, 'ios/Runner/GoogleService-Info.plist');
  if (fs.existsSync(iosConfig)) validateIos(fs.readFileSync(iosConfig));
  if (Number(process.versions.node.split('.')[0]) < 24) throw Error('Local QA requires Node 24 or newer.');
  console.log(`Local runtime Node ${process.versions.node}; production Functions target Node 24. Runtime parity is a separate gate.`);
  for (const port of [...PORTS, 19376, 19377, 19378, 19379]) await available(port);
  for (const file of ['functions/node_modules/firebase-admin/package.json', 'functions/lib/common.js',
    'functions/lib/wallRelease.js', 'functions/lib/onWallApproved.js', 'functions/lib/notificationHelper.js',
    'firestore.rules', 'firestore.indexes.json',
    'tool/weekly_challenge_qa/backend.cjs', 'tool/weekly_challenge_qa/cli_network_guard.cjs',
    'tool/weekly_challenge_qa/AndroidManifest.xml']) {
    if (!fs.existsSync(path.join(repo, file))) throw Error(`Missing ${file}; no install or build is performed by this helper.`);
  }
  if (coverNames().length < FIXTURE_COUNT) throw Error(`Need ${FIXTURE_COUNT} covers in assets/images/covers.`);
  const versions = {firebase: ['--version'], openssl: ['version'], java: ['-version'], python3: ['--version']};
  for (const [binary, argv] of Object.entries(versions)) run(binary, argv);
  console.log('Ports free and local prerequisites found. No emulators started.');
}

async function prepare() {
  await preflight();
  fs.mkdirSync(runtime, {recursive: false, mode: 0o700}); // refuse stale or peer-owned directories
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
  // No R2 env on purpose. With R2_PREVIEW_BASE_URL set, onWallApproved expects an ownedAssets manifest per wall and
  // skips the release push. The fixture walls have no R2 originals, so the release path runs without owned delivery.
  write('functions/package.json', {name: 'prism-local-scheduled-release-qa', private: true, main: 'index.cjs', engines: {node: '24'}});
  const exportLines = EXPORTS.flatMap(([mod, names]) => names.map((name) => `exports.${name} = require('${mod}').${name};`));
  // FCM stub: no push leaves this machine. Each admin.messaging().send() is appended to fcm-capture.jsonl.
  write('functions/index.cjs', `'use strict';\nif (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');\n` +
    `const path = require('node:path');\nconst {guardEnvironment} = require('../backend.cjs');\nguardEnvironment();\n` +
    `const fs = require('node:fs');\nconst admin = require('firebase-admin');\n` +
    `if (admin.apps.length) throw Error('Refusing preinitialized Admin apps');\n` +
    `admin.initializeApp({projectId: '${PROJECT}', credential: admin.credential.cert({projectId: '${PROJECT}', ` +
    `clientEmail: 'local-qa@${PROJECT}.iam.gserviceaccount.com', privateKey: fs.readFileSync(path.join(__dirname, '../key.pem'), 'utf8')})});\n` +
    `const captureFile = path.join(__dirname, '..', 'fcm-capture.jsonl');\nlet sequence = 0;\n` +
    `const capture = {send: async (message) => {\n  sequence += 1;\n` +
    `  fs.appendFileSync(captureFile, JSON.stringify({sequence, at: new Date().toISOString(), message}) + '\\n');\n` +
    `  return 'qa-capture-' + sequence;\n}};\n` +
    `Object.defineProperty(admin, 'messaging', {value: () => capture, configurable: true, writable: true});\n` +
    exportLines.join('\n') + '\n');
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
    compiledSha256: sha256(path.join(runtime, 'functions/lib/wallRelease.js')),
    proof: 'ADMIN SEEDED scheduled release fixtures; local backend only', nodeVersion: process.versions.node,
    productionNodeTarget: '24', preparedAt: new Date().toISOString()});
  const certificate = fs.readFileSync(path.join(runtime, 'cert.der')).toString('base64');
  for (const name of BUILD_USERS) {
    write(`dart-defines-${name}.json`, {PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: APP_USER[name], PRISM_LOCAL_QA_CERTIFICATE: certificate});
  }
  // Synthetic native configuration is an explicit build input. Never overwrite a real file.
  fs.mkdirSync(path.join(runtime, 'native'));
  write('native/google-services.json', ANDROID_CONFIG);
  write('native/GoogleService-Info.plist', IOS_CONFIG);
  run('python3', ['-c', `import plistlib,sys
from pathlib import Path
p=plistlib.loads(Path(sys.argv[1]).read_bytes())
p['FirebaseAnalyticsCollectionEnabled']=False
p['FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED']=True
p['FirebaseMessagingAutoInitEnabled']=False
p['FirebaseAppDelegateProxyEnabled']=False
p['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
Path(sys.argv[2]).write_bytes(plistlib.dumps(p))`, path.join(repo, 'ios/Runner/Info.plist'), path.join(runtime, 'native/Info-LocalQA.plist')]);
  console.log(`Prepared ${runtime}. No native repo config was changed. Start serve and emulators in separate terminals.`);
}

async function emulators() {
  guardEnvironment();
  assert.equal(read('manifest.json').project, PROJECT);
  const config = runtimeFile('cli-config');
  fs.mkdirSync(config, {recursive: true});
  const child = cp.spawn('firebase', ['emulators:start', '--project', PROJECT, '--config', 'firebase.json', '--only', 'auth,firestore,functions'], {
    cwd: runtime,
    stdio: 'inherit',
    env: {...process.env, TMPDIR: '/tmp', XDG_CONFIG_HOME: config, CI: '1', FIREBASE_CLI_DISABLE_TELEMETRY: '1', METADATA_SERVER_DETECTION: 'none',
      NODE_OPTIONS: `--require=${path.join(guardDir, 'cli_network_guard.cjs')}`},
  });
  // Ctrl-C or SIGTERM to this process stops only the emulator process it started.
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal));
  await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', (code) => {
      if (code) process.exitCode = code;
      resolve();
    });
  });
}

function checkDefines(selected) {
  const defines = read(`dart-defines-${selected}.json`);
  assert.equal(defines.PRISM_LOCAL_QA, 'true', 'QA build must explicitly enable isolation');
  assert.equal(defines.PRISM_LOCAL_QA_USER, APP_USER[selected], 'QA identity does not match --user');
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
      const target = checkedPath(path.resolve(repo, destination), repo);
      if (source.startsWith(`${runtime}${path.sep}`)) runtimeFile(path.relative(runtime, source));
      const original = fs.existsSync(target) ? fs.readFileSync(target) : null;
      if (original && check) check(original);
      const replacement = fs.readFileSync(source);
      if (check) check(replacement);
      originals.push({target, original, replacement});
      fs.writeFileSync(target, replacement);
    }
    // Ctrl-C reaches the build child too. Without a listener Node exits here and leaves the QA inputs in place.
    const keepRunning = () => {};
    process.on('SIGINT', keepRunning);
    try {
      build();
    } finally {
      process.off('SIGINT', keepRunning);
    }
  } catch (error) {
    errors.push(error);
  }
  const buildFailed = errors.length > 0;
  for (const {target, original, replacement} of originals.reverse()) {
    try {
      checkedPath(target, repo);
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

async function buildApk(selected) {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  checkDefines(selected);
  withBuildInputs([
    {source: path.join(runtime, 'native/google-services.json'), destination: 'android/app/google-services.json', check: validateAndroid},
    {source: path.join(guardDir, 'AndroidManifest.xml'), destination: 'android/app/src/debug/AndroidManifest.xml'},
  ], () => run('fvm', ['flutter', 'build', 'apk', '--debug', '--no-pub', `--target-platform=android-${process.arch === 'arm64' ? 'arm64' : 'x64'}`,
    '--dart-define-from-file=' + path.join(runtime, `dart-defines-${selected}.json`)],
  {cwd: repo, env: {...process.env, GRADLE_OPTS: `${process.env.GRADLE_OPTS || ''} -Dorg.gradle.workers.max=2`}}));
}

async function buildIos(selected) {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  checkDefines(selected);
  withBuildInputs([
    {source: path.join(runtime, 'native/GoogleService-Info.plist'), destination: 'ios/Runner/GoogleService-Info.plist', check: validateIos},
    {source: path.join(runtime, 'native/Info-LocalQA.plist'), destination: 'ios/Runner/Info.plist'},
  ], () => run('fvm', ['flutter', 'build', 'ios', '--simulator', '--debug', '--no-pub',
    '--dart-define-from-file=' + path.join(runtime, `dart-defines-${selected}.json`)], {cwd: repo}));
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
    const match = req.method === 'GET' ? /^\/(?:covers|previews)\/([A-Za-z0-9_-]+\.webp)$/.exec(req.url ?? '') : null;
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
  assert.equal(admin.apps.length, 0, 'Refusing preinitialized Admin apps');
  admin.initializeApp({projectId: PROJECT, credential: admin.credential.cert({
    projectId: PROJECT,
    clientEmail: `local-qa@${PROJECT}.iam.gserviceaccount.com`,
    privateKey: fs.readFileSync(path.join(runtime, 'key.pem'), 'utf8'),
  })});
  return {admin, db: admin.firestore(), base};
}

// Protected fields follow the base harness: the original and thumb are server-owned and the URLs are empty.
function fixtureWall(id, imageUrl, title, review, createdAt, stamp) {
  return {id, creatorUid: CREATOR, email: CREATOR_EMAIL, by: 'Ana QA', uploadedBy: CREATOR,
    userPhoto: imageUrl, title, desc: 'ADMIN SEEDED scheduled release fixture', wallpaper_thumb: imageUrl,
    wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
    wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'],
    category: 'Nature', tags: ['nature'], colors: ['blue'], review, rejected: false,
    resolution: '1080x2340', size: 'Local fixture', createdAt: stamp(createdAt), qaFixture: 'ADMIN SEEDED'};
}

// ADMIN SEEDED fixtures only. Every write here is marked qaFixture or is a fixed QA identity.
async function seed() {
  const {admin, db} = loadBackend();
  assert.equal((await db.doc(`walls/${PENDING[0]}`).get()).exists, false, 'Refusing to overwrite seeded walls; restart the emulators first');
  assert.equal((await db.doc('walls/qa-live-1').get()).exists, false, 'Refusing to overwrite seeded walls; restart the emulators first');
  const fixtures = fixtureNames();
  const image = (index) => imageFor(fixtures, index);
  const stamp = admin.firestore.Timestamp.fromMillis;
  const now = Date.now();
  for (const [index, {uid, name}] of CAST.entries()) {
    const email = `${uid}@example.test`;
    const username = uid.replaceAll('-', '');
    try { await admin.auth().createUser({uid, email, password: PASSWORD, displayName: name, emailVerified: true}); }
    catch (e) {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
      assert.equal((await admin.auth().getUser(uid)).email, email);
    }
    // isConfiguredAdmin (firestore.rules) accepts the admin custom claim on the ID token.
    if (uid === ADMIN) await admin.auth().setCustomUserClaims(uid, {admin: true});
    await db.doc(`usersv2/${uid}`).set({id: uid, email, username, name, loggedIn: true, createdAt: new Date(now).toISOString(),
      lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free', links: {},
      profilePhoto: image(index), coverPhoto: image(index), bio: 'Local QA fixture', badges: [], subPrisms: [],
      coins: 500, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}});
    await db.doc(`profiles/${uid}`).set({name, username, usernameLower: username.toLowerCase(), profilePhoto: image(index),
      bio: 'Local QA fixture', coverPhoto: image(index), followerCount: uid === CREATOR ? 1 : 0,
      followingCount: uid === FOLLOWER ? 1 : 0});
    await db.doc(`usernames/${username.toLowerCase()}`).set({uid});
  }
  // The follower follows the creator, the same edge pair applyFollowEdge writes.
  await db.doc(`profiles/${FOLLOWER}/following/${CREATOR}`).set({uid: CREATOR, createdAt: stamp(now - 86400000)});
  await db.doc(`profiles/${CREATOR}/followers/${FOLLOWER}`).set({uid: FOLLOWER, createdAt: stamp(now - 86400000), notify: false});
  const live = [];
  for (let n = 1; n <= LIVE_COUNT; n += 1) {
    const id = `qa-live-${n}`;
    live.push(id);
    await db.doc(`walls/${id}`).set({...fixtureWall(id, image(n - 1), `Live wall ${n}`, true, now - (LIVE_COUNT - n + 1) * 120000, stamp),
      publishedAt: stamp(now - (LIVE_COUNT - n + 1) * 60000)});
  }
  for (const [index, id] of PENDING.entries()) {
    await db.doc(`walls/${id}`).set(fixtureWall(id, image(LIVE_COUNT + index), TITLES[id], false, now, stamp));
  }
  const state = {project: PROJECT, proof: 'ADMIN SEEDED scheduled release fixtures; local emulators; not device proof',
    seededAt: new Date(now).toISOString(), creator: {uid: CREATOR, email: CREATOR_EMAIL},
    admin: {uid: ADMIN, email: `${ADMIN}@example.test`}, follower: {uid: FOLLOWER, email: `${FOLLOWER}@example.test`},
    live, pending: PENDING, bad: BAD};
  write('state.json', state);
  record('seed', {live, pending: PENDING, creator: CREATOR, admin: ADMIN, follower: FOLLOWER});
  console.log(`Seeded ${CAST.length} users, ${live.length} live walls and ${PENDING.length} pending walls.`);
  console.log(`Pending wall ids: ${PENDING.join(', ')}`);
  console.log(`Live wall ids: ${live.join(', ')}. Next: schedule.`);
}

const idTokens = new Map();
async function idToken(uid) {
  if (!idTokens.has(uid)) {
    const response = await fetch(`${AUTH_URL}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`, {
      method: 'POST', redirect: 'error', headers: {'content-type': 'application/json'}, signal: AbortSignal.timeout(30000),
      body: JSON.stringify({email: `${uid}@example.test`, password: PASSWORD, returnSecureToken: true})});
    const identity = await response.json();
    assert.equal(identity.localId, uid, `Auth emulator sign-in failed for ${uid}: ${identity.error?.message ?? response.status}`);
    idTokens.set(uid, identity.idToken);
  }
  return idTokens.get(uid);
}
// Firestore REST as one signed-in user, so the emulator applies the rules to that user.
async function rest(uid, method, route, body) {
  const token = await idToken(uid);
  const response = await fetch(`${FIRESTORE_URL}/v1/${route}`, {
    method, redirect: 'error', signal: AbortSignal.timeout(30000),
    headers: {'content-type': 'application/json', authorization: `Bearer ${token}`},
    body: body === undefined ? undefined : JSON.stringify(body)});
  return {status: response.status, body: await response.json().catch(() => ({}))};
}
const docPath = (id) => `${DOCS}/walls/${id}`;
const stampValue = (ms) => ({timestampValue: new Date(ms).toISOString()});
const commit = (uid, write) => rest(uid, 'POST', `${DOCS}:commit`, {writes: [write]});
const iso = (value) => (value?.toDate ? value.toDate().toISOString() : null);

// Creator sets releaseAt on both pending walls through REST with the creator's ID token.
async function schedule() {
  const {admin, db} = loadBackend();
  const state = read('state.json');
  const wait = minutes ?? DEFAULT_MINUTES;
  const releaseAt = Date.now() + wait * 60000;
  const writes = [];
  for (const id of state.pending) {
    const res = await commit(CREATOR, {update: {name: docPath(id), fields: {releaseAt: stampValue(releaseAt)}},
      updateMask: {fieldPaths: ['releaseAt']}});
    assert.equal(res.status, 200, `schedule ${id} as creator: HTTP ${res.status} ${res.body.error?.message ?? ''}`);
    writes.push({id, status: res.status});
  }
  // Fallback check: 5 minutes is inside the 15-minute window, so the rules must refuse it. BAD is a throwaway wall.
  const fixtures = fixtureNames();
  await db.doc(`walls/${BAD}`).set(fixtureWall(BAD, imageFor(fixtures, 0), 'Throwaway refused wall', false,
    Date.now(), admin.firestore.Timestamp.fromMillis));
  const refused = await commit(CREATOR, {update: {name: docPath(BAD), fields: {releaseAt: stampValue(Date.now() + 5 * 60000)}},
    updateMask: {fieldPaths: ['releaseAt']}});
  assert.equal(refused.status, 403, `a 5-minute release must be refused by rules, got HTTP ${refused.status}`);
  for (const id of state.pending) {
    const data = (await db.doc(`walls/${id}`).get()).data();
    assert.equal(data.releaseAt.toMillis(), releaseAt, `${id} releaseAt must match the creator write`);
  }
  const summary = {minutes: wait, releaseAt: new Date(releaseAt).toISOString(), creatorWrites: writes,
    fiveMinuteTry: {wall: BAD, status: refused.status}};
  record('schedule', summary);
  console.log(`Creator set releaseAt ${summary.releaseAt} (+${wait} min) on ${state.pending.join(', ')}.`);
  console.log(`5-minute try on ${BAD} refused by rules with HTTP ${refused.status}.`);
}

// Admin approves for a later release: releaseApprovedAt (server time), reviewedAt, review stays false.
async function approve() {
  const {admin, db} = loadBackend();
  const state = read('state.json');
  for (const id of state.pending) {
    const data = (await db.doc(`walls/${id}`).get()).data();
    assert.ok(data?.releaseAt, `${id} has no releaseAt. Run schedule first`);
    assert.ok(data.releaseAt.toMillis() > Date.now(), `${id} release time must still be in the future`);
    const res = await commit(ADMIN, {update: {name: docPath(id), fields: {reviewedAt: stampValue(Date.now())}},
      updateMask: {fieldPaths: ['reviewedAt']},
      updateTransforms: [{fieldPath: 'releaseApprovedAt', setToServerValue: 'REQUEST_TIME'}]});
    assert.equal(res.status, 200, `approve ${id} as admin: HTTP ${res.status} ${res.body.error?.message ?? ''}`);
  }
  // The rules refuse review: true while releaseAt is in the future, also for admins.
  const early = await commit(ADMIN, {update: {name: docPath(state.pending[0]), fields: {review: {booleanValue: true}}},
    updateMask: {fieldPaths: ['review']}});
  assert.equal(early.status, 403, `admin review: true before releaseAt must be refused, got HTTP ${early.status}`);
  const approved = [];
  for (const id of state.pending) {
    const data = (await db.doc(`walls/${id}`).get()).data();
    assert.ok(data.releaseApprovedAt instanceof admin.firestore.Timestamp, `${id} must carry releaseApprovedAt`);
    assert.equal(data.review, false, `${id} must stay hidden (review false)`);
    assert.equal(data.publishedAt, undefined, `${id} must have no publishedAt yet`);
    approved.push({id, review: data.review, releaseAt: iso(data.releaseAt), releaseApprovedAt: iso(data.releaseApprovedAt)});
  }
  record('approve', {approved, adminReviewTrueBeforeReleaseAt: {status: early.status}});
  console.log(`Approved for a later release: ${state.pending.join(', ')}. Admin review: true refused with HTTP ${early.status}.`);
}

// Follower query and get. Both must hide the scheduled walls.
async function followerQuery(uid) {
  const res = await rest(uid, 'POST', `${DOCS}:runQuery`, {structuredQuery: {from: [{collectionId: 'walls'}],
    where: {fieldFilter: {field: {fieldPath: 'review'}, op: 'EQUAL', value: {booleanValue: true}}}}});
  assert.equal(res.status, 200, `walls where review == true as follower: HTTP ${res.status} ${res.body.error?.message ?? ''}`);
  return res.body.filter((row) => row.document).map((row) => row.document.name.split('/').pop()).sort();
}

async function checkHidden() {
  loadBackend();
  const state = read('state.json');
  const ids = await followerQuery(FOLLOWER);
  const leaked = state.pending.filter((id) => ids.includes(id));
  const get = await rest(FOLLOWER, 'GET', docPath(state.pending[0]));
  const verdict = {role: 'follower', query: 'walls where review == true', resultCount: ids.length,
    liveWallsSeen: state.live.filter((id) => ids.includes(id)).length, scheduledWallsSeen: leaked,
    getScheduledWall: {id: state.pending[0], status: get.status}, hidden: leaked.length === 0 && get.status === 403};
  assert.deepEqual(leaked, [], 'The follower query must not list a scheduled wall');
  assert.equal(verdict.liveWallsSeen, state.live.length, 'The follower query must still list the live walls');
  assert.equal(get.status, 403, `The follower get of a scheduled wall must be 403, got ${get.status}`);
  record('checkHidden', verdict);
  console.log(JSON.stringify(verdict, null, 2));
}

function fcmLines() {
  const file = runtimeFile('fcm-capture.jsonl');
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
}

async function creatorReleaseInbox(db) {
  const snap = await db.collection('notifications').where('modifier', '==', CREATOR_EMAIL).get();
  return snap.docs.map((doc) => ({id: doc.id, ...doc.data()})).filter((doc) => doc.data?.notification_kind === 'walls_released');
}

async function waitFor(check, what, ms = 20000) {
  for (const start = Date.now(); Date.now() - start < ms;) {
    if (await check()) return;
    await sleep(500);
  }
  throw Error(`Timed out waiting for ${what}`);
}

// Runs the release job in-process, then waits for onWallApproved (functions emulator) to finish the release push.
async function release() {
  const {db, base} = loadBackend();
  const state = read('state.json');
  const advance = advanceMinutes ?? DEFAULT_ADVANCE_MINUTES;
  const before = fcmLines().length;
  const wallRelease = require(path.join(base, 'lib/wallRelease.js'));
  const result = await wallRelease.releaseDueWalls(Date.now() + advance * 60000);
  console.log(`releaseDueWalls(now + ${advance} min): ${JSON.stringify(result)}`);
  assert.equal(result.released, state.pending.length, `expected ${state.pending.length} walls released, got ${result.released}`);
  assert.equal(result.creators, 1, `expected one creator, got ${result.creators}`);
  await waitFor(async () => {
    const snaps = await Promise.all(state.pending.map((id) => db.doc(`walls/${id}`).get()));
    const live = snaps.every((snap) => {
      const data = snap.data();
      return data?.review === true && data.releaseNotice === undefined && data.approvedNotifiedAt != null;
    });
    if (!live) return false;
    const topicSent = fcmLines().slice(before).some(({message}) => typeof message.topic === 'string');
    return topicSent && (await creatorReleaseInbox(db)).length >= 1;
  }, 'both walls live, release notice claimed, follower topic push captured and creator inbox written', 60000);
  // The topic sends run one after another after the inbox write. Let the last one finish before reading the capture.
  await sleep(5000);
  const sent = fcmLines().slice(before).map(({message}) => ({
    target: message.topic ? `topic:${message.topic}` : message.condition ? `condition:${message.condition}` : 'token',
    title: message.notification?.title ?? null,
    body: message.notification?.body ?? null,
    notificationKind: message.data?.notification_kind ?? null,
  }));
  for (const push of sent) console.log(`FCM ${push.target} | ${push.title} | ${push.body} | ${push.notificationKind}`);
  const followerPushes = sent.filter((push) => push.target.startsWith('topic:') && push.notificationKind === 'wall_live');
  assert.ok(followerPushes.length >= 1, 'the follower topic push must be captured');
  const inbox = await creatorReleaseInbox(db);
  assert.equal(inbox.length, 1, `expected exactly one creator inbox doc for the release, got ${inbox.length}`);
  const liveAfter = [];
  for (const id of state.pending) {
    const data = (await db.doc(`walls/${id}`).get()).data();
    liveAfter.push({id, review: data.review, publishedAt: iso(data.publishedAt), releaseNotice: data.releaseNotice ?? null,
      approvedNotifiedAt: iso(data.approvedNotifiedAt)});
  }
  const creatorInbox = {id: inbox[0].id, title: inbox[0].notification?.title, body: inbox[0].notification?.body,
    kind: inbox[0].data.notification_kind, wallCount: inbox[0].data.wall_count ?? null};
  record('release', {advanceMinutes: advance, released: result.released, creators: result.creators, liveAfter,
    creatorInbox, fcmSent: sent, followerTopicPushes: followerPushes.length});
  console.log(`Creator inbox: "${creatorInbox.title}" / "${creatorInbox.body}" (one doc, ${creatorInbox.id})`);
  console.log(`Follower topic pushes captured: ${followerPushes.length}`);
}

async function checkVisible() {
  loadBackend();
  const state = read('state.json');
  const ids = await followerQuery(FOLLOWER);
  const visible = state.pending.filter((id) => ids.includes(id));
  const get = await rest(FOLLOWER, 'GET', docPath(state.pending[0]));
  const verdict = {role: 'follower', query: 'walls where review == true', resultCount: ids.length,
    scheduledWallsSeen: visible, getReleasedWall: {id: state.pending[0], status: get.status},
    visible: visible.length === state.pending.length && get.status === 200};
  assert.deepEqual(visible, state.pending, 'The follower query must list both released walls');
  assert.equal(get.status, 200, `The follower get of a released wall must be 200, got ${get.status}`);
  record('checkVisible', verdict);
  console.log(JSON.stringify(verdict, null, 2));
}

async function evidence() {
  const {db} = loadBackend();
  const state = read('state.json');
  const results = fs.existsSync(runtimeFile('results.json')) ? read('results.json') : {};
  const walls = {};
  for (const id of state.pending) {
    const data = (await db.doc(`walls/${id}`).get()).data() ?? {};
    walls[id] = {title: data.title ?? null, review: data.review ?? null, releaseAt: iso(data.releaseAt),
      releaseApprovedAt: iso(data.releaseApprovedAt), publishedAt: iso(data.publishedAt),
      releaseNotice: data.releaseNotice ?? null, approvedNotifiedAt: iso(data.approvedNotifiedAt)};
  }
  console.log(JSON.stringify({
    proof: 'ADMIN SEEDED scheduled release fixtures; local emulators; not device proof',
    project: PROJECT,
    walls,
    steps: results,
  }, null, 2));
}

const commands = {
  preflight, prepare, emulators, seed, schedule, approve, 'check-hidden': checkHidden, release,
  'check-visible': checkVisible, evidence, serve, 'build-apk': () => buildApk(user), 'build-ios': () => buildIos(user),
};
if (!commands[command]) {
  throw Error('Commands: preflight, prepare, emulators, seed, schedule, approve, check-hidden, build-apk, build-ios, serve, release, check-visible, evidence');
}
commands[command]().catch((error) => { console.error(error.stack); process.exitCode = 1; });
