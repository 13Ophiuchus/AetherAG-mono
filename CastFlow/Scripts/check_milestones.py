#!/usr/bin/env python3

"""
Verifies roadmap and milestones stay synchronized.
"""

from pathlib import Path
import re
import sys


ROADMAP = Path("ROADMAP.md")

MILESTONES = Path("MILESTONES.md")


phase_pattern = re.compile(
    r"Phase\s+\d+",
    re.IGNORECASE
)

milestone_pattern = re.compile(
    r"Milestone\s+\d+",
    re.IGNORECASE
)


roadmap = phase_pattern.findall(
    ROADMAP.read_text()
)

milestones = milestone_pattern.findall(
    MILESTONES.read_text()
)

if len(roadmap) != len(milestones):

    print("Roadmap and Milestones differ.")

    print(len(roadmap))

    print(len(milestones))

    sys.exit(1)

print("✓ Milestones synchronized")
