//go:build windows

package icon

import (
	_ "embed"
	"unsafe"

	"golang.org/x/sys/windows"
)

// icon.ico is embedded and used to set the window icon at runtime.
// The .syso resource (built by go-winres) sets the .exe file icon shown in
// Explorer and the taskbar before the window opens.
//
//go:embed ../../assets/icon.ico
var appIconICO []byte

var (
	user32          = windows.NewLazySystemDLL("user32.dll")
	procSendMessage = user32.NewProc("SendMessageW")
	procLoadImage   = user32.NewProc("LoadImageW")
	kernel32        = windows.NewLazySystemDLL("kernel32.dll")
	procGetMod      = kernel32.NewProc("GetModuleHandleW")
)

const (
	imageIcon   = 1
	lrDefaultSz = 0x0040
	lrShared    = 0x8000
	wmSetIcon   = 0x0080
	iconSmall   = 0
	iconBig     = 1
)

// setWindowIcon loads the embedded .ico and sends WM_SETICON to hwnd.
// hwnd is the native HWND returned by webview.Window() cast to uintptr.
func SetWindowIcon(hwnd uintptr) {
	hmod, _, _ := procGetMod.Call(0)

	// Small icon (title bar, Alt+Tab)
	hIconSm, _, _ := procLoadImage.Call(
		hmod,
		uintptr(1), // resource ID 1 = first icon in the .exe (from .syso)
		imageIcon,
		16, 16,
		lrShared,
	)
	if hIconSm != 0 {
		procSendMessage.Call(hwnd, wmSetIcon, iconSmall, hIconSm)
	}

	// Large icon (taskbar, Alt+Tab large view)
	hIconBig, _, _ := procLoadImage.Call(
		hmod,
		uintptr(1),
		imageIcon,
		32, 32,
		lrShared,
	)
	if hIconBig != 0 {
		procSendMessage.Call(hwnd, wmSetIcon, iconBig, hIconBig)
	}

	_ = unsafe.Sizeof(appIconICO) // ensure embed is referenced
}