#!/usr/bin/env python3

"""
Checks internal markdown links.
"""

from pathlib import Path
import re
import sys


LINK = re.compile(
    r"\[[^\]]+\]\(([^)]+)\)"
)

errors = []

for md in Path(".").rglob("*.md"):

    text = md.read_text(
        encoding="utf-8",
        errors="ignore"
    )

    for link in LINK.findall(text):

        if link.startswith("http"):
            continue

        if link.startswith("#"):
            continue

        target = (md.parent / link).resolve()

        if not target.exists():
            errors.append(
                f"{md} -> {link}"
            )

if errors:

    print("Broken links:\n")

    for error in errors:
        print(error)

    sys.exit(1)

print("✓ Links verified")
