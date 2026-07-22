#!/bin/zsh
# One-shot: add -skipPackagePluginValidation and -skipMacroValidation flags
# directly to the xcodebuild build invocation in simulator_smoke_test.sh.
#
# The `defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation`
# preference affects Xcode's IDE session but is not always honored reliably
# by headless `xcodebuild` CLI runs. Passing the flags directly on the
# command line is the more robust, CI-safe fix and doesn't depend on any
# machine-level preference being set first.
set -euo pipefail

TARGET="/Users/nicreich/AetherAG-mono/AetherAG/scripts/simulator_smoke_test.sh"

if [[ ! -f "${TARGET}" ]]; then
  echo "ERROR: ${TARGET} not found."
  exit 1
fi

cp "${TARGET}" "${TARGET}.bak"

python3 - <<PYEOF
from pathlib import Path

path = Path("${TARGET}")
text = path.read_text()

old = '''xcodebuild build \\
  -workspace "\${WORKSPACE}" \\
  -scheme "\${SCHEME}" \\
  -destination "platform=iOS Simulator,id=\${UDID}" \\
  -derivedDataPath "\${REPO_ROOT}/.build/DerivedData-SimulatorSmokeTest" \\'''

new = '''xcodebuild build \\
  -workspace "\${WORKSPACE}" \\
  -scheme "\${SCHEME}" \\
  -destination "platform=iOS Simulator,id=\${UDID}" \\
  -derivedDataPath "\${REPO_ROOT}/.build/DerivedData-SimulatorSmokeTest" \\
  -skipPackagePluginValidation \\
  -skipMacroValidation \\'''

if old in text:
    text = text.replace(old, new)
    path.write_text(text)
    print("Fixed: added -skipPackagePluginValidation and -skipMacroValidation flags to xcodebuild build.")
else:
    print("Exact block not found -- printing current xcodebuild build invocation for manual check:")
    in_block = False
    for line in text.splitlines():
        if "xcodebuild build" in line:
            in_block = True
        if in_block:
            print(" ", line)
            if line.strip().endswith("log\"") or ("tee" in line):
                break
PYEOF

echo ""
echo "=== Verify fix ==="
grep -n -A2 'xcodebuild build' "${TARGET}"

echo ""
echo "=== Diff ==="
diff "${TARGET}.bak" "${TARGET}" || true

echo ""
echo "=== Cleanup backup ==="
rm -f "${TARGET}.bak"
echo "Removed backup."
