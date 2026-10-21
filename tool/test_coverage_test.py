"""Run with python3 -m unittest discover -s tool -p test_coverage_test.py."""
from pathlib import Path
import json
import tempfile
import unittest
import subprocess
from unittest.mock import patch

from test_coverage import main, report


class CoverageReportTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'lib').mkdir()

    def source(self, name):
        path = self.root / 'lib' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('int answer() => 42;\n')

    def lcov(self, text):
        path = self.root / 'lcov.info'
        path.write_text(text)
        return path

    def test_unloaded_source_blocks_perfect_observed_coverage(self):
        self.source('loaded.dart')
        self.source('unloaded.dart')
        result = report(self.root, self.lcov('SF:lib/loaded.dart\nDA:1,1\nend_of_record\n'), 90)
        self.assertEqual(result['observed_percent'], 100)
        self.assertEqual(result['missing_records'], ['lib/unloaded.dart'])
        self.assertEqual(result['passed'], False)

    def test_uncovered_executable_lines_fail_threshold_and_generated_code_is_excluded(self):
        self.source('app.dart')
        self.source('app.g.dart')
        result = report(self.root, self.lcov('SF:lib/app.dart\nDA:1,1\nDA:2,0\nend_of_record\n'), 90)
        self.assertEqual(result['handwritten_files'], 1)
        self.assertEqual(result['observed_percent'], 50)
        self.assertEqual(result['complete'], True)
        self.assertEqual(result['passed'], False)

    def test_root_firebase_options_is_excluded_but_nested_same_name_is_counted(self):
        self.source('firebase_options.dart')
        self.source('features/example/firebase_options.dart')
        result = report(self.root, self.lcov(
            'SF:lib/features/example/firebase_options.dart\nDA:1,1\nend_of_record\n'
            'SF:lib/firebase_options.dart\nDA:1,0\nend_of_record\n'), 90)
        self.assertEqual(result['handwritten_files'], 1)
        self.assertEqual(result['generated_files_excluded'], ['lib/firebase_options.dart'])
        self.assertEqual(result['observed_percent'], 100)
        self.assertTrue(result['passed'])

    def test_empty_executable_record_blocks_perfect_observed_coverage(self):
        self.source('loaded.dart')
        self.source('empty.dart')
        result = report(self.root, self.lcov(
            'SF:lib/loaded.dart\nDA:1,1\nend_of_record\nSF:lib/empty.dart\nend_of_record\n'), 90)
        self.assertEqual(result['observed_percent'], 100)
        self.assertEqual(result['observed_found'], 1)
        self.assertEqual(result['missing_records'], ['lib/empty.dart'])
        self.assertFalse(result['complete'])
        self.assertFalse(result['passed'])

    def test_certified_empty_declaration_record_can_pass(self):
        self.source('loaded.dart')
        (self.root / 'lib' / 'empty.dart').write_text('abstract class A { void f(); }\n')
        result = report(self.root, self.lcov(
            'SF:lib/loaded.dart\nDA:1,1\nend_of_record\nSF:lib/empty.dart\nend_of_record\n'),
            90, declaration_only=['lib/empty.dart'])
        self.assertEqual(result['observed_found'], 1)
        self.assertTrue(result['passed'])

    def test_declaration_verification_checks_absent_and_empty_records(self):
        for name in ['loaded.dart', 'empty.dart', 'absent.dart']:
            self.source(name)
        lcov = self.lcov('SF:lib/loaded.dart\nDA:1,1\nend_of_record\n'
                         'SF:lib/empty.dart\nend_of_record\n')
        with patch('sys.argv', ['test_coverage.py', '--root', str(self.root), 'report', str(lcov),
                                '--verify-declarations']), \
                patch('test_coverage.subprocess.run') as run, patch('builtins.print'):
            run.return_value.stdout = '[]'
            self.assertEqual(main(), 1)
        self.assertEqual(run.call_args.args[0][3:], ['lib/absent.dart', 'lib/empty.dart'])

    def test_duplicate_records_merge_by_line_and_complete_inventory_can_pass(self):
        self.source('app.dart')
        result = report(self.root, self.lcov(
            'SF:lib/app.dart\nDA:1,0\nDA:2,2\nend_of_record\n'
            'SF:lib/app.dart\nDA:1,1\nDA:2,0\nend_of_record\n'), 90)
        self.assertEqual(result['observed_hit'], 2)
        self.assertEqual(result['observed_found'], 2)
        self.assertEqual(result['passed'], True)

    def test_import_inventory_only_adds_denominator(self):
        self.source('app.dart')
        observed = self.lcov('SF:lib/app.dart\nDA:1,1\nend_of_record\n')
        extra = self.root / 'inventory.info'
        extra.write_text('SF:lib/app.dart\nDA:1,0\nDA:2,1\nend_of_record\n')
        result = report(self.root, observed, 90, inventory_lcov=[extra])
        self.assertEqual(result['observed_hit'], 1)
        self.assertEqual(result['observed_found'], 2)
        self.assertEqual(result['passed'], False)

    def test_dart_classifier_rejects_executable_bodies_and_accepts_declarations(self):
        fixtures = {
            'barrel.dart': "export 'other.dart';",
            'abstract.dart': 'abstract class A { void f(); }',
            'redirect.dart': 'abstract class A { factory A() = B; }',
            'function.dart': 'void f() {}',
            'expression.dart': 'int f() => 42;',
            'method.dart': 'abstract class A { void f() {} }',
            'initializer.dart': 'final x = compute();',
        }
        paths = []
        for name, source in fixtures.items():
            path = self.root / name
            path.write_text(source)
            paths.append(str(path))
        process = subprocess.run(['fvm', 'dart', 'tool/test_coverage_declarations.dart', *paths],
                                 check=True, capture_output=True, text=True)
        self.assertEqual([Path(p).name for p in json.loads(process.stdout)],
                         ['barrel.dart', 'abstract.dart', 'redirect.dart'])


if __name__ == '__main__':
    unittest.main()
