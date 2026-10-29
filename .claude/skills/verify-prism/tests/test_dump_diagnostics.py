"""Offline tests for Android dump failure diagnostics."""

import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "verify-prism"
LOADER = importlib.machinery.SourceFileLoader("verify_prism", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
VERIFY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VERIFY)


class AndroidDumpDiagnosticsTest(unittest.TestCase):
    def assert_dump_failure(self, returncode, stderr):
        commands = []

        def run(cmd, **kwargs):
            commands.append(cmd)
            if "uiautomator" in cmd:
                return subprocess.CompletedProcess(cmd, returncode, "", stderr)
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with (
            patch.object(VERIFY, "_run", side_effect=run),
            patch.object(VERIFY.subprocess, "run", side_effect=AssertionError("subprocess.run must not be called")),
            self.assertRaises(SystemExit) as raised,
            patch("sys.stderr") as error_output,
        ):
            VERIFY.android_dump("emulator-5580")

        return raised.exception, commands, error_output.write.call_args_list

    def test_exit_137_explains_possible_uiautomation_contention_and_cleans_up(self):
        failure, commands, output = self.assert_dump_failure(137, "process killed")
        message = "".join(call.args[0] for call in output)

        self.assertEqual(failure.code, 1)
        self.assertIn("exit 137", message)
        self.assertIn("can mean", message)
        self.assertIn("UiAutomation", message)
        self.assertNotIn("only", message)
        self.assertNotIn("exclusive", message)
        self.assertFalse(any("pull" in cmd for cmd in commands))
        self.assertTrue(any("rm" in cmd for cmd in commands))

    def test_other_dump_failure_keeps_stderr_without_uiautomation_hint(self):
        failure, commands, output = self.assert_dump_failure(1, "device unavailable")
        message = "".join(call.args[0] for call in output)

        self.assertEqual(failure.code, 1)
        self.assertIn("exit 1", message)
        self.assertIn("device unavailable", message)
        self.assertNotIn("UiAutomation", message)
        self.assertFalse(any("pull" in cmd for cmd in commands))
        self.assertTrue(any("rm" in cmd for cmd in commands))


if __name__ == "__main__":
    unittest.main()
