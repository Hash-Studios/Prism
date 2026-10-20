import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { webcrypto } from 'node:crypto';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { AiQuotaCoordinator, gptImageSize, seedreamImageSize } from '../src/ai.ts';
import { verifyFirebaseIdTokenFromRequest } from '../src/firebase_auth.ts';
import worker from '../src/index.ts';
import { formatCount, renderOgCardHtml } from '../src/og_card.ts';

globalThis.crypto ??= webcrypto;

const projectId = 'prism-test-project';
const { publicKey, privateKey } = await crypto.subtle.generateKey(
  {
    name: 'RSASSA-PKCS1-v1_5',
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: 'SHA-256',
  },
  true,
  ['sign', 'verify'],
);
const publicJwk = {
  ...await crypto.subtle.exportKey('jwk', publicKey),
  kid: 'test-key',
  use: 'sig',
  alg: 'RS256',
};
const jwksCache = JSON.stringify({
  fetchedAt: new Date().toISOString(),
  expiresAtMs: Date.now() + 60_000,
  keys: [publicJwk],
});

test('Firebase verifier accepts a valid signed token and rejects tampering', async () => {
  const token = await makeToken({ sub: 'user-1' });
  const env = authEnv();
  const request = new Request('https://worker.test/api/ai/generations', {
    headers: { authorization: `Bearer ${token}` },
  });

  assert.equal((await verifyFirebaseIdTokenFromRequest(request, env))?.userId, 'user-1');

  const parts = token.split('.');
  parts[2] = `${parts[2][0] === 'A' ? 'B' : 'A'}${parts[2].slice(1)}`;
  const tampered = new Request(request, { headers: { authorization: `Bearer ${parts.join('.')}` } });
  assert.equal(await verifyFirebaseIdTokenFromRequest(tampered, env), null);
});

test('Firebase verifier rejects missing or invalid project claims before key lookup', async () => {
  const env = {
    FIREBASE_PROJECT_ID: projectId,
    AI_STATE_KV: { get: async () => { throw new Error('unexpected JWKS lookup'); } },
  };

  const invalidClaims = [
    { sub: 'user-1', aud: 'other-project' },
    { sub: 'user-1', iss: 'https://securetoken.google.com/other-project' },
    { sub: 'user-1', exp: Math.floor(Date.now() / 1000) - 3600 },
    { sub: '' },
  ];
  for (const claims of invalidClaims) {
    const token = await makeToken(claims);
    assert.equal(
      await verifyFirebaseIdTokenFromRequest(
        new Request('https://worker.test', { headers: { authorization: `Bearer ${token}` } }),
        env,
      ),
      null,
      `Expected claims ${JSON.stringify(claims)} to be rejected`,
    );
  }
});

test('Worker routes association requests and rejects unauthenticated AI generation', async () => {
  const association = await worker.fetch(
    new Request('https://prismwalls.com/.well-known/apple-app-site-association'),
    workerEnv(),
    { waitUntil() {} },
  );
  assert.equal(association.status, 200);
  const associatedPaths = (await association.json()).applinks.details[0].paths;
  for (const path of ['/share', '/share/*', '/user/*', '/shop', '/drops', '/leaderboard', '/draw', '/coin-history']) {
    assert.ok(associatedPaths.includes(path), `AASA paths missing ${path}`);
  }

  const aiResponse = await worker.fetch(
    new Request('https://prismwalls.com/api/ai/generations', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: 'A quiet mountain lake', qualityTier: 'fast' }),
    }),
    workerEnv(),
    { waitUntil() {} },
  );
  assert.equal(aiResponse.status, 401);
});

test('AI variations enforce generation ownership before quota or provider work', async () => {
  const token = await makeToken({ sub: 'alice' });
  const kv = new MemoryKv([
    ['ai:firebase:jwks:v1', jwksCache],
    ['ai:gen:gen-owned-by-bob', JSON.stringify({
      generationId: 'gen-owned-by-bob',
      userId: 'bob',
      prompt: 'A quiet mountain lake',
      stylePreset: 'minimal',
      qualityTier: 'fast',
      width: 1080,
      height: 1920,
    })],
  ]);
  let quotaCalls = 0;
  const env = workerEnv({
    AI_STATE_KV: kv,
    AI_QUOTA_DO: {
      idFromName: () => 'quota-object',
      get: () => ({ fetch: async () => { quotaCalls += 1; throw new Error('unexpected quota call'); } }),
    },
  });

  const originalFetch = globalThis.fetch;
  let outboundCalls = 0;
  globalThis.fetch = async () => {
    outboundCalls += 1;
    throw new Error('unexpected outbound network or provider call');
  };
  let response;
  try {
    response = await worker.fetch(
      new Request('https://prismwalls.com/api/ai/generations/gen-owned-by-bob/variations', {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ variationPrompt: 'warmer light' }),
      }),
      env,
      { waitUntil() {} },
    );
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.equal(response.status, 403);
  assert.equal(quotaCalls, 0);
  assert.equal(outboundCalls, 0);
});

test('quota coordinator enforces user caps and provider budgets, then releases reservations', async () => {
  const storage = new MemoryStorage();
  const coordinator = new AiQuotaCoordinator({ storage });
  const capRequest = (userId) => quotaRequest({
    op: 'user_daily_cap_try_increment', userId, dayKey: '2026-09-29', cap: 1,
  });

  assert.deepEqual(await responseJson(await coordinator.fetch(capRequest('alice'))), {
    ok: true, allowed: true, current: 1,
  });
  assert.deepEqual(await responseJson(await coordinator.fetch(capRequest('alice'))), {
    ok: true, allowed: false, current: 1,
  });

  const reserve = () => quotaRequest({
    op: 'provider_budget_reserve',
    provider: 'fal',
    dayKey: '2026-09-29',
    monthKey: '2026-09',
    estimatedCostUsd: 0.01,
    dailyBudgetUsd: 0.01,
    monthlyBudgetUsd: 0.01,
  });
  const firstReservation = await responseJson(await coordinator.fetch(reserve()));
  assert.equal(firstReservation.allowed, true);
  assert.equal((await responseJson(await coordinator.fetch(reserve()))).allowed, false);
  assert.deepEqual(
    await responseJson(await coordinator.fetch(quotaRequest({
      op: 'provider_budget_release', reservationId: firstReservation.reservationId,
    }))),
    { ok: true, released: true },
  );
  assert.equal((await responseJson(await coordinator.fetch(reserve()))).allowed, true);
});

const ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36';
const IOS_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1';
const DESKTOP_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
const SHARE_PATH = '/share?id=wall-1&source=prism&provider=Prism'
  + '&thumb=https%3A%2F%2Fraw.githubusercontent.com%2FHash-Studios%2Fx.jpg';

async function getShare(userAgent, path = SHARE_PATH, env = workerEnv({
  PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
  APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
})) {
  return worker.fetch(
    new Request(`https://prismwalls.com${path}`, { headers: { 'user-agent': userAgent } }),
    env,
    { waitUntil() {} },
  );
}

test('share landing page renders on Android with an intent link and no instant redirect', async () => {
  const response = await getShare(ANDROID_UA);
  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /text\/html/);
  const body = await response.text();
  assert.match(body, /cloudfunctions\.net\/ownedThumbnail\/wall-1/);
  assert.doesNotMatch(body, /raw\.githubusercontent\.com/);
  assert.match(body, /wall-1 - Prism/);
  assert.match(body, /Open in Prism/);
  assert.match(body, /intent:\/\/prismwalls\.com\/share\?[^"]*#Intent;scheme=https;package=com\.hash\.prism;S\.browser_fallback_url=/);
  assert.match(body, /Get it on Google Play/);
  assert.doesNotMatch(body, /App Store/);
  assert.doesNotMatch(body, /http-equiv="refresh"/);
  assert.doesNotMatch(body, /location\.replace/);
  assert.match(body, /property="og:image"/);
});

test('share landing page offers the universal link and App Store on iOS, both stores on desktop', async () => {
  const ios = await (await getShare(IOS_UA)).text();
  assert.match(ios, /href="https:\/\/prismwalls\.com\/share\?id=wall-1[^"]*"[^>]*>Open in Prism/);
  assert.match(ios, /Download on the App Store/);
  assert.doesNotMatch(ios, /Get it on Google Play/);

  const desktop = await (await getShare(DESKTOP_UA)).text();
  assert.match(desktop, /Get it on Google Play/);
  assert.match(desktop, /Download on the App Store/);
  assert.doesNotMatch(desktop, />Open in Prism</);
});

test('share landing page drops preview images from hosts that are not allowlisted', async () => {
  const body = await (await getShare(
    ANDROID_UA,
    '/share?id=wall-2&thumb=https%3A%2F%2Fevil.example.com%2Fx.jpg',
  )).text();
  assert.doesNotMatch(body, /src="[^"]*evil\.example\.com/);
  assert.doesNotMatch(body, /og:image" content="[^"]*evil\.example\.com/);
  assert.equal((await getShare(ANDROID_UA, '/share')).status, 200);
});

test('owned thumbnail previews allow only the exact public endpoint', async () => {
  const endpoint = 'https://asia-south1-prism-wallpapers.cloudfunctions.net/ownedThumbnail/wall_1-test';
  for (const [image, allowed] of [
    [endpoint, true],
    [endpoint.replace('https:', 'http:'), false],
    [endpoint.replace('.net/', '.net:8443/'), false],
    [endpoint.replace('.net/', '.net:443/'), false],
    [endpoint.replace('https://', 'https://user:pass@'), false],
    [`${endpoint}?token=secret`, false],
    [`${endpoint}#fragment`, false],
    [endpoint.replace('/ownedThumbnail/', '/ownedOriginal/'), false],
    [`${endpoint}/extra`, false],
    [endpoint.replace('wall_1-test', 'a'.repeat(201)), false],
  ]) {
    const body = await (await getShare(ANDROID_UA, `/share?id=wall&source=wallhaven&thumb=${encodeURIComponent(image)}`)).text();
    assert.equal(/src="[^"]*asia-south1-prism-wallpapers\.cloudfunctions\.net/.test(body), allowed, image);
  }
});

test('allowlisted app pages have safe generic landings on both web hosts', async () => {
  for (const host of ['prismwalls.com', 'www.prismwalls.com']) {
    const response = await worker.fetch(
      new Request(`https://${host}/dashboard/search?utm_campaign=a%2Fb`, { headers: { 'user-agent': ANDROID_UA } }),
      workerEnv({
        PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
        APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
      }),
      { waitUntil() {} },
    );
    assert.equal(response.status, 200);
    const body = await response.text();
    assert.match(body, /Open in Prism/);
    assert.match(body, /Get it on Google Play/);
    assert.match(body, /intent:\/\/prismwalls\.com\/dashboard\/search\?utm_campaign=a%2Fb#Intent;scheme=https/);
  }
});

test('broader Cloudflare route prefixes pass unrelated website paths to the origin', async () => {
  const originalFetch = globalThis.fetch;
  const originRequests = [];
  globalThis.fetch = async (request) => {
    originRequests.push(new Request(request));
    return new Response('Next.js origin', { status: 200 });
  };
  try {
    for (const url of [
      'https://prismwalls.com/shopper',
      'https://prismwalls.com/shareholder?campaign=summer',
      'https://www.prismwalls.com/library-tools',
    ]) {
      const response = await worker.fetch(new Request(url), workerEnv(), { waitUntil() {} });
      assert.equal(response.status, 200, url);
      assert.equal(await response.text(), 'Next.js origin', url);
    }
    const postResponse = await worker.fetch(
      new Request('https://prismwalls.com/shopper', { method: 'POST', body: 'submitted' }),
      workerEnv(),
      { waitUntil() {} },
    );
    assert.equal(postResponse.status, 200);
    assert.equal(await postResponse.text(), 'Next.js origin');

    for (const url of [
      'https://prismwalls.com/api/not-a-worker-route',
      'https://prismwalls.com/.well-known/not-a-file',
    ]) {
      const ownedMiss = await worker.fetch(new Request(url), workerEnv(), { waitUntil() {} });
      assert.equal(ownedMiss.status, 404, url);
    }
    const unsupportedMethod = await worker.fetch(
      new Request('https://prismwalls.com/shop', { method: 'POST', body: 'submitted' }),
      workerEnv(),
      { waitUntil() {} },
    );
    assert.equal(unsupportedMethod.status, 404);
  } finally {
    globalThis.fetch = originalFetch;
  }
  assert.deepEqual(originRequests.map((request) => [request.url, request.method]), [
    ['https://prismwalls.com/shopper', 'GET'],
    ['https://prismwalls.com/shareholder?campaign=summer', 'GET'],
    ['https://www.prismwalls.com/library-tools', 'GET'],
    ['https://prismwalls.com/shopper', 'POST'],
  ]);
  assert.equal(await originRequests.at(-1).text(), 'submitted');
});

test('every Dart deep-link catalog example resolves to a Worker landing', async () => {
  const catalogPath = new URL('../../../../lib/core/router/deep_link_route_catalog.dart', import.meta.url);
  const source = readFileSync(fileURLToPath(catalogPath), 'utf8');
  const examples = [
    ...[...source.matchAll(/DeepLinkRouteExample\(\s*'([^']+)'/g)].map((match) => match[1]),
    '/wallpaper/wall1/position?provider=wallhaven&utm_campaign=warm%2Fwood',
    '/clock-preview?wallpaperId=wall1&provider=prism',
    '/choose-wallpaper?workflow=photoPreview',
    '/choose-wallpaper?workflow=clockPreview',
  ];
  assert.ok(examples.length > 0, 'expected deep-link route catalog examples');

  for (const example of examples) {
    const uri = new URL(example, 'https://prismwalls.com');
    if (uri.pathname === '/') continue; // Next.js owns the marketing homepage.
    for (const host of ['prismwalls.com', 'www.prismwalls.com']) {
      const response = await worker.fetch(
        new Request(`https://${host}${uri.pathname}${uri.search}`, { headers: { 'user-agent': ANDROID_UA } }),
        workerEnv({
          PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
          APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
        }),
        { waitUntil() {} },
      );
      assert.equal(response.status, 200, `${host}${uri.pathname}${uri.search}`);
    }
  }
});

test('direct app landings preserve encoded query values and reject unsupported workflows', async () => {
  const env = workerEnv({
    PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
  });
  const path = '/wallpaper/wall1/position?provider=wallhaven&utm_campaign=warm%2Fwood';
  const response = await worker.fetch(
    new Request(`https://prismwalls.com${path}`, { headers: { 'user-agent': ANDROID_UA } }),
    env,
    { waitUntil() {} },
  );
  assert.equal(response.status, 200);
  assert.match(await response.text(), /intent:\/\/prismwalls\.com\/wallpaper\/wall1\/position\?provider=wallhaven&amp;utm_campaign=warm%2Fwood#Intent;scheme=https/);

  for (const path of [
    '/choose-wallpaper?workflow=unsupported',
    '/choose-wallpaper?workflow=photoPreview&workflow=clockPreview',
    '/clock-preview?wallpaperId=wall1&provider=unsupported',
    '/wallpaper/wall1/position?provider=downloaded',
    '/dashboard/search?q=sunset',
  ]) {
    const invalid = await worker.fetch(new Request(`https://prismwalls.com${path}`), env, { waitUntil() {} });
    assert.equal(invalid.status, 302, path);
    assert.match(invalid.headers.get('location') ?? '', /^https:\/\/play\.google\.com\//, path);
  }
});

test('page short links preserve typed app paths and reject schemes, hosts and unlisted paths', async () => {
  const env = workerEnv();
  const valid = await postLink(env, { type: 'page', payload: { path: '/drops/week-42?utm_source=mail&utm_campaign=a%2Fb' } });
  assert.equal(valid.status, 201);
  const saved = JSON.parse(await env.LINKS_KV.get((await valid.json()).code));
  assert.equal(saved.type, 'page');
  assert.equal(saved.canonical_url, 'https://prismwalls.com/drops/week-42?utm_source=mail&utm_campaign=a%2Fb');

  const encodedCollection = await postLink(env, {
    type: 'page',
    payload: { path: '/collection/soft%20light?utm_source=mail&utm_campaign=room%2Fone' },
  });
  assert.equal(encodedCollection.status, 201);
  const encodedRecord = JSON.parse(await env.LINKS_KV.get((await encodedCollection.json()).code));
  assert.equal(encodedRecord.canonical_url, 'https://prismwalls.com/collection/soft%20light?utm_source=mail&utm_campaign=room%2Fone');

  for (const path of [
    'https://evil.example/redirect', '//evil.example/redirect', 'prism://shop', '/privacy',
    '/drops/..%2Fprivacy', '/collection/%2Fsecret', '/coin-history?next=javascript%3Aalert%281%29',
  ]) {
    const response = await postLink(env, { type: 'page', payload: { path } });
    assert.equal(response.status, 400, path);
    assert.equal((await response.json()).error, 'invalid_canonical_url', path);
  }
});

test('legacy user, setup and referral aliases remain safe on web landings', async () => {
  for (const path of [
    '/profile/maya?utm_source=mail',
    '/fprofile?username=maya',
    '/share-setup?setupName=calm-room',
    '/referral?inviterId=inviter-1&utm_campaign=summer',
    '/user?identifier=maya&utm_source=mail',
    '/refer?userID=inviter-1',
  ]) {
    const response = await getShare(
      ANDROID_UA,
      path,
      workerEnv({
        PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
        APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
      }),
    );
    assert.equal(response.status, 200, path);
    assert.match(await response.text(), /Open in Prism/, path);
  }
});

test('short link page for a stored share record renders the same landing', async () => {
  const links = new MemoryKv([['AbCdEfGh', JSON.stringify({
    code: 'AbCdEfGh',
    type: 'share',
    canonical_url: `https://prismwalls.com${SHARE_PATH}`,
    created_at: new Date().toISOString(),
    preview: { title: 'Sunset - Prism', username: 'maya', image_source_url: 'https://images.pexels.com/a.jpg' },
    version: 1,
  })]]);
  const env = workerEnv({
    LINKS_KV: links,
    PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
  });
  const body = await (await getShare(ANDROID_UA, '/l/AbCdEfGh', env)).text();
  assert.match(body, /Sunset - Prism/);
  assert.match(body, /by @maya/);
  assert.match(body, /cloudfunctions\.net\/ownedThumbnail\/wall-1/);
  assert.doesNotMatch(body, /http-equiv="refresh"/);

  const queryAlias = await getShare(ANDROID_UA, '/l?code=AbCdEfGh&utm_source=campaign', env);
  assert.equal(queryAlias.status, 200);
  assert.match(await queryAlias.text(), /Sunset - Prism/);
  for (const invalid of [
    '/l?code=short',
    '/l?code=AbCdEfGh&code=Another1',
    '/l?code=AbCdEfGh&redirect=https%3A%2F%2Fevil.example',
  ]) {
    assert.equal((await getShare(ANDROID_UA, invalid, env)).status, 400, invalid);
  }
});

function aiEnv(kv, coordinator, overrides = {}) {
  return workerEnv({
    AI_STATE_KV: kv,
    AI_QUOTA_DO: {
      idFromName: () => 'quota-object',
      get: () => ({ fetch: (url, init) => coordinator.fetch(new Request(url, init)) }),
    },
    FAL_API_KEY: 'test-key',
    ...overrides,
  });
}

async function postGeneration(env, extra = {}, token = undefined) {
  const bearer = token ?? await makeToken({ sub: 'alice' });
  return worker.fetch(
    new Request('https://prismwalls.com/api/ai/generations', {
      method: 'POST',
      headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: 'A quiet mountain lake', qualityTier: 'fast', ...extra }),
    }),
    env,
    { waitUntil() {} },
  );
}

function mockFal({
  providerStatus = 200, imageSize = 4096, imageStatus = 200, firestore = null, stats = {}, falPayload = {},
} = {}) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.startsWith('https://firestore.googleapis.com/') && firestore != null) {
      stats.firestore = (stats.firestore ?? 0) + 1;
      return firestore(url, init);
    }
    if (url.startsWith('https://fal.run/')) {
      stats.fal = (stats.fal ?? 0) + 1;
      stats.falRequest = { url, authorization: new Headers(init.headers).get('authorization'), body: JSON.parse(init.body) };
      return providerStatus === 200
        ? Response.json({ images: [{ url: 'https://fal.media/image.png' }], ...falPayload })
        : new Response('boom', { status: providerStatus });
    }
    if (url === 'https://fal.media/image.png') {
      if (imageStatus !== 200) return new Response('gone', { status: imageStatus });
      return new Response(new Uint8Array(imageSize), { headers: { 'content-type': 'image/png' } });
    }
    throw new Error(`unexpected fetch ${url}`);
  };
  return () => { globalThis.fetch = originalFetch; };
}

function aiKv(hardUserDailyCap = 1) {
  const kv = new MemoryKv([
    ['ai:firebase:jwks:v1', jwksCache],
    ['ai:routing:active', JSON.stringify({ hardUserDailyCap })],
  ]);
  kv.delete = async (key) => kv.del(key);
  return kv;
}

test('a failed generation gives the daily cap back so the user can retry', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const env = aiEnv(aiKv(), coordinator);

  const restoreFailing = mockFal({ providerStatus: 500 });
  try {
    assert.equal((await postGeneration(env)).status, 502);
  } finally {
    restoreFailing();
  }

  const restoreWorking = mockFal();
  try {
    assert.equal((await postGeneration(env)).status, 200);
    assert.equal((await postGeneration(env)).status, 429);
  } finally {
    restoreWorking();
  }
});

test('an unsafe output keeps the daily cap because the provider already billed', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const env = aiEnv(aiKv(), coordinator);

  const restoreUnsafe = mockFal({ imageSize: 16 });
  try {
    assert.equal((await postGeneration(env)).status, 502);
  } finally {
    restoreUnsafe();
  }

  const restoreWorking = mockFal();
  try {
    assert.equal((await postGeneration(env)).status, 429);
  } finally {
    restoreWorking();
  }
});

test('an unsafe output stops the request so a second provider is never billed', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const kv = aiKv();
  await kv.put('ai:routing:active', JSON.stringify({
    hardUserDailyCap: 5,
    fallbackOrder: ['fal', 'gemini'],
    providers: { gemini: { enabled: true, weight: 0 } },
  }));
  const env = aiEnv(kv, coordinator, { GEMINI_API_KEY: 'test-gemini-key' });

  let providerCalls = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.startsWith('https://fal.run/')) {
      providerCalls += 1;
      return Response.json({ images: [{ url: 'https://fal.media/image.png' }] });
    }
    if (url === 'https://fal.media/image.png') {
      return new Response(new Uint8Array(16), { headers: { 'content-type': 'image/png' } });
    }
    if (url.startsWith('https://generativelanguage.googleapis.com/')) {
      providerCalls += 1;
      return Response.json({
        candidates: [{ content: { parts: [{ inlineData: { data: 'AAAA', mimeType: 'image/png' } }] } }],
      });
    }
    throw new Error(`unexpected fetch ${url}`);
  };
  try {
    assert.equal((await postGeneration(env)).status, 502);
  } finally {
    globalThis.fetch = originalFetch;
  }
  assert.equal(providerCalls, 1);
});

test('a failed image download keeps the daily cap and the budget spend because fal already billed', async () => {
  const storage = new MemoryStorage();
  const coordinator = new AiQuotaCoordinator({ storage });
  const env = aiEnv(aiKv(), coordinator);

  const restoreBroken = mockFal({ imageStatus: 500 });
  try {
    assert.equal((await postGeneration(env)).status, 502);
    assert.equal((await postGeneration(env)).status, 429);
  } finally {
    restoreBroken();
  }

  const spent = await storage.get(`provider:fal:daily:${new Date().toISOString().slice(0, 10)}`);
  assert.equal(spent, 0.006);
});

test('a watermark failure still returns success, keeps the original and defers the public image', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const kv = aiKv();
  const env = aiEnv(kv, coordinator);

  const restore = mockFal();
  let payload;
  try {
    const response = await postGeneration(env);
    assert.equal(response.status, 200);
    payload = await response.json();
  } finally {
    restore();
  }

  const { imageUrl, watermarkedImageUrl } = payload.imageUrls;
  const original = await worker.fetch(new Request(imageUrl), env, { waitUntil() {} });
  assert.equal(original.status, 200);
  const pending = await worker.fetch(new Request(watermarkedImageUrl), env, { waitUntil() {} });
  assert.equal(pending.status, 503);
  assert.equal(pending.headers.get('retry-after'), '30');

  const budget = await coordinator.fetch(quotaRequest({
    op: 'provider_budget_read', provider: 'fal', dayKey: new Date().toISOString().slice(0, 10),
    monthKey: new Date().toISOString().slice(0, 7),
  }));
  assert.ok((await responseJson(budget)).dailySpentUsd > 0);
});

test('Seedream sizing keeps the requested aspect ratio and meets the fal pixel minimum', () => {
  const minPixels = 2560 * 1440;
  const phone = seedreamImageSize(944, 2048);
  assert.ok(Math.abs(phone.width / phone.height - 944 / 2048) < 0.002, JSON.stringify(phone));
  assert.ok(phone.width * phone.height >= minPixels, JSON.stringify(phone));
  assert.deepEqual(seedreamImageSize(1080, 1920), { width: 1440, height: 2560 });
  assert.deepEqual(seedreamImageSize(1440, 3200), { width: 1440, height: 3200 });
  assert.deepEqual(seedreamImageSize(1024, 1024), { width: 1920, height: 1920 });

  const inputs = [[944, 2048], [1080, 1920], [1179, 2556], [1080, 2400], [2048, 944], [777, 1333], [512, 4096], [4096, 512]];
  for (const [width, height] of inputs) {
    const size = seedreamImageSize(width, height);
    const label = `${width}x${height} -> ${size.width}x${size.height}`;
    assert.equal(size.width % 8, 0, label);
    assert.equal(size.height % 8, 0, label);
    assert.ok(size.width <= 4096 && size.height <= 4096, label);
    assert.ok(size.width * size.height >= minPixels, label);
  }
});

test('a Seedream generation sends and reports a size with the requested aspect ratio', async () => {
  const env = aiEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const stats = {};
  const restore = mockFal({ stats });
  let body;
  try {
    const response = await postGeneration(env, { qualityTier: 'quality', targetSize: '944x2048' });
    assert.equal(response.status, 200);
    body = await response.json();
  } finally {
    restore();
  }
  assert.equal(stats.falRequest.url, 'https://fal.run/fal-ai/bytedance/seedream/v4.5/text-to-image');
  assert.deepEqual(stats.falRequest.body.image_size, seedreamImageSize(944, 2048));
  assert.deepEqual({ width: body.width, height: body.height }, stats.falRequest.body.image_size);
});

function chargeDoc(overrides = {}) {
  const f = {
    userId: 'alice',
    action: 'aiGeneration',
    type: 'debit',
    status: 'completed',
    delta: -10,
    createdAt: new Date().toISOString(),
    ...overrides,
  };
  return Response.json({
    name: 'projects/p/databases/(default)/documents/coinTransactions/x',
    fields: {
      userId: { stringValue: f.userId },
      action: { stringValue: f.action },
      type: { stringValue: f.type },
      status: { stringValue: f.status },
      delta: { integerValue: String(f.delta) },
      createdAt: { timestampValue: f.createdAt },
      ...(f.qualityTier == null ? {} : { qualityTier: { stringValue: f.qualityTier } }),
      ...(f.basePrice == null ? {} : { basePrice: { integerValue: String(f.basePrice) } }),
    },
  });
}

const TX_ID = 'spend_alice_req12345';
const chargedEnv = (kv, coordinator) => aiEnv(kv, coordinator, { AI_REQUIRE_CHARGE: 'true' });

async function getChargeEvidence(env, txId) {
  const response = await worker.fetch(
    new Request(`https://prismwalls.com/api/ai/charges/${txId}`),
    env,
    { waitUntil() {} },
  );
  return { status: response.status, cache: response.headers.get('cache-control'), body: await response.json() };
}

test('with the charge flag on, a request without chargeTxId gets 402 and no provider call', async () => {
  const stats = {};
  const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const restore = mockFal({ stats, firestore: () => chargeDoc() });
  try {
    const response = await postGeneration(env);
    assert.equal(response.status, 402);
    assert.equal((await response.json()).error, 'charge_required');
  } finally {
    restore();
  }
  assert.equal(stats.fal ?? 0, 0);
});

test('with the charge flag off, a request without chargeTxId still works and a bad id shape is rejected', async () => {
  const env = aiEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const restore = mockFal();
  try {
    assert.equal((await postGeneration(env)).status, 200);
    const bad = await postGeneration(env, { chargeTxId: 'a/b' });
    assert.equal(bad.status, 400);
    assert.equal((await postGeneration(env, { chargeTxId: 42 })).status, 400);
  } finally {
    restore();
  }
});

test('a valid charge succeeds once and a replay returns the stored image without a second provider call', async () => {
  const stats = {};
  const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const token = await makeToken({ sub: 'alice' });
  let seen;
  const restore = mockFal({
    stats,
    firestore: (url, init) => {
      seen = { url, authorization: new Headers(init.headers).get('authorization') };
      return chargeDoc();
    },
  });
  try {
    const first = await postGeneration(env, { chargeTxId: TX_ID }, token);
    assert.equal(first.status, 200);
    const firstBody = await first.json();
    const replay = await postGeneration(env, { chargeTxId: TX_ID }, token);
    assert.equal(replay.status, 200);
    assert.deepEqual(await replay.json(), firstBody);
    assert.equal((await getChargeEvidence(env, TX_ID)).body.status, 'succeeded');
  } finally {
    restore();
  }
  assert.equal(stats.fal, 1);
  assert.equal(stats.firestore, 1);
  assert.equal(
    seen.url,
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/coinTransactions/${TX_ID}`,
  );
  assert.equal(seen.authorization, `Bearer ${token}`);
});

test('a charge that does not match the caller, tier, ledger state or age is refused and the claim is released', async () => {
  const cases = {
    'foreign user': { userId: 'bob' },
    'wrong tier amount': { delta: -75 },
    'refunded debit': { status: 'refunded' },
    'credit row': { type: 'credit', delta: 10 },
    'other action': { action: 'wallpaperDownload' },
    'old debit': { createdAt: new Date(Date.now() - 20 * 60 * 1000).toISOString() },
  };
  for (const [label, overrides] of Object.entries(cases)) {
    const stats = {};
    const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
    const restore = mockFal({ stats, firestore: () => chargeDoc(overrides) });
    try {
      const response = await postGeneration(env, { chargeTxId: TX_ID });
      assert.equal(response.status, 402, label);
      assert.equal((await response.json()).error, 'charge_invalid', label);
      assert.equal((await getChargeEvidence(env, TX_ID)).body.status, 'not_started', label);
    } finally {
      restore();
    }
    assert.equal(stats.fal ?? 0, 0, label);
  }

  const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const restore = mockFal({ firestore: () => new Response('missing', { status: 404 }) });
  try {
    assert.equal((await postGeneration(env, { chargeTxId: TX_ID })).status, 402);
  } finally {
    restore();
  }
});

test('a Firestore outage gives 502 without a charge_invalid verdict and frees the claim', async () => {
  const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const restore = mockFal({ firestore: () => new Response('down', { status: 503 }) });
  try {
    assert.equal((await postGeneration(env, { chargeTxId: TX_ID })).status, 502);
    assert.equal((await getChargeEvidence(env, TX_ID)).body.status, 'not_started');
  } finally {
    restore();
  }
});

test('a charge that is still running gets 409 and a failed provider call marks the charge failed', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const env = chargedEnv(aiKv(5), coordinator);
  const claim = await coordinator.fetch(quotaRequest({ op: 'charge_claim', txId: TX_ID }));
  assert.equal((await responseJson(claim)).status, 'new');

  const restore = mockFal({ providerStatus: 500, firestore: () => chargeDoc() });
  try {
    const busy = await postGeneration(env, { chargeTxId: TX_ID });
    assert.equal(busy.status, 409);
    assert.equal((await busy.json()).error, 'charge_in_progress');
    assert.equal((await getChargeEvidence(env, TX_ID)).body.status, 'in_progress');

    const other = 'spend_alice_req99999';
    assert.equal((await postGeneration(env, { chargeTxId: other })).status, 502);
    assert.equal((await getChargeEvidence(env, other)).body.status, 'failed');
    const retry = await postGeneration(env, { chargeTxId: other });
    assert.equal(retry.status, 402);
    assert.equal((await retry.json()).error, 'charge_invalid');
  } finally {
    restore();
  }
});

test('a Pro half-price debit is accepted for its tier', async () => {
  const stats = {};
  const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const restore = mockFal({ stats, firestore: () => chargeDoc({ delta: -5 }) });
  try {
    const response = await postGeneration(env, { chargeTxId: TX_ID, qualityTier: 'fast' });
    assert.equal(response.status, 200);
  } finally {
    restore();
  }
  assert.equal(stats.fal, 1);
});

test('a v2 receipt is checked against its own tier and base price', async () => {
  const cases = [
    ['config price, Pro half', { qualityTier: 'fast', basePrice: 12, delta: -6 }, 'fast', 200],
    ['config price, full', { qualityTier: 'fast', basePrice: 12, delta: -12 }, 'fast', 200],
    ['tier mismatch', { qualityTier: 'fast', basePrice: 10, delta: -10 }, 'balanced', 402],
    ['delta off the base price', { qualityTier: 'fast', basePrice: 12, delta: -10 }, 'fast', 402],
    ['base price without tier', { basePrice: 10, delta: -10 }, 'fast', 402],
    ['zero base price', { qualityTier: 'fast', basePrice: 0, delta: 0 }, 'fast', 402],
  ];
  for (const [label, overrides, qualityTier, status] of cases) {
    const stats = {};
    const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
    const restore = mockFal({ stats, firestore: () => chargeDoc(overrides) });
    try {
      const response = await postGeneration(env, { chargeTxId: TX_ID, qualityTier });
      assert.equal(response.status, status, label);
    } finally {
      restore();
    }
    assert.equal(stats.fal ?? 0, status === 200 ? 1 : 0, label);
  }
});

test('charge evidence reports not_started for an unseen id, no-store, and 404 for a bad shape', async () => {
  const env = aiEnv(aiKv(), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const unseen = await getChargeEvidence(env, 'spend_alice_unseen01');
  assert.equal(unseen.status, 200);
  assert.deepEqual(unseen.body, { status: 'not_started' });
  assert.equal(unseen.cache, 'no-store');
  assert.equal((await getChargeEvidence(env, 'bad.id')).status, 404);
  assert.equal((await getChargeEvidence(env, 'abc')).status, 404);
});

test('a paid request is never downgraded by the budget guardrail but an unpaid one still is', async () => {
  const storage = new MemoryStorage();
  await storage.put(`provider:fal:daily:${new Date().toISOString().slice(0, 10)}`, 29);
  const stats = {};
  const env = chargedEnv(aiKv(5), new AiQuotaCoordinator({ storage }));
  const restore = mockFal({ stats, firestore: () => chargeDoc({ delta: -75 }) });
  try {
    const paid = await postGeneration(env, { chargeTxId: TX_ID, qualityTier: 'balanced' });
    assert.equal(paid.status, 429);
    assert.equal((await paid.json()).error, 'budget_exhausted');
    assert.equal(stats.fal ?? 0, 0);
    assert.equal((await getChargeEvidence(env, TX_ID)).body.status, 'failed');
  } finally {
    restore();
  }

  const unpaidEnv = aiEnv(aiKv(5), new AiQuotaCoordinator({ storage }));
  const restoreUnpaid = mockFal({ stats });
  try {
    const unpaid = await postGeneration(unpaidEnv, { qualityTier: 'balanced' });
    assert.equal(unpaid.status, 200);
    assert.equal((await unpaid.json()).qualityTier, 'fast');
  } finally {
    restoreUnpaid();
  }
});

test('a variation request is charged at the stored tier of its parent', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const kv = aiKv(5);
  await kv.put('ai:gen:gen-parent', JSON.stringify({
    generationId: 'gen-parent', userId: 'alice', prompt: 'A quiet mountain lake', stylePreset: 'minimal',
    qualityTier: 'fast', width: 1080, height: 1920,
  }));
  const env = chargedEnv(kv, coordinator);
  const token = await makeToken({ sub: 'alice' });
  const variation = (chargeTxId) => worker.fetch(
    new Request('https://prismwalls.com/api/ai/generations/gen-parent/variations', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(chargeTxId == null ? {} : { chargeTxId }),
    }),
    env,
    { waitUntil() {} },
  );
  let doc = () => chargeDoc({ delta: -100 });
  const restore = mockFal({ firestore: () => doc() });
  try {
    assert.equal((await variation(null)).status, 402);
    assert.equal((await variation(TX_ID)).status, 402);
    doc = () => chargeDoc({ delta: -10 });
    assert.equal((await variation(TX_ID)).status, 200);
  } finally {
    restore();
  }
});

test('charge records expire after 24 hours and a stuck claim reads as failed', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const send = async (body) => responseJson(await coordinator.fetch(quotaRequest(body)));
  const realNow = Date.now;
  try {
    assert.equal((await send({ op: 'charge_claim', txId: TX_ID })).status, 'new');
    assert.equal((await send({ op: 'charge_claim', txId: TX_ID })).status, 'in_progress');
    await send({ op: 'charge_finish', txId: TX_ID, outcome: 'succeeded', response: '{"a":1}' });
    assert.deepEqual(await send({ op: 'charge_claim', txId: TX_ID }), { ok: true, status: 'done', response: '{"a":1}' });

    const now = realNow();
    Date.now = () => now + 24 * 60 * 60 * 1000 + 1000;
    assert.equal((await send({ op: 'charge_status', txId: TX_ID })).status, 'not_started');

    Date.now = () => now;
    assert.equal((await send({ op: 'charge_claim', txId: 'spend_alice_stuck001' })).status, 'new');
    Date.now = () => now + 6 * 60 * 1000;
    assert.equal((await send({ op: 'charge_status', txId: 'spend_alice_stuck001' })).status, 'failed');
    assert.equal((await send({ op: 'charge_claim', txId: 'spend_alice_stuck001' })).status, 'failed');
  } finally {
    Date.now = realNow;
  }
});

test('health shows only ok for anonymous callers and budget numbers for a valid token', async () => {
  const env = aiEnv(aiKv(), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const anonymous = await worker.fetch(new Request('https://prismwalls.com/api/ai/health'), env, { waitUntil() {} });
  assert.equal(anonymous.status, 200);
  assert.deepEqual(await anonymous.json(), { ok: true });

  const token = await makeToken({ sub: 'alice' });
  const signedIn = await worker.fetch(
    new Request('https://prismwalls.com/api/ai/health', { headers: { authorization: `Bearer ${token}` } }),
    env,
    { waitUntil() {} },
  );
  const body = await signedIn.json();
  assert.equal(body.ok, true);
  assert.equal(typeof body.providers.fal.budget.dailyBudgetUsd, 'number');
});

test('prompt blocklist matches whole words only and keeps multi-word terms', async () => {
  const env = aiEnv(aiKv(10), new AiQuotaCoordinator({ storage: new MemoryStorage() }));
  const restore = mockFal();
  try {
    assert.equal((await postGeneration(env, { prompt: 'a bowl of grapes' })).status, 200);
    assert.equal((await postGeneration(env, { prompt: 'drape and scrape texture' })).status, 200);
    for (const prompt of ['rape', 'a scene of Rape.', 'child   porn', 'Deepfake nude of a star', 'gore kill']) {
      const response = await postGeneration(env, { prompt });
      assert.equal(response.status, 422, prompt);
      assert.equal((await response.json()).error, 'unsafe_prompt', prompt);
    }
  } finally {
    restore();
  }
});

test('share page escapes titles once for text and attributes', async () => {
  const links = new MemoryKv([['AbCdEfGh', JSON.stringify({
    code: 'AbCdEfGh',
    type: 'share',
    canonical_url: `https://prismwalls.com${SHARE_PATH}`,
    created_at: new Date().toISOString(),
    preview: { title: "Don't & Co", description: 'A "quote" & more', username: "o'neil" },
    version: 1,
  })]]);
  const env = workerEnv({
    LINKS_KV: links,
    PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
  });
  for (const userAgent of [ANDROID_UA, 'WhatsApp/2.23']) {
    const body = await (await getShare(userAgent, '/l/AbCdEfGh', env)).text();
    assert.match(body, /og:title" content="Don&#39;t &amp; Co"/);
    assert.match(body, /og:description" content="A &quot;quote&quot; &amp; more"/);
    assert.match(body, /<title>Don&#39;t &amp; Co<\/title>/);
    assert.doesNotMatch(body, /&amp;#39;|&amp;amp;|&amp;quot;|&amp;lt;/);
  }
  const human = await (await getShare(ANDROID_UA, '/l/AbCdEfGh', env)).text();
  assert.match(human, /<h1>Don&#39;t &amp; Co<\/h1>/);
  assert.match(human, /by @o&#39;neil/);
});

test('human landing page adds the Smart App Banner meta with the canonical URL', async () => {
  const body = await (await getShare(IOS_UA)).text();
  assert.match(
    body,
    /<meta name="apple-itunes-app" content="app-id=1405860595, app-argument=https:\/\/prismwalls\.com\/share\?id=wall-1[^"]*" \/>/,
  );
  assert.match(body, />Open in Prism</);
});

test('a missing or malformed short link shows the unavailable page with a store link', async () => {
  const env = workerEnv({
    PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
  });
  const missing = await getShare(IOS_UA, '/l/ZzZzZzZz', env);
  assert.equal(missing.status, 404);
  assert.match(missing.headers.get('content-type'), /text\/html/);
  const missingBody = await missing.text();
  assert.match(missingBody, /PRISM/);
  assert.match(missingBody, /This link is no longer available/);
  assert.match(missingBody, /href="https:\/\/apps\.apple\.com\/app\/id1405860595"[^>]*>Open Prism</);

  const malformed = await getShare(ANDROID_UA, '/l/x', env);
  assert.equal(malformed.status, 400);
  assert.match(await malformed.text(), /href="https:\/\/play\.google\.com\/store\/apps\/details\?id=com\.hash\.prism"[^>]*>Open Prism</);
});

function postLink(env, body, headers = {}) {
  return worker.fetch(
    new Request('https://prismwalls.com/api/links', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'CF-Connecting-IP': '203.0.113.9', ...headers },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    }),
    env,
    { waitUntil() {} },
  );
}

const LINK_BODY = { type: 'share', canonical_url: 'https://prismwalls.com/share?id=wall-1' };

test('wallpaper shares discard original URLs from canonical and payload input', async () => {
  const original = 'https://raw.githubusercontent.com/private/premium-original.jpg?token=secret';
  for (const body of [
    { type: 'share', canonical_url: `https://prismwalls.com/share?id=premium&url=${encodeURIComponent(original)}`,
      preview: { image_source_url: original } },
    { type: 'share', payload: { id: 'premium', source: 'prism', url: original },
      preview: { image_source_url: original } },
    { type: 'share', canonical_url: `https://prismwalls.com/share?id=premium&source=prism&thumb=${encodeURIComponent(original)}`,
      preview: { image_source_url: original } },
  ]) {
    const env = workerEnv();
    const response = await postLink(env, body);
    assert.equal(response.status, 201);
    const record = JSON.parse(await env.LINKS_KV.get((await response.json()).code));
    assert.equal(new URL(record.canonical_url).searchParams.has('url'), false);
    assert.equal(record.preview.image_source_url,
      'https://asia-south1-prism-wallpapers.cloudfunctions.net/ownedThumbnail/premium');
    assert.ok(!JSON.stringify(record).includes('premium-original'));
  }
  const landing = await (await getShare(ANDROID_UA,
    `/share?id=premium&url=${encodeURIComponent(original)}`)).text();
  assert.ok(!landing.includes('premium-original'));
  const env = workerEnv({
    PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id1405860595',
    LINKS_KV: new MemoryKv([['AbCdEfGh', JSON.stringify({
    code: 'AbCdEfGh',
    type: 'share',
    canonical_url: `https://prismwalls.com/share?id=premium&url=${encodeURIComponent(original)}&thumb=${encodeURIComponent(original)}`,
    preview: { image_source_url: original },
  })]]) });
  const storedLanding = await (await getShare(ANDROID_UA, '/l/AbCdEfGh', env)).text();
  assert.ok(!storedLanding.includes('premium-original'));
  assert.match(storedLanding, /ownedThumbnail\/premium/);
  const invalid = await (await getShare(ANDROID_UA,
    `/share?id=..%2Fpremium&source=prism&thumb=${encodeURIComponent(original)}`)).text();
  assert.ok(!invalid.includes('premium-original'));
  assert.doesNotMatch(invalid, /src="[^"]*ownedThumbnail/);
});

test('createLink refuses oversized bodies by header and by streamed size', async () => {
  const env = workerEnv();
  const big = JSON.stringify({ ...LINK_BODY, campaign: { note: 'x'.repeat(20 * 1024) } });

  const declared = await postLink(env, big, { 'content-length': String(big.length) });
  assert.equal(declared.status, 413);

  const streamed = await postLink(env, big);
  assert.equal(streamed.status, 413);
  assert.equal((await postLink(env, LINK_BODY)).status, 201);
});

test('createLink keeps a flat campaign of short strings and drops anything else', async () => {
  const env = workerEnv();
  const stored = async (campaign) => {
    const response = await postLink(env, { ...LINK_BODY, campaign });
    assert.equal(response.status, 201);
    const record = JSON.parse(await env.LINKS_KV.get((await response.json()).code));
    return record.campaign;
  };
  assert.deepEqual(await stored({ source: 'spring', medium: 'push' }), { source: 'spring', medium: 'push' });
  assert.equal(await stored({ nested: { a: 'b' } }), undefined);
  assert.equal(await stored({ count: 3 }), undefined);
  assert.equal(await stored(['a']), undefined);
  assert.equal(await stored({ long: 'x'.repeat(101) }), undefined);
  assert.equal(await stored({ ['k'.repeat(101)]: 'v' }), undefined);
  assert.equal(
    await stored(Object.fromEntries(Array.from({ length: 11 }, (_, i) => [`k${i}`, 'v']))),
    undefined,
  );
});

const RENDER_ENV = { BROWSER_RENDERING_ACCOUNT_ID: 'acct', BROWSER_RENDERING_API_TOKEN: 'token' };

function mockOgRender({ stats = null, renderStatus = 200 } = {}) {
  const originalFetch = globalThis.fetch;
  const calls = { renders: [], firestore: [] };
  globalThis.fetch = async (input, init) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.includes('/browser-rendering/screenshot')) {
      calls.renders.push(JSON.parse(init.body));
      return renderStatus === 200
        ? new Response(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]))
        : new Response('down', { status: renderStatus });
    }
    if (url.startsWith('https://firestore.googleapis.com/')) {
      calls.firestore.push(url);
      return stats == null ? new Response('{}', { status: 404 }) : Response.json({ fields: stats });
    }
    throw new Error(`unexpected fetch ${url}`);
  };
  return { calls, restore: () => { globalThis.fetch = originalFetch; } };
}

function storedLink(code, type, canonicalPath, preview, extra = {}) {
  return [code, JSON.stringify({
    code,
    type,
    canonical_url: `https://prismwalls.com${canonicalPath}`,
    created_at: new Date().toISOString(),
    preview,
    version: 1,
    ...extra,
  })];
}

function getOg(env, path) {
  return worker.fetch(new Request(`https://prismwalls.com${path}`), env, { waitUntil() {} });
}

test('createLink stores creator, counts and gallery, drops bad values and returns a versioned JPEG URL', async () => {
  const env = workerEnv();
  const response = await postLink(env, {
    type: 'user',
    canonical_url: 'https://prismwalls.com/user/maya',
    preview: {
      title: 'Maya Rao (@maya)',
      username: 'maya',
      creator_name: '<b>Maya</b> Rao',
      image_source_url: 'https://lh3.googleusercontent.com/a/photo=s96-c',
      follower_count: 2400,
      wallpaper_count: -3,
      gallery: [
        'https://raw.githubusercontent.com/a/1.jpg',
        'https://evil.example.com/2.jpg',
        42,
        'https://raw.githubusercontent.com/a/3.jpg',
        'https://raw.githubusercontent.com/a/4.jpg',
      ],
    },
  });
  assert.equal(response.status, 201);
  const { code, og_image_url: ogImageUrl } = await response.json();
  assert.equal(ogImageUrl, `https://prismwalls.com/og/${code}.jpg?v=2`);

  const { preview, version } = JSON.parse(await env.LINKS_KV.get(code));
  assert.equal(version, 2);
  assert.equal(preview.creator_name, 'Maya Rao');
  assert.equal(preview.image_source_url, 'https://lh3.googleusercontent.com/a/photo=s96-c');
  assert.equal(preview.follower_count, 2400);
  assert.equal(preview.wallpaper_count, null);
  assert.deepEqual(preview.gallery, ['https://raw.githubusercontent.com/a/1.jpg', 'https://raw.githubusercontent.com/a/3.jpg']);
});

test('an old share link renders the new card once, as a JPEG with its public wallpaper counts', async () => {
  const env = workerEnv({
    ...RENDER_ENV,
    LINKS_KV: new MemoryKv([
      storedLink('OldWall1', 'share', SHARE_PATH, {
        title: 'wall-1 - Prism',
        wall_id: 'wall-1',
        provider: 'Prism',
        image_source_url: 'https://raw.githubusercontent.com/Hash-Studios/x.jpg',
      }, { og_storage: 'kv' }),
      ['og:OldWall1-v1.png', Buffer.from([0x89, 0x50]).toString('base64')],
    ]),
  });
  const { calls, restore } = mockOgRender({ stats: { views: { integerValue: '3048' }, favs: { integerValue: '1' } } });
  try {
    const first = await getOg(env, '/og/OldWall1.png');
    assert.equal(first.status, 200);
    assert.equal(first.headers.get('content-type'), 'image/jpeg');
    assert.equal(calls.renders.length, 1);
    assert.deepEqual(calls.renders[0].screenshotOptions, { type: 'jpeg', quality: 85 });
    assert.match(calls.firestore[0], /\/documents\/wallpaper_stats\/WALL-1$/);

    const html = calls.renders[0].html;
    assert.match(html, />Wallpaper on Prism</);
    assert.doesNotMatch(html, /wall-1 - Prism/);
    assert.match(html, />3k<\/div><div class="lbl">Views</);
    assert.match(html, />1<\/div><div class="lbl">Favourite</);
    assert.match(html, /cloudfunctions\.net\/ownedThumbnail\/wall-1/);

    const record = JSON.parse(await env.LINKS_KV.get('OldWall1'));
    assert.equal(record.version, 2);
    assert.equal(record.og_storage, 'kv');

    const second = await getOg(env, '/og/OldWall1.jpg');
    assert.equal(second.headers.get('content-type'), 'image/jpeg');
    assert.equal(calls.renders.length, 1);
  } finally {
    restore();
  }
});

test('when the new card fails to render, an old link keeps its old image with a short cache', async () => {
  const env = workerEnv({
    ...RENDER_ENV,
    LINKS_KV: new MemoryKv([
      storedLink('OldWall2', 'share', SHARE_PATH, { title: 'Sunset', wall_id: 'wall-1' }, { og_storage: 'kv' }),
      ['og:OldWall2-v1.png', Buffer.from([0x89, 0x50]).toString('base64')],
    ]),
  });
  const { restore } = mockOgRender({ renderStatus: 500 });
  try {
    const response = await getOg(env, '/og/OldWall2.jpg');
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'image/png');
    assert.equal(response.headers.get('cache-control'), 'public, max-age=300');
    assert.deepEqual([...new Uint8Array(await response.arrayBuffer())], [0x89, 0x50]);
    assert.equal(JSON.parse(await env.LINKS_KV.get('OldWall2')).version, 1);
  } finally {
    restore();
  }
});

test('profile and invite cards read names from old titles and never query wallpaper counts', async () => {
  const env = workerEnv({
    ...RENDER_ENV,
    LINKS_KV: new MemoryKv([
      storedLink('OldUser1', 'user', '/user/maya', { title: 'Maya Rao (@maya)', username: 'maya' }),
      storedLink('OldRefr1', 'refer', '/refer/uid-1', {
        title: 'Maya Rao invited you to Prism',
        image_source_url: 'https://lh3.googleusercontent.com/a/photo',
      }),
      storedLink('OldRefr2', 'refer', '/refer/uid-2', { title: 'Join Prism' }),
    ]),
  });
  const { calls, restore } = mockOgRender();
  try {
    for (const code of ['OldUser1', 'OldRefr1', 'OldRefr2']) {
      assert.equal((await getOg(env, `/og/${code}.jpg`)).status, 200);
    }
    const [profile, invite, anonymous] = calls.renders.map((render) => render.html);
    assert.match(profile, /<div class="title"[^>]*>Maya Rao<span class="handle">@maya<\/span>/);
    assert.match(profile, /class="big-avatar" src="[^"]*prism\.webp"/);
    assert.doesNotMatch(profile, /class="stats"/);
    assert.match(invite, /<img class="avatar" src="https:\/\/lh3\.googleusercontent\.com\/a\/photo"/);
    assert.match(invite, /<b>Maya Rao<\/b><\/span><span class="sub">invited you to Prism/);
    assert.match(invite, /web\/public\/assets\/og\/invite-1\.jpg/);
    assert.match(anonymous, /<b>Join Prism<\/b>/);
    assert.equal(calls.firestore.length, 0);
  } finally {
    restore();
  }
});

test('card HTML escapes text, shows the logo without an image, and counts read short', () => {
  const html = renderOgCardHtml({ kind: 'wallpaper', label: 'Wallpaper', title: 'Tom & "Jerry" <3', image: '', stats: [], chip: null });
  assert.match(html, /Tom &amp; &quot;Jerry&quot; &lt;3/);
  assert.match(html, /<img class="logo" src="[^"]*prism\.webp"/);
  assert.deepEqual(
    [0, 999, 1000, 1234, 51_000, 2_500_000].map(formatCount),
    ['0', '999', '1k', '1.2k', '51k', '2.5M'],
  );
});

test('createLink rate limit uses the Durable Object counter and falls back to KV when it fails', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const doEnv = aiEnv(aiKv(), coordinator, { LINKS_KV: new MemoryKv() });
  for (let i = 0; i < 20; i += 1) {
    assert.equal((await postLink(doEnv, LINK_BODY)).status, 201, `call ${i}`);
  }
  assert.equal((await postLink(doEnv, LINK_BODY)).status, 429);
  assert.equal(await doEnv.LINKS_KV.get('rl:10m:203.0.113.9'), null);

  const kvEnv = workerEnv();
  for (let i = 0; i < 20; i += 1) {
    assert.equal((await postLink(kvEnv, LINK_BODY)).status, 201, `call ${i}`);
  }
  assert.equal((await postLink(kvEnv, LINK_BODY)).status, 429);
});

test('rate limit counter resets after its window', async () => {
  const coordinator = new AiQuotaCoordinator({ storage: new MemoryStorage() });
  const bump = async () => responseJson(await coordinator.fetch(
    quotaRequest({ op: 'rate_limit_bump', key: 'rl:test', limit: 1, ttlSeconds: 60 }),
  ));
  const realNow = Date.now;
  try {
    const now = realNow();
    Date.now = () => now;
    assert.equal((await bump()).allowed, true);
    assert.equal((await bump()).allowed, false);
    Date.now = () => now + 61_000;
    assert.equal((await bump()).allowed, true);
  } finally {
    Date.now = realNow;
  }
});

const STUDIO_SECRET = 'studio-test-secret';
const STUDIO_MODEL = 'fal-ai/bytedance/seedream/v4.5/text-to-image';
const STUDIO_ID = 'daily-2026-10-12';
const STUDIO_RAW_KEY = `ai/studio/raw/${STUDIO_ID}.png`;
const today = () => new Date().toISOString().slice(0, 10);

function studioEnv(storage = new MemoryStorage(), overrides = {}) {
  return aiEnv(new MemoryKv(), new AiQuotaCoordinator({ storage }), {
    STUDIO_SECRET,
    AI_IMAGES: new MemoryR2(),
    ...overrides,
  });
}

function studioFetch(env, method, path, { body, headers = {}, secret = STUDIO_SECRET } = {}) {
  return worker.fetch(
    new Request(`https://prismwalls.com${path}`, {
      method,
      headers: { ...(secret == null ? {} : { 'x-studio-secret': secret }), ...headers },
      body,
      ...(body instanceof ReadableStream ? { duplex: 'half' } : {}),
    }),
    env,
    { waitUntil() {} },
  );
}

function postStudioGeneration(env, extra = {}, options = {}) {
  return studioFetch(env, 'POST', '/api/ai/studio/generations', {
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      id: STUDIO_ID, prompt: 'A quiet mountain lake at dawn', model: STUDIO_MODEL, width: 1080, height: 1920, seed: 42,
      ...extra,
    }),
    ...options,
  });
}

test('studio routes are off without STUDIO_SECRET and need the exact secret header', async () => {
  const stats = {};
  const restore = mockFal({ stats });
  try {
    const disabled = await postStudioGeneration(studioEnv(new MemoryStorage(), { STUDIO_SECRET: undefined }));
    assert.equal(disabled.status, 503);
    assert.equal((await disabled.json()).error, 'service_disabled');

    const env = studioEnv();
    for (const secret of [null, '', 'wrong', `${STUDIO_SECRET}x`, STUDIO_SECRET.slice(0, -1)]) {
      const denied = await postStudioGeneration(env, {}, { secret });
      assert.equal(denied.status, 401, String(secret));
      assert.equal((await denied.json()).error, 'unauthorized');
    }
    assert.equal((await studioFetch(env, 'DELETE', `/api/ai/studio/assets/${STUDIO_RAW_KEY}`, { secret: 'x' })).status, 401);
    assert.equal(stats.fal ?? 0, 0);

    assert.equal((await postStudioGeneration(env)).status, 200);
  } finally {
    restore();
  }
});

test('studio generation refuses bad bodies and unknown models before any provider call', async () => {
  const stats = {};
  const env = studioEnv();
  const restore = mockFal({ stats });
  try {
    const invalidJson = await studioFetch(env, 'POST', '/api/ai/studio/generations', { body: '{nope' });
    assert.equal(invalidJson.status, 400);
    assert.equal((await invalidJson.json()).error, 'invalid_json');

    const cases = {
      'short id': { id: 'abc' },
      'id with a slash': { id: 'daily/2026-10-12' },
      'missing prompt': { prompt: undefined },
      'blank prompt': { prompt: '   ' },
      'long prompt': { prompt: 'x'.repeat(2001) },
      'narrow width': { width: 511 },
      'tall height': { height: 4097 },
      'fraction width': { width: 1080.5 },
      'string height': { height: '1920' },
      'negative seed': { seed: -1 },
      'string seed': { seed: '42' },
      'consumer model': { model: 'fal-ai/flux/schnell' },
      'prototype key model': { model: 'constructor' },
      'missing model': { model: undefined },
    };
    for (const [label, extra] of Object.entries(cases)) {
      const response = await postStudioGeneration(env, extra);
      assert.equal(response.status, 400, label);
      assert.equal((await response.json()).error, 'invalid_request', label);
    }
  } finally {
    restore();
  }
  assert.equal(stats.fal ?? 0, 0);
});

test('studio generation sends the prompt as given, stores the raw image and returns the contract', async () => {
  const storage = new MemoryStorage();
  const env = studioEnv(storage);
  const stats = {};
  const restore = mockFal({
    stats,
    falPayload: { images: [{ url: 'https://fal.media/image.png', width: 1440, height: 2560 }], seed: 42 },
  });
  let body;
  try {
    const response = await postStudioGeneration(env);
    assert.equal(response.status, 200);
    body = await response.json();
  } finally {
    restore();
  }

  assert.deepEqual(body, {
    id: STUDIO_ID,
    imageUrl: `https://prismwalls.com/api/ai/assets/${STUDIO_RAW_KEY}`,
    key: STUDIO_RAW_KEY,
    width: 1440,
    height: 2560,
    contentType: 'image/png',
    bytes: 4096,
    model: STUDIO_MODEL,
    provider: 'fal',
    seed: 42,
    costUsd: 0.04,
  });
  assert.equal(stats.falRequest.url, `https://fal.run/${STUDIO_MODEL}`);
  assert.equal(stats.falRequest.authorization, 'Key test-key');
  assert.deepEqual(stats.falRequest.body, {
    prompt: 'A quiet mountain lake at dawn',
    image_size: { width: 1440, height: 2560 },
    seed: 42,
    num_images: 1,
    enable_safety_checker: true,
  });

  const stored = env.AI_IMAGES.objects.get(STUDIO_RAW_KEY);
  assert.equal(stored.bytes.length, 4096);
  assert.deepEqual(stored.httpMetadata, { contentType: 'image/png', cacheControl: 'public, max-age=31536000, immutable' });
  const served = await worker.fetch(new Request(body.imageUrl), env, { waitUntil() {} });
  assert.equal(served.status, 200);
  assert.equal(served.headers.get('content-type'), 'image/png');

  assert.equal(await storage.get(`provider:studio:daily:${today()}`), 0.04);
  assert.equal(await storage.get(`provider:fal:daily:${today()}`), undefined);
});

test('studio generation with v5 lite sends no seed and falls back to the requested size', async () => {
  const env = studioEnv();
  const stats = {};
  const restore = mockFal({ stats });
  let body;
  try {
    const response = await postStudioGeneration(env, {
      model: 'fal-ai/bytedance/seedream/v5/lite/text-to-image', width: 944, height: 2048,
    });
    assert.equal(response.status, 200);
    body = await response.json();
  } finally {
    restore();
  }
  assert.equal('seed' in stats.falRequest.body, false);
  assert.deepEqual(stats.falRequest.body.image_size, seedreamImageSize(944, 2048));
  assert.deepEqual({ width: body.width, height: body.height }, seedreamImageSize(944, 2048));
  assert.equal(body.seed, null);
});

test('GPT Image sizes are multiples of 16 inside the fal limits and keep the phone aspect', () => {
  assert.deepEqual(gptImageSize(1440, 3200), { width: 1440, height: 3200 });
  assert.deepEqual(gptImageSize(944, 2048), { width: 944, height: 2048 });
  assert.deepEqual(gptImageSize(3200, 1440), { width: 3200, height: 1440 });
  const inputs = [[1440, 3200], [1179, 2556], [512, 512], [4096, 4096], [512, 4096], [3000, 3000], [1081, 2401]];
  for (const [width, height] of inputs) {
    const size = gptImageSize(width, height);
    const label = `${width}x${height} -> ${size.width}x${size.height}`;
    assert.equal(size.width % 16, 0, label);
    assert.equal(size.height % 16, 0, label);
    assert.ok(Math.max(size.width, size.height) <= 3840, label);
    assert.ok(Math.max(size.width, size.height) / Math.min(size.width, size.height) <= 3.0001, label);
    const pixels = size.width * size.height;
    assert.ok(pixels >= 655360 && pixels <= 8294400, label);
  }
});

test('studio generation with GPT Image 2.5 sends high quality, no seed and the exact phone size', async () => {
  const env = studioEnv();
  const stats = {};
  const restore = mockFal({ stats });
  let body;
  try {
    const response = await postStudioGeneration(env, {
      model: 'openai/gpt-image-2.5/sunburst/text-to-image', width: 1440, height: 3200,
    });
    assert.equal(response.status, 200);
    body = await response.json();
  } finally {
    restore();
  }
  assert.equal(stats.falRequest.url, 'https://fal.run/openai/gpt-image-2.5/sunburst/text-to-image');
  assert.equal('seed' in stats.falRequest.body, false);
  assert.equal(stats.falRequest.body.quality, 'high');
  assert.deepEqual(stats.falRequest.body.image_size, { width: 1440, height: 3200 });
  assert.equal(body.costUsd, 0.07);
});

test('studio generation bills STUDIO_FAL_API_KEY when it is set and FAL_API_KEY when it is not', async () => {
  for (const [overrides, expected] of [[{ STUDIO_FAL_API_KEY: 'studio-key' }, 'Key studio-key'], [{}, 'Key test-key']]) {
    const stats = {};
    const restore = mockFal({ stats });
    try {
      const response = await postStudioGeneration(studioEnv(new MemoryStorage(), overrides));
      assert.equal(response.status, 200);
    } finally {
      restore();
    }
    assert.equal(stats.falRequest.authorization, expected);
  }
});

test('a repeated studio id replays success and a stale in-flight id never regenerates', async () => {
  const storage = new MemoryStorage();
  const env = studioEnv(storage);
  const stats = {};
  const restore = mockFal({ stats });
  const realNow = Date.now;
  try {
    const first = await postStudioGeneration(env);
    assert.equal(first.status, 200);
    const firstBody = await first.json();
    const replay = await postStudioGeneration(env, { prompt: 'a different prompt' });
    assert.equal(replay.status, 200);
    assert.deepEqual(await replay.json(), firstBody);
    assert.equal(stats.fal, 1);

    const coordinator = new AiQuotaCoordinator({ storage });
    await coordinator.fetch(quotaRequest({ op: 'studio_claim', id: 'daily-running' }));
    const busy = await postStudioGeneration(env, { id: 'daily-running' });
    assert.equal(busy.status, 409);
    assert.equal((await busy.json()).error, 'in_progress');
    assert.equal(stats.fal, 1);

    const now = realNow();
    Date.now = () => now + 6 * 60 * 1000;
    assert.equal((await postStudioGeneration(env, { id: 'daily-running' })).status, 409);
    assert.equal(stats.fal, 1);

    Date.now = () => now + 8 * 24 * 60 * 60 * 1000;
    assert.equal((await postStudioGeneration(env)).status, 200);
    assert.equal(stats.fal, 1);
  } finally {
    Date.now = realNow;
    restore();
  }
});

test('the studio budget is separate from consumer budgets and fails closed with no fal call', async () => {
  const storage = new MemoryStorage();
  await storage.put(`provider:fal:daily:${today()}`, 30);
  const env = studioEnv(storage, { STUDIO_DAILY_BUDGET_USD: '0.05' });
  const stats = {};
  const restore = mockFal({ stats });
  try {
    assert.equal((await postStudioGeneration(env)).status, 200);
    const exhausted = await postStudioGeneration(env, { id: 'daily-2026-10-13' });
    assert.equal(exhausted.status, 429);
    assert.equal((await exhausted.json()).error, 'budget_exhausted');

    const monthly = await postStudioGeneration(studioEnv(new MemoryStorage(), { STUDIO_MONTHLY_BUDGET_USD: '0.01' }));
    assert.equal(monthly.status, 429);
  } finally {
    restore();
  }
  assert.equal(stats.fal, 1);
  assert.equal(await storage.get(`provider:fal:daily:${today()}`), 30);
});

test('a dispatched fal failure consumes the reservation and replays without a second generation', async () => {
  const storage = new MemoryStorage();
  const env = studioEnv(storage, { STUDIO_DAILY_BUDGET_USD: '0.04' });
  const stats = {};
  const restoreFailing = mockFal({ providerStatus: 500, stats });
  try {
    const failed = await postStudioGeneration(env);
    assert.equal(failed.status, 502);
    const failedBody = await failed.json();
    assert.equal(failedBody.error, 'provider_error');
    const replay = await postStudioGeneration(env, { prompt: 'a different prompt' });
    assert.equal(replay.status, 502);
    assert.deepEqual(await replay.json(), failedBody);
  } finally {
    restoreFailing();
  }
  assert.equal(await storage.get(`provider:studio:daily:${today()}`), 0.04);
  assert.equal(env.AI_IMAGES.objects.size, 0);
  assert.equal(stats.fal, 1);
});

test('an ambiguous fal timeout is terminal and cannot be retried for the same id', async () => {
  const storage = new MemoryStorage();
  const env = studioEnv(storage, { STUDIO_DAILY_BUDGET_USD: '0.04' });
  const originalFetch = globalThis.fetch;
  let falCalls = 0;
  globalThis.fetch = async (input) => {
    if (String(input).startsWith('https://fal.run/')) {
      falCalls += 1;
      throw new Error('timeout');
    }
    throw new Error(`unexpected fetch ${String(input)}`);
  };
  try {
    const first = await postStudioGeneration(env);
    assert.equal(first.status, 502);
    const failure = await first.json();
    assert.equal(failure.error, 'provider_timeout');

    const replay = await postStudioGeneration(env, { prompt: 'a different prompt' });
    assert.equal(replay.status, 502);
    assert.deepEqual(await replay.json(), failure);
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.equal(falCalls, 1);
  assert.equal(await storage.get(`provider:studio:daily:${today()}`), 0.04);
});

test('a fal image-download failure is terminal after the provider has answered', async () => {
  const storage = new MemoryStorage();
  const env = studioEnv(storage, { STUDIO_DAILY_BUDGET_USD: '0.04' });
  const stats = {};
  const restore = mockFal({ imageStatus: 500, stats });
  try {
    const first = await postStudioGeneration(env);
    assert.equal(first.status, 502);
    const failure = await first.json();
    const replay = await postStudioGeneration(env);
    assert.equal(replay.status, 502);
    assert.deepEqual(await replay.json(), failure);
  } finally {
    restore();
  }

  assert.equal(stats.fal, 1);
  assert.equal(await storage.get(`provider:studio:daily:${today()}`), 0.04);
  assert.equal(env.AI_IMAGES.objects.size, 0);
});

test('an oversized fal image is rejected without storage or a second generation', async () => {
  const storage = new MemoryStorage();
  const env = studioEnv(storage, { STUDIO_DAILY_BUDGET_USD: '0.04' });
  const stats = {};
  const restore = mockFal({ imageSize: 15 * 1024 * 1024 + 1, stats });
  try {
    const first = await postStudioGeneration(env);
    assert.equal(first.status, 502);
    const failure = await first.json();
    const replay = await postStudioGeneration(env);
    assert.equal(replay.status, 502);
    assert.deepEqual(await replay.json(), failure);
  } finally {
    restore();
  }

  assert.equal(stats.fal, 1);
  assert.equal(await storage.get(`provider:studio:daily:${today()}`), 0.04);
  assert.equal(env.AI_IMAGES.objects.size, 0);
});

test('studio asset upload checks key, content type and size, then stores an image the asset route serves', async () => {
  const env = studioEnv();
  const put = (key, bytes, contentType) => studioFetch(env, 'PUT', `/api/ai/studio/assets/${key}`, {
    body: bytes,
    headers: contentType == null ? {} : { 'content-type': contentType },
  });
  const image = new Uint8Array(2048).fill(7);

  for (const key of [STUDIO_RAW_KEY, 'ai/public/x.png', 'ai/studio/x.gif', 'ai/studio/x', 'ai/studio/a.b.png']) {
    assert.equal((await put(key, image, 'image/png')).status, 400, key);
  }
  for (const contentType of ['image/png', 'text/plain', null]) {
    const response = await put('ai/studio/wall.jpg', image, contentType);
    assert.equal(response.status, 415, String(contentType));
    assert.equal((await response.json()).error, 'invalid_request');
  }
  assert.equal((await put('ai/studio/wall.png', new Uint8Array(1023), 'image/png')).status, 400);
  assert.equal((await put('ai/studio/wall.png', new Uint8Array(15 * 1024 * 1024 + 1), 'image/png')).status, 413);
  assert.equal(env.AI_IMAGES.objects.size, 0);

  const stored = await put('ai/studio/wall-2026-10-12.webp', image, 'image/webp');
  assert.equal(stored.status, 200);
  const body = await stored.json();
  assert.deepEqual(body, {
    key: 'ai/studio/wall-2026-10-12.webp',
    url: 'https://prismwalls.com/api/ai/assets/ai/studio/wall-2026-10-12.webp',
  });
  const served = await worker.fetch(new Request(body.url), env, { waitUntil() {} });
  assert.equal(served.status, 200);
  assert.equal(served.headers.get('content-type'), 'image/webp');
  assert.equal(served.headers.get('cache-control'), 'public, max-age=31536000, immutable');
  assert.deepEqual(new Uint8Array(await served.arrayBuffer()), image);
});

test('studio asset upload cancels a streamed body as soon as it exceeds the byte limit', async () => {
  const env = studioEnv();
  let cancelled = false;
  let chunksRead = 0;
  const body = new ReadableStream({
    pull(controller) {
      chunksRead += 1;
      if (chunksRead <= 3) {
        controller.enqueue(new Uint8Array(8 * 1024 * 1024));
      } else {
        controller.close();
      }
    },
    cancel() {
      cancelled = true;
    },
  }, { highWaterMark: 0 });
  const response = await studioFetch(env, 'PUT', '/api/ai/studio/assets/ai/studio/large.png', {
    body,
    headers: { 'content-type': 'image/png' },
  });

  assert.equal(response.status, 413, await response.clone().text());
  assert.equal(cancelled, true);
  assert.equal(chunksRead, 2);
  assert.equal(env.AI_IMAGES.objects.size, 0);
});

test('studio asset delete removes raw and uploaded keys and also succeeds for a missing key', async () => {
  const env = studioEnv();
  await env.AI_IMAGES.put(STUDIO_RAW_KEY, new Uint8Array(2048));
  await env.AI_IMAGES.put('ai/studio/wall.jpg', new Uint8Array(2048));
  const remove = (key) => studioFetch(env, 'DELETE', `/api/ai/studio/assets/${key}`);

  for (const key of [STUDIO_RAW_KEY, 'ai/studio/wall.jpg', 'ai/studio/missing.png']) {
    const response = await remove(key);
    assert.equal(response.status, 200, key);
    assert.deepEqual(await response.json(), { deleted: true });
  }
  assert.equal(env.AI_IMAGES.objects.size, 0);
  for (const key of ['ai/public/x.png', 'ai/original/x.png', 'ai/studio/raw/nested/x.png']) {
    assert.equal((await remove(key)).status, 400, key);
  }
});

async function makeToken(overrides = {}) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', kid: publicJwk.kid };
  const claims = {
    aud: projectId,
    iss: `https://securetoken.google.com/${projectId}`,
    sub: 'user-1',
    iat: now,
    exp: now + 3600,
    auth_time: now,
    ...overrides,
  };
  const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claims))}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${Buffer.from(signature).toString('base64url')}`;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function authEnv() {
  return {
    FIREBASE_PROJECT_ID: projectId,
    AI_STATE_KV: new MemoryKv([['ai:firebase:jwks:v1', jwksCache]]),
  };
}

function workerEnv(overrides = {}) {
  const kv = overrides.AI_STATE_KV ?? new MemoryKv();
  return {
    LINKS_KV: new MemoryKv(),
    AI_STATE_KV: kv,
    AI_QUOTA_DO: {
      idFromName: () => 'quota-object',
      get: () => ({ fetch: async () => { throw new Error('unexpected quota/provider call'); } }),
    },
    FIREBASE_PROJECT_ID: projectId,
    ...overrides,
  };
}

function quotaRequest(body) {
  return new Request('https://quota.internal/rpc', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

async function responseJson(response) {
  assert.equal(response.status, 200);
  return response.json();
}

class MemoryKv {
  #values;

  constructor(entries = []) {
    this.#values = new Map(entries);
  }

  async get(key) {
    return this.#values.get(key) ?? null;
  }

  async put(key, value) {
    this.#values.set(key, value);
  }

  async del(key) {
    this.#values.delete(key);
  }
}

class MemoryR2 {
  objects = new Map();

  async put(key, value, options = {}) {
    this.objects.set(key, { bytes: new Uint8Array(value), httpMetadata: options.httpMetadata });
  }

  async get(key) {
    const object = this.objects.get(key);
    return object == null ? null : { body: object.bytes, httpMetadata: object.httpMetadata };
  }

  async delete(key) {
    this.objects.delete(key);
  }
}

class MemoryStorage {
  #values = new Map();

  async get(key) {
    return this.#values.get(key);
  }

  async put(key, value) {
    this.#values.set(key, value);
  }

  async delete(key) {
    return this.#values.delete(key);
  }
}
