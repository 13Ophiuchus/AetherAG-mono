#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS="$ROOT/artifacts"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$ARTIFACTS/security-baseline-$STAMP.txt"

mkdir -p "$ARTIFACTS"

{
  printf 'generated_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'superproject_commit=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
  printf '\n[superproject_status]\n'
  git -C "$ROOT" status --short
  printf '\n[submodules]\n'
  git -C "$ROOT" submodule status --recursive
  printf '\n[sensitive_logging_scanner]\n'
  python3 "$ROOT/scripts/check_sensitive_logging.py"
} > "$REPORT" 2>&1

printf 'Evidence report: %s\n' "$REPORT"
tail -n 40 "$REPORT"
