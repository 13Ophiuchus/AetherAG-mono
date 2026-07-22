#!/usr/bin/env python3
import os
import re
import stat
import sys
from pathlib import Path

TARGET_GLOB = "**/flow-swift-macos/Package.swift"
OLD = ".iOS(.v15)"
NEW = ".iOS(.v16)"

def ensure_user_writable(path: Path) -> None:
    mode = path.stat().st_mode
    if not (mode & stat.S_IWUSR):
        path.chmod(mode | stat.S_IWUSR)

def patch_manifest(path: Path) -> str:
    ensure_user_writable(path)
    text = path.read_text()
    if NEW in text:
        return f"OK already updated: {path}"
    if OLD not in text:
        return f"SKIP no {OLD}: {path}"
    updated = text.replace(OLD, NEW)
    path.write_text(updated)
    return f"FIXED {OLD} -> {NEW}: {path}"

def main() -> int:
    repo_root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    matches = sorted(repo_root.glob(TARGET_GLOB))
    if not matches:
        print("INFO no matching flow-swift-macos/Package.swift files found")
        return 0

    print(f"Found {len(matches)} manifest(s):")
    changed = 0
    for path in matches:
        result = patch_manifest(path)
        print(f"  - {result}")
        if result.startswith("FIXED"):
            changed += 1

    print("")
    print(f"Updated {changed} manifest(s).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
