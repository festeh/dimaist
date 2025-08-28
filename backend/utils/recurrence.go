package utils

import (
	"fmt"
	"slices"
	"strconv"
	"strings"
	"time"
)

// ValidateRecurrence validates the recurrence string by trying to calculate next due date
func ValidateRecurrence(recurrence string) error {
	if recurrence == "" {
		return nil // Empty is valid (no recurrence)
	}

	// Try to calculate next due date with current time as test
	now := time.Now()
	_, err := CalculateNextDueDate(recurrence, &now)
	return err
}

// ValidateTaskRecurrence validates task recurrence including due date requirements
func ValidateTaskRecurrence(recurrence string, dueDate, dueDatetime *time.Time) error {
	if recurrence != "" {
		// Check that at least one due date field is provided for recurring tasks
		if dueDate == nil && dueDatetime == nil {
			return fmt.Errorf("recurring task must have either due_date or due_datetime")
		}

		return ValidateRecurrence(recurrence)
	}
	return nil
}

// CalculateNextDueDate calculates the next due date based on recurrence pattern
func CalculateNextDueDate(recurrence string, currentDue *time.Time) (*time.Time, error) {
	if recurrence == "" {
		return nil, nil // No recurrence
	}

	now := time.Now()
	baseDate := now
	if currentDue != nil {
		baseDate = *currentDue
	}

	// Daily
	dailyPatterns := []string{"day", "daily", "everyday", "every day"}
	if slices.Contains(dailyPatterns, strings.ToLower(recurrence)) {
		next := baseDate.AddDate(0, 0, 1)
		return &next, nil
	}

	// Weekly (same day next week)
	weeklyPatterns := []string{"week", "weekly", "every week"}
	if slices.Contains(weeklyPatterns, strings.ToLower(recurrence)) {
		next := baseDate.AddDate(0, 0, 7)
		return &next, nil
	}

	// Weekly patterns (specific weekdays)
	weekdays := map[string]time.Weekday{
		"sun": time.Sunday, "mon": time.Monday, "tue": time.Tuesday,
		"wed": time.Wednesday, "thu": time.Thursday, "fri": time.Friday, "sat": time.Saturday,
	}

	if strings.Contains(recurrence, ",") {
		// Multiple weekdays - find next occurrence
		days := strings.Split(recurrence, ",")
		var targetWeekdays []time.Weekday
		for _, day := range days {
			if wd, ok := weekdays[strings.TrimSpace(strings.ToLower(day))[:3]]; ok {
				targetWeekdays = append(targetWeekdays, wd)
			}
		}

		next := findNextWeekday(baseDate, targetWeekdays)
		return &next, nil
	} else if wd, ok := weekdays[strings.ToLower(recurrence)]; ok {
		// Single weekday
		next := findNextWeekday(baseDate, []time.Weekday{wd})
		return &next, nil
	}

	// Monthly patterns
	parts := strings.Fields(recurrence)
	if len(parts) == 1 {
		// Monthly on specific day
		day, err := strconv.Atoi(parts[0])
		if err == nil && day >= 1 && day <= 31 {
			next := findNextMonthlyDate(baseDate, day, 0)
			return &next, nil
		}
	} else if len(parts) == 2 {
		// Yearly on specific day and month
		day, err := strconv.Atoi(parts[0])
		if err == nil {
			monthMap := map[string]time.Month{
				"jan": time.January, "feb": time.February, "mar": time.March,
				"apr": time.April, "may": time.May, "jun": time.June,
				"jul": time.July, "aug": time.August, "sep": time.September,
				"oct": time.October, "nov": time.November, "dec": time.December,
			}
			if month, ok := monthMap[strings.ToLower(parts[1])[:3]]; ok {
				next := findNextYearlyDate(baseDate, day, month)
				return &next, nil
			}
		}
	}

	return nil, fmt.Errorf("unsupported recurrence pattern: %s", recurrence)
}

func findNextWeekday(from time.Time, weekdays []time.Weekday) time.Time {
	for i := 1; i <= 7; i++ {
		candidate := from.AddDate(0, 0, i)
		if slices.Contains(weekdays, candidate.Weekday()) {
			return candidate
		}
	}
	return from.AddDate(0, 0, 7) // fallback
}

func findNextMonthlyDate(from time.Time, day int, monthOffset int) time.Time {
	year, month, _ := from.Date()
	month += time.Month(monthOffset)

	// Try current month first, then next month
	for range 2 {
		candidate := time.Date(year, month, day, from.Hour(), from.Minute(), from.Second(), from.Nanosecond(), from.Location())
		if candidate.After(from) {
			return candidate
		}
		month++
		if month > 12 {
			month = 1
			year++
		}
	}

	return time.Date(year, month, day, from.Hour(), from.Minute(), from.Second(), from.Nanosecond(), from.Location())
}

func findNextYearlyDate(from time.Time, day int, month time.Month) time.Time {
	year := from.Year()
	candidate := time.Date(year, month, day, from.Hour(), from.Minute(), from.Second(), from.Nanosecond(), from.Location())

	if candidate.After(from) {
		return candidate
	}

	// Next year
	return time.Date(year+1, month, day, from.Hour(), from.Minute(), from.Second(), from.Nanosecond(), from.Location())
}
