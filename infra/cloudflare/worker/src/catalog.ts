// The public web catalogue: wall, folder, hub and creator pages, their sitemaps, and their images.
// Pages render from the webWalls and webPages projections (functions/src/webCatalog.ts), which hold public fields
// only. The HTML is the same for every visitor, so one edge-cached copy serves crawlers and people alike.

import { formatCount, renderOgCardHtml } from './og_card';
import { buildAndroidIntentUrl, escapeAttribute, escapeHtml, screenshotCard, type ScreenshotEnv } from './page_kit';

export interface CatalogEnv extends ScreenshotEnv {
  PLAY_STORE_URL: string;
  APP_STORE_URL: string;
  FIREBASE_PROJECT_ID?: string;
  OG_FALLBACK_IMAGE?: string;
  OG_IMAGES?: R2Bucket;
  /** Local runs point these at the Firestore and Functions emulators. Production leaves them unset. */
  CATALOG_FIRESTORE_ORIGIN?: string;
  CATALOG_PREVIEW_ORIGIN?: string;
  R2_PREVIEW_BASE_URL?: string;
  /** The website's public Mixpanel project token. Unset means downloads are not counted. */
  MIXPANEL_TOKEN?: string;
}

/** Counts one download for an IP. False means the IP is over its limit. */
export type DownloadLimiter = (ip: string) => Promise<boolean>;

type WallState = 'live' | 'gated' | 'hidden' | 'gone';

interface WebWall {
  state: WallState;
  updatedAt: string;
  title?: string;
  description?: string;
  category?: string;
  categorySlug?: string;
  tags?: string[];
  colors?: Array<{ name: string; hex: string }>;
  width?: number;
  height?: number;
  createdAt?: string;
  creatorName?: string;
  creator?: { username: string; name: string } | null;
  thumb?: string;
  blur?: string;
  desktop?: Desktop;
}

interface Desktop { v: string; thumb: string; width: number; height: number }
interface Card { id: string; title: string; thumb: string; width: number; height: number; desktop?: string }
interface CategoryLink { slug: string; name: string; count: number }
interface ListPage {
  kind: string;
  page: number;
  pages: number;
  total: number;
  items: Card[];
  categories?: CategoryLink[];
  slug?: string;
  name?: string;
  creator?: { username: string; name: string; bio: string; photo: string };
  folders?: Array<{ id: string; name: string; total: number; cover: string }>;
}
interface FolderPage {
  kind: 'folder';
  id: string;
  name: string;
  owner: { username: string; name: string; hasPage: boolean } | null;
  total: number;
  items: Card[];
  updatedAt: string;
}

const DOMAIN = 'prismwalls.com';
const SITE = `https://${DOMAIN}`;
const SHARE_ID = /^[A-Za-z0-9_-]{1,200}$/;
const FOLDER_ID = /^[A-Za-z0-9_-]{1,128}$/;
const USERNAME = /^[A-Za-z0-9._-]{1,40}$/;
const SLUG = /^[a-z0-9-]{1,40}$/;
const PAGE_PARAM = /^[1-9]\d{0,3}$/;
const RELATED_COUNT = 12;
const FIRESTORE_TIMEOUT_MS = 4000;
const PREVIEW_TIMEOUT_MS = 15000;
// A page stays fresh for 10 minutes, then serves stale for up to a day while one request refreshes it in the
// background. A takedown therefore reaches each edge location within about 10 minutes plus one request.
const FRESH_SECONDS = 600;
const STALE_SECONDS = 86400;
const MISS_SECONDS = 300;
const STORED_AT = 'x-catalog-stored-at';
const LOGO_URL = '/assets/prism-logo.png';
const OG_HOME = `${SITE}/assets/og/home.jpg`;
const THUMB_WIDTH = 540;
const THUMB_HEIGHT = 1080;
const DESKTOP_WIDTH = 2560;
const DESKTOP_HEIGHT = 1600;
const DESKTOP_THUMB_WIDTH = 960;
const DESKTOP_THUMB_HEIGHT = 600;
/** The web renditions wallpaperPreview makes. The 2560 px desktop originals stay in the app. */
const DOWNLOADS = {
  phone: { label: 'Phone', variant: '' },
  desktop: { label: 'Desktop 16:10', variant: 'desktop', width: 1920, height: 1200 },
  'desktop-16x9': { label: 'Desktop 16:9', variant: 'desktop-16x9', width: 1920, height: 1080 },
} as const;
type DownloadKind = keyof typeof DOWNLOADS;
const SITE_HOSTS = [DOMAIN, `www.${DOMAIN}`];

type Route =
  | { kind: 'wall'; id: string; desktop: boolean }
  | { kind: 'folder'; id: string }
  | { kind: 'hub'; list: 'latest' | 'popular' | 'category'; slug: string; page: number }
  | { kind: 'desktop-hub'; list: 'desktop' | 'sets'; page: number }
  | { kind: 'creator'; username: string; page: number }
  | { kind: 'sitemap-index' }
  | { kind: 'sitemap'; name: string }
  | { kind: 'og'; id: string }
  | { kind: 'preview'; id: string }
  | { kind: 'desktop-image'; id: string; version: string | null }
  | { kind: 'download'; id: string; file: DownloadKind }
  | { kind: 'redirect'; location: string }
  | { kind: 'not-found' };

class FirestoreUnavailable extends Error {}

const activeRefreshes = new WeakMap<Cache, Map<string, Promise<void>>>();

/**
 * The catalogue's response, or null when the path is not a catalogue page. `landing` is the old generic app landing:
 * wall and folder links still work through it while Firestore is unreachable.
 */
export async function handleCatalogRequest(
  request: Request, url: URL, env: CatalogEnv, ctx: ExecutionContext, landing: () => Response,
  limitDownload: DownloadLimiter = async () => false,
): Promise<Response | null> {
  if (request.method !== 'GET' && request.method !== 'HEAD') return null;
  const route = matchRoute(url);
  if (route == null) return null;
  if (route.kind === 'redirect') return Response.redirect(route.location, 301);
  if (request.method === 'HEAD' && ['download', 'preview', 'desktop-image'].includes(route.kind)) {
    return new Response(null, { status: 405, headers: { 'cache-control': 'no-store', allow: 'GET' } });
  }
  // Downloads never touch the page cache: every one checks the Referer, the rate limit and the wall's current state.
  if (route.kind === 'download') return withMethod(request, await handleDownload(request, url, route, env, ctx, limitDownload));
  const key = cacheKeyOf(route);
  try {
    if (route.kind === 'desktop-image') return await renderDesktopImage(route.id, route.version, env);
    const response = await cached(key, ctx, () => route.kind === 'not-found'
      ? renderMissing(404, 'page', env)
      : render(route, env));
    return withMethod(request, response);
  } catch (error) {
    if (!(error instanceof FirestoreUnavailable)) throw error;
    console.warn('[catalog] firestore_unavailable', { route: route.kind, error: `${error.message}` });
    if (route.kind === 'wall' || route.kind === 'folder') return withMethod(request, landing());
    return withMethod(request, unavailable());
  }
}

function matchRoute(url: URL): Route | null {
  const path = url.pathname;
  const segments = path.split('/').filter(Boolean);
  const pageParam = url.searchParams.get('page');

  if (segments[0] === 'wallpaper' && segments.length === 2 && SHARE_ID.test(segments[1])) {
    // Wallhaven and Pexels walls are not Prism walls: they keep the app landing.
    const source = (url.searchParams.get('source') || url.searchParams.get('provider') || 'prism').toLowerCase();
    const desktop = url.searchParams.get('view') === 'desktop';
    return source === 'prism' ? { kind: 'wall', id: segments[1], desktop } : null;
  }
  if (segments[0] === 'folder' && segments.length === 2 && FOLDER_ID.test(segments[1])) {
    return { kind: 'folder', id: segments[1] };
  }
  if (path === '/sitemap.xml') return { kind: 'sitemap-index' };
  const sitemap = /^\/sitemaps\/([a-z]+-\d{1,4})\.xml$/.exec(path);
  if (sitemap) return { kind: 'sitemap', name: sitemap[1] };
  const og = /^\/og\/wall\/([A-Za-z0-9_-]{1,200})\.jpg$/.exec(path);
  if (og) return { kind: 'og', id: og[1] };
  const preview = /^\/api\/catalog\/preview\/([A-Za-z0-9_-]{1,200})\.jpg$/.exec(path);
  if (preview) return { kind: 'preview', id: preview[1] };
  const desktopImage = /^\/api\/catalog\/desktop\/([A-Za-z0-9_-]{1,200})\.jpg$/.exec(path);
  if (desktopImage) return { kind: 'desktop-image', id: desktopImage[1], version: url.searchParams.get('v') };
  const download = /^\/api\/catalog\/download\/([A-Za-z0-9_-]{1,200})\/(phone|desktop|desktop-16x9)\.jpg$/.exec(path);
  if (download) return { kind: 'download', id: download[1], file: download[2] as DownloadKind };

  const listed = matchList(segments);
  if (listed == null) {
    if (['wallpapers', 'creator', 'desktop-wallpapers', 'matching-sets'].includes(segments[0])) return { kind: 'not-found' };
    return null;
  }
  if (pageParam == null) return listed;
  if (pageParam === '1') return { kind: 'redirect', location: `${SITE}${path.replace(/\/$/, '')}` };
  if (!PAGE_PARAM.test(pageParam)) return { kind: 'not-found' };
  return { ...listed, page: Number(pageParam) };
}

function matchList(segments: string[]): Route | null {
  if (segments[0] === 'wallpapers' && segments.length === 1) return { kind: 'hub', list: 'latest', slug: '', page: 1 };
  if (segments[0] === 'wallpapers' && segments.length === 2) {
    if (segments[1] === 'popular') return { kind: 'hub', list: 'popular', slug: '', page: 1 };
    if (SLUG.test(segments[1])) return { kind: 'hub', list: 'category', slug: segments[1], page: 1 };
  }
  if (segments.length === 1 && segments[0] === 'desktop-wallpapers') return { kind: 'desktop-hub', list: 'desktop', page: 1 };
  if (segments.length === 1 && segments[0] === 'matching-sets') return { kind: 'desktop-hub', list: 'sets', page: 1 };
  if (segments[0] === 'creator' && segments.length === 2 && USERNAME.test(segments[1])) {
    return { kind: 'creator', username: segments[1].toLowerCase(), page: 1 };
  }
  return null;
}

/** Only the parsed route names the cache entry, never the raw URL: query strings and headers cannot pick a copy. */
function cacheKeyOf(route: Route): string {
  switch (route.kind) {
    case 'wall': return route.desktop ? `wall/${route.id}/desktop` : `wall/${route.id}`;
    case 'folder': case 'og': case 'preview': return `${route.kind}/${route.id}`;
    case 'desktop-image': return `${route.kind}/${route.id}/${route.version ?? 'unversioned'}`;
    case 'hub': return `hub/${route.list}/${route.slug}/${route.page}`;
    case 'desktop-hub': return `desktop-hub/${route.list}/${route.page}`;
    case 'download': return `download/${route.id}/${route.file}`;
    case 'creator': return `creator/${route.username}/${route.page}`;
    case 'sitemap': return `sitemap/${route.name}`;
    default: return route.kind;
  }
}

function edgeCache(): Cache | null {
  return (globalThis as { caches?: { default?: Cache } }).caches?.default ?? null;
}

/**
 * Edge cache with stale-while-revalidate. The Cache API has no stale serving of its own, so each entry carries the
 * time it was stored and is kept a day longer than it is fresh.
 */
async function cached(key: string, ctx: ExecutionContext, render: () => Promise<Response>): Promise<Response> {
  const cache = edgeCache();
  const cacheKey = new Request(`${SITE}/__catalog/v1/${key}`);
  const hit = cache ? await cache.match(cacheKey) : undefined;
  const store = async (response: Response) => {
    if (cache && [200, 301, 302, 404, 410].includes(response.status)) {
      await cache.put(cacheKey, storable(response.clone()));
    }
  };
  if (hit) {
    const age = (Date.now() - Number(hit.headers.get(STORED_AT) ?? 0)) / 1000;
    const fresh = hit.status === 200 ? FRESH_SECONDS : MISS_SECONDS;
    if (age <= fresh) return forClient(hit);
    if (hit.status === 200 && age <= FRESH_SECONDS + STALE_SECONDS) {
      if (cache) {
        let inFlight = activeRefreshes.get(cache);
        if (!inFlight) {
          inFlight = new Map();
          activeRefreshes.set(cache, inFlight);
        }
        let refresh = inFlight.get(key);
        if (!refresh) {
          refresh = render().then(store)
            .catch((error) => console.warn('[catalog] revalidate_failed', `${error}`))
            .finally(() => inFlight?.delete(key));
          inFlight.set(key, refresh);
        }
        ctx.waitUntil(refresh);
      } else {
        ctx.waitUntil(render().then(store).catch((error) => console.warn('[catalog] revalidate_failed', `${error}`)));
      }
      return forClient(hit);
    }
  }
  try {
    const response = await render();
    ctx.waitUntil(store(response));
    return forClient(response);
  } catch (error) {
    if (hit && error instanceof FirestoreUnavailable) return forClient(hit);
    throw error;
  }
}

function storable(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set(STORED_AT, `${Date.now()}`);
  headers.set('cache-control', `public, max-age=${FRESH_SECONDS + STALE_SECONDS}`);
  return new Response(response.body, { status: response.status, headers });
}

function forClient(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.delete(STORED_AT);
  headers.set('cache-control', response.status === 200
    ? `public, max-age=${FRESH_SECONDS}, stale-while-revalidate=${STALE_SECONDS}`
    : `public, max-age=${MISS_SECONDS}`);
  return new Response(response.body, { status: response.status, headers });
}

function withMethod(request: Request, response: Response): Response {
  return request.method === 'HEAD' ? new Response(null, { status: response.status, headers: response.headers }) : response;
}

async function render(route: Route, env: CatalogEnv): Promise<Response> {
  switch (route.kind) {
    case 'wall': return renderWall(route.id, route.desktop, env);
    case 'folder': return renderFolder(route.id, env);
    case 'hub': return renderHub(route.list, route.slug, route.page, env);
    case 'desktop-hub': return renderDesktopHub(route.list, route.page, env);
    case 'creator': return renderCreator(route.username, route.page, env);
    case 'sitemap-index': return renderSitemapIndex(env);
    case 'sitemap': return renderSitemap(route.name, env);
    case 'og': return renderOgImage(route.id, env);
    case 'preview': return renderPreview(route.id, env);
    case 'desktop-image': return renderDesktopImage(route.id, route.version, env);
    default: return renderMissing(404, 'page', env);
  }
}

// Firestore REST, read with no credentials: the rules make only the two catalogue collections public.

async function readDoc<T>(env: CatalogEnv, path: string): Promise<T | null> {
  if (!env.FIREBASE_PROJECT_ID) throw new FirestoreUnavailable('no project id');
  const origin = env.CATALOG_FIRESTORE_ORIGIN || 'https://firestore.googleapis.com';
  const url = `${origin}/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents/`
    + path.split('/').map(encodeURIComponent).join('/');
  let response: Response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(FIRESTORE_TIMEOUT_MS) });
  } catch (error) {
    throw new FirestoreUnavailable(`${error}`);
  }
  if (response.status === 404) return null;
  if (!response.ok) throw new FirestoreUnavailable(`status ${response.status}`);
  try {
    const doc = await response.json() as { fields?: Record<string, FirestoreValue> };
    return decodeFields(doc.fields ?? {}) as T;
  } catch (error) {
    throw new FirestoreUnavailable(`invalid document: ${error}`);
  }
}

type FirestoreValue = {
  stringValue?: string; integerValue?: string; doubleValue?: number; booleanValue?: boolean; nullValue?: null;
  timestampValue?: string; arrayValue?: { values?: FirestoreValue[] }; mapValue?: { fields?: Record<string, FirestoreValue> };
};

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

function record(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) throw new FirestoreUnavailable('invalid projection');
  return value as Record<string, unknown>;
}

function stringField(source: Record<string, unknown>, key: string, optional = false): string | undefined {
  const value = source[key];
  if (value == null && optional) return undefined;
  if (typeof value !== 'string') throw new FirestoreUnavailable(`invalid ${key}`);
  return value;
}

function requiredString(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  if (typeof value !== 'string') throw new FirestoreUnavailable(`invalid ${key}`);
  return value;
}

function numberField(source: Record<string, unknown>, key: string, optional = false): number | undefined {
  const value = source[key];
  if (value == null && optional) return undefined;
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
    throw new FirestoreUnavailable(`invalid ${key}`);
  }
  return value;
}

function dimensionField(source: Record<string, unknown>, key: string): number | undefined {
  const value = numberField(source, key, true);
  if (value !== undefined && value > 99999) throw new FirestoreUnavailable(`invalid ${key}`);
  return value;
}

function requiredNumber(source: Record<string, unknown>, key: string): number {
  const value = source[key];
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
    throw new FirestoreUnavailable(`invalid ${key}`);
  }
  return value;
}

function publicThumb(value: string, configuredBase?: string): boolean {
  try {
    const base = new URL(configuredBase || 'https://img.prismwalls.com');
    const url = new URL(value);
    if (base.protocol !== 'https:' || base.username || base.password || base.port || base.search || base.hash) return false;
    const prefix = `${base.pathname.replace(/\/$/, '')}/previews/`;
    return url.protocol === 'https:' && url.origin === base.origin && !url.username && !url.password
      && !url.search && !url.hash && url.pathname.startsWith(prefix) && !/%(?:2f|5c)/i.test(url.pathname)
      && url.pathname.length > prefix.length;
  } catch {
    return false;
  }
}

// Matches the builder's allowlist in functions/src/webCatalog.ts, so a stored photo on any other host never prints.
const PROFILE_PHOTO_HOSTS = ['raw.githubusercontent.com', 'firebasestorage.googleapis.com'];

function publicProfilePhoto(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password && !url.port
      && (PROFILE_PHOTO_HOSTS.includes(url.hostname) || url.hostname.endsWith('.googleusercontent.com'));
  } catch {
    return false;
  }
}

function parseWall(value: unknown, env: CatalogEnv): WebWall {
  const source = record(value);
  const storedState = stringField(source, 'state');
  if (storedState !== 'live' && storedState !== 'gated' && storedState !== 'hidden' && storedState !== 'gone') {
    throw new FirestoreUnavailable('invalid state');
  }
  const storedThumb = stringField(source, 'thumb', true);
  const thumb = storedThumb && publicThumb(storedThumb, env.R2_PREVIEW_BASE_URL) ? storedThumb : undefined;
  const state = storedState === 'live' && thumb === undefined ? 'gated' : storedState;
  const tags = source.tags;
  if (tags != null && (!Array.isArray(tags) || !tags.every((tag) => typeof tag === 'string'))) {
    throw new FirestoreUnavailable('invalid tags');
  }
  const colors = source.colors;
  if (colors != null && (!Array.isArray(colors) || !colors.every((color) => {
    const item = record(color);
    return typeof item.name === 'string' && typeof item.hex === 'string';
  }))) throw new FirestoreUnavailable('invalid colors');
  let creator: WebWall['creator'];
  if (source.creator != null) {
    const item = record(source.creator);
    creator = { username: requiredString(item, 'username'), name: requiredString(item, 'name') };
  }
  let desktop: Desktop | undefined;
  if (source.desktop != null) {
    const item = record(source.desktop);
    const v = requiredString(item, 'v');
    const desktopThumb = requiredString(item, 'thumb');
    if (/^[a-f0-9]{16}$/.test(v) && publicThumb(desktopThumb, env.R2_PREVIEW_BASE_URL)
      && item.width === DESKTOP_WIDTH && item.height === DESKTOP_HEIGHT) {
      desktop = { v, thumb: desktopThumb, width: DESKTOP_WIDTH, height: DESKTOP_HEIGHT };
    }
  }
  const blur = stringField(source, 'blur', true);
  if (blur !== undefined && !/^data:image\/jpeg;base64,[A-Za-z0-9+/]*={0,2}$/.test(blur)) {
    throw new FirestoreUnavailable('invalid blur');
  }
  return {
    state,
    updatedAt: requiredString(source, 'updatedAt'),
    title: stringField(source, 'title', true),
    description: stringField(source, 'description', true),
    category: stringField(source, 'category', true),
    categorySlug: stringField(source, 'categorySlug', true),
    tags: tags as string[] | undefined,
    colors: colors as Array<{ name: string; hex: string }> | undefined,
    width: dimensionField(source, 'width'),
    height: dimensionField(source, 'height'),
    createdAt: stringField(source, 'createdAt', true),
    creatorName: stringField(source, 'creatorName', true),
    creator: creator ?? null,
    thumb,
    blur,
    // Only a live wall offers its desktop companion.
    ...(state === 'live' && desktop ? { desktop } : {}),
  };
}

function parseCard(value: unknown, env: CatalogEnv): Card {
  const item = record(value);
  const thumb = requiredString(item, 'thumb');
  if (!publicThumb(thumb, env.R2_PREVIEW_BASE_URL)) throw new FirestoreUnavailable('invalid card thumb');
  const desktop = stringField(item, 'desktop', true);
  if (desktop !== undefined && !publicThumb(desktop, env.R2_PREVIEW_BASE_URL)) {
    throw new FirestoreUnavailable('invalid card desktop thumb');
  }
  return {
    id: requiredString(item, 'id'), title: requiredString(item, 'title'), thumb,
    width: requiredNumber(item, 'width'), height: requiredNumber(item, 'height'), ...(desktop ? { desktop } : {}),
  };
}

function parseListPage(value: unknown, env: CatalogEnv): ListPage {
  const item = record(value);
  if (!Array.isArray(item.items)) throw new FirestoreUnavailable('invalid page items');
  const categories = item.categories;
  if (categories != null && (!Array.isArray(categories) || !categories.every((value) => {
    const category = record(value);
    return typeof category.slug === 'string' && typeof category.name === 'string'
      && typeof category.count === 'number' && Number.isSafeInteger(category.count);
  }))) throw new FirestoreUnavailable('invalid categories');
  let creator: ListPage['creator'];
  if (item.creator != null) {
    const value = record(item.creator);
    const photo = requiredString(value, 'photo');
    creator = {
      username: requiredString(value, 'username'), name: requiredString(value, 'name'),
      bio: requiredString(value, 'bio'), photo: publicProfilePhoto(photo) ? photo : '',
    };
  }
  const folders = item.folders;
  if (folders != null && (!Array.isArray(folders) || !folders.every((value) => {
    const folder = record(value);
    return typeof folder.id === 'string' && typeof folder.name === 'string'
      && typeof folder.total === 'number' && Number.isSafeInteger(folder.total)
      && typeof folder.cover === 'string' && publicThumb(folder.cover, env.R2_PREVIEW_BASE_URL);
  }))) throw new FirestoreUnavailable('invalid folders');
  return {
    kind: requiredString(item, 'kind'), page: requiredNumber(item, 'page'), pages: requiredNumber(item, 'pages'),
    total: requiredNumber(item, 'total'), items: item.items.map((value) => parseCard(value, env)),
    categories: categories as CategoryLink[] | undefined,
    slug: stringField(item, 'slug', true), name: stringField(item, 'name', true), creator,
    folders: folders as ListPage['folders'],
  };
}

function parseFolderPage(value: unknown, env: CatalogEnv): FolderPage {
  const item = record(value);
  if (!Array.isArray(item.items)) throw new FirestoreUnavailable('invalid folder items');
  let owner: FolderPage['owner'];
  if (item.owner != null) {
    const value = record(item.owner);
    owner = {
      username: requiredString(value, 'username'), name: requiredString(value, 'name'), hasPage: value.hasPage === true,
    };
  } else {
    owner = null;
  }
  return {
    kind: 'folder', id: requiredString(item, 'id'), name: requiredString(item, 'name'), owner,
    total: requiredNumber(item, 'total'), items: item.items.map((value) => parseCard(value, env)),
    updatedAt: requiredString(item, 'updatedAt'),
  };
}

async function renderWall(id: string, desktopView: boolean, env: CatalogEnv): Promise<Response> {
  const stored = await readDoc<unknown>(env, `webWalls/${id}`);
  const wall = stored == null ? null : parseWall(stored, env);
  if (wall == null || wall.state === 'hidden' || wall.state === 'gone') {
    if (wall == null && id !== id.toUpperCase() && await readDoc<WebWall>(env, `webWalls/${id.toUpperCase()}`)) {
      return redirect(`${SITE}/wallpaper/${id.toUpperCase()}${desktopView ? '?view=desktop' : ''}`);
    }
    return renderMissing(wall?.state === 'gone' ? 410 : 404, 'wallpaper', env);
  }
  const slug = wall.categorySlug || 'general';
  const category = wall.category || 'General';
  const storedRelated = await readDoc<unknown>(env, `webPages/category~${slug}~1`);
  const related = (storedRelated == null ? [] : parseListPage(storedRelated, env).items)
    .filter((card) => card.id !== id).slice(0, RELATED_COUNT);
  const live = wall.state === 'live';
  const canonical = `${SITE}/wallpaper/${id}`;
  const heading = wall.title || `${category} wallpaper`;
  const creatorName = wall.creator?.name || wall.creatorName || '';
  const resolution = wall.width && wall.height ? `${wall.width} × ${wall.height}` : '';
  const title = `${wall.title || `${category} wallpaper ${id}`}${creatorName ? ` by ${creatorName}` : ''} | Prism`;
  const description = clip(live
    ? `${wall.description ? `${wall.description.replace(/[.!?…]+$/, '')}. ` : ''}${heading}, a ${category} phone wallpaper`
      + `${wall.desktop ? ' with a matching desktop version' : ''}`
      + `${creatorName ? ` by ${creatorName}` : ''}${resolution ? ` in ${resolution}` : ''}. Get it for Android and iPhone in Prism.`
    : `${heading}${creatorName ? ` by ${creatorName}` : ''} is only in the Prism app. Get Prism for Android and iPhone.`, 160);
  const previewPath = `/api/catalog/preview/${id}.jpg`;
  const previewUrl = `${SITE}${previewPath}`;
  const ogImage = live ? `${SITE}/og/wall/${id}.jpg?v=${shortHash(`${wall.thumb}|${heading}|${creatorName}`)}` : OG_HOME;
  const width = wall.width && wall.height ? wall.width : THUMB_WIDTH;
  const height = wall.width && wall.height ? wall.height : THUMB_HEIGHT;
  // wallpaperPreview fits the wall inside a 2560 px square and never enlarges it.
  const previewWidth = Math.round(width * Math.min(1, 2560 / Math.max(width, height)));
  const previewHeight = Math.round(height * Math.min(1, 2560 / Math.max(width, height)));
  const desktop = live ? wall.desktop : undefined;
  const creatorLink = wall.creator
    ? `<a href="/creator/${encodeURIComponent(wall.creator.username)}">${escapeHtml(creatorName)}</a>`
    : escapeHtml(creatorName);

  const desktopPage = live && desktopView;
  const sideBySide = desktopPage && desktop != null;
  const hero = live
    ? `<img class="wall-img" src="${escapeAttribute(previewPath)}" srcset="${escapeAttribute(wall.thumb ?? '')} ${THUMB_WIDTH}w, ${escapeAttribute(previewPath)} ${previewWidth}w"
        sizes="${sideBySide ? '(min-width: 960px) 220px, 40vw' : '(min-width: 960px) 420px, min(100vw - 32px, 480px)'}" width="${width}" height="${height}"
        alt="${escapeAttribute(`${heading}${creatorName ? ` by ${creatorName}` : ''}`)}"${sideBySide ? '' : ' fetchpriority="high"'} decoding="async"
        data-fallback="${escapeAttribute(wall.thumb ?? '')}" onerror="this.onerror=null;this.removeAttribute('srcset');this.src=this.dataset.fallback">`
    : `<div class="wall-img gated" role="img" aria-label="${escapeAttribute(`Blurred preview of ${heading}`)}"
        style="aspect-ratio: ${width} / ${height}${wall.blur?.startsWith('data:image/jpeg;base64,') ? `; background-image: url('${escapeAttribute(wall.blur)}')` : ''}">
        <span class="lock">${LOCK_ICON}<span>Only in Prism</span></span>
      </div>`;

  const facts = [
    `<div><dt>Category</dt><dd><a href="/wallpapers/${escapeAttribute(slug)}">${escapeHtml(category)}</a></dd></div>`,
    resolution ? `<div><dt>Resolution</dt><dd>${escapeHtml(resolution)}</dd></div>` : '',
    wall.colors?.length ? `<div><dt>Colours</dt><dd class="swatches">${wall.colors.map((color) =>
      `<span class="swatch"><i style="background:${/^#[0-9a-f]{6}$/i.test(color.hex) ? color.hex : '#000'}"></i>${escapeHtml(color.name)}</span>`).join('')}</dd></div>` : '',
  ].join('');
  const tags = wall.tags?.length
    ? `<ul class="tags" aria-label="Tags">${wall.tags.map((tag) => `<li>${escapeHtml(tag)}</li>`).join('')}</ul>` : '';
  const crumbs: Array<[string, string]> = [['Wallpapers', `${SITE}/wallpapers`], [category, `${SITE}/wallpapers/${slug}`], [heading, canonical]];

  const tabbed = desktop != null && !desktopPage;
  const phoneFigure = `<figure class="wall-figure${sideBySide ? ' phone-side' : ''}" style="--ar: ${(width / height).toFixed(4)}"${tabbed
    ? ' id="panel-phone" role="tabpanel" aria-labelledby="tab-phone"' : ''}>${hero}${sideBySide ? '<figcaption>Phone</figcaption>' : ''}</figure>`;
  const phoneSize = `${previewWidth} × ${previewHeight}`;
  const monitorAlt = `${heading}, desktop version, on a computer screen`;
  const media = desktop == null ? phoneFigure
    : sideBySide ? `<div class="desktop-stage">
    <figure class="desktop-figure desktop-lead">${monitorHtml(id, desktop, monitorAlt, '(min-width: 960px) 760px, calc(100vw - 52px)', 'fetchpriority="high"')}<figcaption>Desktop</figcaption></figure>
    ${phoneFigure}
  </div>`
    : `<div class="wall-media">
    <div class="view-tabs" role="tablist" aria-label="Show this wallpaper on">
      <button type="button" role="tab" id="tab-phone" aria-controls="panel-phone" aria-selected="true">Phone</button>
      <button type="button" role="tab" id="tab-desktop" aria-controls="panel-desktop" aria-selected="false" tabindex="-1">Desktop</button>
    </div>
    ${phoneFigure}
    <figure class="desktop-figure" id="panel-desktop" role="tabpanel" aria-labelledby="tab-desktop" hidden>${monitorHtml(id, desktop, monitorAlt, '(min-width: 960px) 720px, calc(100vw - 52px)', 'loading="lazy"')}</figure>
  </div>`;
  const downloads = !live ? '<p class="lead">This wallpaper is part of a premium or limited set. Open Prism to see it in full.</p>'
    : sideBySide ? desktopDownloadsHtml(id, phoneSize)
    : desktopPage ? `${downloadsHtml(id, phoneSize, false)}${DESKTOP_HOWTO}`
    : downloadsHtml(id, phoneSize, desktop != null);
  const mainOpen = sideBySide ? '<main class="wall-layout desktop-mode" data-mode="desktop">'
    : desktopPage ? '<main class="wall-layout" data-mode="desktop">'
    : `<main class="wall-layout"${desktop ? ' data-views data-view="phone"' : ''}>`;
  const body = `
${mainOpen}
  ${media}
  <section class="wall-info">
    ${breadcrumbHtml(crumbs)}
    <h1>${escapeHtml(heading)}</h1>
    ${creatorName ? `<p class="byline">by ${creatorLink}</p>` : ''}
    ${wall.description ? `<p class="lead">${escapeHtml(wall.description)}</p>` : ''}
    ${downloads}
    ${actionsHtml(canonical, live ? 'Open in Prism' : 'Get it in Prism', env)}
    <dl class="facts">${facts}</dl>
    ${tags}
  </section>
</main>
${related.length ? `<section class="shelf">
  <div class="shelf-head"><h2>More ${escapeHtml(category)} wallpapers</h2>
    <a href="/wallpapers/${escapeAttribute(slug)}">See all</a></div>
  ${gridHtml(related)}
</section>` : ''}`;

  const jsonLd: unknown[] = [breadcrumbLd(crumbs)];
  if (live) {
    jsonLd.unshift({
      '@context': 'https://schema.org',
      '@type': 'ImageObject',
      name: heading,
      description,
      url: canonical,
      contentUrl: previewUrl,
      thumbnailUrl: wall.thumb,
      encodingFormat: 'image/jpeg',
      ...(wall.width && wall.height ? { width: wall.width, height: wall.height } : {}),
      ...(wall.createdAt ? { uploadDate: wall.createdAt } : {}),
      ...(wall.tags?.length ? { keywords: wall.tags.join(', ') } : {}),
      ...(creatorName ? {
        creator: { '@type': 'Person', name: creatorName, ...(wall.creator ? { url: `${SITE}/creator/${wall.creator.username}` } : {}) },
        creditText: creatorName,
        copyrightNotice: `© ${creatorName}`,
      } : {}),
      acquireLicensePage: canonical,
    });
  }
  return page({
    title, description, canonical, ogImage, ogType: 'article', body, jsonLd,
    robots: live ? 'index,follow,max-image-preview:large' : 'noindex,follow',
    appUrl: canonical, script: tabbed ? TABS_SCRIPT : '',
  });
}

function downloadItem(id: string, file: DownloadKind, size: string): string {
  return `<li><a class="dl" href="/api/catalog/download/${escapeAttribute(id)}/${file}.jpg" download>
        ${DOWNLOAD_ICON}<span>${DOWNLOADS[file].label}<small>${escapeHtml(size)} JPEG</small></span></a></li>`;
}

function downloadsHtml(id: string, phoneSize: string, hasDesktop: boolean): string {
  return `<section class="downloads" aria-labelledby="downloads-title">
      <h2 id="downloads-title">Download free</h2>
      <ul class="dl-list">
        ${downloadItem(id, 'phone', phoneSize)}
        ${hasDesktop ? `${downloadItem(id, 'desktop', '1920 × 1200')}\n        ${downloadItem(id, 'desktop-16x9', '1920 × 1080')}` : ''}
      </ul>
      <p class="note">${hasDesktop
    ? 'Full quality is in Prism: the original phone file and the 2560 × 1600 desktop version.'
    : 'Full quality is in Prism: the original file, set in one tap.'}</p>
    </section>`;
}

/** Desktop mode with a companion: the desktop file leads, and the phone file sits in the list below it. */
function desktopDownloadsHtml(id: string, phoneSize: string): string {
  return `<section class="downloads" aria-labelledby="downloads-title">
      <h2 id="downloads-title">Download free</h2>
      <a class="btn primary dl-lead" href="/api/catalog/download/${escapeAttribute(id)}/desktop.jpg" download>${DOWNLOAD_ICON}<span>Download 1920 × 1200</span></a>
      <ul class="dl-list">
        ${downloadItem(id, 'desktop-16x9', '1920 × 1080')}
        ${downloadItem(id, 'phone', phoneSize)}
      </ul>
      <p class="note">The full 2560 × 1600 desktop file is in Prism.</p>
    </section>`;
}

function monitorHtml(id: string, desktop: Desktop, alt: string, sizes: string, loading: string): string {
  const src = `/api/catalog/desktop/${escapeAttribute(id)}.jpg?v=${escapeAttribute(desktop.v)}`;
  return `<div class="monitor"><img src="${src}"
        srcset="${escapeAttribute(desktop.thumb)} ${DESKTOP_THUMB_WIDTH}w, ${src} ${DOWNLOADS.desktop.width}w"
        sizes="${sizes}" width="${DOWNLOADS.desktop.width}" height="${DOWNLOADS.desktop.height}"
        alt="${escapeAttribute(alt)}" ${loading} decoding="async"></div>
      <div class="stand" aria-hidden="true"></div>`;
}

async function renderFolder(id: string, env: CatalogEnv): Promise<Response> {
  const stored = await readDoc<unknown>(env, `webPages/folder~${id}`);
  const folder = stored == null ? null : parseFolderPage(stored, env);
  if (folder == null) return renderMissing(404, 'folder', env);
  const canonical = `${SITE}/folder/${id}`;
  const owner = folder.owner;
  const count = `${formatCount(folder.total)} ${folder.total === 1 ? 'wallpaper' : 'wallpapers'}`;
  const title = `${folder.name}${owner ? ` by ${owner.name}` : ''}: ${count} | Prism`;
  const description = clip(`${folder.name} is a public Prism folder${owner ? ` by ${owner.name}` : ''} with ${count}. `
    + 'Browse it here, then open it in Prism to follow it.', 160);
  const covers = folder.items.slice(0, 3);
  const body = `
<main class="folder-layout">
  <header class="folder-head">
    ${covers.length ? `<div class="collage" aria-hidden="true">${covers.map((card, index) =>
      `<img src="${escapeAttribute(card.thumb)}" width="${THUMB_WIDTH}" height="${THUMB_HEIGHT}" alt="" ${index === 0 ? 'fetchpriority="high"' : 'loading="lazy"'} decoding="async">`).join('')}</div>` : ''}
    <div class="folder-info">
      ${breadcrumbHtml([['Wallpapers', `${SITE}/wallpapers`], [folder.name, canonical]])}
      <h1>${escapeHtml(folder.name)}</h1>
      <p class="byline">${owner ? `A folder by ${owner.hasPage
    ? `<a href="/creator/${encodeURIComponent(owner.username)}">${escapeHtml(owner.name)}</a>`
    : escapeHtml(owner.name)} · ` : ''}${escapeHtml(count)}</p>
      ${actionsHtml(canonical, 'Open in Prism', env)}
    </div>
  </header>
  ${folder.items.length ? gridHtml(folder.items, covers.length) : '<p class="empty">This folder has no public wallpapers yet.</p>'}
  ${folder.total > folder.items.length ? `<p class="more">Open Prism to see all ${escapeHtml(count)}.</p>` : ''}
</main>`;
  return page({
    title, description, canonical, ogImage: covers[0]?.thumb || OG_HOME, ogType: 'website', body,
    robots: folder.items.length ? 'index,follow,max-image-preview:large' : 'noindex,follow', appUrl: canonical,
    jsonLd: [collectionLd(folder.name, description, canonical, folder.items),
      breadcrumbLd([['Wallpapers', `${SITE}/wallpapers`], [folder.name, canonical]])],
  });
}

async function renderHub(list: 'latest' | 'popular' | 'category', slug: string, pageNumber: number, env: CatalogEnv): Promise<Response> {
  const key = list === 'category' ? `category~${slug}~${pageNumber}` : `${list}~${pageNumber}`;
  const stored = await readDoc<unknown>(env, `webPages/${key}`);
  const data = stored == null ? null : parseListPage(stored, env);
  if (data == null || (data.items.length === 0 && pageNumber > 1)) return renderMissing(404, 'page', env);
  const base = list === 'category' ? `/wallpapers/${slug}` : list === 'popular' ? '/wallpapers/popular' : '/wallpapers';
  const canonical = `${SITE}${base}${pageNumber > 1 ? `?page=${pageNumber}` : ''}`;
  const name = data.name || 'General';
  const heading = list === 'category' ? `${name} wallpapers` : list === 'popular' ? 'Popular wallpapers' : 'New wallpapers';
  const lead = list === 'category'
    ? `${formatCount(data.total)} ${name} wallpapers for Android and iPhone, made by Prism creators.`
    : list === 'popular'
      ? 'The wallpapers Prism users set, save and download the most right now.'
      : 'The newest wallpapers from Prism creators, for Android and iPhone.';
  const suffix = pageNumber > 1 ? ` (page ${pageNumber} of ${data.pages})` : '';
  const title = `${heading}${suffix} | Prism`;
  const description = clip(`${lead}${suffix ? ` Page ${pageNumber} of ${data.pages}.` : ''}`, 160);
  const crumbs: Array<[string, string]> = list === 'latest'
    ? [['Wallpapers', `${SITE}/wallpapers`]]
    : [['Wallpapers', `${SITE}/wallpapers`], [heading, `${SITE}${base}`]];
  const categories = data.categories ?? [];
  const nav = `<nav class="chips" aria-label="Browse wallpapers">
    <a href="/wallpapers"${list === 'latest' ? ' aria-current="page"' : ''}>New</a>
    <a href="/wallpapers/popular"${list === 'popular' ? ' aria-current="page"' : ''}>Popular</a>
    ${categories.map((category) => `<a href="/wallpapers/${escapeAttribute(category.slug)}"${category.slug === slug ? ' aria-current="page"' : ''}>${escapeHtml(category.name)}</a>`).join('')}
  </nav>`;
  const body = `
<main class="hub-layout">
  ${list === 'latest' ? '' : breadcrumbHtml(crumbs)}
  <h1>${escapeHtml(heading)}</h1>
  <p class="lead">${escapeHtml(lead)}</p>
  ${nav}
  ${data.items.length ? gridHtml(data.items, pageNumber === 1 ? 4 : 0) : '<p class="empty">No wallpapers here yet.</p>'}
  ${paginationHtml(base, pageNumber, data.pages)}
  ${appBandHtml(env)}
</main>`;
  return page({
    title, description, canonical, ogImage: OG_HOME, ogType: 'website', body, robots: 'index,follow,max-image-preview:large',
    appUrl: `${SITE}/dashboard`, prev: pageNumber > 1 ? pageHref(base, pageNumber - 1) : '',
    next: pageNumber < data.pages ? pageHref(base, pageNumber + 1) : '',
    jsonLd: [collectionLd(heading, description, canonical, data.items), breadcrumbLd(crumbs)],
  });
}

/** Both hubs read the same `desktop~N` list: one shows the desktop versions, the other shows phone and desktop pairs. */
async function renderDesktopHub(list: 'desktop' | 'sets', pageNumber: number, env: CatalogEnv): Promise<Response> {
  const stored = await readDoc<unknown>(env, `webPages/desktop~${pageNumber}`);
  const data = stored == null ? null : parseListPage(stored, env);
  if (data == null || (data.items.length === 0 && pageNumber > 1)) return renderMissing(404, 'page', env);
  const items = data.items.filter((card) => card.desktop);
  if (items.length === 0 && pageNumber > 1) return renderMissing(404, 'page', env);
  const base = list === 'desktop' ? '/desktop-wallpapers' : '/matching-sets';
  const canonical = `${SITE}${base}${pageNumber > 1 ? `?page=${pageNumber}` : ''}`;
  const heading = list === 'desktop' ? 'Desktop wallpapers' : 'Matching sets';
  const lead = list === 'desktop'
    ? 'Free wallpapers for Mac, Windows and Linux at 1920 × 1200. Each one has a matching phone version.'
    : 'One scene for your phone and your computer. Download both for free, or get them at full quality in Prism.';
  const suffix = pageNumber > 1 ? ` (page ${pageNumber} of ${data.pages})` : '';
  const title = `${heading}${suffix} | Prism`;
  const description = clip(`${lead}${suffix ? ` Page ${pageNumber} of ${data.pages}.` : ''}`, 160);
  const crumbs: Array<[string, string]> = [['Wallpapers', `${SITE}/wallpapers`], [heading, `${SITE}${base}`]];
  const nav = `<nav class="chips" aria-label="Browse wallpapers">
    <a href="/desktop-wallpapers"${list === 'desktop' ? ' aria-current="page"' : ''}>Desktop</a>
    <a href="/matching-sets"${list === 'sets' ? ' aria-current="page"' : ''}>Matching sets</a>
    <a href="/wallpapers">Phone</a>
  </nav>`;
  const cards = items.map((card, index) => {
    const loading = index === 0 ? 'fetchpriority="high" ' : index < 3 ? '' : 'loading="lazy" ';
    const desktopImage = `<img class="desk" src="${escapeAttribute(card.desktop ?? '')}" width="${DESKTOP_THUMB_WIDTH}" height="${DESKTOP_THUMB_HEIGHT}" alt="" ${loading}decoding="async">`;
    const phoneImage = list === 'sets'
      ? `<img class="phone" src="${escapeAttribute(card.thumb)}" width="${THUMB_WIDTH}" height="${THUMB_HEIGHT}" alt="" ${loading}decoding="async">` : '';
    return `<li><a href="/wallpaper/${escapeAttribute(card.id)}${list === 'desktop' ? '#desktop' : ''}">
    <span class="frame">${desktopImage}${phoneImage}</span>
    <span class="desk-title">${escapeHtml(card.title || 'Untitled wallpaper')}</span></a></li>`;
  }).join('');
  const body = `
<main class="hub-layout">
  ${breadcrumbHtml(crumbs)}
  <h1>${escapeHtml(heading)}</h1>
  <p class="lead">${escapeHtml(lead)}</p>
  ${nav}
  ${items.length ? `<ul class="desk-grid${list === 'sets' ? ' sets' : ''}">${cards}</ul>` : '<p class="empty">No desktop wallpapers here yet. New ones come every week.</p>'}
  ${paginationHtml(base, pageNumber, data.pages)}
  ${appBandHtml(env)}
</main>`;
  return page({
    title, description, canonical, ogImage: items[0]?.desktop || OG_HOME, ogType: 'website', body,
    robots: items.length ? 'index,follow,max-image-preview:large' : 'noindex,follow', appUrl: `${SITE}/dashboard`,
    prev: pageNumber > 1 ? pageHref(base, pageNumber - 1) : '',
    next: pageNumber < data.pages ? pageHref(base, pageNumber + 1) : '',
    jsonLd: [collectionLd(heading, description, canonical, items), breadcrumbLd(crumbs)],
  });
}

async function renderCreator(username: string, pageNumber: number, env: CatalogEnv): Promise<Response> {
  const stored = await readDoc<unknown>(env, `webPages/creator~${username}~${pageNumber}`);
  const data = stored == null ? null : parseListPage(stored, env);
  if (data?.creator == null) return renderMissing(404, 'creator', env);
  const creator = data.creator;
  const base = `/creator/${encodeURIComponent(creator.username)}`;
  const canonical = `${SITE}${base}${pageNumber > 1 ? `?page=${pageNumber}` : ''}`;
  const count = `${formatCount(data.total)} ${data.total === 1 ? 'wallpaper' : 'wallpapers'}`;
  const suffix = pageNumber > 1 ? ` (page ${pageNumber} of ${data.pages})` : '';
  const title = `${creator.name} (@${creator.username}): ${count}${suffix} | Prism`;
  const description = clip(creator.bio
    ? `${creator.bio} ${count} by ${creator.name} on Prism.`
    : `${count} by ${creator.name} (@${creator.username}) on Prism, the wallpaper app for Android and iPhone.`, 160);
  const appUrl = `${SITE}/user/${encodeURIComponent(creator.username)}`;
  const folders = pageNumber === 1 ? data.folders ?? [] : [];
  const body = `
<main class="creator-layout">
  <header class="creator-head">
    ${creator.photo ? `<img class="avatar" src="${escapeAttribute(creator.photo)}" width="96" height="96" alt="" referrerpolicy="no-referrer">` : `<span class="avatar initial" aria-hidden="true">${escapeHtml(creator.name.slice(0, 1).toUpperCase())}</span>`}
    <div>
      <h1>${escapeHtml(creator.name)}</h1>
      <p class="byline">@${escapeHtml(creator.username)} · ${escapeHtml(count)}</p>
      ${creator.bio ? `<p class="lead">${escapeHtml(creator.bio)}</p>` : ''}
      ${actionsHtml(appUrl, 'Open profile in Prism', env)}
    </div>
  </header>
  ${folders.length ? `<section class="shelf"><h2>Folders</h2><ul class="folder-row">${folders.map((folder) => `<li><a href="/folder/${escapeAttribute(folder.id)}">
    <img src="${escapeAttribute(folder.cover)}" width="${THUMB_WIDTH}" height="${THUMB_HEIGHT}" alt="" loading="lazy" decoding="async">
    <span class="folder-name">${escapeHtml(folder.name)}</span><span class="folder-count">${formatCount(folder.total)} wallpapers</span></a></li>`).join('')}</ul></section>` : ''}
  <section class="shelf"><h2>Wallpapers</h2>${gridHtml(data.items, pageNumber === 1 ? 4 : 0)}</section>
  ${paginationHtml(base, pageNumber, data.pages)}
</main>`;
  return page({
    title, description, canonical, ogImage: creator.photo || OG_HOME, ogType: 'profile', body,
    robots: 'index,follow,max-image-preview:large', appUrl,
    prev: pageNumber > 1 ? pageHref(base, pageNumber - 1) : '', next: pageNumber < data.pages ? pageHref(base, pageNumber + 1) : '',
    jsonLd: [{
      '@context': 'https://schema.org',
      '@type': 'ProfilePage',
      url: canonical,
      mainEntity: {
        '@type': 'Person', name: creator.name, alternateName: `@${creator.username}`,
        ...(creator.photo ? { image: creator.photo } : {}), ...(creator.bio ? { description: creator.bio } : {}),
      },
    }],
  });
}

async function renderSitemapIndex(env: CatalogEnv): Promise<Response> {
  const stored = await readDoc<unknown>(env, 'webPages/sitemap~index');
  const rawIndex = stored == null ? null : record(stored);
  const sitemaps = rawIndex?.sitemaps;
  if (sitemaps != null && (!Array.isArray(sitemaps) || !sitemaps.every((value) => {
    const item = record(value);
    return typeof item.name === 'string' && typeof item.lastmod === 'string';
  }))) throw new FirestoreUnavailable('invalid sitemap index');
  const index = sitemaps == null ? null : { sitemaps: sitemaps as Array<{ name: string; lastmod: string }> };
  const entries = [`  <sitemap><loc>${SITE}/sitemap-pages.xml</loc></sitemap>`, ...(index?.sitemaps ?? [])
    .filter((entry) => /^[a-z]+-\d{1,4}$/.test(entry.name))
    .map((entry) => `  <sitemap><loc>${SITE}/sitemaps/${entry.name}.xml</loc>${entry.lastmod ? `<lastmod>${escapeHtml(entry.lastmod)}</lastmod>` : ''}</sitemap>`)];
  return xml(`<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${entries.join('\n')}
</sitemapindex>`);
}

async function renderSitemap(name: string, env: CatalogEnv): Promise<Response> {
  const stored = await readDoc<unknown>(env, `webPages/sitemap~${name}`);
  if (stored == null) return new Response('Not found', { status: 404, headers: { 'content-type': 'text/plain; charset=utf-8' } });
  const doc = record(stored);
  if (typeof doc.entries !== 'string') throw new FirestoreUnavailable('invalid sitemap entries');
  const urls = doc.entries.split('\n').filter(Boolean).map((line) => {
    const [path, lastmod] = line.split('\t');
    return `  <url><loc>${escapeHtml(`${SITE}${path}`)}</loc>${lastmod ? `<lastmod>${escapeHtml(lastmod)}</lastmod>` : ''}</url>`;
  });
  return xml(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join('\n')}
</urlset>`);
}

async function renderOgImage(id: string, env: CatalogEnv): Promise<Response> {
  const wallDoc = await readDoc<unknown>(env, `webWalls/${id}`);
  const wall = wallDoc == null ? null : parseWall(wallDoc, env);
  if (wall?.state !== 'live' || !wall.thumb) return redirect(env.OG_FALLBACK_IMAGE || OG_HOME, 302);
  const heading = wall.title || `${wall.category || 'General'} wallpaper`;
  const creatorName = wall.creator?.name || wall.creatorName || '';
  const objectKey = `catalog/wall/${id}-${shortHash(`${wall.thumb}|${heading}|${creatorName}`)}.jpg`;
  const stored = await env.OG_IMAGES?.get(objectKey);
  if (stored) return jpeg(stored.body);
  const bytes = await screenshotCard(renderOgCardHtml({
    kind: 'wallpaper',
    label: 'Wallpaper',
    title: heading,
    image: wall.thumb,
    stats: wall.width && wall.height ? [{ icon: 'phone', value: `${wall.width}×${wall.height}`, label: 'Resolution' }] : [],
    chip: creatorName ? { photo: '', prefix: 'by', name: creatorName, detail: wall.category || '' } : null,
  }), env);
  if (bytes == null) return redirect(wall.thumb, 302);
  await env.OG_IMAGES?.put(objectKey, bytes, { httpMetadata: { contentType: 'image/jpeg' } });
  return jpeg(bytes);
}

async function renderPreview(id: string, env: CatalogEnv): Promise<Response> {
  const wallDoc = await readDoc<unknown>(env, `webWalls/${id}`);
  const wall = wallDoc == null ? null : parseWall(wallDoc, env);
  if (wall?.state !== 'live' || !wall.thumb) return new Response('Not found', { status: 404 });
  const response = await fetchRendition(id, wall, 'phone', env);
  return response ? jpeg(response.body) : redirect(wall.thumb, 302);
}

/** The desktop web rendition, shown in the wall page's desktop mock. Same gate as the phone preview. */
async function renderDesktopImage(id: string, version: string | null, env: CatalogEnv): Promise<Response> {
  const wallDoc = await readDoc<unknown>(env, `webWalls/${id}`);
  const wall = wallDoc == null ? null : parseWall(wallDoc, env);
  if (wall?.state !== 'live' || !wall.thumb || !wall.desktop || version !== wall.desktop.v) {
    return new Response('Not found', { status: 404, headers: { 'cache-control': 'no-store' } });
  }
  const response = await fetchRendition(id, wall, 'desktop', env);
  return response
    ? new Response(response.body, { status: 200, headers: { 'content-type': 'image/jpeg', 'cache-control': 'no-store' } })
    : unavailable();
}

/** One web rendition from wallpaperPreview, which checks the wall again and never returns an original. */
async function fetchRendition(id: string, wall: WebWall, file: DownloadKind, env: CatalogEnv): Promise<Response | null> {
  const origin = env.CATALOG_PREVIEW_ORIGIN || `https://us-central1-${env.FIREBASE_PROJECT_ID}.cloudfunctions.net`;
  const url = new URL(`${origin}/wallpaperPreview`);
  url.searchParams.set('id', id);
  url.searchParams.set('thumb', wall.thumb ?? '');
  if (file !== 'phone') {
    url.searchParams.set('variant', DOWNLOADS[file].variant);
    url.searchParams.set('v', wall.desktop?.v ?? '');
  }
  try {
    const response = await fetch(url.toString(), { signal: AbortSignal.timeout(PREVIEW_TIMEOUT_MS) });
    if (response.ok && response.headers.get('content-type')?.startsWith('image/jpeg')) return response;
  } catch (error) {
    console.warn('[catalog] rendition_fetch_failed', { file, error: `${error}` });
  }
  return null;
}

/**
 * A free web download. Other sites cannot link it (their visitors land on the wall page), each IP gets a small
 * allowance, and the wall's current projection decides, so a takedown or a new gate applies at once. The answer is
 * never stored by any cache, because a stored copy would skip these checks.
 */
async function handleDownload(request: Request, url: URL, route: { id: string; file: DownloadKind }, env: CatalogEnv,
  ctx: ExecutionContext, limitDownload: DownloadLimiter): Promise<Response> {
  const noStore = { 'cache-control': 'no-store', 'x-robots-tag': 'noindex' };
  if (!fromSite(request, url)) {
    return new Response(null, { status: 302, headers: { ...noStore,
      location: `${SITE}/wallpaper/${route.id}${route.file === 'phone' ? '' : '#desktop'}` } });
  }
  const ip = request.headers.get('cf-connecting-ip')?.trim();
  if (!ip) {
    return new Response('Downloads are busy. Try again in a minute.', { status: 503,
      headers: { ...noStore, 'content-type': 'text/plain; charset=utf-8', 'retry-after': '60' } });
  }
  let allowed = false;
  try {
    allowed = await limitDownload(ip);
  } catch (error) {
    console.warn('[catalog] download_limit_failed', `${error}`);
    return new Response('Downloads are busy. Try again in a minute.', { status: 503,
      headers: { ...noStore, 'content-type': 'text/plain; charset=utf-8', 'retry-after': '60' } });
  }
  if (!allowed) {
    return new Response('Too many downloads. Try again later, or get every wallpaper in the Prism app.', { status: 429,
      headers: { ...noStore, 'content-type': 'text/plain; charset=utf-8', 'retry-after': '600' } });
  }
  const notFound = () => new Response('Not found', { status: 404, headers: { ...noStore, 'content-type': 'text/plain; charset=utf-8' } });
  let wall: WebWall | null;
  try {
    const stored = await readDoc<unknown>(env, `webWalls/${route.id}`);
    wall = stored == null ? null : parseWall(stored, env);
  } catch (error) {
    if (!(error instanceof FirestoreUnavailable)) throw error;
    return unavailable();
  }
  if (wall?.state !== 'live' || !wall.thumb || (route.file !== 'phone' && !wall.desktop)) return notFound();
  const rendition = await fetchRendition(route.id, wall, route.file, env);
  if (rendition == null) return unavailable();
  const name = (wall.title || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || route.id;
  ctx.waitUntil(countDownload(env, route.id, route.file));
  return new Response(rendition.body, { status: 200, headers: { ...noStore,
    'content-type': 'image/jpeg',
    'content-disposition': `attachment; filename="prism-${name}-${route.file}.jpg"`,
    'x-content-type-options': 'nosniff' } });
}

/** True for a request that a prismwalls.com page made. Browsers set these headers, so this stops hotlinks, not scripts. */
function fromSite(request: Request, url: URL): boolean {
  if (request.headers.get('sec-fetch-site') === 'cross-site') return false;
  const referer = request.headers.get('referer');
  if (referer) {
    try {
      const from = new URL(referer);
      return from.origin === url.origin || (from.protocol === 'https:' && SITE_HOSTS.includes(from.hostname) && !from.port);
    } catch {
      return false;
    }
  }
  return request.headers.get('sec-fetch-site') === 'same-origin';
}

/** The website's Mixpanel project, with the same `web_` event names and no IP. */
async function countDownload(env: CatalogEnv, id: string, file: DownloadKind): Promise<void> {
  if (!env.MIXPANEL_TOKEN) return;
  try {
    await fetch('https://api-js.mixpanel.com/track?ip=0', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify([{ event: 'web_wallpaper_downloaded', properties: {
        token: env.MIXPANEL_TOKEN, distinct_id: crypto.randomUUID(), $insert_id: crypto.randomUUID(),
        path: `/wallpaper/${id}`, wall_id: id, file } }]),
    });
  } catch (error) {
    console.warn('[catalog] download_count_failed', `${error}`);
  }
}

function renderMissing(status: 404 | 410, what: 'wallpaper' | 'folder' | 'creator' | 'page', env: CatalogEnv): Response {
  const heading = status === 410
    ? 'This wallpaper was removed'
    : { wallpaper: 'This wallpaper is not available', folder: 'This folder is private or was removed',
      creator: 'This creator has no public page', page: 'This page does not exist' }[what];
  const lead = status === 410
    ? 'Its creator or Prism took it down. Browse other wallpapers instead.'
    : 'It may be private, under review, or removed. Browse other wallpapers instead.';
  const markup = documentHtml({
    title: `${heading} | Prism`, description: lead, canonical: '', ogImage: OG_HOME, ogType: 'website',
    robots: 'noindex', appUrl: '', jsonLd: [],
    body: `<main class="missing"><h1>${escapeHtml(heading)}</h1><p class="lead">${escapeHtml(lead)}</p>
      <p><a class="btn primary" href="/wallpapers">Browse wallpapers</a></p>${appBandHtml(env)}</main>`,
  });
  return new Response(markup, { status, headers: { 'content-type': 'text/html; charset=utf-8', 'x-robots-tag': 'noindex' } });
}

function unavailable(): Response {
  return new Response('Prism is busy. Try again in a minute.', {
    status: 503,
    headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store', 'retry-after': '60' },
  });
}

// HTML building blocks.

interface PageInput {
  title: string;
  description: string;
  canonical: string;
  ogImage: string;
  ogType: string;
  robots: string;
  body: string;
  jsonLd: unknown[];
  appUrl: string;
  prev?: string;
  next?: string;
  script?: string;
}

function page(input: PageInput): Response {
  return new Response(documentHtml(input), { status: 200, headers: { 'content-type': 'text/html; charset=utf-8' } });
}

function documentHtml(input: PageInput): string {
  const ld = input.jsonLd.map((entry) => `<script type="application/ld+json">${jsonForScript(entry)}</script>`).join('\n  ');
  const canonical = input.canonical ? `<link rel="canonical" href="${escapeAttribute(input.canonical)}">
  <meta property="og:url" content="${escapeAttribute(input.canonical)}">` : '';
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>${escapeHtml(input.title)}</title>
  <meta name="description" content="${escapeAttribute(input.description)}">
  <meta name="robots" content="${escapeAttribute(input.robots)}">
  ${canonical}
  ${input.prev ? `<link rel="prev" href="${escapeAttribute(input.prev)}">` : ''}
  ${input.next ? `<link rel="next" href="${escapeAttribute(input.next)}">` : ''}
  <meta property="og:site_name" content="Prism">
  <meta property="og:type" content="${escapeAttribute(input.ogType)}">
  <meta property="og:title" content="${escapeAttribute(input.title)}">
  <meta property="og:description" content="${escapeAttribute(input.description)}">
  <meta property="og:image" content="${escapeAttribute(input.ogImage)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeAttribute(input.title)}">
  <meta name="twitter:description" content="${escapeAttribute(input.description)}">
  <meta name="twitter:image" content="${escapeAttribute(input.ogImage)}">
  <meta name="theme-color" content="#0e0e12">
  <meta name="color-scheme" content="dark">
  ${input.appUrl ? `<meta name="apple-itunes-app" content="app-id=6670200846, app-argument=${escapeAttribute(input.appUrl)}">` : ''}
  <link rel="icon" href="/assets/ios.png">
  ${ld}
  <style>${STYLE}</style>
</head>
<body>
  <a class="skip" href="#content">Skip to content</a>
  <header class="site-head">
    <a class="brand" href="/"><img src="${LOGO_URL}" width="28" height="28" alt="">Prism</a>
    <nav aria-label="Main"><a href="/wallpapers">Wallpapers</a><a href="/desktop-wallpapers">Desktop</a><a class="get" href="/#download">Get the app</a></nav>
  </header>
  <div id="content">${input.body}</div>
  <footer class="site-foot">
    <p>Prism is a wallpaper app for Android and iPhone, made by Hash Studios.</p>
    <nav aria-label="Footer"><a href="/wallpapers">Wallpapers</a><a href="/wallpapers/popular">Popular</a><a href="/matching-sets">Matching sets</a><a href="/privacy">Privacy</a><a href="/terms">Terms</a></nav>
  </footer>
  <script>${OPEN_APP_SCRIPT}</script>${input.script ? `\n  <script>${input.script}</script>` : ''}
</body>
</html>`;
}

/** Android opens the app through an intent link with a Play Store fallback. Swapping it in here keeps the HTML the same for every visitor. */
/**
 * iOS opens a universal link in Safari when it points at the page's own host, so on iOS the link goes to the other
 * associated host (prismwalls.com and www.prismwalls.com). Without the app, that host serves the same page.
 */
const OPEN_APP_SCRIPT = `if(/android/i.test(navigator.userAgent))document.querySelectorAll('[data-android]').forEach(function(a){a.href=a.getAttribute('data-android')});`
  + `else if(/iphone|ipad|ipod/i.test(navigator.userAgent)||navigator.maxTouchPoints>1&&/mac/i.test(navigator.platform))`
  + `document.querySelectorAll('[data-android]').forEach(function(a){var u=new URL(a.href);if(u.host===location.host&&(u.host==='${DOMAIN}'||u.host==='www.${DOMAIN}')){`
  + `u.host=u.host.indexOf('www.')===0?u.host.slice(4):'www.'+u.host;a.href=u.href}})`;

function actionsHtml(appUrl: string, label: string, env: CatalogEnv): string {
  return `<div class="actions">
      <a class="btn primary" href="${escapeAttribute(appUrl)}" data-android="${escapeAttribute(buildAndroidIntentUrl(appUrl, env.PLAY_STORE_URL))}">${escapeHtml(label)}</a>
      ${storeButtonsHtml(env)}
    </div>`;
}

function storeButtonsHtml(env: CatalogEnv): string {
  return `<div class="stores">
        <a class="btn store" href="${escapeAttribute(env.PLAY_STORE_URL)}">${PLAY_ICON}<span><small>Get it on</small>Google Play</span></a>
        <a class="btn store" href="${escapeAttribute(env.APP_STORE_URL)}">${APPLE_ICON}<span><small>Download on the</small>App Store</span></a>
      </div>`;
}

function appBandHtml(env: CatalogEnv): string {
  return `<aside class="band"><div><h2>Set any wallpaper in one tap</h2><p>Prism has thousands of wallpapers from real creators, with new ones every day.</p></div>${storeButtonsHtml(env)}</aside>`;
}

function gridHtml(cards: Card[], eager = 0): string {
  return `<ul class="grid">${cards.map((card, index) => `<li><a href="/wallpaper/${escapeAttribute(card.id)}">
    <img src="${escapeAttribute(card.thumb)}" width="${THUMB_WIDTH}" height="${THUMB_HEIGHT}" alt="${card.title ? '' : 'Untitled wallpaper'}" ${index < eager ? '' : 'loading="lazy" '}decoding="async">
    ${card.title ? `<span class="card-title">${escapeHtml(card.title)}</span>` : ''}</a></li>`).join('')}</ul>`;
}

function pageHref(base: string, n: number): string {
  return `${SITE}${base}${n > 1 ? `?page=${n}` : ''}`;
}

function paginationHtml(base: string, current: number, pages: number): string {
  if (pages <= 1) return '';
  const link = (n: number, label: string, rel: string) =>
    `<a href="${escapeAttribute(pageHref(base, n).slice(SITE.length))}" rel="${rel}">${label}</a>`;
  return `<nav class="pager" aria-label="Pages">
    ${current > 1 ? link(current - 1, 'Previous page', 'prev') : '<span></span>'}
    <span>Page ${current} of ${pages}</span>
    ${current < pages ? link(current + 1, 'Next page', 'next') : '<span></span>'}
  </nav>`;
}

function breadcrumbHtml(crumbs: Array<[string, string]>): string {
  return `<nav class="crumbs" aria-label="Breadcrumb"><ol>${crumbs.map(([name, href], index) => index === crumbs.length - 1
    ? `<li aria-current="page">${escapeHtml(name)}</li>`
    : `<li><a href="${escapeAttribute(href.slice(SITE.length) || '/')}">${escapeHtml(name)}</a></li>`).join('')}</ol></nav>`;
}

function breadcrumbLd(crumbs: Array<[string, string]>): unknown {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map(([name, item], index) => ({ '@type': 'ListItem', position: index + 1, name, item })),
  };
}

function collectionLd(name: string, description: string, url: string, cards: Card[]): unknown {
  return {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name,
    description,
    url,
    mainEntity: {
      '@type': 'ItemList',
      itemListElement: cards.map((card, index) => ({ '@type': 'ListItem', position: index + 1, url: `${SITE}/wallpaper/${card.id}` })),
    },
  };
}

/** JSON inside a script tag: `<` is escaped so a title cannot close the tag. */
function jsonForScript(value: unknown): string {
  return JSON.stringify(value).replaceAll('<', '\\u003c').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
}

function clip(value: string, max: number): string {
  return value.length <= max ? value : `${value.slice(0, max - 1).trimEnd()}…`;
}

function shortHash(value: string): string {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
}

function redirect(location: string, status: 301 | 302 = 301): Response {
  return new Response(null, { status, headers: { location } });
}

function jpeg(body: BodyInit | null): Response {
  return new Response(body, { status: 200, headers: { 'content-type': 'image/jpeg' } });
}

function xml(markup: string): Response {
  return new Response(markup, { status: 200, headers: { 'content-type': 'application/xml; charset=utf-8' } });
}

const PLAY_ICON = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" aria-hidden="true"><polygon points="4,3.5 13,8.5 20.5,12 13,15.5 4,20.5 6,12"/></svg>';
const APPLE_ICON = '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M16.37 1.43c0 1.14-.46 2.2-1.2 2.98-.8.85-2.1 1.5-3.14 1.42-.13-1.1.4-2.24 1.15-3 .83-.86 2.2-1.5 3.19-1.4zM20.5 17.1c-.55 1.27-.82 1.84-1.52 2.96-.98 1.57-2.37 3.52-4.08 3.54-1.52.02-1.91-.99-3.97-.98-2.06.01-2.49 1-4.01.99-1.71-.02-3.02-1.78-4-3.35C-.1 15.9-.4 10.7 1.3 8.1c1.2-1.85 3.1-2.93 4.88-2.93 1.81 0 2.95.99 4.45.99 1.45 0 2.34-.99 4.44-.99 1.58 0 3.26.86 4.46 2.35-3.92 2.15-3.28 7.75.97 9.58z"/></svg>';
const DOWNLOAD_ICON = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0-4-4m4 4 4-4M5 19h14"/></svg>';
const DESKTOP_HOWTO = `<section class="desktop-howto" aria-labelledby="desktop-howto-title">
      <h2 id="desktop-howto-title">Use it on your computer</h2>
      <p>This wallpaper has no desktop version yet. You can still set the phone file as your background.</p>
      <ul>
        <li><strong>Windows:</strong> download the file, right-click it, then choose Set as desktop background.</li>
        <li><strong>Mac:</strong> download the file, Control-click it in Finder, then choose Set Desktop Picture.</li>
      </ul>
    </section>`;
/** Phone and Desktop tabs. Arrow keys move between them, and `#desktop` opens the desktop tab. */
const TABS_SCRIPT = `(function(){var m=document.querySelector('[data-views]');if(!m)return;var t=[].slice.call(m.querySelectorAll('[role=tab]'));function show(x,f){t.forEach(function(y){var on=y===x;y.setAttribute('aria-selected',on);y.tabIndex=on?0:-1;document.getElementById(y.getAttribute('aria-controls')).hidden=!on});m.setAttribute('data-view',x.id.slice(4));if(f)x.focus()}t.forEach(function(x,i){x.addEventListener('click',function(){show(x);history.replaceState(null,'',x.id==='tab-desktop'?'#desktop':location.pathname)});x.addEventListener('keydown',function(e){var n=e.key==='ArrowRight'?1:e.key==='ArrowLeft'?-1:0;if(n){e.preventDefault();show(t[(i+n+t.length)%t.length],true)}})});if(location.hash==='#desktop')show(t[1])})()`;
const LOCK_ICON = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';

// Matches prismwalls.com: near-black base, the #e57697 accent, pill buttons and 16px cards.
const STYLE = `
:root{--bg:#0e0e12;--surface:#14141a;--line:rgba(255,255,255,.1);--text:#fff;--muted:rgba(255,255,255,.7);--accent:#e57697;--accent-hover:#ef89a7;--radius:16px;--gutter:clamp(16px,4vw,32px)}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.55 Manrope,Inter,"Segoe UI",system-ui,-apple-system,Roboto,sans-serif;-webkit-font-smoothing:antialiased}
a{color:inherit}
img{display:block;max-width:100%}
h1,h2{line-height:1.15;letter-spacing:-.02em;text-wrap:balance;margin:0}
h1{font-size:clamp(1.9rem,1.4rem + 2.2vw,3rem);font-weight:800}
h2{font-size:1.25rem;font-weight:700}
.skip{position:absolute;left:-9999px}.skip:focus{left:16px;top:16px;z-index:10;background:var(--surface);padding:8px 12px;border-radius:8px}
:focus-visible{outline:2px solid var(--accent);outline-offset:3px;border-radius:6px}
.site-head{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:14px var(--gutter);padding-top:max(14px,env(safe-area-inset-top));max-width:1200px;margin:0 auto}
.brand{display:flex;align-items:center;gap:10px;font-weight:800;font-size:1.1rem;text-decoration:none}
.brand img{border-radius:8px}
.site-head nav{display:flex;gap:4px;align-items:center}
.site-head nav a{text-decoration:none;color:var(--muted);font-weight:600;font-size:.92rem;padding:10px 12px;border-radius:999px;min-height:44px;display:inline-flex;align-items:center}
.site-head nav a:hover{color:var(--text);background:rgba(255,255,255,.06)}
.site-head nav a.get{color:var(--text);background:rgba(255,255,255,.08)}
@media (max-width:520px){.site-head nav a.get{display:none}}
#content{max-width:1200px;margin:0 auto;padding:0 var(--gutter) 48px}
.lead{color:var(--muted);margin:12px 0 0;max-width:62ch}
.byline{color:var(--muted);margin:8px 0 0;font-weight:600}
.byline a{color:var(--text);text-decoration-color:var(--accent);text-underline-offset:3px}
.crumbs ol{list-style:none;display:flex;flex-wrap:wrap;gap:6px;margin:0 0 12px;padding:0;font-size:.85rem;color:var(--muted)}
.crumbs li+li::before{content:"/";margin-inline-end:6px;opacity:.5}
.crumbs a{text-decoration:none}.crumbs a:hover{text-decoration:underline}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:10px;min-height:48px;padding:12px 20px;border-radius:999px;font-weight:700;text-decoration:none;transition:background-color .15s ease-out,transform .15s ease-out}
.btn:active{transform:scale(.98)}
.btn.primary{background:var(--accent);color:#16070c;box-shadow:0 8px 24px -8px rgba(229,118,151,.6)}
.btn.primary:hover{background:var(--accent-hover)}
.btn.store{background:rgba(255,255,255,.06);border:1px solid var(--line);color:#fff;padding:8px 14px;gap:8px;line-height:1.1;text-align:start;white-space:nowrap}
.btn.store:hover{background:rgba(255,255,255,.12)}
.btn.store small{display:block;font-size:.68rem;font-weight:600;color:var(--muted)}
.actions{display:flex;flex-direction:column;gap:12px;margin-top:24px}
.actions .btn.primary{align-self:stretch}
.stores{display:flex;flex-wrap:wrap;gap:12px}
.stores .btn{flex:1 1 150px}
@media (min-width:600px){.actions .btn.primary{align-self:flex-start;min-width:220px}.stores .btn{flex:0 0 auto}}
.wall-layout{display:grid;grid-template-columns:minmax(0,1fr);gap:24px;padding-top:8px}
.wall-figure{margin:0;justify-self:center;width:min(100%,480px,calc(56svh * var(--ar,.5)))}
.wall-img{width:100%;height:auto;border-radius:24px;background:var(--surface);box-shadow:0 30px 60px -20px rgba(0,0,0,.7)}
.wall-img.gated{position:relative;display:grid;place-items:center;background-size:cover;background-position:center;overflow:hidden}
.wall-img.gated::before{content:"";position:absolute;inset:0;backdrop-filter:blur(28px) saturate(1.2);-webkit-backdrop-filter:blur(28px) saturate(1.2);background:rgba(14,14,18,.25)}
.lock{position:relative;display:inline-flex;align-items:center;gap:8px;padding:10px 16px;border-radius:999px;background:rgba(14,14,18,.7);font-weight:700}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:20px 24px;margin:32px 0 0}
.facts dt{font-size:.78rem;color:var(--muted);font-weight:600;margin-bottom:4px}
.facts dd{margin:0;font-weight:700}
.facts dd a{text-decoration-color:var(--accent);text-underline-offset:3px}
.swatches{display:flex;flex-wrap:wrap;gap:10px}
.swatch{display:inline-flex;align-items:center;gap:6px;text-transform:capitalize}
.swatch i{width:16px;height:16px;border-radius:50%;box-shadow:inset 0 0 0 1px rgba(255,255,255,.25)}
.tags{list-style:none;display:flex;flex-wrap:wrap;gap:8px;margin:24px 0 0;padding:0}
.tags li{padding:6px 12px;border-radius:999px;background:rgba(255,255,255,.06);color:var(--muted);font-size:.85rem;font-weight:600}
@media (min-width:960px){
  .wall-layout{grid-template-columns:minmax(0,420px) minmax(0,1fr);gap:64px;align-items:start;padding-top:24px}
  .wall-figure{position:sticky;top:24px;width:min(100%,calc(86svh * var(--ar,.5)));justify-self:start}
  .wall-info{padding-top:24px}
}
.wall-media{display:grid;gap:16px;justify-items:center;align-content:start;min-width:0;width:100%}
.view-tabs{display:inline-flex;gap:4px;padding:4px;border-radius:999px;background:rgba(255,255,255,.06);border:1px solid var(--line)}
.view-tabs button{font:inherit;font-weight:700;font-size:.92rem;color:var(--muted);background:none;border:0;border-radius:999px;min-height:40px;min-width:104px;padding:8px 20px;cursor:pointer;transition:background-color .15s ease-out,color .15s ease-out}
.view-tabs button:hover{color:var(--text)}
.view-tabs button[aria-selected=true]{background:#fff;color:#0e0e12}
.desktop-figure{margin:0;width:100%}
.monitor{padding:clamp(6px,1vw,12px);border-radius:clamp(12px,1.6vw,20px);background:#1b1b21;box-shadow:inset 0 0 0 1px rgba(255,255,255,.09),0 30px 60px -24px rgba(0,0,0,.8)}
.monitor img{width:100%;height:auto;aspect-ratio:16/10;object-fit:cover;border-radius:clamp(6px,.8vw,10px);background:var(--surface)}
.stand{position:relative;width:16%;height:clamp(18px,3vw,40px);margin:0 auto;background:linear-gradient(#24242b,#18181d);clip-path:polygon(22% 0,78% 0,90% 100%,10% 100%)}
.stand::after{content:"";position:absolute;inset:auto -60% -6px;height:6px;border-radius:6px;background:#24242b}
.downloads{margin-top:28px;padding:20px;border-radius:var(--radius);background:var(--surface);border:1px solid var(--line)}
.downloads h2{font-size:1rem}
.dl-list{list-style:none;margin:14px 0 0;padding:0;display:grid;gap:8px;grid-template-columns:repeat(auto-fit,minmax(160px,1fr))}
.dl{display:flex;align-items:center;gap:12px;min-height:56px;padding:10px 14px;border-radius:12px;background:rgba(255,255,255,.07);border:1px solid var(--line);font-weight:700;text-decoration:none;transition:background-color .15s ease-out,transform .15s ease-out}
.dl:hover{background:rgba(255,255,255,.13)}
.dl:active{transform:scale(.98)}
.dl svg{flex:none;color:var(--accent)}
.dl small{display:block;font-size:.76rem;font-weight:600;color:var(--muted);font-variant-numeric:tabular-nums}
.note{color:var(--muted);font-size:.88rem;margin:12px 0 0}
.desk-grid{list-style:none;margin:24px 0 0;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,300px),1fr));gap:20px 16px}
.desk-grid a{display:block;text-decoration:none}
.desk-grid .frame{position:relative;display:block;border-radius:var(--radius);overflow:hidden;background:var(--surface)}
.desk-grid .desk{width:100%;height:auto;aspect-ratio:16/10;object-fit:cover;transition:transform .3s cubic-bezier(.2,.8,.2,1)}
.desk-grid a:hover .desk{transform:scale(1.03)}
.desk-grid.sets .frame{overflow:visible;background:none;padding:0 0 12% 0}
.desk-grid.sets .desk{border-radius:var(--radius);box-shadow:0 20px 40px -20px rgba(0,0,0,.8)}
.desk-grid.sets .phone{position:absolute;right:6%;bottom:0;width:24%;height:auto;aspect-ratio:1/2;object-fit:cover;border-radius:12px;border:3px solid var(--bg);box-shadow:0 16px 32px -12px rgba(0,0,0,.8)}
.desk-title{display:block;margin-top:10px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media (min-width:960px){
  .wall-layout[data-views]{grid-template-columns:minmax(0,520px) minmax(0,1fr)}
  .wall-layout[data-view=desktop]{grid-template-columns:minmax(0,1.6fr) minmax(0,1fr);gap:48px}
  .wall-media{position:sticky;top:24px;justify-items:start}
  .wall-media .wall-figure{position:static;width:min(100%,420px,calc(80svh * var(--ar,.5)))}
}
@media (min-width:1600px){.wall-layout[data-view=desktop]{grid-template-columns:minmax(0,2fr) minmax(0,1fr)}}
.wall-layout.desktop-mode{grid-template-columns:minmax(0,1fr);gap:32px}
.wall-layout.desktop-mode .wall-info{max-width:720px}
.desktop-stage{display:grid;grid-template-columns:minmax(0,1fr);gap:24px;justify-items:center;align-items:end}
.desktop-stage .desktop-lead{width:100%}
.desktop-stage .wall-figure{position:static;width:min(100%,200px);margin:0}
.desktop-stage .wall-img{aspect-ratio:var(--ar,.5);object-fit:cover}
.desktop-mode figcaption{margin-top:10px;text-align:center;color:var(--muted);font-size:.85rem;font-weight:600}
.dl-lead{display:inline-flex;align-items:center;gap:8px;min-height:48px;margin-top:14px}
.desktop-howto{margin-top:28px;padding:20px;border-radius:var(--radius);background:var(--surface);border:1px solid var(--line)}
.desktop-howto h2{font-size:1rem}
.desktop-howto p{color:var(--muted);margin:8px 0 0}
.desktop-howto ul{list-style:none;margin:12px 0 0;padding:0;display:grid;gap:8px;color:var(--muted)}
.desktop-howto strong{color:var(--text)}
@media (min-width:960px){
  .desktop-stage{grid-template-columns:minmax(0,1fr) clamp(150px,17vw,220px);gap:32px;justify-items:stretch}
  .desktop-stage .wall-figure{width:100%}
}
.shelf{margin-top:56px}
.shelf h2{margin-bottom:16px}
.shelf-head{display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin-bottom:16px}
.shelf-head h2{margin:0}
.shelf-head a{color:var(--accent);font-weight:700;text-decoration:none;padding:10px 0}
.grid{list-style:none;margin:24px 0 0;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(min(42vw,168px),1fr));gap:12px}
@media (min-width:960px){.grid{gap:16px;grid-template-columns:repeat(auto-fill,minmax(176px,1fr))}}
.shelf .grid{margin-top:0}
.grid a{display:block;position:relative;border-radius:var(--radius);overflow:hidden;background:var(--surface);text-decoration:none}
.grid img{width:100%;height:auto;aspect-ratio:1/2;object-fit:cover;transition:transform .3s cubic-bezier(.2,.8,.2,1)}
.grid a:hover img{transform:scale(1.03)}
.card-title{position:absolute;inset:auto 0 0;padding:28px 12px 10px;font-size:.82rem;font-weight:700;background:linear-gradient(transparent,rgba(0,0,0,.75));white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.hub-layout{padding-top:16px}
.chips{display:flex;gap:8px;overflow-x:auto;margin:24px calc(-1 * var(--gutter)) 0;padding:0 var(--gutter) 4px;scrollbar-width:none}
.chips a{flex:none;text-decoration:none;font-weight:700;font-size:.9rem;padding:10px 16px;border-radius:999px;background:rgba(255,255,255,.06);min-height:44px;display:inline-flex;align-items:center}
.chips a:hover{background:rgba(255,255,255,.12)}
.chips a[aria-current]{background:#fff;color:#0e0e12}
.pager{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:12px;margin-top:40px;color:var(--muted);font-weight:600}
.pager a{font-weight:700;color:var(--text);text-decoration:none;padding:12px 18px;border-radius:999px;background:rgba(255,255,255,.06);justify-self:start}
.pager a[rel=next]{justify-self:end}
.band{margin-top:64px;padding:28px;border-radius:24px;background:linear-gradient(135deg,rgba(229,118,151,.22),rgba(229,118,151,.04));display:grid;gap:20px}
.band p{color:var(--muted);margin:8px 0 0}
@media (min-width:800px){.band{grid-template-columns:1fr auto;align-items:center;padding:36px 40px}}
.folder-head{display:grid;gap:28px;padding:16px 0 40px}
.collage{display:flex;justify-content:center;height:clamp(220px,52vw,320px)}
.collage img{height:100%;width:auto;aspect-ratio:1/2;object-fit:cover;border-radius:18px;box-shadow:0 20px 40px -12px rgba(0,0,0,.7);border:3px solid var(--bg)}
.collage img:nth-child(1){position:relative;z-index:3}
.collage img:nth-child(2){margin-inline-start:-18%;transform:rotate(6deg) translateY(10px);z-index:2}
.collage img:nth-child(3){margin-inline-start:-18%;transform:rotate(11deg) translateY(22px);z-index:1}
@media (min-width:860px){.folder-head{grid-template-columns:auto 1fr;align-items:center;gap:56px}.collage{justify-content:flex-start;height:340px;padding-inline-end:40px}}
.empty,.more{color:var(--muted);margin-top:24px}
.creator-head{display:grid;gap:20px;padding-top:16px;justify-items:start}
.avatar{width:96px;height:96px;border-radius:50%;object-fit:cover;background:var(--surface);box-shadow:0 0 0 3px var(--bg),0 0 0 5px var(--accent)}
.avatar.initial{display:grid;place-items:center;font-size:2.2rem;font-weight:800}
@media (min-width:760px){.creator-head{grid-template-columns:auto 1fr;gap:32px;align-items:start}}
.folder-row{list-style:none;margin:0;padding:0;display:grid;grid-auto-flow:column;grid-auto-columns:minmax(140px,180px);gap:12px;overflow-x:auto;scrollbar-width:none}
.folder-row a{display:block;text-decoration:none}
.folder-row img{width:100%;height:auto;aspect-ratio:3/4;object-fit:cover;border-radius:var(--radius)}
.folder-name{display:block;font-weight:700;margin-top:8px}
.folder-count{display:block;color:var(--muted);font-size:.85rem}
.missing{padding-top:48px;max-width:640px}
.missing .btn{margin-top:24px}
.site-foot{max-width:1200px;margin:0 auto;padding:32px var(--gutter) max(32px,env(safe-area-inset-bottom));border-top:1px solid var(--line);color:var(--muted);font-size:.9rem;display:flex;flex-wrap:wrap;gap:12px 24px;justify-content:space-between}
.site-foot p{margin:0}
.site-foot nav{display:flex;gap:20px}
.site-foot a{text-decoration:none}.site-foot a:hover{color:var(--text)}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
`;
