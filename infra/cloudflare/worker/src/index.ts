export interface Env {
  LINKS_KV: KVNamespace;
  PLAY_STORE_URL: string;
  APP_STORE_URL: string;
}

type LinkType = 'share' | 'user' | 'setup' | 'refer';

interface CreateLinkRequest {
  type: LinkType;
  canonical_url?: string;
  payload?: Record<string, unknown>;
  campaign?: Record<string, unknown>;
}

interface LinkRecord {
  canonical_url: string;
  created_at: string;
  type: LinkType;
  campaign?: Record<string, unknown>;
}

const DOMAIN = 'prismwalls.com';
const ALLOWED_PATHS = new Set(['/share', '/user', '/setup', '/refer']);
const APP_LINK_PATHS = ['/share', '/user', '/setup', '/refer', '/l'];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/api/links') {
      return createLink(request, env);
    }

    if (request.method === 'GET' && url.pathname.startsWith('/l/')) {
      return resolveShortLink(url.pathname, env);
    }

    if (request.method === 'GET' && APP_LINK_PATHS.some((path) => url.pathname === path || url.pathname.startsWith(`${path}/`))) {
      return fallbackToStore(request, env);
    }

    return new Response('Not found', { status: 404 });
  },
};

async function createLink(request: Request, env: Env): Promise<Response> {
  let body: CreateLinkRequest;
  try {
    body = (await request.json()) as CreateLinkRequest;
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  if (!isValidType(body.type)) {
    return json({ error: 'invalid_type' }, 400);
  }

  const canonical = buildCanonicalUrl(body);
  if (canonical == null) {
    return json({ error: 'invalid_canonical_url' }, 400);
  }

  const code = generateCode(8);
  const record: LinkRecord = {
    canonical_url: canonical.toString(),
    created_at: new Date().toISOString(),
    type: body.type,
    campaign: body.campaign,
  };

  await env.LINKS_KV.put(code, JSON.stringify(record));

  return json(
    {
      short_url: `https://${DOMAIN}/l/${code}`,
      canonical_url: canonical.toString(),
      code,
    },
    201,
  );
}

async function resolveShortLink(pathname: string, env: Env): Promise<Response> {
  const code = pathname.replace('/l/', '').trim();
  if (!/^[A-Za-z0-9]{7,10}$/.test(code)) {
    return new Response('Invalid code', { status: 400 });
  }

  const raw = await env.LINKS_KV.get(code);
  if (raw == null) {
    return new Response('Not found', { status: 404 });
  }

  let record: LinkRecord;
  try {
    record = JSON.parse(raw) as LinkRecord;
  } catch {
    return new Response('Corrupt record', { status: 500 });
  }

  const canonical = tryParseCanonical(record.canonical_url);
  if (canonical == null) {
    return new Response('Invalid canonical URL', { status: 500 });
  }

  return Response.redirect(canonical.toString(), 302);
}

function fallbackToStore(request: Request, env: Env): Response {
  const userAgent = request.headers.get('user-agent')?.toLowerCase() ?? '';
  const destination =
    userAgent.includes('iphone') || userAgent.includes('ipad') || userAgent.includes('ipod')
      ? env.APP_STORE_URL
      : env.PLAY_STORE_URL;

  return Response.redirect(destination, 302);
}

function buildCanonicalUrl(body: CreateLinkRequest): URL | null {
  if (isNonEmptyString(body.canonical_url)) {
    return tryParseCanonical(body.canonical_url);
  }

  if (body.payload == null) {
    return null;
  }

  const path = `/${body.type}`;
  if (!ALLOWED_PATHS.has(path)) {
    return null;
  }

  const canonical = new URL(`https://${DOMAIN}${path}`);
  for (const [key, value] of Object.entries(body.payload)) {
    if (isNonEmptyString(value)) {
      canonical.searchParams.set(key, value);
    }
  }
  return canonical;
}

function tryParseCanonical(value: string): URL | null {
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== 'https:' || parsed.hostname !== DOMAIN || !ALLOWED_PATHS.has(parsed.pathname)) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function isValidType(type: unknown): type is LinkType {
  return type === 'share' || type === 'user' || type === 'setup' || type === 'refer';
}

function generateCode(length: number): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let out = '';
  for (let i = 0; i < bytes.length; i += 1) {
    out += alphabet[bytes[i] % alphabet.length];
  }
  return out;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}
