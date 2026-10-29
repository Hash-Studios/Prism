'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const run = (args, env = process.env) => {
  const result = spawnSync(process.execPath, args, {cwd: __dirname, env, encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout;
};
run(['prepare.cjs', 'demo-prism']);
for (const file of ['prepare', 'local', 'seed', 'assert', 'capacity', 'native', 'images', 'bundle/index']) run(['--check', `${file}.cjs`]);
const env = {PATH: process.env.PATH, GCLOUD_PROJECT: 'demo-prism', GOOGLE_CLOUD_PROJECT: 'demo-prism'};
run(['-e', `const assert = require('node:assert/strict');
  const bundle = require('./.runtime/index.cjs');
  assert.deepEqual(Object.keys(bundle).sort(), ['getCreatorStats','onCreatorStatsDailyWritten','onCreatorStatsFolderCreated']);
  const normalizer = require('./.runtime/lib/viewStats.js');
  assert.equal(normalizer.normalizeId(' qa-creator '), 'QA-CREATOR');
  assert.throws(() => normalizer.normalizeId('bad/id'));
  const h = require('./.runtime/lib/creatorStatsHistory.js');
  assert.equal(h.weekWindows(Date.parse('2026-10-30T12:00:00Z')).length, 8);
  assert.equal(h.isoWeek(Date.parse('2026-01-01T00:00:00Z')), '2026-W01');`], env);
const denied = spawnSync(process.execPath, ['-e', "require('./.runtime/index.cjs')"], {
  cwd: __dirname, env: {...env, GCLOUD_PROJECT: 'prism-wallpapers'}, encoding: 'utf8'});
assert.notEqual(denied.status, 0);
assert.match(denied.stderr, /demo-prism only/);
const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'firebase.json')));
assert.equal(config.functions.length, 1);
assert.equal(config.functions[0].source, '.runtime');
assert.deepEqual(fs.readdirSync(path.join(__dirname, '.runtime/lib')).sort(),
  ['common.js', 'creatorStats.js', 'creatorStatsHistory.js', 'notificationCatalog.js', 'viewStats.js']);
console.log('PASS: script syntax, source transpilation, exact export/module allowlist, normalizer, week boundaries, production-project rejection. No emulator or device started.');
