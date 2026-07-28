#!/usr/bin/env python3

"""
Ensure CHANGELOG contains Unreleased section.
"""

from pathlib import Path
import sys

text = Path("CHANGELOG.md").read_text()

if "## [Unreleased]" not in text:

    print("CHANGELOG missing Unreleased section")

    sys.exit(1)

print("✓ Changelog verified")
