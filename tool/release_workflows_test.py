"""Execute release workflow commands and schedule fixtures from parsed YAML.

Uses Ruby's standard-library YAML parser, available on the hosted runners.
"""

import base64
import fnmatch
import inspect
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import unittest

from tool import release_tools_test as fixture
from tool import shorebird_ota_test as shorebird
import tool.shorebird_ota as ota


def yaml_data(text):
    result = subprocess.run(['ruby', '-rjson', '-ryaml', '-e',
                             'puts JSON.generate(YAML.safe_load(STDIN.read))'],
                            input=text, text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


def workflow(name):
    return yaml_data((fixture.ROOT / '.github/workflows' / name).read_text())


def profile_bytes(bundle_id, name, uuid, team='X2955Z4CKQ'):
    profile = {'Name': name, 'UUID': uuid, 'TeamIdentifier': [team],
               'Entitlements': {'application-identifier': f'{team}.{bundle_id}'}}
    return b'\x30\x82junk' + fixture.plistlib.dumps(profile) + b'\x00trailer'


RELEASE_JOBS = (('testflight.yml', 'build-and-upload'), ('sentry_release_android.yml', 'build_android_with_sentry'))


def scheduled(job, outputs):
    """Evaluate this job's simple changes-output condition without eval."""
    return any(all(outputs[match[0]] == match[1]
                   for match in re.findall(r"needs\.changes\.outputs\.(\w+) == '(true|false)'", term))
               for term in job['if'].split(' || '))


class ReleaseWorkflowsTest(fixture.ReleaseFixture, unittest.TestCase):
    def setUp(self):
        super().setUp()
        (self.work / 'tool').symlink_to(fixture.ROOT / 'tool', target_is_directory=True)

    def test_actual_release_build_steps_preserve_argv(self):
        value = ' spaces "quotes" \'apostrophe\' == \\ $(touch OWNED); & | *'
        shorebird.setup_release_repo(self)
        build_dir = self.work / 'build'
        build_dir.mkdir()
        self.env['CAPTURE'] = str(build_dir / 'capture.json')
        shorebird.git(self.work, 'rm', '--cached', '--ignore-unmatch', 'doppler.json')
        (self.work / '.gitignore').write_text(
            'build/\ndoppler.json\nlib/firebase_options.dart\n'
            'android/app/google-services.json\nios/Runner/GoogleService-Info.plist\n')
        shorebird.git(self.work, 'add', '.gitignore')
        shorebird.git(self.work, 'commit', '-q', '-m', 'ignore generated Doppler fixture')
        self.values['PEXELS_API_KEY'] = value
        self.write_payload()
        runner_temp = self.work / 'runner-temp'
        for name, job_name, platform, build_command in (
            ('testflight.yml', 'build-and-upload', 'ios',
             ['release', 'ios', '--flutter-version=3.47.5', '--build-number=401',
              f'--export-options-plist={runner_temp}/ExportOptions.plist']),
            ('sentry_release_android.yml', 'build_android_with_sentry', 'android',
             ['release', 'android', '--flutter-version=3.47.5', '--obfuscate', '--split-debug-info=build/symbols']),
        ):
            with self.subTest(workflow=name):
                self.native(platform)
                self.env['BUILD_NUMBER'] = '401'
                if platform == 'ios':
                    self.env['RUNNER_TEMP'] = str(runner_temp)
                self.env['SENTRY_RELEASE'] = value
                steps = workflow(name)['jobs'][job_name]['steps']
                build = next(step for step in steps if step.get('name', '').startswith('Build '))
                result = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', build['run'])
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                argv = json.loads(Path(self.env['CAPTURE']).read_text())['argv']
                self.assertTrue(argv[len(build_command)].startswith('--public-key-path='))
                del argv[len(build_command)]
                expected = build_command + ['--dart-define=GH_USERNAME=owner',
                    '--dart-define=R2_PREVIEW_BASE_URL=https://images.example.com',
                    '--dart-define=PEXELS_API_KEY=' + value, '--dart-define=SENTRY_RELEASE=' + value]
                if platform == 'android':
                    expected.append('--dart-define=SENTRY_ENABLED=true')
                self.assertEqual(argv, expected)
                self.assertEqual(result.stdout + result.stderr, '')
                self.assertFalse((self.work / 'OWNED').exists())
                shorebird.delete_release_tags(self)

    def test_release_workflows_install_pinned_shorebird_before_build(self):
        for name, job_name in RELEASE_JOBS:
            with self.subTest(workflow=name):
                steps = workflow(name)['jobs'][job_name]['steps']
                install = next(i for i, step in enumerate(steps) if step.get('name') == 'Install pinned Shorebird CLI')
                build = next(i for i, step in enumerate(steps) if step.get('name', '').startswith('Build '))
                self.assertLess(install, build)
                run = steps[install]['run']
                self.assertIn('tool/shorebird_ota.py cli-version', run)
                self.assertIn('--branch "v$version"', run)

    def test_release_workflows_push_release_record_after_build(self):
        for name, job_name in RELEASE_JOBS:
            with self.subTest(workflow=name):
                job = workflow(name)['jobs'][job_name]
                self.assertEqual(job['permissions']['contents'], 'write')
                names = [step.get('name') for step in job['steps']]
                push = names.index('Push Shorebird release record')
                build = next(i for i, step in enumerate(job['steps']) if (step.get('name') or '').startswith('Build '))
                self.assertLess(build, push)
                if name == 'testflight.yml':
                    self.assertEqual(names[push - 1], 'Check IPA was exported')
                    self.assertLess(push, names.index('Upload to TestFlight (Prism Alpha)'))
                else:
                    self.assertEqual(push, build + 1)

    def test_shorebird_patch_workflow_refuses_stable_and_fetches_history(self):
        patch = workflow('shorebird_patch.yml')
        triggers = patch.get('on', patch.get('true'))
        self.assertNotIn('stable', triggers['workflow_dispatch']['inputs']['track']['options'])
        steps = patch['jobs']['patch']['steps']
        checkout = next(step for step in steps if step.get('uses', '').startswith('actions/checkout'))
        self.assertEqual(checkout['with']['fetch-depth'], 0)
        run = next(step['run'] for step in steps if 'shorebird patch' in step.get('run', ''))
        self.assertIn('--track="$TRACK"', run)

    def test_patch_workflow_replays_testflight_make_and_android_release_configs(self):
        if shutil.which('jq') is None:
            self.skipTest('jq is not installed')

        self.native('ios')
        self.native('android')
        build_dir = self.work / 'build'
        build_dir.mkdir()
        self.env['CAPTURE'] = str(build_dir / 'capture.json')
        shorebird.setup_release_repo(self)
        native_configs = ('android/app/google-services.json', 'ios/Runner/GoogleService-Info.plist')
        shorebird.git(self.work, 'rm', '--cached', '--ignore-unmatch', 'bin/doppler', 'bin/flutter', 'bin/shorebird')
        shorebird.git(self.work, 'rm', '--cached', '--ignore-unmatch', *native_configs)
        (self.work / '.gitignore').write_text(
            'build/\ndoppler.json\nlib/firebase_options.dart\nMakefile\nbin/\n'
            'android/app/google-services.json\nios/Runner/GoogleService-Info.plist\n')
        shorebird.git(self.work, 'add', '.gitignore')
        shorebird.git(self.work, 'commit', '-q', '-m', 'ignore generated Firebase configuration')
        self.executable('doppler', '''#!/usr/bin/env python3
import os, pathlib, sys
if sys.argv[1:3] == ['secrets', 'get']:
    sys.exit(0)
sys.stdout.write(pathlib.Path(os.environ['PAYLOAD']).read_text())
''')
        patch_steps = workflow('shorebird_patch.yml')['jobs']['patch']['steps']
        record_run = next(step['run'] for step in patch_steps
                          if step.get('name') == 'Validate release record and restore build configuration')
        patch_run = next(step['run'] for step in patch_steps if 'shorebird patch' in step.get('run', ''))

        def run_workflow_patch(platform, version):
            self.env.update({'PLATFORM': platform, 'RELEASE_VERSION': version, 'TRACK': 'staging',
                             'GITHUB_OUTPUT': str(build_dir / 'github-output'),
                             'GITHUB_ENV': str(build_dir / 'github-env')})
            for path in ('GITHUB_OUTPUT', 'GITHUB_ENV'):
                Path(self.env[path]).write_text('')
            checked = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', record_run)
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
            outputs = dict(line.split('=', 1) for line in Path(self.env['GITHUB_OUTPUT']).read_text().splitlines())
            self.env.update({'RELEASE_SPLIT_DEBUG_INFO': outputs['split_debug_info'],
                             'RELEASE_TARGET': outputs['target'], 'RELEASE_FLAVOR': outputs['flavor']})
            for line in Path(self.env['GITHUB_ENV']).read_text().splitlines():
                key, value = line.split('=', 1)
                self.env[key] = value
            result = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', patch_run)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return json.loads(Path(self.env['CAPTURE']).read_text())['argv']

        testflight_steps = workflow('testflight.yml')['jobs']['build-and-upload']['steps']
        testflight_build = next(step for step in testflight_steps if step.get('name') == 'Build IPA')
        self.env.update({'BUILD_NUMBER': '401', 'RUNNER_TEMP': str(self.work / 'runner-temp')})
        Path(self.env['RUNNER_TEMP']).mkdir()
        result = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', testflight_build['run'])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.env.update({'SENTRY_ENV': 'ambient', 'SENTRY_RELEASE': 'ambient-release',
                         'SENTRY_DIST': 'ambient-dist', 'SENTRY_ENABLED': 'ambient-enabled'})
        testflight_argv = run_workflow_patch('ios', '3.14.0+401')
        self.assertFalse(any(arg.startswith('--split-debug-info=') for arg in testflight_argv))
        self.assertFalse(any(arg.startswith('--target=') or arg.startswith('--flavor=') for arg in testflight_argv))
        self.assertEqual(Path(self.env['GITHUB_ENV']).read_text().splitlines(),
                         ['SENTRY_ENV=', 'SENTRY_RELEASE=', 'SENTRY_DIST=', 'SENTRY_ENABLED='])

        makefile = (fixture.ROOT / 'Makefile').read_text()
        make_ios_recipe = next(line.strip() for line in makefile.splitlines()
                               if '$(SHOREBIRD) release ios --flutter-version=$(FLUTTER_PIN)' in line)
        make_ios_command = make_ios_recipe.split('-- ', 1)[1].replace('$(SHOREBIRD)', 'shorebird')
        make_ios_command = make_ios_command.replace('$(FLUTTER_PIN)', '3.47.5').replace('$(BUILD_NUMBER)', '402')
        make_ios_command = make_ios_command.replace('$(IOS_BUILD_ARGS)', '--target=lib/main_alt.dart --flavor=qa')
        make_ios_args = shlex.split(make_ios_command)
        self.assertIn('--split-debug-info=build/ios/outputs/symbols', make_ios_args)
        self.env['BUILD_NUMBER'] = '402'
        self.env.update({'SENTRY_ENV': 'staging', 'SENTRY_RELEASE': 'Prism@staging+402',
                         'SENTRY_DIST': '402', 'SENTRY_ENABLED': 'true'})
        result = self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'ios', '--', *make_ios_args)
        self.assertEqual(result.returncode, 0, result.stderr)
        make_ios_argv = run_workflow_patch('ios', '3.14.0+402')
        self.assertIn('--split-debug-info=build/ios/outputs/symbols', make_ios_argv)
        self.assertIn('--target=lib/main_alt.dart', make_ios_argv)
        self.assertIn('--flavor=qa', make_ios_argv)

        android_steps = workflow('sentry_release_android.yml')['jobs']['build_android_with_sentry']['steps']
        android_build = next(step for step in android_steps
                             if step.get('name') == 'Build release AAB with split debug info')
        result = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', android_build['run'])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        android_argv = run_workflow_patch('android', '3.14.0+353')
        self.assertIn('--split-debug-info=build/symbols', android_argv)

        origin = self.work / 'build/origin.git'
        result = subprocess.run(['git', 'clone', '--bare', str(self.work), str(origin)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        shorebird.git(self.work, 'remote', 'add', 'origin', str(origin))
        (self.work / 'Makefile').symlink_to(fixture.ROOT / 'Makefile')
        self.executable('doppler', '''#!/usr/bin/env python3
import os, pathlib, sys
if sys.argv[1:2] == ['me']:
    sys.exit(1)
sys.stdout.write(pathlib.Path(os.environ['PAYLOAD']).read_text())
''')
        self.env['CAPTURE_SENTRY'] = str(build_dir / 'sentry-env.json')
        self.executable('dart', '''#!/usr/bin/env python3
import json, os, pathlib
keys = ('SENTRY_ENV', 'SENTRY_RELEASE', 'SENTRY_DIST', 'SENTRY_ENABLED')
pathlib.Path(os.environ['CAPTURE_SENTRY']).write_text(json.dumps({key: os.environ.get(key) for key in keys}))
''')
        self.env['DOPPLER_TOKEN'] = ''

        def run_make_patch(platform, version, allow_storage='', upload='false'):
            result = self.run_tool('make', '-s', 'patch', f'PLATFORM={platform}', f'RELEASE_VERSION={version}',
                                   'CI=true', 'DOPPLER_REQUIRED=false', f'SENTRY_UPLOAD={upload}',
                                   'ANDROID_JAVA_HOME=', 'GRADLE_USER_HOME_DIR=build/gradle',
                                   'DOPPLER_FLUTTER=python3 tool/flutter_with_doppler.py',
                                   *([f'ALLOW_STORAGE_CHANGES={allow_storage}'] if allow_storage else []))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return json.loads(Path(self.env['CAPTURE']).read_text())['argv']

        self.env.update({'SENTRY_ENV': 'ambient', 'SENTRY_RELEASE': 'ambient-release',
                         'SENTRY_DIST': 'ambient-dist', 'SENTRY_ENABLED': 'ambient-enabled'})
        testflight_make_argv = run_make_patch('ios', '3.14.0+401', upload='true')
        self.assertFalse(any(arg.startswith('--split-debug-info=') for arg in testflight_make_argv))
        sentry_values = json.loads(Path(self.env['CAPTURE_SENTRY']).read_text())
        self.assertEqual(sentry_values, {'SENTRY_ENV': '', 'SENTRY_RELEASE': '', 'SENTRY_DIST': '',
                                         'SENTRY_ENABLED': ''})
        make_ios_make_argv = run_make_patch('ios', '3.14.0+402', upload='true')
        self.assertIn('--split-debug-info=build/ios/outputs/symbols', make_ios_make_argv)
        self.assertIn('--target=lib/main_alt.dart', make_ios_make_argv)
        self.assertIn('--flavor=qa', make_ios_make_argv)
        sentry_values = json.loads(Path(self.env['CAPTURE_SENTRY']).read_text())
        self.assertEqual(sentry_values, {'SENTRY_ENV': 'staging', 'SENTRY_RELEASE': 'Prism@staging+402',
                                         'SENTRY_DIST': '402', 'SENTRY_ENABLED': 'true'})
        android_make_argv = run_make_patch('android', '3.14.0+353')
        self.assertIn('--split-debug-info=build/app/outputs/symbols', android_make_argv)

        storage_file = self.work / 'lib/core/persistence/persistence_keys.dart'
        storage_file.parent.mkdir(parents=True, exist_ok=True)
        storage_file.write_text('const key = 1;\n')
        no_allow = self.run_tool('make', '-s', 'patch', 'PLATFORM=android', 'RELEASE_VERSION=3.14.0+353',
                                 'CI=true', 'DOPPLER_REQUIRED=false', 'SENTRY_UPLOAD=false',
                                 'ANDROID_JAVA_HOME=', 'GRADLE_USER_HOME_DIR=build/gradle',
                                 'DOPPLER_FLUTTER=python3 tool/flutter_with_doppler.py')
        self.assertNotEqual(no_allow.returncode, 0)
        self.assertIn('local storage', no_allow.stderr)
        invalid_allow = self.run_tool('make', '-s', 'patch', 'PLATFORM=android', 'RELEASE_VERSION=3.14.0+353',
                                      'CI=true', 'DOPPLER_REQUIRED=false', 'SENTRY_UPLOAD=false',
                                      'ANDROID_JAVA_HOME=', 'GRADLE_USER_HOME_DIR=build/gradle',
                                      'DOPPLER_FLUTTER=python3 tool/flutter_with_doppler.py',
                                      'ALLOW_STORAGE_CHANGES=0')
        self.assertNotEqual(invalid_allow.returncode, 0)
        self.assertIn('must be empty or 1', invalid_allow.stdout)
        self.assertEqual(run_make_patch('android', '3.14.0+353', '1')[0:2], ['patch', 'android'])

    def test_patch_workflow_validates_release_tag_and_restores_sentry_metadata(self):
        steps = workflow('shorebird_patch.yml')['jobs']['patch']['steps']
        patch_steps = steps
        record_step = next(step for step in steps
                           if step.get('name') == 'Validate release record and restore build configuration')
        run = record_step['run']
        self.assertIn('from tool.shorebird_ota import read_record', run)
        self.assertIn('read_record(sys.argv[1], sys.argv[2])', run)
        self.assertIn('steps.release-record.outputs.split_debug_info', patch_steps[-2]['env']['RELEASE_SPLIT_DEBUG_INFO'])
        self.assertIn('steps.release-record.outputs.target', patch_steps[-2]['env']['RELEASE_TARGET'])
        self.assertIn('steps.release-record.outputs.flavor', patch_steps[-2]['env']['RELEASE_FLAVOR'])
        self.assertIn('for key in SENTRY_ENV SENTRY_RELEASE SENTRY_DIST SENTRY_ENABLED', run)
        self.assertIn('echo "$key=$value" >> "$GITHUB_ENV"', run)

    def test_make_patch_replays_validated_release_config(self):
        makefile = (fixture.ROOT / 'Makefile').read_text()
        patch_recipe = makefile.split('\npatch: ensure-fvm ensure-shorebird doppler-check\n', 1)[1].split(
            '\npatch-list:', 1)[0]
        self.assertIn('python3 tool/shorebird_ota.py make-patch "$(PLATFORM)" "$(RELEASE_VERSION)" "$(TRACK)" '
                      '"$(SHOREBIRD)" "$(DOPPLER_FLUTTER)"', patch_recipe)
        self.assertIn('"$(if $(filter 1,$(ALLOW_STORAGE_CHANGES)),1,0)" "$(PATCH_ARGS)" "$(SENTRY_UPLOAD)" '
                      '"$(SENTRY_DOPPLER_CONFIG)" "$(DART)"', patch_recipe)
        self.assertNotIn('python3 -c', patch_recipe)
        source = inspect.getsource(ota.make_patch)
        self.assertIn('read_record(platform, version)', source)
        self.assertIn("config['split_debug_info']", source)
        self.assertIn("config['target']", source)
        self.assertIn("config['flavor']", source)
        self.assertIn("'--allow-storage-changes'", source)
        self.assertIn("env.update({key: '' for key in SENTRY_RECORDED})", source)

    def test_make_dry_run_skips_tag_push_and_sentry_upload(self):
        self.native('android')
        self.native('ios')
        shorebird.setup_release_repo(self)
        shorebird.git(self.work, 'rm', '--cached', '--ignore-unmatch', 'bin/doppler', 'bin/flutter', 'bin/shorebird')
        (self.work / '.gitignore').write_text(
            'build/\ndoppler.json\nargv.json\nandroid/app/google-services.json\n'
            'ios/Runner/GoogleService-Info.plist\nlib/firebase_options.dart\nMakefile\nbin/\n')
        shorebird.git(self.work, 'add', '.gitignore')
        shorebird.git(self.work, 'commit', '-q', '-m', 'ignore generated test fixtures')
        (self.work / 'Makefile').symlink_to(fixture.ROOT / 'Makefile')
        build_dir = self.work / 'build'
        build_dir.mkdir(exist_ok=True)
        self.env['CAPTURE'] = str(build_dir / 'capture.json')
        self.env['CAPTURE_SENTRY'] = str(build_dir / 'sentry-env.json')
        self.executable('doppler', '''#!/usr/bin/env python3
import os, pathlib, sys
if sys.argv[1:2] == ['me']:
    sys.exit(1)
sys.stdout.write(pathlib.Path(os.environ['PAYLOAD']).read_text())
''')
        self.executable('dart', '''#!/usr/bin/env python3
import os, pathlib
pathlib.Path(os.environ['CAPTURE_SENTRY']).write_text('uploaded')
''')
        self.env['DOPPLER_TOKEN'] = ''

        def make(target, *arguments):
            return self.run_tool('make', '-s', target, 'CI=true', 'DOPPLER_REQUIRED=false',
                                 'SENTRY_UPLOAD=true', 'ANDROID_JAVA_HOME=',
                                 'GRADLE_USER_HOME_DIR=build/gradle', *arguments)

        stale_android = build_dir / 'shorebird/release-tag-android'
        stale_ios = build_dir / 'shorebird/release-tag-ios'
        stale_android.parent.mkdir(parents=True, exist_ok=True)
        stale_android.write_text('shorebird/android/stale+1\n')
        stale_ios.write_text('shorebird/ios/stale+1\n')
        android = make('release-android', 'BUILD_ARGS=--dry-run')
        self.assertEqual(android.returncode, 0, android.stdout + android.stderr)
        self.assertEqual(stale_android.read_text(), 'shorebird/android/stale+1\n')
        self.assertFalse(Path(self.env['CAPTURE_SENTRY']).exists())

        ios = make('release-ios', 'BUILD_NUMBER=354', 'IOS_BUILD_ARGS=--dry-run')
        self.assertEqual(ios.returncode, 0, ios.stdout + ios.stderr)
        self.assertEqual(stale_ios.read_text(), 'shorebird/ios/stale+1\n')
        self.assertFalse(Path(self.env['CAPTURE_SENTRY']).exists())
        tags = shorebird.git(self.work, 'tag', '-l', 'shorebird/*').stdout
        self.assertEqual(tags.strip(), '')

        release = self.run_tool('python3', str(fixture.RUNNER), '--release-platform', 'android', '--',
                                'shorebird', 'release', 'android', '--flutter-version=3.47.5', '--obfuscate',
                                '--split-debug-info=build/app/outputs/symbols')
        self.assertEqual(release.returncode, 0, release.stderr)
        origin = build_dir / 'origin.git'
        cloned = subprocess.run(['git', 'clone', '--bare', str(self.work), str(origin)],
                                capture_output=True, text=True)
        self.assertEqual(cloned.returncode, 0, cloned.stderr)
        shorebird.git(self.work, 'remote', 'add', 'origin', str(origin))
        patch = make('patch', 'PLATFORM=android', 'RELEASE_VERSION=3.14.0+353', 'PATCH_ARGS=--dry-run')
        self.assertEqual(patch.returncode, 0, patch.stdout + patch.stderr)
        self.assertFalse(Path(self.env['CAPTURE_SENTRY']).exists())

    def test_make_release_stops_before_tag_push_when_sentry_upload_fails(self):
        self.native('android')
        self.native('ios')
        shorebird.setup_release_repo(self)
        shorebird.git(self.work, 'rm', '--cached', '--ignore-unmatch', 'bin/doppler', 'bin/flutter', 'bin/shorebird')
        (self.work / '.gitignore').write_text(
            'build/\ndoppler.json\nargv.json\nandroid/app/google-services.json\n'
            'ios/Runner/GoogleService-Info.plist\nlib/firebase_options.dart\nMakefile\nbin/\n')
        shorebird.git(self.work, 'add', '.gitignore')
        shorebird.git(self.work, 'commit', '-q', '-m', 'ignore generated test fixtures')
        (self.work / 'Makefile').symlink_to(fixture.ROOT / 'Makefile')

        origin = self.work / 'build/origin.git'
        origin.parent.mkdir(parents=True, exist_ok=True)
        cloned = subprocess.run(['git', 'clone', '--bare', str(self.work), str(origin)],
                                capture_output=True, text=True)
        self.assertEqual(cloned.returncode, 0, cloned.stderr)
        shorebird.git(self.work, 'remote', 'add', 'origin', str(origin))

        self.executable('doppler', '''#!/usr/bin/env python3
import os, pathlib, sys
if sys.argv[1:2] == ['me']:
    sys.exit(1)
if sys.argv[1:3] == ['secrets', 'get']:
    sys.stdout.write('fixture-secret')
else:
    sys.stdout.write(pathlib.Path(os.environ['PAYLOAD']).read_text())
''')
        self.executable('dart', '''#!/usr/bin/env python3
import sys
sys.exit(23)
''')
        self.env['DOPPLER_TOKEN'] = ''

        def make_release(target, *arguments):
            result = self.run_tool('make', '-s', target, 'CI=true', 'DOPPLER_REQUIRED=false',
                                   'SENTRY_UPLOAD=true', 'ANDROID_JAVA_HOME=',
                                   'GRADLE_USER_HOME_DIR=build/gradle', *arguments)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Uploading debug symbols', result.stdout + result.stderr)
            return result

        make_release('release-android')
        make_release('release-ios', 'BUILD_NUMBER=354')
        for tag in ('shorebird/android/3.14.0+353', 'shorebird/ios/3.14.0+354'):
            remote = subprocess.run(['git', '--git-dir', str(origin), 'show-ref', '--verify', '--quiet',
                                     f'refs/tags/{tag}'], capture_output=True)
            self.assertNotEqual(remote.returncode, 0, f'{tag} was pushed after Sentry upload failed')

    def test_testflight_installs_and_cleans_every_profile(self):
        if shutil.which('jq') is None:
            self.skipTest('jq is not installed')
        steps = workflow('testflight.yml')['jobs']['build-and-upload']['steps']
        install = next(step for step in steps if step.get('name') == 'Install provisioning profiles')
        cleanup = next(step for step in steps if step.get('name') == 'Cleanup keychain & keys')
        self.assertLessEqual({'IOS_PROVISIONING_PROFILE_BASE64', 'IOS_LIVE_ACTIVITIES_PROVISIONING_PROFILE_BASE64'},
                             set(install['env']))
        for name, value in install['env'].items():
            self.assertTrue(name.endswith('PROVISIONING_PROFILE_BASE64'), name)
            self.assertEqual(value, '${{ secrets.' + name + ' }}')
        for name in list(self.env):
            if name.endswith('PROVISIONING_PROFILE_BASE64'):
                self.env.pop(name)
        app_uuid, live_uuid, widget_uuid = 'A1B2C3D4-0001', 'A1B2C3D4-0002', 'A1B2C3D4-0003'
        self.env['IOS_WIDGETS_PROVISIONING_PROFILE_BASE64'] = base64.b64encode(
            profile_bytes('com.hash.prism.Widgets', 'Prism Widgets', widget_uuid)).decode()
        self.env['IOS_PROVISIONING_PROFILE_BASE64'] = base64.b64encode(
            profile_bytes('com.hash.prism', 'Prism App Store', app_uuid)).decode()
        self.env['IOS_LIVE_ACTIVITIES_PROVISIONING_PROFILE_BASE64'] = base64.b64encode(
            profile_bytes('com.hash.prism.LiveActivities', 'Prism Live Activities', live_uuid)).decode()
        self.env['HOME'] = str(self.work / 'home')
        runner_temp = self.work / 'runner-temp'
        runner_temp.mkdir()
        self.env['RUNNER_TEMP'] = str(runner_temp)

        result = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', install['run'])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list((self.work / 'home/Library').rglob('*.mobileprovision'))), 6)
        export = fixture.plistlib.loads((runner_temp / 'ExportOptions.plist').read_bytes())
        self.assertEqual(export['provisioningProfiles'],
                         {'com.hash.prism': app_uuid, 'com.hash.prism.LiveActivities': live_uuid,
                          'com.hash.prism.Widgets': widget_uuid})

        result = self.run_tool('bash', '-e', '-o', 'pipefail', '-c', cleanup['run'])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(list((self.work / 'home/Library').rglob('*.mobileprovision')), [])
        self.assertFalse((runner_temp / 'provisioning-profiles.json').exists())
        self.assertFalse((runner_temp / 'ExportOptions.plist').exists())

    def test_testflight_stops_when_flutter_exported_no_ipa(self):
        steps = workflow('testflight.yml')['jobs']['build-and-upload']['steps']
        names = [step.get('name') for step in steps]
        check_index = names.index('Check IPA was exported')
        self.assertEqual(names[check_index - 1], 'Build IPA')
        self.assertLess(check_index, names.index('Upload to TestFlight (Prism Alpha)'))
        command = steps[check_index]['run']
        result = self.run_tool('bash', '-e', '-c', command)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('did not export', result.stdout)
        ipa = self.work / 'build/ios/ipa/Prism.ipa'
        ipa.parent.mkdir(parents=True)
        ipa.write_bytes(b'')
        self.assertNotEqual(self.run_tool('bash', '-e', '-c', command).returncode, 0)
        ipa.write_bytes(b'PK')
        result = self.run_tool('bash', '-e', '-c', command)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_testflight_does_not_rewrite_the_removed_png_app_icon(self):
        steps = workflow('testflight.yml')['jobs']['build-and-upload']['steps']
        run_bodies = '\n'.join(step.get('run', '') for step in steps)
        self.assertNotIn('AppIcon.appiconset', run_bodies)
        self.assertNotIn('ffmpeg', run_bodies)

    def test_ios_preparation_fails_before_signing_and_build(self):
        steps = workflow('testflight.yml')['jobs']['build-and-upload']['steps']
        preparation_index = next(i for i, step in enumerate(steps)
                                 if step.get('name') == 'Prepare real iOS Firebase configuration')
        signing_index = next(i for i, step in enumerate(steps) if step.get('name') == 'Import signing certificate')
        self.assertLess(preparation_index, signing_index)
        result = self.run_tool('bash', '-e', '-c', steps[preparation_index]['run'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('IOS_GOOGLE_SERVICE_INFO_PLIST', result.stderr)
        self.assertFalse(Path(self.env['CAPTURE']).exists())

    def test_actual_workflow_preparation_generates_matching_platform_options(self):
        cases = (
            ('testflight.yml', 'build-and-upload', 'Prepare real iOS Firebase configuration', 'ios'),
            ('sentry_release_android.yml', 'build_android_with_sentry',
             'Prepare real Android Firebase configuration', 'android'),
        )
        for name, job_name, step_name, platform in cases:
            with self.subTest(workflow=name):
                config = fixture.ios_config() if platform == 'ios' else fixture.android_config()
                if platform == 'ios':
                    self.env['IOS_GOOGLE_SERVICE_INFO_PLIST'] = fixture.plistlib.dumps(config).decode()
                else:
                    Path(self.env['PAYLOAD']).write_text(json.dumps(config))
                steps = workflow(name)['jobs'][job_name]['steps']
                command = next(step['run'] for step in steps if step.get('name') == step_name)
                result = self.run_tool('bash', '-e', '-c', command)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                native_path = ('ios/Runner/GoogleService-Info.plist' if platform == 'ios'
                               else 'android/app/google-services.json')
                native = Path(self.work / native_path)
                actual = fixture.plistlib.loads(native.read_bytes()) if platform == 'ios' else json.loads(native.read_text())
                self.assertEqual(actual, config)
                options = (self.work / 'lib/firebase_options.dart').read_text()
                enum = 'iOS' if platform == 'ios' else 'android'
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

    def test_function_only_paths_schedule_actual_notification_contract(self):
        ci = workflow('ci.yml')
        filters = yaml_data(ci['jobs']['changes']['steps'][0]['with']['filters'])
        job = ci['jobs']['notification_contract']
        scenarios = {
            'functions/src/notifications.ts': True,
            'functions/src/newNotification.ts': True,
            'functions/src/__tests__/other.test.ts': False,
            'functions/package.json': False,
            'web/app/page.tsx': False,
            'lib/core/startup/notification_channels.dart': True,
            'test/core/startup/notification_channels_test.dart': True,
            '.github/workflows/ci.yml': True,
        }
        for changed, expected in scenarios.items():
            # These two filters contain positive single-segment globs only.
            outputs = {key: str(any(len(changed.split('/')) == len(pattern.split('/'))
                                    and fnmatch.fnmatchcase(changed, pattern)
                                    for pattern in filters[key])).lower()
                       for key in ('notification_contract', 'workflow')}
            self.assertEqual(scheduled(job, outputs), expected, changed)
        command = next(step['run'] for step in job['steps'] if step.get('name') == 'Check notification-channel contract')
        self.assertEqual(command.split(), ['flutter', 'test', 'test/core/startup/notification_channels_test.dart'])
        self.assertIn('notification_contract', ci['jobs']['ci']['needs'])
        # This must be an aggregate input, so a failing contract cannot merge.
        aggregate = ci['jobs']['ci']['steps'][0]['env']['RESULTS'].split()
        self.assertIn('needs.notification_contract.result', aggregate)


if __name__ == '__main__':
    unittest.main()
