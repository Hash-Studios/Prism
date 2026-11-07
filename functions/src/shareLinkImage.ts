import {lookup} from "node:dns/promises";
import type {IncomingHttpHeaders} from "node:http";
import * as https from "node:https";
import {BlockList, isIPv4, isIPv6} from "node:net";
import type {LookupFunction} from "node:net";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {CALLABLE_REGIONS} from "./common";

/**
 * Finds the og:image of a page that a user shared to Prism. The server reads only the page HTML, never the image,
 * and stores nothing. The app downloads the image itself.
 */

export const LINK_TIMEOUT_MS = 5000;
export const MAX_HTML_BYTES = 512 * 1024;
export const MAX_REDIRECTS = 3;
export const MAX_URL_LENGTH = 2048;

export type LinkImageResult =
  | {status: "found"; imageUrl: string}
  | {status: "none"; reason: "invalid_url" | "blocked" | "no_image" | "timeout" | "too_large" | "error"};

export type Address = {address: string; family: number};

export interface LinkResponse {
  status: number;
  headers: IncomingHttpHeaders;
  body: AsyncIterable<Buffer>;
  /** Stops reading and frees the socket. */
  close(): void;
}

export interface LinkDeps {
  resolve(host: string): Promise<Address[]>;
  /** One GET to [url] that connects only to [address]. Never follows redirects. */
  get(url: URL, address: Address, signal: AbortSignal): Promise<LinkResponse>;
}

const blocked = new BlockList();
for (const [network, prefix] of [
  ["0.0.0.0", 8], ["10.0.0.0", 8], ["100.64.0.0", 10], ["127.0.0.0", 8], ["169.254.0.0", 16], ["172.16.0.0", 12],
  ["192.0.0.0", 24], ["192.0.2.0", 24], ["192.88.99.0", 24], ["192.168.0.0", 16], ["198.18.0.0", 15],
  ["198.51.100.0", 24], ["203.0.113.0", 24], ["224.0.0.0", 4], ["240.0.0.0", 4],
] as const) {
  blocked.addSubnet(network, prefix, "ipv4");
}
for (const [network, prefix] of [
  ["::", 128], ["::1", 128], ["100::", 64], ["2001::", 23], ["2001:db8::", 32], ["2002::", 16], ["fc00::", 7],
  ["3ffe::", 16], ["3fff::", 20], ["fe80::", 10], ["fec0::", 10], ["ff00::", 8],
] as const) {
  blocked.addSubnet(network, prefix, "ipv6");
}

/** True for a globally routable address, excluding IPv4 transition forms. */
export function isPublicAddress(address: string): boolean {
  if (isIPv4(address)) return !blocked.check(address, "ipv4");
  if (!isIPv6(address)) return false;
  const words = ipv6Words(address);
  if (!words) return false;
  const mapped = words.slice(0, 5).every((word) => word === 0) && words[5] === 0xffff;
  const nat64 = words[0] === 0x64 && words[1] === 0xff9b && words.slice(2, 6).every((word) => word === 0);
  // Do not allow transition addresses: their effective route can be an embedded IPv4 endpoint.
  if (mapped || nat64) return false;
  // ISATAP encodes IPv4 in its interface identifier; block the transition form altogether.
  if ((words[4] === 0 || words[4] === 0x0200) && words[5] === 0x5efe) return false;
  if (words[0] < 0x2000 || words[0] > 0x3fff) return false;
  return !blocked.check(address, "ipv6");
}

function ipv6Words(address: string): number[] | null {
  let normalized = address.toLowerCase();
  const dotted = /(\d+\.\d+\.\d+\.\d+)$/.exec(normalized);
  if (dotted) {
    const octets = dotted[1].split(".").map(Number);
    normalized = normalized.slice(0, -dotted[1].length) +
      `${((octets[0] << 8) | octets[1]).toString(16)}:${((octets[2] << 8) | octets[3]).toString(16)}`;
  }
  const halves = normalized.split("::");
  if (halves.length > 2) return null;
  const left = halves[0] ? halves[0].split(":") : [];
  const right = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  const missing = 8 - left.length - right.length;
  if ((halves.length === 1 && missing !== 0) || (halves.length === 2 && missing < 1)) return null;
  const words = [...left, ...Array(missing).fill("0"), ...right].map((word) => parseInt(word, 16));
  return words.length === 8 && words.every(Number.isFinite) ? words : null;
}

/** Accepts only `https:` on the default port, with no user name or password. */
export function parseHttpsUrl(raw: string): URL | null {
  if (raw.length > MAX_URL_LENGTH) return null;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || url.username || url.password || (url.port && url.port !== "443")) return null;
  if (!url.hostname) return null;
  return url;
}

function bareHost(url: URL): string {
  return url.hostname.replace(/^\[|\]$/g, "");
}

async function publicAddress(url: URL, deps: LinkDeps): Promise<Address | null> {
  const host = bareHost(url);
  const addresses = isIPv4(host) || isIPv6(host) ? [{address: host, family: isIPv4(host) ? 4 : 6}] : await deps.resolve(host);
  if (addresses.length === 0 || !addresses.every((it) => isPublicAddress(it.address))) return null;
  return addresses[0];
}

async function readLimited(body: AsyncIterable<Buffer>, limit: number): Promise<{text: string; cut: boolean}> {
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of body) {
    const room = limit - total;
    if (chunk.length >= room) {
      chunks.push(chunk.subarray(0, room));
      return {text: Buffer.concat(chunks).toString("utf8"), cut: true};
    }
    chunks.push(chunk);
    total += chunk.length;
  }
  return {text: Buffer.concat(chunks).toString("utf8"), cut: false};
}

function decodeEntities(value: string): string {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, hex: string) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec: string) => String.fromCodePoint(parseInt(dec, 10)))
    .replace(/&quot;/g, "\"")
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

const IMAGE_KEYS = ["og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src"];

/** The first image named by the page's meta tags, in [IMAGE_KEYS] order. */
export function metaImage(html: string): string | undefined {
  const found = new Map<string, string>();
  const starts = /<meta\b/gi;
  for (let start = starts.exec(html); start; start = starts.exec(html)) {
    const end = html.indexOf(">", starts.lastIndex);
    if (end < 0) break;
    const tag = html.slice(starts.lastIndex, end);
    starts.lastIndex = end + 1;
    const attributes = new Map<string, string>();
    for (const match of tag.matchAll(/(?:^|\s)([a-z:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/gi)) {
      attributes.set(match[1].toLowerCase(), match[2] ?? match[3] ?? match[4] ?? "");
    }
    const key = (attributes.get("property") ?? attributes.get("name") ?? "").toLowerCase();
    const content = attributes.get("content")?.trim();
    if (content && IMAGE_KEYS.includes(key) && !found.has(key)) found.set(key, decodeEntities(content));
  }
  for (const key of IMAGE_KEYS) {
    if (found.has(key)) return found.get(key);
  }
  return undefined;
}

export async function findLinkImage(raw: string, deps: LinkDeps = linkDeps, timeoutMs = LINK_TIMEOUT_MS):
  Promise<LinkImageResult> {
  const first = parseHttpsUrl(raw);
  if (!first) return {status: "none", reason: "invalid_url"};
  let url: URL = first;
  const controller = new AbortController();
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);
  const timeout = new Promise<never>((_, reject) => {
    controller.signal.addEventListener("abort", () => reject(new Error("timeout")), {once: true});
  });
  timeout.catch(() => undefined);
  try {
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      const address = await Promise.race([publicAddress(url, deps), timeout]);
      if (!address) return {status: "none", reason: "blocked"};
      const response: LinkResponse = await Promise.race([deps.get(url, address, controller.signal), timeout]);
      if (response.status >= 300 && response.status < 400) {
        response.close();
        const location: string | undefined = response.headers.location;
        const next: URL | null = typeof location === "string" ? parseHttpsUrl(new URL(location, url).toString()) : null;
        if (!next) return {status: "none", reason: "blocked"};
        url = next;
        continue;
      }
      const type = String(response.headers["content-type"] ?? "").toLowerCase();
      if (response.status !== 200 || !/^(text\/html|application\/xhtml\+xml)/.test(type)) {
        response.close();
        return {status: "none", reason: "no_image"};
      }
      const declared = Number(response.headers["content-length"] ?? 0);
      if (declared > MAX_HTML_BYTES * 8) {
        response.close();
        return {status: "none", reason: "too_large"};
      }
      let page: {text: string; cut: boolean};
      try {
        page = await Promise.race([readLimited(response.body, MAX_HTML_BYTES), timeout]);
      } finally {
        response.close();
      }
      const named = metaImage(page.text);
      const image = named ? parseHttpsUrl(new URL(named, url).toString()) : null;
      if (!image) return {status: "none", reason: page.cut ? "too_large" : "no_image"};
      if (!(await Promise.race([publicAddress(image, deps), timeout]))) return {status: "none", reason: "blocked"};
      return {status: "found", imageUrl: image.toString()};
    }
    return {status: "none", reason: "blocked"};
  } catch (error) {
    if (timedOut) return {status: "none", reason: "timeout"};
    logger.info("shareLinkImage: fetch failed", {error: error instanceof Error ? error.message : String(error)});
    return {status: "none", reason: "error"};
  } finally {
    clearTimeout(timer);
  }
}

export const linkDeps: LinkDeps = {
  resolve: async (host) => lookup(host, {all: true, verbatim: true}),
  get: (url, address, signal) => new Promise<LinkResponse>((resolve, reject) => {
    // Connect only to the address that was checked, so a second DNS answer cannot point the socket elsewhere.
    const pinned: LookupFunction = (_host, options, callback) => {
      if ((options as {all?: boolean}).all) {
        (callback as unknown as (error: null, addresses: Address[]) => void)(null, [address]);
      } else {
        callback(null, address.address, address.family);
      }
    };
    const request = https.get(url, {
      lookup: pinned,
      signal,
      agent: false,
      headers: {"accept": "text/html,application/xhtml+xml", "user-agent": "PrismLinkPreview/1.0", "accept-encoding": "identity"},
    }, (response) => {
      resolve({
        status: response.statusCode ?? 0,
        headers: response.headers,
        body: response,
        close: () => response.destroy(),
      });
    });
    request.on("error", reject);
  }),
};

/** Callable: `{url}` to `{imageUrl}` or `{imageUrl: null, reason}`. Guests may call it, because Set needs no account. */
export const shareLinkImage = onCall(
  {region: CALLABLE_REGIONS, cors: true, maxInstances: 10, timeoutSeconds: 15, memory: "256MiB"},
  async (request) => {
    const url = (request.data as {url?: unknown} | null)?.url;
    if (typeof url !== "string" || url.length === 0 || url.length > MAX_URL_LENGTH) {
      throw new HttpsError("invalid-argument", "url must be an https link");
    }
    const result = await findLinkImage(url);
    return result.status === "found" ? {imageUrl: result.imageUrl} : {imageUrl: null, reason: result.reason};
  },
);
