package env

import (
	"fmt"
	"os"
)

type Env struct {
	LogLevel           string
	LogFormat          string
	DatabaseURL        string
	ChutesEndpoint     string
	ChutesToken        string
	OpenrouterEndpoint string
	OpenrouterToken    string
	GoogleAIEndpoint   string
	GoogleAIToken      string
	GroqEndpoint       string
	GroqToken          string
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

	chutesEndpoint := os.Getenv("CHUTES_ENDPOINT")
	if chutesEndpoint == "" {
		return nil, fmt.Errorf("CHUTES_ENDPOINT environment variable is required")
	}
	env.ChutesEndpoint = chutesEndpoint

	chutesToken := os.Getenv("CHUTES_TOKEN")
	if chutesToken == "" {
		return nil, fmt.Errorf("CHUTES_TOKEN environment variable is required")
	}
	env.ChutesToken = chutesToken

	openrouterEndpoint := os.Getenv("OPENROUTER_ENDPOINT")
	if openrouterEndpoint == "" {
		return nil, fmt.Errorf("OPENROUTER_ENDPOINT environment variable is required")
	}
	env.OpenrouterEndpoint = openrouterEndpoint

	openrouterToken := os.Getenv("OPENROUTER_TOKEN")
	if openrouterToken == "" {
		return nil, fmt.Errorf("OPENROUTER_TOKEN environment variable is required")
	}
	env.OpenrouterToken = openrouterToken

	googleAIToken := os.Getenv("GOOGLE_AI_TOKEN")
	if googleAIToken == "" {
		return nil, fmt.Errorf("GOOGLE_AI_TOKEN environment variable is required")
	}
	env.GoogleAIToken = googleAIToken
	env.GoogleAIEndpoint = getEnvOrDefault("GOOGLE_AI_ENDPOINT", "https://generativelanguage.googleapis.com/v1beta/openai")

	groqToken := os.Getenv("GROQ_TOKEN")
	if groqToken == "" {
		return nil, fmt.Errorf("GROQ_TOKEN environment variable is required")
	}
	env.GroqToken = groqToken
	env.GroqEndpoint = getEnvOrDefault("GROQ_ENDPOINT", "https://api.groq.com/openai/v1")

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
