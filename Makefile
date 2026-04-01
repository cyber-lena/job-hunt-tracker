BINARY   := job-tracker
DIST     := dist
VERSION  := $(shell git describe --tags --always 2>/dev/null || echo "1.0.0")

# Base ldflags — strip debug info for smaller binaries
BASE_LDFLAGS := -s -w -X main.version=$(VERSION)

# Windows needs -H=windowsgui to suppress the console window
LDFLAGS_WIN  := -ldflags "$(BASE_LDFLAGS) -H=windowsgui"
LDFLAGS      := -ldflags "$(BASE_LDFLAGS)"

# ── NOTE FOR WINDOWS USERS ────────────────────────────────────────────────────
# This Makefile uses Unix env-var syntax (VAR=value command) which CMD/PowerShell
# does not support. On Windows, use the dedicated build scripts instead:
#
#   PowerShell:  powershell -ExecutionPolicy Bypass -File build.ps1
#   CMD:         build.bat
#
# Both scripts set CGO_ENABLED, GOOS, GOARCH correctly for Windows.
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: all binaries installers \
        build-linux build-darwin-amd64 build-darwin-arm64 build-windows \
        build-windows-cross \
        installer-windows installer-macos installer-linux \
        run tidy clean

# ── Default ───────────────────────────────────────────────────────────────────
all: tidy binaries

binaries: build-linux build-darwin-amd64 build-darwin-arm64 build-windows
	@echo ""
	@echo "✅  Binaries in ./$(DIST)/"

# ── Tidy ──────────────────────────────────────────────────────────────────────
tidy:
	go mod tidy

# ── Linux (build on Linux host or use zig cc cross-compiler) ─────────────────
# Requires: gcc  libwebkit2gtk-4.1-dev  pkg-config
build-linux:
	@mkdir -p $(DIST)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
	  go build $(LDFLAGS) -o $(DIST)/$(BINARY)-linux-amd64 .
	@echo "  → $(DIST)/$(BINARY)-linux-amd64"

# ── macOS Intel (must run on macOS host) ──────────────────────────────────────
# Requires: Xcode Command Line Tools
build-darwin-amd64:
	@mkdir -p $(DIST)
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
	  go build $(LDFLAGS) -o $(DIST)/$(BINARY)-darwin-amd64 .
	@echo "  → $(DIST)/$(BINARY)-darwin-amd64"

# ── macOS Apple Silicon (must run on macOS host) ──────────────────────────────
build-darwin-arm64:
	@mkdir -p $(DIST)
	CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
	  go build $(LDFLAGS) -o $(DIST)/$(BINARY)-darwin-arm64 .
	@echo "  → $(DIST)/$(BINARY)-darwin-arm64"

# ── Windows ───────────────────────────────────────────────────────────────────
# This target runs on Linux/Mac with mingw-w64 cross-compiler.
# On Windows CMD/PowerShell use:  build\windows\build.bat
#                            or:  build\windows\build.ps1
build-windows:
	@mkdir -p $(DIST)
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 \
	  CC=x86_64-w64-mingw32-gcc \
	  go build $(LDFLAGS_WIN) -o $(DIST)/$(BINARY)-windows-amd64.exe .
	@echo "  → $(DIST)/$(BINARY)-windows-amd64.exe"

# ── Windows cross-compile from Linux using mingw-w64 (alias) ─────────────────
build-windows-cross: build-windows

# ── Native installers ─────────────────────────────────────────────────────────
installer-windows: build-windows
	@echo "▶  Building Windows installer (NSIS)…"
	makensis build/windows/installer.nsi
	@echo "✅  dist/JobHuntTracker-Setup.exe"

installer-macos:
	@echo "▶  Building macOS installer (.dmg)…"
	bash build/macos/build-dmg.sh

installer-linux: build-linux
	@echo "▶  Building Linux installer (.deb)…"
	bash build/linux/build-deb.sh

# ── Dev ───────────────────────────────────────────────────────────────────────
run: tidy
	go run .

clean:
	rm -rf $(DIST)
