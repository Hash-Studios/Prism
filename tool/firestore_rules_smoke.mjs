// Firestore rules smoke test. Run with: make rules-test (needs Java for the emulator).
const P = 'demo-prism', B = `http://${process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080'}/v1/projects/${P}/databases/(default)/documents`;
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const tok = (uid, email, verified = true) => `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: uid, user_id: uid, email, email_verified: verified, iat: 1, exp: 9999999999, aud: P, iss: `https://securetoken.google.com/${P}` })}.`;
const arr = (xs) => ({ arrayValue: { values: xs.map((s) => ({ stringValue: s })) } });
const coinState = (fields) => ({ coinState: { mapValue: { fields } } });
async function req(method, path, fields, auth, mask) {
  const q = mask ? '?' + mask.map((m) => `updateMask.fieldPaths=${m}`).join('&') : '';
  const r = await fetch(`${B}/${path}${q}`, { method, headers: { ...(auth ? { Authorization: `Bearer ${auth}` } : {}), 'Content-Type': 'application/json' }, body: fields ? JSON.stringify({ fields }) : undefined });
  return r.status;
}
const seed = () => Promise.all([
  req('PATCH', 'usersv2/target', { followers: arr(['a@x.com']), name: { stringValue: 't' } }, 'owner'),
  req('PATCH', 'admin_users/admin@x.com', { ok: { booleanValue: true } }, 'owner'),
  req('PATCH', 'usersv2/b', { id: { stringValue: 'b' }, coins: { integerValue: '10' }, premium: { booleanValue: false } }, 'owner'),
  req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, 'owner'),
  req('PATCH', 'walls/w9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: true } }, 'owner'),
  req('PATCH', 'setups/s9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: true } }, 'owner'),
  req('PATCH', 'rejectedWalls/rw1', { email: { stringValue: 'b@x.com' } }, 'owner'),
  req('PATCH', 'rejectedWalls/rw2', { email: { stringValue: 'b@x.com' } }, 'owner'),
  req('PATCH', 'rejectedSetups/rs1', { email: { stringValue: 'b@x.com' } }, 'owner'),
  req('PATCH', 'trending/current', { updatedAt: { stringValue: 'x' } }, 'owner'),
  req('PATCH', 'popular/current', { updatedAt: { stringValue: 'x' } }, 'owner'),
  req('PATCH', 'appConfig/app', { minBuild: { integerValue: '1' } }, 'owner'),
  req('PATCH', 'usernames/samk', { uid: { stringValue: 'a' } }, 'owner'),
]);
const A = tok('a', 'a@x.com'), Bu = tok('b', 'b@x.com'), ADM = tok('adm', 'admin@x.com');
const ADM_UNVERIFIED = tok('adm', 'admin@x.com', false);
const cases = [
  ['no-op follow (already following)', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com']) }, A, ['followers']), 200],
  ['follow', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com', 'b@x.com']) }, Bu, ['followers']), 200],
  ['unfollow', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com']) }, Bu, ['followers']), 200],
  ['add someone else', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com', 'c@x.com']) }, Bu, ['followers']), 403],
  ['remove someone else', () => req('PATCH', 'usersv2/target', { followers: arr([]) }, Bu, ['followers']), 403],
  ['edit other field', () => req('PATCH', 'usersv2/target', { name: { stringValue: 'x' } }, Bu, ['name']), 403],
  ['admin re-creates rejected wall', () => req('PATCH', 'walls/w1', { email: { stringValue: 'up@x.com' }, review: { booleanValue: false } }, ADM), 200],
  ['user creates wall for other email', () => req('PATCH', 'walls/w2', { email: { stringValue: 'up@x.com' }, review: { booleanValue: false } }, Bu), 403],
  ['owner sets own coins', () => req('PATCH', 'usersv2/b', { coins: { integerValue: '999' } }, Bu, ['coins']), 403],
  ['owner sets own premium', () => req('PATCH', 'usersv2/b', { premium: { booleanValue: true } }, Bu, ['premium']), 403],
  ['owner sets own tier', () => req('PATCH', 'usersv2/b', { subscriptionTier: { stringValue: 'pro' } }, Bu, ['subscriptionTier']), 403],
  ['owner sets a coin award flag', () => req('PATCH', 'usersv2/b', coinState({ profileCompletionRewarded: { booleanValue: true } }), Bu, ['coinState.profileCompletionRewarded']), 403],
  ['owner toggles streak reminder', () => req('PATCH', 'usersv2/b', coinState({ streakReminderEnabled: { booleanValue: false } }), Bu, ['coinState.streakReminderEnabled']), 200],
  ['user writes a coin ledger entry', () => req('PATCH', 'coinTransactions/t1', {
    userId: { stringValue: 'b' }, delta: { integerValue: '500' },
  }, Bu), 403],
  ['user creates own unreviewed wall', () => req('PATCH', 'walls/w3', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, Bu), 200],
  ['admin email without a verified token creates a wall for someone else', () => req('PATCH', 'walls/w5', { email: { stringValue: 'up@x.com' }, review: { booleanValue: false } }, ADM_UNVERIFIED), 403],
  ['admin email without a verified token reads an unreviewed wall', () => req('GET', 'walls/w8', null, ADM_UNVERIFIED), 403],
  ['admin with a verified token reads an unreviewed wall', () => req('GET', 'walls/w8', null, ADM), 200],
  ['owner edits own unreviewed wall', () => req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, by: { stringValue: 'B' } }, Bu), 200],
  ['owner unpublishes own approved wall', () => req('PATCH', 'walls/w9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, Bu), 403],
  ['owner unpublishes own approved setup', () => req('PATCH', 'setups/s9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, Bu), 403],
  ['owner deletes own rejected wall', () => req('DELETE', 'rejectedWalls/rw1', null, Bu), 200],
  ['other user deletes a rejected wall', () => req('DELETE', 'rejectedWalls/rw2', null, A), 403],
  ['owner deletes own rejected setup', () => req('DELETE', 'rejectedSetups/rs1', null, Bu), 200],
  ['signed-out reads trending/current', () => req('GET', 'trending/current', null, null), 200],
  ['user writes trending/current', () => req('PATCH', 'trending/current', { wallIds: arr(['A']) }, Bu), 403],
  ['signed-out reads popular/current', () => req('GET', 'popular/current', null, null), 200],
  ['user writes popular/current', () => req('PATCH', 'popular/current', { wallIds: arr(['A']) }, Bu), 403],
  ['signed-out reads appConfig/app', () => req('GET', 'appConfig/app', null, null), 200],
  ['user writes appConfig/app', () => req('PATCH', 'appConfig/app', { minBuild: { integerValue: '999' } }, Bu), 403],
  ['signed-in user reads the username registry', () => req('GET', 'usernames/samk', null, Bu), 200],
  ['signed-out reads the username registry', () => req('GET', 'usernames/samk', null, null), 403],
  ['user writes the username registry', () => req('PATCH', 'usernames/mine', { uid: { stringValue: 'b' } }, Bu), 403],
  ['user writes a wall action rate doc', () => req('PATCH', 'wallActionRate/b_W1_set', { lastAt: { stringValue: 'x' } }, Bu), 403],
  ['user writes a daily stats doc', () => req('PATCH', 'wallpaper_stats_daily/20260102_W1', { sets: { integerValue: '9' } }, Bu), 403],
];
await seed();
let bad = 0;
for (const [name, run, want] of cases) { const got = await run(); if (got !== want) bad++; console.log(`${got === want ? 'PASS' : 'FAIL'} ${name}: ${got} (want ${want})`); }
process.exit(bad ? 1 : 0);
