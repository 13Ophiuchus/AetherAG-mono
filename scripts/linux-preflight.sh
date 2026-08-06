#!/usr/bin/env bash
# Pre-flight: catch Apple-only or unguarded Linux-incompatible patterns before CI
set -euo pipefail

SEARCH_DIRS=(
  "solana-swift-concurrency/Sources"
  "web3swift-patched/Sources"
  "AetherShared/Sources"
  "AetherAG/Sources"
)

PATTERNS=(
  "URLSession"
  "URLRequest"
  "URLResponse"
  "URLComponents"
  "URLQueryItem"
  "import WebKit"
  "import CoreImage"
  "import Accelerate"
  "import UIKit"
  "import AppKit"
  "SecRandomCopyBytes"
  "NSPredicate(format:"
)

PATTERN=$(IFS="|"; echo "${PATTERNS[*]}")

echo "🔍 Running Linux pre-flight check..."
HITS=$(grep -rn -E "$PATTERN" \
  "${SEARCH_DIRS[@]}" \
  --include="*.swift" \
  2>/dev/null \
  | grep -v "canImport\|FoundationNetworking\|#if\|#else\|#endif\|\.build\|//" \
  | grep -v "import Foundation$" \
  || true)

if [ -z "$HITS" ]; then
  echo "✅ Clean — no unguarded Linux-incompatible patterns found"
  exit 0
else
  echo "❌ Found unguarded Linux-incompatible patterns:"
  echo "$HITS"
  exit 1
fi
