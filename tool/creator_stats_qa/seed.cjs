'use strict';
const {connect} = require('./local.cjs');
async function main() {
  const {admin, db, history: h, backend} = connect();
  const now = Date.now();
  const windows = h.weekWindows(now);
  const imageHost = process.env.QA_IMAGE_HOST ?? '10.0.2.2';
  if (!['10.0.2.2', '127.0.0.1'].includes(imageHost)) throw new Error('QA_IMAGE_HOST must be a local emulator host');
  for (const [index, account] of ['creator', 'other', 'empty'].entries()) {
    const uid = `qa-stats-${account}`;
    const email = `${account}@demo-prism.test`;
    const record = {uid, email, password: 'local-prism-qa-only', emailVerified: true, displayName: `QA ${account}`};
    try { await admin.auth().createUser(record); } catch (error) {
      if (error.code !== 'auth/uid-already-exists' && error.code !== 'auth/email-already-exists') throw error;
      const existing = await admin.auth().getUserByEmail(email);
      if (existing.uid !== uid) throw new Error(`Conflicting fixture email: ${email}. Use a fresh demo emulator.`);
      const {uid: ignoredUid, ...update} = record;
      await admin.auth().updateUser(uid, update);
    }
    const createdAt = windows[0].start;
    await db.doc(`usersv2/${uid}`).set({id: uid, email, username: `qa${account}`, name: `QA ${account}`,
      bio: 'Local emulator fixture', createdAt, lastLoginAt: createdAt, premium: false, subscriptionTier: 'free',
      profilePhoto: `http://${imageHost}:9198/avatar.png`, followers: [], following: [], links: {}, coins: 0,
      loggedIn: true, badges: [], subPrisms: [], transactions: [], uploadsWeekStart: '', uploadsThisWeek: 0});
    await db.doc(`usersv2/${uid}/private/session`).set({postAlerts: true});
    if (account === 'empty') continue;
    const id = `QA-${account.toUpperCase()}`;
    const ref = db.doc(`walls/qa-${account}`);
    await ref.set({id, creatorUid: uid, email, review: true, title: `QA ${account} wall`,
      uploadedBy: `QA ${account}`, by: `QA ${account}`, userPhoto: `http://${imageHost}:9198/avatar.png`,
      wallpaper_url: `http://${imageHost}:9198/${account}.png`, wallpaper_thumb: `http://${imageHost}:9198/${account}.png`,
      wallpaper_provider: 'Prism', resolution: '540x960', file_size: 10000, createdAt,
      desc: 'Demo-only creator stats wallpaper', collections: [], tags: ['qa'], category: 'Abstract',
      colors: ['#335577'], remixCount: 8 + index});
    const wall = await ref.get();
    const historyRef = h.historyRef(wall);
    const existing = (await historyRef.get()).data();
    const weeks = Object.fromEntries(windows.map((w, i) => [w.week,
      Object.fromEntries(h.METRICS.map((m, j) => [m, (i + 1) * (j + 1) * (index + 1)]))]));
    if (!existing) await historyRef.create({wallPath: ref.path, incarnation: h.incarnation(wall), creatorUid: uid,
      from: windows[0].start, weeks, folderAdds: 252 * (index + 1)});
    else {
      const retained = Object.fromEntries(windows.map(w => [w.week, existing.weeks[w.week] ?? weeks[w.week]]));
      await historyRef.update({weeks: retained});
    }
    const stats = db.doc(`wallpaper_stats/${id}`);
    if (!(await stats.get()).exists) await stats.create({views: 12000 * (index + 1), favs: 180 * (index + 1),
      sets: 240 * (index + 1), downloads: 360 * (index + 1), shares: 90 * (index + 1)});
    if (account === 'creator') await backend.deliverCreatorWeek(uid, now);
    console.log(`${account}: ${uid}, ${ref.path}, ${h.incarnation(wall)}`);
  }
  console.log('Seed ready. Run assert.cjs next. No cache or notification fixtures were written directly.');
  await admin.app().delete();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
