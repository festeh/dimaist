package utils

import (
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
)

// normalizeNumberWords converts written numbers to digits in recurrence patterns
func normalizeNumberWords(text string) string {
	wordToNum := map[string]string{
		"one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
		"six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
		"eleven": "11", "twelve": "12",
		"other": "2", "few": "3", "several": "4", "couple": "2",
	}

	normalized := strings.ToLower(text)
	for word, num := range wordToNum {
		normalized = strings.ReplaceAll(normalized, word, num)
	}
	return normalized
}

// parseEveryNPattern parses patterns like "every N days/weeks/months/years"
func parseEveryNPattern(recurrence string) (int, string, error) {
	// Match patterns like "every 2 weeks", "every three days", "every other month"
	re := regexp.MustCompile(`^every\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)s?$`)
	matches := re.FindStringSubmatch(strings.ToLower(recurrence))
	
	if len(matches) != 3 {
		return 0, "", fmt.Errorf("invalid every N pattern: %s", recurrence)
	}

	count, err := strconv.Atoi(matches[1])
	if err != nil {
		return 0, "", fmt.Errorf("invalid number in pattern: %s", matches[1])
	}

	unit := matches[2]
	// Normalize plural forms to singular
	if strings.HasSuffix(unit, "s") {
		unit = unit[:len(unit)-1]
	}

	// Validate reasonable ranges
	switch unit {
	case "day":
		if count < 1 || count > 365 {
			return 0, "", fmt.Errorf("day interval must be between 1 and 365, got %d", count)
		}
	case "week":
		if count < 1 || count > 52 {
			return 0, "", fmt.Errorf("week interval must be between 1 and 52, got %d", count)
		}
	case "month":
		if count < 1 || count > 12 {
			return 0, "", fmt.Errorf("month interval must be between 1 and 12, got %d", count)
		}
	case "year":
		if count < 1 || count > 10 {
			return 0, "", fmt.Errorf("year interval must be between 1 and 10, got %d", count)
		}
	default:
		return 0, "", fmt.Errorf("unsupported time unit: %s", unit)
	}

	return count, unit, nil
}

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
			return fmt.Errorf("recurring tasks must have a due date. Please set either a due date or due datetime to schedule the recurrence")
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

	// Normalize word numbers first
	normalizedRecurrence := normalizeNumberWords(recurrence)

	// Check for "every N [unit]" patterns first
	if strings.HasPrefix(strings.ToLower(normalizedRecurrence), "every ") {
		count, unit, err := parseEveryNPattern(normalizedRecurrence)
		if err == nil {
			var next time.Time
			switch unit {
			case "day":
				next = baseDate.AddDate(0, 0, count)
			case "week":
				next = baseDate.AddDate(0, 0, count*7)
			case "month":
				next = baseDate.AddDate(0, count, 0)
			case "year":
				next = baseDate.AddDate(count, 0, 0)
			}
			return &next, nil
		}
		// If parsing failed, continue to other patterns
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

	// Monthly (same date next month)
	monthlyPatterns := []string{"month", "monthly", "every month"}
	if slices.Contains(monthlyPatterns, strings.ToLower(recurrence)) {
		next := baseDate.AddDate(0, 1, 0)
		return &next, nil
	}

	// Yearly (same date next year)
	yearlyPatterns := []string{"year", "yearly", "annually", "every year"}
	if slices.Contains(yearlyPatterns, strings.ToLower(recurrence)) {
		next := baseDate.AddDate(1, 0, 0)
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

	return nil, fmt.Errorf("unsupported recurrence pattern: '%s'. Valid patterns include: 'daily', 'weekly', 'monthly', 'yearly', intervals like 'every 2 weeks' or 'every three days', weekdays like 'mon' or 'mon,wed,fri', monthly dates like '15', or yearly dates like '25 dec'", recurrence)
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
		// Handle cases where the day doesn't exist in the target month
		// e.g., asking for the 31st in February - fall back to last day of month
		targetMonth := month
		targetYear := year
		
		// Get the last day of the target month to validate
		lastDayOfMonth := time.Date(targetYear, targetMonth+1, 0, 0, 0, 0, 0, from.Location()).Day()
		actualDay := day
		if day > lastDayOfMonth {
			actualDay = lastDayOfMonth
		}
		
		candidate := time.Date(targetYear, targetMonth, actualDay, from.Hour(), from.Minute(), from.Second(), from.Nanosecond(), from.Location())
		if candidate.After(from) {
			return candidate
		}
		
		month++
		if month > 12 {
			month = 1
			year++
		}
	}

	// Fallback for final attempt
	lastDayOfMonth := time.Date(year, month+1, 0, 0, 0, 0, 0, from.Location()).Day()
	actualDay := day
	if day > lastDayOfMonth {
		actualDay = lastDayOfMonth
	}
	return time.Date(year, month, actualDay, from.Hour(), from.Minute(), from.Second(), from.Nanosecond(), from.Location())
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
