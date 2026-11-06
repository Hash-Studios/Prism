// Runs the real topic digest job on the Firestore emulator and saves what it sends, for device proof.
// A QA user follows Pastel and Dreamy; two Pastel walls are approved; the job runs twice (the second run must send
// nothing). FCM and R2 are replaced: the FCM message and the rendered gallery JPEGs are written to <out dir>.
// Run from the repo root after `cd functions && npm run build`:
//   firebase emulators:exec --only firestore --project demo-prism "node tool/qa_topic_digest.mjs /tmp/topic-qa"
import {mkdirSync, writeFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {basename, join, resolve} from 'node:path';

const out = resolve(process.argv[2] ?? '/tmp/topic-qa');
mkdirSync(out, {recursive: true});
process.env.GCLOUD_PROJECT ??= 'demo-prism';
process.env.R2_PREVIEW_BASE_URL = 'https://img.prismwalls.com';

const require = createRequire(resolve('functions/package.json'));
const {Messaging} = require('firebase-admin/messaging');
const sent = [];
Messaging.prototype.send = async function send(message) {
  sent.push(message);
  return `qa-${sent.length}`;
};
const r2 = require('./lib/r2Storage.js');
r2.R2Storage = class {
  async head() {
    return false;
  }
  async put(_bucket, key, bytes) {
    writeFileSync(join(out, basename(key)), bytes);
    return true;
  }
};

const admin = require('firebase-admin');
const {db} = require('./lib/common.js');
const {offsetsAtDigestTime} = require('./lib/followDigest.js');
const {sendDueTopicDigests} = require('./lib/topicDigest.js');

const now = Date.now();
const offset = offsetsAtDigestTime(now, 16 * 60)[0];
const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
const thumbs = [
  'https://img.prismwalls.com/previews/4f2935aee606c4a151ce2a5cd20570e729bfbf38b0b40fbeea65bb1b193c1730.img',
  'https://img.prismwalls.com/previews/17178b61fa1febf9269a5ebab8fbffd627e0ba2211edc7262516d990e60f089a.img',
];

await db.doc('usersv2/qa-user').set({
  email: 'qa@prismwalls.com', loggedIn: true, lastAppOpenAt: ts(now - 60 * 60 * 1000),
  appOpenTimezoneOffsetMinutes: offset,
});
// The fields FollowedTopicsStore.follow and the token sync write.
await db.doc('usersv2/qa-user/private/session').set({
  fcmToken: 'QA_TOKEN', fcmTokenBindingVersion: 1, fcmTokenBindingToken: 'QA_TOKEN',
  notificationLocalizationVersion: 2, notificationLocalizationToken: 'QA_TOKEN',
  topicAlerts: true, topicAlertsToken: 'QA_TOKEN',
  followedTopics: ['category:Pastel', 'mood:dreamy'], followedTopicsOffset: offset,
});
for (const [i, thumb] of thumbs.entries()) {
  await db.doc(`walls/qa-pastel-${i + 1}`).set({
    id: `qaPastel${i + 1}`, review: false, category: 'Pastel', creatorUid: 'qa-creator', originalProtected: true,
    collections: ['pastel'], colors: ['pink', 'white'], visionLabels: ['pastel', 'flower'], wallpaper_thumb: thumb,
  });
}
// Approval: the review flag and the approval stamp that onWallApproved writes.
for (const i of [1, 2]) {
  await db.doc(`walls/qa-pastel-${i}`).update({review: true, approvedNotifiedAt: ts(now - i * 60 * 1000)});
}

const first = await sendDueTopicDigests(now);
const second = await sendDueTopicDigests(now);
const marker = (await db.doc('usersv2/qa-user/private/topicDigest').get()).data();
const news = (await db.doc('topicNews/current').get()).data();
const inbox = (await db.collection('notifications').get()).docs.map((d) => ({id: d.id, ...d.data()}));
const result = {now: new Date(now).toISOString(), offset, firstRunSent: first, secondRunSent: second, marker,
  topicNews: news?.latest, inbox, messages: sent};
writeFileSync(join(out, 'topic_digest_run.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify({firstRunSent: first, secondRunSent: second, messages: sent.length, out}, null, 2));
if (first !== 1 || second !== 0 || sent.length !== 1) process.exit(1);
process.exit(0);
