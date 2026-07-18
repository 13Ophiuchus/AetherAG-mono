#!/bin/zsh
# Diagnose all compiler warnings from an AetherAG build log.
# Usage: ./diagnose_warnings.sh [path-to-build-log]
set -euo pipefail
LOG="${1:-/tmp/aetherag_build.log}"

if [[ ! -f "$LOG" ]]; then
  echo "Build log not found at $LOG. Run: swift build 2>&1 | tee $LOG" >&2
  exit 1
fi

echo "=== Warning count by package ==="
grep -oE '^/Users/[^:]+' "$LOG" | grep -oE '/AetherAG-mono/[^/]+' | sort | uniq -c | sort -rn

echo
echo "=== Warning count by file ==="
grep -E '^/Users.*: warning:' "$LOG" | sed -E 's/^([^:]+):.*/\1/' | sort | uniq -c | sort -rn

echo
echo "=== Distinct warning messages ==="
grep -E '^/Users.*: warning:' "$LOG" | sed -E 's/^[^:]+:[0-9]+:[0-9]+: warning: //' | sort -u

echo
echo "=== Full warning locations (file:line:col: message) ==="
grep -E '^/Users.*: warning:' "$LOG" | sort -u
