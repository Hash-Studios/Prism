// Thumbnails of walls uploaded before owned storage still live in the GitHub walls repo. Some networks block
// raw.githubusercontent.com, so the app can load the same thumbnail through prismwalls.com instead. Only `thumb_` files
// of the configured repo pass: never originals, never another URL, and never the request's or GitHub's headers.

export interface LegacyThumbEnv {
  GH_USERNAME?: string;
  GH_REPO_WALLS?: string;
}

const PREFIX = '/api/legacy-thumbs/';
const UPSTREAM = 'https://raw.githubusercontent.com';
const CACHE_PREFIX = 'https://prismwalls.com/__legacy-thumbs/v1';
const CACHE_SECONDS = 86400;
const TIMEOUT_MS = 8000;
const MAX_BYTES = 4 * 1024 * 1024;
const MAX_PATH_LENGTH = 1024;
const OWNER = /^[A-Za-z0-9-]{1,39}$/;
const REPO = /^(?!\.{1,2}$)[A-Za-z0-9._-]{1,100}$/;
const REF = /^[A-Za-z0-9._-]{1,255}$/;
const UNSAFE_SEGMENT = /[/\\%?#\u0000-\u001f\u007f]/;
// GitHub types files by extension. The bytes decide the type that is served.
const UPSTREAM_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/octet-stream']);
const MESSAGES: Record<number, string> = {
  404: 'Not found',
  405: 'Method not allowed',
  502: 'Thumbnail unavailable',
  503: 'Legacy thumbnails are not configured',
  504: 'Thumbnail timed out',
};

export async function handleLegacyThumbRequest(
  request: Request, url: URL, env: LegacyThumbEnv, ctx: ExecutionContext,
): Promise<Response | null> {
  if (!url.pathname.startsWith(PREFIX)) return null;
  if (request.method !== 'GET' && request.method !== 'HEAD') return failure(request, 405, { allow: 'GET, HEAD' });
  const owner = env.GH_USERNAME?.trim() ?? '';
  const repo = env.GH_REPO_WALLS?.trim() ?? '';
  if (!OWNER.test(owner) || !REPO.test(repo)) return failure(request, 503);
  const path = url.search ? null : thumbPath(url.pathname.slice(PREFIX.length));
  if (path == null) return failure(request, 404);

  const repoPath = `${owner}/${repo}/${path}`;
  const cache = edgeCache();
  const cacheKey = new Request(`${CACHE_PREFIX}/${repoPath}`);
  const head = request.method === 'HEAD';
  const hit = cache ? await cache.match(cacheKey) : undefined;
  if (hit) {
    if (head) await hit.body?.cancel();
    return image(head ? null : hit.body, hit.headers.get('content-type') ?? '', hit.headers.get('content-length'));
  }

  const thumb = await fetchThumb(`${UPSTREAM}/${repoPath}`);
  if (typeof thumb === 'number') return failure(request, thumb);
  const length = `${thumb.bytes.byteLength}`;
  if (cache) {
    ctx.waitUntil(cache.put(cacheKey, image(thumb.bytes, thumb.type, length))
      .catch((error) => console.warn('[legacy-thumbs] cache_put_failed', `${error}`)));
  }
  return image(head ? null : thumb.bytes, thumb.type, length);
}

function thumbPath(rest: string): string | null {
  if (rest.length > MAX_PATH_LENGTH) return null;
  const segments: string[] = [];
  for (const raw of rest.split('/')) {
    let segment: string;
    try {
      segment = decodeURIComponent(raw);
    } catch {
      return null;
    }
    if (!segment || segment === '.' || segment === '..' || UNSAFE_SEGMENT.test(segment)) return null;
    segments.push(segment);
  }
  const name = segments.at(-1) ?? '';
  if (segments.length < 2 || !REF.test(segments[0]) || !name.startsWith('thumb_') || name === 'thumb_') return null;
  return segments.map(encodeURIComponent).join('/');
}

async function fetchThumb(target: string): Promise<{ bytes: Uint8Array; type: string } | number> {
  const signal = AbortSignal.timeout(TIMEOUT_MS);
  try {
    // A fresh request: no cookie, credential or client header reaches GitHub, and a redirect is refused, not followed.
    const upstream = await fetch(target, { method: 'GET', headers: { accept: 'image/*' }, redirect: 'manual', signal });
    const declared = (upstream.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase();
    const length = Number(upstream.headers.get('content-length') ?? 0);
    if (upstream.status !== 200 || !UPSTREAM_TYPES.has(declared) || length > MAX_BYTES) {
      await upstream.body?.cancel().catch(() => undefined);
      if (upstream.status === 404) return 404;
      console.warn('[legacy-thumbs] upstream_rejected', { status: upstream.status, type: declared, length });
      return 502;
    }
    const bytes = await readBounded(upstream.body, signal);
    const type = bytes == null ? null : imageType(bytes);
    if (bytes == null || type == null) {
      console.warn('[legacy-thumbs] upstream_rejected', { status: upstream.status, type: declared, bytes: bytes?.byteLength });
      return 502;
    }
    return { bytes, type };
  } catch (error) {
    console.warn('[legacy-thumbs] upstream_failed', { timeout: signal.aborted, error: `${error}` });
    return signal.aborted ? 504 : 502;
  }
}

async function readBounded(body: ReadableStream<Uint8Array> | null, signal: AbortSignal): Promise<Uint8Array | null> {
  if (body == null) return null;
  const reader = body.getReader();
  const stop = () => { reader.cancel(signal.reason).catch(() => undefined); };
  signal.addEventListener('abort', stop, { once: true });
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (signal.aborted) throw signal.reason;
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BYTES) {
        await reader.cancel().catch(() => undefined);
        return null;
      }
      chunks.push(value);
    }
  } finally {
    signal.removeEventListener('abort', stop);
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

function imageType(bytes: Uint8Array): string | null {
  const ascii = (from: number, to: number) => String.fromCharCode(...bytes.subarray(from, to));
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (ascii(0, 8) === '\x89PNG\r\n\x1a\n') return 'image/png';
  if (ascii(0, 6) === 'GIF87a' || ascii(0, 6) === 'GIF89a') return 'image/gif';
  if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') return 'image/webp';
  return null;
}

function edgeCache(): Cache | null {
  return (globalThis as { caches?: { default?: Cache } }).caches?.default ?? null;
}

function image(body: BodyInit | null, type: string, length: string | null): Response {
  const headers = new Headers({
    'content-type': type,
    'cache-control': `public, max-age=${CACHE_SECONDS}`,
    'x-content-type-options': 'nosniff',
  });
  if (length) headers.set('content-length', length);
  return new Response(body, { status: 200, headers });
}

function failure(request: Request, status: number, extra: Record<string, string> = {}): Response {
  return new Response(request.method === 'HEAD' ? null : MESSAGES[status], {
    status,
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      ...extra,
    },
  });
}
