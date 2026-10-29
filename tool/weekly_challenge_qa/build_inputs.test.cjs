'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../weekly_challenge_qa.cjs'), 'utf8');

for (const failure of ['build', 'missing-manifest', 'changed-manifest', 'missing-overlay', 'disabled-qa', 'extra-define', 'real-config']) {
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
    let builds = 0;
    const fakeProcess = {argv: ['node', 'helper', 'build-apk', '--root', runtime], env: {}, versions: process.versions};
    const context = vm.createContext({
      __dirname: path.join(root, 'tool'), process: fakeProcess,
      console: {error: value => { error = value; }, log() {}},
      require(name) {
        if (name === 'node:child_process') return {spawnSync() {
          builds++;
          if (failure === 'missing-manifest') fs.unlinkSync(manifest);
          if (failure === 'changed-manifest') fs.writeFileSync(manifest, 'peer edit');
          return {status: 1};
        }};
        if (name === './weekly_challenge_qa/backend.cjs') return require('./backend.cjs');
        return require(name);
      },
    });
    await vm.runInContext(source, context);
    assert.equal(fakeProcess.exitCode, 1);
    assert.ok(error);
    assert.equal(builds, ['missing-overlay', 'disabled-qa', 'extra-define', 'real-config'].includes(failure) ? 0 : 1);
    assert.equal(fs.readFileSync(config, 'utf8'), originalConfig);
    if (failure === 'changed-manifest') assert.equal(fs.readFileSync(manifest, 'utf8'), 'peer edit');
    else if (failure === 'missing-manifest') assert.equal(fs.existsSync(manifest), false);
    else assert.equal(fs.readFileSync(manifest, 'utf8'), 'original manifest');
  });
}
