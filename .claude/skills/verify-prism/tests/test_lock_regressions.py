"""Offline regression tests for cross-worktree lock ownership and recovery."""

import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "verify-prism"
LOADER = importlib.machinery.SourceFileLoader("verify_prism_regressions", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
VERIFY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VERIFY)


class LockRegressionTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.root = root
        self.artifacts = root / "current-artifacts"
        self.peer_artifacts = root / "peer-artifacts"
        self.artifacts.mkdir()
        self.peer_artifacts.mkdir()
        self.locks = {platform: root / f"{platform}.lock" for platform in ("ios", "android")}
        self.states = {platform: root / f"{platform}.state" for platform in ("ios", "android")}

        for name, value in (
            ("LOCK", self.locks),
            ("STATE", self.states),
            ("ARTIFACTS", self.artifacts),
        ):
            active_patch = patch.object(VERIFY, name, value)
            active_patch.start()
            self.addCleanup(active_patch.stop)

        run_patch = patch.object(VERIFY, "_run", side_effect=self.healthy_inventory)
        self.run_mock = run_patch.start()
        self.addCleanup(run_patch.stop)
        subprocess_mock = patch.object(
            VERIFY.subprocess,
            "run",
            side_effect=AssertionError("subprocess.run must not be called in lock tests"),
        )
        subprocess_mock.start()
        self.addCleanup(subprocess_mock.stop)

    @staticmethod
    def healthy_inventory(cmd, **kwargs):
        if cmd[:3] == ["axe", "--version"][:3]:
            return subprocess.CompletedProcess(cmd, 0, stdout="1.7.0\n", stderr="")
        if cmd[:4] == ["xcrun", "simctl", "list", "devices"]:
            output = "Prism QA iPhone 17 Pro (test-udid) (Shutdown)\n"
            return subprocess.CompletedProcess(cmd, 0, stdout=output, stderr="")
        if cmd[:5] == ["xcrun", "simctl", "list", "devices", "booted"]:
            return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
        if cmd[:4] == ["xcrun", "simctl", "get_app_container", "test-udid"]:
            return subprocess.CompletedProcess(cmd, 0, stdout="/app", stderr="")
        if cmd == ["adb", "version"]:
            return subprocess.CompletedProcess(cmd, 0, stdout="Android Debug Bridge", stderr="")
        if cmd == ["emulator", "-list-avds"]:
            return subprocess.CompletedProcess(cmd, 0, stdout=f"{VERIFY.ANDROID_AVD_NAME}\n", stderr="")
        if cmd == ["adb", "devices"]:
            return subprocess.CompletedProcess(cmd, 0, stdout="List of devices attached\nemulator-5580\tdevice\n", stderr="")
        if cmd[:6] == ["adb", "-s", "emulator-5580", "shell", "pm", "path"]:
            return subprocess.CompletedProcess(cmd, 0, stdout="package:/base.apk", stderr="")
        if "terminate" in cmd or "force-stop" in cmd:
            return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
        raise AssertionError(f"unexpected _run command: {cmd}")

    def make_stale(self, path):
        old = time.time() - VERIFY.STALE_LOCK_S - 60
        os.utime(path, (old, old))

    def test_peer_with_matching_run_id_is_not_owned_across_artifact_roots(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                with patch.object(VERIFY, "ARTIFACTS", self.peer_artifacts):
                    VERIFY.acquire_lock(platform, "peer-device", "shared-run")

                self.assertEqual(VERIFY._read_kv(self.states[platform])["run_id"], "shared-run")
                self.assertFalse(VERIFY.lock_is_ours(platform))
                with self.assertRaises(SystemExit):
                    VERIFY.require_state(platform)
                self.assertEqual(VERIFY.cmd_doctor(type("Args", (), {"platform": platform})()), 1)

                self.run_mock.reset_mock()
                with self.assertRaises(SystemExit) as raised:
                    VERIFY.cmd_cleanup(type("Args", (), {"platform": platform})())
                self.assertEqual(raised.exception.code, 3)
                self.run_mock.assert_not_called()
                self.assertTrue(self.locks[platform].exists())
                self.assertTrue(self.states[platform].exists())
                self.locks[platform].unlink()
                self.states[platform].unlink()

    def test_require_state_refuses_orphan_state_without_lock(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                self.states[platform].write_text("run_id=orphan-run\n")
                self.run_mock.assert_not_called()

                with self.assertRaises(SystemExit):
                    VERIFY.require_state(platform)

                self.run_mock.assert_not_called()
                self.assertFalse(self.locks[platform].exists())
                self.assertTrue(self.states[platform].exists())
                self.states[platform].unlink()

    def test_free_text_fresh_lock_blocks_doctor_and_cleanup(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                self.locks[platform].write_text("peer lock written by hand\n")
                self.states[platform].write_text("run_id=local-run\n")
                self.assertEqual(VERIFY.cmd_doctor(type("Args", (), {"platform": platform})()), 1)
                self.run_mock.reset_mock()
                with self.assertRaises(SystemExit) as raised:
                    VERIFY.cmd_cleanup(type("Args", (), {"platform": platform})())
                self.assertEqual(raised.exception.code, 3)
                self.run_mock.assert_not_called()
                self.assertTrue(self.locks[platform].exists())
                self.assertTrue(self.states[platform].exists())
                self.locks[platform].unlink()
                self.states[platform].unlink()

    def test_read_only_owner_and_doctor_preserve_stale_foreign_lock_and_state(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                self.locks[platform].write_text("peer lock written by hand\n")
                self.states[platform].write_text("run_id=peer-run\n")
                self.make_stale(self.locks[platform])
                self.make_stale(self.states[platform])
                original_lock = self.locks[platform].read_text()
                original_state = self.states[platform].read_text()

                VERIFY.lock_owner(platform)
                self.assertEqual(VERIFY.cmd_doctor(type("Args", (), {"platform": platform})()), 0)

                self.assertEqual(self.locks[platform].read_text(), original_lock)
                self.assertEqual(self.states[platform].read_text(), original_state)

    def test_cleanup_refuses_stale_foreign_and_free_text_locks(self):
        for platform in ("ios", "android"):
            for contents in ("pid=999999\ndevice_id=peer\nrun_id=peer-run\n", "someone else's lock\n"):
                with self.subTest(platform=platform, contents=contents):
                    self.locks[platform].write_text(contents)
                    self.states[platform].write_text("run_id=peer-run\n")
                    self.make_stale(self.locks[platform])
                    self.make_stale(self.states[platform])
                    self.run_mock.reset_mock()

                    with self.assertRaises(SystemExit) as raised:
                        VERIFY.cmd_cleanup(type("Args", (), {"platform": platform})())

                    self.assertEqual(raised.exception.code, 3)
                    self.run_mock.assert_not_called()
                    self.assertEqual(self.locks[platform].read_text(), contents)
                    self.assertEqual(self.states[platform].read_text(), "run_id=peer-run\n")
                    self.locks[platform].unlink()
                    self.states[platform].unlink()

    def test_stale_lock_acquisition_reclaims_lock_and_state(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                self.locks[platform].write_text("run_id=old-run\n")
                self.states[platform].write_text("run_id=old-run\n")
                self.make_stale(self.locks[platform])

                VERIFY.acquire_lock(platform, "new-device", "new-run")

                self.assertEqual(VERIFY._read_kv(self.locks[platform])["run_id"], "new-run")
                self.assertEqual(VERIFY._read_kv(self.states[platform])["run_id"], "new-run")
                self.locks[platform].unlink()
                self.states[platform].unlink()

    def test_matching_current_artifacts_allow_cleanup_after_owner_pid_dies(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                VERIFY.acquire_lock(platform, "owned-device", "owned-run")
                lock_data = VERIFY._read_kv(self.locks[platform])
                state_data = VERIFY._read_kv(self.states[platform])
                lock_data["pid"] = "99999999"
                state_data["pid"] = "99999999"
                VERIFY._write_kv(self.locks[platform], lock_data)
                VERIFY._write_kv(self.states[platform], state_data)

                self.assertEqual(VERIFY.cmd_cleanup(type("Args", (), {"platform": platform})()), 0)
                self.assertFalse(self.locks[platform].exists())
                self.assertFalse(self.states[platform].exists())
                self.assertEqual(self.run_mock.call_count, 1)
                self.run_mock.reset_mock()

    def test_missing_state_refuses_doctor_and_cleanup_but_takeover_recovers(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                VERIFY.acquire_lock(platform, "owned-device", "owned-run")
                self.states[platform].unlink()
                self.assertEqual(VERIFY.cmd_doctor(type("Args", (), {"platform": platform})()), 1)

                self.run_mock.reset_mock()
                with self.assertRaises(SystemExit) as raised:
                    VERIFY.cmd_cleanup(type("Args", (), {"platform": platform})())
                self.assertEqual(raised.exception.code, 3)
                self.run_mock.assert_not_called()
                self.assertTrue(self.locks[platform].exists())
                self.assertFalse(self.states[platform].exists())

                with patch.dict(os.environ, {"PRISM_VERIFY_TAKEOVER": "1"}):
                    VERIFY.acquire_lock(platform, "recovery-device", "recovery-run")
                self.assertEqual(VERIFY._read_kv(self.locks[platform])["run_id"], "recovery-run")
                self.assertEqual(VERIFY._read_kv(self.states[platform])["run_id"], "recovery-run")
                self.locks[platform].unlink()
                self.states[platform].unlink()

    def test_exclusive_create_race_preserves_peer_lock_and_state(self):
        for platform in ("ios", "android"):
            with self.subTest(platform=platform):
                self.states[platform].write_text("run_id=preexisting-state\n")
                real_open = os.open

                def insert_peer_lock(path, flags, mode=0o777):
                    if Path(path) == self.locks[platform]:
                        self.locks[platform].write_text("pid=peer\nrun_id=peer-run\n")
                    return real_open(path, flags, mode)

                with patch.object(VERIFY.os, "open", side_effect=insert_peer_lock):
                    with self.assertRaises(SystemExit) as raised:
                        VERIFY.acquire_lock(platform, "new-device", "new-run")

                self.assertEqual(raised.exception.code, 3)
                self.assertEqual(VERIFY._read_kv(self.locks[platform])["run_id"], "peer-run")
                self.assertEqual(self.states[platform].read_text(), "run_id=preexisting-state\n")
                self.locks[platform].unlink()
                self.states[platform].unlink()


if __name__ == "__main__":
    unittest.main()
