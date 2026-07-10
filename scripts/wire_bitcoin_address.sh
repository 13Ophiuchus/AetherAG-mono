#!/usr/bin/env bash
set -euo pipefail

# Wire KeyManagerActor.bitcoinAddress(for:) into KeyManager.swift and BitcoinModule.swift,
# then build & test AGWallet via xcodebuild, and finally open the touched files in Xcode.

ROOT_DIR="/Users/nicreich/AetherAG-mono"
AGWALLET_DIR="${ROOT_DIR}/AGWallet"
WORKSPACE="${ROOT_DIR}/Aether.xcworkspace"
SCHEME="AGWallet"

KEYMANAGER_PATH="${AGWALLET_DIR}/Sources/AetherWalletKit/Data/KeyManagementModule/KeyManager.swift"
BITCOINMODULE_PATH="${AGWALLET_DIR}/Sources/AetherWalletKit/Data/BitcoinModule/BitcoinModule.swift"

PATCH_SCRIPT="${AGWALLET_DIR}/scripts/patch_bitcoin_address.py"

echo "==> Wiring bitcoinAddress(for:) via ${PATCH_SCRIPT}"
cd "${AGWALLET_DIR}"

if [[ ! -f "${PATCH_SCRIPT}" ]]; then
  echo "ERROR: Patch script not found at ${PATCH_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${KEYMANAGER_PATH}" ]]; then
  echo "ERROR: KeyManager.swift not found at ${KEYMANAGER_PATH}" >&2
  exit 1
fi

if [[ ! -f "${BITCOINMODULE_PATH}" ]]; then
  echo "ERROR: BitcoinModule.swift not found at ${BITCOINMODULE_PATH}" >&2
  exit 1
fi

# Run the Python patch script. It should be idempotent: no-op if helper already present.
python3 "${PATCH_SCRIPT}" \
  --keymanager "${KEYMANAGER_PATH}" \
  --bitcoinmodule "${BITCOINMODULE_PATH}"

echo "==> Running xcodebuild tests for ${SCHEME} in ${WORKSPACE}"
cd "${ROOT_DIR}"

xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  clean test \
  | xcpretty || {
    echo "ERROR: xcodebuild test failed for scheme ${SCHEME}" >&2
    exit 1
  }

echo "==> Opening patched files in Xcode via xed"
cd "${AGWALLET_DIR}"

# xed opens files in Xcode; -l can jump to a line once you know where the helper lives [web:42][web:51][web:54].
xed "${KEYMANAGER_PATH}"
xed "${BITCOINMODULE_PATH}"

echo "==> wire_bitcoin_address.sh completed successfully"
