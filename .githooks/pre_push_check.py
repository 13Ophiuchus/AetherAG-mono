#!/usr/bin/env python3
"""pre-push: verify every submodule commit pinned by the pushed commits exists on its remote."""
import os
import re
import subprocess
import sys

ZERO_SHA = "0" * 40


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def pushed_commits(stdin_text):
    commits = []
    for line in stdin_text.splitlines():
        parts = line.split()
        if len(parts) != 4:
            continue
        local_sha = parts[1]
        if local_sha == ZERO_SHA or local_sha in commits:
            continue
        commits.append(local_sha)
    return commits


def submodule_config(repo_root, commit):
    """Return {path: url} from the .gitmodules recorded in the pushed commit."""
    result = run(
        ["git", "config", "--blob", f"{commit}:.gitmodules",
         "--get-regexp", r"^submodule\..*\.(path|url)$"],
        cwd=repo_root,
    )
    if result.returncode != 0:
        return {}
    entries = {}
    for line in result.stdout.splitlines():
        key, _, value = line.partition(" ")
        match = re.match(r"^submodule\.(.+)\.(path|url)$", key)
        if match:
            entries.setdefault(match.group(1), {})[match.group(2)] = value.strip()
    return {e["path"]: e.get("url", "") for e in entries.values() if "path" in e}


def pins_for_commit(repo_root, commit):
    """Return [(sha, path, url)] for every submodule pinned by the commit."""
    config = submodule_config(repo_root, commit)
    if not config:
        return []
    result = run(["git", "ls-tree", commit, "--"] + sorted(config), cwd=repo_root)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    pins = []
    for line in result.stdout.splitlines():
        match = re.match(r"^160000 commit ([0-9a-f]{40})\t(.+)$", line)
        if match:
            sha, path = match.groups()
            pins.append((sha, path, config.get(path, "")))
    return pins


def is_initialized(repo_root, path):
    """True only when path is its own git checkout, not an empty dir inside the parent."""
    full = os.path.join(repo_root, path)
    if not os.path.isdir(full):
        return False
    result = run(["git", "rev-parse", "--show-toplevel"], cwd=full)
    return (
        result.returncode == 0
        and os.path.realpath(result.stdout.strip()) == os.path.realpath(full)
    )


def remote_refs(repo_root, path, url, initialized):
    full = os.path.join(repo_root, path)
    if initialized:
        result = run(["git", "ls-remote", "origin"], cwd=full)
    elif "://" in url or re.match(r"^[\w.-]+@[\w.-]+:", url):
        result = run(["git", "ls-remote", url], cwd=repo_root)
    else:
        return None, "uninitialized submodule without an absolute URL"
    if result.returncode != 0:
        return None, result.stderr.strip()
    return result.stdout, ""


def check_submodule(sha, path, url, repo_root):
    initialized = is_initialized(repo_root, path)
    refs, error = remote_refs(repo_root, path, url, initialized)
    if refs is None:
        print(f"  WARN: {path} @ {sha[:8]} could not be verified ({error}), skipping")
        return True

    if sha in refs:
        print(f"  OK:   {path} @ {sha[:8]}")
        return True

    if initialized:
        full = os.path.join(repo_root, path)
        has_commit = run(["git", "cat-file", "-e", f"{sha}^{{commit}}"], cwd=full).returncode == 0
        contained = run(["git", "branch", "-r", "--contains", sha], cwd=full).stdout.strip()
        if has_commit and contained:
            print(f"  OK:   {path} @ {sha[:8]} (reachable from a remote branch)")
            return True

    print(f"  FAIL: {path} @ {sha[:8]} was not found on origin")
    print(f"        fix: push that commit from the {path} submodule checkout first")
    return False


def main():
    repo_root = run(["git", "rev-parse", "--show-toplevel"]).stdout.strip()
    stdin_text = "" if sys.stdin.isatty() else sys.stdin.read()
    commits = pushed_commits(stdin_text)

    if stdin_text.strip() and not commits:
        print("pre-push: only deletions pushed, nothing to verify, OK")
        sys.exit(0)
    if not commits:
        head = run(["git", "rev-parse", "HEAD"], cwd=repo_root).stdout.strip()
        commits = [head] if head else []

    print("pre-push: verifying submodule pins of the pushed commits...")
    pins, seen = [], set()
    for commit in commits:
        for sha, path, url in pins_for_commit(repo_root, commit):
            if (sha, path) not in seen:
                seen.add((sha, path))
                pins.append((sha, path, url))

    if not pins:
        print("pre-push: no submodules pinned, OK")
        sys.exit(0)

    all_ok = True
    for sha, path, url in pins:
        if not check_submodule(sha, path, url, repo_root):
            all_ok = False

    if not all_ok:
        print("\npre-push: ABORTED - a submodule commit pinned by the pushed commits is not on origin.")
        sys.exit(1)

    print("pre-push: OK")
    sys.exit(0)


if __name__ == "__main__":
    main()
