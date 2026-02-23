package database

import (
	"dimaist/utils"
	"time"
)

// CompleteTask marks a task as completed. For recurring tasks, it updates
// the due date to the next occurrence and clears completed_at.
// Returns the updates map to be applied and whether task is recurring.
func CompleteTask(task *Task) (map[string]any, bool, error) {
	now := time.Now()
	updates := map[string]any{
		"completed_at": &now,
	}

	isRecurring := task.Recurrence != ""

	if isRecurring {
		nextDue, err := utils.CalculateNextDueDate(task.Recurrence, task.DueTime())
		if err != nil {
			return nil, false, err
		}

		if nextDue != nil {
			if task.HasTime {
				updates["due"] = nextDue
			} else {
				dateOnly := time.Date(nextDue.Year(), nextDue.Month(), nextDue.Day(), 0, 0, 0, 0, nextDue.Location())
				updates["due"] = &dateOnly
			}
		}

		// For recurring tasks, clear completed_at to keep them active
		updates["completed_at"] = nil
	}

	return updates, isRecurring, nil
}
