//go:build linux

package icon

/*
#cgo linux pkg-config: gtk+-3.0
#include <gtk/gtk.h>

void set_gtk_icon(GtkWidget *widget, const guint8 *data, gsize length) {
    GInputStream *stream = g_memory_input_stream_new_from_data(data, (gssize)length, NULL);
    if (!stream) return;
    GdkPixbuf *pixbuf = gdk_pixbuf_new_from_stream(stream, NULL, NULL);
    g_object_unref(stream);
    if (!pixbuf) return;
    gtk_window_set_icon(GTK_WINDOW(widget), pixbuf);
    g_object_unref(pixbuf);
}
*/
import "C"

import (
	_ "embed"
	"unsafe"
)

//go:embed ../../assets/icon.png
var iconPNG []byte

// setWindowIcon sets the GTK window icon from the embedded PNG.
// hwnd is the GtkWidget* returned by webview.Window() on Linux.
func SetWindowIcon(hwnd uintptr) {
	if len(iconPNG) == 0 || hwnd == 0 {
		return
	}
	widget := (*C.GtkWidget)(unsafe.Pointer(hwnd))
	data := (*C.guint8)(unsafe.Pointer(&iconPNG[0]))
	C.set_gtk_icon(widget, data, C.gsize(len(iconPNG)))
}