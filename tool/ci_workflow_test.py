"""Exercise CI selection, aggregation, and the actual Make test commands."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from tool.release_workflows_test import scheduled, workflow, yaml_data


ROOT = Path(__file__).resolve().parents[1]


def matches(path, patterns):
    def glob(pattern):
        expression = re.escape(pattern).replace(r'\*\*/', '(?:.*/)?').replace(r'\*\*', '.*')
        return re.fullmatch(expression.replace(r'\*', '[^/]*'), path) is not None

    return (any(glob(pattern) for pattern in patterns if not pattern.startswith('!'))
            and not any(glob(pattern[1:]) for pattern in patterns if pattern.startswith('!')))


class CiWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ci = workflow('ci.yml')
        cls.jobs = cls.ci['jobs']
        cls.filters = yaml_data(cls.jobs['changes']['steps'][0]['with']['filters'])

    def outputs(self, path):
        return {name: str(matches(path, patterns)).lower() for name, patterns in self.filters.items()}

    def test_non_app_changes_do_not_schedule_flutter_suite(self):
        for path in ('docs/development/example.md', 'web/app/page.tsx', 'functions/src/index.ts',
                     'firestore.rules', 'metadata/en-US/full_description.txt'):
            with self.subTest(path=path):
                self.assertFalse(scheduled(self.jobs['flutter_tests'], self.outputs(path)))
        for path in ('lib/main.dart', 'lib/core/router/app_router.dart', 'test/core/example_test.dart',
                     'pubspec.lock', '.github/workflows/ci.yml'):
            with self.subTest(path=path):
                self.assertTrue(scheduled(self.jobs['flutter_tests'], self.outputs(path)))

    def test_native_package_changes_only_schedule_the_affected_platform(self):
        cases = {
            'packages/cloud_functions/android/src/Plugin.kt': (True, False),
            'packages/cloud_functions/ios/Sources/Plugin.swift': (False, True),
            'packages/cloud_functions/native_tests/NativeSwiftCheck.swift': (False, True),
            'packages/cloud_functions/lib/cloud_functions.dart': (False, False),
            'packages/cloud_functions/README.md': (False, False),
            'android/README.md': (False, False),
            'ios/README.md': (False, False),
            'packages/cloud_functions/pubspec.yaml': (True, True),
            'pigeons/cloud_functions.dart': (True, True),
            'pubspec.lock': (True, True),
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                outputs = self.outputs(path)
                self.assertEqual(tuple(scheduled(self.jobs[name], outputs) for name in ('android', 'ios')), expected)

    def test_notification_contract_has_one_owner_for_mixed_and_backend_only_changes(self):
        for path, expected in (('functions/src/notifications.ts', True),
                               ('lib/core/startup/notification_channels.dart', False),
                               ('.github/workflows/ci.yml', False)):
            with self.subTest(path=path):
                self.assertEqual(scheduled(self.jobs['notification_contract'], self.outputs(path)), expected)
        mixed = self.outputs('functions/src/notifications.ts')
        mixed['flutter'] = 'true'
        self.assertFalse(scheduled(self.jobs['notification_contract'], mixed))
        fixture = next(step for step in self.jobs['flutter']['steps']
                       if step.get('name') == 'Exercise missing-channel regression fixture')
        self.assertIn('notification-contract-fixture-test', fixture['run'])

    def test_every_shard_is_aggregated_and_a_failed_or_cancelled_shard_blocks_ci(self):
        matrix = self.jobs['flutter_tests']['strategy']
        self.assertFalse(matrix['fail-fast'])
        command = next(step['run'] for step in self.jobs['flutter_tests']['steps']
                       if step.get('name') == 'Run test shard')
        total = int(re.search(r'TEST_TOTAL_SHARDS=(\d+)', command)[1])
        self.assertEqual(matrix['matrix']['shard'], list(range(total)))
        aggregate = self.jobs['ci']
        self.assertIn('flutter_tests', aggregate['needs'])
        step = aggregate['steps'][0]
        self.assertIn('needs.flutter_tests.result', step['env']['RESULTS'])
        for result, expected in (('success', 0), ('failure', 1), ('cancelled', 1)):
            command = step['run'].replace('${{ needs.changes.result }}', 'success')
            completed = subprocess.run(['bash', '-e', '-c', command], capture_output=True, text=True,
                                       env={**os.environ, 'RESULTS': f'success skipped {result} skipped'})
            self.assertEqual(completed.returncode, expected, completed.stdout + completed.stderr)

    def test_native_cache_reader_and_master_writer_use_the_same_key_and_paths(self):
        reader = next(step for step in self.jobs['android']['steps']
                      if step.get('name') == 'Restore Gradle')
        writer = next(step for step in self.jobs['android_cache_base']['steps']
                      if step.get('name') == 'Save Gradle')
        lookup = next(step for step in self.jobs['android_cache_base']['steps'] if step.get('id') == 'cached')
        self.assertEqual(reader['with']['key'], lookup['with']['key'])
        self.assertEqual(reader['with']['path'], writer['with']['path'])
        self.assertEqual(writer['with']['key'], '${{ steps.cached.outputs.cache-primary-key }}')
        size_reader = next(step for step in workflow('app_size.yml')['jobs']['app_size']['steps']
                           if step.get('name') == 'Cache Gradle')
        self.assertEqual(size_reader['with'], reader['with'])
        self.assertNotIn('app_size_base', self.jobs)

    def test_unknown_change_outputs_fail_instead_of_silently_skipping_jobs(self):
        for operator in ('==', '!='):
            job = {'if': f"needs.changes.outputs.fluttre {operator} 'true'"}
            with self.subTest(operator=operator), self.assertRaises(KeyError):
                scheduled(job, {'flutter': 'true'})

    def test_web_uses_the_installed_browser_and_keeps_e2e_and_full_typechecking(self):
        job = self.jobs['web']
        self.assertEqual(job['env']['PLAYWRIGHT_CHROMIUM_CHANNEL'], 'chrome')
        commands = '\n'.join(step.get('run', '') for step in job['steps'])
        self.assertIn('npm run test:e2e', commands)
        self.assertIn('npm run build', commands)
        self.assertNotIn('playwright install', commands)
        self.assertIn('tsc --noEmit', commands)
        self.assertNotIn('ignoreBuildErrors', (ROOT / 'web/next.config.ts').read_text())

    def test_web_type_errors_fail_the_ci_step(self):
        step = next(step for step in self.jobs['web']['steps']
                    if step.get('name') == 'Typecheck all TypeScript')
        with tempfile.TemporaryDirectory() as directory:
            npx = Path(directory) / 'npx'
            npx.write_text('''#!/usr/bin/env python3
import sys
if sys.argv[1:] == ['tsc', '--noEmit']:
    print('TS2322: invalid types in a Playwright spec', file=sys.stderr)
    sys.exit(2)
sys.exit('Unexpected typecheck command')
''')
            npx.chmod(0o755)
            result = subprocess.run(['bash', '-e', '-c', step['run']], cwd=directory,
                                    env={**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH']},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('TS2322: invalid types in a Playwright spec', result.stderr)


class MakeTestCommandsTest(unittest.TestCase):
    def test_analytics_checks_refresh_dependencies_before_using_packages(self):
        for target in ('analytics-schema-check', 'analytics-check'):
            for fail_get in (False, True):
                with self.subTest(target=target, fail_get=fail_get), tempfile.TemporaryDirectory() as directory:
                    work = Path(directory)
                    (work / 'Makefile').symlink_to(ROOT / 'Makefile')
                    (work / 'tool').mkdir()
                    guard = work / 'tool/analytics_raw_usage_guard.sh'
                    guard.write_text('#!/bin/sh\nexit 0\n')
                    guard.chmod(0o755)
                    compiler = work / 'compiler'
                    compiler.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
args = sys.argv[1:]
if args == ['pub', 'get']:
    if os.environ['FAIL_GET'] == '1':
        sys.exit(23)
    Path('packages-current').touch()
elif args[:1] in (['run'], ['test']):
    if not Path('packages-current').exists():
        sys.exit('Cannot resolve packages from stale configuration')
    Path('generated' if args[0] == 'run' else 'tested').touch()
elif args[:1] != ['format']:
    sys.exit('Unexpected compiler command')
''')
                    compiler.chmod(0o755)
                    git = work / 'git'
                    git.write_text('#!/bin/sh\nexit 0\n')
                    git.chmod(0o755)
                    result = subprocess.run(
                        ['make', '-s', target, 'CI=true', f'FLUTTER={compiler}', f'DART={compiler}'],
                        cwd=work, capture_output=True, text=True,
                        env={**os.environ, 'PATH': str(work) + os.pathsep + os.environ['PATH'],
                             'FAIL_GET': str(int(fail_get))})
                    if fail_get:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertFalse((work / 'generated').exists())
                        self.assertFalse((work / 'tested').exists())
                    else:
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertTrue((work / 'generated').exists())
                        self.assertEqual((work / 'tested').exists(), target == 'analytics-check')

    def run_make(self, target, index=None, fail=False, dry_run=False, total=2):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / 'test').mkdir()
            for name in ('a_test.dart', 'b_test.dart', 'c_test.dart', 'nested/d_test.dart', 'support.dart'):
                path = work / 'test' / name
                path.parent.mkdir(exist_ok=True)
                path.touch()
            (work / 'tool').symlink_to(ROOT / 'tool', target_is_directory=True)
            (work / 'Makefile').symlink_to(ROOT / 'Makefile')
            flutter = work / 'flutter'
            flutter.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CAPTURE'], 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('FAIL_SUITE') == '1' and 'test' in sys.argv:
    sys.exit(23)
''')
            flutter.chmod(0o755)
            capture = work / 'commands.jsonl'
            command = ['make', '-s', target, 'CI=true', 'TEST_FLAGS=--concurrency=2']
            if dry_run:
                command.append('-n')
            if index is not None:
                command += [f'TEST_SHARD_INDEX={index}', f'TEST_TOTAL_SHARDS={total}']
            completed = subprocess.run(command, cwd=work, capture_output=True, text=True,
                                       env={**os.environ, 'PATH': str(work) + os.pathsep + os.environ['PATH'],
                                            'CAPTURE': str(capture), 'FAIL_SUITE': str(int(fail))})
            return completed, [json.loads(line) for line in capture.read_text().splitlines()] if capture.exists() else []

    def test_shards_partition_the_suite_and_run_product_mode_checks_only_once(self):
        for index in (0, 1):
            with self.subTest(index=index):
                result, commands = self.run_make('test-shard', index)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(commands[0], ['pub', 'get'])
                expected_files = (['test/a_test.dart', 'test/c_test.dart'] if index == 0
                                  else ['test/b_test.dart', 'test/nested/d_test.dart'])
                self.assertEqual(commands[1], ['test', '--no-pub', '--concurrency=2'] + expected_files)
                release = commands[2:]
                self.assertEqual(len(release), 1 if index == 0 else 0)
                if release:
                    self.assertEqual(release[0], ['test', '--no-pub', '--concurrency=2',
                        '--dart-define=dart.vm.product=true', '--dart-define=PRISM_PERF_AUTODRIVE=true',
                        'test/core/debug/performance_probe_release_test.dart',
                        'test/core/platform/cloud_functions_perf_test.dart'])

    def test_failed_shard_fails_make_and_does_not_run_product_mode_checks(self):
        result, commands = self.run_make('test-shard', 0, fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(commands), 2)

    def test_invalid_or_empty_shards_fail_without_launching_the_suite(self):
        for total, index in ((0, 0), (2, -1), (2, 2), (5, 4)):
            with self.subTest(total=total, index=index):
                result, commands = self.run_make('test-shard', index, total=total)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(commands, [['pub', 'get']])

    def test_local_test_keeps_the_full_suite_and_product_mode_checks(self):
        result, commands = self.run_make('test')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[:2], [['pub', 'get'], ['test', '--no-pub', '--concurrency=2']])
        self.assertIn('--dart-define=dart.vm.product=true', commands[2])

    def test_dry_run_does_not_start_flutter_processes(self):
        result, commands = self.run_make('test', dry_run=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands, [])
        self.assertIn('--dart-define=dart.vm.product=true', result.stdout)


if __name__ == '__main__':
    unittest.main()
