#!/bin/bash
set -e

APP_NAME="EpycZones"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
APP_BUNDLE="${APP_NAME}.app"
DMG_DIR=".dmg-staging"

echo "📦 Creating DMG installer..."

# Ensure the .app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ ${APP_BUNDLE} not found. Run 'make bundle' first."
    exit 1
fi

# Clean previous staging
rm -rf "$DMG_DIR" "$DMG_NAME"
mkdir -p "$DMG_DIR"

# Copy app bundle
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_NAME"

# Clean up staging
rm -rf "$DMG_DIR"

echo "✅ ${DMG_NAME} created ($(du -h "$DMG_NAME" | cut -f1))"
