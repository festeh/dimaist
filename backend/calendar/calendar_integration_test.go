package calendar

import (
	"os"
	"testing"
	"time"

	"dimaist/env"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/api/calendar/v3"
)

func setupTestEnv(t *testing.T) {
	// Check if credentials are available
	clientID := os.Getenv("GOOGLE_CLIENT_ID")
	clientSecret := os.Getenv("GOOGLE_CLIENT_SECRET")
	refreshToken := os.Getenv("GOOGLE_REFRESH_TOKEN")

	if clientID == "" || clientSecret == "" || refreshToken == "" {
		t.Skip("Skipping calendar integration test: Google credentials not configured")
	}

	appEnv = &env.Env{
		GoogleClientID:     clientID,
		GoogleClientSecret: clientSecret,
		GoogleRefreshToken: refreshToken,
	}
}

func TestCalendarIntegration_AuthWorks(t *testing.T) {
	setupTestEnv(t)

	// Test that we can get a calendar service (auth works)
	srv, err := getService()
	require.NoError(t, err, "Failed to create calendar service - auth may be broken")
	assert.NotNil(t, srv)
}

func TestCalendarIntegration_CreateUpdateDeleteEvent(t *testing.T) {
	setupTestEnv(t)

	srv, err := getService()
	require.NoError(t, err)

	// Create a test event
	testTime := time.Now().Add(24 * time.Hour) // Tomorrow
	event := &calendar.Event{
		Summary:     "Dimaist Integration Test Event",
		Description: "This event was created by an automated test and should be deleted automatically",
		Start: &calendar.EventDateTime{
			DateTime: testTime.Format(time.RFC3339),
		},
		End: &calendar.EventDateTime{
			DateTime: testTime.Add(time.Hour).Format(time.RFC3339),
		},
	}

	// CREATE
	created, err := srv.Events.Insert("primary", event).Do()
	require.NoError(t, err, "Failed to create calendar event")
	assert.NotEmpty(t, created.Id)
	assert.Equal(t, "Dimaist Integration Test Event", created.Summary)

	eventID := created.Id
	t.Logf("Created event with ID: %s", eventID)

	// Cleanup: ensure event is deleted even if test fails
	defer func() {
		_ = srv.Events.Delete("primary", eventID).Do()
	}()

	// UPDATE
	created.Summary = "Dimaist Integration Test Event (Updated)"
	updated, err := srv.Events.Update("primary", eventID, created).Do()
	require.NoError(t, err, "Failed to update calendar event")
	assert.Equal(t, "Dimaist Integration Test Event (Updated)", updated.Summary)

	// GET - verify update persisted
	fetched, err := srv.Events.Get("primary", eventID).Do()
	require.NoError(t, err, "Failed to fetch calendar event")
	assert.Equal(t, "Dimaist Integration Test Event (Updated)", fetched.Summary)

	// DELETE
	err = srv.Events.Delete("primary", eventID).Do()
	require.NoError(t, err, "Failed to delete calendar event")

	// Verify deletion - event should be cancelled (Google doesn't immediately 404)
	fetched, err = srv.Events.Get("primary", eventID).Do()
	if err == nil {
		// If we can still fetch it, it should be marked as cancelled
		assert.Equal(t, "cancelled", fetched.Status, "Deleted event should have cancelled status")
	}
	// If err != nil, that's also fine (404)
}

func TestCalendarIntegration_ListEvents(t *testing.T) {
	setupTestEnv(t)

	srv, err := getService()
	require.NoError(t, err)

	// Just verify we can list events (doesn't matter if empty)
	events, err := srv.Events.List("primary").
		TimeMin(time.Now().Format(time.RFC3339)).
		MaxResults(10).
		SingleEvents(true).
		Do()

	require.NoError(t, err, "Failed to list calendar events")
	assert.NotNil(t, events)
	t.Logf("Found %d upcoming events", len(events.Items))
}
