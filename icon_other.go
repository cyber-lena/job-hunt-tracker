//go:build !windows && !linux && !darwin

package main

// setWindowIcon is a no-op on unsupported platforms.
func setWindowIcon(_ uintptr) {}
