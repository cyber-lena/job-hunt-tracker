#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  Job Hunt Tracker — installer & launcher (macOS / Linux)
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

BINARY="job-tracker"
PORT=8080
URL="http://localhost:$PORT"
DIST_DIR="$(cd "$(dirname "$0")/.." && pwd)/dist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colours ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  echo -e "\n${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║       Job Hunt Tracker               ║"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${NC}"
}

info()    { echo -e "  ${GREEN}▶${NC} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "  ${RED}✖${NC}  $*" >&2; }
success() { echo -e "  ${GREEN}✔${NC}  $*"; }

# ── Detect OS & pick binary name ─────────────────────────────────
detect_binary() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    x86_64)  arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
      error "Unsupported architecture: $arch"
      exit 1 ;;
  esac

  case "$os" in
    linux)  echo "${BINARY}-linux-${arch}" ;;
    darwin) echo "${BINARY}-darwin-${arch}" ;;
    *)
      error "Unsupported OS: $os. Use install.bat on Windows."
      exit 1 ;;
  esac
}

# ── Check Go is installed ────────────────────────────────────────
check_go() {
  if ! command -v go &>/dev/null; then
    error "Go is not installed."
    echo ""
    echo "  Install it from: https://go.dev/dl/"
    echo ""
    exit 1
  fi
  local ver
  ver="$(go version | awk '{print $3}' | sed 's/go//')"
  info "Go $ver found"
}

# ── Build binary ─────────────────────────────────────────────────
build_binary() {
  local name="$1"
  info "Building $name …"
  mkdir -p "$DIST_DIR"
  cd "$ROOT_DIR"
  go mod tidy -e 2>/dev/null || true
  go build -ldflags "-s -w" -o "$DIST_DIR/$name" .
  chmod +x "$DIST_DIR/$name"
  success "Built → dist/$name"
}

# ── Open browser ─────────────────────────────────────────────────
open_browser() {
  sleep 1
  if command -v xdg-open &>/dev/null; then
    xdg-open "$URL" &>/dev/null &
  elif command -v open &>/dev/null; then
    open "$URL" &
  fi
}

# ── Kill any process already on the port ─────────────────────────
free_port() {
  local pid
  pid=$(lsof -ti tcp:"$PORT" 2>/dev/null || true)
  if [ -n "$pid" ]; then
    warn "Port $PORT in use (PID $pid) — stopping it…"
    kill "$pid" 2>/dev/null || true
    sleep 1
  fi
}

# ── Main ─────────────────────────────────────────────────────────
main() {
  banner

  local bin_name
  bin_name="$(detect_binary)"
  local bin_path="$DIST_DIR/$bin_name"

  # Build if binary missing or --rebuild flag given
  if [ ! -f "$bin_path" ] || [[ "${1:-}" == "--rebuild" ]]; then
    check_go
    build_binary "$bin_name"
  else
    success "Binary already built: dist/$bin_name"
  fi

  free_port

  info "Starting server on $URL …"
  echo ""
  echo -e "  ${BOLD}Press Ctrl+C to stop.${NC}"
  echo ""

  open_browser &

  # Run from the project root so index.html and jobs.db resolve correctly
  cd "$ROOT_DIR"
  exec "$bin_path"
}

main "$@"
