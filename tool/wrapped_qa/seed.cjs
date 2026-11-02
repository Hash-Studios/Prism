// Seeds Wrapped 2026 signals for the three creator-stats QA accounts on the demo emulators, then the real job builds
// their docs. Run after `bash tool/creator_stats_qa/start.sh demo-prism` and `node tool/creator_stats_qa/seed.cjs
// demo-prism`:
//   node tool/wrapped_qa/seed.cjs demo-prism
// creator = heavy (every card), other = light (cards skipped), empty = not eligible.
const path = require('node:path');
const {execFileSync} = require('node:child_process');

if (process.argv[2] !== 'demo-prism') {
  console.error('Usage: node tool/wrapped_qa/seed.cjs demo-prism');
  process.exit(2);
}
const env = {GCLOUD_PROJECT: 'demo-prism', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080'};
Object.assign(process.env, env);
const functions = path.resolve(__dirname, '../../functions');
const admin = require(path.join(functions, 'node_modules/firebase-admin'));
admin.initializeApp({projectId: 'demo-prism'});
const db = admin.firestore();
const at = (iso) => admin.firestore.Timestamp.fromDate(new Date(`${iso}T09:30:00Z`));

// Public Wallhaven portrait wallpapers (general, SFW, checked by eye) stand in for Prism walls.
const IMAGES = ['9orzex', '7j931e', '8gd69k', 'k81j71', 'mlyr39', 'oggpwp', 'rqgy3j', 'w5mexq', 'w5xom6', 'zpqv8y',
  '8g8kmo', 'lywoxy', 'xezdqv', 'zppjyg'];
const PNG = new Set(['9orzex', '7j931e', 'oggpwp', 'w5xom6']);
const url = (id) => `https://w.wallhaven.cc/full/${id.slice(0, 2)}/wallhaven-${id}.${PNG.has(id) ? 'png' : 'jpg'}`;
const COLOURS = [['blue', 'black'], ['blue', 'purple'], ['black', 'orange'], ['blue', 'teal'], ['blue', 'purple'],
  ['black', 'blue'], ['blue', 'grey'], ['orange', 'green'], ['teal', 'white'], ['blue', 'white'], ['orange', 'green'],
  ['grey', 'black'], ['white', 'grey'], ['teal', 'black']];
const walls = IMAGES.map((image, i) => ({
  id: `QA-WRAP-${i + 1}`,
  thumb: url(image),
  colors: COLOURS[i],
  creatorUid: i < 5 ? 'qa-maya' : `qa-artist-${i}`,
  category: i < 8 ? 'Abstract' : 'Space',
}));

async function seed() {
  const batch = db.batch();
  batch.set(db.doc('profiles/qa-maya'), {username: 'maya.makes', name: 'Maya', profilePhoto: '', followerCount: 0});
  batch.set(db.doc('usersv2/qa-maya'), {id: 'qa-maya', email: 'maya@demo-prism.test', name: 'Maya'});
  for (const wall of walls) {
    batch.set(db.doc(`walls/${wall.id}`), {id: wall.id, review: true, wallpaper_thumb: wall.thumb,
      wallpaper_url: wall.thumb, wallpaper_provider: 'Prism', colors: wall.colors, creatorUid: wall.creatorUid,
      category: wall.category, by: wall.creatorUid === 'qa-maya' ? 'Maya' : 'Artist', title: wall.id,
      createdAt: at('2026-01-05')});
  }
  const save = (uid, wall, i) => batch.set(db.doc(`usersv2/${uid}/images/${wall.id}`), {
    id: wall.id, provider: 'Prism', thumb: wall.thumb, url: wall.thumb, category: wall.category,
    // Saves before 8 Oct 2026 carry only createdAt; later ones carry favouritedAt.
    ...(i % 2 ? {favouritedAt: at(`2026-10-${String(10 + i).padStart(2, '0')}`)} :
      {createdAt: at(`2026-${String(1 + (i % 9)).padStart(2, '0')}-14`)}),
  });
  walls.forEach((wall, i) => save('qa-stats-creator', wall, i));
  // The light user saves one wall per creator, so no creator card.
  walls.slice(4, 14).forEach((wall, i) => save('qa-stats-other', wall, i));
  walls.slice(0, 3).forEach((wall, i) => save('qa-stats-empty', wall, i));

  const claim = (uid, day, n) => batch.set(db.doc(`coinTransactions/qa_${uid}_${n}`), {
    userId: uid, action: 'dailyLogin', delta: 5, type: 'credit', status: 'completed', createdAt: at(day)});
  for (let d = 1; d <= 12; d++) claim('qa-stats-creator', `2026-03-${String(d).padStart(2, '0')}`, d);
  for (let d = 1; d <= 4; d++) claim('qa-stats-other', `2026-06-${String(d).padStart(2, '0')}`, d);
  for (let i = 1; i <= 3; i++) {
    batch.set(db.doc(`aiGenerations/qa_ai_${i}`), {userId: 'qa-stats-creator', createdAt: at(`2026-0${4 + i}-02`),
      imageUrl: url(IMAGES[i + 9]), watermarkedImageUrl: url(IMAGES[i + 9]), status: 'submitted'});
  }
  for (let i = 1; i <= 2; i++) {
    batch.set(db.doc(`folders/qa_folder_${i}`), {ownerId: 'qa-stats-creator', name: `Folder ${i}`,
      createdAt: at('2026-10-28'), covers: [url(IMAGES[12])], itemCount: 6});
  }
  await batch.commit();
  console.log('seeded walls, saves, claims, AI walls and folders for creator, other and empty');
}

seed()
  .then(() => {
    execFileSync('node', ['lib/scripts/buildWrapped.js', '--restart', '--apply'],
      {cwd: functions, env: {...process.env, ...env}, stdio: 'inherit'});
  })
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
