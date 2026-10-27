"""Execute release workflow commands and schedule fixtures from parsed YAML.

Uses Ruby's standard-library YAML parser, available on the hosted runners.
"""

import base64
import fnmatch
import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

from tool import release_tools_test as fixture


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
        self.values['PEXELS_API_KEY'] = value
        self.write_payload()
        runner_temp = self.work / 'runner-temp'
        for name, job_name, platform, build_command in (
            ('testflight.yml', 'build-and-upload', 'ios',
             ['build', 'ipa', '--release', '--build-number=401',
              f'--export-options-plist={runner_temp}/ExportOptions.plist']),
            ('sentry_release_android.yml', 'build_android_with_sentry', 'android',
             ['build', 'appbundle', '--release', '--obfuscate', '--split-debug-info=build/symbols']),
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
                argv = json.loads(Path(self.env['CAPTURE']).read_text())
                expected = build_command + ['--dart-define=GH_USERNAME=owner',
                    '--dart-define=R2_PREVIEW_BASE_URL=https://images.example.com',
                    '--dart-define=PEXELS_API_KEY=' + value, '--dart-define=SENTRY_RELEASE=' + value]
                if platform == 'android':
                    expected.append('--dart-define=SENTRY_ENABLED=true')
                self.assertEqual(argv, expected)
                self.assertEqual(result.stdout + result.stderr, '')
                self.assertFalse((self.work / 'OWNED').exists())

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
