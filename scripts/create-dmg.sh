#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Revu.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_OUTPUT="$BUILD_DIR/Revu-1.0.dmg"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving Revu..."
xcodebuild archive \
    -project "$PROJECT_DIR/Revu.xcodeproj" \
    -scheme Revu \
    -destination 'generic/platform=macOS' \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=NO \
    | tail -5

echo "==> Exporting app from archive..."
# Extract the .app directly from the archive instead of using exportArchive
# (exportArchive requires valid signing for macOS apps)
APP_PATH="$ARCHIVE_PATH/Products/Applications/Revu.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Revu.app not found in archive at $APP_PATH"
    echo "Archive contents:"
    find "$ARCHIVE_PATH/Products" -maxdepth 3 2>/dev/null || true
    exit 1
fi

mkdir -p "$EXPORT_DIR"
cp -R "$APP_PATH" "$EXPORT_DIR/Revu.app"

echo "==> Creating DMG..."
# Check if create-dmg is available for a styled DMG
BG_IMAGE="$SCRIPT_DIR/dmg-background.png"
if command -v create-dmg &>/dev/null; then
    CREATE_DMG_ARGS=(
        --volname "Revu"
        --window-pos 200 120
        --window-size 600 400
        --icon-size 100
        --icon "Revu.app" 150 190
        --app-drop-link 450 190
        --no-internet-enable
        --text-size 14
        --hide-extension "Revu.app"
    )
    if [ -f "$BG_IMAGE" ]; then
        CREATE_DMG_ARGS+=(--background "$BG_IMAGE")
    fi
    create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_OUTPUT" "$EXPORT_DIR/Revu.app"
else
    echo "    (create-dmg not found, using hdiutil fallback)"
    echo "    Install it with: brew install create-dmg"

    STAGING_DIR="$BUILD_DIR/dmg-staging"
    mkdir -p "$STAGING_DIR"
    cp -R "$EXPORT_DIR/Revu.app" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    hdiutil create \
        -volname "Revu" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_OUTPUT"

    rm -rf "$STAGING_DIR"
fi

echo ""
echo "==> Done! DMG created at:"
echo "    $DMG_OUTPUT"
echo ""
echo "    Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
