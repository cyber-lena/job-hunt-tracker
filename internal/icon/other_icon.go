//go:build !windows && !linux && !darwin

package icon

// SetWindowIcon is a no-op on unsupported platforms.
func SetWindowIcon(_ uintptr) {}