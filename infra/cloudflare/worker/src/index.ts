import { AiQuotaCoordinator, type AiEnvBindings, handleAiApiRequest } from './ai';
import { maybeHandleAssociationRequest } from './association_files';

export interface Env extends AiEnvBindings {
  LINKS_KV: KVNamespace;
  OG_IMAGES?: R2Bucket;
  PLAY_STORE_URL: string;
  APP_STORE_URL: string;
  OG_FALLBACK_IMAGE?: string;
  BROWSER_RENDERING_ACCOUNT_ID?: string;
  BROWSER_RENDERING_API_TOKEN?: string;
}

type LinkType = 'share' | 'user' | 'setup' | 'refer';
type OgStorageType = 'r2' | 'kv';

interface CreateLinkPreviewInput {
  title?: string;
  description?: string;
  image_source_url?: string;
  username?: string;
  provider?: string;
  wall_id?: string;
  setup_name?: string;
}

interface CreateLinkRequest {
  type: LinkType;
  canonical_url?: string;
  payload?: Record<string, unknown>;
  campaign?: Record<string, unknown>;
  preview?: CreateLinkPreviewInput;
}

interface PreviewSnapshot {
  title: string;
  description: string;
  image_source_url: string;
  username: string;
  provider: string;
  wall_id: string;
  setup_name: string;
  app_store_url: string;
  play_store_url: string;
}

interface LinkRecord {
  code: string;
  type: LinkType;
  canonical_url: string;
  created_at: string;
  campaign?: Record<string, unknown>;
  preview: PreviewSnapshot;
  og_image_path?: string | null;
  og_storage?: OgStorageType | null;
  version: number;
}

interface CanonicalParseResult {
  canonical: URL;
  type: LinkType;
  canonicalIdentifier: string;
}

const DOMAIN = 'prismwalls.com';
const APP_LINK_PATHS = ['/share', '/user', '/setup', '/refer', '/l'];
const SHORT_CODE_REGEX = /^[A-Za-z0-9]{7,10}$/;
const DEFAULT_OG_VERSION = 1;
const PRISM_APP_ICON_URL = 'https://raw.githubusercontent.com/Hash-Studios/Prism/master/assets/icon/ios.png';
const USER_IDENTIFIER_QUERY_KEYS = ['identifier', 'username', 'user', 'email'];
const SETUP_NAME_QUERY_KEYS = ['name', 'setupName', 'setup_name'];
const REFER_IDENTIFIER_QUERY_KEYS = ['inviterId', 'userID', 'userId', 'userid', 'id'];
const BOT_UA_FRAGMENTS = [
  'facebookexternalhit',
  'facebot',
  'whatsapp',
  'twitterbot',
  'telegrambot',
  'discordbot',
  'slackbot',
  'linkedinbot',
  'skypeuripreview',
  'applebot',
];

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    const associationResponse = maybeHandleAssociationRequest(request, url.pathname);
    if (associationResponse != null) {
      return associationResponse;
    }

    const aiResponse = await handleAiApiRequest(request, url, env);
    if (aiResponse != null) {
      return aiResponse;
    }

    if (request.method === 'POST' && url.pathname === '/api/links') {
      return createLink(request, env, ctx);
    }

    if (request.method === 'GET' && url.pathname.startsWith('/api/links/')) {
      return getLinkDetails(url.pathname, env);
    }

    if ((request.method === 'GET' || request.method === 'HEAD') && url.pathname.startsWith('/og/')) {
      return getOgImage(url.pathname, request.method, env);
    }

    if (request.method === 'GET' && url.pathname.startsWith('/l/')) {
      return resolveShortLink(url.pathname, request, env);
    }

    if (request.method === 'GET' && APP_LINK_PATHS.some((path) => url.pathname === path || url.pathname.startsWith(`${path}/`))) {
      return fallbackToStore(request, env);
    }

    return new Response('Not found', { status: 404 });
  },
};

export { AiQuotaCoordinator };

async function createLink(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const ip = getClientIp(request);
  const withinRateLimit = await enforceCreateRateLimits(ip, env);
  if (!withinRateLimit) {
    return json({ error: 'rate_limited' }, 429);
  }

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
  const parsedCanonical = canonical != null ? parseCanonicalFromUrl(canonical) : null;
  if (canonical == null || parsedCanonical == null || parsedCanonical.type !== body.type) {
    return json({ error: 'invalid_canonical_url' }, 400);
  }

  const code = await generateUniqueCode(env);
  const preview = normalizePreview(body.type, parsedCanonical.canonical, body.preview, env);

  const record: LinkRecord = {
    code,
    type: body.type,
    canonical_url: parsedCanonical.canonical.toString(),
    created_at: new Date().toISOString(),
    campaign: body.campaign,
    preview,
    og_image_path: null,
    og_storage: null,
    version: DEFAULT_OG_VERSION,
  };

  await persistLinkRecord(code, record, env);

  // Keep short-link creation fast; generate branded OG image asynchronously.
  ctx.waitUntil((async () => {
    try {
      const ogPersisted = await generateAndPersistOgImage(code, record, env);
      if (ogPersisted == null) {
        return;
      }
      const updatedRecord: LinkRecord = {
        ...record,
        og_image_path: `/og/${code}.png`,
        og_storage: ogPersisted,
      };
      await persistLinkRecord(code, updatedRecord, env);
    } catch (error) {
      console.warn('Async OG generation failed', error);
    }
  })());

  return json(
    {
      short_url: `https://${DOMAIN}/l/${code}`,
      canonical_url: parsedCanonical.canonical.toString(),
      code,
      og_image_url: getOgImageUrl(record, env),
    },
    201,
  );
}

async function getLinkDetails(pathname: string, env: Env): Promise<Response> {
  const code = pathname.replace('/api/links/', '').trim();
  if (!SHORT_CODE_REGEX.test(code)) {
    return json({ error: 'invalid_code' }, 400);
  }

  const record = await readLinkRecord(code, env);
  if (record == null) {
    return json({ error: 'not_found' }, 404);
  }

  const parsedCanonical = parseCanonicalUrl(record.canonical_url);
  if (parsedCanonical == null) {
    return json({ error: 'invalid_canonical_url' }, 500);
  }
  const canonical = parsedCanonical.canonical;
  const query: Record<string, string> = {};
  canonical.searchParams.forEach((value, key) => {
    query[key] = value;
  });

  return json({
    code,
    type: record.type,
    canonical_url: record.canonical_url,
    path: canonical.pathname,
    query,
    route: mapRouteFromType(record.type),
    route_v2: mapRouteV2FromType(parsedCanonical.type),
    canonical_identifier: parsedCanonical.canonicalIdentifier,
    og_image_url: getOgImageUrl(record, env),
    preview: record.preview,
  });
}

async function resolveShortLink(pathname: string, request: Request, env: Env): Promise<Response> {
  const code = pathname.replace('/l/', '').trim();
  if (!SHORT_CODE_REGEX.test(code)) {
    return new Response('Invalid code', { status: 400 });
  }

  const record = await readLinkRecord(code, env);
  if (record == null) {
    return new Response('Not found', { status: 404 });
  }

  if (isCrawlerRequest(request)) {
    return html(renderCrawlerPreviewHtml(code, record, env));
  }

  return html(renderHumanLandingHtml(code, record, request, env));
}

async function getOgImage(pathname: string, method: string, env: Env): Promise<Response> {
  const codePart = pathname.replace('/og/', '').trim();
  if (!codePart.endsWith('.png')) {
    return new Response('Not found', { status: 404 });
  }

  const code = codePart.replace('.png', '').trim();
  if (!SHORT_CODE_REGEX.test(code)) {
    return new Response('Invalid code', { status: 400 });
  }

  const record = await readLinkRecord(code, env);
  if (record == null) {
    return new Response('Not found', { status: 404 });
  }

  const fromStorage = await fetchOgImageFromStorage(code, record, env);
  if (fromStorage != null) {
    if (method === 'HEAD') {
      return new Response(null, { status: fromStorage.status, headers: fromStorage.headers });
    }
    return fromStorage;
  }

  const generatedStorage = await generateAndPersistOgImage(code, record, env);
  if (generatedStorage != null) {
    record.og_image_path = `/og/${code}.png`;
    record.og_storage = generatedStorage;
    await persistLinkRecord(code, record, env);

    const generated = await fetchOgImageFromStorage(code, record, env);
    if (generated != null) {
      if (method === 'HEAD') {
        return new Response(null, { status: generated.status, headers: generated.headers });
      }
      return generated;
    }
  }

  const fallback = record.preview.image_source_url || env.OG_FALLBACK_IMAGE;
  if (isNonEmptyString(fallback)) {
    return Response.redirect(fallback, 302);
  }

  return new Response('No preview image available', { status: 404 });
}

function fallbackToStore(request: Request, env: Env): Response {
  return Response.redirect(selectStoreUrl(request, env), 302);
}

async function enforceCreateRateLimits(ip: string, env: Env): Promise<boolean> {
  const tenMinuteOk = await bumpRateCounter(env, `rl:10m:${ip}`, 20, 600);
  if (!tenMinuteOk) {
    return false;
  }
  return bumpRateCounter(env, `rl:1d:${ip}`, 200, 86400);
}

async function bumpRateCounter(env: Env, key: string, limit: number, ttlSeconds: number): Promise<boolean> {
  const existing = await env.LINKS_KV.get(key);
  const current = Number.parseInt(existing ?? '0', 10);
  if (current >= limit) {
    return false;
  }
  await env.LINKS_KV.put(key, String(current + 1), { expirationTtl: ttlSeconds });
  return true;
}

async function readLinkRecord(code: string, env: Env): Promise<LinkRecord | null> {
  const raw = await env.LINKS_KV.get(code);
  if (raw == null) {
    return null;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }

  if (typeof parsed !== 'object' || parsed == null) {
    return null;
  }

  const obj = parsed as Record<string, unknown>;
  const parsedCanonical = typeof obj.canonical_url === 'string' ? parseCanonicalUrl(obj.canonical_url) : null;
  if (parsedCanonical == null) {
    return null;
  }

  const canonical = parsedCanonical.canonical;
  const inferredType = parsedCanonical.type;
  let type: LinkType = inferredType;
  if (isValidType(obj.type) && obj.type === inferredType) {
    type = obj.type;
  } else if (isValidType(obj.type) && obj.type !== inferredType) {
    // Persisted records can drift over time; prefer canonical-derived type.
    console.warn('Link record type mismatch with canonical URL', {
      code,
      recordType: obj.type,
      canonicalType: inferredType,
      canonical: canonical.toString(),
    });
  }

  if (!isValidType(type)) {
    return null;
  }

  const preview = normalizePreview(
    type,
    canonical,
    typeof obj.preview === 'object' && obj.preview != null
      ? (obj.preview as CreateLinkPreviewInput)
      : undefined,
    env,
  );

  const version = Number.isInteger(obj.version) ? Number(obj.version) : DEFAULT_OG_VERSION;
  const ogStorage = obj.og_storage === 'r2' || obj.og_storage === 'kv' ? (obj.og_storage as OgStorageType) : null;

  const record: LinkRecord = {
    code,
    type,
    canonical_url: canonical.toString(),
    created_at: typeof obj.created_at === 'string' ? obj.created_at : new Date().toISOString(),
    campaign: typeof obj.campaign === 'object' && obj.campaign != null ? (obj.campaign as Record<string, unknown>) : undefined,
    preview,
    og_image_path: typeof obj.og_image_path === 'string' ? obj.og_image_path : null,
    og_storage: ogStorage,
    version,
  };

  return record;
}

async function persistLinkRecord(code: string, record: LinkRecord, env: Env): Promise<void> {
  await env.LINKS_KV.put(code, JSON.stringify(record));
}

function buildCanonicalUrl(body: CreateLinkRequest): URL | null {
  if (isNonEmptyString(body.canonical_url)) {
    return parseCanonicalUrl(body.canonical_url)?.canonical ?? null;
  }

  if (body.payload == null) {
    return null;
  }

  return buildCanonicalFromPayload(body.type, body.payload);
}

function buildCanonicalFromPayload(type: LinkType, payload: Record<string, unknown>): URL | null {
  if (type === 'share') {
    const canonical = new URL(`https://${DOMAIN}/share`);
    appendPayloadQueryParams(payload, canonical);
    return parseCanonicalFromUrl(canonical)?.canonical ?? null;
  }

  if (type === 'user') {
    const identifier = firstNonEmptyValue(payload, USER_IDENTIFIER_QUERY_KEYS);
    if (identifier.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/user/${encodeURIComponent(identifier)}`);
    appendPayloadQueryParams(payload, canonical, USER_IDENTIFIER_QUERY_KEYS);
    return parseCanonicalFromUrl(canonical)?.canonical ?? null;
  }

  if (type === 'setup') {
    const setupName = firstNonEmptyValue(payload, SETUP_NAME_QUERY_KEYS);
    if (setupName.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/setup/${encodeURIComponent(setupName)}`);
    appendPayloadQueryParams(payload, canonical, SETUP_NAME_QUERY_KEYS);
    return parseCanonicalFromUrl(canonical)?.canonical ?? null;
  }

  const inviterId = firstNonEmptyValue(payload, REFER_IDENTIFIER_QUERY_KEYS);
  if (inviterId.length === 0) {
    return null;
  }
  const canonical = new URL(`https://${DOMAIN}/refer/${encodeURIComponent(inviterId)}`);
  appendPayloadQueryParams(payload, canonical, REFER_IDENTIFIER_QUERY_KEYS);
  return parseCanonicalFromUrl(canonical)?.canonical ?? null;
}

function parseCanonicalUrl(value: string): CanonicalParseResult | null {
  try {
    return parseCanonicalFromUrl(new URL(value));
  } catch {
    return null;
  }
}

function parseCanonicalFromUrl(source: URL): CanonicalParseResult | null {
  if (source.protocol !== 'https:' || source.hostname !== DOMAIN) {
    return null;
  }

  const segments = source.pathname.split('/').filter((segment) => segment.length > 0);
  if (segments.length === 0) {
    return null;
  }

  const root = segments[0];

  if (root === 'share') {
    if (segments.length > 2) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/share`);
    source.searchParams.forEach((value, key) => canonical.searchParams.append(key, value));
    if (segments.length === 2 && !canonical.searchParams.has('id')) {
      const segmentId = decodeCanonicalSegment(segments[1]);
      if (segmentId.length === 0) {
        return null;
      }
      canonical.searchParams.set('id', segmentId);
    }
    return {
      canonical,
      type: 'share',
      canonicalIdentifier: '',
    };
  }

  if (root === 'user') {
    if (segments.length > 2) {
      return null;
    }
    const identifierFromSegment = segments.length === 2 ? decodeCanonicalSegment(segments[1]) : '';
    const identifier = identifierFromSegment || firstNonEmptyQueryParam(source, USER_IDENTIFIER_QUERY_KEYS);
    if (identifier.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/user/${encodeURIComponent(identifier)}`);
    appendQueryParams(source, canonical, USER_IDENTIFIER_QUERY_KEYS);
    return {
      canonical,
      type: 'user',
      canonicalIdentifier: identifier,
    };
  }

  if (root === 'setup') {
    if (segments.length > 2) {
      return null;
    }
    const setupNameFromSegment = segments.length === 2 ? decodeCanonicalSegment(segments[1]) : '';
    const setupName = setupNameFromSegment || firstNonEmptyQueryParam(source, SETUP_NAME_QUERY_KEYS);
    if (setupName.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/setup/${encodeURIComponent(setupName)}`);
    appendQueryParams(source, canonical, SETUP_NAME_QUERY_KEYS);
    return {
      canonical,
      type: 'setup',
      canonicalIdentifier: setupName,
    };
  }

  if (root === 'refer') {
    if (segments.length > 2) {
      return null;
    }
    const inviterIdFromSegment = segments.length === 2 ? decodeCanonicalSegment(segments[1]) : '';
    const inviterId = inviterIdFromSegment || firstNonEmptyQueryParam(source, REFER_IDENTIFIER_QUERY_KEYS);
    if (inviterId.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/refer/${encodeURIComponent(inviterId)}`);
    appendQueryParams(source, canonical, REFER_IDENTIFIER_QUERY_KEYS);
    return {
      canonical,
      type: 'refer',
      canonicalIdentifier: inviterId,
    };
  }

  return null;
}

function appendPayloadQueryParams(
  payload: Record<string, unknown>,
  target: URL,
  excludeKeys: readonly string[] = [],
): void {
  const excludeSet = new Set(excludeKeys.map((key) => key.toLowerCase()));
  for (const [key, value] of Object.entries(payload)) {
    if (excludeSet.has(key.toLowerCase())) {
      continue;
    }
    if (isNonEmptyString(value)) {
      target.searchParams.set(key, value);
    }
  }
}

function appendQueryParams(source: URL, target: URL, excludeKeys: readonly string[] = []): void {
  const excludeSet = new Set(excludeKeys.map((key) => key.toLowerCase()));
  source.searchParams.forEach((value, key) => {
    if (!excludeSet.has(key.toLowerCase())) {
      target.searchParams.append(key, value);
    }
  });
}

function firstNonEmptyQueryParam(url: URL, keys: readonly string[]): string {
  for (const key of keys) {
    const value = url.searchParams.get(key);
    if (isNonEmptyString(value)) {
      return value.trim();
    }
  }
  return '';
}

function firstNonEmptyValue(payload: Record<string, unknown>, keys: readonly string[]): string {
  for (const key of keys) {
    const value = payload[key];
    if (isNonEmptyString(value)) {
      return value.trim();
    }
  }
  return '';
}

function decodeCanonicalSegment(value: string): string {
  try {
    const decoded = decodeURIComponent(value).trim();
    return decoded;
  } catch {
    return '';
  }
}

function normalizePreview(
  type: LinkType,
  canonical: URL,
  input: CreateLinkPreviewInput | undefined,
  env: Env,
): PreviewSnapshot {
  const defaults = buildDefaultPreview(type, canonical, env);
  const merged: PreviewSnapshot = {
    title: clipText(sanitizeText(input?.title ?? defaults.title), 90),
    description: clipText(sanitizeText(input?.description ?? defaults.description), 200),
    image_source_url: sanitizeImageUrl(input?.image_source_url ?? defaults.image_source_url),
    username: clipText(sanitizeText(input?.username ?? defaults.username), 60),
    provider: clipText(sanitizeText(input?.provider ?? defaults.provider), 60),
    wall_id: clipText(sanitizeText(input?.wall_id ?? defaults.wall_id), 60),
    setup_name: clipText(sanitizeText(input?.setup_name ?? defaults.setup_name), 80),
    app_store_url: env.APP_STORE_URL,
    play_store_url: env.PLAY_STORE_URL,
  };

  return merged;
}

function buildDefaultPreview(type: LinkType, canonical: URL, env: Env): PreviewSnapshot {
  const parsedCanonical = parseCanonicalFromUrl(canonical);

  if (type === 'share') {
    const wallId = canonical.searchParams.get('id') ?? 'Wallpaper';
    const provider = canonical.searchParams.get('provider') ?? 'Prism';
    return {
      title: `${wallId} - Prism`,
      description: 'Check out this amazing wallpaper from Prism.',
      image_source_url: canonical.searchParams.get('thumb') ?? canonical.searchParams.get('url') ?? '',
      username: '',
      provider,
      wall_id: wallId,
      setup_name: '',
      app_store_url: env.APP_STORE_URL,
      play_store_url: env.PLAY_STORE_URL,
    };
  }

  if (type === 'setup') {
    const setupName = parsedCanonical?.type === 'setup'
      ? parsedCanonical.canonicalIdentifier
      : canonical.searchParams.get('name') ?? 'Prism Setup';
    return {
      title: `${setupName} - Prism`,
      description: 'Check out this setup shared from Prism.',
      image_source_url: canonical.searchParams.get('thumbUrl') ?? '',
      username: '',
      provider: '',
      wall_id: '',
      setup_name: setupName,
      app_store_url: env.APP_STORE_URL,
      play_store_url: env.PLAY_STORE_URL,
    };
  }

  if (type === 'user') {
    const username = parsedCanonical?.type === 'user'
      ? parsedCanonical.canonicalIdentifier
      : canonical.searchParams.get('username') ?? canonical.searchParams.get('email') ?? 'artist';
    return {
      title: `@${username} on Prism`,
      description: 'Check out this creator profile on Prism.',
      image_source_url: '',
      username,
      provider: '',
      wall_id: '',
      setup_name: '',
      app_store_url: env.APP_STORE_URL,
      play_store_url: env.PLAY_STORE_URL,
    };
  }

  return {
    title: 'Prism Invite',
    description: 'Install Prism and discover amazing wallpapers and setups.',
    image_source_url: '',
    username: '',
    provider: '',
    wall_id: '',
    setup_name: '',
    app_store_url: env.APP_STORE_URL,
    play_store_url: env.PLAY_STORE_URL,
  };
}

function sanitizeText(value: string): string {
  return value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function clipText(value: string, max: number): string {
  if (value.length <= max) {
    return value;
  }
  return `${value.slice(0, Math.max(0, max - 1))}…`;
}

function sanitizeImageUrl(value: string): string {
  if (!isNonEmptyString(value)) {
    return '';
  }
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
      return '';
    }
    return parsed.toString();
  } catch {
    return '';
  }
}

async function generateUniqueCode(env: Env): Promise<string> {
  for (let i = 0; i < 10; i += 1) {
    const code = generateCode(8);
    const existing = await env.LINKS_KV.get(code);
    if (existing == null) {
      return code;
    }
  }
  return `${Date.now().toString(36)}${generateCode(2)}`.slice(0, 10);
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

async function generateAndPersistOgImage(code: string, record: LinkRecord, env: Env): Promise<OgStorageType | null> {
  const pngBytes = await renderOgImageWithBrowserRendering(code, record, env);
  if (pngBytes == null) {
    return null;
  }

  const objectKey = ogObjectKey(code, record.version);
  if (env.OG_IMAGES != null) {
    await env.OG_IMAGES.put(objectKey, pngBytes, {
      httpMetadata: {
        contentType: 'image/png',
        cacheControl: 'public, max-age=31536000, immutable',
      },
    });
    return 'r2';
  }

  const kvPayload = toBase64(pngBytes);
  await env.LINKS_KV.put(`og:${objectKey}`, kvPayload);
  return 'kv';
}

async function fetchOgImageFromStorage(code: string, record: LinkRecord, env: Env): Promise<Response | null> {
  const objectKey = ogObjectKey(code, record.version);

  if (record.og_storage === 'r2' && env.OG_IMAGES != null) {
    const object = await env.OG_IMAGES.get(objectKey);
    if (object != null) {
      return new Response(object.body, {
        headers: {
          'content-type': object.httpMetadata?.contentType ?? 'image/png',
          'cache-control': object.httpMetadata?.cacheControl ?? 'public, max-age=31536000, immutable',
        },
      });
    }
  }

  if (record.og_storage === 'kv') {
    const base64 = await env.LINKS_KV.get(`og:${objectKey}`);
    if (isNonEmptyString(base64)) {
      return new Response(fromBase64(base64), {
        headers: {
          'content-type': 'image/png',
          'cache-control': 'public, max-age=31536000, immutable',
        },
      });
    }
  }

  return null;
}

async function renderOgImageWithBrowserRendering(code: string, record: LinkRecord, env: Env): Promise<Uint8Array | null> {
  if (!isNonEmptyString(env.BROWSER_RENDERING_ACCOUNT_ID) || !isNonEmptyString(env.BROWSER_RENDERING_API_TOKEN)) {
    return null;
  }

  const endpoint = `https://api.cloudflare.com/client/v4/accounts/${env.BROWSER_RENDERING_ACCOUNT_ID}/browser-rendering/screenshot`;
  const htmlTemplate = renderOgCardHtml(record, code);

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.BROWSER_RENDERING_API_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      html: htmlTemplate,
      viewport: {
        width: 1200,
        height: 630,
      },
      screenshotOptions: {
        type: 'png',
      },
    }),
  });

  if (!response.ok) {
    console.warn('Browser rendering screenshot failed', response.status, await response.text());
    return null;
  }

  return new Uint8Array(await response.arrayBuffer());
}

function renderOgCardHtml(record: LinkRecord, code: string): string {
  const preview = record.preview;
  const title = escapeHtml(preview.title || 'Prism');
  const description = escapeHtml(preview.description || 'Discover amazing wallpapers on Prism.');
  const subtitle = escapeHtml(buildSubtitle(record));
  const image = isNonEmptyString(preview.image_source_url) ? preview.image_source_url : PRISM_APP_ICON_URL;
  const cta = escapeHtml(buildCtaText(record.type));
  const typeBadge = escapeHtml(record.type.toUpperCase());

  return `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    width: 1200px;
    height: 630px;
    background: #0a0b14;
    color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
    overflow: hidden;
  }
</style>
</head>
<body>
  <img src="${escapeAttribute(image)}" alt="bg" style="position:absolute;inset:-40px;width:1280px;height:710px;object-fit:cover;filter:blur(32px) brightness(.45) saturate(1.2);" />
  <div style="position:absolute;inset:0;background:linear-gradient(120deg,rgba(9,10,20,.85) 0%, rgba(18,20,34,.73) 40%, rgba(13,14,25,.88) 100%);"></div>
  <div style="position:absolute;inset:0;padding:42px 48px;display:flex;gap:34px;">
    <div style="flex:1;display:flex;flex-direction:column;min-width:0;">
      <div style="display:flex;align-items:center;gap:14px;">
        <img src="${escapeAttribute(PRISM_APP_ICON_URL)}" alt="Prism" style="width:52px;height:52px;border-radius:12px;box-shadow:0 8px 22px rgba(0,0,0,.35);" />
        <div style="font-size:40px;font-weight:800;letter-spacing:.2px;">Prism</div>
        <div style="margin-left:10px;padding:7px 12px;border-radius:999px;border:1px solid rgba(255,255,255,.2);font-size:14px;font-weight:700;letter-spacing:.8px;color:#efeaff;background:rgba(255,255,255,.07);">${typeBadge}</div>
      </div>
      <div style="margin-top:24px;font-size:62px;font-weight:850;line-height:1.02;letter-spacing:-.8px;max-width:700px;white-space:pre-wrap;">${title}</div>
      <div style="margin-top:14px;font-size:30px;font-weight:600;color:#cfc8ff;">${subtitle}</div>
      <div style="margin-top:16px;font-size:28px;line-height:1.28;color:#ece9ff;max-width:760px;">${description}</div>
      <div style="margin-top:auto;display:flex;align-items:center;gap:14px;">
        <div style="padding:14px 18px;border-radius:14px;background:linear-gradient(90deg,#7f6cf9 0%,#8a5fff 45%,#6f8dff 100%);font-size:22px;font-weight:800;box-shadow:0 10px 24px rgba(94,76,214,.35);">${cta}</div>
        <div style="font-size:22px;color:#c4bdf3;">prismwalls.com/l/${escapeHtml(code)}</div>
      </div>
    </div>
    <div style="width:390px;display:flex;align-items:center;justify-content:center;">
      <div style="position:relative;width:350px;height:520px;border-radius:24px;padding:9px;background:linear-gradient(160deg,rgba(255,255,255,.55),rgba(255,255,255,.06));box-shadow:0 18px 34px rgba(0,0,0,.45);">
        <div style="position:absolute;inset:9px;border-radius:16px;overflow:hidden;background:#111;">
          <img src="${escapeAttribute(image)}" alt="preview" style="width:100%;height:100%;object-fit:cover;" />
        </div>
        <div style="position:absolute;left:16px;right:16px;bottom:18px;padding:12px 14px;border-radius:12px;background:rgba(5,6,12,.62);backdrop-filter:blur(6px);font-size:17px;font-weight:700;color:#f0efff;line-height:1.25;border:1px solid rgba(255,255,255,.2);">
          Open in Prism app to view full quality
        </div>
      </div>
    </div>
  </div>
</body>
</html>`;
}

function buildSubtitle(record: LinkRecord): string {
  if (record.type === 'share') {
    const left = record.preview.wall_id || 'Wallpaper';
    const right = record.preview.provider || 'Prism';
    return `${left} · ${right}`;
  }
  if (record.type === 'setup') {
    return record.preview.setup_name || 'Setup';
  }
  if (record.type === 'user') {
    return record.preview.username ? `@${record.preview.username}` : 'Creator profile';
  }
  return 'Invite';
}

function buildCtaText(type: LinkType): string {
  if (type === 'share') {
    return 'Open Wallpaper in Prism';
  }
  if (type === 'setup') {
    return 'Open Setup in Prism';
  }
  if (type === 'user') {
    return 'View Creator in Prism';
  }
  return 'Install Prism App';
}

function renderCrawlerPreviewHtml(code: string, record: LinkRecord, env: Env): string {
  const shortUrl = `https://${DOMAIN}/l/${code}`;
  const canonicalUrl = record.canonical_url;
  const title = escapeHtml(record.preview.title || 'Prism');
  const description = escapeHtml(record.preview.description || 'Discover Prism.');
  const ogImage = escapeAttribute(getOgImageUrl(record, env));

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <meta property="og:title" content="${escapeAttribute(title)}" />
  <meta property="og:description" content="${escapeAttribute(description)}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="${escapeAttribute(shortUrl)}" />
  <meta property="og:image" content="${ogImage}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta property="og:site_name" content="Prism" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeAttribute(title)}" />
  <meta name="twitter:description" content="${escapeAttribute(description)}" />
  <meta name="twitter:image" content="${ogImage}" />
  <link rel="canonical" href="${escapeAttribute(shortUrl)}" />
  <meta name="robots" content="noindex,nofollow" />
</head>
<body>
  <p>Redirecting to ${escapeHtml(canonicalUrl)}</p>
</body>
</html>`;
}

function renderHumanLandingHtml(code: string, record: LinkRecord, request: Request, env: Env): string {
  const shortUrl = `https://${DOMAIN}/l/${code}`;
  const canonicalUrl = record.canonical_url;
  const title = escapeHtml(record.preview.title || 'Prism');
  const description = escapeHtml(record.preview.description || 'Opening Prism...');
  const ogImage = escapeAttribute(getOgImageUrl(record, env));
  const storeUrl = escapeAttribute(selectStoreUrl(request, env));
  const canonicalEscaped = escapeAttribute(canonicalUrl);

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <meta property="og:title" content="${escapeAttribute(title)}" />
  <meta property="og:description" content="${escapeAttribute(description)}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="${escapeAttribute(shortUrl)}" />
  <meta property="og:image" content="${ogImage}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeAttribute(title)}" />
  <meta name="twitter:description" content="${escapeAttribute(description)}" />
  <meta name="twitter:image" content="${ogImage}" />
  <link rel="canonical" href="${escapeAttribute(shortUrl)}" />
  <meta http-equiv="refresh" content="0;url=${canonicalEscaped}" />
  <script>
    (function() {
      var canonicalUrl = ${JSON.stringify(canonicalUrl)};
      var storeUrl = ${JSON.stringify(selectStoreUrl(request, env))};
      setTimeout(function() {
        window.location.replace(storeUrl);
      }, 1200);
      window.location.replace(canonicalUrl);
    })();
  </script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; background: #0f1020; color: #f7f7ff; }
    main { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; }
    .card { max-width: 560px; width: 100%; background: #1b1c33; border: 1px solid #2f315f; border-radius: 16px; padding: 24px; }
    h1 { margin: 0 0 8px; font-size: 24px; }
    p { margin: 0 0 20px; color: #d5d6f3; }
    a { color: #b9b6ff; }
  </style>
</head>
<body>
  <main>
    <div class="card">
      <h1>${title}</h1>
      <p>${description}</p>
      <p>If Prism does not open automatically, <a href="${canonicalEscaped}">open link</a> or <a href="${storeUrl}">install Prism</a>.</p>
    </div>
  </main>
</body>
</html>`;
}

function isCrawlerRequest(request: Request): boolean {
  const userAgent = request.headers.get('user-agent')?.toLowerCase() ?? '';
  return BOT_UA_FRAGMENTS.some((fragment) => userAgent.includes(fragment));
}

function getOgImageUrl(record: LinkRecord, env: Env): string {
  if (isNonEmptyString(record.code)) {
    return `https://${DOMAIN}/og/${record.code}.png`;
  }
  if (isNonEmptyString(record.preview.image_source_url)) {
    return record.preview.image_source_url;
  }
  if (isNonEmptyString(env.OG_FALLBACK_IMAGE)) {
    return env.OG_FALLBACK_IMAGE;
  }
  return PRISM_APP_ICON_URL;
}

function selectStoreUrl(request: Request, env: Env): string {
  const userAgent = request.headers.get('user-agent')?.toLowerCase() ?? '';
  if (userAgent.includes('iphone') || userAgent.includes('ipad') || userAgent.includes('ipod')) {
    return env.APP_STORE_URL;
  }
  return env.PLAY_STORE_URL;
}

function mapRouteFromType(type: LinkType): string {
  if (type === 'share') {
    return '/share';
  }
  if (type === 'setup') {
    return '/share-setup';
  }
  if (type === 'user') {
    return '/follower-profile';
  }
  return '';
}

function mapRouteV2FromType(type: LinkType): string {
  if (type === 'share') {
    return '/share';
  }
  if (type === 'setup') {
    return '/setup/:setupName';
  }
  if (type === 'user') {
    return '/user/:identifier';
  }
  return '/refer/:inviterId';
}

function ogObjectKey(code: string, version: number): string {
  return `${code}-v${version}.png`;
}

function getClientIp(request: Request): string {
  return (
    request.headers.get('CF-Connecting-IP') ??
    request.headers.get('x-forwarded-for')?.split(',')[0].trim() ??
    'unknown'
  );
}

function isValidType(type: unknown): type is LinkType {
  return type === 'share' || type === 'user' || type === 'setup' || type === 'refer';
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtml(value).replaceAll('`', '&#96;');
}

function toBase64(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.length; i += 1) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
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

function html(markup: string, status = 200): Response {
  return new Response(markup, {
    status,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'private, no-store, max-age=0',
    },
  });
}
