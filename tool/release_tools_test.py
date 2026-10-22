"""Behavioral release-tool fixtures. No network, credentials, signing or builds."""

import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / 'tool/flutter_with_doppler.py'
PREPARE = ROOT / 'tool/prepare_release_firebase.py'
APP = 'com.hash.prism'
SENDER = '123456789012'
API_KEY = 'AIza' + 'x' * 35


def android_config():
    return {
        'project_info': {'project_id': 'prism-wallpapers', 'project_number': SENDER,
                         'storage_bucket': 'prism-wallpapers.firebasestorage.app'},
        'client': [{'client_info': {'mobilesdk_app_id': f'1:{SENDER}:android:abcdef0123456789',
                                    'android_client_info': {'package_name': APP}},
                    'api_key': [{'current_key': API_KEY}]}],
    }


def ios_config():
    return {'PROJECT_ID': 'prism-wallpapers', 'GCM_SENDER_ID': SENDER,
            'STORAGE_BUCKET': 'prism-wallpapers.appspot.com', 'BUNDLE_ID': APP,
            'GOOGLE_APP_ID': f'1:{SENDER}:ios:abcdef0123456789', 'API_KEY': API_KEY,
            'CLIENT_ID': 'fixture.apps.googleusercontent.com'}


class ReleaseFixture:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='prism-release-test-')
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        (self.work / 'bin').mkdir()
        self.env = {**os.environ, 'PATH': f'{self.work}/bin:{os.environ["PATH"]}',
                    'DOPPLER_PROJECT': 'prism', 'DOPPLER_CONFIG': 'prd',
                    'DOPPLER_TOKEN': 'fixture-service-token',
                    'CAPTURE': str(self.work / 'argv.json'),
                    'PAYLOAD': str(self.work / 'doppler.json')}
        for key in list(self.env):
            if key.startswith('SENTRY_') or key == 'IOS_GOOGLE_SERVICE_INFO_PLIST':
                self.env.pop(key)
        self.values = {'GH_USERNAME': 'owner', 'R2_PREVIEW_BASE_URL': 'https://images.example.com',
                       'GH_TOKEN': 'server-github', 'SENTRY_AUTH_TOKEN': 'server-sentry',
                       'R2_ACCESS_KEY_ID': 'server-access', 'R2_SECRET_ACCESS_KEY': 'server-secret',
                       'R2_PRIVATE_BUCKET': 'server-private', 'FIREBASE_SECRET': 'server-firebase',
                       'UNKNOWN_FUTURE_SECRET': 'server-future', 'SKIP_FIREBASE_INIT': 'true'}
        self.write_payload()
        self.executable('doppler', '''#!/usr/bin/env python3
import os, pathlib, sys
if os.environ.get('DOPPLER_FAIL'):
    print('untrusted credential output', file=sys.stderr)
    sys.exit(int(os.environ['DOPPLER_FAIL']))
sys.stdout.write(pathlib.Path(os.environ['PAYLOAD']).read_text())
''')
        self.executable('flutter', '''#!/usr/bin/env python3
import json, os, pathlib, sys
if sys.argv[1:2] == ['config']:
    sys.exit(0)
pathlib.Path(os.environ['CAPTURE']).write_text(json.dumps(sys.argv[1:]))
sys.exit(int(os.environ.get('FLUTTER_EXIT', '0')))
''')

    def executable(self, name, source):
        path = self.work / 'bin' / name
        path.write_text(source)
        path.chmod(0o755)

    def write_payload(self):
        Path(self.env['PAYLOAD']).write_text(json.dumps(self.values))

    def run_tool(self, *args):
        return subprocess.run(args, cwd=self.work, env=self.env, capture_output=True, text=True)

    def native(self, platform):
        path = self.work / ('android/app/google-services.json' if platform == 'android'
                            else 'ios/Runner/GoogleService-Info.plist')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(json.dumps(android_config()).encode() if platform == 'android'
                         else plistlib.dumps(ios_config()))
        return path


class ReleaseToolsTest(ReleaseFixture, unittest.TestCase):
    def test_exact_argv_and_no_execution_or_credentials(self):
        dangerous = ' spaced "double" \'single\' = \\ $(touch OWNED) `touch ALSO_OWNED`; & | > * ?\nnext'
        self.values['PEXELS_API_KEY'] = dangerous
        self.env['SENTRY_RELEASE'] = dangerous
        self.write_payload()
        result = self.run_tool('python3', str(RUNNER), '--', 'flutter', 'build', 'ipa', '--release')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(Path(self.env['CAPTURE']).read_text()), [
            'build', 'ipa', '--release', '--dart-define=GH_USERNAME=owner',
            '--dart-define=R2_PREVIEW_BASE_URL=https://images.example.com',
            '--dart-define=PEXELS_API_KEY=' + dangerous, '--dart-define=SENTRY_RELEASE=' + dangerous])
        self.assertFalse((self.work / 'OWNED').exists())
        self.assertFalse((self.work / 'ALSO_OWNED').exists())
        self.assertEqual(result.stdout + result.stderr, '')

    def test_download_failure_prevents_flutter_and_preserves_exit(self):
        self.env['DOPPLER_FAIL'] = '23'
        result = self.run_tool('python3', str(RUNNER), '--', 'flutter', 'run')
        self.assertEqual(result.returncode, 23)
        self.assertFalse(Path(self.env['CAPTURE']).exists())
        self.assertNotIn('untrusted credential output', result.stdout + result.stderr)

    def test_flutter_failure_preserved(self):
        self.env['FLUTTER_EXIT'] = '37'
        result = self.run_tool('python3', str(RUNNER), '--', 'flutter', 'run')
        self.assertEqual(result.returncode, 37)

    def test_malformed_payload_prevents_flutter_without_logging_payload(self):
        Path(self.env['PAYLOAD']).write_text('server-secret invalid JSON')
        result = self.run_tool('python3', str(RUNNER), '--', 'flutter', 'run')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(Path(self.env['CAPTURE']).exists())
        self.assertNotIn('server-secret', result.stdout + result.stderr)

    def test_allowlist_tracks_shipping_env_keys(self):
        # The contract is Env, not every name returned by Doppler. Bool debug
        # switches are deliberately not shipping configuration.
        env_keys = set(re.findall(r"String\.fromEnvironment\('([^']+)'", (ROOT / 'lib/env/env.dart').read_text()))
        self.values = {key: 'fixture' for key in env_keys}
        self.write_payload()
        result = self.run_tool('python3', str(RUNNER), '--', 'flutter', 'run')
        self.assertEqual(result.returncode, 0, result.stderr)
        argv = json.loads(Path(self.env['CAPTURE']).read_text())
        self.assertEqual({arg.split('=', 2)[1] for arg in argv[1:]}, env_keys)

    def test_release_missing_config_stops_before_flutter(self):
        for platform in ('android', 'ios'):
            with self.subTest(platform=platform):
                result = self.run_tool('python3', str(RUNNER), '--release-platform', platform,
                                       '--', 'flutter', 'build', 'ipa', '--release')
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_native_config_derives_options_for_selected_platform(self):
        for platform in ('android', 'ios'):
            with self.subTest(platform=platform):
                self.native(platform)
                result = self.run_tool('python3', str(RUNNER), '--release-platform', platform,
                                       '--', 'flutter', 'build', 'ipa', '--release')
                self.assertEqual(result.returncode, 0, result.stderr)
                options = (self.work / 'lib/firebase_options.dart').read_text()
                self.assertIn(f'appId: \'1:{SENDER}:{platform}:abcdef0123456789\'', options)
                self.assertIn("projectId: 'prism-wallpapers'", options)
                enum = {'android': 'android', 'ios': 'iOS'}[platform]
                self.assertIn(f'defaultTargetPlatform == TargetPlatform.{enum})', options)
                self.assertIn(f'return {platform};', options)
                self.assertIn(f'static const FirebaseOptions {platform} = FirebaseOptions(', options)
                self.assertIn(f"throw UnsupportedError('Firebase configuration was prepared only for {platform}.');",
                              options)
                fields = re.findall(r'^    (\w+): ', options, re.MULTILINE)
                expected_fields = ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'storageBucket']
                if platform == 'ios':
                    expected_fields += ['iosBundleId', 'iosClientId']
                self.assertCountEqual(fields, expected_fields)
                self.assertIn(f"apiKey: '{API_KEY}'", options)
                self.assertNotIn('SKIP_FIREBASE_INIT', ' '.join(json.loads(Path(self.env['CAPTURE']).read_text())))
                self.assertNotIn(API_KEY, result.stdout + result.stderr)

    def test_invalid_native_config_never_builds(self):
        mutations = [('PROJECT_ID', 'other-project'), ('BUNDLE_ID', 'other.bundle'),
                     ('GOOGLE_APP_ID', f'1:{SENDER}:android:abcdef0123456789'),
                     ('GOOGLE_APP_ID', '1:000000000000:ios:0000000000000000'),
                     ('API_KEY', ''), ('GCM_SENDER_ID', 'wrong'), ('STORAGE_BUCKET', 'other.appspot.com')]
        path = self.native('ios')
        for key, value in mutations:
            with self.subTest(key=key, value=value):
                data = ios_config()
                data[key] = value
                path.write_bytes(plistlib.dumps(data))
                result = self.run_tool('python3', str(RUNNER), '--release-platform', 'ios',
                                       '--', 'flutter', 'build', 'ipa')
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(Path(self.env['CAPTURE']).exists())
                self.assertNotIn(API_KEY, result.stdout + result.stderr)

    def test_android_rejects_wrong_package_and_project_and_app_platform(self):
        path = self.native('android')
        for mutation in ('package', 'project', 'platform', 'missing-key'):
            data = android_config()
            if mutation == 'package':
                data['client'][0]['client_info']['android_client_info']['package_name'] = 'other.app'
            elif mutation == 'project':
                data['project_info']['project_id'] = 'other-project'
            elif mutation == 'platform':
                data['client'][0]['client_info']['mobilesdk_app_id'] = f'1:{SENDER}:ios:abcdef0123456789'
            else:
                data['client'][0]['api_key'] = []
            path.write_text(json.dumps(data))
            result = self.run_tool('python3', str(RUNNER), '--release-platform', 'android',
                                   '--', 'flutter', 'build', 'appbundle')
            self.assertNotEqual(result.returncode, 0, mutation)
            self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_rejects_skip_or_unchecked_define_files(self):
        self.native('ios')
        for arguments in (['--dart-define=SKIP_FIREBASE_INIT=true'], ['--dart-define-from-file=unsafe.json'],
                          ['--dart-define', 'SKIP_FIREBASE_INIT=true']):
            result = self.run_tool('python3', str(RUNNER), '--release-platform', 'ios', '--',
                                   'flutter', 'build', 'ipa', *arguments)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_ios_new_secret_prerequisite_and_android_existing_doppler_key(self):
        result = self.run_tool('python3', str(PREPARE), 'ios', '--from-environment')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('IOS_GOOGLE_SERVICE_INFO_PLIST', result.stderr)
        self.env['IOS_GOOGLE_SERVICE_INFO_PLIST'] = plistlib.dumps(ios_config()).decode()
        result = self.run_tool('python3', str(PREPARE), 'ios', '--from-environment')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(plistlib.loads((self.work / 'ios/Runner/GoogleService-Info.plist').read_bytes()), ios_config())
        Path(self.env['PAYLOAD']).write_text(json.dumps(android_config()))
        result = self.run_tool('python3', str(PREPARE), 'android', '--from-doppler')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.work / 'android/app/google-services.json').read_text()), android_config())

    def test_make_run_uses_same_safe_protocol_without_echoing_defines(self):
        shutil.copy(ROOT / 'Makefile', self.work)
        (self.work / 'tool').symlink_to(ROOT / 'tool', target_is_directory=True)
        self.values['PEXELS_API_KEY'] = 'quotes " \' spaces = \\ $(touch OWNED); &'
        self.env['SENTRY_RELEASE'] = self.values['PEXELS_API_KEY']
        self.write_payload()
        result = self.run_tool('make', '-o', 'doppler-check', 'run', 'CI=true', 'ANDROID_JAVA_HOME=',
                               'FIREBASE_RUN_ARG=', 'DOPPLER_CONFIG=prd')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('--dart-define=PEXELS_API_KEY=' + self.values['PEXELS_API_KEY'],
                      json.loads(Path(self.env['CAPTURE']).read_text()))
        self.assertIn('--dart-define=SENTRY_RELEASE=' + self.env['SENTRY_RELEASE'],
                      json.loads(Path(self.env['CAPTURE']).read_text()))
        self.assertNotIn(self.values['PEXELS_API_KEY'], result.stdout + result.stderr)
        self.assertFalse((self.work / 'OWNED').exists())


if __name__ == '__main__':
    unittest.main()
