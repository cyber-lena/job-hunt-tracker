package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	webview "github.com/webview/webview_go"
	"job-tracker/internal/database"
)

//go:embed index.html
var indexHTML []byte

// ─── Server ───────────────────────────────────────────────────────────────────

type server struct {
	store database.Store
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func idFromPath(path, prefix string) (int, bool) {
	s := strings.TrimPrefix(path, prefix)
	s = strings.Trim(s, "/")
	n, err := strconv.Atoi(s)
	return n, err == nil
}

// ─── Handlers ────────────────────────────────────────────────────────────────

func (s *server) listApplications(w http.ResponseWriter, r *http.Request) {
	apps, err := s.store.List()
	if err != nil {
		writeError(w, 500, "DB error")
		return
	}
	writeJSON(w, 200, apps)
}

func (s *server) createApplication(w http.ResponseWriter, r *http.Request) {
	var a database.Application
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		writeError(w, 400, "Invalid JSON")
		return
	}
	if a.Company == "" || a.Role == "" {
		writeError(w, 400, "company and role are required")
		return
	}
	if a.Status == "" {
		a.Status = "Wishlist"
	}
	if a.Currency == "" {
		a.Currency = "USD"
	}
	created, err := s.store.Create(a)
	if err != nil {
		writeError(w, 500, "Insert error")
		return
	}
	writeJSON(w, 201, created)
}

func (s *server) updateApplication(w http.ResponseWriter, r *http.Request, id int) {
	var a database.Application
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		writeError(w, 400, "Invalid JSON")
		return
	}
	updated, found, err := s.store.Update(id, a)
	if err != nil {
		writeError(w, 500, "Update error")
		return
	}
	if !found {
		writeError(w, 404, "Not found")
		return
	}
	writeJSON(w, 200, updated)
}

func (s *server) deleteApplication(w http.ResponseWriter, r *http.Request, id int) {
	found, err := s.store.Delete(id)
	if err != nil {
		writeError(w, 500, "Delete error")
		return
	}
	if !found {
		writeError(w, 404, "Not found")
		return
	}
	writeJSON(w, 200, map[string]any{"deleted": id})
}

// ─── Router ──────────────────────────────────────────────────────────────────

func (s *server) router(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path

	if path == "/" || path == "/index.html" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write(indexHTML)
		return
	}

	if path == "/api/applications" {
		switch r.Method {
		case http.MethodGet:
			s.listApplications(w, r)
		case http.MethodPost:
			s.createApplication(w, r)
		default:
			writeError(w, 405, "Method not allowed")
		}
		return
	}

	if strings.HasPrefix(path, "/api/applications/") {
		id, ok := idFromPath(path, "/api/applications/")
		if !ok {
			writeError(w, 400, "Invalid ID")
			return
		}
		switch r.Method {
		case http.MethodPut:
			s.updateApplication(w, r, id)
		case http.MethodDelete:
			s.deleteApplication(w, r, id)
		default:
			writeError(w, 405, "Method not allowed")
		}
		return
	}

	writeError(w, 404, "Not found")
}

// ─── Data directory ───────────────────────────────────────────────────────────

// dataDir returns the platform config dir for storing jobs.db:
//
//	Windows : %APPDATA%\JobHuntTracker\
//	macOS   : ~/Library/Application Support/JobHuntTracker/
//	Linux   : ~/.config/JobHuntTracker/
func dataDir() string {
	base, err := os.UserConfigDir()
	if err != nil {
		base = "."
	}
	dir := filepath.Join(base, "JobHuntTracker")
	os.MkdirAll(dir, 0o755)
	return dir
}

// ─── Free port ────────────────────────────────────────────────────────────────

// freePort asks the OS for an available loopback port so we never conflict
// with other services.
func freePort() int {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Fatal("Cannot find free port:", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()
	return port
}

// ─── Main ────────────────────────────────────────────────────────────────────

func main() {
	// ── DB ────────────────────────────────────────────────────────────────────
	dbPath := filepath.Join(dataDir(), "jobs.db")
	store, err := database.NewSQLiteStore(dbPath)
	if err != nil {
		log.Fatal("Failed to init DB:", err)
	}
	defer store.Close()

	// ── HTTP server on a random free loopback port ────────────────────────────
	port := freePort()
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	appURL := fmt.Sprintf("http://%s", addr)

	mux := http.NewServeMux()
	srv := &server{store: store}
	mux.HandleFunc("/", srv.router)

	go func() {
		if err := http.ListenAndServe(addr, mux); err != nil {
			log.Fatal("Server error:", err)
		}
	}()

	// ── Native desktop window ─────────────────────────────────────────────────
	//   macOS   → WKWebView   (built-in, no extra deps)
	//   Windows → WebView2    (ships with Edge / Win10+)
	//   Linux   → WebKitGTK   (needs libwebkit2gtk-4.1-dev)
	w := webview.New(false) // false = devtools disabled in release builds
	defer w.Destroy()

	w.SetTitle("Job Hunt Tracker")
	w.SetSize(1280, 820, webview.HintNone)
	w.Navigate(appURL)
	w.Run() // blocks until the window is closed → process exits cleanly
}


// ─── Helpers ─────────────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func idFromPath(path, prefix string) (int, bool) {
	s := strings.TrimPrefix(path, prefix)
	s = strings.Trim(s, "/")
	n, err := strconv.Atoi(s)
	return n, err == nil
}

// ─── Handlers ────────────────────────────────────────────────────────────────

// GET /api/applications
func (s *server) listApplications(w http.ResponseWriter, r *http.Request) {
	apps, err := s.store.List()
	if err != nil {
		writeError(w, 500, "DB error")
		return
	}
	writeJSON(w, 200, apps)
}

// POST /api/applications
func (s *server) createApplication(w http.ResponseWriter, r *http.Request) {
	var a database.Application
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		writeError(w, 400, "Invalid JSON")
		return
	}
	if a.Company == "" || a.Role == "" {
		writeError(w, 400, "company and role are required")
		return
	}
	if a.Status == "" {
		a.Status = "Wishlist"
	}
	if a.Currency == "" {
		a.Currency = "USD"
	}

	created, err := s.store.Create(a)
	if err != nil {
		writeError(w, 500, "Insert error")
		return
	}
	writeJSON(w, 201, created)
}

// PUT /api/applications/{id}
func (s *server) updateApplication(w http.ResponseWriter, r *http.Request, id int) {
	var a database.Application
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		writeError(w, 400, "Invalid JSON")
		return
	}

	updated, found, err := s.store.Update(id, a)
	if err != nil {
		writeError(w, 500, "Update error")
		return
	}
	if !found {
		writeError(w, 404, "Not found")
		return
	}
	writeJSON(w, 200, updated)
}

// DELETE /api/applications/{id}
func (s *server) deleteApplication(w http.ResponseWriter, r *http.Request, id int) {
	found, err := s.store.Delete(id)
	if err != nil {
		writeError(w, 500, "Delete error")
		return
	}
	if !found {
		writeError(w, 404, "Not found")
		return
	}
	writeJSON(w, 200, map[string]any{"deleted": id})
}

// ─── Router ──────────────────────────────────────────────────────────────────

func (s *server) router(w http.ResponseWriter, r *http.Request) {
	// CORS for local dev
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	if r.Method == http.MethodOptions {
		w.WriteHeader(204)
		return
	}

	path := r.URL.Path

	// Static files — served from embedded binary
	if path == "/" || path == "/index.html" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write(indexHTML)
		return
	}

	// /api/applications
	if path == "/api/applications" {
		switch r.Method {
		case http.MethodGet:
			s.listApplications(w, r)
		case http.MethodPost:
			s.createApplication(w, r)
		default:
			writeError(w, 405, "Method not allowed")
		}
		return
	}

	// /api/applications/{id}
	if strings.HasPrefix(path, "/api/applications/") {
		id, ok := idFromPath(path, "/api/applications/")
		if !ok {
			writeError(w, 400, "Invalid ID")
			return
		}
		switch r.Method {
		case http.MethodPut:
			s.updateApplication(w, r, id)
		case http.MethodDelete:
			s.deleteApplication(w, r, id)
		default:
			writeError(w, 405, "Method not allowed")
		}
		return
	}

	writeError(w, 404, "Not found")
}

// ─── Data directory ───────────────────────────────────────────────────────────
