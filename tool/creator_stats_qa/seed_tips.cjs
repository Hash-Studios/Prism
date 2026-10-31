'use strict';
// Run after seed.cjs. Turns `other` into a fan who may tip (verified, 30 days old, 60 coins) and `creator` into "Ava"
// with the wall "Neon rain". It writes no tips: the app sends them through the real tipCreator callable.
const {connect} = require('./local.cjs');
const DAY = 86_400_000;
async function main() {
  const {admin, db} = connect();
  const email = 'other@demo-prism.test';
  const uid = 'qa-stats-other';
  await admin.auth().deleteUser(uid).catch((error) => {
    if (error.code !== 'auth/user-not-found') throw error;
  });
  // The Admin SDK cannot back-date an account, so the Auth emulator import sets createdAt.
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/demo-prism/accounts:batchCreate', {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: 'Bearer owner'},
    body: JSON.stringify({users: [{localId: uid, email, emailVerified: true, rawPassword: 'local-prism-qa-only',
      displayName: 'QA other', createdAt: String(Date.now() - 30 * DAY),
      providerUserInfo: [{providerId: 'password', email, rawId: email}]}]}),
  });
  const result = await response.json();
  if (!response.ok || result.error?.length) throw new Error(JSON.stringify(result));
  await db.doc(`usersv2/${uid}`).update({name: 'Ben', coins: 60});
  await db.doc(`profiles/${uid}`).update({name: 'Ben'});
  await db.doc('usersv2/qa-stats-creator').update({name: 'Ava', coins: 40});
  await db.doc('profiles/qa-stats-creator').update({name: 'Ava'});
  // 3.8.0+ clients list only protected walls. The conversion trigger is not in the emulator, so stamp its result.
  const protectedWall = {originalProtected: true, wallpaper_url: '', wallpaper_path: '', wallpaper_sha: '', thumb_path: '',
    thumb_sha: ''};
  await db.doc('walls/qa-creator').update({...protectedWall, title: 'Neon rain', by: 'Ava', uploadedBy: 'Ava'});
  await db.doc('walls/qa-other').update(protectedWall);
  // Two earlier tippers, so the fan's real tip takes the public line to 3 and it shows.
  await db.doc('wallpaper_stats/QA-CREATOR').set({tippers: 2}, {merge: true});
  const user = await admin.auth().getUser(uid);
  console.log(`Tips seed ready: ${uid} created ${user.metadata.creationTime}, 60 coins. Creator Ava has 40 coins.`);
  await admin.app().delete();
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
