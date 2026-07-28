#!/usr/bin/env python3

"""
Verify that documentation contains runnable examples.

Usage:
    python3 Scripts/check_examples.py
"""

from pathlib import Path
import re
import sys

EXAMPLE_PATTERN = re.compile(r"```(?:swift|bash|python|json|yaml)", re.IGNORECASE)


def main():

    docs = list(Path(".").rglob("*.md"))

    failures = []

    for doc in docs:

        if ".git" in doc.parts:
            continue

        text = doc.read_text(encoding="utf-8", errors="ignore")

        if "Guide" in doc.name or "README" in doc.name:

            if not EXAMPLE_PATTERN.search(text):
                failures.append(doc)

    if failures:

        print("Missing examples:\n")

        for file in failures:
            print(file)

        sys.exit(1)

    print("✓ Documentation examples verified")


if __name__ == "__main__":
    main()
