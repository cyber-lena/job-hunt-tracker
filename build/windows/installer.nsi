; ─────────────────────────────────────────────────────────────────────────────
;  Job Hunt Tracker — Windows Installer (NSIS)
;
;  Requirements: NSIS 3.x  https://nsis.sourceforge.io/
;  Usage:
;    1.  Build the binary first:
;          make build-windows
;    2.  Compile this script:
;          makensis build/windows/installer.nsi
;    3.  Output: dist/JobHuntTracker-Setup.exe
; ─────────────────────────────────────────────────────────────────────────────

!define APP_NAME        "Job Hunt Tracker"
!define APP_EXE         "job-hunt-tracker.exe"
!define PUBLISHER       "Job Hunt Tracker"
!define APP_URL         "http://localhost:8080"
!define INSTALL_DIR     "$PROGRAMFILES64\JobHuntTracker"
!define UNINSTALL_KEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\JobHuntTracker"
!define SOURCE_EXE      "..\..\dist\job-hunt-tracker-windows-amd64.exe"
!define ICON_PATH       "..\..\winres\icon.ico"

; ── Metadata ──────────────────────────────────────────────────────────────────
Name              "${APP_NAME}"
OutFile           "..\..\dist\JobHuntTracker-Setup.exe"
InstallDir        "${INSTALL_DIR}"
InstallDirRegKey  HKLM "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel admin
SetCompressor     /SOLID lzma
Icon              "${ICON_PATH}"
Unicode           True

; ── Modern UI ─────────────────────────────────────────────────────────────────
!include "MUI2.nsh"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN         "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT    "Launch Job Hunt Tracker now"
!define MUI_FINISHPAGE_LINK        "Open http://localhost:8080 after launch"
!define MUI_FINISHPAGE_LINK_LOCATION "${APP_URL}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ── Install section ───────────────────────────────────────────────────────────
Section "Install"

  SetOutPath "$INSTDIR"

  ; Copy binary (renamed to friendly name)
  File /oname=${APP_EXE} "${SOURCE_EXE}"

  ; ── Start Menu shortcut ────────────────────────────────────────────────────
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" \
                  "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0 \
                  SW_SHOWMINIMIZED "" "Track your job applications"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" \
                  "$INSTDIR\Uninstall.exe"

  ; ── Desktop shortcut ───────────────────────────────────────────────────────
  CreateShortcut  "$DESKTOP\${APP_NAME}.lnk" \
                  "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0 \
                  SW_SHOWMINIMIZED "" "Track your job applications"

  ; ── Uninstaller ────────────────────────────────────────────────────────────
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify"         1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 

  ; ── Registry (Add/Remove Programs) ────────────────────────────────────────
  WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayName"          "${APP_NAME}"
  WriteRegStr   HKLM "${UNINSTALL_KEY}" "UninstallString"      "$INSTDIR\Uninstall.exe"
  WriteRegStr   HKLM "${UNINSTALL_KEY}" "InstallLocation"      "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTALL_KEY}" "Publisher"            "${PUBLISHER}"
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify"             1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair"             1
  WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayIcon"      "$INSTDIR\${APP_EXE},0"

SectionEnd

; ── Uninstall section ─────────────────────────────────────────────────────────
Section "Uninstall"

  ; Kill running instance first
  nsExec::Exec 'taskkill /F /IM "${APP_EXE}"'

  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir  "$INSTDIR"

  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"
  RMDir  "$SMPROGRAMS\${APP_NAME}"

  Delete "$DESKTOP\${APP_NAME}.lnk"

  DeleteRegKey HKLM "${UNINSTALL_KEY}"

  ; Note: user data (%APPDATA%\JobHuntTracker\jobs.db) is intentionally kept.

SectionEnd
