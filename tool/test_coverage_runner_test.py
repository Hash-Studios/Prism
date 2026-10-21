"""Exercise coverage orchestration without starting Flutter."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CoverageRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ('tool', 'test', 'bin', 'coverage'):
            (self.root / name).mkdir()
        shutil.copy(Path(__file__).with_name('flutter_coverage.sh'), self.root / 'tool')
        mock = '''#!/usr/bin/env bash
set -eu
printf '%s %s\\n' "${0##*/}" "$*" >> "$RUNNER_LOG"
if [[ "${0##*/}" == fvm ]]; then
  if [[ "$3" == --coverage ]]; then
    [[ "${FAIL_STAGE:-}" != suite ]] || exit 21
  else
    [[ -f "$3" ]]
    [[ "${FAIL_STAGE:-}" != probe ]] || exit 22
  fi
  for arg in "$@"; do
    if [[ "$arg" == --coverage-path=* ]]; then
      printf 'fresh\\n' > "${arg#*=}"
    fi
  done
elif [[ "$2" == imports ]]; then
  [[ ! -e "$3" ]]
  printf 'helper\\n' > "$3"
else
  [[ "$(< "$3")" == fresh ]]
fi
'''
        for name in ('fvm', 'python3'):
            path = self.root / 'bin' / name
            path.write_text(mock)
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.root / 'bin') + ':' + os.environ['PATH'],
                        RUNNER_LOG=str(self.root / 'calls'))

    def run_runner(self, failure=''):
        result = subprocess.run(['bash', str(self.root / 'tool/flutter_coverage.sh'), 'coverage'],
                                env=dict(self.env, FAIL_STAGE=failure), capture_output=True, text=True)
        self.assertEqual(list((self.root / 'test').iterdir()), [])
        return result

    def test_repeated_runs_and_default_threshold(self):
        for _ in range(2):
            result = self.run_runner()
            self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'calls').read_text().splitlines()
        self.assertEqual(len(calls), 8)
        self.assertIn('test --coverage ', calls[0])
        self.assertIn(' imports ', calls[1])
        self.assertIn('--minimum 90', calls[3])

    def test_failed_suite_does_not_use_stale_outputs(self):
        for name in ('full.lcov', 'inventory.lcov'):
            (self.root / 'coverage' / name).write_text('stale')
        self.assertEqual(self.run_runner('suite').returncode, 21)
        self.assertEqual(len((self.root / 'calls').read_text().splitlines()), 1)
        self.assertEqual(list((self.root / 'coverage').iterdir()), [])

    def test_probe_failure_removes_helper_and_skips_report(self):
        self.assertEqual(self.run_runner('probe').returncode, 22)
        self.assertEqual(len((self.root / 'calls').read_text().splitlines()), 3)


if __name__ == '__main__':
    unittest.main()
