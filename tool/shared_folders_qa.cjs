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
let runtime = '/tmp/prism-shared-folders-qa';
let user = null;
while (args.length) {
  const option = args.shift();
  const value = args.shift();
  if (option === '--root' && value) runtime = path.resolve(value);
  else if (option === '--user' && ['viewer', 'creator'].includes(value)) user = value;
  else if (option === '--project' && value === PROJECT) continue;
  else throw Error('Use COMMAND [--root /tmp/prism-shared-folders-qa] [--user viewer|creator] [--project demo-prism]; refusing other projects/options');
}
if (!/^\/tmp\/prism-shared-folders-qa[^/]*$/.test(runtime)) throw Error('Runtime must be /tmp/prism-shared-folders-qa*');
if (/^build-/.test(command) && !user) throw Error(`${command} needs --user viewer or --user creator`);
if (user && !/^build-/.test(command)) throw Error('--user applies only to build-apk and build-ios');

const PASSWORD = 'local-demo-only-password';
const IMAGE_BASE = 'https://localhost:19375/covers/';
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
const INVITE_CODE = /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{10}$/;
const PUSH_HORIZON_MS = 2 * 60 * 60 * 1000;
const FOLDER = 'qa-trip';
const USED_INVITE = 'UsedXyzABC';
const EXPIRED_INVITE = 'ExpiredXYZ';
const FOLDER_NAME = 'Trip';
const CREATOR = 'qa-creator-a';
const VIEWER = 'qa-viewer';
const BLOCKED = 'qa-blocked';
const CAST = [
  {uid: CREATOR, name: 'Ana QA'},
  {uid: VIEWER, name: 'Riya QA'},
  {uid: BLOCKED, name: 'Bo QA'},
];
const WALL_COUNT = 8;
const FAVOURITE_COUNT = 6; // walls 1 to 6 are in Riya's favourites
const TRIP_WALLS = [1, 2]; // walls 1 and 2 are in Trip when it is seeded
const EDITOR_ADD = 3; // the wall that Riya adds in push
// Functions exported to the emulator. Triggers and callables come from the real compiled modules in functions/lib.
const EXPORTS = [
  ['./lib/sharedFolders.js', ['createFolderInvite', 'getFolderInvite', 'joinFolder', 'removeFolderMember', 'leaveFolder']],
  ['./lib/folders.js', ['onFolderWritten', 'onFolderItemWritten']],
];

const wallId = (n) => `qa-shared-${n}`;
const itemKey = (n) => `prism_${wallId(n)}`;
const tokenFor = (uid) => `qa-folder-alert-token-${uid}`;
// The binding fields match fcm_token_service.dart. Without them the server sends nothing and writes no inbox doc.
const session = (uid) => (uid === BLOCKED ? {postAlerts: false} :
  {postAlerts: false, folderAlerts: true, folderAlertsToken: tokenFor(uid), fcmToken: tokenFor(uid),
    fcmTokenBindingVersion: 1, fcmTokenBindingToken: tokenFor(uid)});

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
    'functions/lib/sharedFolders.js', 'functions/lib/folders.js', 'firestore.rules', 'firestore.indexes.json',
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
  write('functions/package.json', {name: 'prism-local-shared-folders-qa', private: true, main: 'index.cjs', engines: {node: '24'}});
  const exportLines = EXPORTS.flatMap(([mod, names]) => names.map((name) => `exports.${name} = require('${mod}').${name};`));
  write('functions/index.cjs', `'use strict';\nif (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');\n` +
    `const {guardEnvironment} = require('../backend.cjs');\nguardEnvironment();\n` +
    `const fs = require('node:fs');\nconst admin = require('firebase-admin');\n` +
    `if (admin.apps.length) throw Error('Refusing preinitialized Admin apps');\n` +
    `admin.initializeApp({projectId: '${PROJECT}', credential: admin.credential.cert({projectId: '${PROJECT}', ` +
    `clientEmail: 'local-qa@${PROJECT}.iam.gserviceaccount.com', privateKey: fs.readFileSync(require('node:path').join(__dirname, '../key.pem'), 'utf8')})});\n` +
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
    compiledSha256: sha256(path.join(runtime, 'functions/lib/sharedFolders.js')),
    proof: 'ADMIN SEEDED shared folder fixtures; local backend only', nodeVersion: process.versions.node,
    productionNodeTarget: '24', preparedAt: new Date().toISOString()});
  const certificate = fs.readFileSync(path.join(runtime, 'cert.der')).toString('base64');
  for (const name of ['viewer', 'creator']) {
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

function checkDefines(user) {
  const defines = read(`dart-defines-${user}.json`);
  assert.equal(defines.PRISM_LOCAL_QA, 'true', 'QA build must explicitly enable isolation');
  assert.equal(defines.PRISM_LOCAL_QA_USER, user, 'QA identity does not match --user');
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
    build();
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
  assert.equal((await db.doc(`folders/${FOLDER}`).get()).exists, false, 'Refusing to overwrite existing folder data; restart the emulators first');
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
    await db.doc(`usersv2/${uid}`).set({id: uid, email, username, name, loggedIn: true, createdAt: new Date(now).toISOString(),
      lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free', links: {},
      profilePhoto: image(index), coverPhoto: image(index), bio: 'Local QA fixture', badges: [], subPrisms: [],
      coins: 0, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}});
    // The app reads names and photos from the public profile projection (functions/src/profiles.ts).
    await db.doc(`profiles/${uid}`).set({name, username, profilePhoto: image(index), bio: 'Local QA fixture',
      coverPhoto: image(index), followerCount: 0, followingCount: 0});
    await db.doc(`usersv2/${uid}/private/session`).set(session(uid));
    await db.doc(`usernames/${username.toLowerCase()}`).set({uid});
  }
  // Bo blocks Ana, so Bo's join is refused.
  await db.doc(`usersv2/${BLOCKED}/blockedUsers/${CREATOR}`).set({blockedUsername: CREATOR.replaceAll('-', ''), createdAt: stamp(now)});
  for (let n = 1; n <= WALL_COUNT; n++) {
    const id = wallId(n);
    const thumb = image(n - 1);
    await db.doc(`walls/${id}`).set({id, creatorUid: CREATOR, email: `${CREATOR}@example.test`, by: CREATOR, uploadedBy: CREATOR,
      userPhoto: image(0), title: `Shared wall ${n}`, desc: 'ADMIN SEEDED shared folder fixture',
      wallpaper_thumb: thumb, wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
      wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'],
      category: 'Nature', tags: ['nature'], colors: [], review: true, rejected: false, resolution: '250x500', size: 'Local fixture',
      createdAt: stamp(now - (WALL_COUNT - n + 1) * 60000), qaFixture: 'ADMIN SEEDED'});
  }
  // Favourites are stored under usersv2/{uid}/images/{wallId}, the same shape as favouriteWallToDoc (Prism provider).
  for (let n = 1; n <= FAVOURITE_COUNT; n++) {
    const id = wallId(n);
    await db.doc(`usersv2/${VIEWER}/images/${id}`).set({id, url: image(n - 1), thumb: image(n - 1), provider: 'Prism',
      category: 'Nature', views: '', resolution: '250x500', fav: '', size: '', photographer: 'Ana QA',
      collections: ['community'], createdAt: stamp(now - (WALL_COUNT - n + 1) * 60000),
      favouritedAt: stamp(now - (FAVOURITE_COUNT - n + 1) * 60000)});
  }
  // Folder with two items. Item shape follows validFolderItem in firestore.rules.
  await db.doc(`folders/${FOLDER}`).set({ownerId: CREATOR, name: FOLDER_NAME, createdAt: stamp(now - 3600000),
    updatedAt: stamp(now), itemCount: TRIP_WALLS.length, covers: [...TRIP_WALLS].reverse().map((n) => image(n - 1)),
    public: false, members: {}, memberIds: []});
  for (const n of TRIP_WALLS) {
    const id = wallId(n);
    await db.doc(`folders/${FOLDER}/items/${itemKey(n)}`).set({id, url: image(n - 1), thumb: image(n - 1), provider: 'Prism',
      category: 'Nature', views: '', resolution: '250x500', fav: '', size: '', photographer: 'Ana QA',
      collections: ['community'], createdAt: stamp(now - 3600000), favouritedAt: stamp(now - 3600000),
      ownerId: CREATOR, addedBy: CREATOR, addedAt: stamp(now - (3 - n) * 60000), wallpaperDocumentId: id});
  }
  // Two refused codes the editor can open on a device: one spent by Bo, one past its 7 days.
  // An invite binds to the folder generation (its create time), as createFolderInvite does.
  const folderCreatedAt = (await db.doc(`folders/${FOLDER}`).get()).createTime;
  const invite = (code, extra) => db.doc(`folderInvites/${code}`).set({code, folderId: FOLDER, folderCreatedAt,
    createdBy: CREATOR, createdAt: stamp(now - 8 * 86400000), expiresAt: stamp(now + 86400000), usedBy: null,
    usedAt: null, ...extra});
  await invite(USED_INVITE, {usedBy: BLOCKED, usedAt: stamp(now - 3600000)});
  await invite(EXPIRED_INVITE, {expiresAt: stamp(now - 86400000)});
  write('state.json', {project: PROJECT, proof: 'ADMIN SEEDED shared folder fixtures; not device proof',
    seededAt: new Date().toISOString(), cast: {creator: CREATOR, viewer: VIEWER, blocked: BLOCKED},
    refusedInvites: {used: USED_INVITE, expired: EXPIRED_INVITE},
    folder: {id: FOLDER, name: FOLDER_NAME, items: TRIP_WALLS.map(itemKey)},
    walls: WALL_COUNT, viewerFavourites: FAVOURITE_COUNT});
  console.log(`Seeded ${CAST.length} users, ${WALL_COUNT} walls, ${FAVOURITE_COUNT} viewer favourites and folder ${FOLDER}. Run assert next.`);
}

// Signs in through the Auth emulator. Tokens stay in memory and are never written to disk.
const idTokens = new Map();
async function idToken(uid) {
  if (!idTokens.has(uid)) {
    const response = await fetch(`${AUTH_URL}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`, {
      method: 'POST', headers: {'content-type': 'application/json'}, signal: AbortSignal.timeout(30000),
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
    method: 'POST', headers: {'content-type': 'application/json', authorization: `Bearer ${token}`},
    signal: AbortSignal.timeout(30000), body: JSON.stringify({data})});
  return {status: response.status, body: await response.json().catch(() => ({}))};
}
function expectOk(res) {
  assert.equal(res.status, 200, res.body.error?.message ?? `HTTP ${res.status}`);
}
function refused(res, reason) {
  assert.equal(res.status, 400, `expected a refusal, got HTTP ${res.status}`);
  assert.equal(res.body.error?.message, reason, `expected refusal "${reason}"`);
}

async function evidence() {
  const {db} = loadBackend();
  const state = read('state.json');
  const steps = [];
  const codes = {};
  let current = 'seeded folder';
  let completed = false;
  const step = async (name, fn) => {
    current = name;
    const detail = await fn();
    steps.push({name, ok: true, detail});
  };
  const folderNow = async () => (await db.doc(`folders/${FOLDER}`).get()).data();
  try {
    await step('seeded folder is owned by Ana and has no editors', async () => {
      const folder = await folderNow();
      assert.ok(folder, 'Run seed first');
      assert.equal(folder.ownerId, CREATOR);
      assert.deepEqual(folder.memberIds ?? [], [], 'Riya already joined. Restart the emulators, then seed again.');
      return {name: folder.name, itemCount: folder.itemCount};
    });
    await step('creator creates invite 1', async () => {
      const res = await callable(CREATOR, 'createFolderInvite', {folderId: FOLDER});
      expectOk(res);
      codes.first = res.body.result.code;
      assert.match(codes.first, INVITE_CODE);
      return 'invite issued';
    });
    await step('viewer previews invite 1 as join', async () => {
      const res = await callable(VIEWER, 'getFolderInvite', {code: codes.first});
      expectOk(res);
      assert.equal(res.body.result.status, 'join');
      assert.equal(res.body.result.name, FOLDER_NAME);
      return {status: res.body.result.status, itemCount: res.body.result.itemCount};
    });
    await step('viewer joins with invite 1', async () => {
      const res = await callable(VIEWER, 'joinFolder', {code: codes.first});
      expectOk(res);
      assert.deepEqual(res.body.result, {folderId: FOLDER, joined: true});
      return 'joined';
    });
    await step('folder lists Riya as the only editor, added by Ana', async () => {
      const folder = await folderNow();
      assert.deepEqual(folder.memberIds, [VIEWER]);
      assert.equal(folder.members[VIEWER].addedBy, CREATOR);
      return {memberIds: folder.memberIds};
    });
    await step('creator creates invite 2 for the refused join', async () => {
      const res = await callable(CREATOR, 'createFolderInvite', {folderId: FOLDER});
      expectOk(res);
      codes.second = res.body.result.code;
      assert.match(codes.second, INVITE_CODE);
      assert.notEqual(codes.second, codes.first);
      return 'invite issued';
    });
    await step('blocked Bo is refused with invite 2 (blocked), invite stays unused', async () => {
      const res = await callable(BLOCKED, 'joinFolder', {code: codes.second});
      refused(res, 'blocked');
      const invite = (await db.doc(`folderInvites/${codes.second}`).get()).data();
      assert.equal(invite.usedBy, null);
      return {status: res.status, reason: 'blocked'};
    });
    await step('blocked Bo is refused with invite 1 (used)', async () => {
      const res = await callable(BLOCKED, 'joinFolder', {code: codes.first});
      refused(res, 'used');
      return {status: res.status, reason: 'used'};
    });
    await step('folder unchanged by the refusals', async () => {
      const folder = await folderNow();
      assert.deepEqual(folder.memberIds, [VIEWER]);
      return {memberIds: folder.memberIds};
    });
    completed = true;
  } catch (error) {
    steps.push({name: current, ok: false, detail: error.message});
  }
  const failed = steps.filter((s) => !s.ok);
  write('evidence.json', {project: PROJECT, proof: state.proof, checkedAt: new Date().toISOString(),
    passed: completed && failed.length === 0, checks: steps,
    codes: {invite1: codes.first, invite2: codes.second}});
  if (codes.first) console.log(`Invite 1 (Riya joins with it): ${codes.first}`);
  if (codes.second) console.log(`Invite 2 (fresh, refused for Bo with "blocked"): ${codes.second}`);
  if (failed.length) throw Error(`${failed.length} check(s) failed; see evidence.json: ${failed.map((c) => c.name).join('; ')}`);
  console.log(`All ${steps.length} checks passed; evidence at ${runtime}/evidence.json. This is backend evidence, not device proof.`);
}

// Creator's fresh link for the device steps. Prints the web link, the in-app path and the custom-scheme link.
async function invite() {
  guardEnvironment();
  assert.equal(read('manifest.json').project, PROJECT);
  const res = await callable(CREATOR, 'createFolderInvite', {folderId: FOLDER});
  expectOk(res);
  const code = res.body.result.code;
  console.log(`https://prismwalls.com/folder/${FOLDER}?invite=${code}`);
  console.log(`/folder/invite/${code}`);
  console.log(`prism://folder/invite/${code}`);
}

async function waitForPending(db, key) {
  const deadline = Date.now() + 60000;
  for (;;) {
    const pending = (await db.doc(`folderActivity/${FOLDER}`).get()).data()?.pending ?? {};
    if (pending[key] === VIEWER) return;
    assert.ok(Date.now() < deadline, 'onFolderItemWritten did not queue the editor add within 60 s');
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
}

// Riya adds wall 3 (Admin write, marked). The real onFolderItemWritten trigger queues it. Then the real push job runs.
async function push() {
  const {admin, db, base} = loadBackend();
  const sharedFolders = require(path.join(base, 'lib/sharedFolders.js'));
  const folder = (await db.doc(`folders/${FOLDER}`).get()).data();
  assert.ok(folder, 'Run seed first');
  assert.ok((folder.memberIds ?? []).includes(VIEWER), 'Riya must join first: run assert, or join on a device');
  const key = itemKey(EDITOR_ADD);
  const itemRef = db.doc(`folders/${FOLDER}/items/${key}`);
  if (!(await itemRef.get()).exists) {
    const id = wallId(EDITOR_ADD);
    await itemRef.set({id, url: IMAGE_BASE + fixtureNames()[EDITOR_ADD - 1], thumb: IMAGE_BASE + fixtureNames()[EDITOR_ADD - 1],
      provider: 'Prism', category: 'Nature', views: '', resolution: '250x500', fav: '', size: '', photographer: 'Ana QA',
      collections: ['community'], createdAt: admin.firestore.Timestamp.now(), favouritedAt: admin.firestore.Timestamp.now(),
      ownerId: CREATOR, addedBy: VIEWER, addedAt: admin.firestore.Timestamp.now(), wallpaperDocumentId: id});
    await waitForPending(db, key);
    console.log(`Queued Riya's add of ${wallId(EDITOR_ADD)} by onFolderItemWritten.`);
  } else {
    console.log(`${key} already exists; sending whatever activity is due.`);
  }
  const sent = await sharedFolders.sendDueFolderActivity(Date.now() + PUSH_HORIZON_MS);
  console.log(`sendDueFolderActivity(now + 2 h): ${sent} push(es) sent. FCM is not reachable in the emulator, so the inbox doc is the evidence.`);
  const inbox = await db.collection('notifications').where('modifier', '==', `${CREATOR}@example.test`).get();
  console.log(`Inbox docs for ${CREATOR}: ${inbox.size}`);
  for (const doc of inbox.docs) console.log(`  ${doc.id}: ${doc.data().notification?.title}`);
}

const commands = {
  preflight, prepare, emulators, serve, seed, assert: evidence, invite, push,
  'build-apk': () => buildApk(user), 'build-ios': () => buildIos(user),
};
if (!commands[command]) throw Error('Commands: preflight, prepare, emulators, serve, seed, assert, invite, push, build-apk, build-ios');
commands[command]().catch((error) => { console.error(error.stack); process.exitCode = 1; });
