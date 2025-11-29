package database

import (
	"database/sql/driver"
	"github.com/lib/pq"
	"time"
)

// TimeArray is a custom type for handling timestamp arrays
type TimeArray []time.Time

// Value implements driver.Valuer interface
func (ta TimeArray) Value() (driver.Value, error) {
	if ta == nil {
		return nil, nil
	}
	timestamps := make([]any, len(ta))
	for i, t := range ta {
		timestamps[i] = t
	}
	return pq.Array(timestamps).Value()
}

// Scan implements sql.Scanner interface
func (ta *TimeArray) Scan(value any) error {
	var timestamps pq.StringArray
	if err := timestamps.Scan(value); err != nil {
		return err
	}

	*ta = make(TimeArray, len(timestamps))
	for i, ts := range timestamps {
		t, err := time.Parse(time.RFC3339, ts)
		if err != nil {
			return err
		}
		(*ta)[i] = t
	}
	return nil
}

type Task struct {
	ID            uint           `gorm:"primaryKey" json:"id"`
	Description   string         `gorm:"not null" json:"description"`
	Notes         string         `json:"notes,omitempty"`
	ProjectID     *uint          `gorm:"index" json:"project_id,omitempty"`
	Project       *Project       `gorm:"foreignKey:ProjectID" json:"project,omitempty"`
	DueDate       *time.Time     `json:"due_date,omitempty"`
	DueDatetime   *time.Time     `json:"due_datetime,omitempty"`
	StartDatetime *time.Time     `json:"start_datetime,omitempty"`
	EndDatetime   *time.Time     `json:"end_datetime,omitempty"`
	Labels        pq.StringArray `gorm:"type:text[]" json:"labels,omitempty"`
	Reminders     TimeArray      `gorm:"type:timestamp[]" json:"reminders,omitempty"`
	Recurrence    string         `json:"recurrence,omitempty"`
	Order         int            `gorm:"default:0" json:"order"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     *time.Time     `gorm:"index" json:"deleted_at,omitempty"`
	CompletedAt   *time.Time     `json:"completed_at,omitempty"`
	GoogleEventID *string        `json:"google_event_id,omitempty"`
}

type Project struct {
	ID        uint       `gorm:"primaryKey" json:"id"`
	Name      string     `gorm:"not null" json:"name"`
	Color     string     `gorm:"default:'gray'" json:"color,omitempty"`
	Icon      *string    `json:"icon,omitempty"`
	Order     int        `gorm:"default:0" json:"order"`
	Tasks     []Task     `gorm:"foreignKey:ProjectID" json:"tasks,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `gorm:"index" json:"deleted_at,omitempty"`
}

type Audio struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Data      string    `gorm:"type:text;not null" json:"data"`
	CreatedAt time.Time `json:"created_at"`
}
