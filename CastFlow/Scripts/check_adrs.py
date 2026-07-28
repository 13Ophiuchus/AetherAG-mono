#!/usr/bin/env python3

"""
Checks ADR directory.

Architecture Decision Records
"""

from pathlib import Path
import sys

from lib.report import Report
from lib.utils import project_root


def main():

    report = Report()

    adr_dir = project_root() / "Documentation" / "ADR"

    if not adr_dir.exists():

        report.fail("ADR directory missing")

    else:

        docs = list(adr_dir.glob("ADR-*.md"))

        if docs:

            report.ok(f"{len(docs)} ADRs found")

        else:

            report.warn("No ADRs yet")

    report.print()

    sys.exit(0 if report.success else 1)


if __name__ == "__main__":

    main()
