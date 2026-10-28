"""Shorebird release records, patch refusals and the pinned CLI, run through tool/flutter_with_doppler.py.

A fake `shorebird` executable records its argv, token and key files. No network, credentials or builds.
"""

import json
from pathlib import Path
import subprocess
import unittest

from tool import release_tools_test as fixture
import tool.shorebird_ota as ota


PUBLIC_PEM = '-----BEGIN PUBLIC KEY-----\nPUB\n-----END PUBLIC KEY-----'
PRIVATE_PEM = '-----BEGIN PRIVATE KEY-----\nPRIV\n-----END PRIVATE KEY-----'
FAKE_SHOREBIRD = '''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1:] == ['--version']:
    print('Shorebird ' + os.environ.get('SB_VERSION', '1.6.133') + ' \\u2022 git@github.com:shorebirdtech/shorebird.git')
    sys.exit(0)
keys = {}
for arg in sys.argv[1:]:
    for flag in ('--public-key-path', '--private-key-path'):
        if arg.startswith(flag + '='):
            with open(arg.split('=', 1)[1]) as key:
                keys[flag] = key.read()
with open(os.environ['CAPTURE'], 'w') as capture:
    json.dump({'argv': sys.argv[1:], 'token': os.environ.get('SHOREBIRD_TOKEN'), 'keys': keys}, capture)
sys.exit(int(os.environ.get('SHOREBIRD_EXIT') or 0))
'''


def git(work, *args):
    return subprocess.run(['git', *args], cwd=work, capture_output=True, text=True, check=True)


def setup_release_repo(test):
    """Writes a release-ready app repo, the fake CLI and the Shorebird Doppler values, then commits everything."""
    work = test.work
    (work / 'pubspec.yaml').write_text('name: prism\nversion: 3.14.0+353\n')
    (work / '.fvmrc').write_text('{"flutter": "3.47.5"}\n')
    (work / 'shorebird.yaml').write_text('app_id: 11111111-2222-3333-4444-555555555555\nauto_update: false\n')
    (work / 'lib').mkdir(exist_ok=True)
    (work / 'lib/main.dart').write_text('void main() {}\n')
    (work / '.gitignore').write_text('build/\n')
    test.executable('shorebird', FAKE_SHOREBIRD)
    for name in ('SHOREBIRD_TOKEN', 'SHOREBIRD_EXIT', 'SB_VERSION'):
        test.env.pop(name, None)
    test.values.update({'SHOREBIRD_PATCH_PUBLIC_KEY': PUBLIC_PEM, 'SHOREBIRD_PATCH_PRIVATE_KEY': PRIVATE_PEM,
                        'SHOREBIRD_TOKEN': 'sb_api_fixture', 'PEXELS_API_KEY': 'pexels-secret-value'})
    test.write_payload()
    git(work, 'init', '-q')
    git(work, 'config', 'user.name', 'Prism Test')
    git(work, 'config', 'user.email', 'test@prism.invalid')
    git(work, 'add', '-A')
    git(work, 'commit', '-q', '-m', 'release fixture')


def delete_release_tags(test):
    for tag in git(test.work, 'tag', '-l', 'shorebird/*').stdout.split():
        git(test.work, 'tag', '-d', tag)


class ShorebirdOtaTest(fixture.ReleaseFixture, unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.native('android')
        setup_release_repo(self)

    def run_wrapper(self, *command, extra=()):
        return self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'android', *extra,
                             '--', 'shorebird', *command)

    def captured(self):
        return json.loads(Path(self.env['CAPTURE']).read_text())

    def tag_message(self, tag):
        return git(self.work, 'tag', '-l', '--format=%(contents)', tag).stdout

    def release(self, *extra):
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols', *extra)
        self.assertEqual(result.returncode, 0, result.stderr)
        Path(self.env['CAPTURE']).unlink()

    def commit_file(self, relative, data):
        path = self.work / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        git(self.work, 'add', '-A')
        git(self.work, 'commit', '-q', '-m', f'change {relative}')

    def test_unsafe_paths_split_native_storage_and_safe(self):
        native = ['android/app/src/main/AndroidManifest.xml', 'ios/Runner/Info.plist', 'pubspec.lock',
                  'pubspec.yaml', 'assets/fonts/ProximaNova-Regular.otf', 'packages/cloud_functions/lib/x.dart',
                  'pigeons/prism_media_api.dart', 'lib/core/platform/pigeon/prism_media_api.g.dart',
                  'shorebird.yaml', '.fvmrc', 'shaders/a.frag']
        storage = ['lib/core/persistence/persistence_keys.dart', 'lib/core/offline/durable_json_store.dart',
                   'lib/features/folders/data/folder_store.dart',
                   'lib/core/persistence/data_sources/settings_local_data_source.dart']
        safe = ['lib/features/home/views/home.dart', 'test/a_test.dart', 'docs/x.md', 'lib/l10n/app_en.arb',
                'functions/src/a.ts']
        for path in native:
            with self.subTest(native=path):
                self.assertEqual(ota.unsafe_paths([path]), ([path], []))
        for path in storage:
            with self.subTest(storage=path):
                self.assertEqual(ota.unsafe_paths([path]), ([], [path]))
        for path in safe:
            with self.subTest(safe=path):
                self.assertEqual(ota.unsafe_paths([path]), ([], []))

    def test_release_records_fingerprint_tag(self):
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')
        captured = self.captured()
        argv = captured['argv']
        self.assertEqual(argv[:5], ['release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                    '--split-debug-info=build/symbols'])
        self.assertEqual(len([arg for arg in argv if arg.startswith('--public-key-path=')]), 1)
        self.assertFalse(any(arg.startswith('--private-key-path=') for arg in argv))
        self.assertEqual(captured['keys'], {'--public-key-path': PUBLIC_PEM + '\n'})
        self.assertEqual(captured['token'], 'sb_api_fixture')
        self.assertIn('--dart-define=PEXELS_API_KEY=pexels-secret-value', argv)
        for arg in argv:
            self.assertNotIn('sb_api_fixture', arg)
            self.assertNotIn('PRIV', arg)

        raw = self.tag_message('shorebird/android/3.14.0+353')
        record = json.loads(raw)
        self.assertEqual(record['release_version'], '3.14.0+353')
        self.assertEqual(record['platform'], 'android')
        self.assertEqual(record['cli_version'], '1.6.133')
        self.assertIs(record['obfuscate'], True)
        self.assertEqual(record['config'], {'flutter_version': '3.47.5', 'split_debug_info': True,
                                            'target': 'lib/main.dart', 'flavor': None})
        self.assertEqual(record['commit'], git(self.work, 'rev-parse', 'HEAD').stdout.strip())
        self.assertIn('PEXELS_API_KEY', record['defines']['names'])
        self.assertEqual(len(record['defines']['sha256']), 64)
        for secret in ('pexels-secret-value', 'PRIV', 'sb_api_fixture'):
            self.assertNotIn(secret, raw)
        marker = (self.work / 'build/shorebird/release-tag-android').read_text()
        self.assertEqual(marker, 'shorebird/android/3.14.0+353\n')

    def test_build_number_changes_the_tag(self):
        self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                         '--split-debug-info=build/symbols', '--build-number=400')
        result = subprocess.run(['git', 'rev-parse', '-q', '--verify', 'refs/tags/shorebird/android/3.14.0+400'],
                                cwd=self.work, capture_output=True)
        self.assertEqual(result.returncode, 0)

    def test_release_refuses_wrong_or_missing_flutter_version(self):
        for flags in (['--flutter-version=3.47.8'], []):
            with self.subTest(flags=flags):
                result = self.run_wrapper('release', 'android', '--obfuscate', '--split-debug-info=build/symbols',
                                          *flags)
                self.assertEqual(result.returncode, 1)
                self.assertIn('--flutter-version=3.47.5', result.stderr)
                self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_placeholder_app_id(self):
        self.commit_file('shorebird.yaml', b'app_id: REPLACE_WITH_SHOREBIRD_APP_ID\nauto_update: false\n')
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('app_id', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_other_cli_version(self):
        self.env['SB_VERSION'] = '1.6.140'
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('1.6.133 is required', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_missing_public_key(self):
        del self.values['SHOREBIRD_PATCH_PUBLIC_KEY']
        self.write_payload()
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('SHOREBIRD_PATCH_PUBLIC_KEY', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_existing_tag(self):
        self.release()
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('already exists', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_platform_mismatch(self):
        self.native('ios')
        result = self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'ios', '--',
                               'shorebird', 'release', 'android', '--flutter-version=3.47.5')
        self.assertEqual(result.returncode, 1)
        self.assertIn('same --release-platform', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_publishes_with_public_and_private_keys_then_removes_them(self):
        self.release()
        self.commit_file('lib/main.dart', b'void main() { print(1); }\n')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        captured = self.captured()
        argv = captured['argv']
        self.assertEqual(argv[:2], ['patch', 'android'])
        public = [arg for arg in argv if arg.startswith('--public-key-path=')]
        private = [arg for arg in argv if arg.startswith('--private-key-path=')]
        self.assertEqual((len(public), len(private)), (1, 1))
        self.assertEqual(captured['keys'], {'--public-key-path': PUBLIC_PEM + '\n',
                                            '--private-key-path': PRIVATE_PEM + '\n'})
        for arg in public + private:
            self.assertFalse(Path(arg.split('=', 1)[1]).exists())

    def test_patch_refusals_that_change_no_files(self):
        self.release()
        cases = (
            ('track stable', ['--release-version=3.14.0+353', '--track=stable', '--split-debug-info=build/symbols'],
             'test track'),
            ('no track', ['--release-version=3.14.0+353', '--split-debug-info=build/symbols'], 'test track'),
            ('latest', ['--release-version=latest', '--track=staging', '--split-debug-info=build/symbols'],
             'not latest'),
            ('no record', ['--release-version=3.9.9+1', '--track=staging', '--split-debug-info=build/symbols'],
             'no release record'),
            ('no split', ['--release-version=3.14.0+353', '--track=staging'], 'split_debug_info'),
            ('native flag', ['--release-version=3.14.0+353', '--track=staging', '--split-debug-info=build/symbols',
                             '--allow-native-diffs'], 'native or asset diffs'),
        )
        for label, args, reason in cases:
            with self.subTest(case=label):
                result = self.run_wrapper('patch', 'android', *args)
                self.assertEqual(result.returncode, 1)
                self.assertIn(reason, result.stderr)
                self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_refuses_changed_dart_defines(self):
        self.release()
        self.values['PEXELS_API_KEY'] = 'changed-value'
        self.write_payload()
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('dart-define names or values', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_refuses_committed_native_change(self):
        self.release()
        self.commit_file('android/app/src/main/AndroidManifest.xml', b'<manifest/>\n')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('android/app/src/main/AndroidManifest.xml', result.stderr)
        self.assertIn('store build', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_refuses_untracked_new_asset(self):
        self.release()
        path = self.work / 'assets/images/new.png'
        path.parent.mkdir(parents=True)
        path.write_bytes(b'png')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('assets/images/new.png', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_storage_change_needs_flag(self):
        self.release()
        self.commit_file('lib/core/persistence/persistence_keys.dart', b'const key = 1;\n')
        patch = ('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                 '--split-debug-info=build/symbols')
        result = self.run_wrapper(*patch)
        self.assertEqual(result.returncode, 1)
        self.assertIn('storage', result.stderr)
        self.assertIn('lib/core/persistence/persistence_keys.dart', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

        result = self.run_wrapper(*patch, extra=('--allow-storage-changes',))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('WARNING', result.stderr)
        self.assertEqual(self.captured()['argv'][:2], ['patch', 'android'])

    def test_patch_reuses_release_sentry_values(self):
        self.env['SENTRY_RELEASE'] = 'Prism@main+7'
        self.env['SENTRY_ENABLED'] = 'true'
        self.release()
        self.env.pop('SENTRY_RELEASE')
        self.env.pop('SENTRY_ENABLED')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--dart-define=SENTRY_RELEASE=Prism@main+7', self.captured()['argv'])


if __name__ == '__main__':
    unittest.main()
