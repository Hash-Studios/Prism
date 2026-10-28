"""Shorebird release records, patch refusals and the pinned CLI, run through tool/flutter_with_doppler.py.

A fake `shorebird` executable records its argv, token and key files. No network, credentials or builds.
"""

import json
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time
import unittest
from unittest.mock import patch

from tool import release_tools_test as fixture
import tool.shorebird_ota as ota


PUBLIC_PEM = '-----BEGIN PUBLIC KEY-----\nPUB\n-----END PUBLIC KEY-----'
PRIVATE_PEM = '-----BEGIN PRIVATE KEY-----\nPRIV\n-----END PRIVATE KEY-----'
FAKE_SHOREBIRD = '''#!/usr/bin/env python3
import json, os, sys, time
if sys.argv[1:] == ['--version']:
    print('Shorebird ' + os.environ.get('SB_VERSION', '1.6.133') + ' \\u2022 git@github.com:shorebirdtech/shorebird.git')
    sys.exit(0)
keys = {}
modes = {}
for arg in sys.argv[1:]:
    for flag in ('--public-key-path', '--private-key-path'):
        if arg.startswith(flag + '='):
            path = arg.split('=', 1)[1]
            modes[flag] = os.stat(path).st_mode & 0o777
            with open(path) as key:
                keys[flag] = key.read()
with open(os.environ['CAPTURE'], 'w') as capture:
    json.dump({'argv': sys.argv[1:], 'token': os.environ.get('SHOREBIRD_TOKEN'), 'keys': keys,
               'modes': modes}, capture)
if os.environ.get('SHOREBIRD_WAIT'):
    time.sleep(60)
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
    (work / '.gitignore').write_text('build/\ndoppler.json\nargv.json\nandroid/app/google-services.json\n'
                                      'ios/Runner/GoogleService-Info.plist\nlib/firebase_options.dart\n')
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
                  'shorebird.yaml', '.fvmrc', 'shaders/a.frag', 'lib/firebase_options.dart']
        storage = ['lib/core/persistence/persistence_keys.dart', 'lib/core/offline/durable_json_store.dart',
                   'lib/features/folders/data/folder_store.dart',
                   'lib/core/persistence/data_sources/settings_local_data_source.dart', 'lib/main.dart']
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

    def test_unsafe_paths_cover_persistent_writers_and_renames(self):
        storage = [
            'lib/core/account/local_account_data_cleaner.dart',
            'lib/core/coins/coins_service.dart',
            'lib/core/coins/pending_download.dart',
            'lib/core/platform/quick_tile_config_service.dart',
            'lib/core/purchases/paywall_orchestrator.dart',
            'lib/core/purchases/upload_quota.dart',
            'lib/core/updates/ota_update_controller.dart',
            'lib/core/wallpaper/original_access_service.dart',
            'lib/notifications/fcm_token_service.dart',
            'lib/notifications/topic_subscription.dart',
            'lib/notifications/notification_signals.dart',
            'lib/features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart',
            'lib/features/onboarding_v2/src/common/onboarding_v2_keys.dart',
            'lib/features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart',
            'lib/features/theme_mode/data/legacy_themes.dart',
            'lib/features/theme_mode/data/seasonal_announcement.dart',
            'lib/features/startup/data/repositories/startup_repository_impl.dart',
            'lib/features/startup/services/notification_permission_prompt_service.dart',
            'lib/features/theme_mode/data/repositories/theme_repository_impl.dart',
            'lib/features/quick_tiles/data/quick_tile_defaults.dart',
            'lib/features/quick_tiles/views/quick_tile_settings_screen.dart',
            'lib/features/session/views/pages/settings_screen.dart',
        ]
        for path in storage:
            with self.subTest(storage=path):
                self.assertEqual(ota.unsafe_paths([path]), ([], [path]))

    def test_changed_paths_reports_both_sides_of_renames_and_staged_changes(self):
        source = self.work / 'android/native.txt'
        source.write_text('native input\n')
        deleted = self.work / 'ios/native.txt'
        deleted.parent.mkdir(parents=True, exist_ok=True)
        deleted.write_text('native input to delete\n')
        git(self.work, 'add', 'android/native.txt')
        git(self.work, 'add', 'ios/native.txt')
        git(self.work, 'commit', '-q', '-m', 'add native input')
        base = git(self.work, 'rev-parse', 'HEAD').stdout.strip()
        source.rename(self.work / 'lib/moved_native.txt')
        git(self.work, 'add', '-A')
        deleted.unlink()
        untracked = self.work / 'android/untracked.txt'
        untracked.write_text('untracked native input\n')

        def fixture_git(*args, **kwargs):
            result = subprocess.run(['git', '-C', str(self.work), *args], capture_output=True, text=True)
            if kwargs.get('check') is not False and result.returncode:
                raise ValueError(result.stderr)
            return result

        with patch.object(ota, 'git', side_effect=fixture_git):
            changed = ota.changed_paths(base)
        self.assertIn('android/native.txt', changed)
        self.assertIn('ios/native.txt', changed)
        self.assertIn('android/untracked.txt', changed)
        self.assertIn('lib/moved_native.txt', changed)

    def test_changed_paths_rejects_missing_release_commit(self):
        def fixture_git(*args, **kwargs):
            result = subprocess.run(['git', '-C', str(self.work), *args], capture_output=True, text=True)
            if kwargs.get('check') is not False and result.returncode:
                raise ValueError(result.stderr)
            return result

        with patch.object(ota, 'git', side_effect=fixture_git):
            with self.assertRaisesRegex(ValueError, 'not in this clone'):
                ota.changed_paths('f' * 40)

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
        self.assertEqual(record['schema'], 2)
        self.assertEqual(record['release_version'], '3.14.0+353')
        self.assertEqual(record['platform'], 'android')
        self.assertEqual(record['cli_version'], '1.6.133')
        self.assertIs(record['obfuscate'], True)
        self.assertEqual(record['config'], {'flutter_version': '3.47.5', 'split_debug_info': True,
                                            'target': 'lib/main.dart', 'flavor': None, 'target_platform': None})
        self.assertEqual(record['commit'], git(self.work, 'rev-parse', 'HEAD').stdout.strip())
        self.assertIn('PEXELS_API_KEY', record['defines']['names'])
        self.assertEqual(len(record['defines']['sha256']), 64)
        for secret in ('pexels-secret-value', 'PRIV', 'sb_api_fixture'):
            self.assertNotIn(secret, raw)
        marker = (self.work / 'build/shorebird/release-tag-android').read_text()
        self.assertEqual(marker, 'shorebird/android/3.14.0+353\n')

    def test_release_records_effective_sentry_defines_from_doppler(self):
        self.values.update({'SENTRY_ENV': 'production', 'SENTRY_RELEASE': 'Prism@main+7'})
        self.write_payload()
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        record = json.loads(self.tag_message('shorebird/android/3.14.0+353'))
        self.assertEqual(record['sentry'], {'SENTRY_ENV': 'production', 'SENTRY_RELEASE': 'Prism@main+7'})

    def test_release_dry_run_does_not_create_record_or_marker(self):
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols', '--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(git(self.work, 'tag', '-l', 'shorebird/android/*').stdout.strip(), '')
        self.assertFalse((self.work / 'build/shorebird/release-tag-android').exists())

    def test_release_refuses_dirty_build_inputs_except_ci_manual_signing_only_diff(self):
        (self.work / 'lib/main.dart').write_text('void main() { print("dirty"); }\n')
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('working tree', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

        (self.work / 'lib/main.dart').write_text('void main() { }\n')
        git(self.work, 'add', 'lib/main.dart')
        git(self.work, 'commit', '-q', '-m', 'change base Dart input')
        probe = subprocess.run(['ruby', '-e', 'require "xcodeproj"'], capture_output=True)
        if probe.returncode:
            self.skipTest('Ruby xcodeproj gem is not installed.')
        project = self.work / 'ios/Runner.xcodeproj'
        shutil.copytree(fixture.ROOT / 'ios/Runner.xcodeproj', project)
        pbxproj = project / 'project.pbxproj'
        bundles = sorted(set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', pbxproj.read_text())))
        manifest = self.work / 'profile_manifest.json'
        manifest.write_text(json.dumps({'profiles': [{'bundle_id': bundle, 'team_id': 'TESTTEAM',
                                                      'name': 'Fixture Profile'} for bundle in bundles]}))
        git(self.work, 'add', 'ios/Runner.xcodeproj')
        git(self.work, 'commit', '-q', '-m', 'add xcode project fixture')
        signed = subprocess.run(['ruby', str(fixture.ROOT / 'tool/ios_ci_manual_signing.rb'), str(project), str(manifest)],
                                cwd=self.work, capture_output=True, text=True)
        manifest.unlink()
        self.assertEqual(signed.returncode, 0, signed.stderr)
        self.native('ios')
        signed_project = pbxproj.read_bytes()
        pbxproj.write_bytes(signed_project + b'\nPRODUCT_BUNDLE_IDENTIFIER = unrelated.change;\n')
        result = self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'ios', '--', 'shorebird',
                               'release', 'ios', '--flutter-version=3.47.5', '--obfuscate',
                               '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('working tree', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())
        pbxproj.write_bytes(signed_project)
        result = self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'ios', '--', 'shorebird',
                               'release', 'ios', '--flutter-version=3.47.5', '--obfuscate',
                               '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)

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

    def test_release_rejects_caller_defines_and_signing_overrides(self):
        for extra in (('--dart-define=EXTRA=value',), ('--dart-define-from-file=extra.json',),
                      ('--public-key-path=other.pem',), ('--private-key-path=other.pem',),
                      ('--public-key-cmd=echo',), ('--sign-cmd=echo',)):
            with self.subTest(extra=extra):
                result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', *extra)
                self.assertEqual(result.returncode, 1)
                self.assertTrue('wrapper-managed' in result.stderr or 'forbidden' in result.stderr,
                                result.stderr)
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

    def test_release_rejects_control_characters_in_selected_tokens_without_logging_them(self):
        for source in ('payload', 'environment'):
            with self.subTest(source=source):
                self.values['SHOREBIRD_TOKEN'] = 'sb_api_hidden\nforged'
                self.write_payload()
                self.env.pop('SHOREBIRD_TOKEN', None)
                if source == 'environment':
                    self.values['SHOREBIRD_TOKEN'] = 'sb_api_valid'
                    self.write_payload()
                    self.env['SHOREBIRD_TOKEN'] = 'sb_api_environment\tinvalid'
                result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5')
                self.assertEqual(result.returncode, 1)
                self.assertIn('invalid SHOREBIRD_TOKEN', result.stderr)
                self.assertNotIn('sb_api_', result.stdout + result.stderr)
                self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_existing_tag(self):
        self.release()
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('already exists', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_release_refuses_duplicate_flutter_version(self):
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--flutter-version=3.47.5')
        self.assertEqual(result.returncode, 1)
        self.assertIn('duplicate option --flutter-version', result.stderr)
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
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(1); }\n')
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
        self.assertEqual(captured['modes'], {'--public-key-path': 0o600, '--private-key-path': 0o600})
        for arg in public + private:
            self.assertFalse(Path(arg.split('=', 1)[1]).exists())

    def test_patch_cleans_key_files_when_cli_fails(self):
        self.release()
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(2); }\n')
        self.env['SHOREBIRD_EXIT'] = '19'
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 19)
        captured = self.captured()
        for arg in captured['argv']:
            if arg.startswith(('--public-key-path=', '--private-key-path=')):
                self.assertFalse(Path(arg.split('=', 1)[1]).exists())

    def test_patch_cleans_key_files_when_wrapper_receives_sigterm(self):
        self.release()
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(7); }\n')
        self.env['SHOREBIRD_WAIT'] = '1'
        command = ['python3', str(fixture.RUNNER), '--release-platform', 'android', '--', 'shorebird', 'patch',
                   'android', '--release-version=3.14.0+353', '--track=staging',
                   '--split-debug-info=build/symbols']
        process = subprocess.Popen(command, cwd=self.work, env=self.env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 10
            while not Path(self.env['CAPTURE']).exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(Path(self.env['CAPTURE']).exists(), 'fake Shorebird did not reach its wait point')
            captured = self.captured()
            key_paths = [arg.split('=', 1)[1] for arg in captured['argv']
                         if arg.startswith(('--public-key-path=', '--private-key-path='))]
            process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 128 + signal.SIGTERM, (stdout, stderr))
            for path in key_paths:
                self.assertFalse(Path(path).exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate(timeout=10)

    def test_patch_cleans_public_key_when_private_key_is_invalid(self):
        self.release()
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(5); }\n')
        del self.values['SHOREBIRD_PATCH_PRIVATE_KEY']
        self.write_payload()
        temp_root = self.work / 'temp'
        temp_root.mkdir()
        self.env['TMPDIR'] = str(temp_root)
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('SHOREBIRD_PATCH_PRIVATE_KEY', result.stderr)
        self.assertEqual(list(temp_root.iterdir()), [])

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

    def test_patch_refuses_duplicate_or_unsupported_options(self):
        self.release()
        base = ('patch', 'android', '--release-version=3.14.0+353', '--split-debug-info=build/symbols')
        cases = (
            (('--track=staging', '--track=stable'), 'duplicate'),
            (('--track=staging', '--channel=stable'), 'duplicate'),
            (('--track=staging', '--release-version=latest'), 'duplicate'),
            (('--track=staging', '--flutter-version=3.47.5'), 'not supported by the pinned patch CLI'),
            (('--track=staging', '--obfuscate'), 'release-managed'),
            (('--track=staging', '--', '--track=stable'), 'separator'),
            (('--track=staging', 'lib/other.dart'), 'unsupported positional argument'),
            (('--track=staging', '--platforms=ios'), 'unsupported patch option'),
            (('--track=staging', '-p', 'ios'), 'unsupported patch option'),
            (('--track=staging', '--allow-native-diffs=true'), 'native or asset diffs'),
        )
        for extra, reason in cases:
            with self.subTest(extra=extra):
                result = self.run_wrapper(*(base + extra))
                self.assertEqual(result.returncode, 1)
                self.assertIn(reason, result.stderr)
                self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_validates_hidden_channel_alias_and_rejects_stable(self):
        self.release()
        args = ('patch', 'android', '--release-version=3.14.0+353', '--channel=stable',
                '--split-debug-info=build/symbols')
        result = self.run_wrapper(*args)
        self.assertEqual(result.returncode, 1)
        self.assertIn('test track', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--channel=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--channel=staging', self.captured()['argv'])

    def test_patch_rejects_caller_defines_and_signing_overrides(self):
        self.release()
        base = ('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                '--split-debug-info=build/symbols')
        for extra in (('--dart-define=EXTRA=one',), ('--dart-define-from-file=other.json',),
                      ('--public-key-path=custom.pem',), ('--private-key-path=custom.pem',),
                      ('--public-key-cmd=echo',), ('--sign-cmd=echo',)):
            with self.subTest(extra=extra):
                result = self.run_wrapper(*(base + extra))
                self.assertEqual(result.returncode, 1)
                self.assertTrue('wrapper-managed' in result.stderr or 'forbidden' in result.stderr,
                                result.stderr)
                self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_rejects_target_platform_override_not_supported_by_cli(self):
        self.release()
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols', '--target-platform=android-arm64')
        self.assertEqual(result.returncode, 1)
        self.assertIn('release-managed', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_wrapper_rejects_global_options_before_guarded_action(self):
        self.release()
        result = self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'android', '--', 'shorebird',
                               '--verbose', 'patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                               '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('global CLI options', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_inherits_release_target_platform(self):
        result = self.run_wrapper('release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                  '--split-debug-info=build/symbols', '--target-platform=android-arm64')
        self.assertEqual(result.returncode, 0, result.stderr)
        Path(self.env['CAPTURE']).unlink()
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(4); }\n')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_patch_refuses_changed_ignored_firebase_inputs(self):
        self.release()
        config = self.work / 'android/app/google-services.json'
        config.write_bytes(config.read_bytes() + b' ')
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(3); }\n')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Firebase options differ', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_rejects_forged_or_mismatched_release_records(self):
        self.release()
        self.commit_file('android/app/src/main/AndroidManifest.xml', b'<manifest/>\n')
        record = json.loads(self.tag_message('shorebird/android/3.14.0+353'))
        mismatched_commit = git(self.work, 'rev-parse', 'HEAD').stdout.strip()
        git(self.work, 'tag', '-fa', 'shorebird/android/3.14.0+353', '-m', json.dumps(record), 'HEAD')
        self.assertNotEqual(mismatched_commit, record['commit'])
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('record commit', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_rejects_untrusted_sentry_record_keys(self):
        self.release()
        record = json.loads(self.tag_message('shorebird/android/3.14.0+353'))
        record['sentry'] = {'DOPPLER_TOKEN': 'not-a-real-token'}
        git(self.work, 'tag', '-fa', 'shorebird/android/3.14.0+353', '-m', json.dumps(record), 'HEAD')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('invalid release record', result.stderr)
        self.assertNotIn('not-a-real-token', result.stdout + result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_rejects_lightweight_tag_and_malformed_annotated_record(self):
        self.release()
        tag = 'shorebird/android/3.14.0+353'
        git(self.work, 'tag', '-d', tag)
        git(self.work, 'tag', tag, 'HEAD')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('not an annotated release record', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

        git(self.work, 'tag', '-d', tag)
        git(self.work, 'tag', '-a', tag, '-m', 'not json', 'HEAD')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('not a release record', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_patch_rejects_release_commit_not_ancestor_of_checkout(self):
        self.release()
        git(self.work, 'checkout', '--orphan', 'unrelated')
        git(self.work, 'commit', '--allow-empty', '-q', '-m', 'unrelated root')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('not an ancestor', result.stderr)
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

    def test_patch_refuses_untracked_native_file(self):
        self.release()
        path = self.work / 'android/app/src/main/kotlin/NewPlugin.kt'
        path.parent.mkdir(parents=True)
        path.write_text('class NewPlugin {}\n')
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 1)
        self.assertIn('NewPlugin.kt', result.stderr)
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

    def test_patch_does_not_add_sentry_overrides_absent_from_release(self):
        self.release()
        self.commit_file('lib/features/home/views/home.dart', b'void main() { print(6); }\n')
        self.env['SENTRY_RELEASE'] = 'ambient-not-from-release'
        result = self.run_wrapper('patch', 'android', '--release-version=3.14.0+353', '--track=staging',
                                  '--split-debug-info=build/symbols')
        self.assertEqual(result.returncode, 0, result.stderr)
        argv = self.captured()['argv']
        self.assertFalse(any(arg.startswith('--dart-define=SENTRY_RELEASE=') for arg in argv))


if __name__ == '__main__':
    unittest.main()
