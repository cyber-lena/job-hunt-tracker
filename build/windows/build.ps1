# ─────────────────────────────────────────────────────────────────
#  Job Hunt Tracker — Windows build script (PowerShell)
#  Run from the project root:
#    powershell -ExecutionPolicy Bypass -File build\windows\build.ps1
# ─────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$env:CGO_ENABLED = "1"
$env:GOOS        = "windows"
$env:GOARCH      = "amd64"

if (-not (Test-Path "dist")) { New-Item -ItemType Directory -Path "dist" | Out-Null }

Write-Host "[..] Running go mod tidy..."
go mod tidy
if ($LASTEXITCODE -ne 0) { Write-Host "[!!] go mod tidy failed."; exit 1 }

Write-Host "[..] Generating Windows resources (icon + manifest)..."
go install github.com/tc-hib/go-winres@latest
go-winres make --in ..\..\winres\winres.json
if ($LASTEXITCODE -ne 0) { Write-Host "[!!] go-winres failed. Make sure winres\icon.ico exists."; exit 1 }

Write-Host "[..] Building job-hunt-tracker-windows-amd64.exe..."
Set-Variable CGO_ENABLED=1
Set-Variable GOOS=windows
Set-Variable GOARCH=amd64
Set-Variable CC=
Set-Variable CGO_CFLAGS=-IC:\WebView2SDK\build\native\include
Set-Variable CGO_LDFLAGS=-LC:\WebView2SDK\x64
go clean -cache -modcache
go build -ldflags "-s -w -H=windowsgui -l C:\WebView2SDK\x64" -gcflags "-i C:\WebView2SDK\build\native\include" -o dist\job-tracker-windows-amd64.exe ..\..\
if ($LASTEXITCODE -ne 0) { Write-Host "[!!] Build failed."; exit 1 }

Write-Host "[OK] dist\job-hunt-tracker-windows-amd64.exe"

# Optional: run NSIS installer build
# makensis build\windows\installer.nsi
