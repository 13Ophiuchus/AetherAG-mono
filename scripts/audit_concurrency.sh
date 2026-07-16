#!/bin/bash
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

LOG_DIR="concurrency_audit_logs"
mkdir -p "$LOG_DIR"

run_audit() {
  local name="$1"
  local path="$2"

  echo "=== Auditing ${name} (path: ${path}) ==="
  [ -d "$path" ] || { echo "!! Skipping ${name}: not found"; return; }

  local raw_log="${LOG_DIR}/${name}_build_raw.log"

  (
    cd "$path" || exit 1
    rm -rf .build
    swift build -Xswiftc -strict-concurrency=complete
  ) > "$raw_log" 2>&1
  local exit_code=$?

  echo "[${name}] Exit code: ${exit_code}"
  [ "$exit_code" -ne 0 ] && { echo "BUILD FAILED"; tail -n 40 "$raw_log"; return; }

  local total firstparty vendor
  total=$(grep -c "warning:" "$raw_log")
  firstparty=$(grep -E "AetherAG-mono/(AGWallet|AetherAG)/Sources" "$raw_log" | wc -l | tr -d ' ')
  vendor=$(grep -E "solana-swift-patched|web3swift-patched" "$raw_log" | wc -l | tr -d ' ')

  echo "Total: ${total} | First-party: ${firstparty} | Vendor: ${vendor}"
  echo
}

run_audit "AGWallet" "AGWallet"
run_audit "AetherAG" "AetherAG"
