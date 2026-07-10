#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/nicreich/AetherAG-mono"
AGWALLET_DIR="${ROOT_DIR}/AGWallet"

KEYMANAGER_PATH="${AGWALLET_DIR}/Sources/AetherWalletKit/Data/KeyManagementModule/KeyManager.swift"
SOLANAMODULE_PATH="${AGWALLET_DIR}/Sources/AetherWalletKit/Data/SolanaModule/SolanaModule.swift"

PATCH_SCRIPT="${AGWALLET_DIR}/scripts/patch_solana_helpers.py"

echo "==> Wiring Solana helpers (solanaAddress(for:), signSolanaMessage, signSolanaTransfer) via ${PATCH_SCRIPT}"
cd "${AGWALLET_DIR}"

if [[ ! -f "${PATCH_SCRIPT}" ]]; then
  echo "ERROR: Patch script not found at ${PATCH_SCRIPT}" >&2
  exit 1
fi

python3 "${PATCH_SCRIPT}" \
  --keymanager "${KEYMANAGER_PATH}" \
  --solanamodule "${SOLANAMODULE_PATH}"

echo "==> Running swift test for AGWallet package"
swift test

echo "==> Opening patched files in Xcode via xed"
xed "${KEYMANAGER_PATH}"
xed "${SOLANAMODULE_PATH}"

echo "==> wire_solana_helpers.sh completed successfully"
