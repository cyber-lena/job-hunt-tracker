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

echo [..] Building...
go build -ldflags "-s -w -H=windowsgui" -o dist\job-tracker-windows-amd64.exe .
if %ERRORLEVEL% neq 0 (
    echo [!!] Build failed.
    exit /b 1
)

echo [OK] dist\job-tracker-windows-amd64.exe
endlocal
