#!/usr/bin/env bash
# Build a DMG containing SmartClipboard.app + an Applications symlink.
# Ad-hoc signed. Run from the repo root.

set -euo pipefail

VERSION="${VERSION:-0.1.0}"
APP_PATH=".build/Build/Products/Release/SmartClipboard.app"
DIST_DIR="dist"
DMG_NAME="SmartClipboard-${VERSION}.dmg"
STAGING=".dmg-staging"

if [[ ! -d "$APP_PATH" ]]; then
    echo "build-dmg: $APP_PATH not found. Run a Release build first:"
    echo "  xcodebuild -project SmartClipboard.xcodeproj -scheme SmartClipboard -configuration Release -derivedDataPath .build build"
    exit 1
fi

# Ad-hoc sign the .app (idempotent)
codesign --force --deep --sign - "$APP_PATH" >/dev/null

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$DMG_NAME"

hdiutil create \
    -volname "Smart Clipboard ${VERSION}" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME" >/dev/null

# Ad-hoc sign the DMG itself
codesign --force --sign - "$DIST_DIR/$DMG_NAME" >/dev/null

rm -rf "$STAGING"

# Size + checksum
ls -lh "$DIST_DIR/$DMG_NAME"
shasum -a 256 "$DIST_DIR/$DMG_NAME"
echo "DMG built: $DIST_DIR/$DMG_NAME"
