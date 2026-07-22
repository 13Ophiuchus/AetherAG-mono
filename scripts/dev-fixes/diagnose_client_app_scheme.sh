#!/bin/zsh
# One-shot: locate any existing (user-specific or shared) Xcode scheme for
# AetherAGMailClientApp / AetherAGMailClientAppRun, and inspect Package.swift
# to confirm the executable product name Xcode should be exposing.
set -euo pipefail

REPO_ROOT="/Users/nicreich/AetherAG-mono"
WORKSPACE="${REPO_ROOT}/Aether.xcworkspace"

echo "=== 1. Searching for any .xcscheme files mentioning ClientApp ==="
find "${REPO_ROOT}" -iname "*.xcscheme" -print0 2>/dev/null \
  | xargs -0 grep -l -i "clientapp" 2>/dev/null || echo "(none found)"

echo ""
echo "=== 2. All shared schemes currently in the workspace ==="
ls -la "${WORKSPACE}/xcshareddata/xcschemes/" 2>/dev/null || echo "(xcshareddata/xcschemes not found)"

echo ""
echo "=== 3. All user-specific (unshared) schemes for current user ==="
find "${WORKSPACE}/xcuserdata" -iname "*.xcscheme" 2>/dev/null || echo "(none found)"

echo ""
echo "=== 4. Executable targets/products declared in AetherAG/Package.swift ==="
python3 - <<'PYEOF'
import re
from pathlib import Path

pkg_path = Path("/Users/nicreich/AetherAG-mono/AetherAG/Package.swift")
text = pkg_path.read_text()

# Find .executable(name: "...", targets: [...]) product declarations
exec_products = re.findall(r'\.executable\(\s*name:\s*"([^"]+)"', text)
print("Executable products declared:", exec_products or "(none found via .executable pattern)")

# Find .executableTarget(name: "..." declarations
exec_targets = re.findall(r'\.executableTarget\(\s*name:\s*"([^"]+)"', text)
print("Executable targets declared:", exec_targets or "(none found via .executableTarget pattern)")
PYEOF

echo ""
echo "=== 5. Currently resolved workspace scheme list (Xcode's view) ==="
xcodebuild -workspace "${WORKSPACE}" -list 2>/dev/null | sed -n '/Schemes:/,$p'
