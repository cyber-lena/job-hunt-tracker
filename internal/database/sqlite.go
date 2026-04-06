package database

import (
	"database/sql"
	"time"

	_ "modernc.org/sqlite"
)

// ─── Model ───────────────────────────────────────────────────────────────────

type Application struct {
	ID          int    `json:"id"`
	Company     string `json:"company"`
	Role        string `json:"role"`
	Status      string `json:"status"`
	SalaryMin   *int   `json:"salary_min"`
	SalaryMax   *int   `json:"salary_max"`
	Currency    string `json:"currency"`
	Comments    string `json:"comments"`
	ContactName string `json:"contact_name"`
	ContactInfo string `json:"contact_info"`
	AppliedAt   string `json:"applied_at"`
	UpdatedAt   string `json:"updated_at"`
}

// ─── Interface ────────────────────────────────────────────────────────────────

type Store interface {
	List() ([]Application, error)
	Create(a Application) (Application, error)
	Update(id int, a Application) (Application, bool, error)
	Delete(id int) (bool, error)
	Close() error
}

// ─── SQLite implementation ────────────────────────────────────────────────────

type SQLiteStore struct {
	db *sql.DB
}

func NewSQLiteStore(path string) (*SQLiteStore, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}

	schema := `
	CREATE TABLE IF NOT EXISTS applications (
		id           INTEGER PRIMARY KEY AUTOINCREMENT,
		company      TEXT    NOT NULL,
		role         TEXT    NOT NULL,
		status       TEXT    NOT NULL DEFAULT 'Wishlist',
		salary_min   INTEGER,
		salary_max   INTEGER,
		currency     TEXT    NOT NULL DEFAULT 'USD',
		comments     TEXT    NOT NULL DEFAULT '',
		contact_name TEXT    NOT NULL DEFAULT '',
		contact_info TEXT    NOT NULL DEFAULT '',
		applied_at   TEXT    NOT NULL,
		updated_at   TEXT    NOT NULL
	);`
	if _, err := db.Exec(schema); err != nil {
		return nil, err
	}

	return &SQLiteStore{db: db}, nil
}

func (s *SQLiteStore) Close() error {
	return s.db.Close()
}

func now() string { return time.Now().Format("2006-01-02T15:04:05") }

// List returns all applications ordered by updated_at DESC.
func (s *SQLiteStore) List() ([]Application, error) {
	rows, err := s.db.Query(`
		SELECT id, company, role, status,
		       salary_min, salary_max, currency,
		       comments, contact_name, contact_info,
		       applied_at, updated_at
		FROM applications ORDER BY updated_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	apps := []Application{}
	for rows.Next() {
		var a Application
		if err := rows.Scan(
			&a.ID, &a.Company, &a.Role, &a.Status,
			&a.SalaryMin, &a.SalaryMax, &a.Currency,
			&a.Comments, &a.ContactName, &a.ContactInfo,
			&a.AppliedAt, &a.UpdatedAt,
		); err != nil {
			return nil, err
		}
		apps = append(apps, a)
	}
	return apps, nil
}

// Create inserts a new application and returns it with ID and timestamps set.
func (s *SQLiteStore) Create(a Application) (Application, error) {
	t := now()
	res, err := s.db.Exec(`
		INSERT INTO applications
		  (company, role, status, salary_min, salary_max, currency,
		   comments, contact_name, contact_info, applied_at, updated_at)
		VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
		a.Company, a.Role, a.Status, a.SalaryMin, a.SalaryMax, a.Currency,
		a.Comments, a.ContactName, a.ContactInfo, t, t,
	)
	if err != nil {
		return Application{}, err
	}
	id, _ := res.LastInsertId()
	a.ID = int(id)
	a.AppliedAt = t
	a.UpdatedAt = t
	return a, nil
}

// Update modifies an existing application by ID.
// Returns the updated application, a found flag, and any error.
func (s *SQLiteStore) Update(id int, a Application) (Application, bool, error) {
	t := now()
	res, err := s.db.Exec(`
		UPDATE applications SET
		  company=?, role=?, status=?,
		  salary_min=?, salary_max=?, currency=?,
		  comments=?, contact_name=?, contact_info=?, applied_at=?,
		  updated_at=?
		WHERE id=?`,
		a.Company, a.Role, a.Status,
		a.SalaryMin, a.SalaryMax, a.Currency,
		a.Comments, a.ContactName, a.ContactInfo, a.AppliedAt,
		t, id,
	)
	if err != nil {
		return Application{}, false, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return Application{}, false, nil
	}
	a.ID = id
	a.UpdatedAt = t
	return a, true, nil
}

// Delete removes an application by ID.
// Returns a found flag and any error.
func (s *SQLiteStore) Delete(id int) (bool, error) {
	res, err := s.db.Exec(`DELETE FROM applications WHERE id=?`, id)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}
