"""Offline regressions for verification lock and state snapshots."""

import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "verify-prism"
LOADER = importlib.machinery.SourceFileLoader("verify_prism_state_reads", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
VERIFY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VERIFY)


class StateReadTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.lock = root / "ios.lock"
        self.state = root / "ios.state"
        for name, value in (
            ("LOCK", {"ios": self.lock}),
            ("STATE", {"ios": self.state}),
            ("ARTIFACTS", root / "artifacts"),
        ):
            active_patch = patch.object(VERIFY, name, value)
            active_patch.start()
            self.addCleanup(active_patch.stop)

        run_patch = patch.object(
            VERIFY,
            "_run",
            side_effect=AssertionError("_run must not call a real device command in state tests"),
        )
        run_patch.start()
        self.addCleanup(run_patch.stop)
        subprocess_patch = patch.object(
            VERIFY.subprocess,
            "run",
            side_effect=AssertionError("subprocess.run must not be called in state tests"),
        )
        subprocess_patch.start()
        self.addCleanup(subprocess_patch.stop)

    def test_disappearing_lock_and_state_reads_are_treated_as_missing(self):
        self.lock.write_text("run_id=old-run\n")
        self.state.write_text("run_id=old-run\n")
        real_read_text = Path.read_text

        def disappear_during_read(path, *args, **kwargs):
            if path in (self.lock, self.state):
                raise FileNotFoundError(path)
            return real_read_text(path, *args, **kwargs)

        with patch.object(Path, "read_text", new=disappear_during_read):
            self.assertIsNone(VERIFY.lock_owner("ios"))
            self.assertEqual(VERIFY._read_kv(self.state), {})

    @staticmethod
    def _start_thread(target, name):
        finished = threading.Event()
        result = []

        def run():
            try:
                result.append(target())
            except BaseException as error:
                result.append(error)
            finally:
                finished.set()

        thread = threading.Thread(target=run, daemon=True, name=name)
        thread.start()
        return thread, finished, result

    def test_require_state_snapshot_serializes_same_checkout_takeover(self):
        VERIFY.acquire_lock("ios", "old-device", "old-run")
        state_read = threading.Event()
        release_state_read = threading.Event()
        requiring_thread_id = []
        real_read_kv = VERIFY._read_kv

        def pause_after_first_state_read(path):
            data = real_read_kv(path)
            if (
                path == self.state
                and requiring_thread_id
                and threading.get_ident() == requiring_thread_id[0]
                and not state_read.is_set()
            ):
                state_read.set()
                if not release_state_read.wait(2):
                    raise AssertionError("test did not release the state snapshot")
            return data

        def require_state():
            requiring_thread_id.append(threading.get_ident())
            return VERIFY.require_state("ios")

        with patch.object(VERIFY, "_read_kv", side_effect=pause_after_first_state_read):
            require_thread, require_finished, require_result = self._start_thread(
                require_state, "require-state"
            )
            takeover_thread = None
            try:
                self.assertTrue(state_read.wait(2), "require_state did not read its initial state")

                def takeover():
                    with patch.dict(os.environ, {"PRISM_VERIFY_TAKEOVER": "1"}):
                        return VERIFY.acquire_lock("ios", "new-device", "new-run")

                takeover_thread, takeover_finished, takeover_result = self._start_thread(
                    takeover, "takeover"
                )
                takeover_blocked_during_snapshot = not takeover_finished.wait(0.2)
            finally:
                release_state_read.set()
                require_thread.join(2)
                if takeover_thread is not None:
                    takeover_thread.join(2)

        self.assertTrue(require_finished.is_set(), "require_state thread did not finish")
        self.assertIsNotNone(takeover_thread)
        self.assertTrue(takeover_finished.is_set(), "takeover thread did not finish")
        self.assertTrue(
            takeover_blocked_during_snapshot,
            "takeover replaced state while require_state was checking its snapshot",
        )
        self.assertNotIsInstance(require_result[0], BaseException)
        self.assertEqual(require_result[0].get("run_id"), "old-run")
        self.assertEqual(takeover_result, [None])
        self.assertEqual(VERIFY._read_kv(self.lock).get("run_id"), "new-run")
        self.assertEqual(VERIFY._read_kv(self.state).get("run_id"), "new-run")


if __name__ == "__main__":
    unittest.main()
