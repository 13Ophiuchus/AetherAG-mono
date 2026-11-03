#!/usr/bin/env bash
set -euo pipefail

echo "==> markdownlint"
python3 - <<'PYTHON'
import os
import subprocess

tracked = subprocess.check_output(
    ["git", "ls-files", "-z", "--", "*.md"]
)
paths = [os.fsdecode(item) for item in tracked.split(b"\0") if item]
if not paths:
    raise SystemExit("No tracked Markdown files found")
print(f"Linting {len(paths)} tracked Markdown files", flush=True)
subprocess.run(["markdownlint", "--", *paths], check=True)
PYTHON

echo "==> optional mkdocs build"
if [[ -f mkdocs.yml ]]; then
  mkdocs build --strict
else
  echo "mkdocs.yml not found; skipping docs site build"
fi
