package logger

import (
	"io"
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// Logger is the global logger instance
var Logger zerolog.Logger

func init() {
	// Default: disabled logger (for CLI usage where logs interfere with JSON output)
	Logger = zerolog.New(io.Discard)
	log.Logger = Logger
}

// InitLogger initializes the global logger with configuration
func InitLogger(logLevel, logFormat string, verbose bool) {
	// Set timestamp precision to include milliseconds
	zerolog.TimeFieldFormat = time.RFC3339Nano

	// If verbose flag is set, override log level to debug
	if verbose {
		logLevel = "debug"
	}

	// Set log level from parameter, default to info
	logLevel = strings.ToLower(logLevel)
	var level zerolog.Level

	switch logLevel {
	case "debug":
		level = zerolog.DebugLevel
	case "info":
		level = zerolog.InfoLevel
	case "warn":
		level = zerolog.WarnLevel
	case "error":
		level = zerolog.ErrorLevel
	default:
		level = zerolog.InfoLevel
	}

	// Configure output format
	if logFormat == "json" {
		// JSON format for production
		Logger = zerolog.New(os.Stdout).
			Level(level).
			With().
			Timestamp().
			Caller().
			Logger()
	} else {
		// Pretty format for development
		Logger = zerolog.New(zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: "01-02 15:04:05.000",
		}).
			Level(level).
			With().
			Timestamp().
			Caller().
			Logger()
	}

	// Set global logger
	log.Logger = Logger
}

// Info logs an info message
func Info(message string) *zerolog.Event {
	return Logger.Info().Str("message", message)
}

// Error logs an error message
func Error(message string) *zerolog.Event {
	return Logger.Error().Str("message", message)
}

// Debug logs a debug message
func Debug(message string) *zerolog.Event {
	return Logger.Debug().Str("message", message)
}

// Warn logs a warning message
func Warn(message string) *zerolog.Event {
	return Logger.Warn().Str("message", message)
}

// InitCLILogger initializes logger for CLI usage (outputs to stderr to not interfere with JSON)
func InitCLILogger(logLevel string) {
	zerolog.TimeFieldFormat = time.RFC3339Nano

	logLevel = strings.ToLower(logLevel)
	var level zerolog.Level

	switch logLevel {
	case "debug":
		level = zerolog.DebugLevel
	case "info":
		level = zerolog.InfoLevel
	case "warn":
		level = zerolog.WarnLevel
	case "error":
		level = zerolog.ErrorLevel
	default:
		level = zerolog.InfoLevel
	}

	// CLI uses stderr with pretty format
	Logger = zerolog.New(zerolog.ConsoleWriter{
		Out:        os.Stderr,
		TimeFormat: "15:04:05",
	}).
		Level(level).
		With().
		Timestamp().
		Caller().
		Logger()

	log.Logger = Logger
}
