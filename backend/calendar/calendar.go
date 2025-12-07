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
func SyncTask(task *database.Task) {
	if !isEnabled() {
		return
	}

	hasLabel := hasCalendarLabel(task)
	hasEventID := task.GoogleEventID != nil && *task.GoogleEventID != ""

	if hasLabel && !hasEventID {
		createEvent(task)
	} else if hasLabel && hasEventID {
		updateEvent(task)
	} else if !hasLabel && hasEventID {
		deleteEvent(*task.GoogleEventID)
		clearEventID(task.ID)
	}
}

// DeleteEvent removes a calendar event
func DeleteEvent(eventID string) {
	if !isEnabled() || eventID == "" {
		return
	}
	deleteEvent(eventID)
}

func createEvent(task *database.Task) {
	srv, err := getService()
	if err != nil {
		logger.Error("Failed to get calendar service").Err(err).Send()
		return
	}

	event := buildEvent(task)
	created, err := srv.Events.Insert("primary", event).Do()
	if err != nil {
		logger.Error("Failed to create calendar event").Err(err).Uint("task_id", task.ID).Send()
		return
	}

	// Store the event ID on the task
	database.DB.Model(&database.Task{}).Where("id = ?", task.ID).Update("google_event_id", created.Id)
	logger.Info("Created calendar event").Str("event_id", created.Id).Uint("task_id", task.ID).Send()
}

func updateEvent(task *database.Task) {
	srv, err := getService()
	if err != nil {
		logger.Error("Failed to get calendar service").Err(err).Send()
		return
	}

	event := buildEvent(task)
	_, err = srv.Events.Update("primary", *task.GoogleEventID, event).Do()
	if err != nil {
		logger.Error("Failed to update calendar event").Err(err).Str("event_id", *task.GoogleEventID).Send()
		return
	}

	logger.Info("Updated calendar event").Str("event_id", *task.GoogleEventID).Uint("task_id", task.ID).Send()
}

func deleteEvent(eventID string) {
	srv, err := getService()
	if err != nil {
		logger.Error("Failed to get calendar service").Err(err).Send()
		return
	}

	err = srv.Events.Delete("primary", eventID).Do()
	if err != nil {
		logger.Error("Failed to delete calendar event").Err(err).Str("event_id", eventID).Send()
		return
	}

	logger.Info("Deleted calendar event").Str("event_id", eventID).Send()
}

func clearEventID(taskID uint) {
	database.DB.Model(&database.Task{}).Where("id = ?", taskID).Update("google_event_id", nil)
}

func buildEvent(task *database.Task) *calendar.Event {
	event := &calendar.Event{
		Summary: task.Description,
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
