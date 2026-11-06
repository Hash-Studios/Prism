import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../edge-worker.mjs';

function request(path, headers = {}) {
  return new Request(`https://prismwalls.com${path}`, { headers });
}

function assets(responses) {
  const calls = [];
  return {
    calls,
    binding: {
      fetch(input) {
        const assetRequest = input instanceof Request ? input : new Request(input);
        const url = new URL(assetRequest.url);
        calls.push(url.pathname);
        const response = responses[url.pathname];
        return Promise.resolve(response
          ? response.clone()
          : new Response('missing', { status: 404 }));
      },
    },
  };
}

test('Accept markdown negotiates the homepage markdown asset', async () => {
  const { binding } = assets({ '/index.md': new Response('# Prism', { headers: { 'Content-Type': 'text/plain' } }) });
  const response = await worker.fetch(request('/', { Accept: 'text/markdown' }), { ASSETS: binding });

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'text/markdown; charset=utf-8');
  assert.equal(response.headers.get('Vary'), 'Accept, User-Agent');
  assert.equal(await response.text(), '# Prism');
});

test('recognized bot user agent receives homepage markdown', async () => {
  const { binding } = assets({ '/index.md': new Response('agent markdown') });
  const response = await worker.fetch(request('/', { 'User-Agent': 'Mozilla GPTBot/1.0' }), { ASSETS: binding });

  assert.equal(await response.text(), 'agent markdown');
  assert.match(response.headers.get('Content-Type'), /^text\/markdown/);
});

test('browser homepage response preserves and appends Link header', async () => {
  const { binding } = assets({ '/': new Response('<html></html>', {
    headers: { 'Content-Type': 'text/html; charset=utf-8', Link: '</existing>; rel="preload"' },
  }) });
  const response = await worker.fetch(request('/', { 'User-Agent': 'Browser' }), { ASSETS: binding });
  const link = response.headers.get('Link');

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Vary'), 'Accept, User-Agent');
  assert.match(link, /<\/existing>; rel="preload"/);
  assert.match(link, /<\/sitemap\.xml>; rel="sitemap"/);
  assert.match(link, /<\/index\.md>; rel="alternate"; type="text\/markdown"/);
  assert.match(link, /<\/openapi\.json>; rel="service-desc"/);
  assert.match(link, /<\/\.well-known\/api-catalog>; rel="api-catalog"/);
});

test('agent mode returns the advertised JSON and is not cached', async () => {
  const { binding } = assets({});
  const response = await worker.fetch(request('/?mode=agent'), { ASSETS: binding });
  const body = await response.json();

  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(response.headers.get('Content-Type'), 'application/json');
  assert.equal(body.name, 'Prism Wallpapers');
  assert.equal(body.api.baseUrl, 'https://prismwalls.com/api/v1');
  assert.equal(body.mcp.server, 'https://prismwalls.com/mcp');
  assert.equal(body.mcp.docs, 'https://prismwalls.com/mcp/docs');
  assert.equal(body.mcp.serverCard, 'https://prismwalls.com/.well-known/mcp/server-card.json');
  assert.ok(Array.isArray(body.capabilities));
});

test('markdown request with missing asset returns linked markdown 404', async () => {
  const { binding } = assets({});
  const response = await worker.fetch(request('/', { Accept: 'text/markdown' }), { ASSETS: binding });
  const body = await response.text();

  assert.equal(response.status, 404);
  assert.match(response.headers.get('Content-Type'), /^text\/markdown/);
  assert.ok(body.startsWith('# Not found'));
  assert.ok(body.length >= 20);
  assert.match(body, /\/llms\.txt/);
  assert.match(body, /\/sitemap\.xml/);
});

test('non-home path passes through the original request and response', async () => {
  const { binding, calls } = assets({ '/about': new Response('about page', { status: 203 }) });
  const originalRequest = request('/about');
  const response = await worker.fetch(originalRequest, { ASSETS: binding });

  assert.deepEqual(calls, ['/about']);
  assert.equal(response.status, 203);
  assert.equal(await response.text(), 'about page');
  assert.equal(response.headers.get('Vary'), null);
});

test('bot negotiation varies both markdown and HTML by User-Agent', async () => {
  const { binding } = assets({
    '/index.md': new Response('# Prism', { headers: { Vary: 'Accept-Encoding' } }),
    '/': new Response('<html></html>', { headers: { 'Content-Type': 'text/html' } }),
  });
  for (const userAgent of ['GPTBot', 'Browser']) {
    const response = await worker.fetch(request('/', { 'User-Agent': userAgent }), { ASSETS: binding });
    assert.match(response.headers.get('Vary'), /User-Agent/i);
    assert.match(response.headers.get('Vary'), /Accept/i);
  }
});

test('HEAD markdown 404 has no body', async () => {
  const { binding } = assets({});
  for (const path of ['/', '/missing']) {
    const response = await worker.fetch(new Request(`https://prismwalls.com${path}`, {
      method: 'HEAD', headers: { Accept: 'text/markdown' },
    }), { ASSETS: binding });
    assert.equal(response.status, 404);
    assert.equal(await response.text(), '');
  }
});

test('explicitly unacceptable markdown is not negotiated', async () => {
  const { binding, calls } = assets({
    '/': new Response('HTML', { headers: { 'Content-Type': 'text/html' } }),
    '/index.md': new Response('markdown'),
  });
  const response = await worker.fetch(request('/', { Accept: 'text/html, text/markdown;q=0' }), { ASSETS: binding });
  assert.equal(await response.text(), 'HTML');
  assert.deepEqual(calls, ['/']);
});

test('the worker sitemap child includes the new static pages', async () => {
  const { readFile } = await import('node:fs/promises');
  const source = await readFile(new URL('../app/sitemap-pages.xml/route.ts', import.meta.url), 'utf8');
  for (const page of ['/about', '/contact', '/docs', '/developers', '/mcp', '/privacy', '/terms']) {
    assert.ok(source.includes(JSON.stringify(page)), `sitemap-pages.xml omits ${page}`);
  }
});

test('developer examples can be copied as commands and JSON', async () => {
  const { readFile } = await import('node:fs/promises');
  for (const page of ['docs', 'mcp']) {
    const source = await readFile(new URL(`../app/${page}/page.tsx`, import.meta.url), 'utf8');
    const template = source.match(/<code>\{(`[^`]*`)\}<\/code>/)[1];
    const rendered = Function(`return ${template}`)();
    if (page === 'mcp') {
      assert.equal(JSON.parse(rendered).mcpServers['prism-wallpapers'].url, 'https://prismwalls.com/mcp');
    } else {
      assert.equal(rendered.split('\n').length, 4);
    }
  }
});

test('auth documentation does not promise unsupported identity endpoints', async () => {
  const { readFile } = await import('node:fs/promises');
  const source = await readFile(new URL('../public/auth.md', import.meta.url), 'utf8');
  assert.match(source, /not supported/i);
  assert.match(source, /## Register/);
  assert.match(source, /## Claim/);
  assert.match(source, /## Exchange/);
});

test('organization schema does not invent a physical address', async () => {
  const { readFile } = await import('node:fs/promises');
  const source = await readFile(new URL('../lib/seo.ts', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /address:\s*\{/);
});

test('published plugin skills resolve to the maintained skill text', async () => {
  const { readFile } = await import('node:fs/promises');
  const plugin = JSON.parse(await readFile(new URL('../public/plugin.json', import.meta.url), 'utf8'));
  for (const skill of plugin.skills) {
    const published = await readFile(new URL(`../public/${skill}/SKILL.md`, import.meta.url), 'utf8');
    const source = await readFile(new URL(`../../${skill}/SKILL.md`, import.meta.url), 'utf8');
    assert.equal(published, source);
  }
});

test('WebMCP releases its tool names before a remount', async () => {
  const { readFile } = await import('node:fs/promises');
  const { createRequire } = await import('node:module');
  const ts = createRequire(import.meta.url)('typescript');
  const source = await readFile(new URL('../components/webmcp.tsx', import.meta.url), 'utf8');
  const javascript = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext } }).outputText
    .replace(/import \{ useEffect \} from "react";/, '')
    .replace('export function WebMcp', 'function WebMcp');
  const tools = new Map();
  const context = {
    registerTool(tool) {
      assert.equal(tools.has(tool.name), false, `duplicate tool ${tool.name}`);
      tools.set(tool.name, tool);
    },
    unregisterTool(name) { tools.delete(name); },
  };
  let effect;
  const Component = Function('useEffect', 'document', 'navigator', `${javascript}; return WebMcp;`)(
    (callback) => { effect = callback; }, {}, { modelContext: context },
  );
  Component();
  const cleanup = effect();
  assert.equal(tools.size, 3);
  assert.equal(typeof cleanup, 'function');
  cleanup();
  assert.equal(tools.size, 0);
  const secondCleanup = effect();
  assert.equal(tools.size, 3);
  secondCleanup();
});

test('homepage markdown alternate is not inherited by unrelated pages', async () => {
  const { readFile } = await import('node:fs/promises');
  const layout = await readFile(new URL('../app/layout.tsx', import.meta.url), 'utf8');
  assert.doesNotMatch(layout, /"text\/markdown"/);
  const homepage = await readFile(new URL('../app/page.tsx', import.meta.url), 'utf8');
  const metadata = homepage.match(/export const metadata: Metadata = (\{[\s\S]*?\n\});/);
  assert.ok(metadata, 'homepage must own its metadata');
  assert.deepEqual(Function(`return (${metadata[1]})`)().alternates, {
    canonical: '/', types: { 'text/markdown': '/index.md' },
  });
});

test('documentation index describes unsupported agent authentication', async () => {
  const { readFile } = await import('node:fs/promises');
  const index = await readFile(new URL('../public/docs/llms.txt', import.meta.url), 'utf8');
  assert.match(index, /agent authentication is not supported/i);
  assert.doesNotMatch(index, /protected integration identity concepts/);
});
