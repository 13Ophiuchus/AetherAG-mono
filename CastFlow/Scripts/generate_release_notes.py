#!/usr/bin/env python3

"""
Automatically generate release notes
from git history.
"""

import subprocess


def git(command):

    return subprocess.check_output(

        ["git"] + command,

        text=True,

    ).strip()


tag = ""

try:

    tag = git([
        "describe",
        "--tags",
        "--abbrev=0"
    ])

except Exception:

    tag = ""


if tag:

    commits = git([
        "log",
        f"{tag}..HEAD",
        "--pretty=format:- %s"
    ])

else:

    commits = git([
        "log",
        "--pretty=format:- %s"
    ])


print("# Release Notes\n")

print(commits)
