package utils

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

// UserLocation is the user's timezone, used when parsing bare datetime strings.
var UserLocation = func() *time.Location {
	loc, err := time.LoadLocation("Europe/Berlin")
	if err != nil {
		panic("failed to load Europe/Berlin timezone: " + err.Error())
	}
	return loc
}()

// ParseDatetime tries multiple formats to parse datetime strings.
// Strings with timezone info are parsed as-is (proper UTC conversion).
// Bare strings (no timezone) are assumed to be in the user's timezone.
func ParseDatetime(s string) (time.Time, error) {
	// Formats with timezone — parse normally, timezone determines UTC value
	for _, f := range []string{
		time.RFC3339, time.RFC3339Nano,
		"2006-01-02T15:04:05Z07:00", "2006-01-02T15:04Z07:00",
		"2006-01-02 15:04:05Z07:00",
		"2006-01-02 15:04:05-07",    // PostgreSQL timestamptz format
		"2006-01-02 15:04:05.999-07", // PostgreSQL timestamptz with fractional seconds
	} {
		if t, err := time.Parse(f, s); err == nil {
			return t.UTC(), nil
		}
	}
	// Bare strings (no timezone) — assume user's timezone
	for _, f := range []string{
		"2006-01-02T15:04:05.000", "2006-01-02T15:04:05", "2006-01-02T15:04",
		"2006-01-02 15:04:05", "2006-01-02 15:04",
	} {
		if t, err := time.ParseInLocation(f, s, UserLocation); err == nil {
			return t.UTC(), nil
		}
	}
	return time.Time{}, fmt.Errorf("unable to parse datetime: %s", s)
}

// FlexibleTime wraps time.Time to accept multiple JSON datetime formats
type FlexibleTime struct {
	time.Time
}

func (ft *FlexibleTime) UnmarshalJSON(data []byte) error {
	var s string
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}
	if s == "" {
		return nil
	}

	t, err := ParseDatetime(s)
	if err != nil {
		return err
	}
	ft.Time = t
	return nil
}

func (ft FlexibleTime) MarshalJSON() ([]byte, error) {
	if ft.IsZero() {
		return []byte("null"), nil
	}
	// Minute granularity in UTC — frontend converts to local
	return json.Marshal(ft.Time.UTC().Format("2006-01-02T15:04Z"))
}

// Value implements driver.Valuer for GORM
func (ft FlexibleTime) Value() (driver.Value, error) {
	if ft.IsZero() {
		return nil, nil
	}
	return ft.Time, nil
}

// Scan implements sql.Scanner for GORM
func (ft *FlexibleTime) Scan(value any) error {
	if value == nil {
		ft.Time = time.Time{}
		return nil
	}
	if t, ok := value.(time.Time); ok {
		ft.Time = t
		return nil
	}
	return fmt.Errorf("cannot scan %T into FlexibleTime", value)
}

// ToTimePtr converts FlexibleTime to *time.Time (nil if zero)
func (ft *FlexibleTime) ToTimePtr() *time.Time {
	if ft == nil || ft.IsZero() {
		return nil
	}
	return &ft.Time
}

// NewFlexibleTime creates a FlexibleTime from time.Time
func NewFlexibleTime(t time.Time) *FlexibleTime {
	return &FlexibleTime{Time: t}
}

// NewFlexibleTimePtr creates a *FlexibleTime from *time.Time
func NewFlexibleTimePtr(t *time.Time) *FlexibleTime {
	if t == nil {
		return nil
	}
	return &FlexibleTime{Time: *t}
}
