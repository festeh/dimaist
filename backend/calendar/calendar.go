package calendar

import (
	"context"
	"time"

	"dimaist/database"
	"dimaist/env"
	"dimaist/logger"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/calendar/v3"
	"google.golang.org/api/option"
)

var appEnv *env.Env

func SetEnv(e *env.Env) {
	appEnv = e
}

func isEnabled() bool {
	return appEnv != nil &&
		appEnv.GoogleClientID != "" &&
		appEnv.GoogleClientSecret != "" &&
		appEnv.GoogleRefreshToken != ""
}

func getService() (*calendar.Service, error) {
	config := &oauth2.Config{
		ClientID:     appEnv.GoogleClientID,
		ClientSecret: appEnv.GoogleClientSecret,
		Endpoint:     google.Endpoint,
	}

	token := &oauth2.Token{
		RefreshToken: appEnv.GoogleRefreshToken,
	}

	client := config.Client(context.Background(), token)
	return calendar.NewService(context.Background(), option.WithHTTPClient(client))
}

func hasCalendarLabel(task *database.Task) bool {
	for _, label := range task.Labels {
		if label == "calendar" {
			return true
		}
	}
	return false
}

// SyncTask syncs a task to Google Calendar based on "calendar" label
func SyncTask(task *database.Task) error {
	if !isEnabled() {
		return nil
	}

	hasLabel := hasCalendarLabel(task)
	hasEventID := task.GoogleEventID != nil && *task.GoogleEventID != ""

	if hasLabel && !hasEventID {
		return createEvent(task)
	} else if hasLabel && hasEventID {
		return updateEvent(task)
	} else if !hasLabel && hasEventID {
		if err := deleteEvent(*task.GoogleEventID); err != nil {
			return err
		}
		clearEventID(task.ID)
	}
	return nil
}

// DeleteEvent removes a calendar event
func DeleteEvent(eventID string) error {
	if !isEnabled() || eventID == "" {
		return nil
	}
	return deleteEvent(eventID)
}

// findExistingEvent searches for an existing event with the same summary and time
func findExistingEvent(srv *calendar.Service, summary string, start, end *calendar.EventDateTime) (*calendar.Event, error) {
	var timeMin, timeMax string
	if start.DateTime != "" {
		timeMin = start.DateTime
		timeMax = end.DateTime
	} else {
		// All-day event: search within the day
		timeMin = start.Date + "T00:00:00Z"
		timeMax = start.Date + "T23:59:59Z"
	}

	events, err := srv.Events.List("primary").
		TimeMin(timeMin).
		TimeMax(timeMax).
		Q(summary).
		SingleEvents(true).
		Do()
	if err != nil {
		return nil, err
	}

	// Find exact match on summary
	for _, e := range events.Items {
		if e.Summary == summary {
			return e, nil
		}
	}
	return nil, nil
}

func createEvent(task *database.Task) error {
	srv, err := getService()
	if err != nil {
		logger.Error("Failed to get calendar service").Err(err).Send()
		return err
	}

	event := buildEvent(task)

	// Check for existing event with same name and time
	existing, err := findExistingEvent(srv, event.Summary, event.Start, event.End)
	if err != nil {
		logger.Warn("Failed to check for existing event, continuing with creation").Err(err).Send()
		// Continue with creation - better to have a duplicate than fail
	}

	if existing != nil {
		// Link to existing event instead of creating duplicate
		database.DB.Model(&database.Task{}).Where("id = ?", task.ID).Update("google_event_id", existing.Id)
		logger.Info("Linked to existing calendar event").Str("event_id", existing.Id).Uint("task_id", task.ID).Send()
		return nil
	}

	// Create new event
	created, err := srv.Events.Insert("primary", event).Do()
	if err != nil {
		logger.Error("Failed to create calendar event").Err(err).Uint("task_id", task.ID).Send()
		return err
	}

	database.DB.Model(&database.Task{}).Where("id = ?", task.ID).Update("google_event_id", created.Id)
	logger.Info("Created calendar event").Str("event_id", created.Id).Uint("task_id", task.ID).Send()
	return nil
}

func updateEvent(task *database.Task) error {
	srv, err := getService()
	if err != nil {
		logger.Error("Failed to get calendar service").Err(err).Send()
		return err
	}

	event := buildEvent(task)
	_, err = srv.Events.Update("primary", *task.GoogleEventID, event).Do()
	if err != nil {
		logger.Error("Failed to update calendar event").Err(err).Str("event_id", *task.GoogleEventID).Send()
		return err
	}

	logger.Info("Updated calendar event").Str("event_id", *task.GoogleEventID).Uint("task_id", task.ID).Send()
	return nil
}

func deleteEvent(eventID string) error {
	srv, err := getService()
	if err != nil {
		logger.Error("Failed to get calendar service").Err(err).Send()
		return err
	}

	err = srv.Events.Delete("primary", eventID).Do()
	if err != nil {
		logger.Error("Failed to delete calendar event").Err(err).Str("event_id", eventID).Send()
		return err
	}

	logger.Info("Deleted calendar event").Str("event_id", eventID).Send()
	return nil
}

func clearEventID(taskID uint) {
	database.DB.Model(&database.Task{}).Where("id = ?", taskID).Update("google_event_id", nil)
}

func buildEvent(task *database.Task) *calendar.Event {
	event := &calendar.Event{
		Summary: task.Title,
	}

	// Add description if present
	if task.Description != nil && *task.Description != "" {
		event.Description = *task.Description
	}

	// Determine start/end times
	if task.StartDatetime != nil && task.EndDatetime != nil {
		// Use explicit start/end if provided
		event.Start = &calendar.EventDateTime{
			DateTime: task.StartDatetime.Format(time.RFC3339),
		}
		event.End = &calendar.EventDateTime{
			DateTime: task.EndDatetime.Format(time.RFC3339),
		}
	} else if task.Due() != nil {
		due := task.Due()
		if task.HasTime() {
			// Timed event: due datetime with 1 hour duration
			event.Start = &calendar.EventDateTime{
				DateTime: due.Format(time.RFC3339),
			}
			event.End = &calendar.EventDateTime{
				DateTime: due.Add(time.Hour).Format(time.RFC3339),
			}
		} else {
			// All-day event
			event.Start = &calendar.EventDateTime{
				Date: due.Format("2006-01-02"),
			}
			event.End = &calendar.EventDateTime{
				Date: due.Format("2006-01-02"),
			}
		}
	} else {
		// No date - use today as all-day event
		today := time.Now().Format("2006-01-02")
		event.Start = &calendar.EventDateTime{
			Date: today,
		}
		event.End = &calendar.EventDateTime{
			Date: today,
		}
	}

	return event
}
