//go:build darwin

package main

// setWindowIcon is a no-op on macOS.
// The window icon is set automatically by macOS from the .icns file
// declared in the .app bundle's Info.plist (CFBundleIconFile).
func setWindowIcon(_ uintptr) {}
