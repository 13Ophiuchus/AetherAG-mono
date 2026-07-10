#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/nicreich/AetherAG-mono"

echo "==> Local CI: AGWallet tests"
cd "${ROOT_DIR}/AGWallet"
swift test

echo
echo "==> Local CI: AetherAG tests"
cd "${ROOT_DIR}/AetherAG"
swift test

echo
echo "==> Local CI: diagnostics"
cd "${ROOT_DIR}"
scripts/diagnose_aetherag.sh
