#!/usr/bin/env python3
"""pre-push: verify every submodule's pinned commit exists on its remote."""
import subprocess
import sys
import re

def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)

def get_submodules(repo_root):
    result = run(["git", "submodule", "status"], cwd=repo_root)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)

    submodules = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        match = re.match(r"^[+\-U ]?([0-9a-f]{40})\s+(\S+)", line)
        if not match:
            continue
        sha, path = match.groups()
        submodules.append((sha, path))
    return submodules

def check_submodule(sha, path, repo_root):
    full_path = f"{repo_root}/{path}"

    remote = run(["git", "config", "--get", "remote.origin.url"], cwd=full_path)
    if remote.returncode != 0 or not remote.stdout.strip():
        print(f"  WARN: {path} has no origin remote configured, skipping")
        return True

    ls_remote = run(["git", "ls-remote", "origin"], cwd=full_path)
    if ls_remote.returncode != 0:
        print(f"  WARN: {path} could not reach origin ({ls_remote.stderr.strip()}), skipping")
        return True

    if sha in ls_remote.stdout:
        print(f"  OK:   {path} @ {sha[:8]}")
        return True

    print(f"  FAIL: {path} @ {sha[:8]} is NOT on origin — push it before pushing the parent")
    print(f"        fix: (cd {path} && git push origin HEAD)")
    return False

def main():
    repo_root_result = run(["git", "rev-parse", "--show-toplevel"])
    repo_root = repo_root_result.stdout.strip()

    print("pre-push: verifying submodule sync...")

    submodules = get_submodules(repo_root)
    if not submodules:
        print("pre-push: no submodules found, OK")
        sys.exit(0)

    all_ok = True
    for sha, path in submodules:
        if not check_submodule(sha, path, repo_root):
            all_ok = False

    if not all_ok:
        print("\npre-push: ABORTED — one or more submodules have unpushed commits pinned in the parent.")
        sys.exit(1)

    print("pre-push: OK")
    sys.exit(0)

if __name__ == "__main__":
    main()
