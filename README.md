# Job Hunt Tracker

A standalone desktop application to track your job applications from first contact to offer. Runs fully locally — no browser, no cloud, no account.

## Stack

| Layer     | Tech |
|-----------|------|
| Desktop window | `github.com/webview/webview_go` — native OS webview (WKWebView / WebView2 / WebKitGTK) |
| Backend   | Go — `net/http`, binds to a random free loopback port at startup |
| Database  | SQLite via `modernc.org/sqlite` |
| Frontend  | HTML / CSS / JS — embedded in the binary via `//go:embed` |

The app opens as a **native desktop window** — no browser, no address bar. Closing the window exits the app. The HTTP server is internal and only accessible from the app itself (`127.0.0.1`, random port).

Data is stored in the platform config directory:

| OS      | Path |
|---------|------|
| Windows | `%APPDATA%\JobHuntTracker\jobs.db` |
| macOS   | `~/Library/Application Support/JobHuntTracker/jobs.db` |
| Linux   | `~/.config/JobHuntTracker/jobs.db` |

---

## Build Requirements

Because the app uses a native webview, **CGo is required** at compile time. Each platform needs:

| Platform | C compiler | Webview engine | Extra |
|----------|-----------|----------------|-------|
| **macOS** | Xcode CLT (`xcode-select --install`) | WKWebView (built-in) | Must build on macOS |
| **Linux** | `gcc` | WebKitGTK | `sudo apt install libwebkit2gtk-4.1-dev pkg-config` |
| **Windows** | MinGW-w64 or MSVC | WebView2 (ships with Edge / Win10+) | Cross-compile or build natively |

---

## Native Installers

### Windows — Setup Wizard (`JobHuntTracker-Setup.exe`)

**Requirements:** [NSIS 3.x](https://nsis.sourceforge.io/), MinGW-w64 for CGo

```bash
make installer-windows   # or: make build-windows-cross  (from Linux + mingw)
# → dist/JobHuntTracker-Setup.exe
```

Installs to `Program Files`, creates Start Menu + Desktop shortcuts, registers uninstaller.

---

### macOS — Disk Image (`JobHuntTracker.dmg`)

**Must run on a macOS host.**

```bash
make installer-macos
# → dist/JobHuntTracker.dmg
```

Open the `.dmg`, drag into Applications, double-click to launch. A native window opens immediately.

> **Gatekeeper:** On first launch right-click → Open to bypass the unsigned-app warning.

---

### Linux — Debian Package (`.deb`)

```bash
# Build-time dep (on the machine that compiles):
sudo apt install gcc libwebkit2gtk-4.1-dev pkg-config

make installer-linux
# → dist/job-hunt-tracker_1.0.0_amd64.deb

sudo dpkg -i dist/job-hunt-tracker_1.0.0_amd64.deb
job-hunt-tracker        # launch from anywhere
```

Runtime dep (`libwebkit2gtk-4.1-0`) is declared in the package and auto-installed by `apt`.

---

## Build Binaries Only

```bash
make all          # all four platforms
make build-linux
make build-darwin-arm64
make build-darwin-amd64
make build-windows        # native Windows host
make build-windows-cross  # Linux host with mingw-w64
```

---

## Development

```bash
go mod tidy
go run .
```

---

## Project Structure

```
job-tracker/
├── main.go                          ← webview window + HTTP server + embed
├── go.mod
├── index.html                       ← Dashboard UI (compiled into binary)
├── Makefile
├── build/
│   ├── windows/installer.nsi        ← NSIS → Setup.exe
│   ├── macos/build-dmg.sh           ← .app bundle + .dmg
│   └── linux/build-deb.sh           ← .deb package
├── scripts/                         ← quick-launch scripts (no installer)
│   ├── install.sh
│   ├── install.bat
│   └── install.ps1
└── internal/
    └── database/
        └── sqlite.go                ← Store interface + SQLite implementation
```

---

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/applications` | List all |
| POST | `/api/applications` | Create |
| PUT | `/api/applications/:id` | Update |
| DELETE | `/api/applications/:id` | Delete |

---

## Application Statuses

`Wishlist` → `Applied` → `Screening` → `Interview` → `Offer` / `Rejected` / `Withdrawn` / `Ghosted`


