import assert from "node:assert/strict";
import type {IncomingHttpHeaders} from "node:http";
import {isIPv6} from "node:net";
import test from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {
  findLinkImage,
  isPublicAddress,
  LinkDeps,
  LinkResponse,
  MAX_HTML_BYTES,
  MAX_REDIRECTS,
  parseHttpsUrl,
  shareLinkImage,
} from "../shareLinkImage";

type Call = {url: string; address: string};
type Probe = {closed: boolean; pulled: number};
type Probed = LinkResponse & Probe;

const PAGE = "https://example.com/p";
const PUBLIC_DNS = {"example.com": ["93.184.216.34"], "cdn.example.com": ["151.101.1.1"]};
const PRIVATE_ADDRESSES = [
  "127.0.0.1", "10.0.0.5", "172.16.3.4", "192.168.1.1", "169.254.169.254", "100.64.0.1", "0.0.0.0",
  "::1", "fc00::1", "fe80::1", "::ffff:127.0.0.1", "::ffff:7f00:1", "64:ff9b::a00:1",
];

const og = (content: string) => `<meta property="og:image" content="${content}">`;

function probed(status: number, headers: IncomingHttpHeaders, chunks: Buffer[]): Probed {
  const probe: Probe = {closed: false, pulled: 0};
  const body = (async function* () {
    for (const chunk of chunks) {
      probe.pulled += 1;
      yield chunk;
    }
  })();
  return Object.assign(probe, {
    status,
    headers,
    body,
    close: () => {
      probe.closed = true;
    },
  });
}

function html(body: string | Buffer[], headers: IncomingHttpHeaders = {}): Probed {
  const chunks = typeof body === "string" ? [Buffer.from(body)] : body;
  return probed(200, {"content-type": "text/html; charset=utf-8", ...headers}, chunks);
}

function redirect(location: string, status = 302): Probed {
  return probed(status, {location}, []);
}

function slices(buf: Buffer, size: number): Buffer[] {
  const out: Buffer[] = [];
  for (let i = 0; i < buf.length; i += size) out.push(buf.subarray(i, i + size));
  return out;
}

function fakeDeps(
  dns: Record<string, string[]>,
  pages: Record<string, () => LinkResponse | Promise<LinkResponse>> = {},
): {deps: LinkDeps; calls: Call[]} {
  const calls: Call[] = [];
  const hosts = new Map(Object.entries(dns));
  const replies = new Map(Object.entries(pages));
  const deps: LinkDeps = {
    resolve: async (host) => (hosts.get(host) ?? []).map((address) => ({address, family: isIPv6(address) ? 6 : 4})),
    get: async (url, address) => {
      calls.push({url: url.toString(), address: address.address});
      const reply = replies.get(url.toString());
      if (!reply) throw new Error(`no page for ${url.toString()}`);
      return reply();
    },
  };
  return {deps, calls};
}

test("returns the og:image of a public page and never fetches the image", async () => {
  const page = html("<meta property=\"og:image\" content=\"https://cdn.example.com/a.jpg\">");
  const {deps, calls} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/a.jpg"});
  assert.deepEqual(calls, [{url: PAGE, address: "93.184.216.34"}]);
});

test("resolves a relative og:image against the page", async () => {
  const page = html(og("/img/a.jpg"));
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://example.com/img/a.jpg"});
});

test("accepts content before property in the meta tag", async () => {
  const page = html("<meta content=\"https://cdn.example.com/a.jpg\" property=\"og:image\">");
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/a.jpg"});
});

test("accepts single quotes in the meta tag", async () => {
  const page = html("<meta property='og:image' content='https://cdn.example.com/a.jpg'>");
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/a.jpg"});
});

test("decodes &amp; in the og:image URL", async () => {
  const page = html(og("https://cdn.example.com/a.jpg?w=1&amp;h=2"));
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/a.jpg?w=1&h=2"});
});

test("prefers og:image:secure_url over og:image", async () => {
  const page = html(
    og("https://cdn.example.com/a.jpg") + "<meta property=\"og:image:secure_url\" content=\"https://cdn.example.com/s.jpg\">",
  );
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/s.jpg"});
});

test("uses twitter:image when the page has no og image", async () => {
  const page = html("<meta name=\"twitter:image\" content=\"https://cdn.example.com/t.jpg\">");
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/t.jpg"});
});

test("returns no_image when the HTML has no image meta tag", async () => {
  const page = html("<title>No image</title>");
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "no_image"});
});

test("returns no_image and closes the response for a non-HTML content type", async () => {
  const page = probed(200, {"content-type": "image/png"}, [Buffer.from(og("https://cdn.example.com/a.jpg"))]);
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "no_image"});
  assert.equal(page.closed, true);
});

test("rejects URLs that are not plain https links", async () => {
  const urls = [
    "file:///etc/passwd",
    "http://example.com/",
    "https://user:pw@example.com/",
    "https://example.com:8443/",
    "javascript:alert(1)",
  ];
  for (const raw of urls) {
    const {deps, calls} = fakeDeps(PUBLIC_DNS);
    assert.deepEqual(await findLinkImage(raw, deps), {status: "none", reason: "invalid_url"}, raw);
    assert.equal(calls.length, 0, raw);
  }
});

for (const address of PRIVATE_ADDRESSES) {
  test(`blocks a host that resolves to ${address}`, async () => {
    const {deps, calls} = fakeDeps({"internal.example": [address]});
    assert.deepEqual(await findLinkImage("https://internal.example/", deps), {status: "none", reason: "blocked"});
    assert.equal(calls.length, 0);
  });
}

test("blocks IP-literal URLs to loopback", async () => {
  for (const raw of ["https://127.0.0.1/", "https://[::1]/"]) {
    const {deps, calls} = fakeDeps({});
    assert.deepEqual(await findLinkImage(raw, deps), {status: "none", reason: "blocked"}, raw);
    assert.equal(calls.length, 0, raw);
  }
});

test("blocks when one DNS answer is private", async () => {
  const {deps, calls} = fakeDeps({"mixed.example": ["93.184.216.34", "10.0.0.1"]});
  assert.deepEqual(await findLinkImage("https://mixed.example/", deps), {status: "none", reason: "blocked"});
  assert.equal(calls.length, 0);
});

test("blocks a redirect to a host that resolves to a private address", async () => {
  const first = redirect("https://internal.example/");
  const {deps, calls} = fakeDeps(
    {...PUBLIC_DNS, "internal.example": ["10.1.2.3"]},
    {[PAGE]: () => first},
  );
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "blocked"});
  assert.equal(first.closed, true);
  assert.equal(calls.length, 1);
});

test("blocks a redirect to http://", async () => {
  const first = redirect("http://example.com/other");
  const {deps, calls} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => first});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "blocked"});
  assert.equal(calls.length, 1);
});

test("blocks a redirect to file:///", async () => {
  const first = redirect("file:///etc/passwd");
  const {deps, calls} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => first});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "blocked"});
  assert.equal(calls.length, 1);
});

test("follows a redirect chain within the limit", async () => {
  const {deps, calls} = fakeDeps(
    {...PUBLIC_DNS, "a.example": ["93.184.216.35"], "b.example": ["93.184.216.36"]},
    {
      "https://a.example/": () => redirect("https://b.example/", 301),
      "https://b.example/": () => html(og("https://cdn.example.com/a.jpg")),
    },
  );
  assert.deepEqual(await findLinkImage("https://a.example/", deps), {
    status: "found",
    imageUrl: "https://cdn.example.com/a.jpg",
  });
  assert.deepEqual(calls.map((call) => call.url), ["https://a.example/", "https://b.example/"]);
});

test("blocks a redirect loop after MAX_REDIRECTS + 1 requests", async () => {
  const {deps, calls} = fakeDeps(
    {"loop.example": ["93.184.216.37"]},
    {"https://loop.example/": () => redirect("https://loop.example/")},
  );
  assert.deepEqual(await findLinkImage("https://loop.example/", deps), {status: "none", reason: "blocked"});
  assert.equal(calls.length, MAX_REDIRECTS + 1);
});

test("blocks an og:image on a private IP literal", async () => {
  const page = html(og("https://10.0.0.1/a.jpg"));
  const {deps, calls} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "blocked"});
  assert.equal(calls.length, 1);
});

test("returns no_image for an og:image that is not https", async () => {
  const page = html(og("http://cdn.example.com/a.jpg"));
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "no_image"});
});

test("times out when the page request never answers", async () => {
  const {deps: dns} = fakeDeps(PUBLIC_DNS);
  const hung: LinkDeps = {
    resolve: dns.resolve,
    get: () => new Promise<LinkResponse>(() => undefined),
  };
  const started = Date.now();
  assert.deepEqual(await findLinkImage(PAGE, hung, 50), {status: "none", reason: "timeout"});
  assert.ok(Date.now() - started < 1000);
});

test("times out when DNS never answers", async () => {
  const hung: LinkDeps = {
    resolve: () => new Promise<never>(() => undefined),
    get: () => new Promise<LinkResponse>(() => undefined),
  };
  const started = Date.now();
  assert.deepEqual(await findLinkImage(PAGE, hung, 50), {status: "none", reason: "timeout"});
  assert.ok(Date.now() - started < 1000);
});

test("stops reading an oversize page when the og tag is after the limit", async () => {
  const tag = og("https://cdn.example.com/a.jpg");
  const text = "x".repeat(MAX_HTML_BYTES) + tag + "x".repeat(100 * 1024);
  const chunks = slices(Buffer.from(text), 16 * 1024);
  const page = html(chunks);
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "too_large"});
  assert.ok(page.pulled < chunks.length, `pulled ${page.pulled} of ${chunks.length} chunks`);
  assert.equal(page.closed, true);
});

test("finds an og tag that sits inside the size limit of an oversize page", async () => {
  const tag = og("https://cdn.example.com/a.jpg");
  const text = tag + "x".repeat(MAX_HTML_BYTES) + "x".repeat(100 * 1024);
  const page = html(slices(Buffer.from(text), 16 * 1024));
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "found", imageUrl: "https://cdn.example.com/a.jpg"});
});

test("returns too_large from content-length without reading the body", async () => {
  const page = html("", {"content-length": String(MAX_HTML_BYTES * 8 + 1)});
  const {deps} = fakeDeps(PUBLIC_DNS, {[PAGE]: () => page});
  assert.deepEqual(await findLinkImage(PAGE, deps), {status: "none", reason: "too_large"});
  assert.equal(page.pulled, 0);
  assert.equal(page.closed, true);
});

test("isPublicAddress accepts public addresses", () => {
  assert.equal(isPublicAddress("8.8.8.8"), true);
  assert.equal(isPublicAddress("2606:4700::1111"), true);
});

test("isPublicAddress rejects private, reserved and malformed addresses", () => {
  for (const address of [...PRIVATE_ADDRESSES, "not-an-ip", "2001:db8::1"]) {
    assert.equal(isPublicAddress(address), false, address);
  }
});

test("parseHttpsUrl rejects a URL longer than 2048 characters", () => {
  const raw = `https://example.com/${"a".repeat(2049 - "https://example.com/".length)}`;
  assert.equal(raw.length, 2049);
  assert.equal(parseHttpsUrl(raw), null);
});

test("callable rejects a non-string url with invalid-argument", async () => {
  await assert.rejects(
    shareLinkImage.run({data: {url: 5}} as unknown as Parameters<typeof shareLinkImage.run>[0]),
    (error: unknown) => error instanceof HttpsError && error.code === "invalid-argument",
  );
});

test("callable rejects a missing url with invalid-argument", async () => {
  await assert.rejects(
    shareLinkImage.run({data: {}} as unknown as Parameters<typeof shareLinkImage.run>[0]),
    (error: unknown) => error instanceof HttpsError && error.code === "invalid-argument",
  );
});
