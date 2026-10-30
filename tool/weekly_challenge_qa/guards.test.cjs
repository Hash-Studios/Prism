'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const backend = path.join(__dirname, 'backend.cjs');
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
