import {createHmac, randomBytes} from "node:crypto";
import {defineSecret} from "firebase-functions/params";

// X API v2 with OAuth 1.0a user tokens for @PrismWallpapers. Static tokens, so nothing to refresh or store.
export const xApiKey = defineSecret("X_API_KEY");
export const xApiSecret = defineSecret("X_API_SECRET");
export const xAccessToken = defineSecret("X_ACCESS_TOKEN");
export const xAccessSecret = defineSecret("X_ACCESS_SECRET");
export const xSecrets = [xApiKey, xApiSecret, xAccessToken, xAccessSecret];

const API = "https://api.x.com";

export interface XCredentials {apiKey: string; apiSecret: string; token: string; tokenSecret: string}

/** RFC 3986 encoding, as OAuth 1.0a requires. */
const enc = (value: string) => encodeURIComponent(value).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);

/** The OAuth 1.0a Authorization header. JSON and multipart bodies are not signed; only query parameters are. */
export function oauthHeader(method: string, url: string, creds: XCredentials,
  nonce = randomBytes(16).toString("hex"), timestamp = Math.floor(Date.now() / 1000).toString(),
  extraParams: Record<string, string> = {}): string {
  const parsed = new URL(url);
  const oauth: Record<string, string> = {
    oauth_consumer_key: creds.apiKey, oauth_nonce: nonce, oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: timestamp, oauth_token: creds.token, oauth_version: "1.0",
  };
  const params: Array<[string, string]> = [...Object.entries(oauth), ...Object.entries(extraParams),
    ...[...parsed.searchParams.entries()]].map(([k, v]) => [enc(k), enc(v)]);
  params.sort(([ak, av], [bk, bv]) => ak < bk ? -1 : ak > bk ? 1 : av < bv ? -1 : av > bv ? 1 : 0);
  const base = [method.toUpperCase(), enc(`${parsed.origin}${parsed.pathname}`),
    enc(params.map(([k, v]) => `${k}=${v}`).join("&"))].join("&");
  const signature = createHmac("sha1", `${enc(creds.apiSecret)}&${enc(creds.tokenSecret)}`).update(base).digest("base64");
  return "OAuth " + Object.entries({...oauth, oauth_signature: signature})
    .map(([k, v]) => `${enc(k)}="${enc(v)}"`).join(", ");
}

/** Status of a failed X call. `posted` is unknown when the request may have reached X. */
export class XError extends Error {
  constructor(message: string, readonly status: number, readonly uncertain = false) {
    super(message);
  }
  /** A refusal X sends before it acts: rate limit. The next run may try again. */
  get retryable(): boolean {
    return this.status === 429;
  }
}

export interface XPostMetrics {
  impressions: number; likes: number; reposts: number; replies: number; quotes: number; bookmarks: number;
  linkClicks: number; profileClicks: number;
}

export interface XOwnPost {id: string; text: string; createdAt: string; mediaCount: number; mediaIds?: string[]; replyTo: string | null}

export interface XClient {
  uploadImage(jpeg: Buffer): Promise<string>;
  setMediaMetadata(mediaId: string, alt: string, sensitive: boolean): Promise<void>;
  createPost(text: string, options: {mediaIds?: string[]; replyTo?: string}): Promise<string>;
  me(): Promise<string>;
  ownPostsSince(userId: string, since: Date): Promise<XOwnPost[]>;
  metrics(ids: string[]): Promise<Record<string, XPostMetrics>>;
}

const num = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? value : 0;

export function xClient(creds: XCredentials, request: typeof fetch = fetch): XClient {
  async function call(method: string, path: string, body?: {json?: unknown; form?: FormData}): Promise<any> {
    const url = `${API}${path}`;
    let res: Response;
    try {
      res = await request(url, {
        method,
        headers: {
          "Authorization": oauthHeader(method, url, creds),
          ...(body?.json === undefined ? {} : {"Content-Type": "application/json"}),
        },
        body: body?.json !== undefined ? JSON.stringify(body.json) : body?.form,
        signal: AbortSignal.timeout(60_000),
      });
    } catch {
      // The request may have reached X. For a create call the caller must treat this as uncertain.
      throw new XError(`X ${method} ${path.split("?")[0]} request failed`, 0, true);
    }
    if (!res.ok) {
      // A 5xx from X can still mean the post was made; a 4xx is a refusal before any action.
      throw new XError(`X ${method} ${path.split("?")[0]} failed: ${res.status}`, res.status, res.status >= 500);
    }
    try {
      const text = await res.text();
      return text ? JSON.parse(text) : {};
    } catch {
      throw new XError(`X ${method} ${path.split("?")[0]} returned invalid JSON`, res.status, true);
    }
  }

  return {
    async uploadImage(jpeg) {
      const form = new FormData();
      form.set("media", new Blob([new Uint8Array(jpeg)], {type: "image/jpeg"}), "wall.jpg");
      form.set("media_category", "tweet_image");
      const id = (await call("POST", "/2/media/upload", {form}))?.data?.id;
      if (typeof id !== "string" || id === "") throw new XError("X media upload returned no id", 200);
      return id;
    },
    async setMediaMetadata(mediaId, alt, sensitive) {
      // ponytail: sensitive_media_warning shape is not fully documented; phase 0 checks it on a test account.
      await call("POST", "/2/media/metadata", {json: {id: mediaId, metadata: {
        alt_text: {text: alt.slice(0, 1000)},
        ...(sensitive ? {sensitive_media_warning: {adult_content: true}} : {}),
      }}});
    },
    async createPost(text, {mediaIds, replyTo}) {
      const id = (await call("POST", "/2/tweets", {json: {
        text,
        ...(mediaIds?.length ? {media: {media_ids: mediaIds}} : {}),
        ...(replyTo ? {reply: {in_reply_to_tweet_id: replyTo}} : {}),
      }}))?.data?.id;
      if (typeof id !== "string" || id === "") throw new XError("X create post returned no id", 200, true);
      return id;
    },
    async me() {
      const id = (await call("GET", "/2/users/me"))?.data?.id;
      if (typeof id !== "string" || id === "") throw new XError("X users/me returned no id", 200);
      return id;
    },
    async ownPostsSince(userId, since) {
      const posts: XOwnPost[] = [];
      const tokens = new Set<string>();
      let next: string | undefined;
      do {
        const query = new URLSearchParams({
          "start_time": since.toISOString().replace(/\.\d{3}Z$/, "Z"),
          "max_results": "100",
          "tweet.fields": "created_at,attachments,referenced_tweets,entities",
          ...(next ? {pagination_token: next} : {}),
        });
        const page = await call("GET", `/2/users/${encodeURIComponent(userId)}/tweets?${query}`);
        if (page.errors?.length) throw new XError("X own-post read was incomplete", 200);
        for (const post of Array.isArray(page.data) ? page.data : []) {
          let text = String(post?.text ?? "");
          for (const url of Array.isArray(post?.entities?.urls) ? post.entities.urls : []) {
            if (typeof url.url === "string" && typeof url.expanded_url === "string" &&
                !/\/status\/\d+\/(?:photo|video)\//.test(url.expanded_url)) {
              text = text.split(url.url).join(url.expanded_url);
            }
          }
          posts.push({
            id: String(post?.id ?? ""), text, createdAt: String(post?.created_at ?? ""),
            mediaCount: Array.isArray(post?.attachments?.media_keys) ? post.attachments.media_keys.length : 0,
            mediaIds: Array.isArray(post?.attachments?.media_keys) ?
              post.attachments.media_keys.map((key: string) => key.slice(key.indexOf("_") + 1)) : [],
            replyTo: (Array.isArray(post?.referenced_tweets) ?
              post.referenced_tweets.find((r: any) => r?.type === "replied_to")?.id : null) ?? null,
          });
        }
        next = typeof page.meta?.next_token === "string" ? page.meta.next_token : undefined;
        if (next && tokens.has(next)) throw new XError("X own-post pagination repeated", 200);
        if (next) tokens.add(next);
      } while (next);
      return posts;
    },
    async metrics(ids) {
      const out: Record<string, XPostMetrics> = {};
      for (let i = 0; i < ids.length; i += 100) {
        const query = new URLSearchParams({"ids": ids.slice(i, i + 100).join(","),
          "tweet.fields": "public_metrics,non_public_metrics"});
        const data = (await call("GET", `/2/tweets?${query}`))?.data;
        for (const post of Array.isArray(data) ? data : []) {
          const p = post?.public_metrics ?? {};
          const n = post?.non_public_metrics ?? {};
          out[String(post?.id)] = {impressions: num(n.impression_count ?? p.impression_count), likes: num(p.like_count),
            reposts: num(p.retweet_count), replies: num(p.reply_count), quotes: num(p.quote_count),
            bookmarks: num(p.bookmark_count), linkClicks: num(n.url_link_clicks), profileClicks: num(n.user_profile_clicks)};
        }
      }
      return out;
    },
  };
}

const URL_PATTERN = /https?:\/\/\S+/g;

/**
 * X's weighted length: a URL counts 23, and characters outside Latin and common punctuation count 2 (emoji, CJK).
 * ponytail: approximates twitter-text's ranges; enough to keep templated captions under 280.
 */
export function xWeightedLength(text: string): number {
  const urls = text.match(URL_PATTERN) ?? [];
  let length = urls.length * 23;
  for (const ch of text.replace(URL_PATTERN, "")) {
    const cp = ch.codePointAt(0) ?? 0;
    length += cp <= 0x10ff || (cp >= 0x2000 && cp <= 0x200d) || (cp >= 0x2010 && cp <= 0x201f) ||
      (cp >= 0x2032 && cp <= 0x2037) ? 1 : 2;
  }
  return length;
}
