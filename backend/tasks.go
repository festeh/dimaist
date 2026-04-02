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

// CreateTaskRequest is the request body for creating a task.
type CreateTaskRequest struct {
	Title         string   `json:"title" validate:"required"`
	Description   *string  `json:"description,omitempty"`
	ProjectID     *uint    `json:"project_id,omitempty"`
	Due           *string  `json:"due,omitempty"`
	HasTime       bool     `json:"has_time,omitempty"`
	StartDatetime *string  `json:"start_datetime,omitempty"`
	EndDatetime   *string  `json:"end_datetime,omitempty"`
	Labels        []string `json:"labels,omitempty"`
	Reminders     []string `json:"reminders,omitempty"`
	Recurrence    string   `json:"recurrence,omitempty"`
	Order         int      `json:"order,omitempty"`
}

// UpdateTaskRequest is the request body for updating a task.
type UpdateTaskRequest struct {
	Title         *string  `json:"title,omitempty"`
	Description   *string  `json:"description,omitempty"`
	ProjectID     *uint    `json:"project_id,omitempty"`
	Due           *string  `json:"due,omitempty"`
	HasTime       *bool    `json:"has_time,omitempty"`
	StartDatetime *string  `json:"start_datetime,omitempty"`
	EndDatetime   *string  `json:"end_datetime,omitempty"`
	Labels        []string `json:"labels,omitempty"`
	Reminders     []string `json:"reminders,omitempty"`
	Recurrence    *string  `json:"recurrence,omitempty"`
	Order         *int     `json:"order,omitempty"`
}

// CreateTaskResponse is the response from creating a task.
type CreateTaskResponse struct {
	Task    database.Task `json:"task"`
	Warning string        `json:"warning,omitempty"`
}

// UpdateTaskResponse is the response from updating a task.
type UpdateTaskResponse struct {
	Warning string `json:"warning,omitempty"`
}

// @Summary List all tasks
// @ID list_tasks
// @Tags tasks
// @Produce json
// @Success 200 {array} database.Task
// @Failure 500 {string} string
// @Router /tasks [get]
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

// @Summary Get a task by ID
// @ID get_task
// @Tags tasks
// @Produce json
// @Param task_id path int true "Task ID"
// @Success 200 {object} database.Task
// @Failure 404 {string} string
// @Failure 500 {string} string
// @Router /tasks/{task_id} [get]
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

// @Summary Create a new task
// @ID create_task
// @Tags tasks
// @Accept json
// @Produce json
// @Param task body CreateTaskRequest true "Task to create"
// @Success 200 {object} CreateTaskResponse
// @Failure 400 {string} string
// @Router /tasks [post]
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

// @Summary Update a task
// @ID update_task
// @Tags tasks
// @Accept json
// @Produce json
// @Param task_id path int true "Task ID"
// @Param task body UpdateTaskRequest true "Task fields to update"
// @Success 200 {object} UpdateTaskResponse
// @Failure 400 {string} string
// @Failure 500 {string} string
// @Router /tasks/{task_id} [put]
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

// @Summary Delete a task
// @ID delete_task
// @Tags tasks
// @Param task_id path int true "Task ID"
// @Success 200
// @Failure 500 {string} string
// @Router /tasks/{task_id} [delete]
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

// @Summary Mark a task as complete
// @ID complete_task
// @Tags tasks
// @Param task_id path int true "Task ID"
// @Success 200
// @Failure 404 {string} string
// @Failure 500 {string} string
// @Router /tasks/{task_id}/complete [post]
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
