package database

import (
	"database/sql/driver"
	"fmt"
	"time"

	"github.com/lib/pq"
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

// Due returns the effective due date/datetime (DueDatetime takes precedence)
func (t *Task) Due() *time.Time {
	if t.DueDatetime != nil {
		return t.DueDatetime
	}
	return t.DueDate
}

// HasTime returns true if task has a specific time (DueDatetime) vs date-only
func (t *Task) HasTime() bool {
	return t.DueDatetime != nil
}

// SetDue sets the appropriate due field based on hasTime flag
func (t *Task) SetDue(due *time.Time, hasTime bool) {
	if due == nil {
		t.DueDate = nil
		t.DueDatetime = nil
		return
	}
	if hasTime {
		t.DueDatetime = due
		t.DueDate = nil
	} else {
		t.DueDate = due
		t.DueDatetime = nil
	}
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

// ValidateLabels returns error if labels contain empty strings
func ValidateLabels(labels []string) error {
	for _, label := range labels {
		if label == "" {
			return fmt.Errorf("labels cannot contain empty strings")
		}
	}
	return nil
}

// CreateTask validates and creates a task with proper defaults
func CreateTask(task *Task) error {
	if err := ValidateLabels(task.Labels); err != nil {
		return err
	}

	// Set order if not provided
	if task.Order == 0 {
		var maxOrder int
		DB.Model(&Task{}).Select("COALESCE(MAX(\"order\"), 0)").Where("project_id = ? AND deleted_at IS NULL", task.ProjectID).Scan(&maxOrder)
		task.Order = maxOrder + 1
	}

	// Ensure CreatedAt is set
	if task.CreatedAt.IsZero() {
		task.CreatedAt = time.Now()
	}

	return DB.Create(task).Error
}
