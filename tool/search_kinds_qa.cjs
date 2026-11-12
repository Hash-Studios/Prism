#!/usr/bin/env node
/*
 * Search kind filters local QA. ADMIN SEEDED fixtures on the demo-prism emulators only.
 *
 * It reuses the scheduled release runtime for the emulators, users, fixture images and the app build:
 *   node tool/search_kinds_qa.cjs preflight | prepare | emulators | seed | build-ios | build-apk | serve
 * Then it adds the kind walls:
 *   node tool/search_kinds_qa.cjs seed-kinds
 *
 * seed-kinds writes 2 live walls, 2 desktop walls, 1 live wall with a desktop version, a 2-wall colour variant set and
 * 1 live wall that waits for its release time (review false). The last one must never show in search.
 * Every kind wall has the search term "sky".
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {PROJECT, guardEnvironment} = require('./weekly_challenge_qa/backend.cjs');

const runtime = '/tmp/prism-scheduled-release-qa-kinds';
const IMAGE_BASE = 'https://localhost:19375/previews/';
const CREATOR = 'qa-creator-a';

function base(command, extra = []) {
  const result = cp.spawnSync('node', [path.join(__dirname, 'scheduled_release_qa.cjs'), command, '--root', runtime, ...extra],
    {stdio: 'inherit'});
  if (result.status !== 0) throw Error(`scheduled_release_qa ${command} exited ${result.status}`);
}

function loadBackend() {
  guardEnvironment();
  const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'manifest.json')));
  assert.equal(manifest.project, PROJECT);
  const admin = require(path.join(runtime, 'functions/node_modules/firebase-admin'));
  admin.initializeApp({projectId: PROJECT, credential: admin.credential.cert({
    projectId: PROJECT,
    clientEmail: `local-qa@${PROJECT}.iam.gserviceaccount.com`,
    privateKey: fs.readFileSync(path.join(runtime, 'key.pem'), 'utf8'),
  })});
  return {admin, db: admin.firestore()};
}

// [id, title, kind fields, review]. Protected fields follow the base harness.
function kindWalls(image) {
  const live = (id) => ({kind: 'live', live: {video: `${IMAGE_BASE}${id}.mp4`, videoPath: `qa/${id}.mp4`, videoSha: 'qa',
    frames: [], durationMs: 4000, width: 1080, height: 1920, codec: 'h264', bytes: 1000, loop: true, verified: true}});
  const desktop = (index) => ({desktopVariant: {v: '0123456789abcdef', width: 2560, height: 1600, wideHeight: 1600,
    thumb: image(index)}});
  return [
    ['qa-kind-live-1', 'Live sky one', live('qa-kind-live-1'), true],
    ['qa-kind-live-2', 'Live sky two', live('qa-kind-live-2'), true],
    ['qa-kind-desktop-1', 'Desktop sky one', desktop(2), true],
    ['qa-kind-desktop-2', 'Desktop sky two', desktop(3), true],
    ['qa-kind-live-desktop', 'Live desktop sky', {...live('qa-kind-live-desktop'), ...desktop(4)}, true],
    ['qa-kind-pair-a', 'Pair sky blue', {variantGroupId: 'qa-kind-pair-a', variantIndex: 0, colors: ['blue']}, true],
    ['qa-kind-pair-b', 'Pair sky orange', {variantGroupId: 'qa-kind-pair-a', variantIndex: 1, colors: ['orange']}, true],
    ['qa-kind-live-scheduled', 'Scheduled live sky', live('qa-kind-live-scheduled'), false],
  ];
}

async function seedKinds() {
  const {admin, db} = loadBackend();
  const fixtures = fs.readdirSync(path.join(runtime, 'fixtures')).sort();
  assert.ok(fixtures.length > 0, 'Run prepare first');
  const image = (index) => IMAGE_BASE + fixtures[index % fixtures.length];
  const now = Date.now();
  const stamp = admin.firestore.Timestamp.fromMillis;
  for (const [index, [id, title, kind, review]] of kindWalls(image).entries()) {
    assert.equal((await db.doc(`walls/${id}`).get()).exists, false, 'Refusing to overwrite seeded walls; restart the emulators');
    await db.doc(`walls/${id}`).set({id, creatorUid: CREATOR, email: `${CREATOR}@example.test`, by: 'Ana QA',
      uploadedBy: CREATOR, userPhoto: image(index), title, desc: 'ADMIN SEEDED search kind fixture',
      wallpaper_thumb: image(index), wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '',
      wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: `qa-object-${id}`, collections: ['community'],
      category: 'Nature', tags: ['sky'], colors: ['blue'], searchTerms: ['sky', 'qa'], review, rejected: false,
      resolution: '1080x2340', size: 'Local fixture', createdAt: stamp(now - index * 60000), qaFixture: 'ADMIN SEEDED',
      ...(review ? {} : {releaseApprovedAt: stamp(now), releaseAt: stamp(now + 86400000)}), ...kind});
  }
  console.log(`Seeded ${kindWalls(image).length} kind walls. qa-kind-live-scheduled is unreleased and must not show.`);
}

const passThrough = ['preflight', 'prepare', 'emulators', 'seed', 'serve'];
const command = process.argv[2];
const run = command === 'seed-kinds'
  ? seedKinds
  : passThrough.includes(command)
    ? async () => base(command)
    : command === 'build-ios' || command === 'build-apk'
      ? async () => base(command, ['--user', 'follower'])
      : null;
if (!run) throw Error(`Commands: ${[...passThrough, 'build-ios', 'build-apk', 'seed-kinds'].join(', ')}`);
run().catch((error) => { console.error(error.stack); process.exitCode = 1; });
