#!/usr/bin/env node
'use strict';
// Seeds the folder sections proof on top of tool/shared_folders_qa.cjs. Run `shared_folders_qa.cjs prepare`,
// `emulators`, `serve` and `seed` first, then `node tool/folder_sections_qa.cjs seed`, then `report` after the
// device steps. Local emulators only: the shared helper's guard refuses any other project.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {PROJECT, guardEnvironment} = require('./weekly_challenge_qa/backend.cjs');

const runtime = '/tmp/prism-shared-folders-qa';
const FOLDER = 'qa-trip';
const CREATOR = 'qa-creator-a';
const VIEWER = 'qa-viewer';
const IMAGE_BASE = 'https://localhost:19375/covers/';
const WALLS = 8;
// Walls 1-3 are dark and quiet, 4-6 dreamy, 7-8 bright. Suggest sections groups them by mood, category and colour.
const LOOKS = [
  {colors: ['black', 'grey'], visionLabels: ['night', 'moon'], category: 'Abstract'},
  {colors: ['black', 'blue'], visionLabels: ['night'], category: 'Abstract'},
  {colors: ['black'], visionLabels: ['darkness'], category: 'Abstract'},
  {colors: ['pink', 'white'], visionLabels: ['sunset', 'cloud'], category: 'Nature'},
  {colors: ['purple', 'pink'], visionLabels: ['sky', 'dusk'], category: 'Nature'},
  {colors: ['blue', 'white'], visionLabels: ['cloud'], category: 'Nature'},
  {colors: ['red', 'orange', 'yellow'], visionLabels: ['abstract'], category: 'Gaming'},
  {colors: ['orange', 'yellow'], visionLabels: ['pattern'], category: 'Gaming'},
];

function loadBackend() {
  guardEnvironment();
  const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'manifest.json'), 'utf8'));
  assert.equal(manifest.project, PROJECT);
  const admin = require(path.join(runtime, 'functions/node_modules/firebase-admin'));
  admin.initializeApp({projectId: PROJECT, credential: admin.credential.cert({
    projectId: PROJECT,
    clientEmail: `local-qa@${PROJECT}.iam.gserviceaccount.com`,
    privateKey: fs.readFileSync(path.join(runtime, 'key.pem'), 'utf8'),
  })});
  return {admin, db: admin.firestore()};
}

async function seed() {
  const {admin, db} = loadBackend();
  const folder = db.doc(`folders/${FOLDER}`);
  assert.ok((await folder.get()).exists, 'Run shared_folders_qa.cjs seed first');
  const fixtures = fs.readdirSync(path.join(runtime, 'fixtures')).sort();
  const image = (index) => IMAGE_BASE + fixtures[index % fixtures.length];
  const stamp = admin.firestore.Timestamp.fromMillis;
  const now = Date.now();
  for (let n = 1; n <= WALLS; n++) {
    const id = `qa-shared-${n}`;
    await db.doc(`walls/${id}`).update(LOOKS[n - 1]);
    await folder.collection('items').doc(`prism_${id}`).set({id, url: image(n - 1), thumb: image(n - 1), provider: 'Prism',
      category: LOOKS[n - 1].category, views: '', resolution: '250x500', fav: '', size: '', photographer: 'Ana QA',
      collections: ['community'], createdAt: stamp(now - 3600000), favouritedAt: stamp(now - 3600000),
      ownerId: CREATOR, addedBy: CREATOR, addedAt: stamp(now - (WALLS - n + 1) * 60000), wallpaperDocumentId: id});
  }
  // Riya joins as an editor, the way joinFolder writes members and memberIds.
  await folder.update({itemCount: WALLS, covers: [8, 7, 6, 5].map((n) => image(n - 1)), updatedAt: stamp(now),
    members: {[VIEWER]: {addedBy: CREATOR, addedAt: stamp(now - 600000)}}, memberIds: [VIEWER], sections: []});
  console.log(`Seeded ${WALLS} walls in ${FOLDER}, all in Unsorted, with ${VIEWER} as an editor. No sections yet.`);
}

// Prints the folder as the devices left it, so the proof can quote the stored sections and moves.
async function report() {
  const {db} = loadBackend();
  const folder = (await db.doc(`folders/${FOLDER}`).get()).data();
  const items = await db.collection(`folders/${FOLDER}/items`).get();
  console.log(JSON.stringify({sections: folder.sections ?? [], items: Object.fromEntries(items.docs.map((d) =>
    [d.id, d.data().sectionId ?? null]))}, null, 2));
}

const commands = {seed, report};
const command = process.argv[2];
if (!commands[command]) throw Error('Commands: seed, report');
commands[command]().catch((error) => { console.error(error.stack); process.exitCode = 1; });
