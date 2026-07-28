#!/usr/bin/env python3

"""
Validate semantic version tags.
"""

import re
import subprocess
import sys

SEMVER = re.compile(r"^v\d+\.\d+\.\d+$")

tags = subprocess.check_output(
    ["git", "tag"],
    text=True
).splitlines()

bad = []

for tag in tags:

    if not SEMVER.match(tag):

        bad.append(tag)

if bad:

    print("Invalid tags:")

    print("\n".join(bad))

    sys.exit(1)

print("✓ Semantic Versioning OK")
