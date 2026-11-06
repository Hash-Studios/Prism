interface AgentEnv {
  FIREBASE_PROJECT_ID?: string;
  CATALOG_FIRESTORE_ORIGIN?: string;
}

interface Wall {
  state?: string;
  title?: string;
  description?: string;
  category?: string;
  categorySlug?: string;
  tags?: string[];
  colors?: Array<{ name: string; hex: string }>;
  width?: number;
  height?: number;
  createdAt?: string;
  updatedAt?: string;
  creatorName?: string;
  creator?: { username: string; name: string } | null;
  thumb?: string;
  desktop?: { v: string; thumb: string; width: number; height: number };
}

interface PageDoc {
  items?: Array<{ id: string; title?: string; thumb?: string; width?: number; height?: number }>;
  categories?: Array<{ slug: string; name: string; count: number }>;
  page?: number;
  pages?: number;
  total?: number;
}

interface PublicWallpaper {
  id: string;
  title: string;
  category: string;
  categorySlug: string;
  tags: string[];
  width: number;
  height: number;
  creator: { username: string; name: string } | null;
  thumb?: string | null;
  url?: string;
  [key: string]: unknown;
}

const SITE = 'https://prismwalls.com';
const AUTH_METADATA = `${SITE}/.well-known/oauth-protected-resource`;
const UI_RESOURCE = 'ui://prism/wallpaper-card';
const PRICING = {
  indicative: true,
  note: 'Prices are indicative; confirm current in-app purchase pricing in Prism.',
  source: `${SITE}/pricing.md`,
  tiers: [
    { id: 'free', name: 'Free', price: 'Free', billing: 'No subscription' },
    { id: 'premium-monthly', name: 'Prism Premium Monthly', price: 'In-app purchase', billing: 'Monthly' },
    { id: 'premium-yearly', name: 'Prism Premium Yearly', price: 'In-app purchase', billing: 'Yearly' },
    { id: 'coins', name: 'Coins', price: 'In-app purchase', billing: 'One-time packs' },
  ],
};

const MAX_BATCH = 10;

class AgentReadError extends Error {}

export async function handleAgentRequest(request: Request, url: URL, env: AgentEnv, _ctx: ExecutionContext): Promise<Response | null> {
  const path = url.pathname;
  if (path === '/api/v1' || path.startsWith('/api/v1/')) {
    if (request.method !== 'GET') return errorResponse(405, 'method_not_allowed', 'Only GET is supported.', 'Use GET for this endpoint.', { allow: 'GET' });
    try {
      if (path === '/api/v1/wallpapers') return json(await listWallpapers(url, env));
      if (path.startsWith('/api/v1/wallpapers/')) {
        const id = path.slice('/api/v1/wallpapers/'.length);
        if (!/^[A-Za-z0-9_-]{1,200}$/.test(id)) return errorResponse(404, 'not_found', 'Wallpaper not found.', 'Check the wallpaper id.');
        const wall = await readDoc<Wall>(env, `webWalls/${id}`);
        if (!isPublicWall(wall)) return errorResponse(404, 'not_found', 'Wallpaper not found.', 'Only public wallpapers are available.');
        return json({ data: publicWall(id, wall, true) });
      }
      if (path === '/api/v1/categories') {
        const page = await readDoc<PageDoc>(env, 'webPages/latest~1');
        return json({ data: publicCategories(page) });
      }
      if (path === '/api/v1/pricing') return json(PRICING);
      if (path === '/api/v1/me') {
        return errorResponse(401, 'unauthorized', 'Authentication is required.', 'Agent authentication is not available. Public catalogue endpoints need no authentication.', {
          'www-authenticate': `Bearer resource_metadata="${AUTH_METADATA}"`,
        });
      }
      if (path === '/api/v1/sandbox/wallpapers') return json({ sandbox: true, data: sampleWalls, page: 1, pages: 1, total: sampleWalls.length });
      return errorResponse(404, 'not_found', 'API endpoint not found.', 'See /openapi.json for supported endpoints.');
    } catch (error) {
      if (error instanceof RpcError) return errorResponse(400, 'invalid_query', error.message, 'Use a category slug.');
      return errorResponse(503, 'catalog_unavailable', 'The wallpaper catalogue is temporarily unavailable.', 'Try again shortly, or browse https://prismwalls.com/wallpapers.');
    }
  }

  if (path === '/openapi.json' && request.method === 'GET') return json(openApi);
  if (path === '/ask' && request.method === 'POST') return handleAsk(request, env);
  if (path === '/mcp' || path === '/mcp/docs') return handleMcp(request, url, env);
  if ((path === '/mcp/server-card' || path === '/.well-known/mcp/server-card.json') && request.method === 'GET') {
    return json(serverCard);
  }
  if (path.startsWith('/.well-known/')) {
    const documents: Record<string, unknown> = {
      '/.well-known/agent-card.json': agentCard,
      '/.well-known/ard.json': directory,
      '/.well-known/ai-catalog.json': directory,
      '/.well-known/api-catalog': apiCatalog,
      '/.well-known/agent-skills/index.json': skillsIndex,
      '/.well-known/oauth-protected-resource': protectedResource,
      '/.well-known/oauth-authorization-server': authorizationServer,
      '/.well-known/http-message-signatures-directory': signaturesDirectory,
    };
    if (Object.hasOwn(documents, path) && request.method === 'GET') {
      if (path === '/.well-known/api-catalog') return json(documents[path], 200, { 'content-type': 'application/linkset+json;profile="https://www.rfc-editor.org/info/rfc9727"' });
      return json(documents[path]);
    }
  }
  if (['/agent/identity', '/agent/claim', '/agent/events'].includes(path)) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: { 'access-control-allow-methods': 'GET, POST, OPTIONS', 'access-control-allow-origin': '*' } });
    if (request.method === 'GET' || request.method === 'POST') {
      return errorResponse(request.method === 'GET' ? 401 : 400, request.method === 'GET' ? 'unauthorized' : 'signup_in_app', 'Agent authentication is not available.', 'Agent authentication is not available. Public catalogue endpoints need no authentication.');
    }
    return errorResponse(405, 'method_not_allowed', 'Method not allowed.', 'Use GET, POST, or OPTIONS.', { allow: 'GET, POST, OPTIONS' });
  }
  return null;
}

async function listWallpapers(url: URL, env: AgentEnv) {
  const requestedPage = Number(url.searchParams.get('page') ?? '1');
  let pageNumber = Number.isInteger(requestedPage) && requestedPage > 0 ? requestedPage : 1;
  const category = url.searchParams.get('category')?.toLowerCase();
  const query = url.searchParams.get('q')?.trim().toLowerCase();
  if (category && !/^[a-z0-9-]{1,100}$/.test(category)) throw new RpcError(-32602, 'Invalid category');
  if (query) pageNumber = 1;
  const popular = !query && !category && url.searchParams.get('sort') === 'popular';
  const key = query ? (category ? `category~${category}~1` : 'latest~1') : category ? `category~${category}~${pageNumber}` : popular ? `popular~${pageNumber}` : `latest~${pageNumber}`;
  const page = await readDoc<PageDoc>(env, `webPages/${key}`);
  if (!page) return { data: [], page: pageNumber, pages: 0, total: 0 };
  const rows = await Promise.all((page.items ?? []).map(async (item) => {
    const wall = await readDoc<Wall>(env, `webWalls/${item.id}`);
    if (!isPublicWall(wall)) return null;
    return { ...publicWall(item.id, wall, false), thumb: wall.state === 'gated' ? undefined : wall.thumb ?? item.thumb, url: `${SITE}/wallpaper/${encodeURIComponent(item.id)}` };
  }));
  let items = rows.filter((item): item is NonNullable<typeof item> => item != null);
  if (query) {
    items = items.filter((item) => `${item.title} ${(item.tags ?? []).join(' ')} ${item.category ?? ''}`.toLowerCase().includes(query));
  }
  return {
    data: items,
    page: pageNumber,
    pages: query ? (items.length ? 1 : 0) : page.pages ?? 0,
    total: query ? items.length : page.total ?? items.length,
    ...(query ? { search: { scope: 'page', description: 'Search filters only the selected projected page; this is not a full search index.' } } : {}),
  };
}

function publicWall(id: string, wall: Wall, detail: boolean): PublicWallpaper {
  const result: PublicWallpaper = {
    id, title: wall.title ?? '', category: wall.category ?? '', categorySlug: wall.categorySlug ?? '', tags: wall.tags ?? [],
    width: wall.width ?? 0, height: wall.height ?? 0, creator: wall.creator ? { username: wall.creator.username, name: wall.creator.name } : null,
  };
  if (detail) {
    Object.assign(result, {
      state: wall.state, description: wall.description ?? '', colors: (wall.colors ?? []).map(({ name, hex }) => ({ name, hex })), createdAt: wall.createdAt ?? '',
      updatedAt: wall.updatedAt ?? '', creatorName: wall.creatorName ?? '',
      ...(wall.state === 'gated' ? {} : { thumb: wall.thumb ?? null }),
      ...(wall.state === 'gated' ? {} : { desktop: wall.desktop ? { v: wall.desktop.v, thumb: wall.desktop.thumb, width: wall.desktop.width, height: wall.desktop.height } : null }),
    });
  }
  return result;
}

function publicCategories(page: PageDoc | null) {
  return (page?.categories ?? []).map(({ slug, name, count }) => ({ slug, name, count }));
}

function isPublicWall(wall: Wall | null): wall is Wall {
  return wall != null && ['live', 'gated'].includes(wall.state ?? '');
}

async function readDoc<T>(env: AgentEnv, path: string): Promise<T | null> {
  if (!env.FIREBASE_PROJECT_ID) throw new AgentReadError('FIREBASE_PROJECT_ID is not configured');
  const origin = env.CATALOG_FIRESTORE_ORIGIN || 'https://firestore.googleapis.com';
  const url = `${origin}/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents/`
    + path.split('/').map(encodeURIComponent).join('/');
  let response: Response;
  try {
    // Cache catalogue pages, but always re-check wall visibility and asset fields against Firestore.
    response = await fetch(url, {
      signal: AbortSignal.timeout(4000),
      ...(path.startsWith('webPages/')
        ? { cf: { cacheTtlByStatus: { '200-299': 300, '400-599': -1 }, cacheEverything: true } }
        : { cache: 'no-store' }),
    });
  } catch (error) {
    throw new AgentReadError(`${error}`);
  }
  if (response.status === 404) return null;
  if (!response.ok) throw new AgentReadError(`Firestore returned ${response.status}`);
  try {
    const document = await response.json() as { fields?: Record<string, FirestoreValue> };
    return decodeFields(document.fields ?? {}) as T;
  } catch (error) {
    throw new AgentReadError(`Invalid Firestore document: ${error}`);
  }
}

type FirestoreValue = { stringValue?: string; integerValue?: string; doubleValue?: number; booleanValue?: boolean; nullValue?: null; timestampValue?: string; arrayValue?: { values?: FirestoreValue[] }; mapValue?: { fields?: Record<string, FirestoreValue> } };

function decodeValue(value: FirestoreValue): unknown {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue?.values ?? []).map(decodeValue);
  if ('mapValue' in value) return decodeFields(value.mapValue?.fields ?? {});
  return null;
}

function decodeFields(fields: Record<string, FirestoreValue>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

async function handleAsk(request: Request, env: AgentEnv): Promise<Response> {
  let body: { query?: string | { text?: string }; prefer?: { streaming?: boolean } };
  try { body = await request.json() as typeof body; } catch { return errorResponse(400, 'invalid_json', 'Request body must be valid JSON.', 'Send a JSON query object.'); }
  if (body == null || typeof body !== 'object' || Array.isArray(body)) return errorResponse(400, 'invalid_body', 'Request body must be a JSON object.', 'Send query.text as a string.');
  const query = typeof body.query === 'string' ? body.query : body.query?.text;
  if (typeof query !== 'string' || !query.trim()) return errorResponse(400, 'invalid_query', 'A query is required.', 'Set query.text to a wallpaper search.');
  try {
    const result = await listWallpapers(new URL(`${SITE}/api/v1/wallpapers?q=${encodeURIComponent(query)}&page=1`), env);
    const found = result.data.slice(0, 5).map((wall) => ({ name: wall.title, url: wall.url, description: `${wall.category} wallpaper by ${wall.creator?.name ?? 'Prism creator'}` }));
    if (body.prefer?.streaming || request.headers.get('accept')?.includes('text/event-stream')) {
      const stream = [`event: start\ndata: ${JSON.stringify({ response_type: 'answer' })}\n\n`, ...found.map((item) => `event: result\ndata: ${JSON.stringify(item)}\n\n`), 'event: complete\ndata: {}\n\n'].join('');
      return new Response(stream, { headers: { 'content-type': 'text/event-stream; charset=utf-8', 'cache-control': 'no-store' } });
    }
    return json({ _meta: { response_type: 'answer', version: '0.55' }, results: found });
  } catch (error) {
    return errorResponse(503, 'catalog_unavailable', 'The wallpaper catalogue is temporarily unavailable.', 'Try again shortly, or browse https://prismwalls.com/wallpapers.');
  }
}

async function handleMcp(request: Request, url: URL, env: AgentEnv): Promise<Response> {
  const origin = request.headers.get('origin');
  if (origin && origin !== SITE) return errorResponse(403, 'forbidden_origin', 'Origin is not allowed.', 'Use the Prism origin or a server-side client.');
  if (request.method === 'GET') return errorResponse(405, 'method_not_allowed', 'MCP uses POST requests.', 'Send a JSON-RPC 2.0 POST.', { allow: 'POST, OPTIONS' });
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: { 'access-control-allow-methods': 'POST, OPTIONS', 'access-control-allow-origin': '*', 'access-control-allow-headers': 'content-type, mcp-session-id, mcp-protocol-version' } });
  if (request.method !== 'POST') return errorResponse(405, 'method_not_allowed', 'MCP uses POST requests.', 'Send a JSON-RPC 2.0 POST.', { allow: 'POST, OPTIONS' });
  let payload: unknown;
  try { payload = await request.json(); } catch { return json({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }, 400); }
  const batch = Array.isArray(payload);
  if (batch && payload.length > MAX_BATCH) return json({ jsonrpc: '2.0', id: null, error: { code: -32600, message: `Batch is limited to ${MAX_BATCH} requests` } }, 400);
  if (batch && payload.length === 0) return json({ jsonrpc: '2.0', id: null, error: { code: -32600, message: 'Invalid Request' } }, 400);
  const responses = await Promise.all((batch ? payload : [payload]).map(async (value: unknown) => {
    const rpc = value as RpcRequest;
    if (!rpc || typeof rpc !== 'object' || Array.isArray(rpc) || rpc.jsonrpc !== '2.0' || typeof rpc.method !== 'string'
      || (Object.hasOwn(rpc, 'id') && rpc.id !== null && typeof rpc.id !== 'string' && typeof rpc.id !== 'number')
      || (Object.hasOwn(rpc, 'params') && (rpc.params === null || typeof rpc.params !== 'object' || Array.isArray(rpc.params)))) {
      return { jsonrpc: '2.0', id: null, error: { code: -32600, message: 'Invalid Request' } };
    }
    const notification = !Object.hasOwn(rpc, 'id');
    try {
      const result = await dispatchRpc(rpc.method, rpc.params ?? {}, env, url.pathname === '/mcp/docs');
      return notification ? null : { jsonrpc: '2.0', id: rpc.id, result };
    } catch (error) {
      if (notification) return null;
      return { jsonrpc: '2.0', id: rpc.id, error: error instanceof RpcError
        ? { code: error.code, message: error.message } : { code: -32603, message: 'Internal error.' } };
    }
  }));
  const replies = responses.filter((response) => response !== null);
  if (!replies.length) return new Response(null, { status: 202 });
  return json(batch ? replies : replies[0]);
}

interface RpcRequest { jsonrpc?: string; id?: string | number | null; method?: string; params?: Record<string, unknown> }
class RpcError extends Error {
  readonly code: number;
  constructor(code: number, message: string) { super(message); this.code = code; }
}

async function dispatchRpc(method: string, params: Record<string, unknown>, env: AgentEnv, docs: boolean): Promise<unknown> {
  if (method === 'initialize') return { protocolVersion: '2025-03-26', capabilities: { tools: {}, resources: {} }, serverInfo: { name: docs ? 'Prism Developer Docs' : 'Prism Wallpapers', version: '1.0.0' } };
  if (method === 'ping') return {};
  if (method === 'tools/list') return { tools: docs ? docsTools : productTools };
  if (method === 'resources/list') return { resources: docs ? [] : [{ uri: UI_RESOURCE, name: 'Wallpaper card', description: 'A visual wallpaper card.', mimeType: 'text/html;profile=mcp-app' }] };
  if (method === 'resources/read') {
    if (docs || params.uri !== UI_RESOURCE) throw new RpcError(-32002, 'Resource not found');
    return { contents: [{ uri: UI_RESOURCE, mimeType: 'text/html;profile=mcp-app', text: wallpaperCardHtml }] };
  }
  if (method !== 'tools/call') throw new RpcError(-32601, 'Method not found');
  const name = params.name;
  if (params.arguments != null && (typeof params.arguments !== 'object' || Array.isArray(params.arguments))) throw new RpcError(-32602, 'Invalid arguments');
  const args = (params.arguments ?? {}) as Record<string, unknown>;
  for (const key of ['q', 'category', 'id']) if (args[key] != null && typeof args[key] !== 'string') throw new RpcError(-32602, 'Invalid arguments');
  if (args.page != null && (!Number.isInteger(args.page) || Number(args.page) < 1)) throw new RpcError(-32602, 'Invalid page');
  if (docs) {
    if (name === 'search_docs') return { content: [{ type: 'text', text: JSON.stringify({ links: [`${SITE}/docs`, `${SITE}/developers`, `${SITE}/pricing.md`, `${SITE}/auth.md`, `${SITE}/openapi.json`] }) }] };
    if (name === 'get_api_overview') return { content: [{ type: 'text', text: JSON.stringify({ title: 'Prism Wallpapers API', openapi: `${SITE}/openapi.json`, docs: `${SITE}/docs` }) }] };
  } else {
    if (name === 'search_wallpapers') {
      const searchUrl = new URL(`${SITE}/api/v1/wallpapers`);
      for (const key of ['q', 'category', 'page']) if (args[key] != null) searchUrl.searchParams.set(key, String(args[key]));
      return { content: [{ type: 'text', text: JSON.stringify(await listWallpapers(searchUrl, env)) }] };
    }
    if (name === 'get_wallpaper' && typeof args.id === 'string') {
      if (!/^[A-Za-z0-9_-]{1,200}$/.test(args.id)) throw new RpcError(-32602, 'Invalid wallpaper id');
      const wall = await readDoc<Wall>(env, `webWalls/${args.id}`);
      if (!isPublicWall(wall)) throw new RpcError(-32004, 'Wallpaper not found');
      return { content: [{ type: 'text', text: JSON.stringify(publicWall(args.id, wall, true)) }], _meta: { ui: { resourceUri: UI_RESOURCE } } };
    }
    if (name === 'list_categories') return { content: [{ type: 'text', text: JSON.stringify(publicCategories(await readDoc<PageDoc>(env, 'webPages/latest~1'))) }] };
    if (name === 'get_pricing') return { content: [{ type: 'text', text: JSON.stringify(PRICING) }] };
  }
  throw new RpcError(-32602, 'Unknown tool or invalid arguments');
}

function schema(properties: Record<string, unknown>, required: string[] = []) {
  return { type: 'object', properties, required, additionalProperties: false };
}

const productTools = [
  { name: 'search_wallpapers', description: 'Search public wallpapers in a projected catalogue page.', inputSchema: schema({ q: { type: 'string' }, category: { type: 'string' }, page: { type: 'integer', minimum: 1 } }) },
  { name: 'get_wallpaper', description: 'Get public metadata for one wallpaper.', inputSchema: schema({ id: { type: 'string' } }, ['id']), _meta: { ui: { resourceUri: UI_RESOURCE } } },
  { name: 'list_categories', description: 'List wallpaper categories.', inputSchema: schema({}) },
  { name: 'get_pricing', description: 'Get indicative in-app purchase tiers.', inputSchema: schema({}) },
];
const docsTools = [
  { name: 'search_docs', description: 'Find Prism API documentation links.', inputSchema: schema({ q: { type: 'string' } }) },
  { name: 'get_api_overview', description: 'Get the Prism API overview and OpenAPI link.', inputSchema: schema({}) },
];

const errorSchema = { type: 'object', properties: { error: { type: 'object', properties: { code: { type: 'string' }, message: { type: 'string' }, hint: { type: 'string' } }, required: ['code', 'message', 'hint'] } }, required: ['error'] };
const categorySchema = { type: 'object', properties: { slug: { type: 'string' }, name: { type: 'string' }, count: { type: 'integer' } }, required: ['slug', 'name', 'count'] };
const wallSchema = { type: 'object', properties: { id: { type: 'string' }, title: { type: 'string' }, category: { type: 'string' }, categorySlug: { type: 'string' }, tags: { type: 'array', items: { type: 'string' } }, width: { type: 'integer' }, height: { type: 'integer' }, thumb: { type: ['string', 'null'], format: 'uri' }, url: { type: 'string', format: 'uri' }, creator: { type: ['object', 'null'] } }, required: ['id', 'title', 'category', 'categorySlug', 'tags', 'width', 'height', 'creator'] };
const listSchema = { type: 'object', properties: { data: { type: 'array', items: wallSchema }, page: { type: 'integer' }, pages: { type: 'integer' }, total: { type: 'integer' } }, required: ['data', 'page', 'pages', 'total'] };
const mcpRequestBody = { required: true, content: { 'application/json': { schema: { type: 'object', properties: { jsonrpc: { const: '2.0' }, id: { type: ['string', 'integer', 'null'] }, method: { type: 'string' }, params: { type: 'object' } }, required: ['jsonrpc', 'method'] } } } };

const openApi = {
  openapi: '3.1.0', info: { title: 'Prism Wallpapers API', version: '1.0.0', description: 'Public wallpaper discovery and agent endpoints.' }, servers: [{ url: SITE }],
  paths: {
    '/api/v1/wallpapers': { get: operation('listWallpapers', 'List public wallpapers; q filters only page 1 of latest (or of the category) and is not a full search index.', { page: param('page', 'integer'), category: param('category', 'string'), q: param('q', 'string'), sort: { type: 'string', enum: ['latest', 'popular'] } }, listSchema) },
    '/api/v1/wallpapers/{id}': { get: operation('getWallpaper', 'Get public wallpaper metadata. Gated walls omit their thumbnail.', {}, { type: 'object', properties: { data: wallSchema } }, [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }]) },
    '/api/v1/categories': { get: operation('listCategories', 'List categories from the latest catalogue page.', {}, { type: 'object', properties: { data: { type: 'array', items: categorySchema } } }) },
    '/api/v1/pricing': { get: operation('getPricing', 'Read indicative in-app purchase tiers; see /pricing.md.', {}, { type: 'object' }) },
    '/api/v1/me': { get: operation('getCurrentAgent', 'Agent authentication is not available. This endpoint always returns 401.', {}, { type: 'object' }) },
    '/api/v1/sandbox/wallpapers': { get: operation('getSandboxWallpapers', 'Get fixed sandbox wallpaper examples.', {}, listSchema) },
    '/ask': { post: { ...operation('askWallpapers', 'Ask a natural-language wallpaper question; supports server-sent events.', {}, { type: 'object', properties: { _meta: { type: 'object' }, results: { type: 'array', items: { type: 'object', properties: { name: { type: 'string' }, url: { type: 'string', format: 'uri' }, description: { type: 'string' } }, required: ['name', 'url', 'description'] } } } }), requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', properties: { query: { oneOf: [{ type: 'string' }, { type: 'object', properties: { text: { type: 'string' } }, required: ['text'] }] }, prefer: { type: 'object', properties: { streaming: { type: 'boolean' } } } }, required: ['query'] } } } } } },
    '/mcp': { post: { ...operation('mcpProduct', 'MCP Streamable HTTP product tools and resources.', {}, { type: 'object' }), requestBody: mcpRequestBody } },
    '/mcp/docs': { post: { ...operation('mcpDocs', 'MCP Streamable HTTP documentation tools.', {}, { type: 'object' }), requestBody: mcpRequestBody } },
  },
};

function operation(id: string, description: string, query: Record<string, unknown>, response: unknown, parameters: unknown[] = []) {
  return { operationId: id, description, parameters: [...Object.entries(query).map(([name, p]) => ({ name, in: 'query', required: false, schema: p })), ...parameters], responses: { '200': { description: 'Successful response', content: { 'application/json': { schema: response } } }, '400': { description: 'Invalid request', content: { 'application/json': { schema: errorSchema } } }, '401': { description: 'Authentication unavailable', content: { 'application/json': { schema: errorSchema } } }, '503': { description: 'Catalogue unavailable', content: { 'application/json': { schema: errorSchema } } }, '404': { description: 'Not found', content: { 'application/json': { schema: errorSchema } } } } };
}
function param(name: string, type: string) { return { type, ...(name === 'page' ? { minimum: 1 } : {}) }; }

const serverCard = { $schema: 'https://static.modelcontextprotocol.io/schemas/v1/server-card.schema.json', name: 'com.prismwalls/mcp', description: 'Discover public wallpapers and Prism developer documentation.', version: '1.0.0', remotes: [{ type: 'streamable-http', url: `${SITE}/mcp` }] };
const agentCard = { name: 'Prism Wallpapers', description: 'Discover public wallpapers and explore Prism wallpaper categories.', url: SITE, version: '1.0.0', capabilities: { streaming: true }, skills: [{ id: 'prism-wallpapers', name: 'Prism Wallpapers', description: 'Search and inspect public Prism wallpapers.' }], defaultInputModes: ['text'], defaultOutputModes: ['text'] };
const directory = { servers: [{ name: 'Prism Wallpapers', url: `${SITE}/mcp`, card: `${SITE}/.well-known/mcp/server-card.json` }, { name: 'Prism Developer Docs', url: `${SITE}/mcp/docs`, card: `${SITE}/.well-known/mcp/server-card.json` }] };
const apiCatalog = { linkset: [{ anchor: `${SITE}/api/v1`, 'service-desc': [{ href: `${SITE}/openapi.json`, type: 'application/json' }], 'service-doc': [{ href: `${SITE}/docs`, type: 'text/html' }] }] };
const skillsIndex = { skills: [{ id: 'prism-wallpapers', name: 'Prism Wallpapers', description: 'Search public Prism wallpapers.', url: 'https://github.com/Hash-Studios/Prism/blob/master/skills/prism-wallpapers/SKILL.md' }] };
const protectedResource = { resource: `${SITE}/api/v1`, authorization_servers: [SITE], bearer_methods_supported: ['header'], scopes_supported: ['wallpapers:read'] };
const authorizationServer = { issuer: SITE, authorization_endpoint: `${SITE}/agent/identity`, token_endpoint: `${SITE}/agent/claim`, agent_auth: { skill: `${SITE}/auth.md`, identity_endpoint: `${SITE}/agent/identity`, claim_endpoint: `${SITE}/agent/claim`, events_endpoint: `${SITE}/agent/events`, identity_types_supported: ['anonymous'] } };
const signaturesDirectory = { keys: [] };
const wallpaperCardHtml = '<!doctype html><html><head><meta charset="utf-8"><title>Prism wallpaper</title></head><body><article><h1>Prism wallpaper</h1><p>Public wallpaper details from Prism.</p></article></body></html>';
const sampleWalls = [{ id: 'sandbox-wall-1', title: 'Quiet Dunes', category: 'Nature', categorySlug: 'nature', tags: ['sand', 'minimal'], width: 1080, height: 2340, thumb: 'https://prismwalls.com/assets/og/home.jpg', url: `${SITE}/wallpaper/sandbox-wall-1`, creator: null }];

function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}) {
  return Response.json(body, { status, headers: { 'content-type': 'application/json; charset=utf-8', ...extraHeaders } });
}
function errorResponse(status: number, code: string, message: string, hint: string, headers: Record<string, string> = {}) {
  return json({ error: { code, message, hint } }, status, headers);
}
