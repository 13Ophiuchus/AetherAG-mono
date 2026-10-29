#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/.artifacts/production-diagnostics/$STAMP"
FAILED=0

mkdir -p "$OUT"
cd "$ROOT"

run() {
  local label="$1"
  shift

  echo
  echo "==> $label"
  "$@" 2>&1 | tee "$OUT/$label.log"
  local status="${PIPESTATUS[0]}"

  if [ "$status" -ne 0 ]; then
    printf 'FAILED: %s (exit %s)\n' "$label" "$status" | tee -a "$OUT/summary.log"
    FAILED=1
  else
    printf 'PASSED: %s\n' "$label" | tee -a "$OUT/summary.log"
  fi
}

run state python3 scripts/discover_state.py
run baseline python3 scripts/production_baseline_audit.py
run readiness python3 scripts/production_readiness_audit.py
run sensitive-logging python3 scripts/check_sensitive_logging.py
run migration python3 scripts/check_module_migration.py
run milestones python3 scripts/sync_milestones.py --check

printf '\nArtifacts: %s\n' "$OUT"
exit "$FAILED"
