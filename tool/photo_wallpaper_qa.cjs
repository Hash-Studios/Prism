#!/usr/bin/env node
'use strict';
// Photo to wallpaper local QA on top of the weekly challenge QA runtime. Commands: prepare, emulators, serve, seed,
// photos, build-apk, build-ios, fail-on, fail-off, ledger.
//
// The real createPhotoWallpaper callable runs in the Functions emulator. Its network is loopback only, so its fal calls
// go to a relay in `serve` (https://localhost:19375/fal/...). The relay sends the first REAL_FAL_LIMIT jobs to fal.ai
// with FAL_API_KEY from its own environment, then answers with a local stub that it labels in ledger.json. Results
// are written to the runtime and served by `serve`. Cloud Vision cannot be reached, so SafeSearch is a stub that
// passes every image.
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, load} = require('./weekly_challenge_qa/backend.cjs');

const runtime = '/tmp/prism-weekly-qa-photo-wall';
const REAL_FAL_LIMIT = 2;
const VIEWER = 'qa-viewer';
const FAL_PRICES = {'fal-ai/bria/expand': () => 0.04, 'fal-ai/seedvr/upscale/image': (w, h) => (w * h) / 1e6 * 0.001};
const file = (name) => path.join(runtime, name);
const readJson = (name, fallback) => (fs.existsSync(file(name)) ? JSON.parse(fs.readFileSync(file(name))) : fallback);
const writeJson = (name, value) => fs.writeFileSync(file(name), JSON.stringify(value, null, 2) + '\n');

function weekly(command) {
  const result = cp.spawnSync('node', [path.join(__dirname, 'weekly_challenge_qa.cjs'), command, '--root', runtime],
    {stdio: 'inherit'});
  if (result.status !== 0) throw Error(`weekly_challenge_qa ${command} exited ${result.status}`);
}

/** Runs inside the Functions emulator. Replaces only the photo job seams: fal transport, storage and SafeSearch. */
function installPhotoSeams(photo, root) {
  const fsm = require('node:fs');
  const p = require('node:path');
  const httpsm = require('node:https');
  const ca = fsm.readFileSync(p.join(root, 'cert.pem'));
  const relay = (method, route, body) => new Promise((resolve, reject) => {
    const req = httpsm.request({host: 'localhost', port: 19375, path: route, method, ca,
      headers: {'content-type': 'application/json'}}, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(new Response(Buffer.concat(chunks), {status: res.statusCode,
        headers: {'content-type': 'application/json', 'x-fal-request-id': res.headers['x-fal-request-id'] || ''}})));
    });
    req.on('error', reject);
    req.setTimeout(170000, () => req.destroy(new Error('relay timeout')));
    if (body) req.write(body);
    req.end();
  });
  photo.photoDeps.fetch = async (url, init = {}) => {
    const target = new URL(url);
    if (target.host === 'fal.run') return relay('POST', `/fal${target.pathname}`, init.body);
    if (target.host === 'api.fal.ai') return relay('DELETE', `/fal-payloads${target.pathname}`);
    throw Error(`Local QA has no route for ${target.host}`);
  };
  photo.photoDeps.falKey = () => 'relay';
  photo.photoDeps.safeSearch = async () => ({adult: 'VERY_UNLIKELY', violence: 'VERY_UNLIKELY', racy: 'VERY_UNLIKELY'});
  photo.photoDeps.store = async (jpeg) => {
    const name = `${require('node:crypto').randomBytes(16).toString('hex')}.jpg`;
    fsm.mkdirSync(p.join(root, 'photo-walls'), {recursive: true});
    fsm.writeFileSync(p.join(root, 'photo-walls', name), jpeg);
    return {url: `https://localhost:19375/photo-walls/${name}`, key: `photo-walls/${name}`};
  };
  photo.photoDeps.remove = async (key) => fsm.rmSync(p.join(root, key), {force: true});
}

async function prepare() {
  assert.ok(fs.existsSync(path.join(__dirname, '../functions/lib/photoWallpaper.js')), 'Run npm run build in functions first');
  weekly('prepare');
  // Only the photo callable. The weekly wrapper's Firestore triggers fire on the seed writes and can stop the
  // Functions emulator, and this flow needs none of them. backend.cjs still installs the loopback port guard.
  fs.writeFileSync(file('functions/index.cjs'), `'use strict';
if (process.env.FUNCTIONS_EMULATOR !== 'true') throw Error('Emulator only');
require('../backend.cjs').load(require('node:path').resolve(__dirname, '..'));
const photo = require('./lib/photoWallpaper.js');
(${installPhotoSeams.toString()})(photo, require('node:path').resolve(__dirname, '..'));
exports.createPhotoWallpaper = photo.createPhotoWallpaper;
`);
  // The callable declares secrets. Without local values the emulator asks Secret Manager, which this runtime blocks.
  // The seams above replace every use of them, so these placeholders never leave the emulator.
  fs.writeFileSync(file('functions/.secret.local'),
    ['FAL_API_KEY', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY'].map((name) => `${name}=local-qa-placeholder\n`).join(''));
  writeJson('ledger.json', []);
  console.log(`Prepared ${runtime}. Next: serve, emulators, seed, photos.`);
}

/** A local stand-in for the model: a blurred fill around the placed photo, or a plain resize. Labelled as a stub. */
async function stubResult(model, body) {
  const sharp = require(path.join(__dirname, '../functions/node_modules/sharp'));
  const input = Buffer.from(String(body.image_url).split(',')[1], 'base64');
  let out;
  if (model === 'fal-ai/bria/expand') {
    const [w, h] = body.canvas_size;
    const [pw, ph] = body.original_image_size;
    const [x, y] = body.original_image_location;
    const fill = await sharp(input).resize(w, h, {fit: 'cover'}).blur(40).toBuffer();
    const placed = await sharp(input).resize(pw, ph, {fit: 'fill'}).toBuffer();
    out = await sharp(fill).composite([{input: placed, left: x, top: y}]).jpeg({quality: 90}).toBuffer();
  } else {
    const meta = await sharp(input).metadata();
    const f = Number(body.upscale_factor) || 2;
    out = await sharp(input).resize(Math.round(meta.width * f), Math.round(meta.height * f), {kernel: 'lanczos3'})
      .jpeg({quality: 90}).toBuffer();
  }
  return {image: {url: `data:image/jpeg;base64,${out.toString('base64')}`}};
}

async function relayFal(model, raw, res) {
  const ledger = readJson('ledger.json', []);
  const body = JSON.parse(raw);
  if (fs.existsSync(file('force-fail'))) {
    ledger.push({at: new Date().toISOString(), model, kind: 'forced-failure', costUsd: 0});
    writeJson('ledger.json', ledger);
    res.writeHead(500, {'content-type': 'application/json'});
    res.end('{"detail":"forced failure for QA"}');
    return;
  }
  const real = ledger.filter((entry) => entry.kind === 'real').length;
  if (real < REAL_FAL_LIMIT && process.env.FAL_API_KEY) {
    const response = await fetch(`https://fal.run/${model}`, {method: 'POST', body: raw, signal: AbortSignal.timeout(160000),
      headers: {'Authorization': `Key ${process.env.FAL_API_KEY}`, 'content-type': 'application/json', 'X-Fal-Store-IO': '0'}});
    const text = await response.text();
    const requestId = response.headers.get('x-fal-request-id') || '';
    let size = null;
    try {
      const image = JSON.parse(text).image;
      size = {width: image.width, height: image.height};
    } catch {
      size = null;
    }
    const costUsd = size ? Math.round(FAL_PRICES[model](size.width, size.height) * 10000) / 10000 : null;
    ledger.push({at: new Date().toISOString(), model, kind: 'real', status: response.status, requestId, size, costUsd});
    writeJson('ledger.json', ledger);
    res.writeHead(response.status, {'content-type': 'application/json', 'x-fal-request-id': requestId});
    res.end(text);
    return;
  }
  const result = await stubResult(model, body);
  ledger.push({at: new Date().toISOString(), model, kind: 'stub', costUsd: 0});
  writeJson('ledger.json', ledger);
  res.writeHead(200, {'content-type': 'application/json', 'x-fal-request-id': `stub-${Date.now().toString(16)}`});
  res.end(JSON.stringify(result));
}

async function relayDelete(route, res) {
  const requestId = route.split('/').filter(Boolean).at(-2);
  const ledger = readJson('ledger.json', []);
  const entry = ledger.find((e) => e.requestId === requestId);
  if (entry && process.env.FAL_API_KEY) {
    const response = await fetch(`https://api.fal.ai/v1/models/requests/${requestId}/payloads`,
      {method: 'DELETE', headers: {'Authorization': `Key ${process.env.FAL_API_KEY}`}, signal: AbortSignal.timeout(10000)});
    entry.payloadDelete = response.status;
    writeJson('ledger.json', ledger);
  }
  res.writeHead(200, {'content-type': 'application/json'});
  res.end('{}');
}

async function serve() {
  const manifest = readJson('manifest.json');
  assert.equal(manifest.project, PROJECT);
  https.createServer({key: fs.readFileSync(file('key.pem')), cert: fs.readFileSync(file('cert.pem'))}, (req, res) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const route = req.url.split('?')[0];
      const done = (error) => { console.error(error); res.writeHead(502); res.end(); };
      if (req.method === 'GET' && route === '/health') { res.end(JSON.stringify(manifest)); return; }
      if (req.method === 'GET' && route === '/wallpaper.jpg') {
        res.setHeader('content-type', 'image/jpeg');
        res.end(fs.readFileSync(file('wallpaper.jpg')));
        return;
      }
      const wall = /^\/photo-walls\/([a-f0-9]{32})\.jpg$/.exec(route);
      if (req.method === 'GET' && wall && fs.existsSync(file(`photo-walls/${wall[1]}.jpg`))) {
        res.setHeader('content-type', 'image/jpeg');
        res.end(fs.readFileSync(file(`photo-walls/${wall[1]}.jpg`)));
        return;
      }
      if (req.method === 'POST' && route.startsWith('/fal/')) {
        relayFal(route.slice('/fal/'.length), Buffer.concat(chunks).toString(), res).catch(done);
        return;
      }
      if (req.method === 'DELETE' && route.startsWith('/fal-payloads/')) { relayDelete(route, res).catch(done); return; }
      res.writeHead(404);
      res.end();
    });
  }).listen(19375, '127.0.0.1', () => console.log(`Photo wallpaper fixtures and fal relay on https://127.0.0.1:19375. ` +
    `Real fal calls left: ${REAL_FAL_LIMIT - readJson('ledger.json', []).filter((e) => e.kind === 'real').length}` +
    `${process.env.FAL_API_KEY ? '' : ' (FAL_API_KEY not set, so every call is a stub)'}.`));
}

/** The viewer with 500 coins, so every job can be paid for. */
async function seed() {
  const {admin, db} = load(runtime);
  try {
    await admin.auth().createUser({uid: VIEWER, email: `${VIEWER}@example.test`, password: 'local-demo-only-password',
      displayName: VIEWER, emailVerified: true});
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
  }
  const now = new Date().toISOString();
  const profile = {id: VIEWER, email: `${VIEWER}@example.test`, username: 'qaviewer', name: 'QA viewer', loggedIn: true,
    createdAt: now, lastLoginAt: now, premium: false, subscriptionTier: 'free', links: {}, followers: [], following: [],
    profilePhoto: 'https://localhost:19375/wallpaper.jpg', coverPhoto: 'https://localhost:19375/wallpaper.jpg',
    bio: 'Local QA fixture', badges: [], subPrisms: [], coins: 500, transactions: [], interestCategories: ['Nature'],
    onboardingV2: {completed: true}};
  await db.doc(`usersv2/${VIEWER}`).set(profile);
  await db.doc(`usersv2/${VIEWER}/private/session`).set({postAlerts: false});
  await db.doc(`profiles/${VIEWER}`).set({...profile, followersCount: 0, followingCount: 0});
  await db.doc('usernames/qaviewer').set({uid: VIEWER});
  console.log(`Seeded ${VIEWER} with 500 coins.`);
}

/** Test photos for the camera roll: a wide landscape, a small phone-shaped photo, and a portrait for the desktop. */
async function photos() {
  const source = process.argv[3];
  assert.ok(source && fs.existsSync(source), 'Pass a real landscape photo: photos <path.jpg>');
  const sharp = require(path.join(__dirname, '../functions/node_modules/sharp'));
  fs.mkdirSync(file('photos'), {recursive: true});
  await sharp(source).rotate().resize(2400, 1600, {fit: 'cover'}).jpeg({quality: 92}).toFile(file('photos/wide-landscape.jpg'));
  await sharp(source).rotate().resize(540, 1170, {fit: 'cover'}).jpeg({quality: 85}).toFile(file('photos/small-phone.jpg'));
  await sharp(source).rotate().resize(1200, 1600, {fit: 'cover'}).jpeg({quality: 92}).toFile(file('photos/portrait.jpg'));
  console.log(`Photos in ${file('photos')}: wide-landscape 2400x1600, small-phone 540x1170, portrait 1200x1600.`);
}

async function ledger() {
  const entries = readJson('ledger.json', []);
  const real = entries.filter((e) => e.kind === 'real');
  console.log(JSON.stringify(entries, null, 2));
  console.log(`Real fal jobs: ${real.length}. Cost: $${real.reduce((sum, e) => sum + (e.costUsd ?? 0), 0).toFixed(4)}.`);
}

/** Swaps in the synthetic iOS config only for the build, then restores the real files. */
async function buildIos() {
  const defines = readJson('dart-defines.json');
  assert.equal(defines.PRISM_LOCAL_QA, 'true');
  const repo = path.resolve(__dirname, '..');
  const swaps = [['native/GoogleService-Info.plist', 'ios/Runner/GoogleService-Info.plist'],
    ['native/Info-LocalQA.plist', 'ios/Runner/Info.plist']].map(([from, to]) => {
    const target = path.join(repo, to);
    return {target, original: fs.existsSync(target) ? fs.readFileSync(target) : null, replacement: fs.readFileSync(file(from))};
  });
  try {
    for (const swap of swaps) fs.writeFileSync(swap.target, swap.replacement);
    const result = cp.spawnSync('fvm', ['flutter', 'build', 'ios', '--debug', '--simulator', '--no-pub',
      `--dart-define-from-file=${file('dart-defines.json')}`], {cwd: repo, stdio: 'inherit'});
    if (result.status !== 0) throw Error(`flutter build ios exited ${result.status}`);
  } finally {
    for (const swap of swaps) {
      if (swap.original) fs.writeFileSync(swap.target, swap.original);
      else fs.rmSync(swap.target, {force: true});
    }
  }
}

const commands = {
  prepare, serve, seed, photos, ledger, 'build-ios': buildIos,
  emulators: () => weekly('emulators'), 'build-apk': () => weekly('build-apk'),
  'fail-on': async () => { fs.writeFileSync(file('force-fail'), ''); console.log('The next fal call fails.'); },
  'fail-off': async () => { fs.rmSync(file('force-fail'), {force: true}); console.log('fal calls run again.'); },
};
const command = process.argv[2];
if (!commands[command]) throw Error(`Commands: ${Object.keys(commands).join(', ')}`);
Promise.resolve(commands[command]()).catch((error) => { console.error(error.stack); process.exitCode = 1; });
