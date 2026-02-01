package env

import (
	"fmt"
	"os"
)

type Env struct {
	LogLevel           string
	LogFormat          string
	DatabaseURL        string
	KimiEndpoint       string
	KimiToken          string
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

	kimiToken := os.Getenv("KIMI_API_KEY")
	if kimiToken == "" {
		return nil, fmt.Errorf("KIMI_API_KEY environment variable is required")
	}
	env.KimiToken = kimiToken
	env.KimiEndpoint = getEnvOrDefault("KIMI_ENDPOINT", "https://api.kimi.com/coding/v1/chat/completions")

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
	env.GoogleAIEndpoint = getEnvOrDefault("GOOGLE_AI_ENDPOINT", "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")

	groqToken := os.Getenv("GROQ_TOKEN")
	if groqToken == "" {
		return nil, fmt.Errorf("GROQ_TOKEN environment variable is required")
	}
	env.GroqToken = groqToken
	env.GroqEndpoint = getEnvOrDefault("GROQ_ENDPOINT", "https://api.groq.com/openai/v1/chat/completions")

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
