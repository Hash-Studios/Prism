"""Deterministic offline tests for lock acquisition and cleanup races."""

import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "verify-prism"
LOADER = importlib.machinery.SourceFileLoader("verify_prism_lock_races", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
VERIFY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VERIFY)
PLATFORMS = ("ios", "android")


class LockRaceTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.locks = {platform: root / f"{platform}.lock" for platform in PLATFORMS}
        self.states = {platform: root / f"{platform}.state" for platform in PLATFORMS}
        self.artifacts = root / "artifacts"

        for name, value in (("LOCK", self.locks), ("STATE", self.states), ("ARTIFACTS", self.artifacts)):
            active_patch = patch.object(VERIFY, name, value)
            active_patch.start()
            self.addCleanup(active_patch.stop)

        run_patch = patch.object(
            VERIFY,
            "_run",
            side_effect=AssertionError("_run must not call a real device command in lock race tests"),
        )
        run_patch.start()
        self.addCleanup(run_patch.stop)

        subprocess_patch = patch.object(
            VERIFY.subprocess,
            "run",
            side_effect=AssertionError("subprocess.run must not be called in lock race tests"),
        )
        subprocess_patch.start()
        self.addCleanup(subprocess_patch.stop)

    @staticmethod
    def _cleanup(platform):
        return VERIFY.cmd_cleanup(type("Args", (), {"platform": platform})())

    def _start_thread(self, target):
        finished = threading.Event()
        result = []

        def run():
            try:
                result.append(target())
            except BaseException as error:
                result.append(error)
            finally:
                finished.set()

        thread = threading.Thread(target=run, daemon=True)
        thread.start()
        return thread, finished, result

    def test_takeover_waits_for_cleanup_before_replacing_lock_and_state(self):
        for platform in PLATFORMS:
            with self.subTest(platform=platform):
                VERIFY.acquire_lock(platform, "old-device", "old-run")
                cleanup_entered = threading.Event()
                allow_cleanup = threading.Event()

                def blocked_run(cmd, **kwargs):
                    cleanup_entered.set()
                    if not allow_cleanup.wait(2):
                        raise AssertionError("test did not release cleanup")
                    return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

                with patch.object(VERIFY, "_run", side_effect=blocked_run):
                    cleanup_thread, cleanup_finished, cleanup_result = self._start_thread(
                        lambda: self._cleanup(platform)
                    )
                    try:
                        self.assertTrue(cleanup_entered.wait(2), "cleanup did not reach its mocked device call")

                        def takeover():
                            with patch.dict(os.environ, {"PRISM_VERIFY_TAKEOVER": "1"}):
                                return VERIFY.acquire_lock(platform, "new-device", "new-run")

                        acquire_thread, acquire_finished, acquire_result = self._start_thread(takeover)
                        blocked_while_cleanup_owned = not acquire_finished.wait(0.2)
                    finally:
                        allow_cleanup.set()
                        cleanup_thread.join(2)
                        if "acquire_thread" in locals():
                            acquire_thread.join(2)

                self.assertTrue(cleanup_finished.is_set(), "cleanup thread did not finish")
                self.assertTrue(acquire_finished.is_set(), "takeover thread did not finish")
                self.assertTrue(blocked_while_cleanup_owned, "takeover did not wait for cleanup's lock guard")
                self.assertEqual(cleanup_result, [0])
                self.assertEqual(acquire_result, [None])
                self.assertEqual(VERIFY._read_kv(self.locks[platform]).get("run_id"), "new-run")
                self.assertEqual(VERIFY._read_kv(self.states[platform]).get("run_id"), "new-run")

    def test_stale_lock_reclamation_serializes_contenders(self):
        for platform in PLATFORMS:
            with self.subTest(platform=platform):
                lock = self.locks[platform]
                state = self.states[platform]
                lock.write_text("run_id=expired-run\n")
                state.write_text("run_id=expired-run\n")
                old = time.time() - VERIFY.STALE_LOCK_S - 60
                os.utime(lock, (old, old))
                reclaim_entered = threading.Event()
                allow_reclaim = threading.Event()
                first_unlink = threading.Lock()
                should_pause = [True]
                real_unlink = Path.unlink

                def pause_old_lock_unlink(path, *args, **kwargs):
                    pause = False
                    if path == lock:
                        with first_unlink:
                            if should_pause[0]:
                                should_pause[0] = False
                                pause = True
                    if pause:
                        reclaim_entered.set()
                        if not allow_reclaim.wait(2):
                            raise AssertionError("test did not release stale-lock reclamation")
                    return real_unlink(path, *args, **kwargs)

                first_thread = second_thread = None
                with patch.object(Path, "unlink", new=pause_old_lock_unlink):
                    first_thread, first_finished, first_result = self._start_thread(
                        lambda: VERIFY.acquire_lock(platform, "first-device", "first-run")
                    )
                    try:
                        self.assertTrue(reclaim_entered.wait(2), "first contender did not reach stale-lock reclaim")
                        second_thread, second_finished, second_result = self._start_thread(
                            lambda: VERIFY.acquire_lock(platform, "second-device", "second-run")
                        )
                        blocked_while_reclaiming = not second_finished.wait(0.2)
                    finally:
                        allow_reclaim.set()
                        first_thread.join(2)
                        if second_thread is not None:
                            second_thread.join(2)

                self.assertTrue(first_finished.is_set(), "first contender did not finish")
                self.assertIsNotNone(second_thread)
                self.assertTrue(second_finished.is_set(), "second contender did not finish")
                self.assertTrue(blocked_while_reclaiming, "second contender did not wait for stale-lock reclaim")
                self.assertEqual(first_result, [None])
                self.assertEqual(len(second_result), 1)
                self.assertIsInstance(second_result[0], SystemExit)
                self.assertEqual(second_result[0].code, 3)
                self.assertEqual(VERIFY._read_kv(lock).get("run_id"), "first-run")
                self.assertEqual(VERIFY._read_kv(state).get("run_id"), "first-run")


if __name__ == "__main__":
    unittest.main()
