#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Job Hunt Tracker — Linux .deb package builder
#
#  Run from the project root:
#    chmod +x build/linux/build-deb.sh
#    ./build/linux/build-deb.sh
#
#  Requirements:
#    • dpkg-deb  (pre-installed on Debian/Ubuntu; brew install dpkg on macOS)
#    • Go toolchain
#
#  Output: dist/job-hunt-tracker_1.0.0_amd64.deb
#
#  Install on target machine:
#    sudo dpkg -i dist/job-hunt-tracker_1.0.0_amd64.deb
#    job-hunt-tracker          # run from anywhere
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PKG_NAME="job-hunt-tracker"
VERSION="1.0.0"
ARCH="amd64"
MAINTAINER="Job Hunt Tracker"
DESCRIPTION="Track your job applications from first contact to offer"

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BINARY_SRC="$DIST_DIR/job-tracker-linux-amd64"
DEB_ROOT="$DIST_DIR/deb-pkg"
DEB_OUT="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"

INSTALL_BIN="/usr/local/bin"
INSTALL_APP="/usr/share/applications"
INSTALL_ICON="/usr/share/pixmaps"

cd "$ROOT_DIR"

# ── 1. Build binary if needed ─────────────────────────────────────────────────
if [ ! -f "$BINARY_SRC" ]; then
  echo "▶  Building linux/amd64 binary…"
  go mod tidy
  GOOS=linux GOARCH=amd64 go build -tags webkit2gtk_4_1 -ldflags "-s -w" -o "$BINARY_SRC" .
fi
echo "✔  Binary: $BINARY_SRC"

# ── 2. Build package directory tree ──────────────────────────────────────────
echo "▶  Assembling package tree…"
rm -rf "$DEB_ROOT"

# Binary
mkdir -p "$DEB_ROOT$INSTALL_BIN"
cp "$BINARY_SRC" "$DEB_ROOT$INSTALL_BIN/$PKG_NAME"
chmod 755 "$DEB_ROOT$INSTALL_BIN/$PKG_NAME"

# .desktop entry (shows in GNOME/KDE app launcher)
mkdir -p "$DEB_ROOT$INSTALL_APP"
cat > "$DEB_ROOT$INSTALL_APP/$PKG_NAME.desktop" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Job Hunt Tracker
GenericName=Job Application Tracker
Comment=Track your job applications from first contact to offer
Exec=$PKG_NAME
Icon=$PKG_NAME
Terminal=false
Categories=Office;ProjectManagement;
Keywords=job;career;employment;tracker;
StartupNotify=true
DESKTOP
chmod 644 "$DEB_ROOT$INSTALL_APP/$PKG_NAME.desktop"

# SVG icon (inline — so we don't need an external asset)
mkdir -p "$DEB_ROOT$INSTALL_ICON"
cat > "$DEB_ROOT$INSTALL_ICON/$PKG_NAME.svg" <<'ICON'
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g" x1="0" y1="48" x2="48" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#5b8af5"/>
      <stop offset="50%" stop-color="#a35bf5"/>
      <stop offset="100%" stop-color="#f5a35b"/>
    </linearGradient>
  </defs>
  <circle cx="24" cy="24" r="22" stroke="url(#g)" stroke-width="2" fill="#1a1e29"/>
  <circle cx="24" cy="24" r="15" stroke="url(#g)" stroke-width="1" stroke-dasharray="4 3" fill="none" opacity="0.5"/>
  <line x1="24" y1="32" x2="24" y2="16" stroke="url(#g)" stroke-width="2.5" stroke-linecap="round"/>
  <polyline points="18,22 24,15 30,22" stroke="url(#g)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  <circle cx="24" cy="33.5" r="2" fill="url(#g)"/>
</svg>
ICON
chmod 644 "$DEB_ROOT$INSTALL_ICON/$PKG_NAME.svg"

# ── 3. control file ───────────────────────────────────────────────────────────
mkdir -p "$DEB_ROOT/DEBIAN"
cat > "$DEB_ROOT/DEBIAN/control" <<CONTROL
Package: $PKG_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 A standalone desktop app to track job applications.
 Opens as a native window using WebKitGTK.
 Data is stored in ~/.config/JobHuntTracker/jobs.db.
Depends: libwebkit2gtk-4.1-0
Section: utils
Priority: optional
Homepage: https://github.com/your-repo/job-hunt-tracker
CONTROL

# postinst: update desktop database after install
cat > "$DEB_ROOT/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
POSTINST
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

# postrm: clean up desktop database on remove
cat > "$DEB_ROOT/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
# Note: user data (~/.config/JobHuntTracker/jobs.db) is intentionally kept.
POSTRM
chmod 755 "$DEB_ROOT/DEBIAN/postrm"

# ── 4. Build .deb ─────────────────────────────────────────────────────────────
echo "▶  Packing .deb…"
dpkg-deb --build --root-owner-group "$DEB_ROOT" "$DEB_OUT"
rm -rf "$DEB_ROOT"

echo ""
echo "✅  Done!"
echo "   .deb  → $DEB_OUT"
echo ""
echo "   Install:   sudo dpkg -i $DEB_OUT"
echo "   Run:       job-hunt-tracker"
echo "   Open:      http://localhost:8080"
echo "   Uninstall: sudo dpkg -r $PKG_NAME"
