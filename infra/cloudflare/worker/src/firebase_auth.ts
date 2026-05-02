export interface FirebaseAuthEnvBindings {
  AI_STATE_KV: KVNamespace;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_AUTH_DEBUG?: string;
}

export interface VerifiedFirebaseAuth {
  token: string;
  userId: string;
  claims: Record<string, unknown>;
}

interface FirebaseJwtHeader {
  alg?: string;
  kid?: string;
}

interface FirebaseJwk {
  kty?: string;
  alg?: string;
  use?: string;
  kid?: string;
  n?: string;
  e?: string;
}

interface JwksCachePayload {
  fetchedAt: string;
  expiresAtMs: number;
  keys: FirebaseJwk[];
}

const FIREBASE_JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const FIREBASE_JWKS_CACHE_KEY = 'ai:firebase:jwks:v1';
const DEFAULT_JWKS_TTL_SECONDS = 60 * 60;
const MAX_CLOCK_SKEW_SECONDS = 300;

let memoryJwksCache: JwksCachePayload | null = null;
const importedKeyCache = new Map<string, CryptoKey>();

export async function verifyFirebaseIdTokenFromRequest(
  request: Request,
  env: FirebaseAuthEnvBindings,
): Promise<VerifiedFirebaseAuth | null> {
  const authHeader = request.headers.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/.exec(authHeader);
  if (match == null) {
    debugAuth(env, 'missing_bearer_header');
    return null;
  }

  const token = match[1].trim();
  if (token.length < 20) {
    debugAuth(env, 'invalid_bearer_token_length');
    return null;
  }

  const projectId = asString(env.FIREBASE_PROJECT_ID);
  if (projectId.length === 0) {
    console.error('[auth] FIREBASE_PROJECT_ID is missing');
    return null;
  }

  const parts = token.split('.');
  if (parts.length !== 3) {
    debugAuth(env, 'jwt_parts_invalid');
    return null;
  }

  const header = tryParseJson<FirebaseJwtHeader>(decodeBase64UrlToString(parts[0]));
  const claims = tryParseJson<Record<string, unknown>>(decodeBase64UrlToString(parts[1]));
  if (header == null || claims == null) {
    debugAuth(env, 'jwt_decode_failed');
    return null;
  }

  if (header.alg !== 'RS256' || !isNonEmptyString(header.kid)) {
    debugAuth(env, 'jwt_header_invalid');
    return null;
  }

  if (!validateFirebaseClaims(claims, projectId, env)) {
    return null;
  }

  const jwk = await getFirebaseJwk(header.kid, env);
  if (jwk == null) {
    debugAuth(env, `jwk_missing:${header.kid}`);
    return null;
  }

  const verified = await verifyJwtSignature(parts, jwk, env);
  if (!verified) {
    debugAuth(env, 'jwt_signature_invalid');
    return null;
  }

  const userId = asString(claims['sub']);
  if (userId.length === 0) {
    debugAuth(env, 'jwt_sub_missing');
    return null;
  }

  return { token, userId, claims };
}

async function getFirebaseJwk(kid: string, env: FirebaseAuthEnvBindings): Promise<FirebaseJwk | null> {
  const nowMs = Date.now();
  if (memoryJwksCache != null && memoryJwksCache.expiresAtMs > nowMs) {
    const hit = memoryJwksCache.keys.find((key) => key.kid === kid);
    if (hit != null) {
      return hit;
    }
  }

  const cachedKv = await readCachedJwksFromKv(env, nowMs);
  if (cachedKv != null) {
    memoryJwksCache = cachedKv;
    const hit = cachedKv.keys.find((key) => key.kid === kid);
    if (hit != null) {
      return hit;
    }
  }

  const fetched = await fetchJwksFromGoogle(env);
  if (fetched == null) {
    return null;
  }
  memoryJwksCache = fetched;
  await cacheJwksToKv(fetched, env);
  return fetched.keys.find((key) => key.kid === kid) ?? null;
}

async function verifyJwtSignature(
  parts: string[],
  jwk: FirebaseJwk,
  env: FirebaseAuthEnvBindings,
): Promise<boolean> {
  if (!isNonEmptyString(jwk.kid) || !isNonEmptyString(jwk.n) || !isNonEmptyString(jwk.e)) {
    debugAuth(env, 'jwk_shape_invalid');
    return false;
  }

  const keyCacheId = `${jwk.kid}:${jwk.n.substring(0, 12)}:${jwk.e}`;
  let cryptoKey = importedKeyCache.get(keyCacheId);
  if (cryptoKey == null) {
    try {
      cryptoKey = await crypto.subtle.importKey(
        'jwk',
        {
          kty: 'RSA',
          alg: 'RS256',
          n: jwk.n,
          e: jwk.e,
          ext: true,
          key_ops: ['verify'],
        },
        {
          name: 'RSASSA-PKCS1-v1_5',
          hash: 'SHA-256',
        },
        false,
        ['verify'],
      );
      importedKeyCache.set(keyCacheId, cryptoKey);
    } catch (error) {
      debugAuth(env, `jwk_import_failed:${error}`);
      return false;
    }
  }

  try {
    const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const signature = decodeBase64UrlToBytes(parts[2]);
    return await crypto.subtle.verify('RSASSA-PKCS1-v1_5', cryptoKey, signature, data);
  } catch (error) {
    debugAuth(env, `jwt_verify_failed:${error}`);
    return false;
  }
}

function validateFirebaseClaims(
  claims: Record<string, unknown>,
  projectId: string,
  env: FirebaseAuthEnvBindings,
): boolean {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const issuer = `https://securetoken.google.com/${projectId}`;

  const aud = asString(claims['aud']);
  if (aud !== projectId) {
    debugAuth(env, `claim_aud_invalid:${aud}`);
    return false;
  }

  const iss = asString(claims['iss']);
  if (iss !== issuer) {
    debugAuth(env, `claim_iss_invalid:${iss}`);
    return false;
  }

  const sub = asString(claims['sub']);
  if (sub.length === 0 || sub.length > 128) {
    debugAuth(env, 'claim_sub_invalid');
    return false;
  }

  const exp = asInt(claims['exp']);
  if (exp <= nowSeconds - MAX_CLOCK_SKEW_SECONDS) {
    debugAuth(env, 'claim_exp_expired');
    return false;
  }

  const iat = asInt(claims['iat']);
  if (iat > nowSeconds + MAX_CLOCK_SKEW_SECONDS) {
    debugAuth(env, 'claim_iat_future');
    return false;
  }

  const authTime = asInt(claims['auth_time']);
  if (authTime > 0 && authTime > nowSeconds + MAX_CLOCK_SKEW_SECONDS) {
    debugAuth(env, 'claim_auth_time_future');
    return false;
  }

  return true;
}

async function fetchJwksFromGoogle(env: FirebaseAuthEnvBindings): Promise<JwksCachePayload | null> {
  try {
    const response = await fetch(FIREBASE_JWKS_URL, {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) {
      debugAuth(env, `jwks_fetch_failed:${response.status}`);
      return null;
    }

    const raw = await response.json() as Record<string, unknown>;
    const keys = Array.isArray(raw.keys) ? raw.keys : [];
    const normalizedKeys = keys
      .map((item) => item as FirebaseJwk)
      .filter(
        (key) =>
          key.kty === 'RSA' &&
          key.use === 'sig' &&
          key.alg === 'RS256' &&
          isNonEmptyString(key.kid) &&
          isNonEmptyString(key.n) &&
          isNonEmptyString(key.e),
      );
    if (normalizedKeys.length === 0) {
      debugAuth(env, 'jwks_no_valid_keys');
      return null;
    }

    const ttlSeconds = parseCacheMaxAgeSeconds(response.headers.get('cache-control'));
    return {
      fetchedAt: new Date().toISOString(),
      expiresAtMs: Date.now() + ttlSeconds * 1000,
      keys: normalizedKeys,
    };
  } catch (error) {
    debugAuth(env, `jwks_fetch_exception:${error}`);
    return null;
  }
}

async function readCachedJwksFromKv(
  env: FirebaseAuthEnvBindings,
  nowMs: number,
): Promise<JwksCachePayload | null> {
  try {
    const raw = await env.AI_STATE_KV.get(FIREBASE_JWKS_CACHE_KEY);
    if (!isNonEmptyString(raw)) {
      return null;
    }
    const parsed = JSON.parse(raw) as JwksCachePayload;
    if (parsed.expiresAtMs <= nowMs || !Array.isArray(parsed.keys) || parsed.keys.length === 0) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

async function cacheJwksToKv(cache: JwksCachePayload, env: FirebaseAuthEnvBindings): Promise<void> {
  const ttlSeconds = Math.max(60, Math.floor((cache.expiresAtMs - Date.now()) / 1000));
  await env.AI_STATE_KV.put(FIREBASE_JWKS_CACHE_KEY, JSON.stringify(cache), {
    expirationTtl: ttlSeconds,
  });
}

function parseCacheMaxAgeSeconds(cacheControl: string | null): number {
  if (!isNonEmptyString(cacheControl)) {
    return DEFAULT_JWKS_TTL_SECONDS;
  }
  const match = /max-age=(\d+)/i.exec(cacheControl);
  if (match == null) {
    return DEFAULT_JWKS_TTL_SECONDS;
  }
  const value = Number.parseInt(match[1], 10);
  if (!Number.isFinite(value) || value <= 0) {
    return DEFAULT_JWKS_TTL_SECONDS;
  }
  return Math.max(60, Math.min(24 * 60 * 60, value));
}

function decodeBase64UrlToString(value: string): string {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  return atob(padded);
}

function decodeBase64UrlToBytes(value: string): Uint8Array {
  const binary = decodeBase64UrlToString(value);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function tryParseJson<T>(raw: string): T | null {
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asInt(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.floor(value);
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function shouldDebug(env: FirebaseAuthEnvBindings): boolean {
  return (env.FIREBASE_AUTH_DEBUG ?? '').trim().toLowerCase() === 'true';
}

function debugAuth(env: FirebaseAuthEnvBindings, message: string): void {
  if (shouldDebug(env)) {
    console.warn('[auth]', message);
  }
}
