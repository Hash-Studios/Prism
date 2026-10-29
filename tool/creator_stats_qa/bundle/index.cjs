'use strict';
if (process.env.GCLOUD_PROJECT !== 'demo-prism' ||
    process.env.GOOGLE_CLOUD_PROJECT && process.env.GOOGLE_CLOUD_PROJECT !== 'demo-prism') throw new Error('demo-prism only');
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({projectId: 'demo-prism', credential: admin.credential.cert({projectId: 'demo-prism',
  clientEmail: 'local-only@demo-prism.iam.gserviceaccount.com',
  privateKey: require('node:crypto').generateKeyPairSync('rsa', {modulusLength: 2048,
    privateKeyEncoding: {type: 'pkcs8', format: 'pem'}, publicKeyEncoding: {type: 'spki', format: 'pem'}}).privateKey})});
const stats = require('./lib/creatorStats.js');
const history = require('./lib/creatorStatsHistory.js');
exports.getCreatorStats = stats.getCreatorStats;
exports.onCreatorStatsDailyWritten = history.onCreatorStatsDailyWritten;
exports.onCreatorStatsFolderCreated = history.onCreatorStatsFolderCreated;
