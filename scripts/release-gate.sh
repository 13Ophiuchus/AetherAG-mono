#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/nicreich/AetherAG-mono"

echo "== repo status =="
git -C "$ROOT" status --short

echo
echo "== AGWallet build/test =="
cd "$ROOT/AGWallet"
swift build
swift test || true

echo
echo "== AetherAG build/test =="
cd "$ROOT/AetherAG"
swift build
swift test

echo
echo "== open milestones =="
grep -Rni '^- \\[\\]' "$ROOT/AGWallet/MILESTONES.md" "$ROOT/AetherAG/MILESTONES.md" 2>/dev/null || true

echo
echo "== production blockers scan =="
grep -RniE 'TODO|FIXME|TBD|unsupportedOperation|fatalError' \
"$ROOT/AGWallet" "$ROOT/AetherAG" \
--include='*.swift' --include='*.md' | head -400 || true

echo
echo "== done =="
