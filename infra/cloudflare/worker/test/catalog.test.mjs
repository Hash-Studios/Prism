import vm from 'node:vm';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import worker from '../src/index.ts';

const DESKTOP_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
const ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36';
const IPHONE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1';
const IPADOS_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15';
const FIRESTORE_PREFIX = 'https://firestore.googleapis.com/v1/projects/prism-test/databases/(default)/documents/';
const PREVIEW_PREFIX = 'https://us-central1-prism-test.cloudfunctions.net/wallpaperPreview';
const THUMB = 'https://img.prismwalls.com/previews/aaa.img';

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

function card(id, title) {
  return { id, title, thumb: 'https://img.prismwalls.com/previews/x.img', width: 1080, height: 2340 };
}

function seedDocs() {
  const nature = Array.from({ length: 13 }, (_, index) => card(`N${index + 2}`, `Nature ${index + 2}`));
  return {
    'webWalls/W1': {
      state: 'live',
      updatedAt: '2026-10-30T00:00:00.000Z',
      title: 'Sunset Ridge',
      description: 'Warm light over hills',
      category: 'Nature',
      categorySlug: 'nature',
      tags: ['sky', 'hills'],
      colors: [{ name: 'orange', hex: '#ff6600' }],
      width: 1080,
      height: 2340,
      createdAt: '2026-10-01T00:00:00.000Z',
      creatorName: 'Sam K',
      creator: { username: 'sam', name: 'Sam K' },
      thumb: THUMB,
    },
    'webWalls/G1': {
      state: 'gated',
      updatedAt: '2026-10-30T00:00:00.000Z',
      title: 'Locked Nebula',
      category: 'Space',
      categorySlug: 'space',
      width: 1080,
      height: 2340,
      creatorName: 'Sam K',
      creator: { username: 'sam', name: 'Sam K' },
      blur: 'data:image/jpeg;base64,AAAA',
    },
    'webWalls/DW1': {
      state: 'live',
      updatedAt: '2026-10-30T00:00:00.000Z',
      title: 'Desk Dawn',
      category: 'Nature',
      categorySlug: 'nature',
      width: 1080,
      height: 2340,
      creatorName: 'Sam K',
      creator: { username: 'sam', name: 'Sam K' },
      thumb: THUMB,
      desktop: { v: '0123456789abcdef', thumb: 'https://img.prismwalls.com/previews/desktop-dw1.jpg', width: 2560, height: 1600 },
    },
    'webWalls/H1': { state: 'hidden', updatedAt: 'x' },
    'webWalls/D1': { state: 'gone', updatedAt: 'x' },
    'webPages/category~nature~1': {
      kind: 'category',
      slug: 'nature',
      name: 'Nature',
      page: 1,
      pages: 2,
      total: 30,
      items: [card('W1', 'Sunset Ridge'), ...nature],
      categories: [{ slug: 'nature', name: 'Nature', count: 30 }],
    },
    'webPages/folder~F1': {
      kind: 'folder',
      id: 'F1',
      name: 'Calm',
      owner: { username: 'sam', name: 'Sam K', hasPage: true },
      total: 3,
      items: [card('W1', 'Sunset Ridge'), card('N2', 'Nature 2')],
      updatedAt: '2026-10-29T00:00:00.000Z',
    },
    'webPages/creator~sam~1': {
      kind: 'creator',
      page: 1,
      pages: 1,
      total: 1,
      items: [card('W1', 'Sunset Ridge')],
      creator: { username: 'sam', name: 'Sam K', bio: 'I make calm walls', photo: 'https://lh3.googleusercontent.com/p.jpg' },
      folders: [],
    },
    'webPages/latest~1': {
      kind: 'latest',
      page: 1,
      pages: 3,
      total: 60,
      items: [card('W1', 'Sunset Ridge')],
      categories: [{ slug: 'nature', name: 'Nature', count: 30 }],
    },
    'webPages/sitemap~index': {
      kind: 'sitemap-index',
      sitemaps: [
        { name: 'walls-1', lastmod: '2026-10-30T00:00:00.000Z' },
        { name: 'walls-2', lastmod: '2026-10-31T00:00:00.000Z' },
      ],
    },
    'webPages/sitemap~walls-1': {
      kind: 'sitemap',
      lastmod: '2026-10-30T00:00:00.000Z',
      entries: '/wallpaper/W1\t2026-10-30T00:00:00.000Z\n/wallpaper/N2\t2026-10-29T00:00:00.000Z',
    },
  };
}

/**
 * Installs the fake Firestore, Functions and edge cache for one test. Everything is restored by t.after.
 * Returns the request helpers plus the state the assertions read.
 */
function setup(t, { firestoreStatus = null } = {}) {
  const realFetch = globalThis.fetch;
  const state = {
    docs: seedDocs(),
    reads: [],
    otherFetches: [],
    previewCalls: [],
    previewStatus: 200,
    pending: [],
    firestoreStatus,
    firestoreGate: null,
    invalidFirestoreJson: false,
  };
  const cache = new FakeCache();

  globalThis.fetch = async (input) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (url.startsWith(FIRESTORE_PREFIX)) {
      state.reads.push(url);
      if (state.firestoreGate) await state.firestoreGate;
      if (state.firestoreStatus) return new Response('', { status: state.firestoreStatus });
      if (state.invalidFirestoreJson) return new Response('{', { status: 200 });
      const path = url.slice(FIRESTORE_PREFIX.length).split('/').map((segment) => decodeURIComponent(segment)).join('/');
      if (!Object.hasOwn(state.docs, path)) return new Response('{}', { status: 404, headers: { 'content-type': 'application/json' } });
      return Response.json({ fields: encodeFields(state.docs[path]) });
    }
    if (url.startsWith(PREVIEW_PREFIX)) {
      state.previewCalls.push(url);
      if (state.previewStatus !== 200) return new Response('Not found', { status: state.previewStatus });
      return new Response(new Uint8Array([1, 2, 3]), { status: 200, headers: { 'content-type': 'image/jpeg' } });
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
    FIREBASE_PROJECT_ID: 'prism-test',
    PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id6670200846',
    OG_FALLBACK_IMAGE: 'https://prismwalls.com/assets/og/home.jpg',
  };
  const ctx = { waitUntil(promise) { state.pending.push(promise); } };

  return {
    state,
    cache,
    env,
    get(path, ua = DESKTOP_UA) {
      return worker.fetch(new Request(`https://prismwalls.com${path}`, { headers: { 'user-agent': ua } }), env, ctx);
    },
    async flush() {
      while (state.pending.length > 0) await Promise.all(state.pending.splice(0));
    },
  };
}

/** Freezes Date.now so the edge-cache age can be moved forward deterministically. */
function stubClock(t) {
  const realNow = Date.now;
  let now = realNow();
  Date.now = () => now;
  t.after(() => {
    Date.now = realNow;
  });
  return { advance(seconds) { now += seconds * 1000; } };
}

function ldJson(body) {
  return [...body.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)].map((match) => JSON.parse(match[1]));
}

function runOpenAppScript(html, navigator, host, hrefs) {
  const script = html.match(/<script>(if\(\/android[^<]*)<\/script>/)[1];
  const links = [...html.matchAll(/<a\b[^>]*href="([^"]*)"[^>]*data-android="([^"]*)"[^>]*>/g)];
  const anchors = (hrefs ?? links.map((link) => link[1])).map((href, index) => ({
    href,
    getAttribute: (name) => name === 'data-android' ? links[index % links.length][2].replaceAll('&amp;', '&') : null,
  }));
  assert.ok(anchors.length > 0, 'the rendered page has an Open in Prism anchor');
  vm.runInNewContext(script, { URL, navigator, location: { host }, document: { querySelectorAll: () => anchors } });
  return anchors.map((anchor) => anchor.href);
}

test('wall page renders the public metadata, structured data and related grid', async (t) => {
  const h = setup(t);
  const response = await h.get('/wallpaper/W1');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /^text\/html/);
  assert.ok(body.includes('<title>Sunset Ridge by Sam K | Prism</title>'));
  assert.ok(body.includes('<link rel="canonical" href="https://prismwalls.com/wallpaper/W1">'));
  assert.ok(body.includes('property="og:title"'));
  assert.ok(body.includes('property="og:image" content="https://prismwalls.com/og/wall/W1.jpg?v='));
  assert.ok(body.includes('name="twitter:card" content="summary_large_image"'));
  assert.ok(body.includes('name="robots" content="index,follow,max-image-preview:large"'));
  assert.ok(body.includes('href="/creator/sam"'));
  assert.ok(body.includes('Open in Prism'));
  assert.ok(body.includes('Google Play'));
  assert.ok(body.includes('App Store'));
  assert.ok(body.includes('src="/api/catalog/preview/W1.jpg"'));
  assert.ok(body.includes('width="1080" height="2340"'));

  const ld = ldJson(body);
  const image = ld.find((entry) => entry['@type'] === 'ImageObject');
  assert.ok(image, 'ImageObject JSON-LD present');
  assert.equal(image.contentUrl, 'https://prismwalls.com/api/catalog/preview/W1.jpg');
  assert.equal(image.creator.name, 'Sam K');
  assert.equal(image.creator.url, 'https://prismwalls.com/creator/sam');
  assert.equal(image.creditText, 'Sam K');
  const breadcrumb = ld.find((entry) => entry['@type'] === 'BreadcrumbList');
  assert.ok(breadcrumb, 'BreadcrumbList JSON-LD present');
  assert.equal(breadcrumb.itemListElement.length, 3);

  assert.equal(body.match(/<li><a href="\/wallpaper\/N\d+"/g)?.length, 12);
  assert.ok(!body.includes('<li><a href="/wallpaper/W1"'), 'the wall does not list itself');
  assert.equal(h.state.reads.length, 2);
  assert.ok(h.state.reads[0].endsWith('/webWalls/W1'));
  assert.ok(h.state.reads[1].endsWith('/webPages/category~nature~1'));
});

test('wall and folder creator links keep the stored username case', async (t) => {
  const h = setup(t);
  h.state.docs['webWalls/W1'].creator.username = 'SAM';
  h.state.docs['webPages/folder~F1'].owner.username = 'SAM';

  const wall = await (await h.get('/wallpaper/W1')).text();
  const folder = await (await h.get('/folder/F1')).text();

  assert.match(wall, /href="\/creator\/SAM"/);
  assert.match(folder, /href="\/creator\/SAM"/);
});

test('gated wall shows the blurred landing and no preview image', async (t) => {
  const h = setup(t);
  const response = await h.get('/wallpaper/G1');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(body.includes('name="robots" content="noindex,follow"'));
  assert.ok(body.includes('Get it in Prism'));
  assert.ok(body.includes('data:image/jpeg;base64,AAAA'));
  assert.ok(!body.includes('img.prismwalls.com/previews'));
  assert.ok(!body.includes('/api/catalog/preview/G1.jpg'));
  assert.ok(!body.includes('"ImageObject"'));
  assert.ok(body.includes('property="og:image" content="https://prismwalls.com/assets/og/home.jpg"'));
});

test('hidden, removed and unknown walls answer 404, 410 and 404 with noindex', async (t) => {
  const h = setup(t);
  const cases = [
    ['/wallpaper/H1', 404],
    ['/wallpaper/D1', 410],
    ['/wallpaper/ZZZ9', 404],
  ];
  for (const [path, status] of cases) {
    const response = await h.get(path);
    const body = await response.text();
    assert.equal(response.status, status, path);
    assert.ok(body.includes('<meta name="robots" content="noindex">'), path);
    assert.equal(response.headers.get('x-robots-tag'), 'noindex', path);
    assert.ok(!body.includes('Sunset'), path);
  }
});

test('folder page renders the owner and canonical, and a missing folder is 404', async (t) => {
  const h = setup(t);
  const response = await h.get('/folder/F1');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(body.includes('<title>Calm by Sam K: 3 wallpapers | Prism</title>'));
  assert.ok(body.includes('<link rel="canonical" href="https://prismwalls.com/folder/F1">'));
  assert.ok(body.includes('href="/creator/sam"'));

  const missing = await h.get('/folder/PRIVATE1');
  assert.equal(missing.status, 404);
  assert.equal(missing.headers.get('x-robots-tag'), 'noindex');
  assert.ok((await missing.text()).includes('<meta name="robots" content="noindex">'));
});

test('a folder owner without a creator page is plain text, not a link', async (t) => {
  const h = setup(t);
  h.state.docs['webPages/folder~F1'].owner = { username: 'sam', name: 'Sam K' };

  const body = await (await h.get('/folder/F1')).text();

  assert.ok(body.includes('A folder by Sam K · '));
  assert.ok(!body.includes('/creator/sam'));
});

test('a folder owner marked without a creator page is not linked', async (t) => {
  const h = setup(t);
  h.state.docs['webPages/folder~F1'].owner.hasPage = false;
  const readsBefore = h.state.reads.length;

  const body = await (await h.get('/folder/F1')).text();

  assert.ok(body.includes('A folder by Sam K · '));
  assert.doesNotMatch(body, /href="\/creator\/sam"/);
  assert.equal(h.state.reads.length - readsBefore, 1, 'a folder page reads only its own document');
});

test('a creator photo outside the profile photo hosts is dropped and the page still renders', async (t) => {
  const h = setup(t);
  h.state.docs['webPages/creator~sam~1'].creator.photo = 'https://tracker.example/pixel.gif';

  const response = await h.get('/creator/sam');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.ok(!body.includes('tracker.example'));
  assert.ok(body.includes('class="avatar initial"'));
});

for (const photo of [
  'https://raw.githubusercontent.com.evil.example/avatar.jpg',
  'https://user@raw.githubusercontent.com/avatar.jpg',
  'https://user:password@raw.githubusercontent.com/avatar.jpg',
  'https://raw.githubusercontent.com:8443/avatar.jpg',
  'http://raw.githubusercontent.com/avatar.jpg',
  'https://evil.googleusercontent.com.example/avatar.jpg',
  'https://evilgoogleusercontent.com/avatar.jpg',
  'https://googleusercontent.com/avatar.jpg',
  'https://googleusercontent.com。evil.example/avatar.jpg',
  'https://googlеusercontent.com/avatar.jpg',
]) {
  test(`creator photo rejects allowlist lookalike ${photo}`, async (t) => {
    const h = setup(t);
    h.state.docs['webPages/creator~sam~1'].creator.photo = photo;

    const response = await h.get('/creator/sam');
    const body = await response.text();
    const profile = ldJson(body).find((entry) => entry['@type'] === 'ProfilePage');

    assert.equal(response.status, 200);
    assert.equal((body.match(/property="og:image"/g) ?? []).length, 1);
    assert.ok(body.includes('property="og:image" content="https://prismwalls.com/assets/og/home.jpg"'));
    assert.ok(!body.includes(photo));
    assert.equal(profile.mainEntity.image, undefined);
    assert.ok(body.includes('class="avatar initial"'));
  });
}

for (const photo of [
  'https://raw.githubusercontent.com/avatar.jpg',
  'https://FIREBASESTORAGE.GOOGLEAPIS.COM/avatar.jpg',
  'https://LH3.GOOGLEUSERCONTENT.COM/avatar.jpg',
]) {
  test(`creator photo accepts allowlisted host ${photo}`, async (t) => {
    const h = setup(t);
    h.state.docs['webPages/creator~sam~1'].creator.photo = photo;

    const response = await h.get('/creator/sam');
    const body = await response.text();
    const profile = ldJson(body).find((entry) => entry['@type'] === 'ProfilePage');

    assert.equal(response.status, 200);
    assert.ok(body.includes(`class="avatar" src="${photo}"`));
    assert.ok(body.includes(`property="og:image" content="${photo}"`));
    assert.equal(profile.mainEntity.image, photo);
  });
}

test('cache headers: 200 is fresh for ten minutes, misses for five, and the stored-at marker never leaks', async (t) => {
  const h = setup(t);
  const first = await h.get('/wallpaper/W1');
  const firstBody = await first.text();
  await h.flush();
  assert.equal(first.headers.get('cache-control'), 'public, max-age=600, stale-while-revalidate=86400');

  const readsBefore = h.state.reads.length;
  const second = await h.get('/wallpaper/W1');
  const secondBody = await second.text();
  await h.flush();
  assert.equal(h.state.reads.length, readsBefore);
  assert.equal(secondBody, firstBody);
  assert.equal(second.headers.get('x-catalog-stored-at'), null);
  assert.equal(second.headers.get('cache-control'), 'public, max-age=600, stale-while-revalidate=86400');

  const miss = await h.get('/wallpaper/ZZZ9');
  assert.equal(miss.headers.get('cache-control'), 'public, max-age=300');

  for (const [path, expectedStatus] of [['/wallpaper/H1', 404], ['/wallpaper/D1', 410]]) {
    const absent = await h.get(path);
    assert.equal(absent.status, expectedStatus);
    await absent.text();
    await h.flush();
    const reads = h.state.reads.length;
    const cachedAbsent = await h.get(path);
    assert.equal(cachedAbsent.status, expectedStatus);
    await cachedAbsent.text();
    await h.flush();
    assert.equal(h.state.reads.length, reads, `${expectedStatus} should be cached`);
    assert.equal(cachedAbsent.headers.get('cache-control'), 'public, max-age=300');
  }
});

test('cache key ignores query strings and user agents', async (t) => {
  const h = setup(t);
  const cachedFirst = await h.get('/wallpaper/W1');
  await cachedFirst.text();
  await h.flush();

  const readsBefore = h.state.reads.length;
  const withQuery = await h.get('/wallpaper/W1?utm_source=x&evil=%3Cscript%3E', ANDROID_UA);
  const body = await withQuery.text();
  await h.flush();
  assert.equal(h.state.reads.length, readsBefore);
  assert.ok(!body.includes('evil'));
  assert.ok(!body.includes('%3Cscript'));

  h.cache.entries.clear();
  const androidHtml = await (await h.get('/wallpaper/W1', ANDROID_UA)).text();
  await h.flush();
  h.cache.entries.clear();
  const desktopHtml = await (await h.get('/wallpaper/W1', DESKTOP_UA)).text();
  await h.flush();
  assert.equal(androidHtml, desktopHtml);
  assert.match(desktopHtml, /data-android="intent:\/\/prismwalls\.com\/wallpaper\/W1#Intent;scheme=https;package=com\.hash\.prism;/);
  assert.equal(desktopHtml.match(/intent:\/\//g)?.length, 1);
});

test('on iOS the open link moves to the other associated host, so Safari hands it to the app', async (t) => {
  const h = setup(t);
  const devices = [
    { userAgent: IPHONE_UA, platform: 'iPhone', maxTouchPoints: 5 },
    { userAgent: 'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X)', platform: 'iPad', maxTouchPoints: 5 },
    { userAgent: 'Mozilla/5.0 (iPod; CPU iPhone OS 18_0 like Mac OS X)', platform: 'iPod', maxTouchPoints: 5 },
    { userAgent: IPADOS_UA, platform: 'MacIntel', maxTouchPoints: 5 },
  ];
  for (const path of ['/wallpaper/W1', '/folder/F1']) {
    const html = await (await h.get(path)).text();
    await h.flush();
    for (const device of devices) {
      assert.deepEqual(runOpenAppScript(html, device, 'prismwalls.com'), [`https://www.prismwalls.com${path}`]);
      assert.deepEqual(runOpenAppScript(html, device, 'www.prismwalls.com'), [`https://prismwalls.com${path}`]);
    }
  }
});

test('the emitted script preserves the Android intent fallback and desktop canonical links on both hosts', async (t) => {
  const h = setup(t);
  const html = await (await h.get('/wallpaper/W1')).text();
  await h.flush();
  for (const host of ['prismwalls.com', 'www.prismwalls.com']) {
    assert.deepEqual(runOpenAppScript(html, { userAgent: ANDROID_UA, platform: 'Linux armv8l', maxTouchPoints: 5 }, host), [
      'intent://prismwalls.com/wallpaper/W1#Intent;scheme=https;package=com.hash.prism;'
        + 'S.browser_fallback_url=https%3A%2F%2Fplay.google.com%2Fstore%2Fapps%2Fdetails%3Fid%3Dcom.hash.prism;end',
    ]);
    for (const device of [
      { userAgent: DESKTOP_UA, platform: 'Linux x86_64', maxTouchPoints: 0 },
      { userAgent: IPADOS_UA, platform: 'MacIntel', maxTouchPoints: 0 },
    ]) {
      assert.deepEqual(runOpenAppScript(html, device, host), ['https://prismwalls.com/wallpaper/W1']);
    }
  }
});

test('iOS host switching preserves the path, query and fragment for either Prism host', async (t) => {
  const h = setup(t);
  const html = await (await h.get('/wallpaper/W1')).text();
  await h.flush();
  const device = { userAgent: IPHONE_UA, platform: 'iPhone', maxTouchPoints: 5 };
  for (const host of ['prismwalls.com', 'www.prismwalls.com']) {
    assert.deepEqual(runOpenAppScript(html, device, host, [
      'https://prismwalls.com/wallpaper/W1?ref=a%2Fb&source=x#preview',
      'https://www.prismwalls.com/folder/F1?ref=a%2Fb&source=x#preview',
    ]), host === 'prismwalls.com' ? [
      'https://www.prismwalls.com/wallpaper/W1?ref=a%2Fb&source=x#preview',
      'https://www.prismwalls.com/folder/F1?ref=a%2Fb&source=x#preview',
    ] : [
      'https://prismwalls.com/wallpaper/W1?ref=a%2Fb&source=x#preview',
      'https://prismwalls.com/folder/F1?ref=a%2Fb&source=x#preview',
    ]);
  }
});

test('the emitted iOS script never rewrites non-Prism hosts, even when they match the page host', async (t) => {
  const h = setup(t);
  const html = await (await h.get('/wallpaper/W1')).text();
  await h.flush();
  const device = { userAgent: IPHONE_UA, platform: 'iPhone', maxTouchPoints: 5 };
  for (const host of ['external.example', 'www.external.example', 'prismwalls.com.evil.example', 'sub.prismwalls.com']) {
    const external = `https://${host}/wallpaper/W1?ref=a%2Fb#preview`;
    for (const pageHost of ['prismwalls.com', host]) {
      assert.deepEqual(runOpenAppScript(html, device, pageHost, [external]), [external]);
    }
  }
  assert.deepEqual(runOpenAppScript(html, device, 'prismwalls.com', [
    'https://prismwalls.com/wallpaper/W1', 'mailto:hello@example.com', 'javascript:void(0)',
  ]), ['https://www.prismwalls.com/wallpaper/W1', 'mailto:hello@example.com', 'javascript:void(0)']);
});

test('cold and cached catalogue HTML is identical across both Prism hosts and all device classes', async (t) => {
  const h = setup(t);
  const expected = await (await h.get('/wallpaper/W1')).text();
  await h.flush();
  const ctx = { waitUntil(promise) { h.state.pending.push(promise); } };
  for (const cold of [false, true]) {
    for (const host of ['prismwalls.com', 'www.prismwalls.com']) {
      for (const ua of [IPHONE_UA, IPADOS_UA, ANDROID_UA, DESKTOP_UA]) {
        if (cold) h.cache.entries.clear();
        const before = h.state.reads.length;
        const response = await worker.fetch(new Request(`https://${host}/wallpaper/W1`, {
          headers: { 'user-agent': ua },
        }), h.env, ctx);
        assert.equal(response.status, 200);
        assert.equal(await response.text(), expected);
        await h.flush();
        assert.equal(h.state.reads.length - before, cold ? 2 : 0);
      }
    }
  }
});

test('host, request headers, and unrelated queries cannot alter the cached page body', async (t) => {
  const h = setup(t);
  const first = await h.get('/wallpaper/W1');
  const expected = await first.text();
  await h.flush();

  const request = new Request('https://attacker.example/wallpaper/W1?utm_source=changed', {
    headers: { 'user-agent': 'Crawler/1.0', accept: 'application/xml', referer: 'https://attacker.example/' },
  });
  const response = await worker.fetch(request, h.env, { waitUntil(promise) { h.state.pending.push(promise); } });
  assert.equal(await response.text(), expected);
});

test('stale entries are served once while a background refresh runs, then a gone wall reaches clients', async (t) => {
  const clock = stubClock(t);
  const h = setup(t);

  const first = await h.get('/wallpaper/W1');
  const liveBody = await first.text();
  await h.flush();

  clock.advance(700);
  const readsBeforeStale = h.state.reads.length;
  const stale = await h.get('/wallpaper/W1');
  const staleBody = await stale.text();
  await h.flush();
  assert.equal(staleBody, liveBody);
  assert.ok(h.state.reads.length > readsBeforeStale, 'a background revalidation read Firestore');

  h.state.docs['webWalls/W1'] = { state: 'gone', updatedAt: 'y' };
  clock.advance(700);
  const serveStale = await h.get('/wallpaper/W1');
  await serveStale.text();
  await h.flush();
  assert.equal(serveStale.status, 200);

  const gone = await h.get('/wallpaper/W1');
  await gone.text();
  await h.flush();
  assert.equal(gone.status, 410);
});

test('wall and desktop cache entries expire after the stale window when Firestore is unavailable', async (t) => {
  const clock = stubClock(t);
  const h = setup(t);
  const paths = ['/wallpaper/W1', '/wallpaper/DW1?view=desktop'];
  for (const path of paths) {
    const first = await h.get(path);
    assert.equal(first.status, 200, path);
    await first.text();
  }
  await h.flush();

  h.state.firestoreStatus = 503;
  clock.advance(600 + 86400 - 1);
  for (const path of paths) {
    const lastStaleSecond = await h.get(path);
    await lastStaleSecond.text();
    assert.equal(lastStaleSecond.headers.get('cache-control'), 'public, max-age=0, stale-while-revalidate=1', path);
  }
  await h.flush();

  clock.advance(2);
  for (const [path, oldTitle, expectedStatus] of [
    ['/wallpaper/W1', 'Sunset Ridge', 200], ['/wallpaper/DW1?view=desktop', 'Desk Dawn', 302],
  ]) {
    const expired = await h.get(path);
    const body = await expired.text();
    assert.equal(expired.status, expectedStatus, path);
    assert.ok(!body.includes(oldTitle), `${path} must not serve the expired cached page`);
  }
  await h.flush();
});

test('concurrent stale hits share one background refresh per cache key', async (t) => {
  const clock = stubClock(t);
  const h = setup(t);
  await (await h.get('/wallpaper/W1')).text();
  await h.flush();
  clock.advance(700);

  let release;
  h.state.firestoreGate = new Promise((resolve) => { release = resolve; });
  const before = h.state.reads.length;
  const responses = await Promise.all(Array.from({ length: 5 }, () => h.get('/wallpaper/W1')));
  for (const response of responses) await response.text();

  h.state.firestoreGate = null;
  release();
  await h.flush();
  assert.equal(h.state.reads.length - before, 2, 'one wall render reads wall and related page once');
});

test('a Firestore outage keeps the old landing for walls and answers 503 for hubs', async (t) => {
  const h = setup(t, { firestoreStatus: 500 });

  const wall = await h.get('/wallpaper/W1', ANDROID_UA);
  const wallBody = await wall.text();
  assert.equal(wall.status, 200);
  assert.ok(wallBody.includes('Open in Prism'));
  assert.ok(wallBody.includes('noindex,nofollow'));
  assert.ok(wall.headers.get('cache-control').includes('no-store'));

  const hub = await h.get('/wallpapers');
  await hub.text();
  assert.equal(hub.status, 503);
  assert.equal(hub.headers.get('cache-control'), 'no-store');

  const head = await worker.fetch(
    new Request('https://prismwalls.com/wallpaper/W1', { method: 'HEAD', headers: { 'user-agent': ANDROID_UA } }),
    h.env,
    { waitUntil(promise) { h.state.pending.push(promise); } },
  );
  assert.equal(head.status, 200);
  assert.equal(await head.text(), '');
});

test('invalid Firestore JSON is a no-store outage response and is not cached', async (t) => {
  const h = setup(t);
  h.state.invalidFirestoreJson = true;
  const response = await h.get('/wallpapers');
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  await response.text();
  await h.flush();
  assert.equal(h.cache.entries.size, 0);
});

test('hubs render with pagination, redirect page=1, and reject bad page numbers', async (t) => {
  const h = setup(t);

  const latest = await h.get('/wallpapers');
  const latestBody = await latest.text();
  assert.equal(latest.status, 200);
  assert.ok(latestBody.includes('<h1>New wallpapers</h1>'));
  assert.ok(latestBody.includes('<link rel="next" href="https://prismwalls.com/wallpapers?page=2">'));
  assert.ok(latestBody.includes('href="/wallpapers?page=2"'));

  const pageOne = await h.get('/wallpapers?page=1');
  await pageOne.text();
  assert.equal(pageOne.status, 301);
  assert.equal(pageOne.headers.get('location'), 'https://prismwalls.com/wallpapers');

  const bad = await h.get('/wallpapers?page=abc');
  await bad.text();
  assert.equal(bad.status, 404);

  const nature = await h.get('/wallpapers/nature');
  const natureBody = await nature.text();
  assert.equal(nature.status, 200);
  assert.ok(natureBody.includes('<h1>Nature wallpapers</h1>'));
  assert.ok(natureBody.includes('<link rel="canonical" href="https://prismwalls.com/wallpapers/nature">'));

  const missingPage = await h.get('/wallpapers/nature?page=2');
  await missingPage.text();
  assert.equal(missingPage.status, 404);
});

test('invalid catalogue routes cache their 404 while page-one redirects bypass the cache', async (t) => {
  const h = setup(t);
  const bad = await h.get('/wallpapers?page=bad');
  assert.equal(bad.status, 404);
  assert.equal(bad.headers.get('cache-control'), 'public, max-age=300');
  await bad.text();
  await h.flush();
  const count = h.cache.entries.size;
  const again = await h.get('/wallpapers?page=other');
  assert.equal(again.status, 404);
  await again.text();
  await h.flush();
  assert.equal(h.cache.entries.size, count);
  assert.equal(h.state.reads.length, 0);

  const redirect = await h.get('/wallpapers?page=1');
  assert.equal(redirect.status, 301);
  assert.equal(redirect.headers.get('cache-control'), null);
  await redirect.text();
  await h.flush();
  assert.equal(h.cache.entries.size, count);
});

test('creator page looks up the lower-case username and renders the profile', async (t) => {
  const h = setup(t);

  const response = await h.get('/creator/Sam');
  const body = await response.text();
  assert.equal(response.status, 200);
  assert.match(body, /<title>Sam K \(@sam\)[^<]*<\/title>/);
  assert.ok(body.includes('I make calm walls'));
  assert.ok(ldJson(body).some((entry) => entry['@type'] === 'ProfilePage'));
  assert.ok(body.includes('href="https://prismwalls.com/user/sam"'));

  const missing = await h.get('/creator/nobody');
  await missing.text();
  assert.equal(missing.status, 404);
});

test('sitemaps list the page sitemap and each wall sitemap with its lastmod', async (t) => {
  const h = setup(t);

  const index = await h.get('/sitemap.xml');
  const indexBody = await index.text();
  assert.equal(index.status, 200);
  assert.match(index.headers.get('content-type'), /^application\/xml/);
  assert.ok(indexBody.includes('<loc>https://prismwalls.com/sitemap-pages.xml</loc>'));
  assert.ok(indexBody.includes('<loc>https://prismwalls.com/sitemaps/walls-1.xml</loc><lastmod>2026-10-30T00:00:00.000Z</lastmod>'));
  assert.ok(indexBody.includes('<loc>https://prismwalls.com/sitemaps/walls-2.xml</loc>'));

  const walls = await h.get('/sitemaps/walls-1.xml');
  const wallsBody = await walls.text();
  assert.equal(walls.status, 200);
  assert.equal(wallsBody.match(/<url>/g)?.length, 2);
  assert.ok(wallsBody.includes('<loc>https://prismwalls.com/wallpaper/W1</loc><lastmod>2026-10-30T00:00:00.000Z</lastmod>'));

  const missing = await h.get('/sitemaps/walls-9.xml');
  await missing.text();
  assert.equal(missing.status, 404);
});

test('wall text is escaped in HTML and JSON-LD and sitemap entries cannot break XML', async (t) => {
  const h = setup(t);
  h.state.docs['webWalls/W1'].title = '</script><script>HTML-XSS</script> & "title"';
  const wallBody = await (await h.get('/wallpaper/W1')).text();
  assert.ok(wallBody.includes('&lt;/script&gt;&lt;script&gt;HTML-XSS&lt;/script&gt;'));
  assert.ok(wallBody.includes('\\u003c/script>\\u003cscript>HTML-XSS\\u003c/script>'));
  assert.doesNotMatch(wallBody, /<script>HTML-XSS/);

  h.state.docs['webPages/sitemap~walls-1'].entries = '/wallpaper/W1</loc><script>XML-XSS</script>\t2026-10-30';
  const sitemapBody = await (await h.get('/sitemaps/walls-1.xml')).text();
  assert.ok(sitemapBody.includes('&lt;/loc&gt;&lt;script&gt;XML-XSS&lt;/script&gt;'));
  assert.doesNotMatch(sitemapBody, /<script>XML-XSS/);
});

test('public pages expose no private fields, and unknown stored fields are never printed', async (t) => {
  const h = setup(t);
  h.state.docs['webWalls/W1'].secretField = 'LEAK-123';
  h.state.docs['webPages/creator~sam~1'].creator.email = 'leak@example.com';
  const forbidden = /creatorUid|ownerId|"uid"|email|@example\.com|wallpaper_url|originalProtected|blurKey/i;
  const paths = ['/wallpaper/W1', '/wallpaper/G1', '/folder/F1', '/creator/sam', '/wallpapers', '/sitemap.xml'];

  for (const path of paths) {
    const body = await (await h.get(path)).text();
    assert.doesNotMatch(body, forbidden, path);
    assert.ok(!body.includes('LEAK-123'), path);
    assert.ok(!body.includes('leak@example.com'), path);
  }
});

for (const [name, malformed, leak] of [
  ['title map', { title: { uid: 'TITLE-UID-LEAK' } }, 'TITLE-UID-LEAK'],
  ['width injection', { width: '1\" onload=\"WIDTH-HTML-LEAK' }, 'WIDTH-HTML-LEAK'],
  ['createdAt map', { createdAt: { uid: 'DATE-UID-LEAK' } }, 'DATE-UID-LEAK'],
]) {
  test(`malformed wall ${name} is not printed or cached`, async (t) => {
    const h = setup(t);
    Object.assign(h.state.docs['webWalls/W1'], malformed);
    const response = await h.get('/wallpaper/W1');
    const body = await response.text();
    assert.doesNotMatch(body, new RegExp(leak));
    await h.flush();
    assert.equal(h.cache.entries.size, 0);
  });
}

test('unknown nested wall fields are ignored without rejecting the public projection', async (t) => {
  const h = setup(t);
  h.state.docs['webWalls/W1'].creator.uid = 'CREATOR-UID-LEAK';
  h.state.docs['webPages/creator~sam~1'].items[0].uid = 'CARD-UID-LEAK';

  const response = await h.get('/wallpaper/W1');
  const body = await response.text();
  assert.equal(response.status, 200);
  assert.doesNotMatch(body, /CREATOR-UID-LEAK/);
  const creator = await (await h.get('/creator/sam')).text();
  assert.doesNotMatch(creator, /CARD-UID-LEAK/);
});

for (const thumb of [
  'https://private.example/original.jpg',
  'https://img.prismwalls.com:8443/previews/aaa.img',
  'https://img.prismwalls.com/previews/aaa.img?token=secret',
  'https://img.prismwalls.com/previews/aaa.img#private',
  'https://img.prismwalls.com/previews/a%2F..%2Foriginal.img',
]) {
  test(`live wall rejects unsafe preview URL ${thumb}`, async (t) => {
    const h = setup(t);
    h.state.docs['webWalls/W1'].thumb = thumb;

    const response = await h.get('/wallpaper/W1');
    const body = await response.text();
    assert.equal(response.status, 200);
    assert.doesNotMatch(body, /private\.example|8443|token=secret|#private|original\.img/);
    assert.equal(h.state.previewCalls.length, 0);

    const preview = await h.get('/api/catalog/preview/W1.jpg');
    assert.equal(preview.status, 404);
    assert.equal(h.state.previewCalls.length, 0);

    const og = await h.get('/og/wall/W1.jpg');
    assert.equal(og.status, 302);
    assert.equal(og.headers.get('location'), h.env.OG_FALLBACK_IMAGE);
  });
}

test('preview URL validation follows the configured R2 preview origin and path', async (t) => {
  const h = setup(t);
  h.env.R2_PREVIEW_BASE_URL = 'https://cdn.example/media';
  h.state.docs['webWalls/W1'].thumb = 'https://cdn.example/media/previews/aaa.img';

  const response = await h.get('/og/wall/W1.jpg');
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('location'), h.state.docs['webWalls/W1'].thumb);
});

test('existing share, short link and non-catalogue routes are unchanged and make no catalogue reads', async (t) => {
  const h = setup(t);

  const share = await h.get('/share?id=wall-1&source=prism', ANDROID_UA);
  const shareBody = await share.text();
  assert.equal(share.status, 200);
  assert.ok(shareBody.includes('Get it on Google Play'));
  assert.match(shareBody, /intent:\/\/prismwalls\.com\/share\?/);

  const wallhaven = await h.get('/wallpaper/W1?source=wallhaven');
  assert.equal(wallhaven.status, 200);
  assert.ok((await wallhaven.text()).includes('noindex,nofollow'));

  const position = await h.get('/wallpaper/W1/position');
  await position.text();
  assert.equal(position.status, 200);

  const shortLink = await h.get('/l/AbCdEfG', ANDROID_UA);
  const shortBody = await shortLink.text();
  assert.equal(shortLink.status, 404);
  assert.ok(shortBody.includes('This link is no longer available'));

  assert.equal(h.state.reads.length, 0);
});

test('preview image streams the wallpaperPreview derivative and falls back to the thumb', async (t) => {
  const h = setup(t);

  const preview = await h.get('/api/catalog/preview/W1.jpg');
  assert.equal(preview.status, 200);
  assert.equal(preview.headers.get('content-type'), 'image/jpeg');
  assert.deepEqual([...new Uint8Array(await preview.arrayBuffer())], [1, 2, 3]);
  assert.equal(h.state.previewCalls.length, 1);
  const called = new URL(h.state.previewCalls[0]);
  assert.equal(called.origin + called.pathname, PREVIEW_PREFIX);
  assert.equal(called.searchParams.get('id'), 'W1');
  assert.equal(called.searchParams.get('thumb'), THUMB);

  const gated = await h.get('/api/catalog/preview/G1.jpg');
  await gated.text();
  assert.equal(gated.status, 404);
  assert.equal(h.state.previewCalls.length, 1, 'the function was not called for G1');
});

test('preview falls back to a redirect to the thumb when the function returns 404', async (t) => {
  const h = setup(t);
  h.state.previewStatus = 404;

  const response = await h.get('/api/catalog/preview/W1.jpg');
  await response.text();
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('location'), THUMB);
});

test('HEAD on a wall returns 200 with an empty body', async (t) => {
  const h = setup(t);
  const response = await worker.fetch(
    new Request('https://prismwalls.com/wallpaper/W1', { method: 'HEAD', headers: { 'user-agent': DESKTOP_UA } }),
    h.env,
    { waitUntil(promise) { h.state.pending.push(promise); } },
  );
  assert.equal(response.status, 200);
  assert.equal(await response.text(), '');
});

test('desktop mode leads with the monitor and puts the phone beside it, with a Download 1920 × 1200 button', async (t) => {
  const h = setup(t);
  const response = await h.get('/wallpaper/DW1?view=desktop');
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(body, /<main class="wall-layout desktop-mode" data-mode="desktop">/);
  const desktopAt = body.indexOf('/api/catalog/desktop/DW1.jpg?v=');
  const phoneAt = body.indexOf('src="/api/catalog/preview/DW1.jpg"');
  assert.ok(desktopAt > 0 && phoneAt > desktopAt, 'the desktop monitor comes before the phone preview');
  assert.ok(body.includes('Download 1920 × 1200'));
  assert.ok(body.includes('href="/api/catalog/download/DW1/desktop.jpg"'));
  assert.ok(body.includes('The full 2560 × 1600 desktop file is in Prism.'));
  assert.ok(!body.includes('role="tablist"'));
  assert.ok(body.includes('<link rel="canonical" href="https://prismwalls.com/wallpaper/DW1">'));
});

test('desktop mode without a desktop companion shows the phone file and set-as-background steps', async (t) => {
  const h = setup(t);
  const body = await (await h.get('/wallpaper/W1?view=desktop')).text();

  assert.match(body, /<main class="wall-layout" data-mode="desktop">/);
  assert.ok(body.includes('Use it on your computer'));
  assert.ok(body.includes('Set as desktop background'));
  assert.ok(body.includes('src="/api/catalog/preview/W1.jpg"'));
  assert.ok(!body.includes('/api/catalog/desktop/'));
});

test('desktop mode keeps the gated page and answers hidden walls with 404', async (t) => {
  const h = setup(t);
  const gated = await (await h.get('/wallpaper/G1?view=desktop')).text();

  assert.ok(gated.includes('Get it in Prism'));
  assert.ok(!gated.includes('/api/catalog/preview/'));
  assert.ok(!gated.includes('/api/catalog/desktop/'));
  assert.ok(!gated.includes('/api/catalog/download/'));
  assert.ok(!gated.includes('data-mode="desktop"'));

  const hidden = await h.get('/wallpaper/H1?view=desktop');
  await hidden.text();
  assert.equal(hidden.status, 404);
});

test('desktop mode reads the same two documents once, and its own cache entry serves the page after that', async (t) => {
  const h = setup(t);
  const cold = await h.get('/wallpaper/DW1?view=desktop');
  await cold.text();
  await h.flush();
  assert.equal(cold.status, 200);
  assert.equal(h.state.reads.length, 2);
  assert.ok(h.state.reads[0].endsWith('/webWalls/DW1'));
  assert.ok(h.state.reads[1].endsWith('/webPages/category~nature~1'));

  const warm = await h.get('/wallpaper/DW1?view=desktop');
  await warm.text();
  await h.flush();
  assert.equal(h.state.reads.length, 2);

  const sameEntry = await h.get('/wallpaper/DW1?view=desktop&utm_source=x');
  await sameEntry.text();
  await h.flush();
  assert.equal(h.state.reads.length, 2);

  const normal = await h.get('/wallpaper/DW1');
  const normalBody = await normal.text();
  await h.flush();
  assert.equal(h.state.reads.length, 4);
  assert.ok(normalBody.includes('role="tablist"'));
  assert.ok(!normalBody.includes('data-mode="desktop"'));

  const phoneView = await (await h.get('/wallpaper/DW1?view=phone')).text();
  await h.flush();
  assert.equal(h.state.reads.length, 4);
  assert.ok(phoneView.includes('role="tablist"'));
  assert.ok(!phoneView.includes('data-mode="desktop"'));
});
