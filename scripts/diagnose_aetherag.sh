#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/nicreich/AetherAG-mono"
AGWALLET_DIR="${ROOT_DIR}/AGWallet"
AETHERAG_DIR="${ROOT_DIR}/AetherAG"
LOG_DIR="${ROOT_DIR}/diagnostics"
mkdir -p "${LOG_DIR}"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

echo "==> AetherAG diagnostics started at $(timestamp)"
echo "ROOT_DIR=${ROOT_DIR}"

echo
echo "==> Environment"
swift --version || echo "swift not available"
xcodebuild -version || echo "xcodebuild not available"

echo
echo "==> Package-level overview"
echo "Contents of ${ROOT_DIR}:"
ls "${ROOT_DIR}"
echo
echo "Contents of AGWallet:"
ls "${AGWALLET_DIR}"
echo
echo "Contents of AetherAG:"
ls "${AETHERAG_DIR}"

echo
echo "==> Step 1: AGWallet package tests"
cd "${AGWALLET_DIR}"
swift test 2>&1 | tee "${LOG_DIR}/agwallet-swift-test.log"

echo
echo "==> Step 2: AetherAG package tests"
cd "${AETHERAG_DIR}"
swift test 2>&1 | tee "${LOG_DIR}/aetherag-swift-test.log"

echo
echo "==> Step 3: SwiftLint report status"
cd "${ROOT_DIR}"
if [[ -f "swiftlint-report.json" ]]; then
  echo "swiftlint-report.json found."
  # Show top 20 lint entries (if any)
  head -n 20 swiftlint-report.json || true
else
  echo "swiftlint-report.json not found; run SwiftLint separately."
fi

echo
echo "==> Step 4: Build/test warnings snapshot"
cd "${ROOT_DIR}"
for f in build.log AGWallet/build.log AetherAG/test-build.log AetherAG/test.log; do
  if [[ -f "$f" ]]; then
    echo "--- Warnings in $f ---"
    grep -i "warning:" "$f" || echo "No warnings found in $f"
  fi
done

echo
echo "==> Step 5: TODO/FIXME inventory"
cd "${ROOT_DIR}"
grep -R --line-number --exclude-dir=.build --exclude-dir=.git --include='*.swift' "TODO" Sources AGWallet AetherAG 2>/dev/null | tee "${LOG_DIR}/todo-fixme.log" || echo "No TODO markers found."
grep -R --line-number --exclude-dir=.build --exclude-dir=.git --include='*.swift' "FIXME" Sources AGWallet AetherAG 2>/dev/null | tee -a "${LOG_DIR}/todo-fixme.log" || echo "No FIXME markers found."

echo
echo "==> Step 6: Server (Vapor) surface scan"
cd "${AETHERAG_DIR}"
if [[ -d "Sources/AetherAGMailServer" ]]; then
  echo "AetherAGMailServer layout:"
  ls Sources/AetherAGMailServer
  echo
  echo "Controllers:"
  ls Sources/AetherAGMailServer/Controllers || true
  echo "Services:"
  ls Sources/AetherAGMailServer/Services || true
  echo "Repositories:"
  ls Sources/AetherAGMailServer/Repositories || true
  echo "Migrations:"
  ls Sources/AetherAGMailServer/Migrations || true
else
  echo "AetherAGMailServer not found under Sources."
fi

echo
echo "==> Step 7: Test-support and scripts overview"
cd "${AETHERAG_DIR}"
echo "Test support scripts:"
ls dev-postgres-and-tests.sh VerifyError.sh migrate_test_support.sh setup-local-testnet.sh 2>/dev/null || true

echo
echo "==> Diagnostics complete at $(timestamp)"
echo "Logs written under ${LOG_DIR}"
