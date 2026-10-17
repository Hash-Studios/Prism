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
  req('PATCH', 'economyConfig/current', { version: { integerValue: '2' } }, 'owner'),
  req('PATCH', 'drops/2026-W42', { weekKey: { stringValue: '2026-W42' } }, 'owner'),
  req('PATCH', 'boosts/W1', { wallId: { stringValue: 'W1' } }, 'owner'),
  req('PATCH', 'draws/2026-W42', { weekKey: { stringValue: '2026-W42' } }, 'owner'),
  req('PATCH', 'drawTickets/2026-W42_b', { uid: { stringValue: 'b' }, count: { integerValue: '1' } }, 'owner'),
  req('PATCH', 'leaderboards/current', { weekKey: { stringValue: '2026-W42' } }, 'owner'),
  req('PATCH', 'usersv2/b/private/economy', { rev: { integerValue: '1' } }, 'owner'),
]);
const A = tok('a', 'a@x.com'), Bu = tok('b', 'b@x.com'), ADM = tok('adm', 'admin@x.com');
const ADM_UNVERIFIED = tok('adm', 'admin@x.com', false);
const C = tok('c', 'c@x.com');
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
  ['owner updates an unrelated field without an app-open offset', () => req('PATCH', 'usersv2/b', {
    name: { stringValue: 'B' },
  }, Bu, ['name']), 200],
  ['owner creates profile without app-open fields', () => req('PATCH', 'usersv2/c', {
    id: { stringValue: 'c' }, name: { stringValue: 'C' },
  }, C), 200],
  ['owner cannot create profile with stale last app open', () => req('PATCH', 'usersv2/c-stale', {
    id: { stringValue: 'c-stale' },
    lastAppOpenAt: { timestampValue: new Date(Date.now() - 6 * 60 * 1000).toISOString() },
  }, tok('c-stale', 'c-stale@x.com')), 403],
  ['owner cannot create profile with invalid app-open offset', () => req('PATCH', 'usersv2/c-offset', {
    id: { stringValue: 'c-offset' }, appOpenTimezoneOffsetMinutes: { integerValue: '9999' },
  }, tok('c-offset', 'c-offset@x.com')), 403],
  ['admin seeds profile with stale app-open timestamp', () => req('PATCH', 'usersv2/d', {
    id: { stringValue: 'd' }, lastAppOpenAt: { timestampValue: new Date(Date.now() - 6 * 60 * 1000).toISOString() },
  }, ADM), 200],
  ['owner can update offset without revalidating old timestamp', () => req('PATCH', 'usersv2/d', {
    appOpenTimezoneOffsetMinutes: { integerValue: '60' },
  }, tok('d', 'd@x.com'), ['appOpenTimezoneOffsetMinutes']), 200],
  ['owner stamps last app open', () => req('PATCH', 'usersv2/b', {
    lastAppOpenAt: { timestampValue: new Date().toISOString() },
    appOpenTimezoneOffsetMinutes: { integerValue: '330' },
  }, Bu, ['lastAppOpenAt', 'appOpenTimezoneOffsetMinutes']), 200],
  ['owner accepts a recent last app open', () => req('PATCH', 'usersv2/b', {
    lastAppOpenAt: { timestampValue: new Date(Date.now() - 4 * 60 * 1000).toISOString() },
  }, Bu, ['lastAppOpenAt']), 200],
  ['owner accepts a last app open within one minute ahead', () => req('PATCH', 'usersv2/b', {
    lastAppOpenAt: { timestampValue: new Date(Date.now() + 50 * 1000).toISOString() },
  }, Bu, ['lastAppOpenAt']), 200],
  ['owner backdates last app open', () => req('PATCH', 'usersv2/b', {
    lastAppOpenAt: { timestampValue: new Date(Date.now() - 6 * 60 * 1000).toISOString() },
  }, Bu, ['lastAppOpenAt']), 403],
  ['owner sets last app open too far ahead', () => req('PATCH', 'usersv2/b', {
    lastAppOpenAt: { timestampValue: new Date(Date.now() + 2 * 60 * 1000).toISOString() },
  }, Bu, ['lastAppOpenAt']), 403],
  ['owner sets a wild timezone offset', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { integerValue: '9999' },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 403],
  ['owner sets a timezone offset below the allowed range', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { integerValue: '-735' },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 403],
  ['owner sets the minimum timezone offset', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { integerValue: '-720' },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 200],
  ['owner sets the maximum timezone offset', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { integerValue: '840' },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 200],
  ['owner sets an offset off the 15 minute grid', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { integerValue: '7' },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 403],
  ['owner sets a non-integer timezone offset', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { doubleValue: 30.5 },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 403],
  ['owner stamps a west-of-UTC offset', () => req('PATCH', 'usersv2/b', {
    appOpenTimezoneOffsetMinutes: { integerValue: '-300' },
  }, Bu, ['appOpenTimezoneOffsetMinutes']), 200],
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
  ['user writes a notification scoreboard metric', () => req('PATCH', 'metrics/notificationScoreboard', { sends: { integerValue: '9' } }, Bu), 403],
  ['user writes a notification scoreboard day', () => req('PATCH', 'metrics/notificationScoreboard/days/20261017', { sends: { integerValue: '9' } }, Bu), 403],
  ['user writes a notification scoreboard signal', () => req('PATCH', 'metrics/notificationScoreboard/signals/s1', { sentAt: { stringValue: 'x' } }, Bu), 403],
  ['signed-in reads economyConfig/current', () => req('GET', 'economyConfig/current', null, Bu), 200],
  ['signed-out reads economyConfig/current', () => req('GET', 'economyConfig/current', null, null), 200],
  ['user writes economyConfig/current', () => req('PATCH', 'economyConfig/current', { version: { integerValue: '9' } }, Bu), 403],
  ['signed-in reads a drop', () => req('GET', 'drops/2026-W42', null, Bu), 200],
  ['user writes a drop', () => req('PATCH', 'drops/2026-W42', { count: { integerValue: '9' } }, Bu), 403],
  ['signed-in reads a boost', () => req('GET', 'boosts/W1', null, Bu), 200],
  ['user writes a boost', () => req('PATCH', 'boosts/W2', { wallId: { stringValue: 'W2' } }, Bu), 403],
  ['signed-in reads a draw', () => req('GET', 'draws/2026-W42', null, Bu), 200],
  ['user writes a draw', () => req('PATCH', 'draws/2026-W42', { status: { stringValue: 'settled' } }, Bu), 403],
  ['owner reads own draw ticket', () => req('GET', 'drawTickets/2026-W42_b', null, Bu), 200],
  ['user reads another uid draw ticket', () => req('GET', 'drawTickets/2026-W42_b', null, A), 403],
  // 404 means the read was allowed and the doc is missing.
  ['owner gets own missing draw ticket', () => req('GET', 'drawTickets/2026-W43_b', null, Bu), 404],
  ['user gets another uid missing draw ticket', () => req('GET', 'drawTickets/2026-W43_b', null, A), 403],
  ['user gets a ticket id with an extra suffix', () => req('GET', 'drawTickets/2026-W43_b_b', null, Bu), 403],
  ['owner writes own draw ticket', () => req('PATCH', 'drawTickets/2026-W42_b', { uid: { stringValue: 'b' }, count: { integerValue: '5' } }, Bu), 403],
  ['signed-in reads the leaderboard', () => req('GET', 'leaderboards/current', null, Bu), 200],
  ['user writes the leaderboard', () => req('PATCH', 'leaderboards/current', { weekKey: { stringValue: 'x' } }, Bu), 403],
  ['user writes a quest event rate doc', () => req('PATCH', 'questEventRate/b_2026-01-01_favourite', { count: { integerValue: '1' } }, Bu), 403],
  ['user reads a gift rate doc', () => req('GET', 'giftRateDaily/b_2026-01-01', null, Bu), 403],
  ['owner reads own private economy doc', () => req('GET', 'usersv2/b/private/economy', null, Bu), 200],
  ['other user reads a private economy doc', () => req('GET', 'usersv2/b/private/economy', null, A), 403],
  ['owner writes own private economy doc', () => req('PATCH', 'usersv2/b/private/economy', { rev: { integerValue: '99' } }, Bu), 403],
  ['owner sets own xp', () => req('PATCH', 'usersv2/b', { xp: { integerValue: '9999' } }, Bu, ['xp']), 403],
  ['owner sets own xpWeek', () => req('PATCH', 'usersv2/b', { xpWeek: { mapValue: { fields: { xp: { integerValue: '9' } } } } }, Bu, ['xpWeek']), 403],
  ['owner sets own cosmetics', () => req('PATCH', 'usersv2/b', { cosmetics: { mapValue: { fields: { frame: { stringValue: 'frame_gold' } } } } }, Bu, ['cosmetics']), 403],
  ['owner sets own quests', () => req('PATCH', 'usersv2/b', { quests: { mapValue: { fields: {} } } }, Bu, ['quests']), 403],
  ['owner sets own inventory', () => req('PATCH', 'usersv2/b', { inventory: { mapValue: { fields: {} } } }, Bu, ['inventory']), 403],
  ['owner sets own drops', () => req('PATCH', 'usersv2/b', { drops: { mapValue: { fields: {} } } }, Bu, ['drops']), 403],
  ['owner sets coinState.premiumPreviewUnlocks', () => req('PATCH', 'usersv2/b', coinState({ premiumPreviewUnlocks: { mapValue: { fields: {} } } }), Bu, ['coinState.premiumPreviewUnlocks']), 200],
  ['new user doc with xp', () => req('PATCH', 'usersv2/n1', { id: { stringValue: 'n1' }, xp: { integerValue: '500' } }, tok('n1', 'n1@x.com')), 403],
  ['new user doc without xp', () => req('PATCH', 'usersv2/n2', { id: { stringValue: 'n2' } }, tok('n2', 'n2@x.com')), 200],
  ['owner sets boostedUntil on own wall', () => req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, boostedUntil: { integerValue: '9999999999999' } }, Bu), 403],
  ['owner sets dropReserved on own wall', () => req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, dropReserved: { booleanValue: true } }, Bu), 403],
  ['owner sets dropWeek on own wall', () => req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, dropWeek: { stringValue: '2026-W42' } }, Bu), 403],
  ['owner creates a wall with dropReserved', () => req('PATCH', 'walls/w11', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, dropReserved: { booleanValue: true } }, Bu), 403],
  ['admin sets dropReserved on a wall', () => req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, dropReserved: { booleanValue: true } }, ADM), 200],
];
await seed();
let bad = 0;
for (const [name, run, want] of cases) { const got = await run(); if (got !== want) bad++; console.log(`${got === want ? 'PASS' : 'FAIL'} ${name}: ${got} (want ${want})`); }
process.exit(bad ? 1 : 0);
