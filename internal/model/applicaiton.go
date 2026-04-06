package model

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