#!/bin/zsh
# One-shot: fix REPO_ROOT resolution in clean_rebuild_after_deps.sh.
# The script was placed directly at the repo root, but its path logic
# assumed it lived one level down (e.g. scripts/), so it walked UP one
# extra level and computed REPO_ROOT=/Users/nicreich instead of
# /Users/nicreich/AetherAG-mono.
set -euo pipefail

TARGET="/Users/nicreich/AetherAG-mono/clean_rebuild_after_deps.sh"

if [[ ! -f "${TARGET}" ]]; then
  echo "ERROR: ${TARGET} not found."
  exit 1
fi

cp "${TARGET}" "${TARGET}.bak"

python3 - <<PYEOF
from pathlib import Path

path = Path("${TARGET}")
text = path.read_text()

old = 'REPO_ROOT="\$(cd "\${SCRIPT_DIR}/.." && pwd)"'
new = 'REPO_ROOT="\${SCRIPT_DIR}"'

if old in text:
    text = text.replace(old, new)
    path.write_text(text)
    print("Fixed: REPO_ROOT now resolves to the script's own directory (repo root), not one level up.")
else:
    print("Exact pattern not found -- printing current REPO_ROOT line for manual check:")
    for line in text.splitlines():
        if line.strip().startswith("REPO_ROOT="):
            print(" ", line)
PYEOF

echo ""
echo "=== Verify fix ==="
grep -n 'SCRIPT_DIR=\|REPO_ROOT=' "${TARGET}"

echo ""
echo "=== Diff ==="
diff "${TARGET}.bak" "${TARGET}" || true

echo ""
echo "=== Cleanup backup ==="
rm -f "${TARGET}.bak"
echo "Removed backup."
