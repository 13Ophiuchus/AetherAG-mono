#!/bin/zsh
# One-shot: disable Xcode's build-tool-plugin trust/fingerprint validation
# gate for headless xcodebuild runs. Without this, packages that ship
# SwiftPM build tool plugins (e.g. swift-secp256k1's "SharedSourcesPlugin")
# fail with:
#   ** BUILD FAILED **
#   Validate plug-in "SharedSourcesPlugin" in package "swift-secp256k1"
# because Xcode normally shows an interactive "Trust & Enable" dialog for
# third-party plugins, which has no equivalent in CLI/CI builds.
set -euo pipefail

echo "=== Before ==="
defaults read com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation 2>/dev/null || echo "(unset)"
defaults read com.apple.dt.Xcode IDESkipMacroFingerprintValidation 2>/dev/null || echo "(unset)"

echo ""
echo "=== Applying fix ==="
# Skip build-tool-plugin fingerprint validation (the actual gate hit here)
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
# Also skip macro fingerprint validation -- same trust-gate mechanism,
# commonly hit right after fixing the plugin one (e.g. swift-syntax macros).
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

echo ""
echo "=== After ==="
defaults read com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation
defaults read com.apple.dt.Xcode IDESkipMacroFingerprintValidation

echo ""
echo "Done. Re-run your build with:"
echo "  cd /Users/nicreich/AetherAG-mono"
echo "  ./AetherAG/scripts/simulator_smoke_test.sh \"iPhone 16\""
