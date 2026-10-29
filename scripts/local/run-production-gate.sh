#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this script from inside the AetherAG Git worktree." >&2
  exit 1
}
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/.artifacts/production-gate/$STAMP"

mkdir -p "$OUT"
cd "$ROOT"

run() {
  local label="$1"
  shift
  echo
  echo "==> $label"
  "$@" 2>&1 | tee "$OUT/$label.log"
}

run state python3 scripts/discover_state.py
run baseline python3 scripts/production_baseline_audit.py
run readiness python3 scripts/production_readiness_audit.py
run sensitive-logging python3 scripts/check_sensitive_logging.py
run migration python3 scripts/check_module_migration.py
run milestones python3 scripts/sync_milestones.py --check

echo
echo "Artifacts: $OUT"
