'use strict';
// Run after seed.cjs. Sets up creator premium walls: `creator` ("Ava", 30 days old) owns "Neon rain" as a protected
// private upload, and `other` ("Ben", 30 days old) is a buyer with 100 coins. It sets no price and writes no unlock:
// the creator prices the wall in the app (setWallPrice) and the buyer unlocks it in the app (unlockCreatorWall).
const crypto = require('node:crypto');
const {connect} = require('./local.cjs');
const DAY = 86_400_000;
const sha = (text) => crypto.createHash('sha256').update(text).digest('hex');

async function recreate(admin, uid, account) {
  const email = `${account}@demo-prism.test`;
  await admin.auth().deleteUser(uid).catch((error) => {
    if (error.code !== 'auth/user-not-found') throw error;
  });
  // The Admin SDK cannot back-date an account, so the Auth emulator import sets createdAt.
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/demo-prism/accounts:batchCreate', {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: 'Bearer owner'},
    body: JSON.stringify({users: [{localId: uid, email, emailVerified: true, rawPassword: 'local-prism-qa-only',
      displayName: `QA ${account}`, createdAt: String(Date.now() - 30 * DAY),
      providerUserInfo: [{providerId: 'password', email, rawId: email}]}]}),
  });
  const result = await response.json();
  if (!response.ok || result.error?.length) throw new Error(JSON.stringify(result));
}

async function main() {
  const {admin, db} = connect();
  const creator = 'qa-stats-creator';
  const fan = 'qa-stats-other';
  await recreate(admin, creator, 'creator');
  await recreate(admin, fan, 'other');
  await db.doc(`usersv2/${creator}`).update({name: 'Ava', coins: 5});
  await db.doc(`profiles/${creator}`).update({name: 'Ava'});
  await db.doc(`usersv2/${fan}`).update({name: 'Ben', coins: 100});
  await db.doc(`profiles/${fan}`).update({name: 'Ben'});
  await db.doc('economyConfig/current').set({flags: {creatorWallsEnabled: true}}, {merge: true});

  const wallRef = db.doc('walls/qa-creator');
  const wall = await wallRef.get();
  const thumbUrl = wall.data().wallpaper_thumb;
  // Stand-ins for the R2 manifest. The emulator bundle accepts only assets marked qaSeeded.
  const asset = (kind, extra = {}) => {
    const objectId = sha(`qa-creator-wall:${kind}`);
    return {qaSeeded: true, qaThumbUrl: thumbUrl, bucket: 'qa-private', object: `owned/${objectId}`, objectId,
      sha256: sha(`qa-creator-wall-bytes:${kind}`), uid: creator, repo: 'qa', path: `${kind}.png`, sha: sha(kind).slice(0, 40),
      sourceKind: 'owned', ...extra};
  };
  const original = asset('original');
  const thumb = asset('thumb', {previewObjectId: sha('qa-creator-wall:thumb')});
  await wallRef.update({creatorUid: creator, title: 'Neon rain', by: 'Ava', uploadedBy: 'Ava', review: true,
    wallpaper_provider: 'Prism', originalProtected: true, originalObjectId: original.objectId, wallpaper_url: '',
    wallpaper_path: '', wallpaper_sha: '', thumb_path: '', thumb_sha: '', collections: ['community'],
    creatorPrice: admin.firestore.FieldValue.delete()});
  await db.doc('ownedAssets/QA-CREATOR').set({status: 'ready', canonicalPath: wallRef.path,
    incarnation: wall.createTime.toMillis(), incarnationNanos: wall.createTime.nanoseconds, original, thumb,
    provenance: {kind: 'owned', uid: creator}});
  const people = await Promise.all([creator, fan].map((uid) => admin.auth().getUser(uid)));
  console.log(`Creator walls seed ready: ${people.map((u) => `${u.uid} created ${u.metadata.creationTime}`).join('; ')}. ` +
    'Ava has 5 coins and owns walls/qa-creator (no price). Ben has 100 coins.');
  await admin.app().delete();
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
