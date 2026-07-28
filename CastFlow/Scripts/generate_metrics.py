#!/usr/bin/env python3

"""
Repository Metrics Generator
"""

from pathlib import Path
import json


metrics = {

    "swift_files": 0,
    "python_files": 0,
    "markdown_files": 0,
    "lines_of_swift": 0,
    "lines_of_python": 0,
    "lines_of_markdown": 0,

}


for file in Path(".").rglob("*"):

    if not file.is_file():
        continue

    suffix = file.suffix.lower()

    try:

        lines = len(
            file.read_text(
                encoding="utf-8",
                errors="ignore"
            ).splitlines()
        )

    except Exception:

        continue

    if suffix == ".swift":

        metrics["swift_files"] += 1
        metrics["lines_of_swift"] += lines

    elif suffix == ".py":

        metrics["python_files"] += 1
        metrics["lines_of_python"] += lines

    elif suffix == ".md":

        metrics["markdown_files"] += 1
        metrics["lines_of_markdown"] += lines


print(json.dumps(metrics, indent=4))
