#!/usr/bin/env python3
"""Scan repo-owned source/doc files for production blockers.

Usage:
    python3 scripts/blocker_scan.py
    python3 scripts/blocker_scan.py --no-tests   # exclude Tests/ dirs
"""
import argparse
import os
import re
import sys

ROOTS = ["AGWallet", "AetherAG", "flow-swift-macos"]
PRUNE_DIRS = {".build", ".git", "DerivedData", "node_modules", ".swiftpm"}
INCLUDE_EXT = {".swift", ".md", ".yml", ".yaml"}
PATTERN = re.compile(
    r"TODO|FIXME|TBD|unsupportedOperation|fatalError|preconditionFailure|assertionFailure"
)


def scan(roots, exclude_tests=False):
    matches = []
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in PRUNE_DIRS]
            if exclude_tests:
                dirnames[:] = [d for d in dirnames if d.lower() != "tests"]
            for fname in filenames:
                ext = os.path.splitext(fname)[1]
                if ext not in INCLUDE_EXT:
                    continue
                path = os.path.join(dirpath, fname)
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        for lineno, line in enumerate(f, start=1):
                            if PATTERN.search(line):
                                matches.append((path, lineno, line.strip()))
                except OSError:
                    continue
    return matches


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-tests", action="store_true", help="Exclude Tests/ directories")
    parser.add_argument("--roots", nargs="*", default=ROOTS)
    args = parser.parse_args()

    print("== repo-owned blockers only ==")
    results = scan(args.roots, exclude_tests=args.no_tests)
    for path, lineno, line in results:
        print(f"{path}:{lineno}:{line}")
    print(f"\n-- total matches: {len(results)} --", file=sys.stderr)


if __name__ == "__main__":
    main()
