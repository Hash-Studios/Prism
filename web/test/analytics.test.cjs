const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');

function mount(token, storage = new Map(), search = '?utm_source=launch&utm_campaign=summer&email=private@example.com') {
  const requests = [];
  const listeners = new Map();
  let cleanup;
  class Element {
    constructor(link, qr = false) { this.link = link; this.qr = qr; }
    closest(selector) { return selector === 'a' ? this.link : this.qr ? this : null; }
  }
  const site = { PLAY_STORE_URL: 'https://play.google.com/store/apps/details?id=com.hash.prism',
    APP_STORE_URL: 'https://apps.apple.com/app/id1405860595' };
  const source = fs.readFileSync(require.resolve('../components/analytics.tsx'), 'utf8');
  const compiled = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX,
  } }).outputText;
  const exports = {};
  vm.runInNewContext(compiled, {
    exports, URLSearchParams, Element, crypto: require('node:crypto').webcrypto,
    process: { env: { NEXT_PUBLIC_MIXPANEL_TOKEN: token } },
    require(name) {
      if (name === 'react') return { useEffect: (effect) => { cleanup = effect(); } };
      if (name === 'next/navigation') return { usePathname: () => '/' };
      return site;
    },
    window: { location: { pathname: '/', search } },
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

test('sends campaign-aware landing, real store clicks and hover QR through Mixpanel HTTP', () => {
  const state = mount('public-test-token');
  state.listeners.get('click')({ target: new state.Element({ href: state.site.APP_STORE_URL }) });
  state.listeners.get('mouseover')({ target: new state.Element(null, true) });
  state.listeners.get('mouseover')({ target: new state.Element(null, true) });
  assert.deepEqual(state.requests.map((request) => request.payload.event),
    ['web_landing_viewed', 'web_store_clicked', 'web_qr_viewed']);
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
