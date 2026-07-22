#!/bin/zsh
# One-shot: disable code signing enforcement for the Simulator smoke-test
# build. Simulator builds don't need valid signatures, and SPM-generated
# resource-only bundles (e.g. AetherAG_AetherAGMailClientApp.bundle) lack a
# CFBundleExecutable, which makes Xcode's codesign step fail with:
#   "bundle format unrecognized, invalid, or unsuitable"
# Passing these four build settings on the command line skips signing
# entirely for this invocation, without touching the checked-in project
# signing configuration.
set -euo pipefail

TARGET="/Users/nicreich/AetherAG-mono/AetherAG/scripts/simulator_smoke_test.sh"

if [[ ! -f "${TARGET}" ]]; then
  echo "ERROR: ${TARGET} not found."
  exit 1
fi

cp "${TARGET}" "${TARGET}.bak"

python3 - "${TARGET}" <<'PYEOF'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

old = (
    'xcodebuild build \\\n'
    '  -workspace "${WORKSPACE}" \\\n'
    '  -scheme "${SCHEME}" \\\n'
    '  -destination "platform=iOS Simulator,id=${UDID}" \\\n'
    '  -derivedDataPath "${REPO_ROOT}/.build/DerivedData-SimulatorSmokeTest" \\\n'
)

new = (
    'xcodebuild build \\\n'
    '  -workspace "${WORKSPACE}" \\\n'
    '  -scheme "${SCHEME}" \\\n'
    '  -destination "platform=iOS Simulator,id=${UDID}" \\\n'
    '  -derivedDataPath "${REPO_ROOT}/.build/DerivedData-SimulatorSmokeTest" \\\n'
    '  CODE_SIGNING_ALLOWED=NO \\\n'
    '  CODE_SIGNING_REQUIRED=NO \\\n'
    '  CODE_SIGN_IDENTITY="" \\\n'
    '  CODE_SIGNING_ENTITLEMENTS="" \\\n'
)

if old in text:
    text = text.replace(old, new)
    path.write_text(text)
    print("Fixed: added CODE_SIGNING_ALLOWED=NO and related settings to xcodebuild build.")
else:
    print("Exact block not found. Current xcodebuild build invocation:")
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if "xcodebuild build" in line:
            for l in lines[i:i+8]:
                print(" ", l)
            break
    sys.exit(1)
PYEOF

echo ""
echo "=== Verify fix ==="
grep -n -A8 'xcodebuild build \\' "${TARGET}"

echo ""
echo "=== Diff ==="
diff "${TARGET}.bak" "${TARGET}" || true

rm -f "${TARGET}.bak"
echo ""
echo "Removed backup."
