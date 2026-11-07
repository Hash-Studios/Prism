'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const {createRequire} = require('node:module');
const backend = path.join(__dirname, 'backend.cjs');
const photoQa = path.join(__dirname, '../photo_wallpaper_qa.cjs');
function probe(source, env = {}) {
  return spawnSync(process.execPath, ['-e', source], {
    encoding: 'utf8', env: {PATH: process.env.PATH, ...env},
  });
}
test('a production project is rejected before loading Firebase', () => {
  const result = probe(`require(${JSON.stringify(backend)}).guardEnvironment()`, {GCLOUD_PROJECT: 'prism-wallpapers'});
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Refusing GCLOUD_PROJECT/);
});
test('a remote emulator or real credentials are rejected', () => {
  for (const env of [{FIRESTORE_EMULATOR_HOST: 'example.com:19372'}, {GOOGLE_APPLICATION_CREDENTIALS: '/do/not/read'}, {FIREBASE_TOKEN: 'do-not-use'}, {FIREBASE_CONFIG: '{"projectId":"prism-wallpapers"}'}]) {
    const result = probe(`require(${JSON.stringify(backend)}).guardEnvironment()`, env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Refusing nonlocal|Unset GOOGLE_APPLICATION_CREDENTIALS|Unset FIREBASE_TOKEN|Refusing non-demo/);
  }
});
test('external destinations and undeclared ports fail before TCP connect', () => {
  const result = probe(`
    require(${JSON.stringify(backend)}).guardEnvironment();
    const net = require('node:net');
    const assert = require('node:assert/strict');
    for (const options of [{host:'example.com',port:443}, {host:'8.8.8.8',port:19372}, {host:'localhost',port:8080}, {path:'/tmp/peer.sock'}]) {
      assert.throws(() => new net.Socket().connect(options), /Local QA denied TCP/);
    }
  `);
  assert.equal(result.status, 0, result.stderr);
});
test('CLI child networking rejects external addresses while allowing declared local transport', () => {
  const guard = path.join(__dirname, 'cli_network_guard.cjs');
  const result = probe(`
    require(${JSON.stringify(guard)});
    const net = require('node:net');
    const assert = require('node:assert/strict');
    assert.throws(() => new net.Socket().connect('/tmp/peer.sock'), /denied nonlocal TCP/);
    for (const host of ['example.com', '169.254.169.254', '8.8.8.8']) {
      assert.throws(() => new net.Socket().connect({host, port:443}), /denied nonlocal TCP/);
    }
  `);
  assert.equal(result.status, 0, result.stderr);
});
test('helper rejects an explicit production project before preflight or filesystem writes', () => {
  const result = spawnSync(process.execPath, [path.join(__dirname, '../weekly_challenge_qa.cjs'), 'prepare', '--project', 'prism-wallpapers'], {encoding: 'utf8'});
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /refusing other projects/);
});
const syntheticGooglePlist = '<plist><dict><key>API_KEY</key><string>AIzaSy000000000000000000000000000000000</string>' +
  '<key>GCM_SENDER_ID</key><string>1234567890</string><key>GOOGLE_APP_ID</key><string>1:1234567890:ios:0123456789abcdef</string>' +
  '<key>PROJECT_ID</key><string>demo-prism</string><key>BUNDLE_ID</key><string>com.hash.prism</string>' +
  '<key>IS_ANALYTICS_ENABLED</key><false/><key>IS_GCM_ENABLED</key><false/><key>PLIST_VERSION</key><string>1</string></dict></plist>';
const syntheticInfoPlist = '<plist><dict><key>FirebaseAnalyticsCollectionEnabled</key><false/>' +
  '<key>FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED</key><true/><key>FirebaseMessagingAutoInitEnabled</key><false/>' +
  '<key>FirebaseAppDelegateProxyEnabled</key><false/><key>NSAppTransportSecurity</key>' +
  '<dict><key>NSAllowsLocalNetworking</key><true/></dict></dict></plist>';

function photoFixture(t, options = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'photo-qa-test-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const runtime = path.join(root, 'runtime');
  const put = (name, data, base = runtime) => {
    const target = path.join(base, name);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.writeFileSync(target, data);
  };
  put('manifest.json', JSON.stringify({project: 'demo-prism', runtime}));
  const defines = {PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: 'viewer', PRISM_LOCAL_QA_CERTIFICATE: 'AQID'};
  put('dart-defines.json', JSON.stringify(defines));
  put('cert.der', Buffer.from([1, 2, 3]));
  put('cert.pem', 'fixture certificate');
  put('native/GoogleService-Info.plist', syntheticGooglePlist);
  put('native/Info-LocalQA.plist', syntheticInfoPlist);
  put('ios/Runner/GoogleService-Info.plist', 'original Google config', root);
  put('ios/Runner/Info.plist', 'original Info config', root);
  put('functions/lib/photoWallpaper.js', '', root);
  const state = {builds: 0, loads: 0, authWrites: 0};
  const admin = {apps: options.apps ?? [], auth: () => ({createUser: async () => { state.authWrites++; }})};
  const backendStub = {PROJECT: 'demo-prism', load: () => {
    state.loads++;
    return {admin, db: {doc: () => ({set: async () => undefined})}};
  }};
  const actualRequire = createRequire(photoQa);
  const localRequire = (name) => {
    if (name === './weekly_challenge_qa/backend.cjs' || name === '../backend.cjs') return backendStub;
    if (name === 'firebase-admin' || name.endsWith('/firebase-admin')) return admin;
    if (name === 'node:fs') return options.fs ?? fs;
    if (name === 'node:child_process') return {spawnSync: (binary, args, spawnOptions) => {
      if (binary === 'fvm') {
        state.builds++;
        return options.build?.(root) ?? {status: 0};
      }
      if (binary === 'node') {
        fs.mkdirSync(path.join(runtime, 'functions'), {recursive: true});
        return {status: 0};
      }
      return spawnSync(binary, args, spawnOptions);
    }};
    return actualRequire(name);
  };
  const module = {exports: {}};
  if (options.runMain) localRequire.main = module;
  const context = {require: localRequire, module, __dirname: path.join(root, 'tool'), Buffer, Response, AbortSignal,
    process: {argv: ['node', photoQa, ...(options.args ?? ['ledger'])], env: options.env ?? {}},
    fetch: options.fetch ?? (() => { throw Error('Unexpected network call'); }), console: {log() {}, error() {}}};
  const source = fs.readFileSync(photoQa, 'utf8')
    .replace("const runtime = '/tmp/prism-weekly-qa-photo-wall';", `const runtime = ${JSON.stringify(runtime)};`);
  vm.runInNewContext(source + '\nglobalThis.api = {seed, buildIos, prepare, installPhotoSeams, relayDelete};', context);
  return {...context.api, root, runtime, put, defines, state, require: localRequire};
}

test('photo CLI rejects project overrides instead of silently ignoring them', (t) => {
  assert.throws(() => photoFixture(t, {runMain: true, args: ['ledger', '--project', 'prism-wallpapers']}),
    /ledger does not accept arguments/);
});
test('photo CLI rejects inherited object properties as commands', (t) => {
  assert.throws(() => photoFixture(t, {runMain: true, args: ['toString']}), /Commands:/);
});
test('photo seed rejects an existing non-demo Admin app before loading or writing', async (t) => {
  const qa = photoFixture(t, {apps: [{options: {projectId: 'prism-wallpapers'}}]});
  await assert.rejects(qa.seed(), /pre-existing non-demo/);
  assert.equal(qa.state.loads, 0);
  assert.equal(qa.state.authWrites, 0);
});
test('serialized photo wrapper validates Admin apps and has no missing outer-scope references', async (t) => {
  for (const projectId of ['demo-prism', 'prism-wallpapers']) {
    const qa = photoFixture(t, {apps: [{options: {projectId}}]});
    await qa.prepare();
    const wrapper = fs.readFileSync(path.join(qa.runtime, 'functions/index.cjs'), 'utf8');
    const wrapperRequire = (name) => name === './lib/photoWallpaper.js' ? {photoDeps: {}, createPhotoWallpaper: 'callable'} : qa.require(name);
    const context = {require: wrapperRequire, __dirname: path.join(qa.runtime, 'functions'),
      process: {env: {FUNCTIONS_EMULATOR: 'true'}}, exports: {}};
    if (projectId !== 'demo-prism') {
      assert.throws(() => vm.runInNewContext(wrapper, context), /pre-existing non-demo/);
      assert.equal(qa.state.loads, 0);
    } else {
      vm.runInNewContext(wrapper, context);
      assert.equal(context.exports.createPhotoWallpaper, 'callable');
    }
  }
});
test('photo storage uses the preallocated result key that deletion will remove', async (t) => {
  const qa = photoFixture(t);
  const photo = {photoDeps: {}};
  qa.installPhotoSeams(photo, qa.runtime);
  const key = `photo-walls/${'a'.repeat(32)}.jpg`;
  const stored = await photo.photoDeps.store(Buffer.from('result'), key);
  assert.equal(stored.key, key);
  assert.equal(stored.url, `https://localhost:19375/${key}`);
  assert.equal(fs.readFileSync(path.join(qa.runtime, key), 'utf8'), 'result');
  await photo.photoDeps.remove(key);
  assert.equal(fs.existsSync(path.join(qa.runtime, key)), false);
});
test('photo result removal refuses paths outside its result namespace', async (t) => {
  const qa = photoFixture(t);
  qa.put('victim.jpg', 'unrelated fixture', qa.root);
  const photo = {photoDeps: {}};
  qa.installPhotoSeams(photo, qa.runtime);
  await assert.rejects(photo.photoDeps.remove('../victim.jpg'), /Unexpected local photo result key/);
  assert.equal(fs.readFileSync(path.join(qa.root, 'victim.jpg'), 'utf8'), 'unrelated fixture');
});
test('iOS build rejects invalid manifests, defines, certificates and semantic native configs before building', async (t) => {
  const cases = [
    ['manifest.json', JSON.stringify({project: 'prism-wallpapers', runtime: '/elsewhere'})],
    ['dart-defines.json', JSON.stringify({PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: 'viewer', PRISM_LOCAL_QA_CERTIFICATE: 'AQID', PROJECT_ID: 'prism-wallpapers'})],
    ['dart-defines.json', JSON.stringify({PRISM_LOCAL_QA: 'true', PRISM_LOCAL_QA_USER: 'viewer', PRISM_LOCAL_QA_CERTIFICATE: 'wrong'})],
    ['native/GoogleService-Info.plist', syntheticGooglePlist.replace('<string>demo-prism</string>', '<string>prism-wallpapers</string>')],
    ['native/GoogleService-Info.plist', syntheticGooglePlist.replace('<key>PROJECT_ID</key>', '<key>PROJECT_ID</key><string>prism-wallpapers</string><key>PROJECT_ID</key>')],
    ['native/Info-LocalQA.plist', syntheticInfoPlist.replace('<key>FirebaseMessagingAutoInitEnabled</key><false/>', '<key>FirebaseMessagingAutoInitEnabled</key><true/>')],
  ];
  for (const [index, [name, bytes]] of cases.entries()) {
    await t.test(`${index}: ${name}`, async (t) => {
      const qa = photoFixture(t);
      qa.put(name, bytes);
      await assert.rejects(qa.buildIos(), undefined, name);
      assert.equal(qa.state.builds, 0, name);
      assert.equal(fs.readFileSync(path.join(qa.root, 'ios/Runner/GoogleService-Info.plist'), 'utf8'), 'original Google config');
    });
  }
});
test('iOS build restores originals after success and preserves concurrent edits after failure', async (t) => {
  const normal = photoFixture(t);
  await normal.buildIos();
  assert.equal(normal.state.builds, 1);
  assert.equal(fs.readFileSync(path.join(normal.root, 'ios/Runner/GoogleService-Info.plist'), 'utf8'), 'original Google config');
  const concurrent = photoFixture(t, {build: (root) => {
    fs.writeFileSync(path.join(root, 'ios/Runner/GoogleService-Info.plist'), 'concurrent update');
    return {status: 1};
  }});
  await assert.rejects(concurrent.buildIos());
  assert.equal(fs.readFileSync(path.join(concurrent.root, 'ios/Runner/GoogleService-Info.plist'), 'utf8'), 'concurrent update');
  assert.equal(fs.readFileSync(path.join(concurrent.root, 'ios/Runner/Info.plist'), 'utf8'), 'original Info config');
});
test('iOS restoration continues after one restore fails', async (t) => {
  const qa = photoFixture(t, {fs: {...fs, writeFileSync: (target, data, ...args) => {
    if (String(target).endsWith('GoogleService-Info.plist') && String(data) === 'original Google config') throw Error('restore failed');
    return fs.writeFileSync(target, data, ...args);
  }}});
  await assert.rejects(qa.buildIos());
  assert.equal(fs.readFileSync(path.join(qa.root, 'ios/Runner/Info.plist'), 'utf8'), 'original Info config');
});
test('photo relay preserves real fal deletion status and payload details', async (t) => {
  for (const status of [200, 503]) {
    const payload = {cdn_delete_results: [{exception: status === 200 ? null : 'unavailable'}]};
    const qa = photoFixture(t, {env: {FAL_API_KEY: 'fixture-key'}, fetch: async () => Response.json(payload, {status})});
    qa.put('ledger.json', JSON.stringify([{kind: 'real', requestId: 'req-abcdef12'}]));
    const response = {writeHead(code) { this.status = code; }, end(body) { this.body = body; }};
    await qa.relayDelete('/fal-payloads/v1/models/requests/req-abcdef12/payloads', response);
    assert.equal(response.status, status);
    assert.deepEqual(JSON.parse(response.body), payload);
  }
});
test('photo relay reports an explicit successful cleanup for synthetic requests', async (t) => {
  const qa = photoFixture(t);
  const response = {writeHead(code) { this.status = code; }, end(body) { this.body = body; }};
  await qa.relayDelete('/fal-payloads/v1/models/requests/stub-abcdef12/payloads', response);
  assert.equal(response.status, 200);
  assert.deepEqual(JSON.parse(response.body), {cdn_delete_results: []});
});
test('photo relay cannot acknowledge real payload deletion when its key is unavailable', async (t) => {
  const qa = photoFixture(t);
  qa.put('ledger.json', JSON.stringify([{kind: 'real', requestId: 'req-abcdef12'}]));
  const response = {writeHead(code) { this.status = code; }, end(body) { this.body = body; }};
  await qa.relayDelete('/fal-payloads/v1/models/requests/req-abcdef12/payloads', response);
  assert.equal(response.status, 503);
});
test('photo relay cannot acknowledge unknown non-synthetic payload deletion', async (t) => {
  const qa = photoFixture(t);
  const response = {writeHead(code) { this.status = code; }, end(body) { this.body = body; }};
  await qa.relayDelete('/fal-payloads/v1/models/requests/req-fedcba98/payloads', response);
  assert.equal(response.status, 503);
});
test('iOS build rejects an empty pinned certificate before building', async (t) => {
  const qa = photoFixture(t);
  qa.put('cert.der', Buffer.alloc(0));
  qa.put('dart-defines.json', JSON.stringify({...qa.defines, PRISM_LOCAL_QA_CERTIFICATE: ''}));
  await assert.rejects(qa.buildIos());
  assert.equal(qa.state.builds, 0);
});
test('CLI child networking allows only the socket attested by the emulator child', () => {
  const guard = path.join(__dirname, 'cli_network_guard.cjs');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'qa-guard-tmpdir-'));
  const socket = path.join(tmp, 'fire_emu_0123456789abcdef.sock');
  const result = probe(`
    const childProcess = require('node:child_process');
    const http = require('node:http');
    const assert = require('node:assert/strict');
    require(${JSON.stringify(guard)});
    const socket = ${JSON.stringify(socket)};
    const child = childProcess.spawn(process.execPath, ['-e', "require('node:http').createServer((req, res) => res.end('ready')).listen(process.env.PORT); setInterval(() => {}, 1000)"], {
      env: {PATH: process.env.PATH, TMPDIR: ${JSON.stringify(tmp)}, PORT: socket, NODE_OPTIONS: '--require=${guard}'}, stdio: ['ignore', 'ignore', 'inherit', 'ipc'],
    });
    const request = http.get({socketPath: socket, path: '/'}, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => body += chunk);
      response.on('end', () => {
        assert.equal(body, 'ready');
        child.kill();
      });
    });
    request.on('error', (error) => { throw error; });
    child.once('message', (message) => {
      assert.equal(message.type, 'local-qa-emulator-socket');
    });
    child.once('exit', () => {
      const net = require('node:net');
      assert.throws(() => new net.Socket().connect({path: socket}), /denied nonlocal TCP/);
      require('node:fs').unlinkSync(socket);
      const peer = net.createServer();
      peer.listen(socket, () => {
        assert.throws(() => new net.Socket().connect({path: socket}), /denied nonlocal TCP/);
        peer.close();
      });
    });
  `, {TMPDIR: tmp});
  fs.rmSync(tmp, {recursive: true, force: true});
  assert.equal(result.status, 0, result.stderr);
});
test('CLI child networking rejects an unrelated server bound to its assigned emulator path', () => {
  const guard = path.join(__dirname, 'cli_network_guard.cjs');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'qa-guard-peer-'));
  const socket = path.join(tmp, 'fire_emu_0123456789abcdef.sock');
  const result = probe(`
    const childProcess = require('node:child_process');
    const net = require('node:net');
    const assert = require('node:assert/strict');
    require(${JSON.stringify(guard)});
    const server = net.createServer();
    const socket = ${JSON.stringify(socket)};
    server.listen(socket, () => {
      const child = childProcess.spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], {
        env: {PATH: process.env.PATH, TMPDIR: ${JSON.stringify(tmp)}, PORT: socket, NODE_OPTIONS: '--require=${guard}'}, stdio: ['ignore', 'ignore', 'inherit', 'ipc'],
      });
      assert.throws(() => new net.Socket().connect({path: socket}), /denied nonlocal TCP/);
      child.kill();
      child.once('exit', () => server.close());
    });
  `, {TMPDIR: tmp});
  fs.rmSync(tmp, {recursive: true, force: true});
  assert.equal(result.status, 0, result.stderr);
});
test('CLI child networking rejects traversal and symlink substitution of an attested socket', () => {
  const guard = path.join(__dirname, 'cli_network_guard.cjs');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'qa-guard-boundary-'));
  const socket = path.join(tmp, 'fire_emu_0123456789abcdef.sock');
  const result = probe(`
    const childProcess = require('node:child_process');
    const fs = require('node:fs');
    const net = require('node:net');
    const path = require('node:path');
    const assert = require('node:assert/strict');
    require(${JSON.stringify(guard)});
    const socket = ${JSON.stringify(socket)};
    const child = childProcess.spawn(process.execPath, ['-e', "require('node:net').createServer().listen(process.env.PORT); setInterval(() => {}, 1000)"], {
      env: {PATH: process.env.PATH, TMPDIR: ${JSON.stringify(tmp)}, PORT: socket, NODE_OPTIONS: '--require=${guard}'}, stdio: ['ignore', 'ignore', 'inherit', 'ipc'],
    });
    child.once('message', () => {
      const directory = path.dirname(socket);
      const traversal = directory + '/../' + path.basename(directory) + '/' + path.basename(socket);
      assert.throws(() => new net.Socket().connect({path: traversal}), /denied nonlocal TCP/);
      fs.unlinkSync(socket);
      fs.symlinkSync(path.join(path.dirname(socket), 'peer.sock'), socket);
      assert.throws(() => new net.Socket().connect({path: socket}), /denied nonlocal TCP/);
      child.kill();
    });
  `, {TMPDIR: tmp});
  fs.rmSync(tmp, {recursive: true, force: true});
  assert.equal(result.status, 0, result.stderr);
});
