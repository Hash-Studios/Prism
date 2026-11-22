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
const daily = require('./lib/creatorStatsDaily.js');
exports.getCreatorStats = stats.getCreatorStats;
exports.onCreatorStatsDailyWritten = daily.onCreatorStatsDailyWritten;
exports.onCreatorStatsFolderCreated = history.onCreatorStatsFolderCreated;
exports.tipCreator = require('./fnlib/tips.js').tipCreator;
exports.getCreatorFundStatus = require('./fnlib/creatorFund/status.js').getCreatorFundStatus;
const comments = require('./fnlib/comments.js');
exports.addComment = comments.addComment;
exports.deleteComment = comments.deleteComment;
exports.setCommentHidden = comments.setCommentHidden;
exports.submitContentReport = require('./fnlib/submitContentReport.js').submitContentReport;
// Creator premium walls. The emulator has no R2, so the stored-upload identity checks read a seeded manifest instead
// (seed_creator_walls.cjs). Those checks keep their unit tests; the purchase transaction below is the real code.
const owned = require('./fnlib/ownedAssetDelivery.js');
owned.stored = (value) => !!value && typeof value === 'object' && value.qaSeeded === true;
owned.verifyStoredUploadRegistry = async (asset) => {
  if (!asset || asset.qaSeeded !== true) throw new Error('Not a seeded QA asset');
};
owned.ownedThumbnailUrl = (asset) => asset.qaThumbUrl;
const creatorWalls = require('./fnlib/creatorWalls.js');
exports.setWallPrice = creatorWalls.setWallPrice;
exports.unlockCreatorWall = creatorWalls.unlockCreatorWall;
// The approved-wall editor loads and saves metadata through these. The creator prices the wall from that editor.
const wallMetadata = require('./fnlib/wallMetadata.js');
exports.getWallMetadataForEdit = wallMetadata.getWallMetadataForEdit;
exports.editWallMetadata = wallMetadata.editWallMetadata;
