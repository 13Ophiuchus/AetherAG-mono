#!/usr/bin/env python3
"""
verify_module_boundaries.py

Ensures feature modules do not import forbidden modules.

Architecture Enforcement

Author: CastFlow
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Allowed dependency graph
#
# UI
#  ↓
# App
#  ↓
# Core
#  ↓
# Networking
#  ↓
# Media
#  ↓
# Rendering
#

FORBIDDEN = {

    "UI": [
        "Rendering",
        "Networking",
        "Security",
    ],

    "Rendering": [
        "UI",
    ],

    "Media": [
        "UI",
    ],
}

IMPORT = re.compile(r"^\s*import\s+([A-Za-z0-9_]+)", re.MULTILINE)

errors = []


def module_name(path: Path):

    parts = path.parts

    if "Sources" not in parts:
        return None

    idx = parts.index("Sources")

    if idx + 1 >= len(parts):
        return None

    return parts[idx + 1]


for swift in Path("Sources").rglob("*.swift"):

    module = module_name(swift)

    if module is None:
        continue

    imports = IMPORT.findall(
        swift.read_text(
            encoding="utf8",
            errors="ignore"
        )
    )

    forbidden = FORBIDDEN.get(module, [])

    for imported in imports:

        if imported in forbidden:

            errors.append(
                f"{swift}: {module} imports forbidden module {imported}"
            )

if errors:

    print()

    print("Architecture Violations")

    print("-----------------------")

    for e in errors:
        print(e)

    sys.exit(1)

print("✓ Module boundaries verified")
