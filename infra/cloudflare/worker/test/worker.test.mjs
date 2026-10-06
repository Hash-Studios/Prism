import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { test } from 'node:test';
import { AiQuotaCoordinator } from '../src/ai.ts';
import { verifyFirebaseIdTokenFromRequest } from '../src/firebase_auth.ts';
import worker from '../src/index.ts';

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
  assert.deepEqual((await association.json()).applinks.details[0].paths, [
    '/share', '/share*', '/share/*', '/user/*', '/setup/*', '/refer/*', '/l/*',
  ]);

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
  assert.match(body, /raw\.githubusercontent\.com\/Hash-Studios\/x\.jpg/);
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
  assert.match(body, /images\.pexels\.com\/a\.jpg/);
  assert.doesNotMatch(body, /http-equiv="refresh"/);
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

async function postGeneration(env) {
  const token = await makeToken({ sub: 'alice' });
  return worker.fetch(
    new Request('https://prismwalls.com/api/ai/generations', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: 'A quiet mountain lake', qualityTier: 'fast' }),
    }),
    env,
    { waitUntil() {} },
  );
}

function mockFal({ providerStatus = 200, imageSize = 4096, imageStatus = 200 } = {}) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.startsWith('https://fal.run/')) {
      return providerStatus === 200
        ? Response.json({ images: [{ url: 'https://fal.media/image.png' }] })
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

function aiKv() {
  const kv = new MemoryKv([
    ['ai:firebase:jwks:v1', jwksCache],
    ['ai:routing:active', JSON.stringify({ hardUserDailyCap: 1 })],
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
