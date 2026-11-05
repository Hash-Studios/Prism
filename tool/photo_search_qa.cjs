#!/usr/bin/env node
'use strict';
// Search by photo local QA on top of the weekly challenge QA runtime. Commands: prepare, emulators, serve, seed,
// build-apk, cap, uncap. The runtime blocks all nonlocal network, so Cloud Vision is replaced by a stub that names
// what a photo shows from its mean colour. Every result screenshot from this runtime shows stub labels.
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, load} = require('./weekly_challenge_qa/backend.cjs');

const runtime = '/tmp/prism-weekly-qa-photo';
const IMAGE = (name) => `https://localhost:19375/${name}.jpg`;
const PALETTE = ['cc0000', 'ff6600', 'ffcc33', '669900', '66cccc', '0066cc', '663399', 'ea4c88', '663300', '000000',
  '999999', 'ffffff'];
const VIEWER = 'qa-viewer';

// Prism walls: [id, title, colours, gradient, labels]. The gradient is a magick gradient spec for the fixture image.
const WALLS = [
  ['qa-sunset-dunes', 'Dusk dunes', ['orange', 'pink', 'purple'], '#ff7a1a-#c2185b', ['Sky', 'Sunset', 'Afterglow']],
  ['qa-sunset-sea', 'Red sea evening', ['red', 'orange'], '#d81b1b-#ff8a00', ['Sunset', 'Sea', 'Evening']],
  ['qa-orange-abstract', 'Orange fold', ['orange'], '#ff6a00-#ffb000', ['Abstract', 'Pattern']],
  ['qa-green-room', 'Fern room', ['green', 'brown'], '#3f6f2a-#7a4a1f', ['Room', 'Interior design', 'Houseplant']],
  ['qa-green-forest', 'Moss forest', ['green'], '#1f4d1a-#6a9a2a', ['Forest', 'Tree', 'Green']],
  ['qa-neon-street', 'Neon alley', ['black', 'pink', 'purple'], '#0a0a12-#e0287a', ['Neon', 'Night', 'Street']],
  ['qa-neon-city', 'Cyan night', ['black', 'teal'], '#05060a-#3fd0d0', ['City', 'Night', 'Light']],
  ['qa-blue-calm', 'Blue calm', ['blue'], '#0a3d91-#4a8fe0', ['Water', 'Blue']],
  ['qa-grey-stone', 'Grey stone', ['grey', 'white'], '#7a7a7a-#e6e6e6', ['Rock', 'Texture']],
];

// The test photos for the camera roll: [file, magick arguments].
const PHOTOS = [
  ['photo-sunset.jpg', ['-size', '1200x1600', 'gradient:#ffb347-#ff5e3a', '(', '-size', '1200x700', 'gradient:#ff5e3a-#7b2d8b', ')',
    '-append', '-fill', '#ffe08a', '-draw', 'circle 600,1250 600,1130', '-fill', '#2a1430', '-draw',
    'polygon 0,1900 300,1650 650,1820 900,1600 1200,1760 1200,2300 0,2300', '-resize', '1200x1600!']],
  ['photo-green-room.jpg', ['-size', '1200x1600', 'xc:#4f7a3a', '-fill', '#7a4e26', '-draw', 'rectangle 0,1150 1200,1600',
    '-fill', '#d8e6c8', '-draw', 'rectangle 380,250 820,800', '-fill', '#2f5a24', '-draw', 'circle 220,1000 220,820',
    '-fill', '#5a3418', '-draw', 'rectangle 180,1000 260,1150']],
  ['photo-neon-street.jpg', ['-size', '1200x1600', 'xc:#07070d', '-fill', '#ff2fa0', '-draw', 'rectangle 120,300 520,420',
    '-fill', '#29e6ff', '-draw', 'rectangle 650,520 1080,620', '-fill', '#b04cff', '-draw', 'rectangle 200,820 900,900',
    '-fill', '#ff2fa0', '-draw', 'rectangle 760,1050 1000,1400', '-blur', '0x6', '-fill', '#14141f', '-draw',
    'polygon 0,1600 450,1150 750,1150 1200,1600']],
];

function weekly(command) {
  const result = cp.spawnSync('node', [path.join(__dirname, 'weekly_challenge_qa.cjs'), command, '--root', runtime], {stdio: 'inherit'});
  if (result.status !== 0) throw Error(`weekly_challenge_qa ${command} exited ${result.status}`);
}

const magick = (args) => cp.execFileSync('magick', args);

/** The weekly runtime, plus the real photoSearchLabels callable with a Vision stub, fixture walls and the photos. */
async function prepare() {
  assert.ok(fs.existsSync(path.join(__dirname, '../functions/lib/photoSearchLabels.js')), 'Run npm run build in functions first');
  weekly('prepare');
  for (const [id, , , gradient] of WALLS) magick(['-size', '540x960', `gradient:${gradient}`, path.join(runtime, `${id}.jpg`)]);
  for (const hex of PALETTE) {
    for (let i = 1; i <= 6; i++) {
      magick(['-size', '540x960', `gradient:#${hex}-#${hex}`, '-modulate', `${80 + i * 6},100,100`, '-fill', '#ffffff22',
        '-draw', `circle ${90 * i},${160 * i} ${90 * i + 60},${160 * i}`, path.join(runtime, `wh-${hex}-${i}.jpg`)]);
    }
  }
  fs.mkdirSync(path.join(runtime, 'photos'));
  for (const [file, args] of PHOTOS) magick([...args, '-quality', '92', path.join(runtime, 'photos', file)]);
  fs.appendFileSync(path.join(runtime, 'functions/index.cjs'), `
// Cloud Vision cannot be reached from this runtime. The stub names the photo from its mean colour.
const wallCategory = require('./lib/wallCategory.js');
wallCategory.detectLabelsInImage = async (bytes) => {
  const {channels: [r, g, b]} = await require('sharp')(bytes).stats();
  if (r.mean < 70 && g.mean < 70 && b.mean < 80) return ['Neon', 'Night', 'Street', 'Light', 'City'];
  if (g.mean > r.mean && g.mean > b.mean) return ['Room', 'Interior design', 'Houseplant', 'Green', 'Wall'];
  if (r.mean > b.mean) return ['Sky', 'Sunset', 'Afterglow', 'Cloud', 'Evening'];
  return ['Blue', 'Water'];
};
exports.photoSearchLabels = require('./lib/photoSearchLabels.js').photoSearchLabels;
`);
  console.log(`Prepared ${runtime}: ${WALLS.length} walls, ${PALETTE.length * 6} colour fixtures, photos in ${runtime}/photos.`);
}

async function serve() {
  const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'manifest.json')));
  assert.equal(manifest.project, PROJECT);
  const files = new Set(fs.readdirSync(runtime).filter((name) => name.endsWith('.jpg')).map((name) => `/${name}`));
  https.createServer({key: fs.readFileSync(path.join(runtime, 'key.pem')), cert: fs.readFileSync(path.join(runtime, 'cert.pem'))},
    (req, res) => {
      if (req.method === 'GET' && req.url === '/health') {
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify(manifest));
        return;
      }
      if (req.method !== 'GET' || !files.has(req.url)) { res.writeHead(404); res.end(); return; }
      res.setHeader('content-type', 'image/jpeg');
      res.end(fs.readFileSync(path.join(runtime, req.url.slice(1))));
    }).listen(19375, '127.0.0.1', () => console.log(`Photo search fixtures (${files.size}) on https://127.0.0.1:19375.`));
}

/** The viewer and the fixture walls, with colours and search terms written the way the backend writes them. */
async function seed() {
  const {admin, db} = load(runtime);
  const {wallSearchTermsFor} = require(path.join(runtime, 'functions/lib/wallSearchTerms.js'));
  const now = Date.now();
  try {
    await admin.auth().createUser({uid: VIEWER, email: `${VIEWER}@example.test`, password: 'local-demo-only-password',
      displayName: VIEWER, emailVerified: true});
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
  }
  const profile = {id: VIEWER, email: `${VIEWER}@example.test`, username: 'qaviewer', name: 'QA viewer', loggedIn: true,
    createdAt: new Date(now).toISOString(), lastLoginAt: new Date(now).toISOString(), premium: false, subscriptionTier: 'free',
    links: {}, followers: [], following: [], profilePhoto: IMAGE('qa-blue-calm'), coverPhoto: IMAGE('qa-blue-calm'),
    bio: 'Local QA fixture', badges: [], subPrisms: [], coins: 0, transactions: [], interestCategories: ['Nature'],
    onboardingV2: {completed: true}};
  await db.doc(`usersv2/${VIEWER}`).set(profile);
  await db.doc(`usersv2/${VIEWER}/private/session`).set({postAlerts: false});
  await db.doc(`profiles/${VIEWER}`).set({...profile, followersCount: 0, followingCount: 0});
  await db.doc('usernames/qaviewer').set({uid: VIEWER});
  for (const [i, [id, title, colors, , labels]] of WALLS.entries()) {
    const wall = {id, title, colors, visionLabels: labels, tags: [], category: 'General', desc: '', by: 'QA creator',
      creatorUid: 'qa-creator', email: 'qa-creator@example.test', uploadedBy: 'qa-creator', userPhoto: IMAGE('qa-grey-stone'),
      wallpaper_thumb: IMAGE(id), wallpaper_url: IMAGE(id), wallpaper_provider: 'Prism', collections: ['community'],
      review: true, rejected: false, resolution: '1080x1920', size: 'Local fixture', qaFixture: 'ADMIN SEEDED',
      createdAt: admin.firestore.Timestamp.fromMillis(now - i * 60000)};
    await db.doc(`walls/${id}`).set({...wall, searchTerms: wallSearchTermsFor(wall)});
  }
  console.log(`Seeded ${VIEWER} and ${WALLS.length} walls.`);
}

/** Uses up the viewer's photo searches for today, so the next one shows the capped note. */
async function cap() {
  const {admin, db} = load(runtime);
  await db.doc(`photoSearchRate/${VIEWER}`).set({day: new Date().toISOString().slice(0, 10), count: 20, results: {},
    expireAt: admin.firestore.Timestamp.fromMillis(Date.now() + 2 * 86400000)});
  console.log(`${VIEWER} is at the daily cap.`);
}

async function uncap() {
  const {db} = load(runtime);
  await db.doc(`photoSearchRate/${VIEWER}`).delete();
  console.log(`${VIEWER} has no photo searches today.`);
}

const commands = {prepare, serve, seed, cap, uncap, emulators: () => weekly('emulators'), 'build-apk': () => weekly('build-apk')};
const command = process.argv[2];
if (!commands[command]) throw Error(`Commands: ${Object.keys(commands).join(', ')}`);
Promise.resolve(commands[command]()).catch((error) => { console.error(error.stack); process.exitCode = 1; });
