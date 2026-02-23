package ai

import (
	"io"
	"net/http"
	"strings"

	"dimaist/logger"
)

// HandleModels proxies GET /ai/models to the AI provider's /v1/models endpoint
func HandleModels(w http.ResponseWriter, r *http.Request) {
	// Derive models URL from chat completions endpoint
	// e.g. "https://ai.dimalip.in/v1/chat/completions" -> "https://ai.dimalip.in/v1/models"
	modelsURL := strings.TrimSuffix(appEnv.AIEndpoint, "/chat/completions") + "/models"

	req, err := http.NewRequestWithContext(r.Context(), "GET", modelsURL, nil)
	if err != nil {
		logger.Error("Failed to create models request").Err(err).Send()
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", "Bearer "+appEnv.AIToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		logger.Error("Failed to fetch models").Err(err).Send()
		http.Error(w, "Failed to fetch models", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}
