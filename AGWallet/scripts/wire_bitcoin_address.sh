#!/usr/bin/env bash
set -euo pipefail

# Wire KeyManagerActor.bitcoinAddress(for:) into KeyManager.swift and BitcoinModule.swift,
# then run swift test for the AGWallet package, and finally open the touched files in Xcode.

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

python3 "${PATCH_SCRIPT}" \
  --keymanager "${KEYMANAGER_PATH}" \
  --bitcoinmodule "${BITCOINMODULE_PATH}"

echo "==> Running swift test for AGWallet package"
cd "${AGWALLET_DIR}"

swift test

echo "==> Opening patched files in Xcode via xed"
xed "${KEYMANAGER_PATH}"
xed "${BITCOINMODULE_PATH}"

echo "==> wire_bitcoin_address.sh completed successfully"
