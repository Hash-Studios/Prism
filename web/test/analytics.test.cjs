const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');

function mount(token, storage = new Map(), search = '?utm_source=launch&utm_campaign=summer&email=private@example.com',
  { pathname = '/', navigator = {} } = {}) {
  const requests = [];
  const listeners = new Map();
  let cleanup;
  class Element {
    constructor(link, marks = []) { this.link = link; this.marks = marks === true ? ['[data-analytics-qr]'] : marks; }
    closest(selector) { return selector === 'a' ? this.link : this.marks.includes(selector) ? this : null; }
  }
  const site = { PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id6670200846' };
  const source = fs.readFileSync(require.resolve('../components/analytics.tsx'), 'utf8');
  const compiled = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX,
  } }).outputText;
  const exports = {};
  vm.runInNewContext(compiled, {
    exports, URLSearchParams, Element, navigator, crypto: require('node:crypto').webcrypto,
    process: { env: { NEXT_PUBLIC_MIXPANEL_TOKEN: token } },
    require(name) {
      if (name === 'react') return { useEffect: (effect) => { cleanup = effect(); } };
      if (name === 'next/navigation') return { usePathname: () => '/' };
      return site;
    },
    window: { location: { pathname, search, origin: 'https://prismwalls.com' } },
    sessionStorage: { getItem: (key) => storage.get(key) || null, setItem: (key, value) => storage.set(key, value) },
    document: {
      addEventListener: (name, handler) => listeners.set(name, handler),
      removeEventListener: (name) => listeners.delete(name),
    },
    fetch: async (url, options) => { requests.push({ url, options, payload: JSON.parse(options.body)[0] }); },
  });
  exports.MarketingAnalytics();
  return { requests, listeners, Element, site, cleanup };
}

test('sends campaign-aware landing, real store clicks and actual QR reveals through Mixpanel HTTP', () => {
  const state = mount('public-test-token');
  state.listeners.get('click')({ target: new state.Element({ href: state.site.APP_STORE_URL }) });
  state.listeners.get('prism:qr-revealed')({ target: new state.Element(null, true) });
  state.listeners.get('prism:qr-revealed')({ target: new state.Element(null, true) });
  assert.deepEqual(state.requests.map((request) => request.payload.event),
    ['web_landing_viewed', 'web_store_clicked', 'web_qr_viewed', 'web_qr_viewed']);
  for (const request of state.requests) {
    assert.equal(request.url, 'https://api-js.mixpanel.com/track?ip=0');
    assert.equal(request.options.method, 'POST');
    assert.equal(request.options.keepalive, true);
    assert.equal(request.payload.properties.utm_source, 'launch');
    assert.equal(request.payload.properties.email, undefined);
    assert.equal(request.payload.properties.token, 'public-test-token');
  }
  assert.equal(state.requests[1].payload.properties.store, 'app_store');
  assert.equal(state.listeners.has('focusin'), false);
  assert.equal(state.listeners.has('mouseover'), false);
  state.cleanup();
  assert.equal(state.listeners.size, 0);
});

test('missing public token disables transport without changing links or listeners', () => {
  const state = mount(undefined);
  assert.equal(state.requests.length, 0);
  assert.equal(state.listeners.size, 0);
});

test('store clicks retain validated landing campaign across internal navigation', () => {
  const storage = new Map();
  mount('public-test-token', storage);
  const nextPage = mount('public-test-token', storage, '');
  nextPage.listeners.get('click')({ target: new nextPage.Element({ href: nextPage.site.PLAY_STORE_URL }) });
  assert.equal(nextPage.requests[1].payload.properties.utm_source, 'launch');
  assert.equal(nextPage.requests[1].payload.properties.utm_campaign, 'summer');
  assert.equal(nextPage.requests[1].payload.properties.email, undefined);
});

function mountWebMcp(fetch) {
  const tools = new Map();
  let effect;
  const source = fs.readFileSync(require.resolve('../components/webmcp.tsx'), 'utf8');
  const compiled = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX,
  } }).outputText;
  const exports = {};
  vm.runInNewContext(compiled, {
    exports,
    fetch,
    document: { modelContext: {
      registerTool: (tool) => tools.set(tool.name, tool),
      unregisterTool: (name) => tools.delete(name),
    } },
    navigator: {},
    require(name) { return name === 'react' ? { useEffect: (callback) => { effect = callback; } } : {}; },
    encodeURIComponent,
  });
  exports.WebMcp();
  effect();
  return tools;
}

test('WebMCP marks HTTP and transport failures as tool errors', async () => {
  let mode = 'http';
  const tools = mountWebMcp(async () => {
    if (mode === 'network') throw new TypeError('offline');
    return new Response('unavailable', { status: 503 });
  });
  const execute = tools.get('get_pricing').execute;

  const httpFailure = await execute({});
  assert.equal(httpFailure.isError, true);
  assert.equal(httpFailure.content[0].text, 'unavailable');

  mode = 'network';
  const networkFailure = await execute({});
  assert.equal(networkFailure.isError, true);
  assert.match(networkFailure.content[0].text, /offline/);
});

const APK_URL = 'https://github.com/Hash-Studios/Prism/releases/download/v3.24.0%2B366/prism-3.24.0-366.apk';

test('download intent and APK clicks keep the entry page and send only the APK version', () => {
  const storage = new Map();
  const landing = mount('public-test-token', storage, '?utm_source=reddit&ref=someone@example.com',
    { pathname: '/open-source-android-wallpaper-app' });
  landing.listeners.get('click')({ target: new landing.Element({ href: 'https://prismwalls.com/download' }) });
  assert.deepEqual(landing.requests.map((request) => request.payload.event), ['web_landing_viewed', 'web_download_clicked']);
  for (const request of landing.requests) {
    assert.equal(request.payload.properties.path, '/open-source-android-wallpaper-app');
    assert.equal(request.payload.properties.entry_path, '/open-source-android-wallpaper-app');
  }

  const download = mount('public-test-token', storage, '', { pathname: '/download' });
  download.listeners.get('click')({ target: new download.Element({ href: APK_URL }, ['[data-analytics-apk]']) });
  download.listeners.get('click')({ target: new download.Element(
    { href: 'https://github.com/Hash-Studios/Prism/releases/latest' }, ['[data-analytics-apk]']) });
  download.listeners.get('click')({ target: new download.Element({ href: 'https://github.com/Hash-Studios/Prism' }) });
  assert.deepEqual(download.requests.map((request) => request.payload.event),
    ['web_landing_viewed', 'web_apk_clicked', 'web_apk_clicked']);
  const [, apk, fallback] = download.requests.map((request) => request.payload.properties);
  assert.equal(apk.path, '/download');
  assert.equal(apk.entry_path, '/open-source-android-wallpaper-app');
  assert.equal(apk.utm_source, 'reddit');
  assert.equal(apk.target, 'apk_file');
  assert.equal(apk.apk_version, '3.24.0');
  assert.equal(fallback.target, 'releases_page');
  assert.equal(fallback.apk_version, undefined);
  for (const request of [...landing.requests, ...download.requests]) {
    assert.doesNotMatch(request.options.body, /github\.com|\.apk|someone|example\.com|ref/);
  }
});

test('only known page paths are sent, and a tampered entry page is replaced', () => {
  const sent = (pathname, storage = new Map()) =>
    mount('public-test-token', storage, '', { pathname }).requests[0].payload.properties;
  assert.equal(sent('/amoled-wallpapers/').path, '/amoled-wallpapers');
  assert.equal(sent('/changelog/v3-24-0').path, '/changelog/v3-24-0');
  for (const pathname of ['/jane.doe@example.com', '/wallpaper/OUUKGMD2GF', '/changelog/jane-doe', '/changelog/v3']) {
    const properties = sent(pathname);
    assert.equal(properties.path, 'other');
    assert.equal(properties.entry_path, 'other');
  }
  const storage = new Map([['prism_marketing_entry', '/jane.doe@example.com']]);
  assert.equal(sent('/download', storage).entry_path, '/download');
  assert.equal(storage.get('prism_marketing_entry'), '/download');
  const unknownEntry = new Map();
  sent('/unlisted', unknownEntry);
  assert.equal(sent('/download', unknownEntry).entry_path, 'other');
});

test('Do Not Track and Global Privacy Control send nothing and add no listeners', () => {
  for (const navigator of [{ doNotTrack: '1' }, { globalPrivacyControl: true }]) {
    const state = mount('public-test-token', new Map(), '', { navigator });
    assert.equal(state.requests.length, 0);
    assert.equal(state.listeners.size, 0);
  }
  assert.equal(mount('public-test-token', new Map(), '', { navigator: { doNotTrack: '0' } }).requests.length, 1);
});
