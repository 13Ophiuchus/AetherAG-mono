#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "=== Guardrail: legacy XCTest imports ==="
if grep -R -n '^import XCTest' AGWallet/Tests AetherAG/Tests 2>/dev/null; then
  echo "FAIL: legacy XCTest import(s) found."
  fail=1
else
  echo "OK: no XCTest imports."
fi

echo
echo "=== Guardrail: XCTestCase subclasses ==="
if grep -R -n 'XCTestCase' AGWallet/Tests AetherAG/Tests 2>/dev/null; then
  echo "FAIL: XCTestCase subclass(es) found."
  fail=1
else
  echo "OK: no XCTestCase usage."
fi

echo
echo "=== Guardrail: first-party strict-concurrency warnings ==="
for proj in AGWallet AetherAG; do
  log="/tmp/${proj}_guardrail_build.log"
  ( cd "$proj" && swift build -Xswiftc -strict-concurrency=complete ) > "$log" 2>&1 || true
  firstparty=$(grep -E "AetherAG-mono/(AGWallet|AetherAG)/Sources.*warning:" "$log" | wc -l | tr -d ' ')
  echo "[$proj] first-party warnings: $firstparty"
  if [ "$firstparty" -ne 0 ]; then
    echo "FAIL: $proj has $firstparty first-party warning(s)."
    grep -E "AetherAG-mono/(AGWallet|AetherAG)/Sources.*warning:" "$log"
    fail=1
  fi
done

exit $fail
