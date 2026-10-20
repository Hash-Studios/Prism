import { AiQuotaCoordinator, type AiEnvBindings, bumpRateLimit, handleAiApiRequest } from './ai';
import { maybeHandleAssociationRequest } from './association_files';
import { formatCount, type OgCard, type OgChip, type OgStat, renderOgCardHtml } from './og_card';

export interface Env extends AiEnvBindings {
  LINKS_KV: KVNamespace;
  OG_IMAGES?: R2Bucket;
  R2_PREVIEW_BASE_URL?: string;
  GH_USERNAME?: string;
  GH_REPO_WALLS?: string;
  PLAY_STORE_URL: string;
  APP_STORE_URL: string;
  OG_FALLBACK_IMAGE?: string;
  BROWSER_RENDERING_ACCOUNT_ID?: string;
  BROWSER_RENDERING_API_TOKEN?: string;
}

type LinkType = 'share' | 'user' | 'setup' | 'refer' | 'page';
type OgStorageType = 'r2' | 'kv';

interface CreateLinkPreviewInput {
  title?: string;
  description?: string;
  image_source_url?: string;
  username?: string;
  provider?: string;
  wall_id?: string;
  setup_name?: string;
  creator_name?: unknown;
  creator_photo_url?: unknown;
  resolution?: unknown;
  follower_count?: unknown;
  wallpaper_count?: unknown;
  gallery?: unknown;
}

interface CreateLinkRequest {
  type: LinkType;
  canonical_url?: string;
  payload?: Record<string, unknown>;
  campaign?: Record<string, unknown>;
  preview?: CreateLinkPreviewInput;
}

interface PreviewDefaults {
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

interface PreviewSnapshot extends PreviewDefaults {
  creator_name: string;
  creator_photo_url: string;
  resolution: string;
  follower_count: number | null;
  wallpaper_count: number | null;
  gallery: string[];
}

interface WallpaperStats {
  views: number | null;
  favs: number | null;
  downloads: number | null;
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
// Keep in sync with AppRouter and DeepLinkParser. Root and website-only paths are intentionally excluded.
const APP_PAGE_PATHS = [
  '/onboarding/v2', '/dashboard', '/dashboard/home', '/dashboard/search', '/dashboard/search/users',
  '/dashboard/rewards', '/dashboard/streak', '/dashboard/collection', '/ai', '/wallpaper-detail',
  '/wotd-archive', '/download-wallpaper', '/wallpaper-filter', '/choose-wallpaper', '/edit-profile', '/share-prism', '/settings',
  '/premium', '/paywall',
  '/blocked-accounts', '/about', '/fav-walls', '/downloads', '/library', '/upload-wall', '/edit-wall', '/review',
  '/coin-transactions', '/theme', '/notifications', '/collection-view', '/followers', '/following',
  '/admin-review', '/admin-review/swipe', '/admin-review/image', '/admin-firestore-telemetry', '/debug-panel',
  '/daily-chest', '/spin-wheel', '/photo-preview', '/clock-preview', '/quick-tile-settings',
  '/auto-rotate', '/ios-shortcuts', '/wallpaper-history', '/wallpaper-position', '/live-wallpaper', '/rewards',
  '/coin-history', '/shop', '/drops', '/leaderboard', '/draw', '/streak', '/not-found',
];
const APP_LINK_PATHS = [
  '/share', '/user', '/fprofile', '/follower-profile', '/profile', '/setup', '/share-setup', '/refer', '/referral',
  '/collection', '/category', '/wallpaper', '/l', ...APP_PAGE_PATHS,
];
const PAGE_PARAMETER_ROOTS = new Set(['drops']);
const PAGE_IDENTIFIER_ROOTS = new Set(['user', 'fprofile', 'follower-profile', 'profile']);
const PAGE_QUERY_KEYS = new Map<string, Set<string>>([
  ['/wallpaper-detail', new Set(['wallId', 'id', 'source', 'provider'])],
  ['/wallpaper-position', new Set(['wallpaperId', 'source', 'provider', 'entryPoint'])],
  ['/download-wallpaper', new Set(['wallpaperId', 'source', 'provider'])],
  ['/live-wallpaper', new Set(['wallpaperId', 'source', 'provider'])],
  ['/library', new Set(['tab'])],
  ['/choose-wallpaper', new Set(['workflow'])],
  ['/debug-panel', new Set(['tab'])],
  ['/admin-review/image', new Set(['wallpaperId', 'source', 'provider'])],
  ['/fprofile', new Set(['identifier', 'username', 'user', 'email'])],
  ['/follower-profile', new Set(['identifier', 'username', 'user', 'email'])],
  ['/profile', new Set(['identifier', 'username', 'user', 'email'])],
  ['/share-setup', new Set(['name', 'setupName', 'setup_name'])],
  ['/referral', new Set(['inviterId', 'userID', 'userId', 'userid', 'id'])],
  ['/collection-view', new Set(['collectionName', 'name'])],
  ['/followers', new Set(['user', 'identifier'])],
  ['/following', new Set(['user', 'identifier'])],
  ['/wallpaper', new Set(['wallpaperId', 'source', 'provider', 'entryPoint'])],
  ['/photo-preview', new Set(['wallpaperId', 'source', 'provider'])],
  ['/clock-preview', new Set(['wallpaperId', 'source', 'provider'])],
]);
const PAGE_UTM_KEYS = new Set(['utm_source', 'utm_medium', 'utm_campaign']);
const ANDROID_PACKAGE = 'com.hash.prism';
const PREVIEW_IMAGE_HOSTS = new Set([
  'raw.githubusercontent.com',
  'images.pexels.com',
  'w.wallhaven.cc',
  'th.wallhaven.cc',
  'prismwalls.com',
  'lh3.googleusercontent.com',
  'lh4.googleusercontent.com',
  'lh5.googleusercontent.com',
  'lh6.googleusercontent.com',
  'firebasestorage.googleapis.com',
]);
const SHORT_CODE_REGEX = /^[A-Za-z0-9]{7,10}$/;
const DEFAULT_OG_VERSION = 1;
// Bump when the card design changes: old links then render a new card under a new image URL.
const OG_CARD_VERSION = 2;
const OG_ASSET_BASE = 'https://raw.githubusercontent.com/Hash-Studios/Prism/master/web/public/assets/og';
const INVITE_GALLERY = [1, 2, 3].map((n) => `${OG_ASSET_BASE}/invite-${n}.jpg`);
const GALLERY_MAX_ITEMS = 4;
const WALLPAPER_STATS_TIMEOUT_MS = 4000;
const IOS_APP_ID = '1405860595';
const CREATE_LINK_MAX_BODY_BYTES = 8 * 1024;
const CAMPAIGN_MAX_KEYS = 10;
const CAMPAIGN_MAX_TEXT_LENGTH = 100;
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

    if (request.method === 'GET' && url.pathname === '/l') {
      const code = shortCodeFromQuery(url);
      if (code == null) return html(renderUnavailableHtml(request, env), 400);
      return resolveShortLink(`/l/${code}`, request, env);
    }

    if (request.method === 'GET' && url.pathname.startsWith('/l/')) {
      return resolveShortLink(url.pathname, request, env);
    }

    const isAppLinkPath = APP_LINK_PATHS.some((path) => url.pathname === path || url.pathname.startsWith(`${path}/`));
    if (request.method === 'GET' && isAppLinkPath) {
      return renderDirectLanding(url, request, env);
    }

    const workerOwnedPath = ['/api', '/og', '/l', '/.well-known'].some(
      (path) => url.pathname === path || url.pathname.startsWith(`${path}/`),
    ) || url.pathname === '/apple-app-site-association';
    if (isAppLinkPath || workerOwnedPath) return new Response('Not found', { status: 404 });

    return fetch(request);
  },
};

export { AiQuotaCoordinator };

async function createLink(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const ip = getClientIp(request);
  const withinRateLimit = await enforceCreateRateLimits(ip, env);
  if (!withinRateLimit) {
    return json({ error: 'rate_limited' }, 429);
  }

  const declaredLength = Number.parseInt(request.headers.get('content-length') ?? '', 10);
  if (declaredLength > CREATE_LINK_MAX_BODY_BYTES) {
    return json({ error: 'payload_too_large' }, 413);
  }
  const rawBody = await readBoundedText(request, CREATE_LINK_MAX_BODY_BYTES);
  if (rawBody == null) {
    return json({ error: 'payload_too_large' }, 413);
  }

  let body: CreateLinkRequest;
  try {
    body = JSON.parse(rawBody) as CreateLinkRequest;
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }
  if (typeof body !== 'object' || body == null) {
    return json({ error: 'invalid_json' }, 400);
  }

  if (!isValidType(body.type)) {
    return json({ error: 'invalid_type' }, 400);
  }

  const canonical = buildCanonicalUrl(body, env);
  const parsedCanonical = canonical != null ? parseCanonicalFromUrl(canonical, env) : null;
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
    campaign: sanitizeCampaign(body.campaign),
    preview,
    og_image_path: null,
    og_storage: null,
    version: OG_CARD_VERSION,
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
        og_image_path: `/og/${code}.jpg`,
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

async function readBoundedText(request: Request, maxBytes: number): Promise<string | null> {
  if (request.body == null) {
    return '';
  }
  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  let received = 0;
  let text = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) {
      return text + decoder.decode();
    }
    received += value.byteLength;
    if (received > maxBytes) {
      await reader.cancel();
      return null;
    }
    text += decoder.decode(value, { stream: true });
  }
}

function sanitizeCampaign(raw: unknown): Record<string, string> | undefined {
  if (typeof raw !== 'object' || raw == null || Array.isArray(raw)) {
    return undefined;
  }
  const entries = Object.entries(raw);
  if (entries.length > CAMPAIGN_MAX_KEYS) {
    return undefined;
  }
  for (const [key, value] of entries) {
    if (key.length > CAMPAIGN_MAX_TEXT_LENGTH || typeof value !== 'string' || value.length > CAMPAIGN_MAX_TEXT_LENGTH) {
      return undefined;
    }
  }
  return Object.fromEntries(entries) as Record<string, string>;
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

  const parsedCanonical = parseCanonicalUrl(record.canonical_url, env);
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
    route: record.type === 'page' ? canonical.pathname : mapRouteFromType(record.type),
    route_v2: parsedCanonical.type === 'page' ? canonical.pathname : mapRouteV2FromType(parsedCanonical.type),
    canonical_identifier: parsedCanonical.canonicalIdentifier,
    og_image_url: getOgImageUrl(record, env),
    preview: record.preview,
  });
}

async function resolveShortLink(pathname: string, request: Request, env: Env): Promise<Response> {
  const code = pathname.replace('/l/', '').trim();
  if (!SHORT_CODE_REGEX.test(code)) {
    return html(renderUnavailableHtml(request, env), 400);
  }

  const record = await readLinkRecord(code, env);
  if (record == null) {
    return html(renderUnavailableHtml(request, env), 404);
  }

  if (isCrawlerRequest(request)) {
    return html(renderCrawlerPreviewHtml(code, record, env));
  }

  return html(renderHumanLandingHtml(`https://${DOMAIN}/l/${code}`, record, request, env));
}

async function getOgImage(pathname: string, method: string, env: Env): Promise<Response> {
  const codePart = pathname.replace('/og/', '').trim();
  const extension = ['.jpg', '.png'].find((ext) => codePart.endsWith(ext));
  if (extension == null) {
    return new Response('Not found', { status: 404 });
  }

  const code = codePart.slice(0, -extension.length).trim();
  if (!SHORT_CODE_REGEX.test(code)) {
    return new Response('Invalid code', { status: 400 });
  }

  const record = await readLinkRecord(code, env);
  if (record == null) {
    return new Response('Not found', { status: 404 });
  }

  if (record.version === OG_CARD_VERSION) {
    const fromStorage = await fetchOgImageFromStorage(code, record, env);
    if (fromStorage != null) {
      return imageResponse(fromStorage, method);
    }
  }

  const generatedStorage = await generateAndPersistOgImage(code, record, env);
  if (generatedStorage != null) {
    const updated: LinkRecord = {
      ...record,
      og_image_path: `/og/${code}.jpg`,
      og_storage: generatedStorage,
      version: OG_CARD_VERSION,
    };
    await persistLinkRecord(code, updated, env);

    const generated = await fetchOgImageFromStorage(code, updated, env);
    if (generated != null) {
      return imageResponse(generated, method);
    }
  }

  // The new card failed to render: an older card is still better than the fallback. Cache it only briefly,
  // because the versioned URL gets the new card once a render succeeds.
  if (record.version !== OG_CARD_VERSION) {
    const legacy = await fetchOgImageFromStorage(code, record, env);
    if (legacy != null) {
      const headers = new Headers(legacy.headers);
      headers.set('cache-control', 'public, max-age=300');
      return imageResponse(new Response(legacy.body, { status: legacy.status, headers }), method);
    }
  }

  const fallback = record.preview.image_source_url || env.OG_FALLBACK_IMAGE;
  if (isNonEmptyString(fallback)) {
    return Response.redirect(fallback, 302);
  }

  return new Response('No preview image available', { status: 404 });
}

function imageResponse(response: Response, method: string): Response {
  if (method === 'HEAD') {
    return new Response(null, { status: response.status, headers: response.headers });
  }
  return response;
}

function fallbackToStore(request: Request, env: Env): Response {
  return Response.redirect(selectStoreUrl(request, env), 302);
}

function renderDirectLanding(url: URL, request: Request, env: Env): Response {
  const parsed = parseCanonicalUrl(`https://${DOMAIN}${url.pathname}${url.search}`, env);
  if (parsed == null) {
    return fallbackToStore(request, env);
  }
  const record: LinkRecord = {
    code: '',
    type: parsed.type,
    canonical_url: parsed.canonical.toString(),
    created_at: new Date().toISOString(),
    preview: normalizePreview(parsed.type, parsed.canonical, undefined, env),
    version: DEFAULT_OG_VERSION,
  };
  return html(renderHumanLandingHtml(record.canonical_url, record, request, env));
}

async function enforceCreateRateLimits(ip: string, env: Env): Promise<boolean> {
  const tenMinuteOk = await bumpRateCounter(env, `rl:10m:${ip}`, 20, 600);
  if (!tenMinuteOk) {
    return false;
  }
  return bumpRateCounter(env, `rl:1d:${ip}`, 200, 86400);
}

async function bumpRateCounter(env: Env, key: string, limit: number, ttlSeconds: number): Promise<boolean> {
  try {
    return await bumpRateLimit(env, key, limit, ttlSeconds);
  } catch (error) {
    console.warn('Durable Object rate limit failed, using KV counter', error);
  }
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
  const parsedCanonical = typeof obj.canonical_url === 'string' ? parseCanonicalUrl(obj.canonical_url, env) : null;
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

function buildCanonicalUrl(body: CreateLinkRequest, env: Env): URL | null {
  if (isNonEmptyString(body.canonical_url)) {
    return parseCanonicalUrl(body.canonical_url, env)?.canonical ?? null;
  }

  if (body.payload == null) {
    return null;
  }

  return buildCanonicalFromPayload(body.type, body.payload, env);
}

function buildCanonicalFromPayload(type: LinkType, payload: Record<string, unknown>, env: Env): URL | null {
  if (type === 'page') {
    const path = payload.path;
    if (!isNonEmptyString(path) || !path.startsWith('/') || path.startsWith('//')) {
      return null;
    }
    let candidate: URL;
    try {
      candidate = new URL(path, `https://${DOMAIN}`);
    } catch {
      return null;
    }
    if (candidate.origin !== `https://${DOMAIN}` || candidate.hash) {
      return null;
    }
    const canonical = parseCanonicalFromUrl(candidate, env);
    if (canonical?.type !== 'page') {
      return null;
    }
    appendPayloadQueryParams(payload, canonical.canonical, ['path']);
    return parseCanonicalFromUrl(canonical.canonical, env)?.canonical ?? null;
  }

  if (type === 'share') {
    const canonical = new URL(`https://${DOMAIN}/share`);
    appendPayloadQueryParams(payload, canonical);
    return parseCanonicalFromUrl(canonical, env)?.canonical ?? null;
  }

  if (type === 'user') {
    const identifier = firstNonEmptyValue(payload, USER_IDENTIFIER_QUERY_KEYS);
    if (identifier.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/user/${encodeURIComponent(identifier)}`);
    appendPayloadQueryParams(payload, canonical, USER_IDENTIFIER_QUERY_KEYS);
    return parseCanonicalFromUrl(canonical, env)?.canonical ?? null;
  }

  if (type === 'setup') {
    const setupName = firstNonEmptyValue(payload, SETUP_NAME_QUERY_KEYS);
    if (setupName.length === 0) {
      return null;
    }
    const canonical = new URL(`https://${DOMAIN}/setup/${encodeURIComponent(setupName)}`);
    appendPayloadQueryParams(payload, canonical, SETUP_NAME_QUERY_KEYS);
    return parseCanonicalFromUrl(canonical, env)?.canonical ?? null;
  }

  const inviterId = firstNonEmptyValue(payload, REFER_IDENTIFIER_QUERY_KEYS);
  if (inviterId.length === 0) {
    return null;
  }
  const canonical = new URL(`https://${DOMAIN}/refer/${encodeURIComponent(inviterId)}`);
  appendPayloadQueryParams(payload, canonical, REFER_IDENTIFIER_QUERY_KEYS);
  return parseCanonicalFromUrl(canonical, env)?.canonical ?? null;
}

function parseCanonicalUrl(value: string, env: Env): CanonicalParseResult | null {
  try {
    return parseCanonicalFromUrl(new URL(value), env);
  } catch {
    return null;
  }
}

function parseCanonicalFromUrl(source: URL, env: Env): CanonicalParseResult | null {
  if (source.protocol !== 'https:' || (source.hostname !== DOMAIN && source.hostname !== `www.${DOMAIN}`)) {
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
    source.searchParams.forEach((value, key) => {
      if (key !== 'url') canonical.searchParams.append(key, value);
    });
    if (segments.length === 2 && !canonical.searchParams.has('id')) {
      const segmentId = decodeCanonicalSegment(segments[1]);
      if (segmentId.length === 0) {
        return null;
      }
      canonical.searchParams.set('id', segmentId);
    }
    const provider = (canonical.searchParams.get('source') || canonical.searchParams.get('provider') || 'prism').toLowerCase();
    const thumb = canonical.searchParams.get('thumb') ?? '';
    canonical.searchParams.set('thumb', sanitizeShareImageUrl(thumb, env, provider));
    return {
      canonical,
      type: 'share',
      canonicalIdentifier: '',
    };
  }

  if (root === 'user') {
    if (segments.length === 3 && ['followers', 'following'].includes(segments[2])) {
      // Relationship routes are catalogued app pages, not profile-share links.
    } else if (segments.length > 2) {
      return null;
    } else {
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
  }

  if (root === 'setup') {
    if (segments.length > 2) {
      return null;
    }
    const setupNameFromSegment = segments.length === 2 ? decodeCanonicalSegment(segments[1]) : '';
    const setupName = setupNameFromSegment || firstNonEmptyQueryParam(source, SETUP_NAME_QUERY_KEYS);
    if (setupName.length === 0) {
      if (segments.length === 2) return null;
      const canonical = new URL(`https://${DOMAIN}/setup`);
      source.searchParams.forEach((value, key) => canonical.searchParams.append(key, value));
      return { canonical, type: 'setup', canonicalIdentifier: '' };
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

  if (isAllowedAppPage(segments, source)) {
    if (!hasAllowedPageQuery(segments, source)) return null;
    const canonical = new URL(`https://${DOMAIN}${source.pathname}`);
    source.searchParams.forEach((value, key) => canonical.searchParams.append(key, value));
    return { canonical, type: 'page', canonicalIdentifier: '' };
  }

  return null;
}

function isAllowedAppPage(segments: string[], url: URL): boolean {
  if (segments.length === 0) return false;
  const path = `/${segments.join('/')}`;
  if (APP_PAGE_PATHS.includes(path)) return true;
  if (PAGE_IDENTIFIER_ROOTS.has(segments[0]) && segments.length === 2 && isSafePathSegment(segments[1])) return true;
  if (PAGE_IDENTIFIER_ROOTS.has(segments[0]) && segments.length === 1 && url.searchParams.size > 0) return true;
  if (PAGE_PARAMETER_ROOTS.has(segments[0]) && segments.length === 2 && isSafePathSegment(segments[1])) return true;
  if (segments.length === 2 && ['collection', 'category', 'wallpaper'].includes(segments[0]) && isSafePathSegment(segments[1])) {
    return true;
  }
  if (segments.length === 3 && segments[0] === 'user' && ['followers', 'following'].includes(segments[2])
      && isSafePathSegment(segments[1])) return true;
  if (segments.length === 3 && segments[0] === 'wallpaper'
      && ['position', 'download', 'live'].includes(segments[2]) && isSafePathSegment(segments[1])) return true;
  if (segments.length === 4 && segments[0] === 'drops' && segments[2] === 'preview'
      && isSafePathSegment(segments[1]) && isSafePathSegment(segments[3])) return true;
  // Preserve the legacy link aliases handled by DeepLinkParser.
  if (['share-setup', 'setup', 'refer', 'referral'].includes(segments[0])) {
    if (segments.length === 2 && isSafePathSegment(segments[1])) return true;
    if (segments.length === 1 && segments[0] === 'share-setup') return true;
    if (segments.length === 1 && url.searchParams.size > 0) return true;
  }
  if (segments[0] === 'l' && segments.length === 2 && SHORT_CODE_REGEX.test(segments[1])) return true;
  return false;
}

function hasAllowedPageQuery(segments: string[], url: URL): boolean {
  const routePath = `/${segments.join('/')}`;
  const queryRoute = segments[0] === 'user' && segments.length === 3
    ? `/${segments[2]}`
    : PAGE_IDENTIFIER_ROOTS.has(segments[0]) && segments[0] !== 'user'
      ? `/${segments[0]}`
      : ['share-setup', 'referral'].includes(segments[0])
        ? `/${segments[0]}`
    : segments[0] === 'wallpaper'
      ? '/wallpaper'
      : routePath;
  const allowed = PAGE_QUERY_KEYS.get(queryRoute) ?? new Set<string>();
  for (const key of url.searchParams.keys()) {
    if (url.searchParams.getAll(key).length !== 1) return false;
    if (!allowed.has(key) && !PAGE_UTM_KEYS.has(key)) return false;
  }
  const queryValue = (...keys: string[]) => keys.map((key) => url.searchParams.get(key)).find(isNonEmptyString) ?? '';
  if (queryRoute === '/library' && url.searchParams.has('tab')
      && !['favourites', 'downloads', 'history'].includes(url.searchParams.get('tab')?.toLowerCase() ?? '')) return false;
  if (queryRoute === '/choose-wallpaper' && ![
    'uploadWall', 'editWall', 'wallpaperFilter', 'downloadWallpaper', 'wallpaperPosition', 'liveWallpaper',
    'clockPreview', 'photoPreview',
  ].includes(url.searchParams.get('workflow') ?? '')) return false;
  if (queryRoute === '/debug-panel' && url.searchParams.has('tab')
      && !['logs', 'tools', 'storage', 'app-info', 'mascot'].includes(url.searchParams.get('tab') ?? '')) return false;
  if (queryRoute === '/wallpaper-detail' && !queryValue('wallId', 'id')) return false;
  if (queryRoute === '/collection-view' && !queryValue('collectionName', 'name')) return false;
  if ((queryRoute === '/followers' || queryRoute === '/following')
      && segments.length === 1 && !queryValue('user', 'identifier')) return false;
  if ([
    '/wallpaper-detail', '/wallpaper', '/wallpaper-position', '/download-wallpaper', '/live-wallpaper',
    '/photo-preview', '/clock-preview',
  ].includes(queryRoute)) {
    const source = queryValue('source', 'provider').toLowerCase();
    if (source && !['prism', 'wallhaven', 'pexels'].includes(source)) return false;
  }
  return true;
}

function isSafePathSegment(segment: string): boolean {
  if (!segment || segment === '.' || segment === '..' || /[\\/\\\\\u0000-\u001f\u007f]/.test(segment)) return false;
  try {
    const decoded = decodeURIComponent(segment);
    return decoded !== '.' && decoded !== '..' && !/[\\/\\\\\u0000-\u001f\u007f]/.test(decoded);
  } catch {
    return false;
  }
}

function shortCodeFromQuery(url: URL): string | null {
  let code: string | null = null;
  for (const key of url.searchParams.keys()) {
    const values = url.searchParams.getAll(key);
    if (values.length !== 1) return null;
    if (key === 'code') {
      code = values[0];
    } else if (!PAGE_UTM_KEYS.has(key)) {
      return null;
    }
  }
  return code;
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
    image_source_url: sanitizeImageUrl(
      type === 'share' ? defaults.image_source_url : input?.image_source_url ?? defaults.image_source_url,
      env,
    ),
    username: clipText(sanitizeText(input?.username ?? defaults.username), 60),
    provider: clipText(sanitizeText(input?.provider ?? defaults.provider), 60),
    wall_id: clipText(sanitizeText(input?.wall_id ?? defaults.wall_id), 60),
    setup_name: clipText(sanitizeText(input?.setup_name ?? defaults.setup_name), 80),
    app_store_url: env.APP_STORE_URL,
    play_store_url: env.PLAY_STORE_URL,
    creator_name: clipText(sanitizeText(textInput(input?.creator_name)), 60),
    creator_photo_url: sanitizeImageUrl(textInput(input?.creator_photo_url), env),
    resolution: clipText(sanitizeText(textInput(input?.resolution)), 20),
    follower_count: countInput(input?.follower_count),
    wallpaper_count: countInput(input?.wallpaper_count),
    gallery: galleryInput(input?.gallery, env),
  };

  return merged;
}

function buildDefaultPreview(type: LinkType, canonical: URL, env: Env): PreviewDefaults {
  const parsedCanonical = parseCanonicalFromUrl(canonical, env);

  if (type === 'share') {
    const wallId = canonical.searchParams.get('id') ?? 'Wallpaper';
    const provider = canonical.searchParams.get('provider') ?? 'Prism';
    return {
      title: `${wallId} - Prism`,
      description: 'Check out this amazing wallpaper from Prism.',
      image_source_url: canonical.searchParams.get('thumb') ?? '',
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

  if (type === 'page') {
    const pageName = canonical.pathname.split('/').filter(Boolean).at(-1)?.replaceAll('-', ' ') ?? 'Prism';
    return {
      title: `${pageName.replace(/\b\w/g, (letter) => letter.toUpperCase())} - Prism`,
      description: 'Open this page in Prism.',
      image_source_url: '',
      username: '',
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

function sanitizeImageUrl(value: string, env?: Env): string {
  if (!isNonEmptyString(value)) {
    return '';
  }
  try {
    const parsed = new URL(value);
    if (env != null && isR2PreviewUrl(parsed, env)) return parsed.toString();
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
      return '';
    }
    if (!PREVIEW_IMAGE_HOSTS.has(parsed.hostname.toLowerCase())) {
      return '';
    }
    parsed.protocol = 'https:';
    return parsed.toString();
  } catch {
    return '';
  }
}

function configuredR2PreviewBase(env: Env): URL | null {
  if (!isNonEmptyString(env.R2_PREVIEW_BASE_URL)) return null;
  try {
    const base = new URL(env.R2_PREVIEW_BASE_URL);
    if (base.protocol !== 'https:' || base.username || base.password || base.port || base.search || base.hash) return null;
    return base;
  } catch {
    return null;
  }
}

function isR2PreviewUrl(value: URL, env: Env): boolean {
  const base = configuredR2PreviewBase(env);
  if (base == null || value.protocol !== 'https:' || value.username || value.password || value.port || value.search || value.hash) return false;
  const prefix = `${base.pathname.replace(/\/$/, '')}/previews/`;
  return value.origin === base.origin && value.pathname.startsWith(prefix)
    && /^[a-f0-9]{64}\.img$/.test(value.pathname.slice(prefix.length));
}

function sanitizeShareImageUrl(value: string, env: Env, provider: string): string {
  if (!isNonEmptyString(value)) return '';
  try {
    const parsed = new URL(value);
    if (isR2PreviewUrl(parsed, env)) return parsed.toString();
    if (parsed.hostname === 'raw.githubusercontent.com') {
      const owner = env.GH_USERNAME?.trim();
      const repo = env.GH_REPO_WALLS?.trim();
      const segments = parsed.pathname.split('/').filter(Boolean);
      return parsed.protocol === 'https:'
        && parsed.username === '' && parsed.password === '' && !parsed.port && !parsed.search && !parsed.hash
        && owner != null && owner.length > 0 && repo != null && repo.length > 0
        && segments.length >= 4 && segments[0].toLowerCase() === owner.toLowerCase() && segments[1] === repo
        && segments.at(-1)?.startsWith('thumb_')
        ? parsed.toString() : '';
    }
    if (parsed.hostname === 'prismwalls.com') {
      return parsed.protocol === 'https:' && !parsed.username && !parsed.password && !parsed.port && !parsed.search
        && !parsed.hash && /^\/api\/ai\/assets\/ai\/studio\/thumb_[A-Za-z0-9_-]+\.jpg$/.test(parsed.pathname)
        ? parsed.toString() : '';
    }
    if (!['wallhaven', 'pexels'].includes(provider)) return '';
    return sanitizeImageUrl(value, env);
  } catch {
    return '';
  }
}

function textInput(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function countInput(value: unknown): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function galleryInput(value: unknown, env: Env): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .slice(0, GALLERY_MAX_ITEMS)
    .map((item) => sanitizeGalleryImageUrl(textInput(item), env))
    .filter((url) => url.length > 0);
}

function sanitizeGalleryImageUrl(value: string, env: Env): string {
  if (!isNonEmptyString(value)) return '';
  try {
    const parsed = new URL(value);
    if (isR2PreviewUrl(parsed, env)) return parsed.toString();
    if (parsed.hostname === 'raw.githubusercontent.com') return sanitizeShareImageUrl(value, env, 'prism');
    if (parsed.hostname === 'prismwalls.com') {
      return parsed.protocol === 'https:' && !parsed.username && !parsed.password && !parsed.port && !parsed.search
        && !parsed.hash && /^\/api\/ai\/assets\/ai\/studio\/thumb_[A-Za-z0-9_-]+\.jpg$/.test(parsed.pathname)
        ? parsed.toString() : '';
    }
    if (!/^lh[3-6]\.googleusercontent\.com$/.test(parsed.hostname)) return '';
    return sanitizeImageUrl(value, env);
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
  const imageBytes = await renderOgImageWithBrowserRendering(record, env);
  if (imageBytes == null) {
    return null;
  }

  const objectKey = ogObjectKey(code, OG_CARD_VERSION);
  if (env.OG_IMAGES != null) {
    await env.OG_IMAGES.put(objectKey, imageBytes, {
      httpMetadata: {
        contentType: ogContentType(OG_CARD_VERSION),
        cacheControl: 'public, max-age=31536000, immutable',
      },
    });
    return 'r2';
  }

  const kvPayload = toBase64(imageBytes);
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
          'content-type': object.httpMetadata?.contentType ?? ogContentType(record.version),
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
          'content-type': ogContentType(record.version),
          'cache-control': 'public, max-age=31536000, immutable',
        },
      });
    }
  }

  return null;
}

async function renderOgImageWithBrowserRendering(record: LinkRecord, env: Env): Promise<Uint8Array | null> {
  if (!isNonEmptyString(env.BROWSER_RENDERING_ACCOUNT_ID) || !isNonEmptyString(env.BROWSER_RENDERING_API_TOKEN)) {
    return null;
  }

  const endpoint = `https://api.cloudflare.com/client/v4/accounts/${env.BROWSER_RENDERING_ACCOUNT_ID}/browser-rendering/screenshot`;
  const stats = await fetchWallpaperStats(record, env);
  const htmlTemplate = renderOgCardHtml(ogCardFromRecord(record, stats));

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
      // Fonts and images load from the network; wait for them before the screenshot.
      gotoOptions: {
        waitUntil: 'networkidle0',
      },
      screenshotOptions: {
        type: 'jpeg',
        quality: 85,
      },
    }),
  });

  if (!response.ok) {
    console.warn('Browser rendering screenshot failed', response.status, await response.text());
    return null;
  }

  return new Uint8Array(await response.arrayBuffer());
}

/** Public counters for a Prism wallpaper. Other sources and failures give null, so the card shows no counts. */
async function fetchWallpaperStats(record: LinkRecord, env: Env): Promise<WallpaperStats | null> {
  if (record.type !== 'share' || !isNonEmptyString(env.FIREBASE_PROJECT_ID)) {
    return null;
  }
  const source = new URL(record.canonical_url).searchParams.get('source') || record.preview.provider;
  const wallId = record.preview.wall_id.trim().toUpperCase();
  if (source.toLowerCase() !== 'prism' || wallId.length === 0) {
    return null;
  }

  const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}`
    + `/databases/(default)/documents/wallpaper_stats/${encodeURIComponent(wallId)}`;
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(WALLPAPER_STATS_TIMEOUT_MS) });
    if (!response.ok) {
      return null;
    }
    const doc = await response.json() as { fields?: Record<string, { integerValue?: unknown; doubleValue?: unknown }> };
    const count = (name: string): number | null => {
      const raw = doc.fields?.[name]?.integerValue ?? doc.fields?.[name]?.doubleValue;
      const value = typeof raw === 'string' || typeof raw === 'number' ? Number(raw) : Number.NaN;
      return Number.isFinite(value) && value >= 0 ? Math.floor(value) : null;
    };
    return { views: count('views'), favs: count('favs'), downloads: count('downloads') };
  } catch (error) {
    console.warn('Wallpaper stats fetch failed', error);
    return null;
  }
}

function ogCardFromRecord(record: LinkRecord, stats: WallpaperStats | null): OgCard {
  const preview = record.preview;

  if (record.type === 'user') {
    const handle = preview.username ? `@${preview.username}` : '';
    const name = profileName(preview, handle);
    const hidden = (preview.wallpaper_count ?? 0) - preview.gallery.length;
    return {
      kind: 'profile',
      name,
      handle: name === handle ? '' : handle,
      photo: preview.image_source_url,
      stats: countStats([
        ['image', preview.wallpaper_count, 'Wallpaper'],
        ['users', preview.follower_count, 'Follower'],
      ]),
      gallery: preview.gallery,
      more: hidden > 0 ? `+${formatCount(hidden)} more` : '',
    };
  }

  if (record.type === 'refer') {
    const name = preview.creator_name || (/^(.+) invited you to Prism$/.exec(preview.title)?.[1] ?? '');
    const chip: OgChip = name
      ? { photo: preview.image_source_url, prefix: '', name, detail: 'invited you to Prism' }
      : { photo: '', prefix: '', name: 'Join Prism', detail: 'Wallpapers for Android and iOS' };
    return { kind: 'invite', gallery: INVITE_GALLERY, chip };
  }

  if (record.type === 'setup') {
    return {
      kind: 'wallpaper',
      label: 'Setup',
      title: preview.setup_name || stripPrismSuffix(preview.title) || 'Prism setup',
      image: preview.image_source_url,
      stats: [],
      chip: null,
    };
  }

  const wallpaperStats = countStats([
    ['eye', stats?.views ?? null, 'View'],
    ['heart', stats?.favs ?? null, 'Favourite'],
    ['download', stats?.downloads ?? null, 'Download'],
  ]);
  if (preview.resolution) {
    wallpaperStats.push({ icon: 'phone', value: preview.resolution.replace(/\s*x\s*/i, '×'), label: 'Resolution' });
  }
  const title = stripPrismSuffix(preview.title);
  const provider = preview.provider && preview.provider.toLowerCase() !== 'prism' ? `on ${preview.provider}` : '';
  return {
    kind: 'wallpaper',
    label: 'Wallpaper',
    // Old links used "<wall id> - Prism" as the title; an id means nothing on the card.
    title: title && title !== preview.wall_id ? title : 'Wallpaper on Prism',
    image: preview.image_source_url,
    stats: wallpaperStats.slice(0, 3),
    chip: preview.creator_name
      ? { photo: preview.creator_photo_url, prefix: 'by', name: preview.creator_name, detail: provider }
      : null,
  };
}

function countStats(items: Array<[OgStat['icon'], number | null, string]>): OgStat[] {
  return items
    .filter(([, value]) => value != null && value > 0)
    .map(([icon, value, noun]) => ({
      icon,
      value: formatCount(value as number),
      label: value === 1 ? noun : `${noun}s`,
    }));
}

function profileName(preview: PreviewSnapshot, handle: string): string {
  if (preview.creator_name) {
    return preview.creator_name;
  }
  if (handle && preview.title.endsWith(` (${handle})`)) {
    return preview.title.slice(0, -(handle.length + 3)).trim() || handle;
  }
  if (handle && preview.title === `${handle} on Prism`) {
    return handle;
  }
  return preview.title || handle || 'Prism creator';
}

function stripPrismSuffix(title: string): string {
  return title.endsWith(' - Prism') ? title.slice(0, -' - Prism'.length).trim() : title;
}

function renderCrawlerPreviewHtml(code: string, record: LinkRecord, env: Env): string {
  const shortUrl = `https://${DOMAIN}/l/${code}`;
  const canonicalUrl = record.canonical_url;
  const title = record.preview.title || 'Prism';
  const description = record.preview.description || 'Discover Prism.';
  const ogImage = escapeAttribute(getOgImageUrl(record, env));

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
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

const LANDING_STYLE = `  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; background: #0f1020; color: #f7f7ff; }
    main { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; box-sizing: border-box; }
    .card { max-width: 420px; width: 100%; background: #1b1c33; border: 1px solid #2f315f; border-radius: 16px; padding: 20px; box-sizing: border-box; }
    .brand { margin: 0 0 12px; font-size: 14px; font-weight: 700; letter-spacing: .4px; color: #b9b6ff; }
    .hero { display: block; width: 100%; max-height: 60vh; object-fit: cover; border-radius: 12px; background: #111; }
    .hero.icon { width: 96px; height: 96px; margin: 0 auto; object-fit: contain; }
    h1 { margin: 16px 0 4px; font-size: 22px; overflow-wrap: anywhere; }
    .creator { margin: 0 0 8px; color: #b9b6ff; font-weight: 600; }
    p { margin: 0 0 16px; color: #d5d6f3; }
    .actions { display: flex; flex-direction: column; gap: 10px; }
    .btn { display: block; text-align: center; padding: 14px 16px; border-radius: 12px; border: 1px solid #4a4d8f; color: #f7f7ff; text-decoration: none; font-weight: 700; }
    .btn.primary { background: #7f6cf9; border-color: #7f6cf9; }
    .hint { margin: 12px 0 0; font-size: 14px; }
  </style>`;

function renderHumanLandingHtml(shortUrl: string, record: LinkRecord, request: Request, env: Env): string {
  const canonicalUrl = record.canonical_url;
  const title = record.preview.title || 'Prism';
  const description = record.preview.description || 'Discover wallpapers on Prism.';
  const creator = record.preview.username ? `by @${record.preview.username}` : '';
  const ogImage = escapeAttribute(getOgImageUrl(record, env));
  const hasImage = isNonEmptyString(record.preview.image_source_url);
  const heroImage = escapeAttribute(hasImage ? record.preview.image_source_url : PRISM_APP_ICON_URL);
  const platform = detectPlatform(request);
  const playUrl = escapeAttribute(env.PLAY_STORE_URL);
  const appStoreUrl = escapeAttribute(env.APP_STORE_URL);
  const openUrl = escapeAttribute(
    platform === 'android' ? buildAndroidIntentUrl(canonicalUrl, env.PLAY_STORE_URL) : canonicalUrl,
  );

  const buttons: string[] = [];
  if (platform !== 'other') {
    buttons.push(`<a class="btn primary" href="${openUrl}">Open in Prism</a>`);
  }
  if (platform !== 'ios') {
    buttons.push(`<a class="btn" href="${playUrl}">Get it on Google Play</a>`);
  }
  if (platform !== 'android') {
    buttons.push(`<a class="btn" href="${appStoreUrl}">Download on the App Store</a>`);
  }
  const hint = platform === 'other' ? '<p class="hint">Open this link on your phone to see it in Prism.</p>' : '';

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeAttribute(description)}" />
  <meta property="og:title" content="${escapeAttribute(title)}" />
  <meta property="og:description" content="${escapeAttribute(description)}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="${escapeAttribute(shortUrl)}" />
  <meta property="og:image" content="${ogImage}" />
  <meta property="og:site_name" content="Prism" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeAttribute(title)}" />
  <meta name="twitter:description" content="${escapeAttribute(description)}" />
  <meta name="twitter:image" content="${ogImage}" />
  <link rel="canonical" href="${escapeAttribute(shortUrl)}" />
  <meta name="robots" content="noindex,nofollow" />
  <meta name="color-scheme" content="dark" />
  <meta name="apple-itunes-app" content="app-id=${IOS_APP_ID}, app-argument=${escapeAttribute(canonicalUrl)}" />
${LANDING_STYLE}
</head>
<body>
  <main>
    <div class="card">
      <p class="brand">PRISM</p>
      <img class="hero${hasImage ? '' : ' icon'}" src="${heroImage}" alt="${hasImage ? escapeAttribute(title) : 'Prism'}" referrerpolicy="no-referrer" />
      <h1>${escapeHtml(title)}</h1>
      ${creator ? `<p class="creator">${escapeHtml(creator)}</p>` : ''}
      <p>${escapeHtml(description)}</p>
      <div class="actions">
        ${buttons.join('\n        ')}
      </div>
      ${hint}
    </div>
  </main>
</body>
</html>`;
}

function renderUnavailableHtml(request: Request, env: Env): string {
  const storeUrl = escapeAttribute(selectStoreUrl(request, env));
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Prism</title>
  <meta name="robots" content="noindex,nofollow" />
  <meta name="color-scheme" content="dark" />
${LANDING_STYLE}
</head>
<body>
  <main>
    <div class="card">
      <p class="brand">PRISM</p>
      <h1>This link is no longer available</h1>
      <p>The wallpaper or page you wanted has moved or been removed.</p>
      <div class="actions">
        <a class="btn primary" href="${storeUrl}">Open Prism</a>
      </div>
    </div>
  </main>
</body>
</html>`;
}

type Platform = 'android' | 'ios' | 'other';

function detectPlatform(request: Request): Platform {
  const userAgent = request.headers.get('user-agent')?.toLowerCase() ?? '';
  if (userAgent.includes('iphone') || userAgent.includes('ipad') || userAgent.includes('ipod')) {
    return 'ios';
  }
  if (userAgent.includes('android')) {
    return 'android';
  }
  return 'other';
}

function buildAndroidIntentUrl(canonicalUrl: string, fallbackUrl: string): string {
  const target = new URL(canonicalUrl);
  const path = `${target.host}${target.pathname}${target.search}`.replaceAll(';', '%3B');
  return `intent://${path}#Intent;scheme=https;package=${ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(fallbackUrl)};end`;
}

function isCrawlerRequest(request: Request): boolean {
  const userAgent = request.headers.get('user-agent')?.toLowerCase() ?? '';
  return BOT_UA_FRAGMENTS.some((fragment) => userAgent.includes(fragment));
}

function getOgImageUrl(record: LinkRecord, env: Env): string {
  if (isNonEmptyString(record.code)) {
    return `https://${DOMAIN}/og/${record.code}.jpg?v=${OG_CARD_VERSION}`;
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
  if (type === 'page') {
    return '';
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
  if (type === 'page') {
    return '/:allowlistedPage';
  }
  return '/refer/:inviterId';
}

function ogObjectKey(code: string, version: number): string {
  return `${code}-v${version}.${version >= OG_CARD_VERSION ? 'jpg' : 'png'}`;
}

function ogContentType(version: number): string {
  return version >= OG_CARD_VERSION ? 'image/jpeg' : 'image/png';
}

function getClientIp(request: Request): string {
  return (
    request.headers.get('CF-Connecting-IP') ??
    request.headers.get('x-forwarded-for')?.split(',')[0].trim() ??
    'unknown'
  );
}

function isValidType(type: unknown): type is LinkType {
  return type === 'share' || type === 'user' || type === 'setup' || type === 'refer' || type === 'page';
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
