#!/bin/zsh
# One-shot: verify Aether.xcworkspace now exposes AetherAGMailClientAppShell,
# confirm the scheme file was written as SHARED (not user-specific), and
# patch scripts/simulator_smoke_test.sh to default to the new scheme.
set -euo pipefail

REPO_ROOT="/Users/nicreich/AetherAG-mono"
WORKSPACE="${REPO_ROOT}/Aether.xcworkspace"
SCHEME_NAME="AetherAGMailClientAppShell"
SMOKE_SCRIPT="${REPO_ROOT}/AetherAG/scripts/simulator_smoke_test.sh"

echo "=== 1. Workspace-level scheme list ==="
xcodebuild -workspace "${WORKSPACE}" -list

echo ""
echo "=== 2. Confirm scheme file is SHARED, not user-specific ==="
SHARED_PATH="${REPO_ROOT}/AetherAGMailClientAppShell/AetherAGMailClientAppShell.xcodeproj/xcshareddata/xcschemes/${SCHEME_NAME}.xcscheme"
if [[ -f "${SHARED_PATH}" ]]; then
  echo "OK: shared scheme file exists at:"
  echo "  ${SHARED_PATH}"
else
  echo "WARNING: expected shared scheme file not found at:"
  echo "  ${SHARED_PATH}"
  echo "Searching for it elsewhere..."
  find "${REPO_ROOT}/AetherAGMailClientAppShell" -iname "*.xcscheme"
fi

echo ""
echo "=== 3. Current contents of simulator_smoke_test.sh (first 40 lines) ==="
if [[ -f "${SMOKE_SCRIPT}" ]]; then
  head -40 "${SMOKE_SCRIPT}"
else
  echo "WARNING: ${SMOKE_SCRIPT} not found."
fi

echo ""
echo "=== 4. Patch smoke-test script to default to workspace + new scheme ==="
python3 - <<PYEOF
import re
from pathlib import Path

path = Path("${SMOKE_SCRIPT}")
if not path.exists():
    print(f"SKIP: {path} does not exist, nothing to patch.")
else:
    text = path.read_text()
    original = text

    # Try to find an existing SCHEME= or PROJECT= assignment to update in place.
    scheme_pattern = re.compile(r'^(SCHEME\s*=\s*)["\']?[^"\'\n]*["\']?', re.MULTILINE)
    workspace_pattern = re.compile(r'^(WORKSPACE\s*=\s*)["\']?[^"\'\n]*["\']?', re.MULTILINE)

    scheme_line = 'SCHEME="${SCHEME_NAME}"'
    workspace_line = 'WORKSPACE="${WORKSPACE}"'

    if scheme_pattern.search(text):
        text = scheme_pattern.sub(lambda m: scheme_line, text, count=1)
        print("Updated existing SCHEME= line.")
    else:
        print("No SCHEME= line found -- leaving script structure untouched.")
        print("Manual review needed: add SCHEME=\"${SCHEME_NAME}\" to the script.")

    if workspace_pattern.search(text):
        text = workspace_pattern.sub(lambda m: workspace_line, text, count=1)
        print("Updated existing WORKSPACE= line.")
    else:
        print("No WORKSPACE= line found -- leaving script structure untouched.")

    if text != original:
        backup = path.with_suffix(path.suffix + ".bak")
        backup.write_text(original)
        path.write_text(text)
        print(f"Patched {path}, backup saved to {backup}")
    else:
        print("No changes made to script (patterns not matched or already correct).")
PYEOF

echo ""
echo "=== 5. Show diff of any changes made ==="
if [[ -f "${SMOKE_SCRIPT}.bak" ]]; then
  diff "${SMOKE_SCRIPT}.bak" "${SMOKE_SCRIPT}" || true
else
  echo "(no .bak file created -- no automatic patch applied)"
fi
