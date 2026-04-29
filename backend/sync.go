package main

import (
	"net/http"
	"strconv"

	"dimaist/database"
	"dimaist/logger"
	"dimaist/sync"
	"dimaist/utils"
)

// SyncResponse mirrors sync.Page with the token serialized as a string,
// since JSON numbers lose precision for large int64 values in some clients.
type SyncResponse struct {
	Projects  []database.Project `json:"projects"`
	Tasks     []database.Task    `json:"tasks"`
	SyncToken string             `json:"sync_token"`
	HasMore   bool               `json:"has_more"`
}

// @Summary Sync data with incremental updates
// @ID sync_data
// @Tags sync
// @Produce json
// @Param sync_token query string false "Opaque revision cursor; empty or 0 means full sync"
// @Param limit query int false "Max rows per table (default 1000)"
// @Success 200 {object} SyncResponse
// @Failure 400 {string} string
// @Failure 500 {string} string
// @Router /sync [get]
func syncData(w http.ResponseWriter, r *http.Request) {
	tokenStr := r.URL.Query().Get("sync_token")
	var token int64
	if tokenStr != "" {
		t, err := strconv.ParseInt(tokenStr, 10, 64)
		if err != nil || t < 0 {
			logger.Error("Invalid sync token").Str("sync_token", tokenStr).Send()
			http.Error(w, "Invalid sync_token: must be a non-negative integer", http.StatusBadRequest)
			return
		}
		token = t
	}

	limit := 0
	if s := r.URL.Query().Get("limit"); s != "" {
		n, err := strconv.Atoi(s)
		if err != nil || n <= 0 {
			http.Error(w, "Invalid limit: must be a positive integer", http.StatusBadRequest)
			return
		}
		limit = n
	}

	page, err := sync.Read(r.Context(), token, limit)
	if err != nil {
		logger.Error("Sync failed").Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	utils.RespondJSON(w, http.StatusOK, SyncResponse{
		Projects:  page.Projects,
		Tasks:     page.Tasks,
		SyncToken: strconv.FormatInt(page.SyncToken, 10),
		HasMore:   page.HasMore,
	})
}
