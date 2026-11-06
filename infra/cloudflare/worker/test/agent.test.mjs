import assert from 'node:assert/strict';
import { test } from 'node:test';
import worker from '../src/index.ts';

const FIRESTORE_PREFIX = 'https://firestore.googleapis.com/v1/projects/prism-test/databases/(default)/documents/';

function encode(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === 'object') return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, child]) => [key, encode(child)])) } };
  throw new Error(`Unsupported fixture value: ${value}`);
}

function setup(t) {
  const originalFetch = globalThis.fetch;
  const docs = {
    'webPages/latest~1': {
      kind: 'latest', page: 1, pages: 3, total: 1,
      items: [{ id: 'W1', title: 'Sunset Ridge', thumb: 'https://img.prismwalls.com/sunset.jpg', width: 1080, height: 2340 }],
      categories: [{ slug: 'nature', name: 'Nature', count: 17 }],
    },
    'webWalls/W1': {
      state: 'live', title: 'Sunset Ridge', description: 'Golden mountains', category: 'Nature', categorySlug: 'nature',
      tags: ['sunset', 'mountain'], colors: [{ name: 'orange', hex: '#ff6600' }], width: 1080, height: 2340,
      createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-02T00:00:00.000Z', creatorName: 'Sam K',
      creator: { username: 'sam', name: 'Sam K' }, thumb: 'https://img.prismwalls.com/sunset.jpg',
      email: 'private@example.com', uid: 'private-user-id', originalUrl: 'https://private.example/original.jpg',
    },
  };
  globalThis.fetch = async (input) => {
    const target = typeof input === 'string' ? input : input.url;
    if (!target.startsWith(FIRESTORE_PREFIX)) return new Response('', { status: 404 });
    const path = target.slice(FIRESTORE_PREFIX.length).split('/').map(decodeURIComponent).join('/');
    if (!Object.hasOwn(docs, path)) return new Response('{}', { status: 404 });
    const fields = Object.fromEntries(Object.entries(docs[path]).map(([key, value]) => [key, encode(value)]));
    return Response.json({ fields });
  };
  t.after(() => { globalThis.fetch = originalFetch; });
  const env = { LINKS_KV: { get: async () => null }, AI_STATE_KV: { get: async () => null }, FIREBASE_PROJECT_ID: 'prism-test', PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism', APP_STORE_URL: 'https://apps.apple.com/app/id1499765773' };
  const ctx = { waitUntil() {} };
  return {
    docs,
    async get(path) { return worker.fetch(new Request(`https://prismwalls.com${path}`), env, ctx); },
    async post(path, payload, headers = {}) {
      return worker.fetch(new Request(`https://prismwalls.com${path}`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(payload) }), env, ctx);
    },
  };
}

test('OpenAPI document describes the Prism API and agent operations', async (t) => {
  const h = setup(t);
  const response = await h.get('/openapi.json');
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assert.equal(body.openapi, '3.1.0');
  assert.equal(body.info.title, 'Prism Wallpapers API');
  assert.equal(body.paths['/api/v1/wallpapers'].get.operationId, 'listWallpapers');
  assert.equal(body.paths['/ask'].post.operationId, 'askWallpapers');
  assert.equal(body.paths['/mcp/docs'].post.operationId, 'mcpDocs');
  assert.equal(body.paths['/api/v1/wallpapers'].get.parameters[0].name, 'page');
  assert.equal(body.paths['/api/v1/wallpapers'].get.responses['200'].content['application/json'].schema.type, 'object');
});

test('unknown API paths return the JSON error envelope', async (t) => {
  const h = setup(t);
  const response = await h.get('/api/v1/does-not-exist');
  assert.equal(response.status, 404);
  assert.equal(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assert.deepEqual(await response.json(), { error: { code: 'not_found', message: 'API endpoint not found.', hint: 'See /openapi.json for supported endpoints.' } });
});

test('current-agent endpoint requires bearer auth and advertises resource metadata', async (t) => {
  const h = setup(t);
  const response = await h.get('/api/v1/me');
  assert.equal(response.status, 401);
  assert.equal(response.headers.get('www-authenticate'), 'Bearer resource_metadata="https://prismwalls.com/.well-known/oauth-protected-resource"');
  assert.deepEqual(await response.json(), { error: { code: 'unauthorized', message: 'Authentication is required.', hint: 'Agent authentication is not available. Public catalogue endpoints need no authentication.' } });
});

test('wallpaper list reads public Firestore projections and strips private fields', async (t) => {
  const h = setup(t);
  const response = await h.get('/api/v1/wallpapers');
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.data[0].id, 'W1');
  assert.equal(body.data[0].title, 'Sunset Ridge');
  assert.equal(body.data[0].categorySlug, 'nature');
  assert.deepEqual(body.data[0].tags, ['sunset', 'mountain']);
  assert.equal(body.data[0].thumb, 'https://img.prismwalls.com/sunset.jpg');
  assert.equal(body.data[0].url, 'https://prismwalls.com/wallpaper/W1');
  assert.equal(body.data[0].creator.name, 'Sam K');
  assert.equal(Object.hasOwn(body.data[0], 'email'), false);
  assert.equal(Object.hasOwn(body.data[0], 'uid'), false);
  assert.equal(Object.hasOwn(body.data[0], 'originalUrl'), false);
  assert.equal(body.page, 1);
  assert.equal(body.pages, 3);
  assert.equal(body.total, 1);
});

test('MCP initialize, tools list and wallpaper tool calls follow JSON-RPC', async (t) => {
  const h = setup(t);
  const initialized = await (await h.post('/mcp', { jsonrpc: '2.0', id: 1, method: 'initialize', params: {} })).json();
  assert.equal(initialized.result.protocolVersion, '2025-03-26');
  assert.deepEqual(initialized.result.capabilities, { tools: {}, resources: {} });
  const listed = await (await h.post('/mcp', { jsonrpc: '2.0', id: 2, method: 'tools/list' })).json();
  assert.equal(listed.result.tools[0].name, 'search_wallpapers');
  assert.equal(listed.result.tools[1].name, 'get_wallpaper');
  assert.equal(listed.result.tools[1]._meta.ui.resourceUri, 'ui://prism/wallpaper-card');
  const called = await (await h.post('/mcp', { jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'get_wallpaper', arguments: { id: 'W1' } } })).json();
  const wall = JSON.parse(called.result.content[0].text);
  assert.equal(wall.title, 'Sunset Ridge');
  assert.equal(wall.thumb, 'https://img.prismwalls.com/sunset.jpg');
  assert.equal(called.result._meta.ui.resourceUri, 'ui://prism/wallpaper-card');
});

test('MCP discovery does not advertise unimplemented authentication or signing keys', async (t) => {
  const h = setup(t);
  const cardResponse = await h.get('/.well-known/mcp/server-card.json');
  const card = await cardResponse.json();
  assert.equal(card.$schema, 'https://static.modelcontextprotocol.io/schemas/v1/server-card.schema.json');
  assert.equal(card.name, 'com.prismwalls/mcp');
  assert.equal(card.remotes[0].type, 'streamable-http');
  assert.equal(card.remotes[0].url, 'https://prismwalls.com/mcp');
  const authResponse = await h.get('/.well-known/oauth-authorization-server');
  const auth = await authResponse.json();
  assert.equal(authResponse.status, 200);
  assert.equal(auth.issuer, 'https://prismwalls.com');
  assert.equal(auth.agent_auth.identity_endpoint, 'https://prismwalls.com/agent/identity');
  assert.deepEqual(auth.agent_auth.identity_types_supported, ['anonymous']);
  const resource = await (await h.get('/.well-known/oauth-protected-resource')).json();
  assert.deepEqual(resource.authorization_servers, ['https://prismwalls.com']);
  assert.deepEqual(await (await h.get('/.well-known/http-message-signatures-directory')).json(), { keys: [] });
});

test('NLWeb returns wallpaper results and supports event-stream responses', async (t) => {
  const h = setup(t);
  const ordinary = await h.post('/ask', { query: { text: 'sunset' } });
  const body = await ordinary.json();
  assert.equal(ordinary.status, 200);
  assert.deepEqual(body._meta, { response_type: 'answer', version: '0.55' });
  assert.equal(body.results[0].name, 'Sunset Ridge');
  assert.equal(body.results[0].url, 'https://prismwalls.com/wallpaper/W1');
  const streamed = await h.post('/ask', { query: 'sunset', prefer: { streaming: true } });
  const events = await streamed.text();
  assert.equal(streamed.headers.get('content-type'), 'text/event-stream; charset=utf-8');
  assert.ok(events.startsWith('event: start\n'));
  assert.ok(events.includes('event: result\ndata: {"name":"Sunset Ridge"'));
  assert.ok(events.endsWith('event: complete\ndata: {}\n\n'));
  const invalid = await h.post('/ask', null);
  assert.equal(invalid.status, 400);
  assert.deepEqual(await invalid.json(), { error: { code: 'invalid_body', message: 'Request body must be a JSON object.', hint: 'Send query.text as a string.' } });
});

test('public fields are allowlisted recursively and gated desktop previews are omitted', async (t) => {
  const h = setup(t);
  Object.assign(h.docs['webWalls/W1'].creator, { email: 'private@example.com', uid: 'secret' });
  h.docs['webWalls/W1'].desktop = { v: '1', thumb: 'https://img.prismwalls.com/desktop.jpg', width: 1920, height: 1080, wallpaper_url: 'private', storagePath: 'secret' };
  h.docs['webWalls/W1'].colors[0].uid = 'secret';
  h.docs['webPages/latest~1'].categories[0].email = 'private@example.com';
  const detail = (await (await h.get('/api/v1/wallpapers/W1')).json()).data;
  assert.deepEqual(detail.creator, { username: 'sam', name: 'Sam K' });
  assert.deepEqual(detail.desktop, { v: '1', thumb: 'https://img.prismwalls.com/desktop.jpg', width: 1920, height: 1080 });
  assert.deepEqual(detail.colors, [{ name: 'orange', hex: '#ff6600' }]);
  assert.deepEqual((await (await h.get('/api/v1/categories')).json()).data, [{ slug: 'nature', name: 'Nature', count: 17 }]);
  h.docs['webWalls/W1'].state = 'gated';
  const gated = (await (await h.get('/api/v1/wallpapers/W1')).json()).data;
  assert.equal(Object.hasOwn(gated, 'thumb'), false);
  assert.equal(Object.hasOwn(gated, 'desktop'), false);
  assert.equal(Object.hasOwn((await (await h.get('/api/v1/wallpapers')).json()).data[0], 'thumb'), false);
});

test('MCP and category inputs cannot escape public projection documents', async (t) => {
  const h = setup(t);
  const originalFetch = globalThis.fetch;
  let reads = 0;
  globalThis.fetch = async (...args) => { reads++; return originalFetch(...args); };
  for (const id of ['../users/private', 'W1/secret', '']) {
    const rpc = await (await h.post('/mcp', { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'get_wallpaper', arguments: { id } } })).json();
    assert.equal(rpc.error.code, -32602);
  }
  assert.equal((await h.get('/api/v1/wallpapers?category=..%2F..%2Fusers')).status, 400);
  assert.equal(reads, 0);
});

test('MCP notifications and batches follow JSON-RPC transport semantics', async (t) => {
  const h = setup(t);
  const notification = await h.post('/mcp', { jsonrpc: '2.0', method: 'notifications/initialized' });
  assert.equal(notification.status, 202);
  assert.equal(await notification.text(), '');
  const mixed = await (await h.post('/mcp', [{ jsonrpc: '2.0', method: 'notifications/initialized' }, { jsonrpc: '2.0', id: 0, method: 'ping' }])).json();
  assert.deepEqual(mixed, [{ jsonrpc: '2.0', id: 0, result: {} }]);
  for (const rpc of [{ jsonrpc: '2.0', id: {}, method: 'ping' }, { jsonrpc: '2.0', id: 1, method: 'ping', params: 'bad' }]) {
    const response = await (await h.post('/mcp', rpc)).json();
    assert.equal(response.error.code, -32600);
    assert.equal(response.id, null);
  }
  const badArgs = await (await h.post('/mcp', { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'search_wallpapers', arguments: { q: {} } } })).json();
  assert.equal(badArgs.error.code, -32602);
  assert.equal((await h.post('/mcp', { jsonrpc: '2.0', id: 1, method: 'ping' }, { origin: 'https://evil.example' })).status, 403);
});

test('NLWeb rejects non-string queries with a JSON client error', async (t) => {
  const h = setup(t);
  for (const query of [{ text: 1 }, { text: {} }, 3, []]) {
    const response = await h.post('/ask', { query });
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, 'invalid_query');
  }
});

test('popular and search pagination report the page actually read', async (t) => {
  const h = setup(t);
  h.docs['webPages/popular~2'] = { items: [{ id: 'W1' }], page: 2, pages: 2, total: 2 };
  const popular = await (await h.get('/api/v1/wallpapers?sort=popular&page=2')).json();
  assert.equal(popular.page, 2);
  assert.equal(popular.data[0].id, 'W1');
  const search = await (await h.get('/api/v1/wallpapers?q=sunset&page=3')).json();
  assert.equal(search.page, 1);
});

test('OpenAPI response schemas describe sandbox and nullable detail thumbnails', async (t) => {
  const h = setup(t);
  const spec = await (await h.get('/openapi.json')).json();
  const sandboxSchema = spec.paths['/api/v1/sandbox/wallpapers'].get.responses['200'].content['application/json'].schema;
  const sandbox = await (await h.get('/api/v1/sandbox/wallpapers')).json();
  for (const key of sandboxSchema.required) assert.ok(Object.hasOwn(sandbox, key), key);
  delete h.docs['webWalls/W1'].thumb;
  const detail = (await (await h.get('/api/v1/wallpapers/W1')).json()).data;
  const detailSchema = spec.paths['/api/v1/wallpapers/{id}'].get.responses['200'].content['application/json'].schema.properties.data;
  assert.equal(detail.thumb, null);
  assert.deepEqual(detailSchema.properties.thumb.type, ['string', 'null']);
});


test('browser documents coexist with agent endpoints and existing catalogue dispatch', async (t) => {
  const h = setup(t);
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, ...rest) => {
    if (input instanceof Request && input.url.startsWith('https://prismwalls.com/')) return new Response('<html>Static site</html>', { headers: { 'content-type': 'text/html' } });
    return originalFetch(input, ...rest);
  };
  const env = { LINKS_KV: { get: async () => null }, AI_STATE_KV: { get: async () => null }, FIREBASE_PROJECT_ID: 'prism-test', PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism', APP_STORE_URL: 'https://apps.apple.com/app/id1499765773' };
  for (const path of ['/about', '/mcp']) {
    const response = await worker.fetch(new Request(`https://prismwalls.com${path}`, { headers: { accept: 'text/html' } }), env, { waitUntil() {} });
    assert.equal(response.status, 200);
    assert.equal(await response.text(), '<html>Static site</html>');
  }
  assert.equal((await h.get('/mcp')).status, 405);
  assert.equal((await h.get('/.well-known/assetlinks.json')).status, 200);
  assert.equal((await h.get('/wallpaper/W1')).status, 200);
  assert.equal((await h.get('/sitemap.xml')).headers.get('content-type'), 'application/xml; charset=utf-8');
});

test('MCP Apps resources use the registered metadata shape and MIME type', async (t) => {
  const h = setup(t);
  const tools = await (await h.post('/mcp', { jsonrpc: '2.0', id: 1, method: 'tools/list' })).json();
  assert.deepEqual(tools.result.tools[1]._meta.ui, { resourceUri: 'ui://prism/wallpaper-card' });
  const resource = await (await h.post('/mcp', { jsonrpc: '2.0', id: 2, method: 'resources/read', params: { uri: 'ui://prism/wallpaper-card' } })).json();
  assert.equal(resource.result.contents[0].mimeType, 'text/html;profile=mcp-app');
});

test('API catalog uses relation-keyed RFC 9727 linkset discovery', async (t) => {
  const h = setup(t);
  const catalog = await (await h.get('/.well-known/api-catalog')).json();
  assert.deepEqual(catalog.linkset, [{ anchor: 'https://prismwalls.com/api/v1', 'service-desc': [{ href: 'https://prismwalls.com/openapi.json', type: 'application/json' }], 'service-doc': [{ href: 'https://prismwalls.com/docs', type: 'text/html' }] }]);
});

test('agent placeholders do not promise app-based agent identity or supported OAuth', async (t) => {
  const h = setup(t);
  for (const path of ['/api/v1/me', '/agent/identity', '/agent/claim', '/agent/events']) {
    const body = await (await h.get(path)).json();
    assert.equal(body.error.hint, 'Agent authentication is not available. Public catalogue endpoints need no authentication.');
  }
  const spec = await (await h.get('/openapi.json')).json();
  assert.equal(spec.paths['/api/v1/me'].get.description, 'Agent authentication is not available. This endpoint always returns 401.');
  assert.ok(spec.paths['/api/v1/me'].get.responses['401']);
});

test('wallpaper agent instructions bypass catalogue routes for GET and HEAD', async (t) => {
  setup(t);
  const requests = [];
  globalThis.fetch = async (request) => {
    requests.push([request.url, request.method]);
    return new Response(request.method === 'HEAD' ? null : '# Wallpaper agent instructions', { headers: { 'content-type': 'text/plain; charset=utf-8' } });
  };
  const env = { LINKS_KV: { get: async () => null }, AI_STATE_KV: { get: async () => null }, FIREBASE_PROJECT_ID: 'prism-test', PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism', APP_STORE_URL: 'https://apps.apple.com/app/id1499765773' };
  for (const method of ['GET', 'HEAD']) {
    const response = await worker.fetch(new Request('https://prismwalls.com/wallpapers/llms.txt', { method }), env, { waitUntil() {} });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'text/plain; charset=utf-8');
    assert.equal(await response.text(), method === 'HEAD' ? '' : '# Wallpaper agent instructions');
  }
  assert.deepEqual(requests, [['https://prismwalls.com/wallpapers/llms.txt', 'GET'], ['https://prismwalls.com/wallpapers/llms.txt', 'HEAD']]);
});

test('empty public projections return empty API and NLWeb results', async (t) => {
  const h = setup(t);
  delete h.docs['webPages/latest~1'];
  assert.deepEqual(await (await h.get('/api/v1/wallpapers')).json(), { data: [], page: 1, pages: 0, total: 0 });
  assert.deepEqual(await (await h.get('/api/v1/categories')).json(), { data: [] });
  const answer = await (await h.post('/ask', { query: 'sunset' })).json();
  assert.deepEqual(answer.results, []);
});

test('projection outages produce controlled unavailable responses', async (t) => {
  const h = setup(t);
  globalThis.fetch = async () => new Response(null, { status: 503 });
  const api = await h.get('/api/v1/wallpapers');
  assert.equal(api.status, 503);
  assert.equal((await api.json()).error.code, 'catalog_unavailable');
  const ask = await h.post('/ask', { query: 'sunset' });
  assert.equal(ask.status, 503);
  assert.equal((await ask.json()).error.code, 'catalog_unavailable');
  const mcp = await h.post('/mcp', { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'get_wallpaper', arguments: { id: 'W1' } } });
  assert.deepEqual(await mcp.json(), { jsonrpc: '2.0', id: 1, error: { code: -32603, message: 'Internal error.' } });
});
