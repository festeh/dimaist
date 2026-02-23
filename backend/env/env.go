package env

import (
	"fmt"
	"os"
)

type Env struct {
	LogLevel           string
	LogFormat          string
	DatabaseURL        string
	AIEndpoint         string
	AIToken            string
	GoogleClientID     string
	GoogleClientSecret string
	GoogleRefreshToken string
}

func New() (*Env, error) {
	env := &Env{}

	// Required environment variables
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL environment variable is required")
	}
	env.DatabaseURL = databaseURL

	aiToken := os.Getenv("AI_TOKEN")
	if aiToken == "" {
		return nil, fmt.Errorf("AI_TOKEN environment variable is required")
	}
	env.AIToken = aiToken
	env.AIEndpoint = getEnvOrDefault("AI_ENDPOINT", "https://ai.dimalip.in/v1/chat/completions")

	// Optional environment variables with defaults
	env.LogLevel = getEnvOrDefault("LOG_LEVEL", "info")
	env.LogFormat = getEnvOrDefault("LOG_FORMAT", "text")

	// Google Calendar credentials (optional)
	env.GoogleClientID = os.Getenv("GOOGLE_CLIENT_ID")
	env.GoogleClientSecret = os.Getenv("GOOGLE_CLIENT_SECRET")
	env.GoogleRefreshToken = os.Getenv("GOOGLE_REFRESH_TOKEN")

	return env, nil
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
