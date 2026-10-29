"""Offline regression tests for Android tree capture. No adb calls are made."""

import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "verify-prism"
LOADER = importlib.machinery.SourceFileLoader("verify_prism", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
VERIFY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VERIFY)

STALE_TREE = '<hierarchy><node text="Rewards" /></hierarchy>'
FRESH_TREE = '<hierarchy><node text="Trending" /></hierarchy>'


class AndroidDumpTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.artifacts = Path(self.directory.name)
        (self.artifacts / "_dump.xml").write_text(STALE_TREE)
        self.artifacts_patch = patch.object(VERIFY, "ARTIFACTS", self.artifacts)
        self.artifacts_patch.start()
        self.addCleanup(self.artifacts_patch.stop)
        self.subprocess_guard = patch.object(
            VERIFY.subprocess,
            "run",
            side_effect=AssertionError("android_dump must use _run"),
        )
        self.subprocess_guard.start()
        self.addCleanup(self.subprocess_guard.stop)
        self.commands = []

    def subprocess(self, cmd, **kwargs):
        self.commands.append(cmd)
        if "pull" in cmd:
            Path(cmd[-1]).write_text(FRESH_TREE)
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    def test_failed_pull_never_returns_previous_rewards_tree(self):
        def failed_pull(cmd, **kwargs):
            self.commands.append(cmd)
            return subprocess.CompletedProcess(cmd, 1 if "pull" in cmd else 0, "", "pull failed")

        with patch.object(VERIFY, "_run", side_effect=failed_pull):
            with self.assertRaises(SystemExit):
                VERIFY.android_dump("emulator-5580")

    def test_dump_failure_does_not_pull_or_return_old_tree(self):
        def failed_dump(cmd, **kwargs):
            self.commands.append(cmd)
            return subprocess.CompletedProcess(cmd, 1 if "uiautomator" in cmd else 0, "", "dump failed")

        with patch.object(VERIFY, "_run", side_effect=failed_dump):
            with self.assertRaises(SystemExit):
                VERIFY.android_dump("emulator-5580")
        self.assertFalse(any("pull" in cmd for cmd in self.commands))

    def test_zero_exit_without_new_file_does_not_reuse_old_tree(self):
        with patch.object(VERIFY, "_run", return_value=subprocess.CompletedProcess([], 0, "", "")):
            with self.assertRaises(SystemExit):
                VERIFY.android_dump("emulator-5580")

    def test_zero_exit_dump_cannot_pull_a_previous_remote_tree(self):
        remote = {"/sdcard/prism-verify-dump.xml": STALE_TREE}

        def missing_remote(cmd, **kwargs):
            self.commands.append(cmd)
            if "pull" in cmd:
                if cmd[-2] not in remote:
                    return subprocess.CompletedProcess(cmd, 1, "", "remote file missing")
                Path(cmd[-1]).write_text(remote[cmd[-2]])
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with patch.object(VERIFY, "_run", side_effect=missing_remote):
            with self.assertRaises(SystemExit):
                VERIFY.android_dump("emulator-5580")

    def test_success_returns_fresh_tree_without_shared_paths(self):
        with patch.object(VERIFY, "_run", side_effect=self.subprocess):
            first = VERIFY.android_dump("emulator-5580")
            second = VERIFY.android_dump("emulator-5580")
        self.assertEqual(first.find("node").get("text"), "Trending")
        self.assertEqual(second.find("node").get("text"), "Trending")
        dumps = [cmd[-1] for cmd in self.commands if "uiautomator" in cmd]
        pulls = [Path(cmd[-1]) for cmd in self.commands if "pull" in cmd]
        self.assertEqual(len(set(dumps)), 2)
        self.assertEqual(len(set(pulls)), 2)
        self.assertTrue(all(not path.exists() for path in pulls))
        self.assertEqual((self.artifacts / "_dump.xml").read_text(), STALE_TREE)

    def test_invalid_xml_fails_closed(self):
        def invalid_tree(cmd, **kwargs):
            result = self.subprocess(cmd, **kwargs)
            if "pull" in cmd:
                Path(cmd[-1]).write_text("not XML")
            return result

        with patch.object(VERIFY, "_run", side_effect=invalid_tree):
            with self.assertRaises(SystemExit):
                VERIFY.android_dump("emulator-5580")

    def test_overlapping_captures_cannot_replace_each_others_tree(self):
        remote = {}
        nested = []
        started = False

        def overlap(cmd, **kwargs):
            nonlocal started
            self.commands.append(cmd)
            if "uiautomator" in cmd:
                remote[cmd[-1]] = STALE_TREE if started else FRESH_TREE
            elif "pull" in cmd:
                if not started:
                    started = True
                    nested.append(VERIFY.android_dump("emulator-5580"))
                Path(cmd[-1]).write_text(remote[cmd[-2]])
            elif "rm" in cmd:
                remote.pop(cmd[-1], None)
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with patch.object(VERIFY, "_run", side_effect=overlap):
            outer = VERIFY.android_dump("emulator-5580")
        self.assertEqual(outer.find("node").get("text"), "Trending")
        self.assertEqual(nested[0].find("node").get("text"), "Rewards")
        self.assertEqual(remote, {})

    def test_subprocess_timeout_fails_closed_and_still_attempts_cleanup(self):
        def timed_out(cmd, **kwargs):
            if "uiautomator" in cmd:
                raise subprocess.TimeoutExpired(cmd, 30)
            return self.subprocess(cmd, **kwargs)

        with patch.object(VERIFY, "_run", side_effect=timed_out):
            with self.assertRaises(SystemExit):
                VERIFY.android_dump("emulator-5580")
        self.assertTrue(any("rm" in cmd for cmd in self.commands))


if __name__ == "__main__":
    unittest.main()
