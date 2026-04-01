@echo off
:: ─────────────────────────────────────────────────────────────────
::  Job Hunt Tracker — installer & launcher (Windows)
:: ─────────────────────────────────────────────────────────────────
setlocal EnableDelayedExpansion

set BINARY=job-tracker-windows-amd64.exe
set PORT=8080
set URL=http://localhost:%PORT%

:: Resolve project root (one level up from \scripts\)
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..
set DIST_DIR=%ROOT_DIR%\dist

echo.
echo   ╔══════════════════════════════════════╗
echo   ║       Job Hunt Tracker               ║
echo   ╚══════════════════════════════════════╝
echo.

:: ── Check if binary exists ────────────────────────────────────────
if exist "%DIST_DIR%\%BINARY%" (
    echo   [OK]  Binary found: dist\%BINARY%
    goto :launch
)

:: ── Binary missing — need to build ───────────────────────────────
echo   [..] Binary not found. Building now...
echo.

:: Check Go
where go >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [!!] Go is not installed or not in PATH.
    echo.
    echo        Download it from: https://go.dev/dl/
    echo        After installing, re-run this script.
    echo.
    pause
    exit /b 1
)

for /f "tokens=3" %%v in ('go version') do set GO_VER=%%v
echo   [OK] !GO_VER! found

:: Build
echo   [..] Running go mod tidy...
pushd "%ROOT_DIR%"
go mod tidy
if %ERRORLEVEL% neq 0 (
    echo   [!!] go mod tidy failed. Check your internet connection.
    pause
    exit /b 1
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

echo   [..] Compiling for Windows...
set GOOS=windows
set GOARCH=amd64
go build -ldflags "-s -w" -o "%DIST_DIR%\%BINARY%" .
if %ERRORLEVEL% neq 0 (
    echo   [!!] Build failed.
    pause
    exit /b 1
)
popd

echo   [OK] Built: dist\%BINARY%
echo.

:launch
:: ── Free port if in use ──────────────────────────────────────────
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":%PORT% " ^| findstr LISTENING 2^>nul') do (
    echo   [..] Port %PORT% in use (PID %%p) — stopping it...
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 1 /nobreak >nul
)

:: ── Launch ───────────────────────────────────────────────────────
echo   [>>] Starting server at %URL%
echo.
echo        Press Ctrl+C in this window to stop the app.
echo.

:: Open browser after short delay
start "" /B cmd /c "timeout /t 2 /nobreak >nul && start %URL%"

:: Run the server from project root (so index.html + jobs.db resolve)
pushd "%ROOT_DIR%"
"%DIST_DIR%\%BINARY%"
popd

endlocal
