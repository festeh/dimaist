package main

import (
	"encoding/json"
	"net/http"

	"dimaist/database"
	"dimaist/logger"
	"dimaist/utils"
	"gorm.io/gorm"
)

func listProjects(w http.ResponseWriter, r *http.Request) {
	var projects []database.Project
	result := database.DB.Preload("Tasks", "deleted_at IS NULL").Where("deleted_at IS NULL").Find(&projects)
	if result.Error != nil {
		logger.Error("Failed to retrieve projects").Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	utils.RespondJSON(w, http.StatusOK, projects)
}

func createProject(w http.ResponseWriter, r *http.Request) {
	var p database.Project
	err := json.NewDecoder(r.Body).Decode(&p)
	if err != nil {
		logger.Error("Failed to decode project request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if p.Order == 0 {
		var maxOrder int
		database.DB.Model(&database.Project{}).Select("COALESCE(MAX(\"order\"), 0)").Where("deleted_at IS NULL").Scan(&maxOrder)
		p.Order = maxOrder + 1
	}

	result := database.DB.Create(&p)
	if result.Error != nil {
		logger.Error("Failed to create project").Err(result.Error).Str("name", p.Name).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	utils.RespondJSON(w, http.StatusOK, p)
}

func updateProject(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseProjectID(r, w)
	if !ok {
		return
	}

	var p database.Project
	err := json.NewDecoder(r.Body).Decode(&p)
	if err != nil {
		logger.Error("Failed to decode project update request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	result := database.DB.Model(&p).Where("id = ? AND deleted_at IS NULL", id).Updates(p)
	if result.Error != nil {
		logger.Error("Failed to update project").Uint("project_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func deleteProject(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseProjectID(r, w)
	if !ok {
		return
	}

	if _, err := database.SoftDelete(&database.Project{}, id); err != nil {
		logger.Error("Failed to delete project").Uint("project_id", id).Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func updateOrderBatch(model any, ids []uint, whereClause string, whereArgs ...any) error {
	for i, id := range ids {
		var result *gorm.DB
		if whereClause != "" {
			result = database.DB.Model(model).Where("id = ? AND deleted_at IS NULL AND "+whereClause, append([]any{id}, whereArgs...)...).Update("order", i+1)
		} else {
			result = database.DB.Model(model).Where("id = ? AND deleted_at IS NULL", id).Update("order", i+1)
		}
		if result.Error != nil {
			return result.Error
		}
	}
	return nil
}

func reorderProjects(w http.ResponseWriter, r *http.Request) {
	var projectIDs []uint
	err := json.NewDecoder(r.Body).Decode(&projectIDs)
	if err != nil {
		logger.Error("Failed to decode project IDs").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = updateOrderBatch(&database.Project{}, projectIDs, "", nil)
	if err != nil {
		logger.Error("Failed to reorder projects").Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func reorderTasks(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseProjectID(r, w)
	if !ok {
		return
	}

	var taskIDs []uint
	err := json.NewDecoder(r.Body).Decode(&taskIDs)
	if err != nil {
		logger.Error("Failed to decode task IDs").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = updateOrderBatch(&database.Task{}, taskIDs, "project_id = ?", id)
	if err != nil {
		logger.Error("Failed to reorder tasks").Uint("project_id", id).Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}
