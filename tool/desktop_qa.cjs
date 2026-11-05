#!/usr/bin/env node
'use strict';
// Creator desktop version local QA on top of the weekly challenge QA runtime. See tool/desktop_qa/README.md.
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, load} = require('./weekly_challenge_qa/backend.cjs');

const runtime = '/tmp/prism-weekly-qa-desktop';
const PREVIEW = 'https://localhost:19375';
const IMAGE = (name) => `${PREVIEW}/${name}.jpg`;
const CREATOR = 'qa-creator-a';
const ADMIN = 'qa-admin';
/** Gallery fixtures for the picker: two good uploads and two that the app refuses before upload. */
const UPLOADS = [
  {name: 'desktop-dusk-1610', size: '2560x1600', hue: 100},
  {name: 'desktop-dawn-169', size: '1920x1080', hue: 40},
  {name: 'desktop-portrait', size: '1080x1920', hue: 160},
  {name: 'desktop-small', size: '1600x1000', hue: 70},
];

function weekly(command) {
  const result = cp.spawnSync('node', [path.join(__dirname, 'weekly_challenge_qa.cjs'), command, '--root', runtime], {stdio: 'inherit'});
  if (result.status !== 0) throw Error(`weekly_challenge_qa ${command} exited ${result.status}`);
}

/**
 * The weekly runtime plus the real desktop callables. R2 is a folder in the runtime, and previews are served by
 * `serve`, because the production preview base cannot carry the fixture port.
 */
async function prepare() {
  weekly('prepare');
  const source = path.join(runtime, 'wallpaper.jpg');
  for (const upload of UPLOADS) {
    cp.execFileSync('magick', [source, '-resize', `${upload.size}^`, '-gravity', 'center', '-extent', upload.size,
      '-modulate', `100,140,${upload.hue}`, path.join(runtime, `${upload.name}.jpg`)]);
  }
  fs.mkdirSync(path.join(runtime, 'r2'));
  fs.writeFileSync(path.join(runtime, 'functions/.secret.local'), 'R2_ACCESS_KEY_ID=local-qa\nR2_SECRET_ACCESS_KEY=local-qa\n');
  fs.appendFileSync(path.join(runtime, 'functions/index.cjs'), `
Object.assign(process.env, {R2_ACCOUNT_ID: '${'a'.repeat(32)}', R2_ACCESS_KEY_ID: 'local-qa', R2_SECRET_ACCESS_KEY: 'local-qa',
  R2_PRIVATE_BUCKET: 'qa-private', R2_PREVIEW_BUCKET: 'qa-preview', R2_PREVIEW_BASE_URL: 'https://localhost'});
(${installDesktopSeams.toString()})(require('node:path').resolve(__dirname, '..'), '${PREVIEW}');
const desktop = require('./lib/desktopSubmissions.js');
exports.submitDesktopVersion = desktop.submitDesktopVersion;
exports.reviewDesktopSubmission = desktop.reviewDesktopSubmission;
`);
  console.log(`Prepared ${runtime} with the desktop callables and ${UPLOADS.length} gallery fixtures.`);
}

/** Runs inside the functions emulator: R2 objects become files, and preview URLs point at the fixture server. */
function installDesktopSeams(root, previewBase) {
  const fs = require('node:fs');
  const path = require('node:path');
  const crypto = require('node:crypto');
  const r2 = require(path.join(root, 'functions/lib/r2Storage.js'));
  const gallery = require(path.join(root, 'functions/lib/pushGallery.js'));
  const studio = require(path.join(root, 'functions/lib/studio/desktop.js'));
  const file = (kind, object) => {
    const target = path.resolve(root, 'r2', kind, object);
    if (!target.startsWith(path.join(root, 'r2', kind) + path.sep)) throw Error('R2 object escapes the runtime');
    return target;
  };
  r2.R2Storage.prototype.put = async function (kind, object, bytes, metadata) {
    const target = file(kind, object);
    if (fs.existsSync(target)) return false;
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.writeFileSync(target, bytes);
    fs.writeFileSync(`${target}.sha256`, metadata.sha256 || '');
    return true;
  };
  r2.R2Storage.prototype.head = async function (kind, object) {
    const target = file(kind, object);
    if (!fs.existsSync(target)) return null;
    return {size: fs.statSync(target).size, sha256: fs.readFileSync(`${target}.sha256`, 'utf8')};
  };
  r2.R2Storage.prototype.delete = async function (kind, object) {
    const target = file(kind, object);
    fs.rmSync(target, {force: true});
    fs.rmSync(`${target}.sha256`, {force: true});
  };
  studio.desktopThumbUrl = (shareId, sha) =>
    `${previewBase}/previews/desktop-${crypto.createHash('sha256').update(`${shareId}\0${sha}`).digest('hex')}.jpg`;
  gallery.isPreviewUrl = (url) => typeof url === 'string' && url.startsWith(`${previewBase}/previews/`);
}

async function serve() {
  const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'manifest.json')));
  assert.equal(manifest.project, PROJECT);
  const fixtures = new Set(['wallpaper', ...UPLOADS.map((upload) => upload.name)].map((name) => `/${name}.jpg`));
  const server = https.createServer({key: fs.readFileSync(path.join(runtime, 'key.pem')), cert: fs.readFileSync(path.join(runtime, 'cert.pem'))},
    (req, res) => {
      const preview = /^\/previews\/desktop-[a-f0-9]{64}\.jpg$/.test(req.url ?? '');
      if (req.method !== 'GET' || (!fixtures.has(req.url) && !preview)) { res.writeHead(404); res.end(); return; }
      const target = preview ? path.join(runtime, 'r2/preview', req.url.slice(1)) : path.join(runtime, req.url.slice(1));
      if (!fs.existsSync(target)) { res.writeHead(404); res.end(); return; }
      res.setHeader('content-type', 'image/jpeg');
      res.end(fs.readFileSync(target));
    });
  server.listen(19375, '127.0.0.1', () => console.log('Desktop fixture HTTPS on 127.0.0.1:19375. Ctrl-C stops only this server.'));
}

/** The creator, the admin and two approved walls of the creator: one for approve, one for reject. */
async function seed() {
  const {admin, db} = load(runtime);
  const now = Date.now();
  for (const uid of [CREATOR, ADMIN]) {
    try {
      await admin.auth().createUser({uid, email: `${uid}@example.test`, password: 'local-demo-only-password', displayName: uid, emailVerified: true});
    } catch (e) {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
    }
    const profile = {id: uid, email: `${uid}@example.test`, username: uid.replaceAll('-', ''), name: uid === ADMIN ? 'QA Admin' : 'Noor QA',
      loggedIn: true, createdAt: new Date(now).toISOString(), lastLoginAt: new Date(now).toISOString(), premium: true,
      subscriptionTier: 'pro', links: {}, followers: [], following: [], profilePhoto: IMAGE('wallpaper'), coverPhoto: IMAGE('wallpaper'),
      bio: 'Local QA fixture', badges: [], subPrisms: [], coins: 0, transactions: [], interestCategories: ['Nature'],
      onboardingV2: {completed: true}};
    await db.doc(`usersv2/${uid}`).set(profile);
    await db.doc(`usersv2/${uid}/private/session`).set({postAlerts: false});
    await db.doc(`profiles/${uid}`).set({...profile, followersCount: 0, followingCount: 0});
    await db.doc(`usernames/${profile.username.toLowerCase()}`).set({uid});
  }
  await admin.auth().setCustomUserClaims(ADMIN, {admin: true});
  await db.doc(`admin_users/${ADMIN}@example.test`).set({email: `${ADMIN}@example.test`});
  const wall = (id, title) => ({id, creatorUid: CREATOR, email: `${CREATOR}@example.test`, by: 'Noor QA', uploadedBy: CREATOR,
    userPhoto: IMAGE('wallpaper'), title, desc: 'ADMIN SEEDED desktop fixture', wallpaper_thumb: IMAGE('wallpaper'),
    wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '', wallpaper_provider: 'Prism',
    originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'], category: 'Nature', tags: ['local'],
    review: true, rejected: false, resolution: '1080x2340', size: 'Local fixture',
    createdAt: admin.firestore.Timestamp.fromMillis(now), qaFixture: 'ADMIN SEEDED'});
  await db.doc('walls/qa-desk-approve').set(wall('QADESKA001', 'Dusk ridge'));
  await db.doc('walls/qa-desk-reject').set(wall('QADESKR001', 'Quiet dunes'));
  console.log(`Seeded ${CREATOR}, ${ADMIN} (admin claim), walls/qa-desk-approve and walls/qa-desk-reject.`);
}

/** Pushes the gallery fixtures to the emulator, so the picker can choose them. */
function gallery() {
  const serial = process.env.ANDROID_SERIAL || 'emulator-5554';
  for (const upload of UPLOADS) {
    const remote = `/sdcard/Pictures/${upload.name}.jpg`;
    cp.execFileSync('adb', ['-s', serial, 'push', path.join(runtime, `${upload.name}.jpg`), remote], {stdio: 'inherit'});
    cp.execFileSync('adb', ['-s', serial, 'shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
      '-d', `file://${remote}`], {stdio: 'inherit'});
  }
}

/** What the server holds now: each submission, the wall link and the stored objects. */
async function evidence() {
  const {db} = load(runtime);
  const submissions = (await db.collection('desktopSubmissions').get()).docs.map((doc) => ({id: doc.id, wallDocId: doc.data().wallDocId,
    state: doc.data().state, reason: doc.data().reason ?? null, v: doc.data().original?.sha256?.slice(0, 16) ?? null}));
  const walls = {};
  for (const id of ['qa-desk-approve', 'qa-desk-reject']) walls[id] = (await db.doc(`walls/${id}`).get()).data()?.desktopVariant ?? null;
  const objects = [];
  const walk = (dir) => {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (!entry.name.endsWith('.sha256')) objects.push(path.relative(path.join(runtime, 'r2'), full));
    }
  };
  walk(path.join(runtime, 'r2'));
  const inbox = (await db.collection('notifications').where('modifier', '==', `${CREATOR}@example.test`).get()).docs
    .map((doc) => ({kind: doc.data().message?.kind, body: doc.data().notification?.body}));
  const result = {submissions, walls, objects: objects.sort(), inbox};
  fs.writeFileSync(path.join(runtime, 'desktop-evidence.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
}

const withUser = (user) => () => {
  const file = path.join(runtime, 'dart-defines.json');
  fs.writeFileSync(file, JSON.stringify({...JSON.parse(fs.readFileSync(file)), PRISM_LOCAL_QA_USER: user}, null, 2) + '\n');
  weekly('build-apk');
  const apk = path.join(path.resolve(__dirname, '..'), 'build/app/outputs/flutter-apk/app-debug.apk');
  fs.copyFileSync(apk, path.join(runtime, `prism-${user}.apk`));
  console.log(`Built ${path.join(runtime, `prism-${user}.apk`)}`);
};

const commands = {prepare, serve, seed, gallery, evidence, emulators: () => weekly('emulators'),
  'build-creator': withUser('creator'), 'build-admin': withUser('admin')};
const command = process.argv[2];
if (!commands[command]) throw Error(`Commands: ${Object.keys(commands).join(', ')}`);
Promise.resolve(commands[command]()).catch((error) => { console.error(error.stack); process.exitCode = 1; });
