#!/usr/bin/env python3

"""
Checks repository architecture.

Ensures expected top-level folders exist.
"""

from pathlib import Path
import sys

from lib.report import Report
from lib.utils import project_root


EXPECTED = [

    "Sources",

    "Tests",

    "Documentation",

    "Scripts",

    "Plugins",

    ".github",

]


def main():

    root = project_root()

    report = Report()

    for directory in EXPECTED:

        if (root / directory).exists():

            report.ok(directory)

        else:

            report.fail(directory)

    report.print()

    sys.exit(0 if report.success else 1)


if __name__ == "__main__":

    main()
