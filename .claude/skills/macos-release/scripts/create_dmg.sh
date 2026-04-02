#!/bin/bash
set -euo pipefail

# Usage: create_dmg.sh <version> <buildNumber>
# Example: create_dmg.sh 1.0.0 1
#
# Full release pipeline:
# 1. flutter build macos
# 2. xcodebuild archive + exportArchive (Developer ID)
# 3. create-dmg (npm) — auto-generates styled DMG
# 4. notarize + staple
# 5. upload to GitHub release
#
# Prerequisites:
# - npm install --global create-dmg
# - Developer ID provisioning profile installed
# - Notarytool keychain profile "appshot-notary"

VERSION="${1:?Usage: create_dmg.sh <version> <buildNumber>}"
BUILD_NUMBER="${2:?Usage: create_dmg.sh <version> <buildNumber>}"
REPO="tyypgzl/appshot-releases"
TAG="v${VERSION}"
APP_NAME="Appshot"
KEYCHAIN_PROFILE="appshot-notary"

PROJECT_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
APP_DIR="$PROJECT_ROOT/app"
DIST_DIR="$APP_DIR/dist"
EXPORT_OPTIONS="$APP_DIR/macos/ExportOptions.plist"
DIST_ENTITLEMENTS="$APP_DIR/macos/Runner/Distribution.entitlements"
RELEASE_ENTITLEMENTS="$APP_DIR/macos/Runner/Release.entitlements"

cd "$APP_DIR"

# ── 1. Flutter build (obfuscated) ─────────────────────────────
echo "=== Flutter Build (obfuscated) ==="
DEBUG_SYMBOLS_DIR="$DIST_DIR/${BUILD_NUMBER}/debug-symbols"
mkdir -p "$DEBUG_SYMBOLS_DIR"
fvm flutter build macos --release --obfuscate --split-debug-info="$DEBUG_SYMBOLS_DIR" 2>&1 | tail -2
echo "Debug symbols saved to: $DEBUG_SYMBOLS_DIR"
echo ""

# ── 2. Xcode archive (with Distribution entitlements) ────────
echo "=== Xcode Archive ==="
cp "$RELEASE_ENTITLEMENTS" "$RELEASE_ENTITLEMENTS.bak"
cp "$DIST_ENTITLEMENTS" "$RELEASE_ENTITLEMENTS"

rm -rf build/macos/Appshot.xcarchive build/macos/export

xcodebuild archive \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/macos/Appshot.xcarchive \
  -quiet 2>&1 | tail -3

cp "$RELEASE_ENTITLEMENTS.bak" "$RELEASE_ENTITLEMENTS"
rm -f "$RELEASE_ENTITLEMENTS.bak"
echo "Archive complete"
echo ""

# ── 3. Export with Developer ID ───────────────────────────────
echo "=== Developer ID Export ==="
xcodebuild -exportArchive \
  -archivePath build/macos/Appshot.xcarchive \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath build/macos/export \
  2>&1 | tail -3

APP_PATH="build/macos/export/Appshot.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Error: Export failed"
  exit 1
fi
codesign -d -vvv "$APP_PATH" 2>&1 | grep "Authority=" | head -1
echo ""

# ── 4. Copy to dist (for macos_updater hashes) ───────────────
mkdir -p "$DIST_DIR/${BUILD_NUMBER}/appshot-${VERSION}+${BUILD_NUMBER}-macos"
cp -R "$APP_PATH" "$DIST_DIR/${BUILD_NUMBER}/appshot-${VERSION}+${BUILD_NUMBER}-macos/appshot.app"
echo "Copied to dist/"

# ── 5. Create DMG ─────────────────────────────────────────────
echo ""
echo "=== Creating DMG ==="
rm -f "$DIST_DIR/${APP_NAME} ${VERSION}.dmg"

create-dmg \
  --overwrite \
  --dmg-title "$APP_NAME" \
  --identity "Developer ID Application: Tayyip GUZEL (29QHZAJ863)" \
  "$APP_PATH" \
  "$DIST_DIR"

# create-dmg names it "Appshot 1.0.0.dmg", rename to "Appshot-1.0.0.dmg"
DMG_ORIG="$DIST_DIR/${APP_NAME} ${VERSION}.dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
if [ -f "$DMG_ORIG" ]; then
  mv "$DMG_ORIG" "$DMG_PATH"
fi

echo "DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1 | tr -d ' '))"
echo ""

# ── 6. Notarize ───────────────────────────────────────────────
echo "=== Notarizing ==="
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
echo ""
xcrun stapler staple "$DMG_PATH"
echo ""

# ── 7. Upload ─────────────────────────────────────────────────
echo "=== Uploading ==="
cd "$PROJECT_ROOT"
gh release upload "$TAG" "$DMG_PATH#${APP_NAME}-${VERSION}.dmg" --repo "$REPO" --clobber
echo ""
echo "Done: https://github.com/$REPO/releases/download/$TAG/${APP_NAME}-${VERSION}.dmg"
