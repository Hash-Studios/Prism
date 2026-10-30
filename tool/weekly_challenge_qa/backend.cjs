'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const PROJECT = 'demo-prism';
const PORTS = [19371, 19372, 19373, 19374, 19375];
function guardEnvironment() {
  process.env.METADATA_SERVER_DETECTION = 'none';
  for (const name of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']) {
    if (process.env[name] && process.env[name] !== PROJECT) throw Error(`Refusing ${name} other than ${PROJECT}`);
    process.env[name] = PROJECT;
  }
  for (const [name, value] of Object.entries({FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:19371',
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:19372'})) {
    if (process.env[name] && process.env[name] !== value) throw Error(`Refusing nonlocal ${name}`);
    process.env[name] = value;
  }
  for (const name of ['GOOGLE_APPLICATION_CREDENTIALS', 'FIREBASE_TOKEN', 'GOOGLE_OAUTH_ACCESS_TOKEN', 'CLOUDSDK_AUTH_ACCESS_TOKEN']) {
    if (process.env[name]) throw Error(`Unset ${name} for local QA`);
  }
  if (process.env.FIREBASE_CONFIG) {
    const config = JSON.parse(process.env.FIREBASE_CONFIG);
    if (config.projectId !== PROJECT) throw Error('Refusing non-demo FIREBASE_CONFIG');
  }
  process.env.FIREBASE_CONFIG = JSON.stringify({projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com`});
  // Stop Admin/Google libraries before any nonlocal TCP connection, including raw IP destinations.
  // This protects this Node process only. It is not a device/native SDK network sandbox.
  const original = net.Socket.prototype.connect;
  if (!original.localQaGuard) {
    function localConnect(...args) {
      const first = Array.isArray(args[0]) ? args[0][0] : args[0];
      const options = typeof first === 'object' ? first : {port: first, host: typeof args[1] === 'string' ? args[1] : 'localhost'};
      const host = options.host || 'localhost';
      if (options.path || !['127.0.0.1', 'localhost', '::1'].includes(host) || !PORTS.includes(Number(options.port))) {
        throw Error(`Local QA denied TCP ${host}:${options.port}`);
      }
      return original.apply(this, args);
    }
    localConnect.localQaGuard = true;
    net.Socket.prototype.connect = localConnect;
  }
}
function load(runtime) {
  guardEnvironment();
  const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'manifest.json')));
  if (manifest.project !== PROJECT || manifest.runtime !== fs.realpathSync(runtime)) throw Error('Wrong QA runtime manifest');
  const base = path.join(runtime, 'functions');
  const admin = require(path.join(base, 'node_modules/firebase-admin'));
  if (!admin.apps.length) admin.initializeApp({projectId: PROJECT, credential: admin.credential.cert({
    projectId: PROJECT,
    clientEmail: 'local-qa@demo-prism.iam.gserviceaccount.com',
    privateKey: fs.readFileSync(path.join(runtime, 'key.pem'), 'utf8'),
  })});
  const challenge = require(path.join(base, 'lib/weeklyChallenges.js'));
  const wotd = require(path.join(base, 'lib/wallOfTheDay.js'));
  const db = admin.firestore();
  challenge.challengeIo.premium = async () => [];
  challenge.challengeIo.ready = async (id, premium, supplied) => {
    const wall = supplied || (await db.doc(`walls/${id}`).get()).data();
    const bytes = fs.readFileSync(path.join(runtime, 'wallpaper.jpg'));
    return !!wall && wall.qaFixture === 'ADMIN SEEDED' && wall.review === true &&
      wall.wallpaper_thumb === 'https://localhost:19375/wallpaper.jpg' &&
      crypto.createHash('sha256').update(bytes).digest('hex') === manifest.fixtureSha256 &&
      ['wallpaper_url', 'wallpaper_path', 'wallpaper_sha', 'thumb_path', 'thumb_sha'].every(k => wall[k] === '') &&
      wotd.isWotdEligible(wall, premium);
  };
  // owner and send remain real. Every seeded user has postAlerts=false and no push tokens.
  return {admin, db, challenge, wotd, manifest};
}
module.exports = {PROJECT, PORTS, guardEnvironment, load};
