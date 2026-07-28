#!/usr/bin/env python3
"""
Common utility functions.

CastFlow Documentation Toolkit
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def project_root() -> Path:
    return ROOT


def run(command: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
    )


def success(message: str) -> None:
    print(f"✅ {message}")


def warning(message: str) -> None:
    print(f"⚠️  {message}")


def error(message: str) -> None:
    print(f"❌ {message}")


def fatal(message: str) -> None:
    error(message)
    sys.exit(1)


def json_output(data: dict) -> None:
    print(json.dumps(data, indent=4))


def executable_exists(name: str) -> bool:
    return shutil.which(name) is not None
