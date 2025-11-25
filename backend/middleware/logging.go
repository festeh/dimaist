package middleware

import (
	"net/http"
	"time"

	"dimaist/logger"
	"github.com/go-chi/chi/v5/middleware"
)

// LoggingMiddleware provides structured request logging
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create a response wrapper to capture status code
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

		// Log the incoming request
		logger.Info("HTTP request started").
			Str("method", r.Method).
			Str("path", r.URL.Path).
			Str("remote_addr", r.RemoteAddr).
			Str("user_agent", r.UserAgent()).
			Send()

		// Process request
		next.ServeHTTP(ww, r)

		// Log the completed request
		duration := time.Since(start)
		logger.Info("HTTP request completed").
			Str("method", r.Method).
			Str("path", r.URL.Path).
			Int("status_code", ww.Status()).
			Int("bytes_written", ww.BytesWritten()).
			Dur("duration", duration).
			Send()
	})
}
