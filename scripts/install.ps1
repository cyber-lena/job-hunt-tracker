# ─────────────────────────────────────────────────────────────────
#  Job Hunt Tracker — installer & launcher (Windows PowerShell)
#  Usage: Right-click → "Run with PowerShell"
#         or: powershell -ExecutionPolicy Bypass -File install.ps1
# ─────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$Binary  = "job-tracker-windows-amd64.exe"
$Port    = 8080
$Url     = "http://localhost:$Port"
$Root    = Resolve-Path (Join-Path $PSScriptRoot "..")
$DistDir = Join-Path $Root "dist"
$BinPath = Join-Path $DistDir $Binary

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       Job Hunt Tracker               ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info    { param($m) Write-Host "  " -NoNewline; Write-Host "▶" -ForegroundColor Green -NoNewline; Write-Host "  $m" }
function Write-Success { param($m) Write-Host "  " -NoNewline; Write-Host "✔" -ForegroundColor Green -NoNewline; Write-Host "  $m" }
function Write-Warn    { param($m) Write-Host "  " -NoNewline; Write-Host "⚠" -ForegroundColor Yellow -NoNewline; Write-Host "  $m" }
function Write-Err     { param($m) Write-Host "  " -NoNewline; Write-Host "✖" -ForegroundColor Red -NoNewline; Write-Host "  $m" }

# ── Check Go ─────────────────────────────────────────────────────
function Assert-Go {
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Err "Go is not installed or not in PATH."
        Write-Host ""
        Write-Host "     Download: https://go.dev/dl/" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
    $ver = (go version) -replace "go version go", "" -replace " .*", ""
    Write-Info "Go $ver found"
}

# ── Build ────────────────────────────────────────────────────────
function Build-Binary {
    Write-Info "Running go mod tidy..."
    Push-Location $Root
    go mod tidy
    if ($LASTEXITCODE -ne 0) {
        Write-Err "go mod tidy failed. Check your internet connection."
        Pop-Location; exit 1
    }

    if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir | Out-Null }

    Write-Info "Compiling for Windows (amd64)..."
    $env:GOOS    = "windows"
    $env:GOARCH  = "amd64"
    go build -ldflags "-s -w" -o $BinPath .
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Build failed."
        Pop-Location; exit 1
    }
    Remove-Item Env:GOOS, Env:GOARCH -ErrorAction SilentlyContinue
    Pop-Location
    Write-Success "Built: dist\$Binary"
}

# ── Free port ────────────────────────────────────────────────────
function Free-Port {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $pid = $conn.OwningProcess
        Write-Warn "Port $Port in use (PID $pid) — stopping it..."
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

# ── Open browser ─────────────────────────────────────────────────
function Open-Browser {
    Start-Job {
        Start-Sleep -Seconds 2
        Start-Process $using:Url
    } | Out-Null
}

# ─────────────────────────────────────────────────────────────────
Write-Banner

if (-not (Test-Path $BinPath)) {
    Write-Info "Binary not found — building now..."
    Write-Host ""
    Assert-Go
    Build-Binary
    Write-Host ""
} else {
    Write-Success "Binary found: dist\$Binary"
}

Free-Port
Open-Browser

Write-Info "Starting server at $Url"
Write-Host ""
Write-Host "  Press Ctrl+C to stop the app." -ForegroundColor White
Write-Host ""

# Run from project root so index.html + jobs.db resolve correctly
Set-Location $Root
& $BinPath
