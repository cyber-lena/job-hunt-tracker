#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Job Hunt Tracker — macOS .app + .dmg builder
#
#  Run from the project root:
#    chmod +x build/macos/build-dmg.sh
#    ./build/macos/build-dmg.sh
#
#  Requirements:
#    • macOS host (uses hdiutil — macOS only)
#    • Go toolchain (for the build step)
#
#  Output: dist/JobHuntTracker.dmg
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_NAME="Job Hunt Tracker"
BUNDLE_ID="com.jobhunttracker.app"
VERSION="1.0.0"
ARCH="$(uname -m)"   # arm64 or x86_64 → we map to Go arch below

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
DMG_OUT="$DIST_DIR/JobHuntTracker.dmg"
DMG_TMP="$DIST_DIR/dmg-tmp"

# Map arch
case "$ARCH" in
  arm64)   GO_ARCH="arm64"  ;;
  x86_64)  GO_ARCH="amd64"  ;;
  *)
    echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

BINARY_SRC="$DIST_DIR/job-tracker-darwin-$GO_ARCH"

cd "$ROOT_DIR"

# ── 1. Build binary if needed ─────────────────────────────────────────────────
if [ ! -f "$BINARY_SRC" ]; then
  echo "▶  Building darwin/$GO_ARCH binary…"
  go mod tidy
  GOOS=darwin GOARCH=$GO_ARCH go build -ldflags "-s -w" -o "$BINARY_SRC" .
fi
echo "✔  Binary: $BINARY_SRC"

# ── 2. Create .app bundle structure ──────────────────────────────────────────
echo "▶  Building .app bundle…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BINARY_SRC" "$APP_DIR/Contents/MacOS/job-hunt-tracker"
chmod +x "$APP_DIR/Contents/MacOS/job-hunt-tracker"

# ── 2a. Build .icns icon ──────────────────────────────────────────────────────
ICON_PNG="$ROOT_DIR/assets/icon.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"

if [ -f "$ICON_PNG" ]; then
  echo "▶  Creating .icns from assets/icon.png…"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  # macOS iconset requires these exact filenames
  sips -z 16  16  "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
  sips -z 32  32  "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
  sips -z 32  32  "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
  sips -z 64  64  "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
  sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET_DIR"
  echo "✔  AppIcon.icns embedded in bundle"
  ICON_KEY='<key>CFBundleIconFile</key>      <string>AppIcon</string>'
else
  echo "⚠  assets/icon.png not found — skipping icon (add it for a custom app icon)"
  ICON_KEY=''
fi

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>       <string>job-hunt-tracker</string>
  <key>CFBundleIdentifier</key>       <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>             <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>      <string>${APP_NAME}</string>
  <key>CFBundleVersion</key>          <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key>      <string>APPL</string>
  <key>CFBundleSignature</key>        <string>????</string>
  <key>LSMinimumSystemVersion</key>   <string>11.0</string>
  <key>NSHighResolutionCapable</key>  <true/>
  ${ICON_KEY}
</dict>
</plist>
PLIST

echo "✔  .app bundle: $APP_DIR"

# ── 3. Remove quarantine attribute (dev builds) ───────────────────────────────
xattr -cr "$APP_DIR" 2>/dev/null || true

# ── 4. Build .dmg ─────────────────────────────────────────────────────────────
echo "▶  Building .dmg…"
rm -rf "$DMG_TMP" "$DMG_OUT"
mkdir -p "$DMG_TMP"

cp -r "$APP_DIR" "$DMG_TMP/"

# Symlink to /Applications for drag-install UX
ln -s /Applications "$DMG_TMP/Applications"

# Create the DMG
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "$DMG_OUT"

rm -rf "$DMG_TMP"

echo ""
echo "✅  Done!"
echo "   DMG   → $DMG_OUT"
echo "   App   → $APP_DIR"
echo ""
echo "   To install: open $DMG_OUT"
echo "               drag '${APP_NAME}' into Applications"
