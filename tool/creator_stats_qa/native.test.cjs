'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const test = require('node:test');

test('native config preflight does not leave a partial demo config beside a real config', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'creator-stats-native-'));
  try {
    const toolDir = path.join(root, 'tool/creator_stats_qa');
    const androidDir = path.join(root, 'android/app');
    const iosDir = path.join(root, 'ios/Runner');
    fs.mkdirSync(toolDir, {recursive: true});
    fs.mkdirSync(androidDir, {recursive: true});
    fs.mkdirSync(iosDir, {recursive: true});
    fs.copyFileSync(path.join(__dirname, 'native.cjs'), path.join(toolDir, 'native.cjs'));
    const realAndroidConfig = '{"project_info":{"project_id":"prism-wallpapers"}}\n';
    fs.writeFileSync(path.join(androidDir, 'google-services.json'), realAndroidConfig);

    const result = spawnSync(process.execPath, [path.join(toolDir, 'native.cjs'), 'demo-prism'], {encoding: 'utf8'});

    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Existing native config differs/);
    assert.equal(fs.readFileSync(path.join(androidDir, 'google-services.json'), 'utf8'), realAndroidConfig);
    assert.equal(fs.existsSync(path.join(iosDir, 'GoogleService-Info.plist')), false);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('native config preflight does not leave Android config when a real iOS config exists', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'creator-stats-native-'));
  try {
    const toolDir = path.join(root, 'tool/creator_stats_qa');
    const androidDir = path.join(root, 'android/app');
    const iosDir = path.join(root, 'ios/Runner');
    fs.mkdirSync(toolDir, {recursive: true});
    fs.mkdirSync(androidDir, {recursive: true});
    fs.mkdirSync(iosDir, {recursive: true});
    fs.copyFileSync(path.join(__dirname, 'native.cjs'), path.join(toolDir, 'native.cjs'));
    const realIosConfig = '<plist><string>prism-wallpapers</string></plist>\n';
    fs.writeFileSync(path.join(iosDir, 'GoogleService-Info.plist'), realIosConfig);

    const result = spawnSync(process.execPath, [path.join(toolDir, 'native.cjs'), 'demo-prism'], {encoding: 'utf8'});

    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Existing iOS native config differs/);
    assert.equal(fs.readFileSync(path.join(iosDir, 'GoogleService-Info.plist'), 'utf8'), realIosConfig);
    assert.equal(fs.existsSync(path.join(androidDir, 'google-services.json')), false);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});
