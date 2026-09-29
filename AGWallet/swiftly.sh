#!/usr/bin/env bash
set -uo pipefail

echo "================================================================"
echo "1. Switch swiftly's global default to defer to Xcode"
echo "================================================================"
swiftly use xcode

echo ""
echo "================================================================"
echo "2. Verify swiftly now shows xcode as in-use/default"
echo "================================================================"
swiftly list

echo ""
echo "================================================================"
echo "3. Verify plain 'swift' now resolves to Xcode's 6.4 toolchain"
echo "================================================================"
swift --version

echo ""
echo "================================================================"
echo "4. Verify xcrun agrees"
echo "================================================================"
xcrun --find swift
xcrun swift --version

echo ""
echo "================================================================"
echo "5. Optional: update swiftly itself (it flagged an update available)"
echo "================================================================"
echo "Run manually when convenient:"
echo "  swiftly self-update"
