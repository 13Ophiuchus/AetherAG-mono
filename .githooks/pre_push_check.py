#!/usr/bin/env python3
"""pre-push: verify every pinned submodule commit is reachable from origin."""

from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile


def run(cmd, cwd=None):
    env = os.environ.copy()
    for key in (
        "GIT_DIR",
        "GIT_WORK_TREE",
        "GIT_COMMON_DIR",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_PREFIX",
    ):
        env.pop(key, None)

    return subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
    )


def get_submodules(repo_root):
    result = run(["git", "submodule", "status"], cwd=repo_root)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        return None

    submodules = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue

        match = re.match(r"^[+\-U ]?([0-9a-f]{40})\s+(\S+)", line)
        if match:
            submodules.append(match.groups())

    return submodules


def remote_url(repo_path):
    result = run(["git", "config", "--get", "remote.origin.url"], cwd=repo_path)
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return result.stdout.strip()


def check_submodule(sha, path, repo_root):
    repo_path = Path(repo_root) / path

    if not repo_path.is_dir():
        print(f"  FAIL: {path} is not initialized or is missing")
        return False

    origin = remote_url(repo_path)
    if not origin:
        print(f"  FAIL: {path} has no origin remote configured")
        return False

    with tempfile.TemporaryDirectory(prefix="submodule-origin-check-") as temp_dir:
        temp_repo = Path(temp_dir) / "repo.git"

        init = run(["git", "init", "--bare", str(temp_repo)])
        if init.returncode != 0:
            print(f"  FAIL: {path} could not create temporary repository")
            return False

        fetch = run(
            [
                "git",
                "-C",
                str(temp_repo),
                "fetch",
                "--quiet",
                "--no-tags",
                origin,
                "+refs/heads/*:refs/remotes/origin/*",
            ]
        )
        if fetch.returncode != 0:
            message = fetch.stderr.strip() or fetch.stdout.strip() or "unknown fetch error"
            print(f"  FAIL: {path} could not fetch origin ({message})")
            return False

        refs = run(
            [
                "git",
                "-C",
                str(temp_repo),
                "for-each-ref",
                "--format=%(refname)",
                "refs/remotes/origin",
            ]
        )
        if refs.returncode != 0:
            print(f"  FAIL: {path} could not enumerate fetched origin refs")
            return False

        for ref in refs.stdout.splitlines():
            if not ref.strip():
                continue

            ancestor = run(
                ["git", "-C", str(temp_repo), "merge-base", "--is-ancestor", sha, ref]
            )
            if ancestor.returncode == 0:
                print(f"  OK:   {path} @ {sha[:8]} reachable via {ref}")
                return True
            if ancestor.returncode not in (0, 1):
                message = ancestor.stderr.strip() or "unknown ancestry-check error"
                print(f"  FAIL: {path} could not inspect {ref} ({message})")
                return False

    print(f"  FAIL: {path} @ {sha[:8]} is NOT reachable from origin")
    print("        Push the submodule commit to an origin branch, then retry.")
    return False


def main():
    root = run(["git", "rev-parse", "--show-toplevel"])
    if root.returncode != 0:
        print(root.stderr, file=sys.stderr)
        return 1

    repo_root = root.stdout.strip()
    print("pre-push: verifying submodule sync...")

    submodules = get_submodules(repo_root)
    if submodules is None:
        return 1
    if not submodules:
        print("pre-push: no submodules found, OK")
        return 0

    all_ok = True
    for sha, path in submodules:
        if not check_submodule(sha, path, repo_root):
            all_ok = False

    if not all_ok:
        print("\npre-push: ABORTED — one or more pinned submodule commits are unavailable on origin.")
        return 1

    print("pre-push: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
