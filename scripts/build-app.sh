#!/bin/bash
# Build TheGipher.app into build/. Pass --install to also copy it to /Applications
# and (re)launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/TheGipher.app"
VERSION="0.1.0"

swift build -c release --product TheGipher
BIN="$(swift build -c release --show-bin-path)/TheGipher"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN" "$APP/Contents/MacOS/TheGipher"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TheGipher</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.thegipher.app</string>
    <key>CFBundleName</key><string>TheGipher</string>
    <key>CFBundleDisplayName</key><string>TheGipher</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Sign with a real identity when one exists: macOS ties the Accessibility grant to
# the signature, and an ad-hoc signature changes on every build (so you'd have to
# re-grant after each rebuild). Override with CODESIGN_IDENTITY.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null |
    awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed: ${IDENTITY:-ad-hoc})"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x TheGipher 2>/dev/null || true
    rm -rf /Applications/TheGipher.app
    cp -R "$APP" /Applications/TheGipher.app
    open /Applications/TheGipher.app
    echo "Installed and launched /Applications/TheGipher.app"
fi
