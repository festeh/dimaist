package main

import (
	"encoding/json"
	"net/http"

	"github.com/dima-b/go-task-backend/database"
	"github.com/dima-b/go-task-backend/logger"
)

type SearchResult struct {
	Type     string `json:"type"`
	ID       uint   `json:"id"`
	Title    string `json:"title"`
	Subtitle string `json:"subtitle,omitempty"`
	Content  string `json:"content,omitempty"`
}

type FindResponse struct {
	Results []SearchResult `json:"results"`
	Count   int            `json:"count"`
}

func findItems(w http.ResponseWriter, r *http.Request) {
	logger.Info("Searching items").Send()

	query := r.URL.Query().Get("q")
	if query == "" {
		logger.Error("Search query is required").Send()
		http.Error(w, "Query parameter 'q' is required", http.StatusBadRequest)
		return
	}

	var results []SearchResult

	// Search tasks
	var tasks []database.Task
	taskResult := database.DB.Preload("Project").
		Where("LOWER(description) LIKE LOWER(?) OR LOWER(notes) LIKE LOWER(?) OR array_to_string(labels, ',') ILIKE ?",
			"%"+query+"%", "%"+query+"%", "%"+query+"%").
		Find(&tasks)

	if taskResult.Error != nil {
		logger.Error("Failed to search tasks").Err(taskResult.Error).Send()
		http.Error(w, taskResult.Error.Error(), http.StatusInternalServerError)
		return
	}

	for _, task := range tasks {
		subtitle := ""
		if task.Project != nil {
			subtitle = task.Project.Name
		}
		results = append(results, SearchResult{
			Type:     "task",
			ID:       task.ID,
			Title:    task.Description,
			Subtitle: subtitle,
		})
	}

	// Search projects
	var projects []database.Project
	projectResult := database.DB.Where("LOWER(name) LIKE LOWER(?)", "%"+query+"%").Find(&projects)

	if projectResult.Error != nil {
		logger.Error("Failed to search projects").Err(projectResult.Error).Send()
		http.Error(w, projectResult.Error.Error(), http.StatusInternalServerError)
		return
	}

	for _, project := range projects {
		results = append(results, SearchResult{
			Type:  "project",
			ID:    project.ID,
			Title: project.Name,
		})
	}

	response := FindResponse{
		Results: results,
		Count:   len(results),
	}

	logger.Info("Successfully found items").
		Str("query", query).
		Int("count", len(results)).
		Send()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
