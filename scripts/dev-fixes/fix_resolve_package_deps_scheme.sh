#!/bin/zsh
# One-shot: fix clean_rebuild_after_deps.sh so the
# `xcodebuild -resolvePackageDependencies` call includes -scheme.
# xcodebuild requires -scheme whenever -workspace is passed, even for
# -resolvePackageDependencies, which has nothing to do with the actual
# SwiftPM dependency graph (that already resolved successfully upstream).
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

old = '''  step "Resolve workspace package dependencies"
  cd "\${REPO_ROOT}"
  xcodebuild -workspace "\${REPO_ROOT}/Aether.xcworkspace" -resolvePackageDependencies'''

new = '''  step "Resolve workspace package dependencies"
  cd "\${REPO_ROOT}"
  xcodebuild -workspace "\${REPO_ROOT}/Aether.xcworkspace" -scheme "AetherAGMailClientAppShell" -resolvePackageDependencies'''

if old in text:
    text = text.replace(old, new)
    path.write_text(text)
    print("Fixed: added -scheme AetherAGMailClientAppShell to the -resolvePackageDependencies call.")
else:
    print("Exact block not found -- printing current resolvePackageDependencies line(s) for manual check:")
    for line in text.splitlines():
        if "resolvePackageDependencies" in line:
            print(" ", line)
PYEOF

echo ""
echo "=== Verify fix ==="
grep -n 'resolvePackageDependencies' "${TARGET}"

echo ""
echo "=== Diff ==="
diff "${TARGET}.bak" "${TARGET}" || true

echo ""
echo "=== Cleanup backup ==="
rm -f "${TARGET}.bak"
echo "Removed backup."
