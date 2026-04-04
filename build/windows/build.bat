@echo off
:: ─────────────────────────────────────────────────────────────────────────────
::  Job Hunt Tracker — Windows build script
::  Run from the project root: build\windows\build.bat
::  Output: dist\job-tracker-windows-amd64.exe
:: ─────────────────────────────────────────────────────────────────────────────
setlocal

set CGO_ENABLED=1
set GOOS=windows
set GOARCH=amd64

if not exist dist mkdir dist

echo [..] Running go mod tidy...
go mod tidy
if %ERRORLEVEL% neq 0 (
    echo [!!] go mod tidy failed.
    exit /b 1
)

echo [..] Generating Windows resources (icon + manifest)...
go install github.com/tc-hib/go-winres@latest
go-winres make --in ..\..\winres\winres.json
if %ERRORLEVEL% neq 0 (
    echo [!!] go-winres failed. Make sure winres\icon.ico exists.
    exit /b 1
)

echo [..] Building...
set CGO_ENABLED=1
set GOOS=windows
set GOARCH=amd64
set CC=
set CGO_CFLAGS=-IC:\WebView2SDK\build\native\include
go env CGO_CFLAGS
set CGO_LDFLAGS=-LC:\WebView2SDK\x64
go clean -cache -modcache
go build -ldflags "-s -w -H=windowsgui" -o dist\job-tracker-windows-amd64.exe ..\..\
if %ERRORLEVEL% neq 0 (
    echo [!!] Build failed.
    exit /b 1
)

echo [OK] dist\job-tracker-windows-amd64.exe

endlocal
