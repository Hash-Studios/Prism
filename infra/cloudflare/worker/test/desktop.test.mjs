import assert from 'node:assert/strict';
import { test } from 'node:test';
import worker from '../src/index.ts';

const DESKTOP_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
const FIRESTORE_PREFIX = 'https://firestore.googleapis.com/v1/projects/prism-test/databases/(default)/documents/';
const PREVIEW_PREFIX = 'https://us-central1-prism-test.cloudfunctions.net/wallpaperPreview';
const MIXPANEL_PREFIX = 'https://api-js.mixpanel.com/';
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.hash.prism';
const APP_STORE_URL = 'https://apps.apple.com/app/id1405860595';
const THUMB = 'https://img.prismwalls.com/previews/aaa.img';
const DESKTOP_THUMB = 'https://img.prismwalls.com/previews/desktop-bbb.jpg';
const DESKTOP_V = '0123456789abcdef';
const NEXT_DESKTOP_V = 'fedcba9876543210';
const REFERER = 'https://prismwalls.com/wallpaper/LIVE1';

class MemoryKv {
  #values = new Map();

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

class FakeCache {
  entries = new Map();

  async match(request) {
    const entry = this.entries.get(request.url);
    return entry ? new Response(entry.body, { status: entry.status, headers: entry.headers }) : undefined;
  }

  async put(request, response) {
    this.entries.set(request.url, {
      status: response.status,
      headers: [...response.headers],
      body: await response.arrayBuffer(),
    });
  }
}

function encode(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number' && Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === 'object') return { mapValue: { fields: encodeFields(value) } };
  throw new Error(`unsupported fixture value: ${value}`);
}

function encodeFields(object) {
  return Object.fromEntries(Object.entries(object).map(([key, value]) => [key, encode(value)]));
}

function liveWall(overrides = {}) {
  return {
    state: 'live',
    updatedAt: '2026-11-01T00:00:00.000Z',
    title: 'Quiet Harbor',
    category: 'Nature',
    categorySlug: 'nature',
    width: 1440,
    height: 3200,
    thumb: THUMB,
    desktop: { v: DESKTOP_V, thumb: DESKTOP_THUMB, width: 2560, height: 1600 },
    ...overrides,
  };
}

function withoutDesktop(wall) {
  const { desktop, ...rest } = wall;
  return rest;
}

function seedDocs() {
  return {
    'webWalls/LIVE1': liveWall(),
    'webWalls/LIVE2': withoutDesktop(liveWall()),
    'webWalls/GATED1': {
      state: 'gated',
      updatedAt: '2026-11-01T00:00:00.000Z',
      title: 'Quiet Harbor',
      category: 'Nature',
      categorySlug: 'nature',
      width: 1440,
      height: 3200,
      desktop: { v: DESKTOP_V, thumb: DESKTOP_THUMB, width: 2560, height: 1600 },
    },
    'webPages/desktop~1': {
      kind: 'desktop',
      page: 1,
      pages: 1,
      total: 1,
      items: [{
        id: 'LIVE1', title: 'Quiet Harbor', thumb: THUMB, width: 1440, height: 3200, desktop: DESKTOP_THUMB,
      }],
    },
    'webPages/category~nature~1': {
      kind: 'category',
      slug: 'nature',
      name: 'Nature',
      page: 1,
      pages: 1,
      total: 0,
      items: [],
      categories: [{ slug: 'nature', name: 'Nature', count: 0 }],
    },
    'webPages/sitemap~index': {
      sitemaps: [{ name: 'categories-1', lastmod: '2026-11-01T00:00:00.000Z' }],
    },
    'webPages/sitemap~categories-1': {
      kind: 'sitemap',
      entries: '/desktop-wallpapers\t2026-11-01T00:00:00.000Z\n/matching-sets\t2026-11-01T00:00:00.000Z',
    },
  };
}

/**
 * Installs the fake Firestore, wallpaperPreview, Mixpanel and edge cache for one test. Everything is restored by
 * t.after. Returns the request helper plus the state the assertions read.
 */
function setup(t) {
  const realFetch = globalThis.fetch;
  const state = {
    docs: seedDocs(),
    reads: [],
    previewCalls: [],
    previewStatus: 200,
    mixpanelCalls: [],
    otherFetches: [],
    pending: [],
    rateLimits: new Map(),
  };
  const cache = new FakeCache();

  globalThis.fetch = async (input, init) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (url.startsWith(FIRESTORE_PREFIX)) {
      const path = url.slice(FIRESTORE_PREFIX.length).split('/').map((segment) => decodeURIComponent(segment)).join('/');
      state.reads.push(path);
      if (!Object.hasOwn(state.docs, path)) return new Response('{}', { status: 404, headers: { 'content-type': 'application/json' } });
      return Response.json({ fields: encodeFields(state.docs[path]) });
    }
    if (url.startsWith(PREVIEW_PREFIX)) {
      state.previewCalls.push(url);
      const variant = new URL(url).searchParams.get('variant') || 'phone';
      return new Response(state.previewStatus === 200 ? `JPEGBYTES-${variant}` : 'Not found', {
        status: state.previewStatus, headers: { 'content-type': 'image/jpeg' },
      });
    }
    if (url.startsWith(MIXPANEL_PREFIX)) {
      state.mixpanelCalls.push({ url, body: JSON.parse(init.body) });
      return new Response('1', { status: 200 });
    }
    state.otherFetches.push(url);
    return new Response('Not found', { status: 404 });
  };
  globalThis.caches = { default: cache };
  t.after(() => {
    globalThis.fetch = realFetch;
    delete globalThis.caches;
  });

  const env = {
    LINKS_KV: new MemoryKv(),
    AI_STATE_KV: new MemoryKv(),
    // Minimal atomic Durable Object rate limiter for download tests.
    AI_QUOTA_DO: {
      idFromName: () => 'quota-object',
      get: () => ({ fetch: async (_url, init) => {
        const request = JSON.parse(init.body);
        if (request.op !== 'rate_limit_bump') throw new Error('unexpected quota operation');
        const now = Date.now();
        const current = state.rateLimits.get(request.key);
        const count = current && current.expiresAt > now ? current.count : 0;
        if (count >= request.limit) return Response.json({ ok: true, allowed: false, current: count });
        const next = count + 1;
        state.rateLimits.set(request.key, { count: next, expiresAt: current?.expiresAt ?? now + request.ttlSeconds * 1000 });
        return Response.json({ ok: true, allowed: true, current: next });
      } }),
    },
    FIREBASE_PROJECT_ID: 'prism-test',
    PLAY_STORE_URL,
    APP_STORE_URL,
    OG_FALLBACK_IMAGE: 'https://prismwalls.com/assets/og/home.jpg',
  };
  const ctx = { waitUntil(promise) { state.pending.push(promise); } };

  return {
    state,
    cache,
    env,
    get(path, headers = {}) {
      return worker.fetch(new Request(`https://prismwalls.com${path}`, {
        headers: { 'user-agent': DESKTOP_UA, 'cf-connecting-ip': '203.0.113.1', ...headers },
      }), env, ctx);
    },
    download(path, headers = {}) {
      return this.get(path, { referer: REFERER, ...headers });
    },
    async flush() {
      while (state.pending.length > 0) await Promise.all(state.pending.splice(0));
    },
  };
}

test('wall page shows Phone and Desktop tabs only when the wall has a desktop companion', async (t) => {
  const h = setup(t);
  const response = await h.get('/wallpaper/LIVE1');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(body.includes('role="tablist"'));
  assert.ok(body.includes('id="tab-desktop"'));
  assert.ok(body.includes('src="/api/catalog/desktop/LIVE1.jpg?v=0123456789abcdef"'));
  assert.ok(body.includes('data-views'));
  assert.ok(body.includes('<script>'));

  const plain = await h.get('/wallpaper/LIVE2');
  const plainBody = await plain.text();
  assert.equal(plain.status, 200);
  assert.ok(!plainBody.includes('role="tablist"'));
  assert.ok(!plainBody.includes('tab-desktop'));
  assert.ok(!plainBody.includes('Desktop 16:10'));

  const gated = await h.get('/wallpaper/GATED1');
  const gatedBody = await gated.text();
  assert.equal(gated.status, 200);
  assert.ok(!gatedBody.includes('role="tablist"'));
  assert.ok(!gatedBody.includes('Download free'));
  assert.ok(gatedBody.includes('Get it in Prism'));
  assert.ok(!gatedBody.includes('/api/catalog/download/'));
});

test('wall page links the phone, desktop and 16:9 downloads and both stores', async (t) => {
  const h = setup(t);
  const body = await (await h.get('/wallpaper/LIVE1')).text();

  assert.ok(body.includes('href="/api/catalog/download/LIVE1/phone.jpg"'));
  assert.ok(body.includes('href="/api/catalog/download/LIVE1/desktop.jpg"'));
  assert.ok(body.includes('href="/api/catalog/download/LIVE1/desktop-16x9.jpg"'));
  assert.ok(body.includes('Full quality is in Prism'));
  assert.ok(body.includes(`href="${PLAY_STORE_URL}"`));
  assert.ok(body.includes(`href="${APP_STORE_URL}"`));
  assert.ok(body.includes('1152 × 2560'));
});

test('desktop download answers with attachment headers and is never cached', async (t) => {
  const h = setup(t);
  const response = await h.download('/api/catalog/download/LIVE1/desktop.jpg', { referer: REFERER });
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'image/jpeg');
  assert.equal(response.headers.get('content-disposition'), 'attachment; filename="prism-quiet-harbor-desktop.jpg"');
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(body, 'JPEGBYTES-desktop');

  assert.equal(h.state.previewCalls.length, 1);
  const called = new URL(h.state.previewCalls[0]);
  assert.equal(called.searchParams.get('variant'), 'desktop');
  assert.equal(called.searchParams.get('v'), DESKTOP_V);
  assert.equal(called.searchParams.get('thumb'), THUMB);

  const again = await h.download('/api/catalog/download/LIVE1/desktop.jpg', { referer: REFERER });
  assert.equal(await again.text(), 'JPEGBYTES-desktop');
  assert.equal(h.state.previewCalls.length, 2);
  assert.ok(![...h.cache.entries.keys()].some((key) => key.includes('download')));
});

test('HEAD on downloads and rendition routes does no limiter, Firestore or preview work', async (t) => {
  const h = setup(t);
  h.env.MIXPANEL_TOKEN = 'tok';
  const path = '/api/catalog/download/LIVE1/desktop.jpg';
  const response = await worker.fetch(new Request(`https://prismwalls.com${path}`, {
    method: 'HEAD', headers: { referer: REFERER, 'cf-connecting-ip': '203.0.113.11' },
  }), h.env, { waitUntil(promise) { h.state.pending.push(promise); } });

  assert.equal(response.status, 405);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(h.state.reads.length, 0);
  assert.equal(h.state.previewCalls.length, 0);
  assert.equal(h.state.rateLimits.size, 0);
  assert.equal(h.state.mixpanelCalls.length, 0);

  const rendition = await worker.fetch(new Request('https://prismwalls.com/api/catalog/preview/LIVE1.jpg', {
    method: 'HEAD',
  }), h.env, { waitUntil(promise) { h.state.pending.push(promise); } });
  assert.equal(rendition.status, 405);
  assert.equal(h.state.reads.length, 0);
  assert.equal(h.state.previewCalls.length, 0);

  const desktop = await worker.fetch(new Request(`https://prismwalls.com/api/catalog/desktop/LIVE1.jpg?v=${DESKTOP_V}`, {
    method: 'HEAD',
  }), h.env, { waitUntil(promise) { h.state.pending.push(promise); } });
  assert.equal(desktop.status, 405);
  assert.equal(h.state.reads.length, 0);
  assert.equal(h.state.previewCalls.length, 0);
  assert.equal(h.state.mixpanelCalls.length, 0);
});

test('downloads from another site redirect to the wall page', async (t) => {
  const h = setup(t);

  const desktop = await h.download('/api/catalog/download/LIVE1/desktop.jpg', { referer: 'https://evil.example/page' });
  assert.equal(desktop.status, 302);
  assert.equal(desktop.headers.get('location'), 'https://prismwalls.com/wallpaper/LIVE1#desktop');
  assert.equal(desktop.headers.get('cache-control'), 'no-store');

  const phone = await h.download('/api/catalog/download/LIVE1/phone.jpg', { referer: 'https://evil.example/page' });
  assert.equal(phone.status, 302);
  assert.equal(phone.headers.get('location'), 'https://prismwalls.com/wallpaper/LIVE1');

  assert.equal(h.state.previewCalls.length, 0);
});

test('referer rules allow the site and its www host, and block lookalike hosts', async (t) => {
  const h = setup(t);
  const path = '/api/catalog/download/LIVE1/desktop.jpg';

  const none = await h.get(path);
  assert.equal(none.status, 302);

  const sameOrigin = await h.get(path, { 'sec-fetch-site': 'same-origin' });
  assert.equal(sameOrigin.status, 200);

  const www = await h.get(path, { referer: 'https://www.prismwalls.com/x' });
  assert.equal(www.status, 200);

  const lookalike = await h.get(path, { referer: 'https://prismwalls.com.evil.example/' });
  assert.equal(lookalike.status, 302);

  const contradictory = await h.get(path, {
    referer: REFERER, 'sec-fetch-site': 'cross-site', 'cf-connecting-ip': '203.0.113.12',
  });
  assert.equal(contradictory.status, 302);
});

test('desktop rendition requires its current version and fails closed on origin errors', async (t) => {
  const h = setup(t);
  const current = await h.get(`/api/catalog/desktop/LIVE1.jpg?v=${DESKTOP_V}`);
  assert.equal(current.status, 200);
  assert.equal(current.headers.get('cache-control'), 'no-store');
  assert.equal(await current.text(), 'JPEGBYTES-desktop');

  const oldVersion = await h.get('/api/catalog/desktop/LIVE1.jpg?v=old-version');
  assert.equal(oldVersion.status, 404);
  assert.equal(h.state.previewCalls.length, 1);

  h.state.docs['webWalls/LIVE1'] = { ...liveWall(), state: 'gated', desktop: { ...liveWall().desktop, v: NEXT_DESKTOP_V } };
  const gated = await h.get(`/api/catalog/desktop/LIVE1.jpg?v=${DESKTOP_V}`);
  assert.equal(gated.status, 404);
  assert.equal(gated.headers.get('cache-control'), 'no-store');
  assert.equal(h.state.previewCalls.length, 1);

  h.state.docs['webWalls/LIVE1'] = liveWall({ desktop: { ...liveWall().desktop, v: NEXT_DESKTOP_V } });
  h.state.previewStatus = 404;
  const failedOrigin = await h.get(`/api/catalog/desktop/LIVE1.jpg?v=${NEXT_DESKTOP_V}`);
  assert.equal(failedOrigin.status, 503);
  assert.equal(failedOrigin.headers.get('cache-control'), 'no-store');
  assert.equal(failedOrigin.headers.get('location'), null);
  assert.equal(h.state.previewCalls.length, 2);

  h.state.previewStatus = 200;
  const currentVersion = await h.get(`/api/catalog/desktop/LIVE1.jpg?v=${NEXT_DESKTOP_V}`);
  assert.equal(currentVersion.status, 200);
  assert.equal(h.state.previewCalls.length, 3);
  assert.equal(new URL(h.state.previewCalls[2]).searchParams.get('v'), NEXT_DESKTOP_V);
});

test('downloads are rate limited per IP', async (t) => {
  const h = setup(t);
  const path = '/api/catalog/download/LIVE1/phone.jpg';
  const headers = { referer: REFERER, 'cf-connecting-ip': '203.0.113.9' };

  for (let attempt = 1; attempt <= 30; attempt += 1) {
    const response = await h.get(path, headers);
    await response.arrayBuffer();
    assert.equal(response.status, 200, `download ${attempt}`);
  }

  const limited = await h.get(path, headers);
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get('retry-after'), '600');
  assert.equal(limited.headers.get('cache-control'), 'no-store');

  const other = await h.get(path, { referer: REFERER, 'cf-connecting-ip': '198.51.100.7' });
  assert.equal(other.status, 200);
});

test('downloads fail closed when the trusted IP or atomic limiter is unavailable', async (t) => {
  const h = setup(t);
  const path = '/api/catalog/download/LIVE1/phone.jpg';
  const noIp = await worker.fetch(new Request(`https://prismwalls.com${path}`, { headers: { referer: REFERER } }), h.env,
    { waitUntil() {} });
  assert.equal(noIp.status, 503);
  assert.equal(h.state.previewCalls.length, 0);

  let kvCalls = 0;
  h.env.LINKS_KV = { get: async () => { kvCalls += 1; return null; }, put: async () => { kvCalls += 1; } };
  h.env.AI_QUOTA_DO = { idFromName: () => 'quota-object', get: () => ({ fetch: async () => { throw new Error('DO down'); } }) };
  const failed = await h.get(path, { referer: REFERER, 'cf-connecting-ip': '203.0.113.10' });
  assert.equal(failed.status, 503);
  assert.equal(failed.headers.get('cache-control'), 'no-store');
  assert.equal(kvCalls, 0);
  assert.equal(h.state.reads.length, 0);
  assert.equal(h.state.previewCalls.length, 0);
});

test('gated walls are never downloadable and missing companions answer 404', async (t) => {
  const h = setup(t);
  const referer = { referer: REFERER };

  for (const file of ['phone.jpg', 'desktop.jpg']) {
    const response = await h.get(`/api/catalog/download/GATED1/${file}`, referer);
    assert.equal(response.status, 404, file);
  }
  assert.equal(h.state.previewCalls.length, 0);

  const noCompanion = await h.get('/api/catalog/download/LIVE2/desktop.jpg', referer);
  assert.equal(noCompanion.status, 404);
  const phone = await h.get('/api/catalog/download/LIVE2/phone.jpg', referer);
  assert.equal(phone.status, 200);
  assert.equal(await phone.text(), 'JPEGBYTES-phone');

  const missing = await h.get('/api/catalog/download/NOPE/phone.jpg', referer);
  assert.equal(missing.status, 404);

  const gatedImage = await h.get('/api/catalog/desktop/GATED1.jpg');
  assert.equal(gatedImage.status, 404);

  const unknownFile = await h.get('/api/catalog/download/LIVE1/original.jpg', referer);
  const unknownBody = await unknownFile.text();
  assert.ok(unknownFile.status !== 200 || !unknownBody.includes('JPEGBYTES-'));
});

test('a desktop companion with an untrusted thumb is dropped', async (t) => {
  const h = setup(t);
  h.state.docs['webWalls/LIVE1'] = liveWall({
    desktop: { v: DESKTOP_V, thumb: 'https://evil.example/previews/x.jpg', width: 2560, height: 1600 },
  });

  const body = await (await h.get('/wallpaper/LIVE1')).text();
  assert.ok(!body.includes('role="tablist"'));

  const download = await h.download('/api/catalog/download/LIVE1/desktop.jpg');
  assert.equal(download.status, 404);
  assert.equal(h.state.previewCalls.length, 0);
});

test('desktop hub lists desktop wallpapers and redirects the page-1 link', async (t) => {
  const h = setup(t);
  const response = await h.get('/desktop-wallpapers');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(body.includes('<h1>Desktop wallpapers</h1>'));
  assert.ok(body.includes('rel="canonical" href="https://prismwalls.com/desktop-wallpapers"'));
  assert.ok(body.includes('href="/wallpaper/LIVE1#desktop"'));
  assert.ok(body.includes(`src="${DESKTOP_THUMB}"`));
  assert.ok(body.includes('<a href="/desktop-wallpapers" aria-current="page">'));

  const page1 = await h.get('/desktop-wallpapers?page=1');
  assert.equal(page1.status, 301);
  assert.equal(page1.headers.get('location'), 'https://prismwalls.com/desktop-wallpapers');

  const extra = await h.get('/desktop-wallpapers/extra');
  assert.equal(extra.status, 404);
});

test('desktop hub returns 404 when a later page has no desktop companions', async (t) => {
  const h = setup(t);
  h.state.docs['webPages/desktop~2'] = {
    kind: 'desktop', page: 2, pages: 2, total: 2,
    items: [{ id: 'LIVE2', title: 'Phone only', thumb: THUMB, width: 1440, height: 3200 }],
  };

  const response = await h.get('/matching-sets?page=2');
  assert.equal(response.status, 404);
  assert.equal(response.headers.get('x-robots-tag'), 'noindex');
});

test('matching sets hub shows the phone and desktop pair for each wall', async (t) => {
  const h = setup(t);
  const response = await h.get('/matching-sets');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(body.includes('<h1>Matching sets</h1>'));
  assert.ok(body.includes('class="desk-grid sets"'));
  assert.ok(body.includes(`src="${THUMB}"`));
  assert.ok(body.includes(`src="${DESKTOP_THUMB}"`));
});

test('sitemap lists the desktop hub and the matching sets page', async (t) => {
  const h = setup(t);
  const response = await h.get('/sitemaps/categories-1.xml');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(body.includes('<loc>https://prismwalls.com/desktop-wallpapers</loc>'));
  assert.ok(body.includes('<loc>https://prismwalls.com/matching-sets</loc>'));
});

test('one allowed download counts once in Mixpanel, and blocked or uncounted downloads do not', async (t) => {
  const h = setup(t);
  h.env.MIXPANEL_TOKEN = 'tok';

  const response = await h.download('/api/catalog/download/LIVE1/desktop-16x9.jpg');
  assert.equal(response.status, 200);
  await response.arrayBuffer();
  await h.flush();

  assert.equal(h.state.mixpanelCalls.length, 1);
  const call = h.state.mixpanelCalls[0];
  assert.equal(call.url, 'https://api-js.mixpanel.com/track?ip=0');
  assert.equal(call.body[0].event, 'web_wallpaper_downloaded');
  assert.equal(call.body[0].properties.wall_id, 'LIVE1');
  assert.equal(call.body[0].properties.file, 'desktop-16x9');
  assert.equal(call.body[0].properties.token, 'tok');

  const blocked = await h.download('/api/catalog/download/LIVE1/phone.jpg', { referer: 'https://evil.example/' });
  assert.equal(blocked.status, 302);
  await h.flush();
  assert.equal(h.state.mixpanelCalls.length, 1);

  delete h.env.MIXPANEL_TOKEN;
  const uncounted = await h.download('/api/catalog/download/LIVE1/phone.jpg');
  assert.equal(uncounted.status, 200);
  await uncounted.arrayBuffer();
  await h.flush();
  assert.equal(h.state.mixpanelCalls.length, 1);
});
