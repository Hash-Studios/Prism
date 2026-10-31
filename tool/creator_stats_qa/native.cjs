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
const iosTarget = path.resolve(__dirname, '../../ios/Runner/GoogleService-Info.plist');
const iosConfig = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>API_KEY</key><string>AIzaSyDemoPrismLocalOnly00000000000000000</string>
<key>GCM_SENDER_ID</key><string>123456789012</string>
<key>GOOGLE_APP_ID</key><string>1:123456789012:ios:0000000000000000000000</string>
<key>PROJECT_ID</key><string>demo-prism</string>
<key>STORAGE_BUCKET</key><string>demo-prism.appspot.com</string>
<key>BUNDLE_ID</key><string>com.hash.prism</string>
<key>IS_ANALYTICS_ENABLED</key><false/>
<key>IS_GCM_ENABLED</key><false/>
<key>PLIST_VERSION</key><string>1</string>
</dict></plist>
`;
if (fs.existsSync(iosTarget)) {
  assert.equal(fs.readFileSync(iosTarget, 'utf8'), iosConfig,
    'Existing iOS native config differs. Refusing to overwrite it. Use a QA checkout with no real native config.');
} else fs.writeFileSync(iosTarget, iosConfig, {flag: 'wx'});
if (fs.existsSync(target)) {
  assert.deepEqual(JSON.parse(fs.readFileSync(target, 'utf8')), config,
    'Existing native config differs. Refusing to overwrite it. Use a QA checkout with no real native config.');
} else fs.writeFileSync(target, JSON.stringify(config, null, 2) + '\n', {flag: 'wx'});
console.log('Demo-only Android and iOS native config ready. Never commit it or use this checkout for release builds.');
