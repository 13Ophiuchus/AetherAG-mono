#!/bin/zsh
# Automate clean rebuilds after dependency configuration changes.
# Use this after editing Package.swift, Package.resolved, XcodeGen project.yml,
# or other dependency wiring files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
SERVER_DIR="${REPO_ROOT}/AetherAG"
SHELL_APP_DIR="${REPO_ROOT}/AetherAGMailClientAppShell"
DERIVED_DATA_DIR="${REPO_ROOT}/.build/DerivedData-SimulatorSmokeTest"
DEVICE_NAME="${1:-iPhone 16}"
RUN_SIMULATOR_SMOKE="${RUN_SIMULATOR_SMOKE:-1}"
REGENERATE_XCODEGEN="${REGENERATE_XCODEGEN:-1}"

step() {
  echo ""
  echo "==> $1"
}

step "Repository root"
echo "${REPO_ROOT}"

step "Clean SwiftPM artifacts"
cd "${SERVER_DIR}"
swift package reset || true
rm -rf .build

step "Resolve SwiftPM dependencies"
swift package resolve

step "Clean Xcode/Simulator derived data"
rm -rf "${DERIVED_DATA_DIR}"

if [[ -d "${SHELL_APP_DIR}" && -f "${SHELL_APP_DIR}/project.yml" ]]; then
  if [[ "${REGENERATE_XCODEGEN}" == "1" ]]; then
    step "Regenerate Xcode project from XcodeGen"
    cd "${SHELL_APP_DIR}"
    xcodegen generate
  fi

  step "Resolve workspace package dependencies"
  cd "${REPO_ROOT}"
  xcodebuild -workspace "${REPO_ROOT}/Aether.xcworkspace" -scheme "AetherAGMailClientAppShell" -resolvePackageDependencies

  step "List workspace schemes"
  xcodebuild -workspace "${REPO_ROOT}/Aether.xcworkspace" -list | sed -n '/Schemes:/,$p'

  if [[ "${RUN_SIMULATOR_SMOKE}" == "1" ]]; then
    step "Run simulator smoke test"
    "${SERVER_DIR}/scripts/simulator_smoke_test.sh" "${DEVICE_NAME}"
  else
    step "Skipping simulator smoke test"
    echo "Set RUN_SIMULATOR_SMOKE=1 to enable."
  fi
else
  step "Shell app project not present"
  echo "Skipping XcodeGen/workspace steps because ${SHELL_APP_DIR} was not found."
fi

step "Run server preflight"
cd "${SERVER_DIR}"
./scripts/preflight.sh

step "Done"
echo "Clean rebuild flow completed successfully."
