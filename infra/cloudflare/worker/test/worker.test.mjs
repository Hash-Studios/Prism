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
    '/share/*', '/user/*', '/setup/*', '/refer/*', '/l/*',
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
