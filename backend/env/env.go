package env

import (
	"fmt"
	"os"
)

type Env struct {
	ElevenLabsAPIKey string
	AsrUrl           string
	LogLevel         string
	LogFormat        string
	DatabaseURL      string
}

func New() (*Env, error) {
	env := &Env{}
	
	// Required environment variables
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL environment variable is required")
	}
	env.DatabaseURL = databaseURL
	
	elevenLabsAPIKey := os.Getenv("ELEVENLABS_API_KEY")
	if elevenLabsAPIKey == "" {
		return nil, fmt.Errorf("ELEVENLABS_API_KEY environment variable is required")
	}
	env.ElevenLabsAPIKey = elevenLabsAPIKey
	
	asrURL := os.Getenv("ASR_URL")
	if asrURL == "" {
		return nil, fmt.Errorf("ASR_URL environment variable is required")
	}
	env.AsrUrl = asrURL
	
	// Optional environment variables with defaults
	env.LogLevel = getEnvOrDefault("LOG_LEVEL", "info")
	env.LogFormat = getEnvOrDefault("LOG_FORMAT", "text")
	
	return env, nil
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}