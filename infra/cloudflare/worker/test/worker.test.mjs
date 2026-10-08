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

function mockFal({ providerStatus = 200, imageSize = 4096, imageStatus = 200, firestore = null, stats = {} } = {}) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = String(input instanceof Request ? input.url : input);
    if (url.startsWith('https://firestore.googleapis.com/') && firestore != null) {
      stats.firestore = (stats.firestore ?? 0) + 1;
      return firestore(url, init);
    }
    if (url.startsWith('https://fal.run/')) {
      stats.fal = (stats.fal ?? 0) + 1;
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
