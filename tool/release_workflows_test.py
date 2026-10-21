"""Execute release workflow commands and schedule fixtures from parsed YAML.

Uses Ruby's standard-library YAML parser, available on the hosted runners.
"""

import fnmatch
import json
from pathlib import Path
import re
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
        for name, job_name, platform, build_command in (
            ('testflight.yml', 'build-and-upload', 'ios', ['build', 'ipa', '--release', '--build-number=401']),
            ('sentry_release_android.yml', 'build_android_with_sentry', 'android',
             ['build', 'appbundle', '--release', '--obfuscate', '--split-debug-info=build/symbols']),
        ):
            with self.subTest(workflow=name):
                self.native(platform)
                self.env['BUILD_NUMBER'] = '401'
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
