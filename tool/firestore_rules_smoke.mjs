// Firestore rules smoke test. Run with: make rules-test (needs Java for the emulator).
const P = 'demo-prism', B = `http://${process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080'}/v1/projects/${P}/databases/(default)/documents`;
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const tok = (uid, email, verified = true) => `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: uid, user_id: uid, email, email_verified: verified, iat: 1, exp: 9999999999, aud: P, iss: `https://securetoken.google.com/${P}` })}.`;
const arr = (xs) => ({ arrayValue: { values: xs.map((s) => ({ stringValue: s })) } });
const coinState = (fields) => ({ coinState: { mapValue: { fields } } });
const depth = (tier) => ({ mapValue: { fields: {
  tier: { stringValue: tier }, kind: { stringValue: 'person' }, top: { doubleValue: 0.2 }, v: { integerValue: '1' }, by: { stringValue: 'detector' },
} } });
const spatial = (tier) => ({ mapValue: { fields: {
  tier: { stringValue: tier }, map: { stringValue: 'https://img.prismwalls.com/spatial/v1/w.png' }, v: { integerValue: '1' },
} } });
async function req(method, path, fields, auth, mask) {
  const q = mask ? '?' + mask.map((m) => `updateMask.fieldPaths=${m}`).join('&') : '';
  const r = await fetch(`${B}/${path}${q}`, { method, headers: { ...(auth ? { Authorization: `Bearer ${auth}` } : {}), 'Content-Type': 'application/json' }, body: fields ? JSON.stringify({ fields }) : undefined });
  return r.status;
}
async function profileHasNoEmail(path, auth) {
  const r = await fetch(`${B}/${path}`, { headers: { Authorization: `Bearer ${auth}` } });
  const body = await r.json();
  return r.status === 200 && body.fields && !('email' in body.fields) ? 200 : -1;
}
async function transformFollowers(uid, operation, emails, auth) {
  const r = await fetch(`${B}:commit`, {
    method: 'POST', headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: [{ transform: {
      document: `projects/${P}/databases/(default)/documents/usersv2/${uid}`,
      fieldTransforms: [{ fieldPath: 'followers', [operation]: arr(emails).arrayValue }],
    } }] }),
  });
  return r.status;
}
const runQuery = async (auth, filters, collectionId = 'drawTickets', parent = '', options = {}) => {
  const r = await fetch(`${B}${parent ? `/${parent}` : ''}:runQuery`, {
    method: 'POST',
    headers: { ...(auth ? { Authorization: `Bearer ${auth}` } : {}), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: { compositeFilter: { op: 'AND', filters } },
        ...options,
      },
    }),
  });
  return r.status;
};
const runCollectionQuery = async (auth, collectionId, parent = '') => {
  const r = await fetch(`${B}${parent ? `/${parent}` : ''}:runQuery`, {
    method: 'POST',
    headers: { ...(auth ? { Authorization: `Bearer ${auth}` } : {}), 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId }] } }),
  });
  return r.status;
};
const documentIdFilter = (path) => ({
  fieldFilter: {
    field: { fieldPath: '__name__' },
    op: 'EQUAL',
    value: { referenceValue: `projects/${P}/databases/(default)/documents/${path}` },
  },
});
const ticketIdFilter = (id) => documentIdFilter(`drawTickets/${id}`);
const ticketUidFilter = (uid) => ({
  fieldFilter: { field: { fieldPath: 'uid' }, op: 'EQUAL', value: { stringValue: uid } },
});
const provenanceFields = ['wallpaper_path', 'wallpaper_sha', 'thumb_path', 'thumb_sha'];
const redactedProvenance = Object.fromEntries(provenanceFields.map((field) => [field, { stringValue: '' }]));
const publicWall = {
  email: { stringValue: 'b@x.com' }, review: { booleanValue: true },
  originalProtected: { booleanValue: true }, wallpaper_url: { stringValue: '' }, ...redactedProvenance,
};
const str = (v) => ({ stringValue: v });
const ts = () => ({ timestampValue: new Date().toISOString() });
const folderFields = (owner, name = 'Blue walls', extra = {}) => ({ ownerId: str(owner), name: str(name), createdAt: ts(), updatedAt: ts(), itemCount: { integerValue: '0' }, covers: arr([]), ...extra });
const itemFields = (owner, id = 'abc', provider = 'WallHaven') => ({ id: str(id), provider: str(provider), ownerId: str(owner), addedAt: ts(), url: str('https://example.com/f.jpg'), thumb: str('https://example.com/t.jpg') });
const ownerFilter = (uid) => ({ fieldFilter: { field: { fieldPath: 'ownerId' }, op: 'EQUAL', value: { stringValue: uid } } });
const newestFirst = (field, limit) => ({ orderBy: [{ field: { fieldPath: field }, direction: 'DESCENDING' }], ...(limit ? { limit } : {}) });
const commitDocs = async (auth, docs) => {
  const r = await fetch(`${B}:commit`, {
    method: 'POST', headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: docs.map(([path, fields]) => ({ update: { name: `projects/${P}/databases/(default)/documents/${path}`, fields } })) }),
  });
  return r.status;
};
const seed = () => Promise.all([
  req('PATCH', 'usersv2/a', { id: str('a'), email: str('a@x.com'), followers: arr(['c@x.com']), following: arr([]) }, 'owner'),
  req('PATCH', 'profiles/a', {
    name: str('A'), username: str('a'), profilePhoto: str(''), bio: str(''), links: { mapValue: { fields: {} } },
    coverPhoto: str(''), badges: arr([]), xp: { integerValue: '0' }, cosmetics: { mapValue: { fields: {} } },
    followerCount: { integerValue: '1' },
  }, 'owner'),
  req('PATCH', 'profiles/a/followers/c', { followedAt: str('x') }, 'owner'),
  req('PATCH', 'profiles/a/following/c', { followedAt: str('x') }, 'owner'),
  req('PATCH', 'usersv2/multi', { followers: arr(['v1@x.com', 'v2@x.com']) }, 'owner'),
  req('PATCH', 'usersv2/removal', { followers: arr(['b@x.com', 'v1@x.com', 'v2@x.com']) }, 'owner'),
  req('PATCH', 'usersv2/duplicates', { followers: arr(['b@x.com', 'b@x.com', 'v1@x.com', 'v1@x.com']) }, 'owner'),
  req('PATCH', 'usersv2/b/images/legacy-alias', { id: { stringValue: 'target' }, provider: { stringValue: 'Unknown' } }, 'owner'),
  req('PATCH', 'usersv2/target', { followers: arr(['a@x.com']), name: { stringValue: 't' } }, 'owner'),
  req('PATCH', 'admin_users/admin@x.com', { ok: { booleanValue: true } }, 'owner'),
  req('PATCH', 'usersv2/b', { id: { stringValue: 'b' }, coins: { integerValue: '10' }, premium: { booleanValue: false } }, 'owner'),
  req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, 'owner'),
  req('PATCH', 'walls/w9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: true } }, 'owner'),
  req('PATCH', 'walls/protected', { ...publicWall, wallpaper_thumb: { stringValue: 'https://example.com/preview.jpg' } }, 'owner'),
  ...provenanceFields.flatMap((field) => [
    req('PATCH', `walls/leaked-${field}`, { ...publicWall, [field]: { stringValue: 'private-original-provenance' } }, 'owner'),
    req('PATCH', `walls/missing-${field}`, Object.fromEntries(Object.entries(publicWall).filter(([key]) => key !== field)), 'owner'),
  ]),
  req('PATCH', 'walls/approval-race', { ...publicWall, review: { booleanValue: false }, wallpaper_path: { stringValue: 'originals/private.jpg' } }, 'owner'),
  req('PATCH', 'walls/leaked', { email: { stringValue: 'b@x.com' }, review: { booleanValue: true }, originalProtected: { booleanValue: true }, wallpaper_url: { stringValue: 'https://example.com/original.jpg' } }, 'owner'),
  req('PATCH', 'ownedAssets/protected', { status: { stringValue: 'ready' } }, 'owner'),
  req('PATCH', 'aiGenerationReceipts/gen-1', {
    generationId: { stringValue: 'gen-1' }, userId: { stringValue: 'b' },
    imageUrl: { stringValue: 'https://prismwalls.com/api/ai/assets/ai/original/gen-1.png' },
    watermarkedImageUrl: { stringValue: 'https://prismwalls.com/api/ai/assets/ai/public/gen-1.png' },
  }, 'owner'),
  req('PATCH', 'walls/w12', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, depth: depth('auto') }, 'owner'),
  req('PATCH', 'walls/w14', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, searchTerms: arr(['sunset']), visionLabels: arr(['sky']), spatial: spatial('great') }, 'owner'),
  req('PATCH', 'setups/s9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: true } }, 'owner'),
  req('PATCH', 'rejectedWalls/rw1', { email: { stringValue: 'b@x.com' } }, 'owner'),
  req('PATCH', 'rejectedWalls/rw2', { email: { stringValue: 'b@x.com' } }, 'owner'),
  req('PATCH', 'rejectedSetups/rs1', { email: { stringValue: 'b@x.com' } }, 'owner'),
  req('PATCH', 'trending/current', { updatedAt: { stringValue: 'x' } }, 'owner'),
  req('PATCH', 'moods/current', { updatedAt: { stringValue: 'x' } }, 'owner'),
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
  req('PATCH', 'creatorWallCredits/test-wall', { creatorUid: { stringValue: 'b' } }, 'owner'),
  req('PATCH', 'creatorDeletionState/b', { closed: { booleanValue: false } }, 'owner'),
  req('PATCH', 'creatorMemberRateDaily/b_2026-10-18', { memberUid: { stringValue: 'b' } }, 'owner'),
  req('PATCH', 'usersv2/b/private/economy/creatorMembers/a', { memberUid: { stringValue: 'a' } }, 'owner'),
  req('PATCH', 'folders/fb', folderFields('b'), 'owner'),
  req('PATCH', 'folders/fb/items/wallhaven_abc', itemFields('b'), 'owner'),
  req('PATCH', 'folders/reused', folderFields('b'), 'owner'),
  req('PATCH', 'folders/reused/items/wallhaven_private', itemFields('b', 'private'), 'owner'),
  req('PATCH', 'folders/absent/items/wallhaven_orphan', itemFields('b', 'orphan'), 'owner'),
]);
const A = tok('a', 'a@x.com'), Bu = tok('b', 'b@x.com'), ADM = tok('adm', 'admin@x.com');
const ADM_UNVERIFIED = tok('adm', 'admin@x.com', false);
const C = tok('c', 'c@x.com');
const themeFields = {
  mode: str('dark'), lightThemeId: str('kLFrost White'), lightAccent: { integerValue: '4293228183' },
  darkThemeId: str('kDOlive'), darkAccent: { integerValue: '4278190080' }, changedAt: { integerValue: '1793000000000' },
};
const themeNoChangedAt = Object.fromEntries(Object.entries(themeFields).filter(([k]) => k !== 'changedAt'));
const themeMap = (fields) => ({ themePrefs: { mapValue: { fields } } });
const cases = [
  ['stranger can get a public profile', () => req('GET', 'profiles/a', null, Bu), 200],
  ['public profile carries no email key', () => profileHasNoEmail('profiles/a', Bu), 200],
  ['stranger can list public profiles', () => runCollectionQuery(Bu, 'profiles'), 200],
  ['signed-out user cannot get a public profile', () => req('GET', 'profiles/a'), 403],
  ['stranger can read a follower edge', () => req('GET', 'profiles/a/followers/c', null, Bu), 200],
  ['stranger can list follower edges', () => runCollectionQuery(Bu, 'followers', 'profiles/a'), 200],
  ['stranger can read a following edge', () => req('GET', 'profiles/a/following/c', null, Bu), 200],
  ['stranger can list following edges', () => runCollectionQuery(Bu, 'following', 'profiles/a'), 200],
  ['signed-out user cannot list follower edges', () => runCollectionQuery(undefined, 'followers', 'profiles/a'), 403],
  ['stranger cannot update a public profile', () => req('PATCH', 'profiles/a', { name: str('x') }, Bu, ['name']), 403],
  ['owner cannot update own public profile', () => req('PATCH', 'profiles/a', { name: str('x') }, A, ['name']), 403],
  ['owner cannot create a public profile', () => req('PATCH', 'profiles/b', { name: str('B') }, Bu), 403],
  ['owner cannot delete own public profile', () => req('DELETE', 'profiles/a', null, A), 403],
  ['stranger cannot delete a public profile', () => req('DELETE', 'profiles/a', null, Bu), 403],
  ['admin client cannot write a public profile', () => req('PATCH', 'profiles/a', { name: str('x') }, ADM, ['name']), 403],
  ['owner cannot write own follower edge', () => req('PATCH', 'profiles/a/followers/b', { followedAt: str('x') }, A), 403],
  ['follower cannot create own follower edge', () => req('PATCH', 'profiles/a/followers/b', { followedAt: str('x') }, Bu), 403],
  ['follower cannot update a follower edge', () => req('PATCH', 'profiles/a/followers/c', { followedAt: str('y') }, tok('c', 'c@x.com'), ['followedAt']), 403],
  ['follower cannot delete a follower edge', () => req('DELETE', 'profiles/a/followers/c', null, tok('c', 'c@x.com')), 403],
  ['owner cannot write own following edge', () => req('PATCH', 'profiles/a/following/b', { followedAt: str('x') }, A), 403],
  ['owner cannot update a following edge', () => req('PATCH', 'profiles/a/following/c', { followedAt: str('y') }, A, ['followedAt']), 403],
  ['owner cannot delete a following edge', () => req('DELETE', 'profiles/a/following/c', null, A), 403],
  ['stranger cannot get usersv2', () => req('GET', 'usersv2/a', null, Bu), 403],
  ['owner can get own usersv2', () => req('GET', 'usersv2/a', null, A), 200],
  ['stranger cannot list usersv2', () => runCollectionQuery(Bu, 'usersv2'), 403],
  ['stranger cannot add own email to followers', () => req('PATCH', 'usersv2/a', { followers: arr(['c@x.com', 'b@x.com']) }, Bu, ['followers']), 403],
  ['owner cannot write own following array', () => req('PATCH', 'usersv2/a', { following: arr(['b@x.com']) }, A, ['following']), 403],
  ['owner cannot set creatorUid on wall create', () => req('PATCH', 'walls/forged-creator', { email: str('b@x.com'), review: { booleanValue: false }, creatorUid: str('a') }, Bu), 403],
  ['owner cannot change creatorUid on wall update', () => req('PATCH', 'walls/w8', { creatorUid: str('a') }, Bu, ['creatorUid']), 403],
  ['admin may set creatorUid on a wall', () => req('PATCH', 'walls/admin-creator', { email: str('b@x.com'), review: { booleanValue: false }, creatorUid: str('b') }, ADM), 200],
  ['owner cannot set creatorUid on setup create', () => req('PATCH', 'setups/forged-creator', { email: str('b@x.com'), review: { booleanValue: false }, creatorUid: str('a') }, Bu), 403],
  ['owner cannot change creatorUid on setup update', () => req('PATCH', 'setups/s9', { creatorUid: str('a') }, Bu, ['creatorUid']), 403],
  ['foreign profile email rejected', () => req('PATCH', 'usersv2/forger', {
    id: { stringValue: 'forger' }, email: { stringValue: 'victim@x.com' },
  }, tok('forger', 'forger@x.com')), 403],
  ['email-less identity can create an email-less profile', () => req('PATCH', 'usersv2/no-email', {
    id: { stringValue: 'no-email' }, email: { stringValue: '' },
  }, tok('no-email', undefined)), 200],
  ['trusted mixed-case profile email allowed', () => req('PATCH', 'usersv2/mixed', {
    id: { stringValue: 'mixed' }, email: { stringValue: 'Mixed@X.com' }, username: { stringValue: '' },
    usernameCandidate: { stringValue: 'Mixed' },
  }, tok('mixed', 'Mixed@X.com')), 200],
  ['initial canonical username bypass rejected', () => req('PATCH', 'usersv2/canonical', {
    id: { stringValue: 'canonical' }, username: { stringValue: 'SamK' },
  }, tok('canonical', 'canonical@x.com')), 403],
  ['initial canonical lowercase bypass rejected', () => req('PATCH', 'usersv2/lower', {
    id: { stringValue: 'lower' }, usernameLower: { stringValue: 'samk' },
  }, tok('lower', 'lower@x.com')), 403],
  ['direct owner rename rejected', () => req('PATCH', 'usersv2/b', { username: { stringValue: 'SamK' } }, Bu, ['username']), 403],
  ['unverified email cannot follow as another identity', () => transformFollowers('multi', 'appendMissingElements', ['b@x.com'], tok('impostor', 'b@x.com', false)), 403],
  ['unverified email cannot edit another identity upload', () => req('PATCH', 'walls/w8', {
    by: { stringValue: 'Impostor' },
  }, tok('impostor', 'b@x.com', false), ['by']), 403],
  ['foreign follower replacement on add rejected', () => req('PATCH', 'usersv2/multi', {
    followers: arr(['b@x.com', 'fake1@x.com', 'fake2@x.com']),
  }, Bu, ['followers']), 403],
  ['foreign follower replacement on removal rejected', () => req('PATCH', 'usersv2/removal', {
    followers: arr(['fake1@x.com', 'fake2@x.com']),
  }, Bu, ['followers']), 403],
  ['foreign follower duplicate substitution rejected', () => req('PATCH', 'usersv2/multi', {
    followers: arr(['b@x.com', 'v1@x.com', 'v1@x.com']),
  }, Bu, ['followers']), 403],
  ['foreign follower reorder rejected', () => req('PATCH', 'usersv2/multi', {
    followers: arr(['v2@x.com', 'v1@x.com']),
  }, Bu, ['followers']), 403],
  ['arrayUnion follow rejected', () => transformFollowers('multi', 'appendMissingElements', ['b@x.com'], Bu), 403],
  ['arrayRemove unfollow rejected', () => transformFollowers('multi', 'removeAllFromArray', ['b@x.com'], Bu), 403],
  ['favourite alias rejected', () => req('PATCH', 'usersv2/b/images/alias', {
    id: { stringValue: 'target' }, provider: { stringValue: 'Prism' },
  }, Bu), 403],
  ['unsupported favourite provider rejected', () => req('PATCH', 'usersv2/b/images/unknown', {
    id: { stringValue: 'unknown' }, provider: { stringValue: 'Unknown' },
  }, Bu), 403],
  ['favourite missing stored id rejected', () => req('PATCH', 'usersv2/b/images/no-id', {
    provider: { stringValue: 'Prism' },
  }, Bu), 403],
  ['favourite numeric stored id rejected', () => req('PATCH', 'usersv2/b/images/123', {
    id: { integerValue: '123' }, provider: { stringValue: 'Pexels' },
  }, Bu), 403],
  ['owner may delete malformed legacy favourites', () => req('DELETE', 'usersv2/b/images/legacy-alias', null, Bu), 200],
  ...['Prism', 'wall_of_the_day', 'WallOfTheDay', 'WallHaven', 'Pexels'].flatMap((provider) => [
    [`valid ${provider} favourite allowed`, () => req('PATCH', `usersv2/b/images/${provider}`, {
      id: { stringValue: provider }, provider: { stringValue: provider }, url: { stringValue: 'https://example.com/w.jpg' },
      thumb: { stringValue: 'https://example.com/t.jpg' }, favouritedAt: { timestampValue: new Date().toISOString() },
    }, Bu), 200],
    [`${provider} favourite delete allowed`, () => req('DELETE', `usersv2/b/images/${provider}`, null, Bu), 200],
  ]),
  ['guest reads redacted public metadata', () => req('GET', 'walls/protected'), 200],
  ['guest reads a reviewed legacy wall (3.7.0 read rule restored)', () => req('GET', 'walls/w9'), 200],
  ['guest reads a reviewed wall that only claims protection (read tightening ships later)', () => req('GET', 'walls/leaked'), 200],
  ...provenanceFields.flatMap((field) => [
    [`guest reads reviewed wall with ${field} (read tightening ships later)`, () => req('GET', `walls/leaked-${field}`), 200],
    [`guest reads reviewed wall missing ${field} (read tightening ships later)`, () => req('GET', `walls/missing-${field}`), 200],
    [`owner retains access to ${field} for cleanup`, () => req('GET', `walls/leaked-${field}`, null, Bu), 200],
  ]),
  ['owner reads pending provenance', () => req('GET', 'walls/approval-race', null, Bu), 200],
  ['admin approves before binder redaction', () => req('PATCH', 'walls/approval-race', { review: { booleanValue: true } }, ADM, ['review']), 200],
  ['approved wall is readable before the binder redacts it', () => req('GET', 'walls/approval-race'), 200],
  ['admin retains approval race access', () => req('GET', 'walls/approval-race', null, ADM), 200],
  ['binder redacts approval race provenance', () => req('PATCH', 'walls/approval-race', redactedProvenance, 'owner', provenanceFields), 200],
  ['guest reads approval only after binder redaction', () => req('GET', 'walls/approval-race'), 200],
  ['free user cannot read original manifest', () => req('GET', 'ownedAssets/protected', null, Bu), 403],
  ['guest cannot read original manifest', () => req('GET', 'ownedAssets/protected'), 403],
  ['owner cannot read original manifest', () => req('GET', 'ownedAssets/protected', null, Bu), 403],
  ['owner cannot write original manifest', () => req('PATCH', 'ownedAssets/protected', { status: { stringValue: 'deleted' } }, Bu), 403],
  ['owner cannot delete original manifest', () => req('DELETE', 'ownedAssets/protected', null, Bu), 403],
  ['guest cannot read R2 object registry', () => req('GET', 'r2ObjectRegistry/object-id'), 403],
  ['owner cannot read R2 object registry', () => req('GET', 'r2ObjectRegistry/object-id', null, Bu), 403],
  ['owner cannot write R2 object registry', () => req('PATCH', 'r2ObjectRegistry/object-id', { status: { stringValue: 'active' } }, Bu), 403],
  ['owner cannot delete R2 object registry', () => req('DELETE', 'r2ObjectRegistry/object-id', null, Bu), 403],
  ...[['owner', Bu], ['guest', undefined], ['admin', ADM]].flatMap(([role, auth]) => [
    [`${role} cannot read AI generation receipt`, () => req('GET', 'aiGenerationReceipts/gen-1', null, auth), 403],
    [`${role} cannot list AI generation receipts`, () => runQuery(auth, [
      { fieldFilter: { field: { fieldPath: 'userId' }, op: 'EQUAL', value: { stringValue: 'b' } } },
    ], 'aiGenerationReceipts'), 403],
    [`${role} cannot create AI generation receipt`, () => req('PATCH', `aiGenerationReceipts/new-${role}`, { userId: { stringValue: 'b' } }, auth), 403],
    [`${role} cannot update AI generation receipt`, () => req('PATCH', 'aiGenerationReceipts/gen-1', { userId: { stringValue: 'b' } }, auth, ['userId']), 403],
    [`${role} cannot delete AI generation receipt`, () => req('DELETE', 'aiGenerationReceipts/gen-1', null, auth), 403],
  ]),
  ['review-only public query keeps 3.7.0 feeds working', () => runQuery(A, [
    { fieldFilter: { field: { fieldPath: 'review' }, op: 'EQUAL', value: { booleanValue: true } } },
  ], 'walls'), 200],
  ['URL-only redaction query keeps working', () => runQuery(A, [
    { fieldFilter: { field: { fieldPath: 'review' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'originalProtected' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'wallpaper_url' }, op: 'EQUAL', value: { stringValue: '' } } },
  ], 'walls'), 200],
  ['redacted public query keeps feeds usable', () => runQuery(A, [
    { fieldFilter: { field: { fieldPath: 'review' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'originalProtected' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'wallpaper_url' }, op: 'EQUAL', value: { stringValue: '' } } },
    ...provenanceFields.map((fieldPath) => ({ fieldFilter: { field: { fieldPath }, op: 'EQUAL', value: { stringValue: '' } } })),
  ], 'walls'), 200],
  ['no-op follow array write rejected', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com']) }, A, ['followers']), 403],
  ['follow array write rejected', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com', 'b@x.com']) }, Bu, ['followers']), 403],
  ['unfollow array write rejected', () => req('PATCH', 'usersv2/target', { followers: arr(['a@x.com']) }, Bu, ['followers']), 403],
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
  ['owner writes a valid themePrefs map', () => req('PATCH', 'usersv2/b', themeMap(themeFields), Bu, ['themePrefs']), 200],
  ['owner writes themePrefs with an extra key', () => req('PATCH', 'usersv2/b', themeMap({ ...themeFields, extra: str('x') }), Bu, ['themePrefs']), 403],
  ['owner writes themePrefs with mode sepia', () => req('PATCH', 'usersv2/b', themeMap({ ...themeFields, mode: str('sepia') }), Bu, ['themePrefs']), 403],
  ['owner writes themePrefs with a string lightAccent', () => req('PATCH', 'usersv2/b', themeMap({ ...themeFields, lightAccent: str('4293228183') }), Bu, ['themePrefs']), 403],
  ['owner writes themePrefs missing changedAt', () => req('PATCH', 'usersv2/b', themeMap(themeNoChangedAt), Bu, ['themePrefs']), 403],
  ['stranger writes themePrefs on another user doc', () => req('PATCH', 'usersv2/a', themeMap(themeFields), Bu, ['themePrefs']), 403],
  ['user writes a coin ledger entry', () => req('PATCH', 'coinTransactions/t1', {
    userId: { stringValue: 'b' }, delta: { integerValue: '500' },
  }, Bu), 403],
  ['user creates own unreviewed wall', () => req('PATCH', 'walls/w3', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, Bu), 200],
  ['admin email without a verified token creates a wall for someone else', () => req('PATCH', 'walls/w5', { email: { stringValue: 'up@x.com' }, review: { booleanValue: false } }, ADM_UNVERIFIED), 403],
  ['admin email without a verified token reads an unreviewed wall', () => req('GET', 'walls/w8', null, ADM_UNVERIFIED), 403],
  ['admin with a verified token reads an unreviewed wall', () => req('GET', 'walls/w8', null, ADM), 200],
  ['owner edits own unreviewed wall', () => req('PATCH', 'walls/w8', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, by: { stringValue: 'B' } }, Bu), 200],
  ['owner cannot forge protected upload metadata', () => req('PATCH', 'walls/forged-protection', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, originalProtected: { booleanValue: true }, originalObjectId: { stringValue: 'a'.repeat(64) } }, Bu), 403],
  ['owner cannot change protected upload markers', () => req('PATCH', 'walls/w8', { originalProtected: { booleanValue: true }, originalObjectId: { stringValue: 'a'.repeat(64) } }, Bu, ['originalProtected', 'originalObjectId']), 403],
  ['owner cannot forge moderation signals on create', () => req('PATCH', 'walls/forged-moderation', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, moderation: { mapValue: { fields: { v: { integerValue: '1' } } } } }, Bu), 403],
  ['owner cannot change moderation signals', () => req('PATCH', 'walls/w8', { moderation: { mapValue: { fields: { v: { integerValue: '1' } } } } }, Bu, ['moderation']), 403],
  ['owner unpublishes own approved wall', () => req('PATCH', 'walls/w9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, Bu), 403],
  ['owner unpublishes own approved setup', () => req('PATCH', 'setups/s9', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false } }, Bu), 403],
  ['owner deletes own rejected wall', () => req('DELETE', 'rejectedWalls/rw1', null, Bu), 200],
  ['other user deletes a rejected wall', () => req('DELETE', 'rejectedWalls/rw2', null, A), 403],
  ['owner deletes own rejected setup', () => req('DELETE', 'rejectedSetups/rs1', null, Bu), 200],
  ['signed-out reads trending/current', () => req('GET', 'trending/current', null, null), 200],
  ['user writes trending/current', () => req('PATCH', 'trending/current', { wallIds: arr(['A']) }, Bu), 403],
  ['signed-out reads moods/current', () => req('GET', 'moods/current', null, null), 200],
  ['user writes moods/current', () => req('PATCH', 'moods/current', { moods: arr([]) }, Bu), 403],
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
  ['signed-out reads a drop', () => req('GET', 'drops/2026-W42', null, null), 200],
  ['signed-out lists drops', () => runCollectionQuery(null, 'drops'), 200],
  ['user writes a drop', () => req('PATCH', 'drops/2026-W42', { count: { integerValue: '9' } }, Bu), 403],
  ['signed-out writes a drop', () => req('PATCH', 'drops/2026-W42', { count: { integerValue: '9' } }, null), 403],
  ['signed-in reads a boost', () => req('GET', 'boosts/W1', null, Bu), 200],
  ['user writes a boost', () => req('PATCH', 'boosts/W2', { wallId: { stringValue: 'W2' } }, Bu), 403],
  ['signed-in reads a draw', () => req('GET', 'draws/2026-W42', null, Bu), 200],
  ['user writes a draw', () => req('PATCH', 'draws/2026-W42', { status: { stringValue: 'settled' } }, Bu), 403],
  ['owner reads own draw ticket', () => req('GET', 'drawTickets/2026-W42_b', null, Bu), 200],
  ['user reads another uid draw ticket', () => req('GET', 'drawTickets/2026-W42_b', null, A), 403],
  ['owner queries own draw ticket by document id and uid', () => runQuery(Bu, [ticketIdFilter('2026-W42_b'), ticketUidFilter('b')]), 200],
  ['owner queries own exact ticket by document id', () => runQuery(Bu, [ticketIdFilter('2026-W42_b')]), 200],
  ['owner cannot query another uid tickets', () => runQuery(Bu, [ticketUidFilter('a')]), 403],
  ['other user query for draw ticket is rejected', () => runQuery(A, [ticketIdFilter('2026-W42_b'), ticketUidFilter('b')]), 403],
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
  ['owner queries own exact private economy doc', () => runQuery(Bu, [documentIdFilter('usersv2/b/private/economy')], 'private', 'usersv2/b'), 200],
  ['other user cannot query private economy doc', () => runQuery(A, [documentIdFilter('usersv2/b/private/economy')], 'private', 'usersv2/b'), 403],
  ['owner writes own private economy doc', () => req('PATCH', 'usersv2/b/private/economy', { rev: { integerValue: '99' } }, Bu), 403],
  ...['creatorWallCredits/test-wall', 'creatorDeletionState/b', 'creatorMemberRateDaily/b_2026-10-18',
    'usersv2/b/private/economy/creatorMembers/a'].flatMap((path) => [
    [`owner cannot read server creator store ${path}`, () => req('GET', path, null, Bu), 403],
    [`other member cannot read server creator store ${path}`, () => req('GET', path, null, A), 403],
    [`admin client cannot read server creator store ${path}`, () => req('GET', path, null, ADM), 403],
    [`signed-out cannot read server creator store ${path}`, () => req('GET', path, null, null), 403],
    [`owner cannot write server creator store ${path}`, () => req('PATCH', path, { closed: { booleanValue: true } }, Bu), 403],
    [`admin client cannot write server creator store ${path}`, () => req('PATCH', path, { closed: { booleanValue: true } }, ADM), 403],
  ]),
  ['shipped favourite create remains allowed', () => req('PATCH', 'usersv2/b/images/shipped-wall', {
    id: { stringValue: 'shipped-wall' }, provider: { stringValue: 'Prism' },
  }, Bu), 200],
  ['shipped favourite update remains allowed', () => req('PATCH', 'usersv2/b/images/shipped-wall', {
    provider: { stringValue: 'Prism' },
  }, Bu, ['provider']), 200],
  ['shipped favourite delete remains allowed', () => req('DELETE', 'usersv2/b/images/shipped-wall', null, Bu), 200],
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
  ['owner creates a wall with depth', () => req('PATCH', 'walls/w13', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, depth: depth('auto') }, Bu), 403],
  ['owner sets depth on own unreviewed wall', () => req('PATCH', 'walls/w3', { depth: depth('auto') }, Bu, ['depth']), 403],
  ['owner changes an existing depth', () => req('PATCH', 'walls/w12', { depth: depth('menu') }, Bu, ['depth']), 403],
  ['owner removes an existing depth', () => req('PATCH', 'walls/w12', {}, Bu, ['depth']), 403],
  ['owner updates another field and leaves depth untouched', () => req('PATCH', 'walls/w12', { by: { stringValue: 'B' } }, Bu, ['by']), 200],
  ['admin sets depth on a wall', () => req('PATCH', 'walls/w12', { depth: depth('menu') }, ADM, ['depth']), 200],
  ['owner creates a wall with spatial', () => req('PATCH', 'walls/w15', { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, spatial: spatial('great') }, Bu), 403],
  ['owner sets spatial on own unreviewed wall', () => req('PATCH', 'walls/w3', { spatial: spatial('great') }, Bu, ['spatial']), 403],
  ['owner changes an existing spatial', () => req('PATCH', 'walls/w14', { spatial: spatial('ok') }, Bu, ['spatial']), 403],
  ['owner removes an existing spatial', () => req('PATCH', 'walls/w14', {}, Bu, ['spatial']), 403],
  ['owner updates another field and leaves spatial untouched', () => req('PATCH', 'walls/w14', { by: { stringValue: 'B' } }, Bu, ['by']), 200],
  ['admin sets spatial on a wall', () => req('PATCH', 'walls/w14', { spatial: spatial('ok') }, ADM, ['spatial']), 200],
  ...['searchTerms', 'visionLabels'].flatMap((key) => [
    [`owner creates a wall with ${key}`, () => req('PATCH', `walls/create-${key}`, { email: { stringValue: 'b@x.com' }, review: { booleanValue: false }, [key]: arr(['stuffed']) }, Bu), 403],
    [`owner sets ${key} on own unreviewed wall`, () => req('PATCH', 'walls/w3', { [key]: arr(['stuffed']) }, Bu, [key]), 403],
    [`owner changes an existing ${key}`, () => req('PATCH', 'walls/w14', { [key]: arr(['stuffed']) }, Bu, [key]), 403],
    [`owner removes an existing ${key}`, () => req('PATCH', 'walls/w14', {}, Bu, [key]), 403],
    [`admin sets ${key} on a wall`, () => req('PATCH', 'walls/w14', { [key]: arr(['admin']) }, ADM, [key]), 200],
  ]),
  ['owner updates another field and leaves searchTerms and visionLabels untouched', () => req('PATCH', 'walls/w14', { by: { stringValue: 'B' } }, Bu, ['by']), 200],
  ['owner creates a folder', () => req('PATCH', 'folders/f1', folderFields('b'), Bu), 200],
  ['owner reads own folder', () => req('GET', 'folders/fb', null, Bu), 200],
  ['owner lists own folders by ownerId newest first', () => runQuery(Bu, [ownerFilter('b')], 'folders', '', newestFirst('updatedAt')), 200],
  ['owner renames own folder', () => req('PATCH', 'folders/f1', { name: str('Calm'), updatedAt: ts() }, Bu, ['name', 'updatedAt']), 200],
  ['owner adds an item with a provider_id key', () => req('PATCH', 'folders/f1/items/wallhaven_abc', itemFields('b'), Bu), 200],
  ['owner reads own folder item', () => req('GET', 'folders/fb/items/wallhaven_abc', null, Bu), 200],
  ['owner lists own folder items newest first with preview limit', () => runQuery(Bu, [ownerFilter('b')], 'items', 'folders/fb', newestFirst('addedAt', 4)), 200],
  ['owner fetches own items for local sorting and deletion without a composite index', () => runQuery(Bu, [ownerFilter('b')], 'items', 'folders/fb'), 200],
  ['owner can check missing folder membership', () => req('GET', 'folders/fb/items/wallhaven_missing', null, Bu), 404],
  ['stranger cannot check missing folder membership', () => req('GET', 'folders/fb/items/wallhaven_missing', null, C), 403],
  ['owner updates own folder item', () => req('PATCH', 'folders/f1/items/wallhaven_abc', { thumb: str('https://example.com/new.jpg') }, Bu, ['thumb']), 200],
  ['owner removes an item', () => req('DELETE', 'folders/f1/items/wallhaven_abc', null, Bu), 200],
  ['owner deletes own folder', () => req('DELETE', 'folders/f1', null, Bu), 200],
  ['stranger cannot read a folder', () => req('GET', 'folders/fb', null, C), 403],
  ['stranger cannot list folders of another user', () => runQuery(C, [ownerFilter('b')], 'folders'), 403],
  ['owner cannot list all users folders without a filter', () => runCollectionQuery(Bu, 'folders'), 403],
  ['stranger cannot rename a folder', () => req('PATCH', 'folders/fb', { name: str('Mine'), updatedAt: ts() }, C, ['name', 'updatedAt']), 403],
  ['stranger cannot delete a folder', () => req('DELETE', 'folders/fb', null, C), 403],
  ['stranger cannot read folder items', () => req('GET', 'folders/fb/items/wallhaven_abc', null, C), 403],
  ['stranger cannot list folder items', () => runQuery(C, [ownerFilter('c')], 'items', 'folders/fb', newestFirst('addedAt')), 403],
  ['stranger cannot add an item to a folder', () => req('PATCH', 'folders/fb/items/pexels_9', itemFields('c', '9', 'Pexels'), C), 403],
  ['stranger cannot update a folder item', () => req('PATCH', 'folders/fb/items/wallhaven_abc', itemFields('c'), C), 403],
  ['stranger cannot delete a folder item', () => req('DELETE', 'folders/fb/items/wallhaven_abc', null, C), 403],
  ['signed-out user cannot read a folder', () => req('GET', 'folders/fb'), 403],
  ['signed-out user cannot list folders', () => runQuery(undefined, [ownerFilter('b')], 'folders'), 403],
  ['signed-out user cannot create a folder', () => req('PATCH', 'folders/signed-out', folderFields('b')), 403],
  ['signed-out user cannot update a folder', () => req('PATCH', 'folders/fb', { name: str('Mine') }, undefined, ['name']), 403],
  ['signed-out user cannot delete a folder', () => req('DELETE', 'folders/fb'), 403],
  ['signed-out user cannot read an item', () => req('GET', 'folders/fb/items/wallhaven_abc'), 403],
  ['signed-out user cannot list items', () => runQuery(undefined, [ownerFilter('b')], 'items', 'folders/fb'), 403],
  ['signed-out user cannot create an item', () => req('PATCH', 'folders/fb/items/pexels_9', itemFields('b', '9', 'Pexels')), 403],
  ['signed-out user cannot update an item', () => req('PATCH', 'folders/fb/items/wallhaven_abc', itemFields('b')), 403],
  ['signed-out user cannot delete an item', () => req('DELETE', 'folders/fb/items/wallhaven_abc'), 403],
  ['folder for another owner is refused', () => req('PATCH', 'folders/f2', folderFields('c'), Bu), 403],
  ['empty folder name is refused', () => req('PATCH', 'folders/f3', folderFields('b', ''), Bu), 403],
  ['folder name over 50 chars is refused', () => req('PATCH', 'folders/f4', folderFields('b', 'x'.repeat(51)), Bu), 403],
  ['folder name with 50 chars is accepted', () => req('PATCH', 'folders/length50', folderFields('b', 'x'.repeat(50)), Bu), 200],
  ['whitespace-only folder name is refused', () => req('PATCH', 'folders/spaces', folderFields('b', ' \t\n'), Bu), 403],
  ['untrimmed folder name is refused', () => req('PATCH', 'folders/f5', folderFields('b', ' Blue '), Bu), 403],
  ['folder with a public field is refused', () => req('PATCH', 'folders/f6', folderFields('b', 'Blue', { public: { booleanValue: true } }), Bu), 403],
  ['folder with five covers is refused', () => req('PATCH', 'folders/f7', folderFields('b', 'Blue', { covers: arr(['a', 'b', 'c', 'd', 'e']) }), Bu), 403],
  ['changing a folder ownerId is refused', () => req('PATCH', 'folders/fb', { ownerId: str('c') }, Bu, ['ownerId']), 403],
  ['negative itemCount is refused', () => req('PATCH', 'folders/fb', { itemCount: { integerValue: '-1' }, updatedAt: ts() }, Bu, ['itemCount', 'updatedAt']), 403],
  ['item with another ownerId is refused', () => req('PATCH', 'folders/fb/items/wallhaven_xyz', itemFields('c', 'xyz'), Bu), 403],
  ['item key without the provider is refused', () => req('PATCH', 'folders/fb/items/abc', itemFields('b'), Bu), 403],
  ['item key for another provider is refused', () => req('PATCH', 'folders/fb/items/pexels_abc', itemFields('b'), Bu), 403],
  ['item with an unknown provider is refused', () => req('PATCH', 'folders/fb/items/unknown_abc', itemFields('b', 'abc', 'Unknown'), Bu), 403],
  ...['Prism', 'wall_of_the_day', 'WallOfTheDay', 'WallHaven', 'Pexels'].map((provider) => [
    `folder accepts favourite provider ${provider} with its lowercased key`,
    () => req('PATCH', `folders/fb/items/${provider.toLowerCase()}_parity`, {
      ...itemFields('b', 'parity', provider), category: str('Blue'), views: str('1'), resolution: str('10x20'),
      fav: str('2'), size: str('200'), photographer: str('Artist'), collections: arr(['Blue']),
      depth: depth('person'), createdAt: ts(), favouritedAt: ts(),
    }, Bu), 200,
  ]),
  ['empty folder item id is refused', () => req('PATCH', 'folders/fb/items/wallhaven_', itemFields('b', ''), Bu), 403],
  ['item can preserve the source wallpaper document id', () => req('PATCH', 'folders/fb/items/prism_source', { ...itemFields('b', 'source', 'Prism'), wallpaperDocumentId: str('source-doc') }, Bu), 200],
  ['item source document id must be a string', () => req('PATCH', 'folders/fb/items/prism_invalid', { ...itemFields('b', 'invalid', 'Prism'), wallpaperDocumentId: { integerValue: '5' } }, Bu), 403],
  ['item source document id cannot be empty', () => req('PATCH', 'folders/fb/items/prism_empty', { ...itemFields('b', 'empty', 'Prism'), wallpaperDocumentId: str('') }, Bu), 403],
  ['item can keep a Spatial Scene wall\'s spatial map', () => req('PATCH', 'folders/fb/items/prism_spatial', { ...itemFields('b', 'spatial', 'Prism'), spatial: { mapValue: { fields: { tier: str('scene'), map: str('https://example.com/d.png') } } } }, Bu), 200],
  ['item spatial must be a map', () => req('PATCH', 'folders/fb/items/prism_spatialstr', { ...itemFields('b', 'spatialstr', 'Prism'), spatial: str('scene') }, Bu), 403],
  ['changing an item ownerId is refused', () => req('PATCH', 'folders/fb/items/wallhaven_abc', { ownerId: str('c') }, Bu, ['ownerId']), 403],
  ['item with an extra field is refused', () => req('PATCH', 'folders/fb/items/wallhaven_extra', { ...itemFields('b', 'extra'), public: { booleanValue: true } }, Bu), 403],
  ['item in a missing folder is refused', () => req('PATCH', 'folders/missing/items/wallhaven_abc', itemFields('b'), Bu), 403],
  ['owner updates own seeded folder count', () => req('PATCH', 'folders/fb', { itemCount: { integerValue: '1' }, covers: arr(['https://example.com/t.jpg']), updatedAt: ts() }, Bu, ['itemCount', 'covers', 'updatedAt']), 200],
  ['owner creates a folder and first item atomically', () => commitDocs(Bu, [
    ['folders/atomic', folderFields('b', 'Atomic', { itemCount: { integerValue: '1' }, covers: arr(['https://example.com/t.jpg']) })],
    ['folders/atomic/items/wallhaven_first', itemFields('b', 'first')],
  ]), 200],
  ['atomic folder creation cannot insert another owner item', () => commitDocs(Bu, [
    ['folders/atomic-bad', folderFields('b')], ['folders/atomic-bad/items/wallhaven_first', itemFields('c', 'first')],
  ]), 403],
  ['owner can delete a parent with remaining items', () => req('DELETE', 'folders/reused', null, Bu), 200],
  ['another user can reuse a deleted folder id', () => req('PATCH', 'folders/reused', folderFields('c'), C), 200],
  ['recreated folder owner cannot read the previous owner item', () => req('GET', 'folders/reused/items/wallhaven_private', null, C), 403],
  ['previous item owner cannot read through another owner parent', () => req('GET', 'folders/reused/items/wallhaven_private', null, Bu), 403],
  ['recreated folder owner cannot overwrite the previous owner item', () => req('PATCH', 'folders/reused/items/wallhaven_private', itemFields('c', 'private'), C), 403],
  ['recreated folder owner cannot delete the previous owner item', () => req('DELETE', 'folders/reused/items/wallhaven_private', null, C), 403],
  ['recreated folder owner cannot list the previous owner items without a filter', () => runCollectionQuery(C, 'items', 'folders/reused'), 403],
  ['recreated folder owner can query only own items', () => runQuery(C, [ownerFilter('c')], 'items', 'folders/reused'), 200],
  ['previous item owner cannot delete in a recreated folder owned by another user', () => req('DELETE', 'folders/reused/items/wallhaven_private', null, Bu), 403],
  ['orphan item cannot be read while its parent is absent', () => req('GET', 'folders/absent/items/wallhaven_orphan', null, Bu), 403],
  ['previous item owner can delete an orphan with no parent', () => req('DELETE', 'folders/absent/items/wallhaven_orphan', null, Bu), 200],
  ['account deletion closes the folder write barrier', () => req('PATCH', 'creatorDeletionState/b', { closed: { booleanValue: true } }, 'owner'), 200],
  ['deleting account cannot create more folders', () => req('PATCH', 'folders/after-close', folderFields('b'), Bu), 403],
  ['deleting account cannot update a folder', () => req('PATCH', 'folders/fb', { name: str('Too late') }, Bu, ['name']), 403],
  ['deleting account cannot create an item', () => req('PATCH', 'folders/fb/items/prism_late', itemFields('b', 'late', 'Prism'), Bu), 403],
  ['deleting account cannot update an item', () => req('PATCH', 'folders/fb/items/wallhaven_abc', { thumb: str('https://example.com/late.jpg') }, Bu, ['thumb']), 403],
  ['deleting account can still remove its items', () => req('DELETE', 'folders/fb/items/wallhaven_abc', null, Bu), 200],
  ['deleting account can still remove its folders', () => req('DELETE', 'folders/atomic', null, Bu), 200],
];
await seed();
let bad = 0;
for (const [name, run, want] of cases) { const got = await run(); if (got !== want) bad++; console.log(`${got === want ? 'PASS' : 'FAIL'} ${name}: ${got} (want ${want})`); }
process.exit(bad ? 1 : 0);
