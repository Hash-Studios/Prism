'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../weekly_challenge_qa.cjs'), 'utf8');

for (const failure of ['build', 'missing-manifest', 'changed-manifest', 'missing-overlay', 'disabled-qa', 'extra-define', 'real-config', 'both-restores', 'restore-after-success']) {
  test(`temporary inputs restore after ${failure}`, async t => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'prism-weekly-qa-review-'));
    t.after(() => fs.rmSync(root, {recursive: true, force: true}));
    const runtime = path.join(root, 'runtime');
    const config = path.join(root, 'android/app/google-services.json');
    const manifest = path.join(root, 'android/app/src/debug/AndroidManifest.xml');
    for (const dir of ['runtime/native', 'android/app/src/debug', 'tool/weekly_challenge_qa']) {
      fs.mkdirSync(path.join(root, dir), {recursive: true});
    }
    fs.writeFileSync(path.join(runtime, 'manifest.json'), JSON.stringify({project: 'demo-prism', runtime}));
    fs.writeFileSync(path.join(runtime, 'cert.der'), 'fixture certificate');
    const defines = {PRISM_LOCAL_QA: failure === 'disabled-qa' ? 'false' : 'true', PRISM_LOCAL_QA_USER: 'viewer', PRISM_LOCAL_QA_CERTIFICATE: Buffer.from('fixture certificate').toString('base64')};
    if (failure === 'extra-define') defines.SKIP_FIREBASE_INIT = 'true';
    fs.writeFileSync(path.join(runtime, 'dart-defines.json'), JSON.stringify(defines));
    fs.writeFileSync(path.join(runtime, 'native/google-services.json'), JSON.stringify({project_info: {project_id: 'demo-prism'}, client: [{api_key: [{current_key: failure === 'real-config' ? 'unexpected-key' : 'AIzaSy000000000000000000000000000000000'}]}], fixture: true}));
    const originalConfig = JSON.stringify({project_info: {project_id: 'demo-prism'}, client: [{api_key: [{current_key: 'AIzaSy000000000000000000000000000000000'}]}], original: true});
    fs.writeFileSync(config, originalConfig);
    fs.writeFileSync(manifest, 'original manifest');
    if (failure !== 'missing-overlay') fs.writeFileSync(path.join(root, 'tool/weekly_challenge_qa/AndroidManifest.xml'), 'QA overlay');
    let error;
    let aggregate;
    let builds = 0;
    const fakeProcess = {argv: ['node', 'helper', 'build-apk', '--root', runtime], env: {}, versions: process.versions};
    const context = vm.createContext({
      __dirname: path.join(root, 'tool'), process: fakeProcess,
      AggregateError: class extends AggregateError {
        constructor(errors, message) { super(errors, message); aggregate = this; }
      },
      console: {error: value => { error = value; }, log() {}},
      require(name) {
        if (name === 'node:child_process') return {spawnSync() {
          builds++;
          if (failure === 'missing-manifest') fs.unlinkSync(manifest);
          if (failure === 'changed-manifest' || failure === 'both-restores' || failure === 'restore-after-success') fs.writeFileSync(manifest, 'peer edit');
          if (failure === 'both-restores') fs.writeFileSync(config, 'peer config');
          return {status: failure === 'restore-after-success' ? 0 : 1};
        }};
        if (name === './weekly_challenge_qa/backend.cjs') return require('./backend.cjs');
        return require(name);
      },
    });
    await vm.runInContext(source, context);
    assert.equal(fakeProcess.exitCode, 1);
    assert.ok(error);
    assert.equal(builds, ['missing-overlay', 'disabled-qa', 'extra-define', 'real-config'].includes(failure) ? 0 : 1);
    if (['missing-manifest', 'changed-manifest', 'both-restores'].includes(failure)) {
      assert.match(error, /fvm exited 1/);
      assert.equal(aggregate.errors[0].message, 'fvm exited 1');
      assert.equal(aggregate.errors.length, failure === 'both-restores' ? 3 : 2);
      assert.match(error, failure === 'missing-manifest' ? /ENOENT/ : /changed concurrently/);
      if (failure === 'both-restores') {
        assert.ok(error.includes(config));
        assert.ok(error.includes(manifest));
      }
    }
    if (failure === 'restore-after-success') {
      assert.equal(aggregate.errors.length, 1);
      assert.match(aggregate.errors[0].message, /changed concurrently/);
    }
    assert.equal(fs.readFileSync(config, 'utf8'), failure === 'both-restores' ? 'peer config' : originalConfig);
    if (failure === 'changed-manifest' || failure === 'both-restores' || failure === 'restore-after-success') assert.equal(fs.readFileSync(manifest, 'utf8'), 'peer edit');
    else if (failure === 'missing-manifest') assert.equal(fs.existsSync(manifest), false);
    else assert.equal(fs.readFileSync(manifest, 'utf8'), 'original manifest');
  });
}
