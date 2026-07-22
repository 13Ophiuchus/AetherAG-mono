#!/bin/zsh
# One-shot: revert the WORKSPACE= line in simulator_smoke_test.sh back to
# the portable ${REPO_ROOT}/Aether.xcworkspace expression (the earlier
# regex patch incorrectly hardcoded an absolute path). Keep the SCHEME=
# change (AetherAGMailClientAppShell), which is correct.
set -euo pipefail

SMOKE_SCRIPT="/Users/nicreich/AetherAG-mono/AetherAG/scripts/simulator_smoke_test.sh"

python3 - <<PYEOF
from pathlib import Path

path = Path("${SMOKE_SCRIPT}")
text = path.read_text()
original = text

bad = 'WORKSPACE="/Users/nicreich/AetherAG-mono/Aether.xcworkspace"'
good = 'WORKSPACE="\${REPO_ROOT}/Aether.xcworkspace"'

if bad in text:
    text = text.replace(bad, good)
    path.write_text(text)
    print("Fixed: WORKSPACE= line restored to portable form.")
else:
    print("No exact match found for the hardcoded line -- printing current WORKSPACE= line for manual check:")
    for line in text.splitlines():
        if line.strip().startswith("WORKSPACE="):
            print(" ", line)
PYEOF

echo ""
echo "=== Verify final SCHEME= and WORKSPACE= lines ==="
grep -n '^SCHEME=\|^WORKSPACE=' "${SMOKE_SCRIPT}"

echo ""
echo "=== Full script for final review ==="
cat "${SMOKE_SCRIPT}"

echo ""
echo "=== Clean up .bak files ==="
rm -f "${SMOKE_SCRIPT}.bak"
echo "Removed backup file."

echo ""
echo "=== Stage and diff against git HEAD ==="
cd /Users/nicreich/AetherAG-mono/AetherAG
git diff scripts/simulator_smoke_test.sh
