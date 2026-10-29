#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, PORTS, guardEnvironment, load} = require('./weekly_challenge_qa/backend.cjs');
const repo = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const command = args.shift();
let runtime = '/tmp/prism-weekly-qa';
while (args.length) {
  const option = args.shift();
  const value = args.shift();
  if (option === '--root' && value) runtime = path.resolve(value);
  else if (option === '--project' && value === PROJECT) continue;
  else throw Error('Use COMMAND [--root /tmp/prism-weekly-qa] [--project demo-prism]; refusing other projects/options');
}
if (!runtime.startsWith('/tmp/prism-weekly-qa') || runtime === '/tmp/prism-challenge-runtime') throw Error('Runtime must be /tmp/prism-weekly-qa*');
function write(name, value) { fs.writeFileSync(path.join(runtime, name), typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n'); }
function read(name) { return JSON.parse(fs.readFileSync(path.join(runtime, name))); }
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
async function preflight() {
  guardEnvironment();
  const androidConfig = path.join(repo, 'android/app/google-services.json');
  if (fs.existsSync(androidConfig)) {
    const config = JSON.parse(fs.readFileSync(androidConfig));
    if (config.project_info?.project_id !== PROJECT || config.client?.[0]?.api_key?.[0]?.current_key !== 'AIzaSy000000000000000000000000000000000') {
      throw Error('Real Android Firebase config present. Use isolated synthetic build inputs first.');
    }
  }
  const iosConfig = path.join(repo, 'ios/Runner/GoogleService-Info.plist');
  if (fs.existsSync(iosConfig) && !fs.readFileSync(iosConfig, 'utf8').includes('<string>AIzaSy000000000000000000000000000000000</string>')) {
    throw Error('Real iOS Firebase config present. Use isolated synthetic build inputs first.');
  }
  if (Number(process.versions.node.split('.')[0]) < 24) throw Error('Local QA requires Node 24 or newer.');
  console.log(`Local runtime Node ${process.versions.node}; production Functions target Node 24. Runtime parity is a separate gate.`);
  for (const port of [...PORTS, 19376, 19377, 19378, 19379]) await available(port);
  for (const file of ['functions/node_modules/firebase-admin/package.json', 'functions/lib/weeklyChallenges.js',
    'functions/lib/wallOfTheDay.js', 'assets/images/wallpaper.jpg', 'firestore.rules', 'firestore.indexes.json']) {
    if (!fs.existsSync(path.join(repo, file))) throw Error(`Missing ${file}; no install or build is performed by this helper.`);
  }
  for (const binary of ['firebase', 'openssl', 'java']) run(binary, binary === 'java' ? ['-version'] : binary === 'firebase' ? ['--version'] : ['version']);
  console.log('Ports free and local prerequisites found. No emulators started.');
}
async function prepare() {
  await preflight();
  fs.mkdirSync(runtime, {recursive: false}); // refuse stale or peer-owned directories
  fs.mkdirSync(path.join(runtime, 'functions'));
  fs.cpSync(path.join(repo, 'functions/lib'), path.join(runtime, 'functions/lib'), {recursive: true});
  fs.symlinkSync(path.join(repo, 'functions/node_modules'), path.join(runtime, 'functions/node_modules'), 'dir');
  fs.copyFileSync(path.join(repo, 'tool/weekly_challenge_qa/backend.cjs'), path.join(runtime, 'backend.cjs'));
  fs.copyFileSync(path.join(repo, 'assets/images/wallpaper.jpg'), path.join(runtime, 'wallpaper.jpg'));
  fs.copyFileSync(path.join(repo, 'firestore.rules'), path.join(runtime, 'firestore.rules'));
  fs.copyFileSync(path.join(repo, 'firestore.indexes.json'), path.join(runtime, 'firestore.indexes.json'));
  write('functions/package.json', {name: 'prism-local-challenge-qa', private: true, main: 'index.cjs', engines: {node: '24'}});
  write('functions/index.cjs', `'use strict';\nif (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');\nconst {challenge} = require('../backend.cjs').load(require('node:path').resolve(__dirname, '..'));\nfor (const name of ['listWeeklyChallenges', 'getWeeklyChallenge', 'setChallengeVote']) exports[name] = challenge[name];\n` + fs.readFileSync(path.join(__dirname, 'weekly_challenge_qa/admission_probe.cjs'), 'utf8'));
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
  const fixtureSha256 = crypto.createHash('sha256').update(fs.readFileSync(path.join(runtime, 'wallpaper.jpg'))).digest('hex');
  write('manifest.json', {project: PROJECT, runtime: fs.realpathSync(runtime), fixtureSha256,
    compiledSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(runtime, 'functions/lib/weeklyChallenges.js'))).digest('hex'),
    proof: 'ADMIN SEEDED; not authenticated upload admission', nodeVersion: process.versions.node, productionNodeTarget: '24', preparedAt: new Date().toISOString()});
  write('dart-defines.json', {PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: 'viewer',
    PRISM_LOCAL_QA_CERTIFICATE: fs.readFileSync(path.join(runtime, 'cert.der')).toString('base64')});
  // Synthetic native configuration is an explicit build input. Never overwrite a real file.
  fs.mkdirSync(path.join(runtime, 'native'));
  write('native/google-services.json', {project_info: {project_number: '1234567890', project_id: PROJECT, storage_bucket: `${PROJECT}.appspot.com`},
    client: [{client_info: {mobilesdk_app_id: '1:1234567890:android:0123456789abcdef', android_client_info: {package_name: 'com.hash.prism'}},
      api_key: [{current_key: 'AIzaSy000000000000000000000000000000000'}]}], configuration_version: '1'});
  write('native/GoogleService-Info.plist', `<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>API_KEY</key><string>AIzaSy000000000000000000000000000000000</string><key>GCM_SENDER_ID</key><string>1234567890</string>
<key>GOOGLE_APP_ID</key><string>1:1234567890:ios:0123456789abcdef</string><key>PROJECT_ID</key><string>demo-prism</string>
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
    env: {...process.env, XDG_CONFIG_HOME: config, CI: '1', FIREBASE_CLI_DISABLE_TELEMETRY: '1', METADATA_SERVER_DETECTION: 'none',
      NODE_OPTIONS: `--require=${path.join(__dirname, 'weekly_challenge_qa/cli_network_guard.cjs')}`},
  });
}
async function buildApk() {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  const defines = read('dart-defines.json');
  assert.equal(defines.PRISM_LOCAL_QA, 'true', 'QA build must explicitly enable isolation');
  assert.ok(['viewer', 'creator', 'guest'].includes(defines.PRISM_LOCAL_QA_USER), 'Unknown QA identity');
  assert.ok(Object.keys(defines).every(key => ['PRISM_LOCAL_QA', 'PRISM_LOCAL_QA_USER', 'PRISM_LOCAL_QA_CERTIFICATE'].includes(key)), 'Unexpected QA build define');
  const certificate = fs.readFileSync(path.join(runtime, 'cert.der'));
  assert.ok(certificate.length, 'Missing QA certificate');
  assert.equal(defines.PRISM_LOCAL_QA_CERTIFICATE, certificate.toString('base64'), 'QA certificate mismatch');
  function validateNativeConfig(bytes) {
    const config = JSON.parse(bytes);
    assert.equal(config.project_info?.project_id, PROJECT, 'Refusing non-demo native config');
    assert.equal(config.client?.[0]?.api_key?.[0]?.current_key, 'AIzaSy000000000000000000000000000000000', 'Refusing non-synthetic native key');
  }
  const destinations = [
    ['native/google-services.json', 'android/app/google-services.json'],
    [null, 'android/app/src/debug/AndroidManifest.xml'],
  ];
  const originals = [];
  try {
    for (const [source, destination] of destinations) {
      const target = path.join(repo, destination);
      const original = fs.existsSync(target) ? fs.readFileSync(target) : null;
      if (source && original) validateNativeConfig(original);
      const replacement = fs.readFileSync(source ? path.join(runtime, source) : path.join(__dirname, 'weekly_challenge_qa/AndroidManifest.xml'));
      if (source) validateNativeConfig(replacement);
      originals.push({target, original, replacement});
      fs.writeFileSync(target, replacement);
    }
    run('fvm', ['flutter', 'build', 'apk', '--debug', '--no-pub', '--target-platform=android-x64', '--dart-define-from-file=' + path.join(runtime, 'dart-defines.json')], {cwd: repo, env: {...process.env, GRADLE_OPTS: `${process.env.GRADLE_OPTS || ''} -Dorg.gradle.workers.max=2`}});
  } finally {
    const errors = [];
    for (const {target, original, replacement} of originals.reverse()) {
      try {
        if (!fs.readFileSync(target).equals(replacement)) throw Error('Build input changed concurrently; refusing overwrite: ' + target);
        if (original) fs.writeFileSync(target, original);
        else fs.unlinkSync(target);
      } catch (error) {
        errors.push(error);
      }
    }
    if (errors.length) throw new AggregateError(errors, 'Unable to restore all QA build inputs: ' + errors.map(error => error.message).join('; '));
  }
}
async function serve() {
  const manifest = read('manifest.json');
  assert.equal(manifest.project, PROJECT);
  assert.equal(manifest.runtime, fs.realpathSync(runtime));
  await available(19375);
  const server = https.createServer({key: fs.readFileSync(path.join(runtime, 'key.pem')), cert: fs.readFileSync(path.join(runtime, 'cert.pem'))}, (req, res) => {
    if (req.method !== 'GET' || !['/health', '/wallpaper.jpg'].includes(req.url)) { res.writeHead(404); res.end(); return; }
    if (req.url === '/health') { res.setHeader('content-type', 'application/json'); res.end(JSON.stringify(manifest)); return; }
    res.setHeader('content-type', 'image/jpeg');
    res.end(fs.readFileSync(path.join(runtime, 'wallpaper.jpg')));
  });
  server.listen(19375, '127.0.0.1', () => console.log('Local fixture HTTPS on 127.0.0.1:19375. Ctrl-C stops only this server.'));
}
async function seed() {
  const {admin, db, challenge, manifest} = load(runtime);
  assert.equal((await db.collection('weeklyChallenges').limit(1).get()).empty, true, 'Refusing to overwrite existing emulator challenge data');
  const stamp = admin.firestore.Timestamp.fromMillis;
  const now = Date.now();
  const image = 'https://localhost:19375/wallpaper.jpg';
  for (const uid of ['qa-viewer', 'qa-creator-a', 'qa-creator-b']) {
    try { await admin.auth().createUser({uid, email: `${uid}@example.test`, password: 'local-demo-only-password', displayName: uid, emailVerified: true}); }
    catch (e) { if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
      assert.equal((await admin.auth().getUser(uid)).email, `${uid}@example.test`); }
    const profile = {id: uid, email: `${uid}@example.test`, username: uid.replaceAll('-', ''), name: uid, loggedIn: true,
      createdAt: new Date(now).toISOString(), lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free',
      links: {}, followers: [], following: ['qa-creator-a'], profilePhoto: image, coverPhoto: image, bio: 'Local QA fixture',
      badges: [], subPrisms: [], coins: 0, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}};
    await db.doc(`usersv2/${uid}`).set(profile);
    await db.doc(`usersv2/${uid}/private/session`).set({postAlerts: false});
    await db.doc(`profiles/${uid}`).set({...profile, followersCount: 0, followingCount: 1});
    await db.doc(`usernames/${profile.username.toLowerCase()}`).set({uid});
  }
  const week = challenge.mondayAt(now);
  const state = {project: PROJECT, proof: manifest.proof, active: challenge.dateKey(week),
    history: challenge.dateKey(week - 7 * 86400000), empty: challenge.dateKey(week - 14 * 86400000), entries: []};
  for (const id of [state.active, state.history, state.empty]) {
    await db.doc(`weeklyChallenges/${id}`).set({theme: id === state.active ? 'Local light and shadows' : 'Local QA history',
      state: 'open', opensAt: stamp(now - 3600000), closesAt: stamp(now + 3600000), revision: 0, sealed: false, noWinner: false});
  }
  for (const [index, uid] of ['qa-creator-a', 'qa-creator-b', 'qa-viewer', 'qa-creator-a'].entries()) {
    const id = `qa-wall-${index}`;
    const ref = db.doc(`walls/${id}`);
    const challengeId = index === 3 ? state.history : state.active;
    await ref.create({id, creatorUid: uid, email: `${uid}@example.test`, by: uid, uploadedBy: uid, userPhoto: image,
      title: `Local fixture ${index + 1}`, desc: 'ADMIN SEEDED challenge fixture', wallpaper_thumb: image,
      wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
      wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${index}`,
      collections: ['Nature'], category: 'Nature', tags: ['local'], colors: [], review: true, rejected: false,
      resolution: '250x500', size: 'Local fixture', createdAt: stamp(now + index), challengeId, qaFixture: 'ADMIN SEEDED'});
    const snap = await ref.get();
    const entryId = challenge.admissionIdentity(challengeId, id, snap.createTime);
    const base = db.doc(`weeklyChallenges/${challengeId}`);
    await base.collection('admissions').doc(entryId).create({challengeId, wallId: id, createTime: snap.createTime, admitted: true, creatorUid: uid});
    await base.collection('entries').doc(entryId).create({challengeId, wallId: id, wallLogicalId: id, creatorUid: uid,
      createTime: snap.createTime, ownerEmailHash: crypto.createHash('sha256').update(`${uid}@example.test`).digest('hex'),
      state: 'approved', voteCount: 0, approvedAt: null});
    await base.collection('members').doc(uid).set({count: 1});
    await challenge.reconcileChallengeWall(id, challengeId, stamp(now + index), snap.createTime);
    state.entries.push({challengeId, wallId: id, entryId, uid});
  }
  // Use the real voting transaction for initial counts and matching vote subdocuments.
  await challenge.voteChallenge('qa-creator-b', state.active, state.entries[0].entryId, true);
  await challenge.voteChallenge('qa-viewer', state.history, state.entries[3].entryId, true);
  // Admin changes the fixture deadline; actual production schedule/finalizer create history and inbox.
  for (const id of [state.history, state.empty]) await db.doc(`weeklyChallenges/${id}`).update({closesAt: stamp(Date.now())});
  // A non-Monday slot avoids opening an unrelated production calendar slot.
  await challenge.runChallengeSchedule(Date.now(), Date.now());
  state.seededAt = new Date().toISOString();
  console.log(`Real deep links: prism://challenges/${state.active} and prism://challenges/${state.history}`);
  write('state.json', state);
  await evidence();
}
async function evidence() {
  const {db, challenge} = load(runtime);
  const state = read('state.json');
  const active = await challenge.getChallenge(state.active, 'qa-viewer', 'top');
  const newest = await challenge.getChallenge(state.active, 'qa-viewer', 'new');
  assert.equal(active.entries.length, 3);
  assert.equal(newest.entries.length, 3);
  for (const item of state.entries) {
    const wall = await db.doc(`walls/${item.wallId}`).get();
    assert.equal(challenge.admissionIdentity(item.challengeId, item.wallId, wall.createTime), item.entryId);
    const ref = db.doc(`weeklyChallenges/${item.challengeId}/entries/${item.entryId}`);
    const entry = (await ref.get()).data();
    assert.equal(entry.state, 'approved');
    assert.equal(await challenge.challengeIo.ready(item.wallId, []), true, 'Local fixture readiness must pass');
    assert.equal((await challenge.challengeIo.owner(item.uid)).uid, item.uid);
    assert.ok(entry.approvedAt && entry.gateKey);
    assert.equal(entry.voteCount, (await ref.collection('challengeVotes').get()).size);
    assert.equal((await db.doc(`weeklyChallenges/${item.challengeId}/admissions/${item.entryId}`).get()).data().admitted, true);
  }
  const history = (await db.doc(`weeklyChallenges/${state.history}`).get()).data();
  assert.ok(history.winnerEntryId);
  assert.equal((await db.doc(`weeklyChallenges/${state.empty}`).get()).data().noWinner, true);
  const inbox = (await db.doc(`notifications/challenge_winner_${state.history}_qa-creator-a`).get()).data();
  assert.equal(inbox.data.challenge_id, state.history);
  assert.equal(inbox.pushHandled, true);
  const notice = (await db.doc(`challengeNotices/winner_${state.history}_qa-creator-a`).get()).data();
  assert.equal(notice.sent, true);
  assert.equal(notice.pushState, 'disabled');
  if (state.published) {
    assert.equal((await db.doc('wall_of_the_day/current').get()).data().wallId, state.published.wallId);
    assert.equal((await db.doc(`challengeWotdReservations/${state.published.day}`).get()).data().state, 'consumed');
  }
  const callableEvidence = await checkCallables(state);
  const result = {callableEvidence, project: PROJECT, proof: state.proof, checkedAt: new Date().toISOString(),
    top: active, newest, history, notice, inbox, published: state.published || null};
  result.localReadiness = {allFixtureWallsReady: true, allFixtureOwnersVerified: true, productionReadinessProven: false};
  write('evidence.json', result);
  write(`evidence-${active.challenge.state}.json`, result);
  console.log(`Assertions passed; evidence at ${runtime}/evidence.json. This is backend fixture evidence, not device proof.`);
}
async function checkCallables(state) {
  const signIn = await fetch('http://127.0.0.1:19371/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSy000000000000000000000000000000000', {
    method: 'POST', headers: {'content-type': 'application/json'}, signal: AbortSignal.timeout(30000),
    body: JSON.stringify({email: 'qa-viewer@example.test', password: 'local-demo-only-password', returnSecureToken: true})});
  const identity = await signIn.json();
  assert.equal(identity.localId, 'qa-viewer', 'Auth emulator sign-in failed');
  async function call(name, data) {
    const response = await fetch(`http://127.0.0.1:19373/${PROJECT}/us-central1/${name}`, {
      method: 'POST', headers: {'content-type': 'application/json', authorization: `Bearer ${identity.idToken}`}, signal: AbortSignal.timeout(30000),
      body: JSON.stringify({data})});
    const body = await response.json();
    return {status: response.status, ...body};
  }
  const list = await call('listWeeklyChallenges', {kind: 'past'});
  assert.equal(list.status, 200);
  assert.ok(list.result.challenges.some(c => c.id === state.history));
  const page = await call('getWeeklyChallenge', {challengeId: state.active, sort: 'top'});
  assert.equal(page.status, 200);
  assert.equal(page.result.entries.length, 3);
  let vote = null;
  if (page.result.challenge.state === 'open') {
    const entryId = state.entries[1].entryId;
    const previous = page.result.entries.find(e => e.id === entryId).voted;
    const changed = await call('setChallengeVote', {challengeId: state.active, entryId, vote: !previous});
    assert.equal(changed.status, 200);
    const afterChange = await call('getWeeklyChallenge', {challengeId: state.active, sort: 'top'});
    assert.equal(afterChange.result.entries.find(e => e.id === entryId).voted, !previous);
    const restored = await call('setChallengeVote', {challengeId: state.active, entryId, vote: previous});
    assert.equal(restored.status, 200);
    const afterRestore = await call('getWeeklyChallenge', {challengeId: state.active, sort: 'top'});
    assert.equal(afterRestore.result.entries.find(e => e.id === entryId).voted, previous);
    const own = await call('setChallengeVote', {challengeId: state.active, entryId: state.entries[2].entryId, vote: true});
    assert.equal(own.error.status, 'FAILED_PRECONDITION');
    assert.equal(own.error.message, 'own-entry');
    vote = {changed: changed.result, persistedAfterChange: afterChange.result.entries.find(e => e.id === entryId), restored: restored.result, persistedAfterRestore: afterRestore.result.entries.find(e => e.id === entryId), ownRejected: own.error};
  }
  const closed = await call('setChallengeVote', {challengeId: state.history, entryId: state.entries[3].entryId, vote: true});
  assert.equal(closed.error.status, 'FAILED_PRECONDITION');
  return {listStatus: list.status, pageStatus: page.status, vote, closedRejected: closed.error};
}
async function probeAdmission() {
  const {db, challenge} = load(runtime);
  const state = read('state.json');
  const ref = db.doc('walls/qa-upload-probe');
  if (!(await ref.get()).exists) {
    const auth = await fetch('http://127.0.0.1:19371/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local-demo-only', {
      method: 'POST', headers: {'content-type': 'application/json'}, signal: AbortSignal.timeout(30000),
      body: JSON.stringify({email: 'qa-viewer@example.test', password: 'local-demo-only-password', returnSecureToken: true}),
    });
    const identity = await auth.json();
    assert.equal(identity.localId, 'qa-viewer');
    const response = await fetch(`http://127.0.0.1:19372/v1/projects/${PROJECT}/databases/(default)/documents/walls?documentId=qa-upload-probe`, {
      method: 'POST', headers: {'content-type': 'application/json', authorization: `Bearer ${identity.idToken}`},
      signal: AbortSignal.timeout(30000),
      body: JSON.stringify({fields: {id: {stringValue: 'qa-upload-probe'}, email: {stringValue: 'qa-viewer@example.test'},
        review: {booleanValue: false}, challengeId: {stringValue: state.active}}}),
    });
    const body = await response.json();
    write('probe-write.json', {status: response.status, fixtureUid: identity.localId, body});
    assert.equal(response.status, 200, 'Real client write must satisfy current rules');
  }
  const deadline = Date.now() + 30000;
  let observed;
  do {
    observed = (await db.doc('qaEvidence/admissionProbe').get()).data();
    if (observed) break;
    await new Promise(resolve => setTimeout(resolve, 250));
  } while (Date.now() < deadline);
  assert.ok(observed, 'No actual Firestore auth-context event observed within 30 seconds');
  const wall = await ref.get();
  const entryId = challenge.admissionIdentity(state.active, ref.id, wall.createTime);
  const entryExists = (await db.doc(`weeklyChallenges/${state.active}/entries/${entryId}`).get()).exists;
  if (observed.provenance.authId !== 'qa-viewer') {
    assert.equal(observed.admitted, false, 'Wrong event principal must never be admitted');
    assert.equal(entryExists, false);
    assert.equal(wall.data().challengeId, undefined);
  }
  write('admission-probe.json', {signedInFixtureUid: 'qa-viewer', ...observed, entryExists,
    boundary: 'Real authenticated client wall write and unmodified trigger context; no uploaded bytes or full submission proof'});
  console.log(`Actual trigger principal ${observed.provenance.authId}; admitted=${observed.admitted}. See admission-probe.json.`);
}
async function close() {
  const {db, admin, challenge} = load(runtime);
  const state = read('state.json');
  await db.doc(`weeklyChallenges/${state.active}`).update({closesAt: admin.firestore.Timestamp.now()});
  await challenge.runChallengeSchedule(Date.now(), Date.now());
  // Idempotency check calls the actual finalizer again.
  assert.equal(await challenge.finalizeChallenge(state.active), false);
  await evidence();
}
async function publish() {
  const {db, challenge, wotd} = load(runtime);
  const state = read('state.json');
  const history = (await db.doc(`weeklyChallenges/${state.history}`).get()).data();
  const day = history.reservedDate;
  assert.match(day, /^\d{4}-\d{2}-\d{2}$/);
  const pick = await challenge.reservedChallengePick(day, []);
  assert.ok(pick, 'No real reservation candidate');
  assert.equal(await challenge.challengeIo.ready(pick.wallId, []), true);
  const slot = Date.parse(`${day}T03:30:00Z`);
  const committed = await wotd.commitWotdPick(slot, pick.wallId, [], true);
  if (!committed) {
    const current = (await db.doc('wall_of_the_day/current').get()).data();
    assert.equal(current.wallId, pick.wallId);
    assert.equal(current.date.toMillis(), slot);
  }
  state.published = {day, wallId: pick.wallId, slot};
  write('state.json', state);
  await evidence();
  console.log('Published reserved wall with actual commitWotdPick. Date is the reserved fixture day; device clock was not changed.');
}
const commands = {preflight, prepare, emulators, 'build-apk': buildApk, serve, seed, close, 'publish-wotd': publish, 'probe-admission': probeAdmission, assert: evidence};
if (!commands[command]) throw Error('Commands: preflight, prepare, emulators, build-apk, serve, seed, close, publish-wotd, probe-admission, assert');
commands[command]().catch(error => { console.error(error.stack); process.exitCode = 1; });
