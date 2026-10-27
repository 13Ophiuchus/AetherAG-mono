#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

python3 scripts/discover_state.py

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
cp reports/current-state.md "reports/current-state-${timestamp}.md"
cp reports/current-state.json "reports/current-state-${timestamp}.json"

printf '\nDiscovery complete:\n'
printf '  %s\n' "reports/current-state.md"
printf '  %s\n' "reports/current-state.json"
printf '  %s\n' "reports/current-state-${timestamp}.md"
printf '  %s\n' "reports/current-state-${timestamp}.json"
