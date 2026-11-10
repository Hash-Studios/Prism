#!/usr/bin/env node
/*
 * Live walls local QA. ADMIN SEEDED fixtures on the demo-prism emulators only. Not device proof on its own.
 * Uses the same ports as tool/scheduled_release_qa.cjs. Do not run both harnesses at the same time.
 *
 * Command order (see tool/live_walls_qa/README.md):
 *   1. preflight                          checks ports and prerequisites; starts nothing
 *   2. prepare                            writes the runtime under /tmp/prism-live-walls-qa*
 *   3. emulators                          separate shell; runs until Ctrl-C
 *   4. serve                              separate shell; fixture HTTPS 19375 and plain HTTP 19380
 *   5. seed                               users creator, admin, viewer; 6 approved still walls; no live walls
 *   6. reverse-android <serial>           adb reverse for the app's local ports
 *   7. media-ios <udid> | media-android <serial>   fixture videos into the device library
 *   8. build-apk | build-ios --user creator|admin|viewer
 *   9. check-live                         lists walls with kind == live and their proof fields
 *  10. evidence                           prints a JSON summary
 *  11. unreverse-android <serial>         removes the adb reverse rules
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const http = require('node:http');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, guardEnvironment} = require('./live_walls_qa/guard.cjs');
const {parseRange} = require('./live_walls_qa/range.cjs');
const repo = path.resolve(__dirname, '..');
const harnessDir = path.join(__dirname, 'live_walls_qa');
const sharedDir = path.join(__dirname, 'weekly_challenge_qa');
const args = process.argv.slice(2);
const command = args.shift();
const BUILD_USERS = ['creator', 'admin', 'viewer'];
const APP_USER = {creator: 'creator', admin: 'admin', viewer: 'viewer'};
const DEVICE_COMMANDS = ['media-ios', 'media-android', 'reverse-android', 'unreverse-android'];
const DEVICE_ID = /^[A-Za-z0-9._:-]{1,80}$/;
let runtime = '/tmp/prism-live-walls-qa';
let user = null;
let device = null;
const USAGE = 'Use COMMAND [--root /tmp/prism-live-walls-qa] [--user creator|admin|viewer] [--project demo-prism]; ' +
  'device commands take one device id first; refusing other options';
if (DEVICE_COMMANDS.includes(command)) {
  device = args.shift();
  if (!DEVICE_ID.test(device ?? '')) throw Error(`${command} needs a device id (iOS UDID or Android serial)`);
}
while (args.length) {
  const option = args.shift();
  const value = args.shift();
  if (option === '--root' && value) runtime = path.resolve(value);
  else if (option === '--user' && BUILD_USERS.includes(value)) user = value;
  else if (option === '--project' && value === PROJECT) continue;
  else throw Error(USAGE);
}
if (!/^\/tmp\/prism-live-walls-qa[^/]*$/.test(runtime)) throw Error('Runtime must be /tmp/prism-live-walls-qa*');
if (/^build-/.test(command) && !user) throw Error(`${command} needs --user creator, admin or viewer`);
if (user && !/^build-/.test(command)) throw Error('--user applies only to build-apk and build-ios');

const PASSWORD = 'local-demo-only-password';
// Same ports as the scheduled release harness. The app hard-codes them.
const AUTH_PORT = 19371;
const FIRESTORE_PORT = 19372;
const FUNCTIONS_PORT = 19373;
const HUB_PORT = 19374;
const FIXTURE_HTTPS = 19375;
const LOGGING_PORT = 19376;
const FIRESTORE_WS_PORT = 19377;
const EVENTARC_PORT = 19378;
const TASKS_PORT = 19379;
const FIXTURE_HTTP = 19380;
const HARNESS_PORTS = [AUTH_PORT, FIRESTORE_PORT, FUNCTIONS_PORT, HUB_PORT, FIXTURE_HTTPS, LOGGING_PORT,
  FIRESTORE_WS_PORT, EVENTARC_PORT, TASKS_PORT, FIXTURE_HTTP];
const REVERSE_PORTS = [AUTH_PORT, FIRESTORE_PORT, FUNCTIONS_PORT, FIXTURE_HTTPS, FIXTURE_HTTP];
const PUBLIC_BASE = `https://localhost:${FIXTURE_HTTPS}`;
const COVER_BASE = `${PUBLIC_BASE}/covers/`;
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
const AUTH_URL = `http://127.0.0.1:${AUTH_PORT}`;
const DOCS = `projects/${PROJECT}/databases/(default)/documents`;
// The app hard-codes these uids for its QA identities, so the seed uses them too.
const CREATOR = 'qa-creator-a';
const ADMIN = 'qa-admin';
const VIEWER = 'qa-viewer';
const CREATOR_EMAIL = `${CREATOR}@example.test`;
const CAST = [
  {uid: CREATOR, name: 'Ana QA'},
  {uid: ADMIN, name: 'Mod QA'},
  {uid: VIEWER, name: 'Riya QA'},
];
const STILL_IDS = Array.from({length: 6}, (_, index) => `qa-still-${index + 1}`);
const GRADIENT = (size, seconds) => `gradients=s=${size}:d=${seconds}:speed=0.015:c0=0x0b1d51:c1=0x7b2ff7:c2=0xf107a3:c3=0xffb86b,format=yuv420p`;
// Fixture videos. ffmpeg writes each into <runtime>/media/.
const MEDIA = [
  {file: 'live-ok.mp4', expect: 'accepted', source: GRADIENT('1080x1920', 6), fps: 30, crf: 26},
  {file: 'live-landscape.mp4', expect: 'refused', source: GRADIENT('1920x1080', 2), fps: 30, crf: 26},
  {file: 'live-long.mp4', expect: 'refused', source: GRADIENT('1080x1920', 20), fps: 5, crf: 35},
];
const EXPORTS = [
  ['./lib/githubContent.js', ['githubPutFile', 'githubDeleteFile']],
  ['./lib/onWallSubmitted.js', ['onWallSubmitted']],
  ['./lib/ownedAssetDelivery.js', ['onOwnedWallWritten']],
  ['./lib/onWallApproved.js', ['onWallApproved']],
  ['./lib/originalAccess.js', ['resolveOriginalAccess']],
];
const DEFINE_KEYS = ['PRISM_LOCAL_QA', 'PRISM_LOCAL_QA_USER', 'PRISM_LOCAL_QA_CERTIFICATE', 'GH_REPO_WALLS'];

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
function write(name, value) {
  fs.writeFileSync(runtimeFile(name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n');
}
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
    server.once('error', () => reject(Error(`Port ${port} is busy. Stop the process that uses it. ` +
      'The scheduled release harness uses the same ports; the two harnesses cannot run at the same time.')));
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
function encodeArgs(item, out) {
  return ['-y', '-f', 'lavfi', '-i', item.source, '-r', String(item.fps), '-c:v', 'libx264', '-preset', 'medium',
    '-crf', String(item.crf), '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out];
}
function sidecarType(file) {
  const meta = `${file}.meta.json`;
  return fs.existsSync(meta) ? JSON.parse(fs.readFileSync(meta, 'utf8')).contentType || null : null;
}

async function preflight() {
  guardEnvironment();
  const androidConfig = path.join(repo, 'android/app/google-services.json');
  if (fs.existsSync(androidConfig)) validateAndroid(fs.readFileSync(androidConfig));
  const iosConfig = path.join(repo, 'ios/Runner/GoogleService-Info.plist');
  if (fs.existsSync(iosConfig)) validateIos(fs.readFileSync(iosConfig));
  if (Number(process.versions.node.split('.')[0]) < 24) throw Error('Local QA requires Node 24 or newer.');
  console.log(`Local runtime Node ${process.versions.node}; production Functions target Node 24.`);
  for (const port of HARNESS_PORTS) await available(port);
  if (!fs.existsSync(path.join(repo, 'functions/lib/githubContent.js'))) {
    throw Error('functions/lib is not built. Run: cd functions && npm run build');
  }
  for (const file of ['functions/node_modules/firebase-admin/package.json', 'functions/lib/common.js',
    'functions/lib/githubContent.js', 'functions/lib/ownedAssetDelivery.js', 'functions/lib/onWallSubmitted.js',
    'functions/lib/onWallApproved.js', 'functions/lib/originalAccess.js', 'functions/lib/r2Storage.js',
    'firestore.rules', 'firestore.indexes.json', 'tool/weekly_challenge_qa/cli_network_guard.cjs',
    'tool/weekly_challenge_qa/AndroidManifest.xml']) {
    if (!fs.existsSync(path.join(repo, file))) throw Error(`Missing ${file}. Run: cd functions && npm run build`);
  }
  if (coverNames().length < FIXTURE_COUNT) throw Error(`Need ${FIXTURE_COUNT} covers in assets/images/covers.`);
  const versions = {firebase: ['--version'], openssl: ['version'], java: ['-version'], ffmpeg: ['-version'], python3: ['--version']};
  for (const [binary, argv] of Object.entries(versions)) run(binary, argv);
  console.log('Ports free and local prerequisites found. No emulators started.');
  console.log('The scheduled release harness uses the same ports. Run only one harness at a time.');
}

async function prepare() {
  await preflight();
  fs.mkdirSync(runtime, {recursive: false, mode: 0o700});
  fs.mkdirSync(path.join(runtime, 'fixtures'));
  const covers = coverNames();
  for (const name of covers) {
    assert.match(name, COVER_NAME);
    fs.copyFileSync(path.join(repo, 'assets/images/covers', name), path.join(runtime, 'fixtures', name));
  }
  fs.mkdirSync(path.join(runtime, 'functions'));
  fs.cpSync(path.join(repo, 'functions/lib'), path.join(runtime, 'functions/lib'), {recursive: true});
  fs.symlinkSync(path.join(repo, 'functions/node_modules'), path.join(runtime, 'functions/node_modules'), 'dir');
  // Runtime only: the fake R2 takes the name of the real module, which moves aside.
  fs.renameSync(path.join(runtime, 'functions/lib/r2Storage.js'), path.join(runtime, 'functions/lib/r2Storage.real.js'));
  fs.copyFileSync(path.join(harnessDir, 'fake_r2.cjs'), runtimeFile('functions/lib/live_walls_fake_r2.cjs'));
  write('functions/lib/r2Storage.js', `'use strict';\n// QA runtime only: disk stand-in for the R2 client. The real module is r2Storage.real.js.\n` +
    `const real = require('./r2Storage.real.js');\nconst {makeDiskR2Storage} = require('./live_walls_fake_r2.cjs');\n` +
    `module.exports = {...real, R2Storage: makeDiskR2Storage(${JSON.stringify(fs.realpathSync(runtime))})};\n`);
  fs.copyFileSync(path.join(harnessDir, 'guard.cjs'), runtimeFile('backend.cjs'));
  fs.copyFileSync(path.join(repo, 'firestore.rules'), runtimeFile('firestore.rules'));
  fs.copyFileSync(path.join(repo, 'firestore.indexes.json'), runtimeFile('firestore.indexes.json'));
  write('functions/package.json', {name: 'prism-local-live-walls-qa', private: true, main: 'index.cjs', engines: {node: '24'}});
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
    emulators: {auth: {host: '127.0.0.1', port: AUTH_PORT}, firestore: {host: '127.0.0.1', port: FIRESTORE_PORT,
      websocketPort: FIRESTORE_WS_PORT}, functions: {host: '127.0.0.1', port: FUNCTIONS_PORT},
    hub: {host: '127.0.0.1', port: HUB_PORT}, eventarc: {host: '127.0.0.1', port: EVENTARC_PORT},
    tasks: {host: '127.0.0.1', port: TASKS_PORT}, ui: {enabled: false},
    logging: {host: '127.0.0.1', port: LOGGING_PORT}, singleProjectMode: true}});
  // The Firebase emulator reads functions/.env and functions/.secret.local from the functions source directory.
  write('functions/.env', ['GH_REPO_WALLS=qa-walls', 'GH_REPO_SETUPS=qa-setups', 'GH_USERNAME=qa-owner',
    'R2_ACCOUNT_ID=00000000000000000000000000000000', 'R2_PRIVATE_BUCKET=qa-private', 'R2_PREVIEW_BUCKET=qa-preview',
    `R2_PREVIEW_BASE_URL=${PUBLIC_BASE}`].join('\n') + '\n');
  write('functions/.secret.local', ['GH_TOKEN=qa-local', 'STUDIO_SECRET=qa-local', 'R2_ACCESS_KEY_ID=qa-local',
    'R2_SECRET_ACCESS_KEY=qa-local'].join('\n') + '\n');
  run('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', path.join(runtime, 'key.pem'),
    '-out', path.join(runtime, 'cert.pem'), '-days', '7', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost']);
  fs.chmodSync(path.join(runtime, 'key.pem'), 0o600);
  run('openssl', ['x509', '-in', path.join(runtime, 'cert.pem'), '-outform', 'DER', '-out', path.join(runtime, 'cert.der')]);
  fs.mkdirSync(path.join(runtime, 'media'));
  for (const item of MEDIA) run('ffmpeg', encodeArgs(item, path.join(runtime, 'media', item.file)));
  write('manifest.json', {project: PROJECT, runtime: fs.realpathSync(runtime),
    fixtures: covers.map((name) => ({file: name, sha256: sha256(path.join(runtime, 'fixtures', name))})),
    media: MEDIA.map((item) => ({file: item.file, expect: item.expect, bytes: fs.statSync(path.join(runtime, 'media', item.file)).size,
      sha256: sha256(path.join(runtime, 'media', item.file))})),
    compiledSha256: sha256(path.join(runtime, 'functions/lib/onWallApproved.js')),
    proof: 'ADMIN SEEDED live walls fixtures; local backend only', nodeVersion: process.versions.node,
    productionNodeTarget: '24', preparedAt: new Date().toISOString()});
  const certificate = fs.readFileSync(path.join(runtime, 'cert.der')).toString('base64');
  for (const name of BUILD_USERS) {
    write(`dart-defines-${name}.json`, {PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: APP_USER[name],
      PRISM_LOCAL_QA_CERTIFICATE: certificate, GH_REPO_WALLS: 'qa-walls'});
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
  console.log(`Prepared ${runtime}. No native repo config was changed. Start emulators and serve in separate terminals.`);
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
      NODE_OPTIONS: `--require=${path.join(sharedDir, 'cli_network_guard.cjs')}`},
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
  assert.equal(defines.GH_REPO_WALLS, 'qa-walls', 'QA build must name the QA walls repo');
  assert.ok(Object.keys(defines).every((key) => DEFINE_KEYS.includes(key)), 'Unexpected QA build define');
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
    {source: path.join(sharedDir, 'AndroidManifest.xml'), destination: 'android/app/src/debug/AndroidManifest.xml'},
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

// Fixture server. One handler serves the HTTPS port (19375) and the plain HTTP port (19380).
function fixtureFile(pathname) {
  let match = /^\/previews\/([a-f0-9]{64}\.img)$/.exec(pathname);
  if (match) return {file: path.join(runtime, 'r2', 'preview', 'previews', match[1])};
  match = /^\/private\/(private-originals\/[a-f0-9]{64})$/.exec(pathname);
  if (match) return {file: path.join(runtime, 'r2', 'private', match[1])};
  match = /^\/covers\/([A-Za-z0-9_-]+\.webp)$/.exec(pathname);
  if (match) return {file: path.join(runtime, 'fixtures', match[1]), contentType: 'image/webp'};
  return null;
}
function fixtureHandler(manifest) {
  return (req, res) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, {Allow: 'GET, HEAD'});
      res.end();
      return;
    }
    const head = req.method === 'HEAD';
    const pathname = new URL(req.url ?? '/', PUBLIC_BASE).pathname;
    if (pathname === '/health') {
      const body = JSON.stringify(manifest);
      res.writeHead(200, {'content-type': 'application/json', 'content-length': Buffer.byteLength(body)});
      res.end(head ? undefined : body);
      return;
    }
    const target = fixtureFile(pathname);
    if (!target || !fs.existsSync(target.file)) {
      res.writeHead(404);
      res.end();
      return;
    }
    const bytes = fs.readFileSync(target.file);
    const contentType = target.contentType ?? sidecarType(target.file) ?? 'application/octet-stream';
    const common = {'content-type': contentType, 'accept-ranges': 'bytes'};
    const range = parseRange(req.headers.range, bytes.length);
    if (range?.unsatisfiable) {
      res.writeHead(416, {...common, 'content-range': `bytes */${bytes.length}`});
      res.end();
      return;
    }
    if (range) {
      const body = bytes.subarray(range.start, range.end + 1);
      res.writeHead(206, {...common, 'content-range': `bytes ${range.start}-${range.end}/${bytes.length}`,
        'content-length': body.length});
      res.end(head ? undefined : body);
      return;
    }
    res.writeHead(200, {...common, 'content-length': bytes.length});
    res.end(head ? undefined : bytes);
  };
}

async function serve() {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  await available(FIXTURE_HTTPS);
  await available(FIXTURE_HTTP);
  const handler = fixtureHandler(manifest);
  const tls = https.createServer({key: fs.readFileSync(path.join(runtime, 'key.pem')),
    cert: fs.readFileSync(path.join(runtime, 'cert.pem'))}, handler);
  const plain = http.createServer(handler);
  tls.listen(FIXTURE_HTTPS, '127.0.0.1', () => console.log(`Fixture HTTPS on 127.0.0.1:${FIXTURE_HTTPS}.`));
  plain.listen(FIXTURE_HTTP, '127.0.0.1', () => console.log(`Fixture plain HTTP on 127.0.0.1:${FIXTURE_HTTP}. Ctrl-C stops both.`));
}

function loadBackend() {
  guardEnvironment();
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime), 'Wrong QA runtime manifest');
  const admin = require(path.join(runtime, 'functions/node_modules/firebase-admin'));
  assert.equal(admin.apps.length, 0, 'Refusing preinitialized Admin apps');
  admin.initializeApp({projectId: PROJECT, credential: admin.credential.cert({
    projectId: PROJECT,
    clientEmail: `local-qa@${PROJECT}.iam.gserviceaccount.com`,
    privateKey: fs.readFileSync(path.join(runtime, 'key.pem'), 'utf8'),
  })});
  return {admin, db: admin.firestore()};
}

// Protected fields follow the base harness: the original and thumb are server-owned and the URLs are empty.
function fixtureWall(id, imageUrl, title, review, createdAt, stamp) {
  return {id, creatorUid: CREATOR, email: CREATOR_EMAIL, by: 'Ana QA', uploadedBy: CREATOR,
    userPhoto: imageUrl, title, desc: 'ADMIN SEEDED live walls fixture', wallpaper_thumb: imageUrl,
    wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
    wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'],
    category: 'Nature', tags: ['nature'], colors: ['blue'], review, rejected: false,
    resolution: '1080x2340', size: 'Local fixture', createdAt: stamp(createdAt), qaFixture: 'ADMIN SEEDED'};
}

// ADMIN SEEDED fixtures only. Every write here is marked qaFixture or is a fixed QA identity.
async function seed() {
  const {admin, db} = loadBackend();
  assert.equal((await db.doc(`walls/${STILL_IDS[0]}`).get()).exists, false, 'Refusing to overwrite seeded walls; restart the emulators first');
  const fixtures = fixtureNames();
  const image = (index) => COVER_BASE + fixtures[index % fixtures.length];
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
    // premium false for the creator, so the weekly upload quota path runs.
    await db.doc(`usersv2/${uid}`).set({id: uid, email, username, name, loggedIn: true, createdAt: new Date(now).toISOString(),
      lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free', links: {},
      profilePhoto: image(index), coverPhoto: image(index), bio: 'Local QA fixture', badges: [], subPrisms: [],
      coins: 500, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}});
    await db.doc(`profiles/${uid}`).set({name, username, usernameLower: username.toLowerCase(), profilePhoto: image(index),
      bio: 'Local QA fixture', coverPhoto: image(index), followerCount: 0, followingCount: 0});
    await db.doc(`usernames/${username.toLowerCase()}`).set({uid});
  }
  for (const [index, id] of STILL_IDS.entries()) {
    const ago = (STILL_IDS.length - index) * 60000;
    await db.doc(`walls/${id}`).set({...fixtureWall(id, image(index), `Still wall ${index + 1}`, true, now - ago, stamp),
      publishedAt: stamp(now - ago)});
  }
  const state = {project: PROJECT, proof: 'ADMIN SEEDED live walls fixtures; local emulators; not device proof',
    seededAt: new Date(now).toISOString(), creator: {uid: CREATOR, email: CREATOR_EMAIL},
    admin: {uid: ADMIN, email: `${ADMIN}@example.test`}, viewer: {uid: VIEWER, email: `${VIEWER}@example.test`},
    stills: STILL_IDS};
  write('state.json', state);
  record('seed', {stills: STILL_IDS, creator: CREATOR, admin: ADMIN, viewer: VIEWER});
  console.log(`Seeded ${CAST.length} users and ${STILL_IDS.length} approved still walls. No live walls are seeded.`);
  console.log(`Next: create a live wall on the device as ${CREATOR}, then run check-live.`);
}

async function reverseAndroid(serial, remove) {
  for (const port of REVERSE_PORTS) {
    run('adb', ['-s', serial, 'reverse', ...(remove ? ['--remove'] : []), `tcp:${port}`, ...(remove ? [] : [`tcp:${port}`])]);
  }
  record(remove ? 'unreverseAndroid' : 'reverseAndroid', {serial, ports: REVERSE_PORTS});
}

async function mediaIos(udid) {
  read('manifest.json');
  const files = MEDIA.map((item) => runtimeFile(path.join('media', item.file)));
  run('xcrun', ['simctl', 'addmedia', udid, ...files]);
  record('mediaIos', {udid, files: MEDIA.map((item) => item.file)});
}

async function mediaAndroid(serial) {
  read('manifest.json');
  for (const item of MEDIA) {
    run('adb', ['-s', serial, 'push', runtimeFile(path.join('media', item.file)), '/sdcard/Movies/']);
    run('adb', ['-s', serial, 'shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
      '-d', `file:///sdcard/Movies/${item.file}`]);
  }
  record('mediaAndroid', {serial, files: MEDIA.map((item) => item.file)});
}

// Lists the walls the device created with kind == live, and whether each video is in the preview store.
async function checkLive() {
  const {db} = loadBackend();
  const snap = await db.collection('walls').where('kind', '==', 'live').get();
  const rows = snap.docs.map((doc) => {
    const data = doc.data();
    const live = data.live ?? {};
    const videoId = /\/previews\/([a-f0-9]{64})\.img$/.exec(String(live.video ?? ''))?.[1] ?? null;
    return {id: doc.id, review: data.review ?? null, verified: live.verified ?? null, error: live.error ?? null,
      durationMs: live.durationMs ?? null, width: live.width ?? null, height: live.height ?? null,
      video: live.video ?? null,
      videoInPreview: videoId !== null && fs.existsSync(runtimeFile(path.join('r2', 'preview', 'previews', `${videoId}.img`)))};
  });
  record('checkLive', rows);
  console.log(JSON.stringify(rows, null, 2));
  console.log(`${rows.length} live wall(s). Next: evidence.`);
}

async function evidence() {
  const state = read('state.json');
  const results = fs.existsSync(runtimeFile('results.json')) ? read('results.json') : {};
  console.log(JSON.stringify({
    proof: 'ADMIN SEEDED live walls fixtures; local emulators; not device proof',
    project: PROJECT,
    state,
    steps: results,
  }, null, 2));
}

const commands = {
  preflight, prepare, emulators, serve, seed, evidence, 'check-live': checkLive,
  'media-ios': () => mediaIos(device), 'media-android': () => mediaAndroid(device),
  'reverse-android': () => reverseAndroid(device, false), 'unreverse-android': () => reverseAndroid(device, true),
  'build-apk': () => buildApk(user), 'build-ios': () => buildIos(user),
};
if (!Object.hasOwn(commands, command)) {
  throw Error('Commands: preflight, prepare, emulators, serve, seed, media-ios, media-android, reverse-android, ' +
    'unreverse-android, build-apk, build-ios, check-live, evidence');
}
commands[command]().catch((error) => { console.error(error.stack); process.exitCode = 1; });
