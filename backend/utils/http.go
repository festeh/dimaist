package utils

import (
	"encoding/json"
	"net/http"
	"strconv"

	"dimaist/logger"
	"github.com/go-chi/chi/v5"
)

// RespondJSON writes a JSON response with the given status code
func RespondJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		json.NewEncoder(w).Encode(data)
	}
}

// RespondError writes an error response with plain text
func RespondError(w http.ResponseWriter, status int, message string) {
	http.Error(w, message, status)
}

// RespondValidationError writes a JSON validation error response
func RespondValidationError(w http.ResponseWriter, field, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	json.NewEncoder(w).Encode(map[string]any{
		"error":   "Validation error",
		"message": message,
		"field":   field,
	})
}

// ParseIDFromURL extracts and validates an ID parameter from the URL
func ParseIDFromURL(r *http.Request, w http.ResponseWriter, paramName string) (uint, bool) {
	idStr := chi.URLParam(r, paramName)
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		logger.Error("Invalid "+paramName).Str(paramName, idStr).Err(err).Send()
		http.Error(w, "Invalid "+paramName, http.StatusBadRequest)
		return 0, false
	}
	return uint(id), true
}

// ParseTaskID is a convenience function for parsing task IDs
func ParseTaskID(r *http.Request, w http.ResponseWriter) (uint, bool) {
	return ParseIDFromURL(r, w, "taskID")
}

// ParseProjectID is a convenience function for parsing project IDs
func ParseProjectID(r *http.Request, w http.ResponseWriter) (uint, bool) {
	return ParseIDFromURL(r, w, "projectID")
}
