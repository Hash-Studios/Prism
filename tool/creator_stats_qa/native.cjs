'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
assert.equal(process.argv.length, 3);
assert.equal(process.argv[2], 'demo-prism');
const target = path.resolve(__dirname, '../../android/app/google-services.json');
const config = {project_info: {project_number: '123456789012', project_id: 'demo-prism', storage_bucket: 'demo-prism.appspot.com'},
  client: [{client_info: {mobilesdk_app_id: '1:123456789012:android:0000000000000000000000',
    android_client_info: {package_name: 'com.hash.prism'}}, oauth_client: [],
    api_key: [{current_key: 'AIzaSyDemoPrismLocalOnly00000000000000000'}], services: {appinvite_service: {other_platform_oauth_client: []}}}],
  configuration_version: '1'};
// Google Services prefers variant configs over the root file. Refuse any override.
function checkVariants(directory) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) checkVariants(file);
    else assert.notEqual(entry.name, 'google-services.json', `Remove native variant config from the QA checkout: ${file}`);
  }
}
checkVariants(path.resolve(__dirname, '../../android/app/src'));
if (fs.existsSync(target)) {
  assert.deepEqual(JSON.parse(fs.readFileSync(target, 'utf8')), config,
    'Existing native config differs. Refusing to overwrite it. Use a QA checkout with no real native config.');
} else fs.writeFileSync(target, JSON.stringify(config, null, 2) + '\n', {flag: 'wx'});
console.log('Demo-only Android native config ready. Never commit it or use this checkout for release builds.');
