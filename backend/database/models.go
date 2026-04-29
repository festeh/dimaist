package database

import (
	"database/sql/driver"
	"fmt"
	"time"

	"dimaist/utils"

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
		t, err := utils.ParseDatetime(ts)
		if err != nil {
			return err
		}
		(*ta)[i] = t
	}
	return nil
}

type Task struct {
	ID            uint                `gorm:"primaryKey" json:"id"`
	Title         string              `gorm:"column:title;not null" json:"title"`
	Description   *string             `json:"description,omitempty"`
	ProjectID     *uint               `gorm:"index" json:"project_id,omitempty"`
	Project       *Project            `gorm:"foreignKey:ProjectID" json:"project,omitempty"`
	Due           *utils.FlexibleTime `gorm:"type:timestamptz" json:"due,omitempty"`
	HasTime       bool                `json:"has_time" gorm:"column:has_time;default:false"`
	StartDatetime *utils.FlexibleTime `json:"start_datetime,omitempty"`
	EndDatetime   *utils.FlexibleTime `json:"end_datetime,omitempty"`
	Labels        pq.StringArray      `gorm:"type:text[]" json:"labels,omitempty"`
	Reminders     TimeArray           `gorm:"type:timestamptz[]" json:"reminders,omitempty"`
	Recurrence    string              `json:"recurrence,omitempty"`
	Order         int                 `gorm:"default:0" json:"order"`
	Revision      int64               `gorm:"not null;default:0;index" json:"revision"`
	CreatedAt     utils.FlexibleTime  `json:"created_at"`
	UpdatedAt     utils.FlexibleTime  `json:"updated_at"`
	DeletedAt     *utils.FlexibleTime `gorm:"index" json:"deleted_at,omitempty"`
	CompletedAt   *utils.FlexibleTime `json:"completed_at,omitempty"`
	GoogleEventID *string             `json:"google_event_id,omitempty"`
}

// DueTime returns the effective due date as *time.Time
func (t *Task) DueTime() *time.Time {
	if t.Due != nil {
		return t.Due.ToTimePtr()
	}
	return nil
}

type Project struct {
	ID        uint                `gorm:"primaryKey" json:"id"`
	Name      string              `gorm:"not null" json:"name"`
	Color     string              `gorm:"default:'gray'" json:"color,omitempty"`
	Icon      *string             `json:"icon,omitempty"`
	Order     int                 `gorm:"default:0" json:"order"`
	Tasks     []Task              `gorm:"foreignKey:ProjectID" json:"tasks,omitempty"`
	Revision  int64               `gorm:"not null;default:0;index" json:"revision"`
	CreatedAt utils.FlexibleTime  `json:"created_at"`
	UpdatedAt utils.FlexibleTime  `json:"updated_at"`
	DeletedAt *utils.FlexibleTime `gorm:"index" json:"deleted_at,omitempty"`
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

	// Default to Inbox if no project specified
	if task.ProjectID == nil {
		var inbox Project
		if err := DB.Where("name = ? AND deleted_at IS NULL", "Inbox").First(&inbox).Error; err == nil {
			task.ProjectID = &inbox.ID
		}
	}

	// Set order if not provided
	if task.Order == 0 {
		var maxOrder int
		DB.Model(&Task{}).Select("COALESCE(MAX(\"order\"), 0)").Where("project_id = ? AND deleted_at IS NULL", task.ProjectID).Scan(&maxOrder)
		task.Order = maxOrder + 1
	}

	// Ensure CreatedAt is set
	if task.CreatedAt.IsZero() {
		task.CreatedAt = utils.FlexibleTime{Time: time.Now()}
	}

	return DB.Create(task).Error
}
