#!/usr/bin/env python3

"""
Checks that every public Swift declaration has documentation.

Simple heuristic.
"""

from pathlib import Path
import re
import sys

PUBLIC_PATTERN = re.compile(r"^\s*public\s", re.MULTILINE)


def documented(lines, index):

    start = max(0, index - 3)

    return any(lines[i].strip().startswith("///")
               for i in range(start, index))


missing = []

for swift in Path("Sources").rglob("*.swift"):

    lines = swift.read_text(
        encoding="utf-8",
        errors="ignore"
    ).splitlines()

    for idx, line in enumerate(lines):

        if PUBLIC_PATTERN.match(line):

            if not documented(lines, idx):
                missing.append(
                    f"{swift}:{idx+1}"
                )

if missing:

    print("Missing API Documentation\n")

    for item in missing:
        print(item)

    sys.exit(1)

print("✓ Public APIs documented")
