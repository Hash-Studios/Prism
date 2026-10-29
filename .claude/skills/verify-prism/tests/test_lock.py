"""Offline tests for lock ownership. No device calls are made."""

import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "verify-prism"
LOADER = importlib.machinery.SourceFileLoader("verify_prism", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
VERIFY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VERIFY)


class LockTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.lock = root / "ios.lock"
        self.state = root / "ios.state"
        for target, value in (("LOCK", {"ios": self.lock}), ("STATE", {"ios": self.state}),
                              ("ARTIFACTS", root / "artifacts")):
            p = patch.object(VERIFY, target, value)
            p.start()
            self.addCleanup(p.stop)

    def test_free_lock_is_ours(self):
        self.assertTrue(VERIFY.lock_is_ours("ios"))

    def test_peer_freeform_lock_is_not_ours_without_state(self):
        self.lock.write_text("t3-peer day15 Thu Oct 29\n")
        self.assertFalse(VERIFY.lock_is_ours("ios"))

    def test_acquired_lock_is_ours_and_second_acquire_refuses(self):
        VERIFY.acquire_lock("ios", "UDID", "run-1")
        self.assertTrue(VERIFY.lock_is_ours("ios"))
        with self.assertRaises(SystemExit):
            VERIFY.acquire_lock("ios", "UDID", "run-2")
        self.assertIn("run_id=run-1", self.lock.read_text())

    def test_cleanup_refuses_peer_lock(self):
        self.lock.write_text("run_id=peer\n")
        with self.assertRaises(SystemExit), patch.object(VERIFY, "_run") as run:
            VERIFY.cmd_cleanup_ios()
        run.assert_not_called()
        self.assertTrue(self.lock.exists())


if __name__ == "__main__":
    unittest.main()
