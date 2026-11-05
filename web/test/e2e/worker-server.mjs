import http from 'node:http';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import worker from '../../../infra/cloudflare/worker/src/index.ts';

const PORT = Number(process.env.PORT ?? 3108);
const SITE = 'https://prismwalls.com';
const FIRESTORE_PREFIX = 'https://firestore.googleapis.com/v1/projects/prism-test/databases/(default)/documents/';
const PREVIEW_PREFIX = 'https://us-central1-prism-test.cloudfunctions.net/wallpaperPreview';
const THUMB = 'https://img.prismwalls.com/previews/aaa.img';
const DESKTOP_THUMB = 'https://img.prismwalls.com/previews/desktop-dw1.jpg';
const JPEG = Buffer.from('/9j/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAAIAAgDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAABf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AJwBUc//2Q==', 'base64');
const SKIPPED_REQUEST_HEADERS = new Set(['host', 'connection', 'keep-alive', 'transfer-encoding', 'content-length']);

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
  return { id, title, thumb: 'https://img.prismwalls.com/previews/x.img', width: 1440, height: 3200 };
}

function seedDocs() {
  const creator = { username: 'mira', name: 'Mira' };
  const updatedAt = '2026-10-30T00:00:00.000Z';
  return {
    'webWalls/DW1': {
      state: 'live',
      updatedAt,
      title: 'Aurora Ridge',
      category: 'Nature',
      categorySlug: 'nature',
      width: 1440,
      height: 3200,
      createdAt: '2026-10-01T00:00:00.000Z',
      creatorName: 'Mira',
      creator,
      thumb: THUMB,
      desktop: { v: '0123456789abcdef', thumb: DESKTOP_THUMB, width: 2560, height: 1600 },
    },
    'webWalls/W1': {
      state: 'live',
      updatedAt,
      title: 'Sunset Ridge',
      category: 'Nature',
      categorySlug: 'nature',
      width: 1440,
      height: 3200,
      createdAt: '2026-10-01T00:00:00.000Z',
      creatorName: 'Mira',
      creator,
      thumb: THUMB,
    },
    'webWalls/G1': {
      state: 'gated',
      updatedAt,
      title: 'Locked Dawn',
      category: 'Space',
      categorySlug: 'space',
      width: 1440,
      height: 3200,
      creatorName: 'Mira',
      creator,
      blur: `data:image/jpeg;base64,${JPEG.toString('base64')}`,
    },
    'webPages/category~nature~1': {
      kind: 'category',
      slug: 'nature',
      name: 'Nature',
      page: 1,
      pages: 1,
      total: 4,
      items: [card('DW1', 'Aurora Ridge'), card('W1', 'Sunset Ridge'), card('N2', 'Nature 2'), card('N3', 'Nature 3')],
      categories: [{ slug: 'nature', name: 'Nature', count: 4 }],
    },
  };
}

const docs = seedDocs();
const env = {
  LINKS_KV: new MemoryKv(),
  AI_STATE_KV: new MemoryKv(),
  FIREBASE_PROJECT_ID: 'prism-test',
  PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
  APP_STORE_URL: 'https://apps.apple.com/app/id6670200846',
  OG_FALLBACK_IMAGE: 'https://prismwalls.com/assets/og/home.jpg',
  R2_PREVIEW_BASE_URL: 'https://img.prismwalls.com',
};
const ctx = {
  waitUntil(promise) {
    Promise.resolve(promise).catch(() => {});
  },
  passThroughOnException() {},
};

globalThis.caches = undefined;
globalThis.fetch = async (input) => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  if (url.startsWith(FIRESTORE_PREFIX)) {
    const path = url.slice(FIRESTORE_PREFIX.length).split('?')[0].split('/').map((segment) => decodeURIComponent(segment)).join('/');
    if (!Object.hasOwn(docs, path)) return new Response('{}', { status: 404, headers: { 'content-type': 'application/json' } });
    return Response.json({ fields: encodeFields(docs[path]) });
  }
  if (url.startsWith(PREVIEW_PREFIX)) {
    return new Response(JPEG, { status: 200, headers: { 'content-type': 'image/jpeg' } });
  }
  return new Response('Not found', { status: 404 });
};

async function createShareCodes() {
  const codes = {};
  for (const id of ['DW1', 'W1']) {
    const response = await worker.fetch(new Request(`${SITE}/api/links`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'CF-Connecting-IP': '203.0.113.9' },
      body: JSON.stringify({ type: 'share', payload: { id, source: 'prism', provider: 'Prism' } }),
    }), env, ctx);
    if (response.status !== 201) throw new Error(`POST /api/links for ${id} returned ${response.status}`);
    codes[id] = (await response.json()).code;
  }
  return codes;
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks);
}

function sendJson(res, status, value) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(value));
}

const codes = await createShareCodes();

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', 'http://127.0.0.1');
    if (req.method === 'GET' && url.pathname === '/__codes') return sendJson(res, 200, codes);
    if (req.method === 'GET' && url.pathname === '/__preview.jpg') {
      res.writeHead(200, { 'content-type': 'image/jpeg' });
      return res.end(JPEG);
    }

    const headers = new Headers();
    for (const [name, value] of Object.entries(req.headers)) {
      if (typeof value === 'string' && !SKIPPED_REQUEST_HEADERS.has(name)) headers.set(name, value);
    }
    const body = req.method === 'GET' || req.method === 'HEAD' ? undefined : await readBody(req);
    const request = new Request(`${SITE}${url.pathname}${url.search}`, { method: req.method, headers, body });
    const response = await worker.fetch(request, env, ctx);

    const outHeaders = {};
    for (const [name, value] of response.headers) {
      if (name !== 'set-cookie') outHeaders[name] = value;
    }
    const cookies = response.headers.getSetCookie();
    if (cookies.length > 0) outHeaders['set-cookie'] = cookies;
    res.writeHead(response.status, outHeaders);
    if (response.body == null || req.method === 'HEAD') return res.end();
    await pipeline(Readable.fromWeb(response.body), res);
  } catch (error) {
    if (!res.headersSent) res.writeHead(500, { 'content-type': 'text/plain' });
    res.end(String(error?.stack ?? error));
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`worker-server listening on ${PORT}`);
});
