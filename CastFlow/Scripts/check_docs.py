#!/usr/bin/env python3

"""
Verifies required repository documentation.

Exit 0 = success

Exit 1 = missing documentation
"""

from pathlib import Path
import sys

from lib.filesystem import Repository
from lib.report import Report
from lib.utils import project_root


REQUIRED = [

    "README.md",

    "ROADMAP.md",

    "MILESTONES.md",

    "CONTRIBUTING.md",

    "SECURITY.md",

    "CHANGELOG.md",

]


def main():

    repo = Repository(project_root())

    report = Report()

    for filename in REQUIRED:

        if repo.exists(filename):

            report.ok(filename)

        else:

            report.fail(filename)

    report.print()

    sys.exit(0 if report.success else 1)


if __name__ == "__main__":

    main()
