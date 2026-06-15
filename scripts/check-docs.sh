#!/usr/bin/env bash
set -euo pipefail

echo "==> markdownlint"
markdownlint README.md . --ignore .build --ignore .git --ignore node_modules --ignore Package.resolved

echo "==> optional mkdocs build"
if [[ -f mkdocs.yml ]]; then
  mkdocs build --strict
else
  echo "mkdocs.yml not found; skipping docs site build"
fi
