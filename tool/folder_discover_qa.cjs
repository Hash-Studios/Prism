#!/usr/bin/env node
/*
 * Folder discovery local QA. ADMIN SEEDED fixtures on local emulators. Not device proof.
 *
 * Command order:
 *   1. preflight                      checks ports and prerequisites; starts nothing
 *   2. prepare                        writes the runtime under /tmp/prism-folder-discover-qa*
 *   3. emulators                      separate shell; runs until Ctrl-C
 *   4. seed                           users, walls, private folders made public by setFolderPublic
 *   5. rank                           folderStatsDaily docs, rebuildFolderDiscovery, assertions
 *   6. build-ios | build-apk --user viewer|admin|creator|guest
 *   7. serve                          separate shell; fixture HTTPS on 19375
 *   8. hide                           setFolderDiscoveryHidden as admin, then assertions
 *   9. evidence                       prints a JSON summary
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
const BUILD_USERS = ['viewer', 'creator', 'admin', 'guest'];
let runtime = '/tmp/prism-folder-discover-qa';
let user = null;
while (args.length) {
  const option = args.shift();
  const value = args.shift();
  if (option === '--root' && value) runtime = path.resolve(value);
  else if (option === '--user' && BUILD_USERS.includes(value)) user = value;
  else if (option === '--project' && value === PROJECT) continue;
  else throw Error('Use COMMAND [--root /tmp/prism-folder-discover-qa] [--user viewer|creator|admin|guest] [--project demo-prism]; refusing other projects/options');
}
if (!/^\/tmp\/prism-folder-discover-qa[^/]*$/.test(runtime)) throw Error('Runtime must be /tmp/prism-folder-discover-qa*');
if (/^build-/.test(command) && !user) throw Error(`${command} needs --user viewer, creator, admin or guest`);
if (user && !/^build-/.test(command)) throw Error('--user applies only to build-apk and build-ios');

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
const FUNCTIONS_URL = 'http://127.0.0.1:19373';
// Riya signs in on the device. Ana and Mod sign in too. Bo and Neo own folders but never sign in to the app.
// The seed still gives them emulator passwords, because setFolderPublic needs an ID token for the owner.
const VIEWER = 'qa-viewer';
const CREATOR = 'qa-creator-a';
const ADMIN = 'qa-admin';
const BO = 'qa-creator-b';
const NEO = 'qa-creator-new';
const CAST = [
  {uid: VIEWER, name: 'Riya QA'},
  {uid: CREATOR, name: 'Ana QA'},
  {uid: ADMIN, name: 'Mod QA'},
  {uid: BO, name: 'Bo QA'},
  {uid: NEO, name: 'Neo QA'},
];
const OWNERS = [CREATOR, BO, NEO];
const MIN_DISCOVER_WALLS = 8;
const DAY_MS = 24 * 60 * 60 * 1000;
const EXPORTS = [
  ['./lib/folderDiscovery.js', ['setFolderDiscoveryHidden', 'recordFolderSignal']],
  ['./lib/folders.js', ['onFolderWritten', 'onFolderItemWritten']],
  ['./lib/publicFolders.js', ['setFolderPublic', 'setFolderFollow']],
  ['./lib/submitContentReport.js', ['submitContentReport']],
];
// The free gallery gate reads Remote Config, which the emulator does not have.
const PREMIUM = ['space', 'abstract', 'flat', 'mesh gradients', 'fluids'];
const wallId = (n) => `qa-discover-${n}`;
const range = (from, to) => Array.from({length: to - from + 1}, (_, i) => from + i);
// Walls 1 to 16 are approved. Walls 9 to 16 are Pastel, so Soft pastels is exactly those eight.
// Night skies needs 9 walls. Walls 1 to 8 are Nature or Dark, so wall 9 (Pastel) is its ninth. Sixteen walls
// cannot give 9 Dark/Nature walls and 8 Pastel walls with no overlap.
const WALLS = [
  {category: 'Nature', colors: ['blue']}, {category: 'Nature', colors: ['teal']},
  {category: 'Nature', colors: ['blue', 'white']}, {category: 'Nature', colors: ['green']},
  {category: 'Dark', colors: ['black']}, {category: 'Dark', colors: ['black', 'grey']},
  {category: 'Dark', colors: ['black', 'blue']}, {category: 'Dark', colors: ['grey']},
  {category: 'Pastel', colors: ['pink']}, {category: 'Pastel', colors: ['pink', 'white']},
  {category: 'Pastel', colors: ['white']}, {category: 'Pastel', colors: ['pink']},
  {category: 'Abstract', colors: ['pink', 'white']}, {category: 'Abstract', colors: ['white']},
  {category: 'Abstract', colors: ['pink']}, {category: 'Abstract', colors: ['pink', 'white']},
];
// key: the name in folders.json. walls: wall numbers. Folders may share walls; items are per folder.
const FOLDERS = [
  {key: 'night', id: 'qa-folder-night', owner: CREATOR, name: 'Night skies', walls: range(1, 9)},
  {key: 'soft', id: 'qa-folder-soft', owner: CREATOR, name: 'Soft pastels', walls: range(9, 16)},
  {key: 'third', id: 'qa-folder-third', owner: CREATOR, name: 'Third of Ana', walls: range(6, 13)},
  {key: 'abstract', id: 'qa-folder-abstract', owner: BO, name: 'Abstract shapes', walls: range(5, 14)},
  {key: 'tiny', id: 'qa-folder-tiny', owner: BO, name: 'Tiny', walls: range(1, 3)},
  {key: 'new', id: 'qa-folder-new', owner: NEO, name: 'Brand new', walls: range(1, 8)},
];
// Today's signals, written to folderStatsDaily. Missing counts are zero.
const SIGNALS = [
  {key: 'night', follows: 2, saves: 1, opens: 6},
  {key: 'soft', opens: 5},
  {key: 'third', opens: 4},
  {key: 'abstract', follows: 1, opens: 3},
  {key: 'tiny', opens: 9},
];
const FAVOURITE_WALLS = [9, 10, 11, 12];

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
    'functions/lib/folderDiscovery.js', 'functions/lib/folders.js', 'functions/lib/publicFolders.js',
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
  write('functions/.env', `R2_PREVIEW_BASE_URL=${PREVIEW_BASE}\n`);
  write('functions/package.json', {name: 'prism-local-folder-discover-qa', private: true, main: 'index.cjs', engines: {node: '24'}});
  const exportLines = EXPORTS.flatMap(([mod, names]) => names.map((name) => `exports.${name} = require('${mod}').${name};`));
  write('functions/index.cjs', `'use strict';\nif (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');\n` +
    `const {guardEnvironment} = require('../backend.cjs');\nguardEnvironment();\n` +
    `const fs = require('node:fs');\nconst admin = require('firebase-admin');\n` +
    `if (admin.apps.length) throw Error('Refusing preinitialized Admin apps');\n` +
    `admin.initializeApp({projectId: '${PROJECT}', credential: admin.credential.cert({projectId: '${PROJECT}', ` +
    `clientEmail: 'local-qa@${PROJECT}.iam.gserviceaccount.com', privateKey: fs.readFileSync(require('node:path').join(__dirname, '../key.pem'), 'utf8')})});\n` +
    exportLines.join('\n') + '\n' +
    `require('./lib/publicFolders.js').publicFolderDeps.premium = async () => ${JSON.stringify(PREMIUM)};\n` +
    // Save all needs an original. The emulator has no R2, so the QA grant points at the fixture preview.
    `exports.resolveOriginalAccess = require('firebase-functions/v2/https').onCall({region: ['asia-south1', 'us-central1']}, (req) => {\n` +
    `  if (!req.auth) throw new (require('firebase-functions/v2/https').HttpsError)('unauthenticated', 'Sign in');\n` +
    `  const n = Number(String(req.data?.assetId ?? '').replace('qa-discover-', '')) || 1;\n` +
    `  const files = require('node:fs').readdirSync(require('node:path').join(__dirname, '../fixtures')).sort();\n` +
    `  if (req.data?.action === 'quote') return {status: 'quoted', requiredCoins: 0, currentBalance: 0};\n` +
    `  return {status: 'granted', url: '${IMAGE_BASE}' + files[(n - 1) % files.length], expiresAt: Date.now() + 300000, currentBalance: 0};\n` +
    `});\n`);
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
    compiledSha256: sha256(path.join(runtime, 'functions/lib/folderDiscovery.js')),
    proof: 'ADMIN SEEDED folder discovery fixtures; local backend only', nodeVersion: process.versions.node,
    productionNodeTarget: '24', preparedAt: new Date().toISOString()});
  const certificate = fs.readFileSync(path.join(runtime, 'cert.der')).toString('base64');
  for (const name of BUILD_USERS) {
    write(`dart-defines-${name}.json`, {PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: name, PRISM_LOCAL_QA_CERTIFICATE: certificate});
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
  assert.equal(defines.PRISM_LOCAL_QA_USER, selected, 'QA identity does not match --user');
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
// ADMIN SEEDED fixtures only. Every write here is marked qaFixture or is a fixed QA identity.
async function seed() {
  const {admin, db} = loadBackend();
  assert.equal((await db.doc(`walls/${wallId(1)}`).get()).exists, false, 'Refusing to overwrite seeded data; restart the emulators first');
  assert.equal((await db.doc(`folders/${FOLDERS[0].id}`).get()).exists, false, 'Refusing to overwrite seeded folders; restart the emulators first');
  const fixtures = fixtureNames();
  const image = (index) => IMAGE_BASE + fixtures[index % fixtures.length];
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
    // isAdminCaller (functions/src/adminConfig.ts) accepts the admin custom claim on the ID token.
    if (uid === ADMIN) await admin.auth().setCustomUserClaims(uid, {admin: true});
    await db.doc(`usersv2/${uid}`).set({id: uid, email, username, name, loggedIn: true, createdAt: new Date(now).toISOString(),
      lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free', links: {},
      profilePhoto: image(index), coverPhoto: image(index), bio: 'Local QA fixture', badges: [], subPrisms: [],
      coins: 500, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}});
    await db.doc(`profiles/${uid}`).set({name, username, usernameLower: username.toLowerCase(), profilePhoto: image(index),
      bio: 'Local QA fixture', coverPhoto: image(index), followerCount: uid === CREATOR ? 1 : 0,
      followingCount: uid === VIEWER ? 1 : 0});
    await db.doc(`usernames/${username.toLowerCase()}`).set({uid});
  }
  // Riya follows Ana, the same edge pair applyFollowEdge writes.
  await db.doc(`profiles/${VIEWER}/following/${CREATOR}`).set({uid: CREATOR, createdAt: stamp(now - 86400000)});
  await db.doc(`profiles/${CREATOR}/followers/${VIEWER}`).set({uid: VIEWER, createdAt: stamp(now - 86400000), notify: false});
  for (const [index, wall] of WALLS.entries()) {
    const n = index + 1;
    const id = wallId(n);
    await db.doc(`walls/${id}`).set({id, creatorUid: CREATOR, email: `${CREATOR}@example.test`, by: 'Ana QA', uploadedBy: CREATOR,
      userPhoto: image(0), title: `Discover wall ${n}`, desc: 'ADMIN SEEDED folder discovery fixture',
      wallpaper_thumb: image(index), wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
      wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'],
      category: wall.category, tags: [wall.category.toLowerCase()], colors: wall.colors, review: true,
      rejected: false, resolution: '1080x2340', size: 'Local fixture',
      createdAt: stamp(now - (WALLS.length - n + 1) * 60000), qaFixture: 'ADMIN SEEDED'});
  }
  // Private folders with items. Item shape follows validFolderItem in firestore.rules, as shared_folders_qa does.
  for (const folder of FOLDERS) {
    const items = folder.walls;
    await db.doc(`folders/${folder.id}`).set({ownerId: folder.owner, name: folder.name, createdAt: stamp(now - 3600000),
      updatedAt: stamp(now), itemCount: items.length, covers: items.slice(0, 4).map((n) => image(n - 1)),
      public: false, members: {}, memberIds: []});
    for (const [index, n] of items.entries()) {
      const id = wallId(n);
      await db.doc(`folders/${folder.id}/items/prism_${id}`).set({id, url: image(n - 1), thumb: image(n - 1), provider: 'Prism',
        category: WALLS[n - 1].category, views: '', resolution: '1080x2340', fav: '', size: '', photographer: 'Ana QA',
        collections: ['community'], createdAt: stamp(now - 3600000), favouritedAt: stamp(now - 3600000),
        ownerId: folder.owner, addedBy: folder.owner, addedAt: stamp(now - (items.length - index) * 60000), wallpaperDocumentId: id});
    }
  }
  // Each owner makes their own folder public, through the real callable.
  for (const folder of FOLDERS) {
    expectOk(await callable(folder.owner, 'setFolderPublic', {folderId: folder.id, public: true}));
  }
  for (const folder of FOLDERS) {
    await waitFor(async () => (await db.doc(`publicFolders/${folder.id}`).get()).data()?.itemCount === folder.walls.length,
      `publicFolders/${folder.id} with ${folder.walls.length} items`);
  }
  // Riya's favourites: Pastel walls, the shape favouriteWallToDoc writes (Prism provider).
  for (const n of FAVOURITE_WALLS) {
    const id = wallId(n);
    await db.doc(`usersv2/${VIEWER}/images/${id}`).set({id, url: image(n - 1), thumb: image(n - 1), provider: 'Prism',
      category: WALLS[n - 1].category, views: '', resolution: '1080x2340', fav: '', size: '', photographer: 'Ana QA',
      collections: ['community'], createdAt: stamp(now - (WALLS.length - n + 1) * 60000),
      favouritedAt: stamp(now - n * 60000)});
  }
  const folderIds = Object.fromEntries(FOLDERS.map((folder) => [folder.key, folder.id]));
  write('folders.json', folderIds);
  write('state.json', {project: PROJECT, proof: 'ADMIN SEEDED folder discovery fixtures; not device proof',
    seededAt: new Date().toISOString(), cast: {viewer: VIEWER, creator: CREATOR, admin: ADMIN, bo: BO, neo: NEO},
    walls: WALLS.length, folders: folderIds});
  console.log(`Seeded ${CAST.length} users, ${WALLS.length} walls and ${FOLDERS.length} public folders. Next: rank.`);
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
async function callable(uid, name, data) {
  const token = await idToken(uid);
  const response = await fetch(`${FUNCTIONS_URL}/${PROJECT}/us-central1/${name}`, {
    method: 'POST', redirect: 'error', headers: {'content-type': 'application/json', authorization: `Bearer ${token}`},
    signal: AbortSignal.timeout(60000), body: JSON.stringify({data})});
  return {status: response.status, body: await response.json().catch(() => ({}))};
}
function expectOk(res) {
  assert.equal(res.status, 200, res.body.error?.message ?? `HTTP ${res.status}`);
  return res.body.result;
}
async function waitFor(check, what, ms = 20000) {
  for (const start = Date.now(); Date.now() - start < ms;) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw Error(`Timed out waiting for ${what}`);
}
const names = (rows = []) => rows.map((entry) => entry.name);

// Scores today's signals, rebuilds discovery with owner ages overridden to 30 days, then checks the lists.
async function rank() {
  const {admin, db, base} = loadBackend();
  const folderIds = read('folders.json');
  const day = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  for (const signal of SIGNALS) {
    const folderId = folderIds[signal.key];
    assert.ok(folderId, `Run seed first: no folder ${signal.key}`);
    await db.doc(`folderStatsDaily/${day}_${folderId}`).set({folderId, day, follows: signal.follows ?? 0,
      saves: signal.saves ?? 0, opens: signal.opens ?? 0});
  }
  const discovery = require(path.join(base, 'lib/folderDiscovery.js'));
  const createdMs = Date.now() - 30 * DAY_MS;
  discovery.folderDiscoveryDeps.owners = async (uids) => new Map(uids.filter((uid) => OWNERS.includes(uid))
    .map((uid) => [uid, {createdMs, disabled: false}]));
  await discovery.rebuildFolderDiscovery();
  const doc = (await db.doc('folderTrending/current').get()).data() ?? {};
  const trending = doc.trending ?? [];
  const fresh = doc.new ?? [];
  console.log(`trending: ${trending.map((e) => `${e.name} (${e.id})`).join(', ') || '(none)'}`);
  console.log(`new: ${fresh.map((e) => `${e.name} (${e.id})`).join(', ') || '(none)'}`);
  assert.deepEqual(names(trending).sort(), ['Abstract shapes', 'Night skies', 'Soft pastels'],
    'trending must hold Night skies, Soft pastels and Abstract shapes (owner cap drops Third of Ana, Tiny is too small)');

  // `new` holds every eligible folder, except one an owner loses to the 2-per-owner cap.
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - 7 * DAY_MS);
  const eligible = (await db.collection('publicFolders').where('discoveryEligibleAt', '>=', since).get()).docs
    .map((snap) => ({id: snap.id, ownerId: snap.data().ownerId, itemCount: snap.data().itemCount, hidden: snap.data().discoveryHidden === true}))
    .filter((folder) => folder.itemCount >= MIN_DISCOVER_WALLS && !folder.hidden);
  const freshIds = new Set(fresh.map((e) => e.id));
  const perOwner = new Map();
  for (const entry of fresh) perOwner.set(entry.ownerId, (perOwner.get(entry.ownerId) ?? 0) + 1);
  for (const folder of eligible) {
    if (!freshIds.has(folder.id)) assert.equal(perOwner.get(folder.ownerId), 2, `${folder.id} is eligible but missing from new without the owner cap`);
  }
  assert.ok(freshIds.has(folderIds.new), 'Brand new must be in the New tab');
  console.log(`Rank OK. ${eligible.length} eligible folders, ${fresh.length} in new.`);
}

// Moderator hides Abstract shapes. The folder stays public and drops out of both discover lists.
async function hide() {
  const {db} = loadBackend();
  const folderIds = read('folders.json');
  expectOk(await callable(ADMIN, 'setFolderDiscoveryHidden', {folderId: folderIds.abstract, hidden: true}));
  const doc = (await db.doc('folderTrending/current').get()).data() ?? {};
  const trending = names(doc.trending);
  const fresh = names(doc.new);
  console.log(`folderTrending/current trending: ${trending.join(', ') || '(none)'}`);
  console.log(`folderTrending/current new: ${fresh.join(', ') || '(none)'}`);
  assert.ok(!trending.includes('Abstract shapes'), 'Abstract shapes must leave trending');
  assert.ok(!fresh.includes('Abstract shapes'), 'Abstract shapes must leave new');
  assert.ok((await db.doc(`publicFolders/${folderIds.abstract}`).get()).exists, 'publicFolders header must stay');
  console.log('Hide OK. Abstract shapes is out of discovery and still public.');
}

async function evidence() {
  const {db} = loadBackend();
  const folderIds = read('folders.json');
  const doc = (await db.doc('folderTrending/current').get()).data() ?? {};
  const signalRate = (await db.collection('folderSignalRate').get()).size;
  const reports = (await db.collection('contentReports').where('contentType', '==', 'folder').get()).docs
    .map((snap) => ({id: snap.id, target: snap.data().targetFirestoreDocId ?? null, status: snap.data().status ?? null}));
  const discoveryHidden = {};
  for (const folder of FOLDERS) {
    discoveryHidden[folder.name] = (await db.doc(`folders/${folderIds[folder.key]}`).get()).data()?.discoveryHidden === true;
  }
  console.log(JSON.stringify({
    proof: 'ADMIN SEEDED folder discovery fixtures; local emulators; not device proof',
    trending: names(doc.trending),
    new: names(doc.new),
    folderSignalRate: signalRate,
    contentReports: reports,
    discoveryHidden,
  }, null, 2));
}

const commands = {
  preflight, prepare, emulators, seed, rank, hide, evidence, serve,
  'build-apk': () => buildApk(user), 'build-ios': () => buildIos(user),
};
if (!commands[command]) throw Error('Commands: preflight, prepare, emulators, seed, rank, hide, evidence, serve, build-apk, build-ios');
commands[command]().catch((error) => { console.error(error.stack); process.exitCode = 1; });
