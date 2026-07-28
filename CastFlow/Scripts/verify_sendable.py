#!/usr/bin/env python3

"""
Checks that models conform to Sendable.

Heuristic only.
"""

from pathlib import Path
import re
import sys

MODEL = re.compile(r"\b(struct|class|enum)\s+(\w+)")

sendable = re.compile(r"Sendable")

errors = []

for file in Path("Sources").rglob("*.swift"):

    if "Models" not in file.parts:
        continue

    text = file.read_text(
        encoding="utf8",
        errors="ignore"
    )

    if MODEL.search(text):

        if not sendable.search(text):

            errors.append(file)

if errors:

    print("Missing Sendable:")

    for e in errors:

        print(e)

    sys.exit(1)

print("✓ Sendable validation passed")
