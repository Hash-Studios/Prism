import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in <String>[
    'native-ios',
    'native-android',
    'admin',
    'worker',
    'environment',
  ]) {
    test('shared folders QA isolates $scenario', () async {
      final result = await Process.run('node', <String>['-e', _sandbox, Directory.current.path, scenario]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });
  }
}

const _sandbox = r'''
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const repo = process.argv[1];
const scenario = process.argv[2];
const filename = path.join(repo, 'tool/shared_folders_qa.cjs');
const source = fs.readFileSync(filename, 'utf8');
const backend = fs.readFileSync(path.join(repo, 'tool/weekly_challenge_qa/backend.cjs'), 'utf8');
const root = '/tmp/prism-shared-folders-qa-test';

function sandbox({env = {}, apps = [], links = []} = {}) {
  const files = new Map([
    [path.join(root, 'manifest.json'), JSON.stringify({project: 'demo-prism', runtime: root})],
    [path.join(root, 'key.pem'), 'disposable-test-key'],
    [path.join(root, 'cert.der'), 'disposable-test-certificate'],
  ]);
  const symlinks = new Set(links);
  const writes = [];
  let adminReads = 0;
  const directories = new Set(['/tmp', root, path.join(root, 'functions')]);
  const fakeFs = {
    constants: fs.constants,
    existsSync: p => files.has(p) || directories.has(p) || symlinks.has(p),
    lstatSync: p => {
      if (!fakeFs.existsSync(p)) throw Object.assign(Error('missing'), {code: 'ENOENT'});
      return {isSymbolicLink: () => symlinks.has(p), isDirectory: () => directories.has(p), uid: process.getuid()};
    },
    realpathSync: p => symlinks.has(p) ? '/outside-runtime' : p,
    readFileSync: (p, encoding) => {
      if (!files.has(p)) throw Error('Unexpected read: ' + p);
      const bytes = Buffer.from(files.get(p));
      return encoding ? bytes.toString(encoding) : bytes;
    },
    writeFileSync: (p, value) => { writes.push(p); files.set(p, value); },
    mkdirSync: p => directories.add(p),
    readdirSync: () => Array.from({length: 8}, (_, i) => `cover-${i}.webp`),
    cpSync: () => {},
    copyFileSync: () => {},
    symlinkSync: () => {},
    chmodSync: () => {},
  };
  const fakeNet = {Socket: function () {}};
  fakeNet.Socket.prototype.connect = () => { throw Error('Unexpected real connection'); };
  const fakeProcess = {
    argv: ['node', filename, 'seed', '--root', root], env: {...env},
    versions: {node: '24.0.0'}, getuid: () => process.getuid(),
  };
  const admin = {
    apps,
    credential: {cert: value => value},
    initializeApp: options => { apps.push({options}); },
    firestore: () => { adminReads++; return {}; },
  };
  let guard;
  function fakeRequire(name) {
    if (name === 'node:fs') return fakeFs;
    if (name === 'node:net') return fakeNet;
    if (name === 'node:child_process') return {spawnSync: () => ({status: 0})};
    if (name === './weekly_challenge_qa/backend.cjs' || name === '../backend.cjs') return guard;
    if (name === 'firebase-admin' || name.endsWith('/node_modules/firebase-admin')) return admin;
    if (name.startsWith('./lib/')) return {};
    if (name.startsWith('node:')) return require(name);
    throw Error('Unexpected require: ' + name);
  }
  const context = vm.createContext({
    require: fakeRequire, __dirname: path.dirname(filename), process: fakeProcess,
    Buffer, console: {log: () => {}, error: () => {}}, AbortSignal,
    fetch: () => { throw Error('Unexpected fetch'); },
  });
  const module = {exports: {}};
  vm.runInNewContext(backend, {require: fakeRequire, process: fakeProcess, module});
  guard = module.exports;
  // Evaluate the CLI definitions, but never dispatch a command or open a real resource.
  vm.runInContext(source.slice(0, source.lastIndexOf('commands[command]().catch')), context);
  return {context, files, writes, admin, symlinks, fakeProcess, adminReads: () => adminReads,
    run: expression => vm.runInContext(expression, context)};
}

async function prepared() {
  const s = sandbox();
  s.run('preflight = async () => {}; sha256 = () => "fixture-sha"');
  await s.run('prepare()');
  return s;
}

async function main() {
  if (scenario.startsWith('native-')) {
    const s = await prepared();
    const android = s.files.get(path.join(root, 'native/google-services.json'));
    const ios = s.files.get(path.join(root, 'native/GoogleService-Info.plist'));
    s.context.android = android;
    s.context.ios = Buffer.from(ios);
    s.run('validateAndroid(android); validateIos(ios)');
    if (scenario === 'native-ios') {
      s.context.ios = Buffer.from(ios.replace('<key>PROJECT_ID</key><string>demo-prism</string>',
        '<key>PROJECT_ID</key><string>prism-wallpapers</string><key>DECOY</key><string>demo-prism</string>'));
      assert.throws(() => s.run('validateIos(ios)'), /Refusing|synthetic|demo/);
    } else {
      const mixed = JSON.parse(android);
      mixed.client.push({client_info: {mobilesdk_app_id: '1:999:android:production',
        android_client_info: {package_name: 'com.hash.prism'}}, api_key: [{current_key: 'production-key'}]});
      s.context.android = JSON.stringify(mixed);
      assert.throws(() => s.run('validateAndroid(android)'), /Refusing|synthetic|client/);
    }
  }
  if (scenario === 'admin') {
    for (const projectId of ['prism-wallpapers', 'demo-prism']) {
      const s = sandbox({apps: [{options: {projectId}}]});
      assert.throws(() => s.run('loadBackend()'), /Admin|app|initialized/);
      assert.equal(s.adminReads(), 0);
    }
    const s = sandbox();
    s.run('loadBackend()');
    assert.equal(s.admin.apps[0].options.projectId, 'demo-prism');
  }
  if (scenario === 'worker') {
    const preparedRuntime = await prepared();
    const entry = preparedRuntime.files.get(path.join(root, 'functions/index.cjs'));
    for (const [env, apps, expected] of [
      [{}, [], /Emulator only/],
      [{FUNCTIONS_EMULATOR: 'true', FIRESTORE_EMULATOR_HOST: 'production:443'}, [], /nonlocal/],
      [{FUNCTIONS_EMULATOR: 'true', GOOGLE_APPLICATION_CREDENTIALS: '/credentials.json'}, [], /Unset/],
      [{FUNCTIONS_EMULATOR: 'true'}, [{options: {projectId: 'prism-wallpapers'}}], /Admin|app|initialized/],
    ]) {
      const s = sandbox({env, apps});
      s.context.exports = {};
      s.context.__dirname = path.join(root, 'functions');
      assert.throws(() => vm.runInContext(`(function () {\n${entry}\n})()`, s.context), expected);
      assert.equal(s.adminReads(), 0);
    }
    const s = sandbox({env: {FUNCTIONS_EMULATOR: 'true'}});
    s.context.exports = {};
    s.context.__dirname = path.join(root, 'functions');
    vm.runInContext(`(function () {\n${entry}\n})()`, s.context);
    assert.equal(s.admin.apps[0].options.projectId, 'demo-prism');
    assert.equal(s.fakeProcess.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:19372');
    assert.equal(s.fakeProcess.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:19371');
  }
  if (scenario === 'paths') {
    const rootLink = sandbox({links: [root]});
    rootLink.files.set(path.join(root, 'manifest.json'), JSON.stringify({project: 'demo-prism', runtime: '/outside-runtime'}));
    assert.throws(() => rootLink.run('loadBackend()'), /symlink|runtime|Runtime/);
    const targetLink = sandbox({links: [path.join(root, 'state.json')]});
    assert.throws(() => targetLink.run('write("state.json", {test: true})'), /symlink|runtime|Runtime/);
    assert.equal(targetLink.writes.length, 0);
  }
  if (scenario === 'redirects') {
    const s = sandbox();
    const requests = [];
    s.context.fetch = async (url, options) => {
      requests.push({url, options});
      if (options.redirect !== 'error') throw Error('Redirect could forward a write outside demo-prism');
      return {status: 200, json: async () => url.includes('signInWithPassword')
        ? {localId: 'qa-creator-a', idToken: 'emulator-token'} : {result: {}}};
    };
    await s.run('callable("qa-creator-a", "createFolderInvite", {folderId: "qa-trip"})');
    assert.equal(requests.length, 2);
    assert.match(requests[1].url, /^http:\/\/127\.0\.0\.1:19373\/demo-prism\//);
  }
  if (scenario === 'environment') {
    for (const env of [
      {GCLOUD_PROJECT: 'prism-wallpapers'},
      {GOOGLE_CLOUD_PROJECT: 'prism-wallpapers'},
      {FIREBASE_CONFIG: JSON.stringify({projectId: 'prism-wallpapers'})},
      {FIRESTORE_EMULATOR_HOST: 'production:443'},
      {FIREBASE_AUTH_EMULATOR_HOST: 'production:443'},
      {GOOGLE_APPLICATION_CREDENTIALS: '/credentials.json'},
    ]) {
      const s = sandbox({env});
      assert.throws(() => s.run('loadBackend()'), /Refusing|Unset/);
      assert.equal(s.adminReads(), 0);
    }
  }
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
''';
