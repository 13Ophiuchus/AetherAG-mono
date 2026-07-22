#!/bin/zsh
# One-shot: install XcodeGen (if needed), generate an iOS App target
# (AetherAGMailClientAppShell) wired to the existing AetherAGMailClientApp /
# AetherAGMailClientCore SPM libraries via project.yml, then run xcodegen to
# produce a real .xcodeproj with a shared scheme.
set -euo pipefail

REPO_ROOT="/Users/nicreich/AetherAG-mono"
APP_DIR="${REPO_ROOT}/AetherAGMailClientAppShell"

echo "=== 1. Ensure Homebrew + XcodeGen are installed ==="
if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew not found. Install from https://brew.sh first."
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing xcodegen via Homebrew..."
  brew install xcodegen
else
  echo "xcodegen already installed: $(xcodegen --version)"
fi

echo ""
echo "=== 2. Scaffold shell app directory ==="
mkdir -p "${APP_DIR}/Sources/AetherAGMailClientAppShell"
mkdir -p "${APP_DIR}/Resources"

echo ""
echo "=== 3. Write @main App entry point (thin shell over AppRootView) ==="
cat > "${APP_DIR}/Sources/AetherAGMailClientAppShell/AetherAGMailClientAppShellApp.swift" <<'SWIFTEOF'
import SwiftUI
import AetherAGMailClientApp

@main
struct AetherAGMailClientAppShellApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
SWIFTEOF

echo ""
echo "=== 4. Write Info.plist ==="
cat > "${APP_DIR}/Resources/Info.plist" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
PLISTEOF

echo ""
echo "=== 5. Write project.yml (XcodeGen spec) ==="
cat > "${APP_DIR}/project.yml" <<YMLEOF
name: AetherAGMailClientAppShell
options:
  bundleIdPrefix: com.aetherag
  deploymentTarget:
    iOS: "17.0"

packages:
  AetherAG:
    path: ../AetherAG

targets:
  AetherAGMailClientAppShell:
    type: application
    platform: iOS
    sources:
      - path: Sources/AetherAGMailClientAppShell
    info:
      path: Resources/Info.plist
      properties:
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.aetherag.clientappshell
        SWIFT_VERSION: "6.0"
        TARGETED_DEVICE_FAMILY: "1"
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
    dependencies:
      - package: AetherAG
        product: AetherAGMailClientApp
      - package: AetherAG
        product: AetherAGMailClientCore

schemes:
  AetherAGMailClientAppShell:
    build:
      targets:
        AetherAGMailClientAppShell: all
    run:
      config: Debug
    test:
      config: Debug
    shared: true
YMLEOF

echo ""
echo "=== 6. Run xcodegen to produce the .xcodeproj ==="
cd "${APP_DIR}"
xcodegen generate

echo ""
echo "=== 7. Verify the generated scheme ==="
xcodebuild -project "${APP_DIR}/AetherAGMailClientAppShell.xcodeproj" -list

echo ""
echo "Done. Project scaffolded at: ${APP_DIR}"
echo "Next: add AetherAGMailClientAppShell.xcodeproj to Aether.xcworkspace (see next script)."
