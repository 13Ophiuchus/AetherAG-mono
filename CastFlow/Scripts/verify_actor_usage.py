#!/usr/bin/env python3

"""
Verifies services use actors.
"""

from pathlib import Path
import re
import sys

ACTOR = re.compile(r"\bactor\b")

errors = []

for file in Path("Sources").rglob("*Service.swift"):

    text = file.read_text()

    if not ACTOR.search(text):

        errors.append(file)

if errors:

    print("Service should be actors")

    for e in errors:
        print(e)

    sys.exit(1)

print("✓ Actor isolation verified")
