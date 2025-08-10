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
	timestamps := make([]interface{}, len(ta))
	for i, t := range ta {
		timestamps[i] = t
	}
	return pq.Array(timestamps).Value()
}

// Scan implements sql.Scanner interface
func (ta *TimeArray) Scan(value interface{}) error {
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
	ProjectID     *uint          `gorm:"index" json:"project_id"`
	Project       *Project       `gorm:"foreignKey:ProjectID" json:"project"`
	DueDate       *time.Time     `json:"due_date"`
	DueDatetime   *time.Time     `json:"due_datetime"`
	StartDatetime *time.Time     `json:"start_datetime"`
	EndDatetime   *time.Time     `json:"end_datetime"`
	Labels        pq.StringArray `gorm:"type:text[]" json:"labels"`
	Reminders     TimeArray      `gorm:"type:timestamp[]" json:"reminders"`
	Recurrence    string         `json:"recurrence"`
	Order         int            `gorm:"default:0" json:"order"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	CompletedAt   *time.Time     `json:"completed_at"`
}

type Project struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Name      string    `gorm:"not null" json:"name"`
	Color     string    `gorm:"default:'gray'" json:"color"`
	Order     int       `gorm:"default:0" json:"order"`
	Tasks     []Task    `gorm:"foreignKey:ProjectID" json:"tasks"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Note struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Title     string    `gorm:"not null" json:"title"`
	Content   string    `json:"content"`
	AudioID   *uint     `gorm:"index" json:"audio_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Audio struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Data      string    `gorm:"type:text;not null" json:"data"`
	CreatedAt time.Time `json:"created_at"`
}
