from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HOOK = Path(__file__).resolve().parents[2] / ".githooks" / "pre_push_check.py"
SPEC = importlib.util.spec_from_file_location("pre_push_check_under_test", HOOK)
hook = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(hook)

SHA_A = "a" * 40
SHA_B = "b" * 40
URL = "https://example.invalid/org/sub.git"


def cp(code=0, out="", err=""):
    return subprocess.CompletedProcess([], code, out, err)


class Recorder:
    def __init__(self, handler):
        self.handler = handler
        self.calls = []

    def __call__(self, cmd, cwd=None):
        self.calls.append((tuple(cmd), cwd))
        return self.handler(tuple(cmd), cwd)


def check(handler, repo_root, sha=SHA_A, url=URL):
    recorder = Recorder(handler)
    out = io.StringIO()
    with mock.patch.object(hook, "run", recorder), contextlib.redirect_stdout(out):
        ok = hook.check_submodule(sha, "sub", url, repo_root)
    return ok, out.getvalue(), recorder


class PrePushCheckTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = os.path.realpath(self.tmp.name)
        self.sub = os.path.join(self.root, "sub")
        os.mkdir(self.sub)

    def uninitialized(self, refs_out, refs_code=0):
        def handler(cmd, cwd):
            if cmd[:3] == ("git", "rev-parse", "--show-toplevel"):
                return cp(0, self.root + "\n")
            if cmd[:2] == ("git", "ls-remote"):
                return cp(refs_code, refs_out)
            return cp(1, "", "unexpected: %r" % (cmd,))
        return handler

    def test_pushed_commits_skips_deletions_and_duplicates(self):
        text = (
            f"refs/heads/x {SHA_A} refs/heads/x {'0' * 40}\n"
            f"refs/heads/y {SHA_A} refs/heads/y {'0' * 40}\n"
            f"(delete) {'0' * 40} refs/heads/old {SHA_B}\n"
            "garbage\n"
        )
        self.assertEqual(hook.pushed_commits(text), [SHA_A])

    def test_pins_come_from_the_pushed_commit(self):
        def handler(cmd, cwd):
            if cmd[:2] == ("git", "config"):
                return cp(0, "submodule.sub.path sub\nsubmodule.sub.url %s\n" % URL)
            if cmd[:2] == ("git", "ls-tree"):
                return cp(0, "160000 commit %s\tsub\n" % SHA_A)
            return cp(1)
        with mock.patch.object(hook, "run", Recorder(handler)):
            pins = hook.pins_for_commit(self.root, "c" * 40)
        self.assertEqual(pins, [(SHA_A, "sub", URL)])

    def test_empty_worktree_directory_uses_the_submodule_url_not_the_parent(self):
        ok, out, recorder = check(self.uninitialized("%s\trefs/heads/main\n" % SHA_A), self.root)
        self.assertTrue(ok, out)
        self.assertIn(("git", "ls-remote", URL), [c for c, _ in recorder.calls])
        self.assertNotIn(("git", "ls-remote", "origin"), [c for c, _ in recorder.calls])
        self.assertFalse([c for c, _ in recorder.calls if c[:3] == ("git", "config", "--get")])

    def test_missing_pin_fails_for_uninitialized_submodule(self):
        ok, out, _ = check(self.uninitialized("%s\trefs/heads/main\n" % SHA_B), self.root)
        self.assertFalse(ok)
        self.assertIn("FAIL", out)

    def test_relative_url_without_checkout_warns_and_skips(self):
        ok, out, _ = check(self.uninitialized(""), self.root, url="../sub.git")
        self.assertTrue(ok)
        self.assertIn("WARN", out)

    def initialized(self, tip_out, contained):
        def handler(cmd, cwd):
            if cmd[:3] == ("git", "rev-parse", "--show-toplevel"):
                return cp(0, self.sub + "\n")
            if cmd == ("git", "ls-remote", "origin"):
                return cp(0, tip_out)
            if cmd[:3] == ("git", "cat-file", "-e"):
                return cp(0)
            if cmd[:3] == ("git", "branch", "-r"):
                return cp(0, contained)
            return cp(1, "", "unexpected: %r" % (cmd,))
        return handler

    def test_initialized_non_tip_reachable_from_remote_branch_passes(self):
        ok, out, _ = check(self.initialized("%s\trefs/heads/main\n" % SHA_B, "  origin/main\n"), self.root)
        self.assertTrue(ok, out)

    def test_initialized_non_tip_not_reachable_fails(self):
        ok, out, _ = check(self.initialized("%s\trefs/heads/main\n" % SHA_B, ""), self.root)
        self.assertFalse(ok)

    def test_deletion_only_push_exits_zero(self):
        stdin = io.StringIO(f"(delete) {'0' * 40} refs/heads/old {SHA_B}\n")
        out = io.StringIO()
        with mock.patch.object(hook, "run", Recorder(lambda c, w: cp(0, self.root + "\n"))), \
                mock.patch("sys.stdin", stdin), contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as raised:
                hook.main()
        self.assertEqual(raised.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
