from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import shutil
import subprocess
import sys
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
ZERO = "0" * 40
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
            if cmd[:2] == ("git", "ls-remote"):
                return cp(refs_code, refs_out)
            return cp(1, "", "unexpected: %r" % (cmd,))
        return handler

    def initialized(self, tip_out, contained):
        Path(self.sub, ".git").write_text("gitdir: ../.git/modules/sub\n")

        def handler(cmd, cwd):
            if cmd == ("git", "ls-remote", "origin"):
                return cp(0, tip_out)
            if cmd[:3] == ("git", "cat-file", "-e"):
                return cp(0)
            if cmd[:3] == ("git", "branch", "-r"):
                return cp(0, contained)
            return cp(1, "", "unexpected: %r" % (cmd,))
        return handler

    def test_pushed_commits_skips_deletions_and_duplicates(self):
        text = (
            f"refs/heads/x {SHA_A} refs/heads/x {ZERO}\n"
            f"refs/heads/y {SHA_A} refs/heads/y {ZERO}\n"
            f"(delete) {ZERO} refs/heads/old {SHA_B}\n"
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

    def test_empty_directory_is_not_initialized(self):
        self.assertFalse(hook.is_initialized(self.root, "sub"))

    def test_directory_with_git_entry_is_initialized(self):
        Path(self.sub, ".git").write_text("gitdir: ../.git/modules/sub\n")
        self.assertTrue(hook.is_initialized(self.root, "sub"))

    def test_missing_directory_is_not_initialized(self):
        self.assertFalse(hook.is_initialized(self.root, "does-not-exist"))

    def test_empty_worktree_directory_uses_the_submodule_url_not_the_parent(self):
        ok, out, recorder = check(self.uninitialized("%s\trefs/heads/main\n" % SHA_A), self.root)
        self.assertTrue(ok, out)
        self.assertIn(("git", "ls-remote", URL), [c for c, _ in recorder.calls])
        self.assertNotIn(("git", "ls-remote", "origin"), [c for c, _ in recorder.calls])

    def test_missing_pin_fails_for_uninitialized_submodule(self):
        ok, out, _ = check(self.uninitialized("%s\trefs/heads/main\n" % SHA_B), self.root)
        self.assertFalse(ok)
        self.assertIn("FAIL", out)

    def test_relative_url_without_checkout_warns_and_skips(self):
        ok, out, _ = check(self.uninitialized(""), self.root, url="../sub.git")
        self.assertTrue(ok)
        self.assertIn("WARN", out)

    def test_initialized_non_tip_reachable_from_remote_branch_passes(self):
        ok, out, _ = check(self.initialized("%s\trefs/heads/main\n" % SHA_B, "  origin/main\n"), self.root)
        self.assertTrue(ok, out)

    def test_initialized_non_tip_not_reachable_fails(self):
        ok, out, _ = check(self.initialized("%s\trefs/heads/main\n" % SHA_B, ""), self.root)
        self.assertFalse(ok)

    def test_deletion_only_push_exits_zero(self):
        stdin = io.StringIO(f"(delete) {ZERO} refs/heads/old {SHA_B}\n")
        out = io.StringIO()
        with mock.patch.object(hook, "run", Recorder(lambda c, w: cp(0, self.root + "\n"))), \
                mock.patch("sys.stdin", stdin), contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as raised:
                hook.main()
        self.assertEqual(raised.exception.code, 0)

    def test_child_git_processes_do_not_inherit_repository_location(self):
        leaked = {
            "GIT_DIR": "/leak/dir",
            "GIT_WORK_TREE": "/leak/tree",
            "GIT_INDEX_FILE": "/leak/index",
            "GIT_COMMON_DIR": "/leak/common",
            "KEEP_ME": "yes",
        }
        captured = {}

        def fake_run(cmd, **kwargs):
            captured.update(kwargs)
            return cp(0)

        with mock.patch.dict(os.environ, leaked), mock.patch.object(hook.subprocess, "run", fake_run):
            hook.run(["git", "status"], cwd=self.root)
        env = captured["env"]
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
            self.assertNotIn(name, env)
        self.assertEqual(env.get("KEEP_ME"), "yes")


@unittest.skipUnless(shutil.which("git"), "git is required")
class RealGitHookTests(unittest.TestCase):
    """Runs the hook as git does: a subprocess with repository-location variables exported."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = os.path.realpath(self.tmp.name)
        self.env = {
            **os.environ,
            "HOME": self.base,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid",
            "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid",
        }
        for name in hook.REPO_LOCATION_VARIABLES:
            self.env.pop(name, None)

        self.git("init", "-q", "--bare", "sub.git", cwd=self.base)
        self.git("init", "-q", "-b", "main", "subsrc", cwd=self.base)
        src = os.path.join(self.base, "subsrc")
        Path(src, "f").write_text("x\n")
        self.git("add", "f", cwd=src)
        self.git("commit", "-q", "-m", "c", cwd=src)
        self.git("remote", "add", "origin", os.path.join(self.base, "sub.git"), cwd=src)
        self.git("push", "-q", "origin", "main", cwd=src)
        self.pin = self.git("rev-parse", "HEAD", cwd=src).stdout.strip()

        self.parent = os.path.join(self.base, "parent")
        self.git("init", "-q", "-b", "main", "parent", cwd=self.base)
        Path(self.parent, ".gitmodules").write_text(
            '[submodule "sub"]\n\tpath = sub\n\turl = file://%s\n' % os.path.join(self.base, "sub.git")
        )
        self.git("add", ".gitmodules", cwd=self.parent)
        os.mkdir(os.path.join(self.parent, "sub"))

    def git(self, *args, cwd):
        result = subprocess.run(["git", *args], cwd=cwd, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def commit_pin(self, sha):
        self.git("update-index", "--add", "--cacheinfo", "160000,%s,sub" % sha, cwd=self.parent)
        self.git("commit", "-q", "-m", "pin", cwd=self.parent)
        return self.git("rev-parse", "HEAD", cwd=self.parent).stdout.strip()

    def run_hook(self, commit, with_git_dir):
        env = dict(self.env)
        if with_git_dir:
            env["GIT_DIR"] = os.path.join(self.parent, ".git")
        stdin = "refs/heads/main %s refs/heads/main %s\n" % (commit, ZERO)
        return subprocess.run(
            [sys.executable, "-I", "-B", str(HOOK)],
            cwd=self.parent, env=env, input=stdin, capture_output=True, text=True,
        )

    def test_valid_pin_passes_with_and_without_git_dir_exported(self):
        commit = self.commit_pin(self.pin)
        for with_git_dir in (False, True):
            result = self.run_hook(commit, with_git_dir)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("OK:", result.stdout)

    def test_unpublished_pin_fails_with_and_without_git_dir_exported(self):
        commit = self.commit_pin("c" * 40)
        for with_git_dir in (False, True):
            result = self.run_hook(commit, with_git_dir)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("FAIL:", result.stdout)


if __name__ == "__main__":
    unittest.main()
