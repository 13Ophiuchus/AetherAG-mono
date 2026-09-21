#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent

excluded_directories = {
    ".git",
    ".build",
    "DerivedData",
    "artifacts",
    "Packages",
}

blocking_patterns = [
    re.compile(
        r'\b(?:print|debugPrint)\s*\(\s*(?:self\.)?'
        r'(?:mnemonic|mnemonics|seed|seedPhrase|privateKey|privateKeys)\b',
        re.IGNORECASE,
    ),
    re.compile(
        r'\b(?:print|debugPrint|log\.(?:debug|info|notice|warning|error)|'
        r'logger\.(?:debug|info|notice|warning|error))'
        r'\s*\([^)]*\\\('
        r'(?:self\.)?(?:mnemonic|mnemonics|seed|seedPhrase|privateKey|privateKeys)\b',
        re.IGNORECASE,
    ),
]

review_patterns = [
    re.compile(r'\b(?:mnemonic|seed phrase|seedPhrase|privateKey)\b', re.IGNORECASE),
]

blocking_hits: list[str] = []
review_hits: list[str] = []

for path in root.rglob("*.swift"):
    if any(part in excluded_directories for part in path.parts):
        continue

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    for line_number, line in enumerate(text.splitlines(), start=1):
        record = f"{path.relative_to(root)}:{line_number}: {line.strip()}"

        if any(pattern.search(line) for pattern in blocking_patterns):
            blocking_hits.append(record)
        elif (
            "Tests" not in path.parts
            and "Example" not in path.parts
            and "Examples" not in path.parts
            and any(pattern.search(line) for pattern in review_patterns)
        ):
            review_hits.append(record)

if review_hits and "--verbose" in sys.argv:
    print("Sensitive-term review findings:", file=sys.stderr)
    print("\n".join(review_hits), file=sys.stderr)

if blocking_hits:
    print("\nBlocking secret-logging findings:", file=sys.stderr)
    print("\n".join(blocking_hits), file=sys.stderr)
    sys.exit(1)

print("Sensitive logging scan passed: no direct secret-value logging detected.")
