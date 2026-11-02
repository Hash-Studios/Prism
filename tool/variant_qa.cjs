#!/usr/bin/env node
'use strict';
// Colour variant local QA on top of the weekly challenge QA runtime. See tool/variant_qa/README.md.
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, load} = require('./weekly_challenge_qa/backend.cjs');

const repo = path.resolve(__dirname, '..');
const runtime = '/tmp/prism-weekly-qa-variants';
const IMAGE = (name) => `https://localhost:19375/${name}.jpg`;
const COLOURWAYS = [
  {name: 'variant-red', hue: 100, colour: 'red'},
  {name: 'variant-blue', hue: 33, colour: 'blue'},
  {name: 'variant-green', hue: 167, colour: 'green'},
];
const OWNER = 'qa-creator-a';
const OTHER = 'qa-creator-b';

function weekly(command) {
  const result = cp.spawnSync('node', [path.join(__dirname, 'weekly_challenge_qa.cjs'), command, '--root', runtime], {stdio: 'inherit'});
  if (result.status !== 0) throw Error(`weekly_challenge_qa ${command} exited ${result.status}`);
}

/** The weekly runtime, plus the real variant trigger, the real submit check and three colourways of the fixture. */
async function prepare() {
  weekly('prepare');
  const source = path.join(runtime, 'wallpaper.jpg');
  for (const way of COLOURWAYS) {
    cp.execFileSync('magick', [source, '-modulate', `100,140,${way.hue}`, path.join(runtime, `${way.name}.jpg`)]);
  }
  cp.execFileSync('magick', [source, '-gravity', 'center', '-crop', '250x400+0+0', '+repage', '-modulate', '100,140,60',
    path.join(runtime, 'variant-wide.jpg')]);
  fs.appendFileSync(path.join(runtime, 'functions/index.cjs'), `
const variants = require('./lib/wallVariants.js');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
exports.onWallVariantWritten = variants.onWallVariantWritten;
// The variant step of onWallSubmitted. The rest of it pushes to admins, which this runtime cannot reach.
exports.qaVariantSubmitCheck = onDocumentCreated({document: 'walls/{wallId}', region: 'asia-south1'},
  (event) => event.data ? variants.checkSubmittedVariantOf(event.data) : null);
`);
  console.log(`Prepared ${runtime} with the variant trigger and ${COLOURWAYS.length + 1} colourway images.`);
}

async function serve() {
  const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'manifest.json')));
  assert.equal(manifest.project, PROJECT);
  const files = new Set(['wallpaper', 'variant-wide', ...COLOURWAYS.map((way) => way.name)].map((name) => `/${name}.jpg`));
  const server = https.createServer({key: fs.readFileSync(path.join(runtime, 'key.pem')), cert: fs.readFileSync(path.join(runtime, 'cert.pem'))},
    (req, res) => {
      if (req.method !== 'GET' || !files.has(req.url)) { res.writeHead(404); res.end(); return; }
      res.setHeader('content-type', 'image/jpeg');
      res.end(fs.readFileSync(path.join(runtime, req.url.slice(1))));
    });
  server.listen(19375, '127.0.0.1', () => console.log('Variant fixture HTTPS on 127.0.0.1:19375. Ctrl-C stops only this server.'));
}

const until = async (what, check, ms = 30000) => {
  const end = Date.now() + ms;
  for (;;) {
    const value = await check();
    if (value) return value;
    if (Date.now() > end) throw Error(`Timed out waiting for ${what}`);
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
};

/** Users, a root wall, two approved colourways, a wrong shape and another creator's link, through the real triggers. */
async function seed() {
  const {admin, db} = load(runtime);
  const stamp = admin.firestore.Timestamp.fromMillis;
  const now = Date.now();
  for (const uid of ['qa-viewer', OWNER, OTHER]) {
    try {
      await admin.auth().createUser({uid, email: `${uid}@example.test`, password: 'local-demo-only-password', displayName: uid, emailVerified: true});
    } catch (e) {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
    }
    const profile = {id: uid, email: `${uid}@example.test`, username: uid.replaceAll('-', ''), name: uid, loggedIn: true,
      createdAt: new Date(now).toISOString(), lastLoginAt: new Date(now).toISOString(), premium: true, subscriptionTier: 'pro',
      links: {}, followers: [], following: [], profilePhoto: IMAGE('wallpaper'), coverPhoto: IMAGE('wallpaper'), bio: 'Local QA fixture',
      badges: [], subPrisms: [], coins: 0, transactions: [], interestCategories: ['Nature'], onboardingV2: {completed: true}};
    await db.doc(`usersv2/${uid}`).set(profile);
    await db.doc(`usersv2/${uid}/private/session`).set({postAlerts: false});
    await db.doc(`profiles/${uid}`).set({...profile, followersCount: 0, followingCount: 0});
    await db.doc(`usernames/${profile.username.toLowerCase()}`).set({uid});
  }
  const wall = (id, uid, image, extra) => ({id, creatorUid: uid, email: `${uid}@example.test`, by: uid, uploadedBy: uid,
    userPhoto: IMAGE('wallpaper'), title: 'Dusk ridge', desc: 'ADMIN SEEDED colour variant fixture', wallpaper_thumb: IMAGE(image),
    wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '', wallpaper_provider: 'Prism',
    originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'], category: 'Nature', tags: ['local'],
    review: false, rejected: false, resolution: '250x500', size: 'Local fixture', createdAt: stamp(now), qaFixture: 'ADMIN SEEDED', ...extra});
  await db.doc('walls/qa-var-root').create(wall('qa-var-root', OWNER, 'variant-red', {colors: ['red'], review: true}));
  await db.doc('walls/qa-plain').create(wall('qa-plain', OWNER, 'wallpaper', {colors: ['purple'], review: true, title: 'Plain wall'}));
  const variants = [['qa-var-blue', 'variant-blue', 'blue'], ['qa-var-green', 'variant-green', 'green']];
  for (const [id, image, colour] of variants) {
    await db.doc(`walls/${id}`).create(wall(id, OWNER, image, {colors: [colour], variantOf: 'qa-var-root'}));
  }
  await db.doc('walls/qa-var-wide').create(wall('qa-var-wide', OWNER, 'variant-wide',
    {colors: ['orange'], variantOf: 'qa-var-root', resolution: '250x400', title: 'Dusk ridge wide'}));
  await db.doc('walls/qa-var-foreign').create(wall('qa-var-foreign', OTHER, 'variant-green',
    {colors: ['green'], variantOf: 'qa-var-root', title: 'Not my wall'}));
  for (const [id, reason] of [['qa-var-wide', 'aspect_ratio'], ['qa-var-foreign', 'not_owner']]) {
    await until(`${id} drop`, async () => (await db.doc(`walls/${id}`).get()).data()?.variantLink === reason);
  }
  for (const [id] of variants) {
    await db.doc(`walls/${id}`).update({review: true});
    await until(`${id} link`, async () => (await db.doc(`walls/${id}`).get()).data()?.variantLink === 'linked');
  }
  await evidence();
}

async function evidence() {
  const {db} = load(runtime);
  const group = (await db.doc('wallVariantGroups/qa-var-root').get()).data();
  const walls = {};
  for (const id of ['qa-var-root', 'qa-var-blue', 'qa-var-green', 'qa-var-wide', 'qa-var-foreign']) {
    const data = (await db.doc(`walls/${id}`).get()).data() ?? {};
    walls[id] = {review: data.review, variantOf: data.variantOf ?? null, variantGroupId: data.variantGroupId ?? null,
      variantIndex: data.variantIndex ?? null, variantLink: data.variantLink ?? null};
  }
  assert.deepEqual(group?.walls, ['qa-var-root', 'qa-var-blue', 'qa-var-green']);
  assert.deepEqual([walls['qa-var-root'].variantIndex, walls['qa-var-blue'].variantIndex, walls['qa-var-green'].variantIndex], [0, 1, 2]);
  assert.equal(walls['qa-var-wide'].variantLink, 'aspect_ratio');
  assert.equal(walls['qa-var-wide'].variantOf, null);
  assert.equal(walls['qa-var-foreign'].variantLink, 'not_owner');
  fs.writeFileSync(path.join(runtime, 'variant-evidence.json'), JSON.stringify({group: group?.walls, walls}, null, 2) + '\n');
  console.log(`Variant evidence passed: ${path.join(runtime, 'variant-evidence.json')}`);
}

const commands = {prepare, serve, seed, assert: evidence,
  emulators: () => weekly('emulators'), 'build-apk': () => weekly('build-apk')};
const command = process.argv[2];
if (!commands[command]) throw Error(`Commands: ${Object.keys(commands).join(', ')}`);
Promise.resolve(commands[command]()).catch((error) => { console.error(error.stack); process.exitCode = 1; });
