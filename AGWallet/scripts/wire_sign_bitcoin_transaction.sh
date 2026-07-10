#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/nicreich/AetherAG-mono"
AGWALLET_DIR="${ROOT_DIR}/AGWallet"

KEYMANAGER_PATH="${AGWALLET_DIR}/Sources/AetherWalletKit/Data/KeyManagementModule/KeyManager.swift"
BITCOINMODULE_PATH="${AGWALLET_DIR}/Sources/AetherWalletKit/Data/BitcoinModule/BitcoinModule.swift"

PATCH_SCRIPT="${AGWALLET_DIR}/scripts/patch_sign_bitcoin_transaction.py"

echo "==> Wiring signBitcoinTransaction(_:chain:) via ${PATCH_SCRIPT}"
cd "${AGWALLET_DIR}"

if [[ ! -f "${PATCH_SCRIPT}" ]]; then
  echo "ERROR: Patch script not found at ${PATCH_SCRIPT}" >&2
  exit 1
fi

python3 "${PATCH_SCRIPT}" \
  --keymanager "${KEYMANAGER_PATH}" \
  --bitcoinmodule "${BITCOINMODULE_PATH}"

echo "==> Running swift test for AGWallet package"
swift test

echo "==> Opening patched files in Xcode via xed"
xed "${KEYMANAGER_PATH}"
xed "${BITCOINMODULE_PATH}"

echo "==> wire_sign_bitcoin_transaction.sh completed successfully"
