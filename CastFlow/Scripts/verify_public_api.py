#!/usr/bin/env python3

"""
Prevent accidental public API growth.
"""

from pathlib import Path
import re
import json

PUBLIC = re.compile(r"\bpublic\b")

apis = {}

for file in Path("Sources").rglob("*.swift"):

    count = len(
        PUBLIC.findall(
            file.read_text(
                encoding="utf8",
                errors="ignore"
            )
        )
    )

    if count:

        apis[str(file)] = count

print(json.dumps(apis, indent=4))
