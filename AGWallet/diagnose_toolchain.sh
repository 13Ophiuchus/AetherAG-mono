#!/usr/bin/env bash
set -uo pipefail

echo "================================================================"
echo "1. List all toolchains swiftly knows about and which is default"
echo "================================================================"
swiftly list

echo ""
echo "================================================================"
echo "2. Confirm no .swift-version file is overriding this (should be empty)"
echo "================================================================"
find "$PWD" -maxdepth 1 -name ".swift-version" 2>/dev/null
find "$HOME" -maxdepth 1 -name ".swift-version" 2>/dev/null

echo ""
echo "================================================================"
echo "3. OPTION A: Point swiftly's default at Xcode's own toolchain"
echo "   (lets swift/xcrun fall through to Xcode when no pin exists)"
echo "================================================================"
echo "Run manually if you prefer swiftly to defer to Xcode:"
echo "  swiftly use xcode"
echo ""
echo "This tells swiftly's shim to hand off to /usr/bin/swift -> Xcode's"
echo "XcodeDefault.xctoolchain (Swift 6.4 / macosx27.0.0) by default."

echo ""
echo "================================================================"
echo "4. OPTION B: Install & switch swiftly's default to match Xcode 27"
echo "   (keeps swiftly in control, just aligned to Swift 6.4)"
echo "================================================================"
echo "Run manually if you prefer swiftly to manage 6.4 directly:"
echo "  swiftly install 6.4.0"
echo "  swiftly use 6.4.0"

echo ""
echo "================================================================"
echo "5. Verify the fix"
echo "================================================================"
echo "After running one of the options above, re-check with:"
echo "  swiftly list"
echo "  swift --version"
echo "  xcrun --find swift"
