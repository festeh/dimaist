package main

import (
	"net/http"
	"time"

	"dimaist/database"
	"dimaist/logger"
	"dimaist/utils"
)

type SyncResponse struct {
	Projects          []database.Project `json:"projects"`
	Tasks             []database.Task    `json:"tasks"`
	DeletedProjectIds []uint             `json:"deleted_project_ids"`
	DeletedTaskIds    []uint             `json:"deleted_task_ids"`
	SyncToken         string             `json:"sync_token"`
}

func syncData(w http.ResponseWriter, r *http.Request) {
	syncToken := r.URL.Query().Get("sync_token")

	var projects []database.Project
	var tasks []database.Task
	var deletedProjectIds []uint
	var deletedTaskIds []uint

	var syncTime time.Time
	if syncToken != "" {
		var err error
		syncTime, err = time.Parse(time.RFC3339, syncToken)
		if err != nil {
			logger.Error("Invalid sync token format").Str("sync_token", syncToken).Err(err).Send()
			http.Error(w, "Invalid sync token format", http.StatusBadRequest)
			return
		}
	}

	projectQuery := database.DB.Preload("Tasks", "deleted_at IS NULL").Where("deleted_at IS NULL")
	if syncToken != "" {
		projectQuery = projectQuery.Where("updated_at > ?", syncTime)
	}

	result := projectQuery.Find(&projects)
	if result.Error != nil {
		logger.Error("Failed to retrieve projects").Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	taskQuery := database.DB.Preload("Project").Where("deleted_at IS NULL")
	if syncToken != "" {
		taskQuery = taskQuery.Where("updated_at > ?", syncTime)
	}

	result = taskQuery.Find(&tasks)
	if result.Error != nil {
		logger.Error("Failed to retrieve tasks").Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if syncToken != "" {
		var deletedProjects []database.Project
		result = database.DB.Select("id").Where("deleted_at > ?", syncTime).Find(&deletedProjects)
		if result.Error != nil {
			logger.Error("Failed to retrieve deleted projects").Err(result.Error).Send()
			http.Error(w, result.Error.Error(), http.StatusInternalServerError)
			return
		}
		for _, p := range deletedProjects {
			deletedProjectIds = append(deletedProjectIds, p.ID)
		}

		var deletedTasks []database.Task
		result = database.DB.Select("id").Where("deleted_at > ?", syncTime).Find(&deletedTasks)
		if result.Error != nil {
			logger.Error("Failed to retrieve deleted tasks").Err(result.Error).Send()
			http.Error(w, result.Error.Error(), http.StatusInternalServerError)
			return
		}
		for _, t := range deletedTasks {
			deletedTaskIds = append(deletedTaskIds, t.ID)
		}
	}

	newSyncToken := time.Now().Format(time.RFC3339)

	response := SyncResponse{
		Projects:          projects,
		Tasks:             tasks,
		DeletedProjectIds: deletedProjectIds,
		DeletedTaskIds:    deletedTaskIds,
		SyncToken:         newSyncToken,
	}

	utils.RespondJSON(w, http.StatusOK, response)
}
