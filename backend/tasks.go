package main

import (
	"encoding/json"
	"fmt"
	"net/http"

	"dimaist/calendar"
	"dimaist/database"
	"dimaist/logger"
	"dimaist/utils"
	"gorm.io/gorm"
)

func listTasks(w http.ResponseWriter, r *http.Request) {
	var tasks []database.Task
	result := database.DB.Preload("Project").Where("deleted_at IS NULL").Find(&tasks)
	if result.Error != nil {
		logger.Error("Failed to retrieve tasks").Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	utils.RespondJSON(w, http.StatusOK, tasks)
}

func getTask(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	var task database.Task
	result := database.DB.Preload("Project").Where("id = ? AND deleted_at IS NULL", id).First(&task)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			http.Error(w, "Task not found", http.StatusNotFound)
			return
		}
		logger.Error("Failed to retrieve task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	utils.RespondJSON(w, http.StatusOK, task)
}

func createTask(w http.ResponseWriter, r *http.Request) {
	var t database.Task
	err := json.NewDecoder(r.Body).Decode(&t)
	if err != nil {
		logger.Error("Failed to decode task request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := utils.ValidateTaskRecurrence(t.Recurrence, t.DueTime()); err != nil {
		utils.RespondValidationError(w, "recurrence", err.Error())
		return
	}

	if err := database.CreateTask(&t); err != nil {
		logger.Error("Failed to create task").Err(err).Str("title", t.Title).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var calendarWarning string
	if err := calendar.SyncTask(&t); err != nil {
		calendarWarning = err.Error()
	}

	response := map[string]any{"task": t}
	if calendarWarning != "" {
		response["warning"] = calendarWarning
	}
	utils.RespondJSON(w, http.StatusOK, response)
}

func updateTask(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	var t database.Task
	err := json.NewDecoder(r.Body).Decode(&t)
	if err != nil {
		logger.Error("Failed to decode task update request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := database.ValidateLabels(t.Labels); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := utils.ValidateTaskRecurrence(t.Recurrence, t.DueTime()); err != nil {
		utils.RespondValidationError(w, "recurrence", err.Error())
		return
	}

	t.ID = id
	result := database.DB.Model(&t).Where("id = ? AND deleted_at IS NULL", id).Select("*").Omit("id", "google_event_id").Updates(t)
	if result.Error != nil {
		logger.Error("Failed to update task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	var calendarWarning string
	var updated database.Task
	if err := database.DB.Where("id = ? AND deleted_at IS NULL", id).First(&updated).Error; err == nil {
		if err := calendar.SyncTask(&updated); err != nil {
			calendarWarning = err.Error()
		}
	}

	if calendarWarning != "" {
		utils.RespondJSON(w, http.StatusOK, map[string]string{"warning": calendarWarning})
	} else {
		w.WriteHeader(http.StatusOK)
	}
}

func deleteTask(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	var task database.Task
	database.DB.Select("google_event_id").First(&task, id)

	if _, err := database.SoftDelete(&database.Task{}, id); err != nil {
		logger.Error("Failed to delete task").Uint("task_id", id).Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if task.GoogleEventID != nil && *task.GoogleEventID != "" {
		go calendar.DeleteEvent(*task.GoogleEventID)
	}

	w.WriteHeader(http.StatusOK)
}

func completeTask(w http.ResponseWriter, r *http.Request) {
	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	var task database.Task
	result := database.DB.Where("id = ? AND deleted_at IS NULL", id).First(&task)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			http.Error(w, "Task not found", http.StatusNotFound)
			return
		}
		logger.Error("Failed to fetch task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	updates, _, err := database.CompleteTask(&task)
	if err != nil {
		logger.Error("Failed to calculate next due date").Str("recurrence", task.Recurrence).Err(err).Send()
		http.Error(w, fmt.Sprintf("Failed to calculate next due date: %s", err.Error()), http.StatusInternalServerError)
		return
	}

	result = database.DB.Model(&task).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		logger.Error("Failed to complete task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}
