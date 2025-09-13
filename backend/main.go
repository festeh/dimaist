package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"time"

	"github.com/dima-b/go-task-backend/ai"
	"github.com/dima-b/go-task-backend/database"
	"github.com/dima-b/go-task-backend/env"
	"github.com/dima-b/go-task-backend/logger"
	"github.com/dima-b/go-task-backend/middleware"
	"github.com/dima-b/go-task-backend/utils"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/joho/godotenv"
	"gorm.io/gorm"
)

var appEnv *env.Env

func main() {
	// Parse command line flags
	port := flag.String("port", "3000", "Port to run the server on")
	verbose := flag.Bool("verbose", false, "Enable verbose logging (shows AI request bodies)")
	flag.Parse()

	err := godotenv.Load()
	if err != nil {
		// We can't log this yet since logger isn't initialized
		fmt.Printf("Warning: Error loading .env file, using environment variables: %v\n", err)
	}

	// Initialize environment configuration
	appEnv, err = env.New()
	if err != nil {
		fmt.Printf("Error: Failed to initialize environment: %v\n", err)
		return
	}

	// Set environment for ai package
	ai.SetEnv(appEnv)

	// Initialize logger with env config
	logger.InitLogger(appEnv.LogLevel, appEnv.LogFormat, *verbose)

	// Log if verbose mode is enabled
	if *verbose {
		logger.Debug("Verbose mode enabled - debug logs will be shown").Send()
	}

	err = database.InitDB(appEnv.DatabaseURL)
	if err != nil {
		logger.Error("Unable to connect to database").Err(err).Send()
		return
	}

	logger.Info("Database initialized successfully").Send()

	r := chi.NewRouter()
	r.Use(middleware.LoggingMiddleware)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("welcome"))
	})

	// Task routes
	r.Route("/tasks", func(r chi.Router) {
		r.Get("/", listTasks)
		r.Post("/", createTask)
		r.Route("/{taskID}", func(r chi.Router) {
			r.Get("/", getTask)
			r.Put("/", updateTask)
			r.Delete("/", deleteTask)
			r.Post("/complete", completeTask)
		})
	})

	// Project routes
	r.Route("/projects", func(r chi.Router) {
		r.Get("/", listProjects)
		r.Post("/", createProject)
		r.Route("/{projectID}", func(r chi.Router) {
			r.Put("/tasks/reorder", reorderTasks)
			r.Put("/", updateProject)
			r.Delete("/", deleteProject)
		})
	})

	// Reordering routes (separate to avoid conflicts)
	r.Put("/projects-reorder", reorderProjects)

	// AI routes
	r.Route("/ai", func(r chi.Router) {
		r.Post("/audio", transcribeAudio)
		r.Post("/text", ai.HandleAIText)
	})

	// Sync route
	r.Get("/sync", syncData)

	// Search route
	r.Get("/find", findItems)

	logger.Info("Starting server").Str("port", *port).Send()
	err = http.ListenAndServe(":"+*port, r)
	if err != nil {
		logger.Error("Server failed to start").Err(err).Send()
	}
}

func listTasks(w http.ResponseWriter, r *http.Request) {
	logger.Info("Listing tasks").Send()

	var tasks []database.Task
	result := database.DB.Preload("Project").Where("deleted_at IS NULL").Find(&tasks)
	if result.Error != nil {
		logger.Error("Failed to retrieve tasks").Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully retrieved tasks").Int64("count", result.RowsAffected).Send()
	json.NewEncoder(w).Encode(tasks)
}

func getTask(w http.ResponseWriter, r *http.Request) {
	logger.Info("Getting task").Send()

	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	var task database.Task
	result := database.DB.Preload("Project").Where("id = ? AND deleted_at IS NULL", id).First(&task)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			logger.Error("Task not found").Uint("task_id", id).Send()
			http.Error(w, "Task not found", http.StatusNotFound)
			return
		}
		logger.Error("Failed to retrieve task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully retrieved task").Uint("task_id", id).Send()
	json.NewEncoder(w).Encode(task)
}

func createTask(w http.ResponseWriter, r *http.Request) {
	logger.Info("Creating new task").Send()

	var t database.Task
	err := json.NewDecoder(r.Body).Decode(&t)
	if err != nil {
		logger.Error("Failed to decode task request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Validate recurrence pattern
	if err := utils.ValidateTaskRecurrence(t.Recurrence, t.DueDate, t.DueDatetime); err != nil {
		logger.Error("Invalid task recurrence").Str("recurrence", t.Recurrence).Err(err).Send()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]any{
			"error": "Invalid recurrence pattern",
			"message": err.Error(),
			"field": "recurrence",
		})
		return
	}

	// Set order if not provided
	if t.Order == 0 {
		var maxOrder int
		database.DB.Model(&database.Task{}).Select("COALESCE(MAX(\"order\"), 0)").Where("project_id = ? AND deleted_at IS NULL", t.ProjectID).Scan(&maxOrder)
		t.Order = maxOrder + 1
	}

	result := database.DB.Create(&t)
	if result.Error != nil {
		logger.Error("Failed to create task").Err(result.Error).Str("description", t.Description).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully created task").Uint("task_id", t.ID).Str("description", t.Description).Send()
	json.NewEncoder(w).Encode(t)
}

func updateTask(w http.ResponseWriter, r *http.Request) {

	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	var t database.Task
	err := json.NewDecoder(r.Body).Decode(&t)
	logger.Info("Updating task").Uint("task_id", id).Interface("task", t).Send()
	if err != nil {
		logger.Error("Failed to decode task update request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Validate recurrence pattern
	if err := utils.ValidateTaskRecurrence(t.Recurrence, t.DueDate, t.DueDatetime); err != nil {
		logger.Error("Invalid task recurrence").Str("recurrence", t.Recurrence).Err(err).Send()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]any{
			"error": "Invalid recurrence pattern",
			"message": err.Error(),
			"field": "recurrence",
		})
		return
	}

	result := database.DB.Model(&t).Where("id = ? AND deleted_at IS NULL", id).Select("*").Updates(t)
	if result.Error != nil {
		logger.Error("Failed to update task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully updated task").Uint("task_id", id).Send()
	w.WriteHeader(http.StatusOK)
}

func deleteTask(w http.ResponseWriter, r *http.Request) {
	logger.Info("Deleting task").Send()

	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	result := database.DB.Model(&database.Task{}).Where("id = ?", id).Updates(map[string]any{
		"deleted_at": time.Now(),
		"updated_at": time.Now(),
	})
	if result.Error != nil {
		logger.Error("Failed to delete task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully deleted task").Uint("task_id", id).Send()
	w.WriteHeader(http.StatusOK)
}

func completeTask(w http.ResponseWriter, r *http.Request) {
	logger.Info("Completing task").Send()

	id, ok := utils.ParseTaskID(r, w)
	if !ok {
		return
	}

	// First, fetch the task to check if it's recurring
	var task database.Task
	result := database.DB.Where("id = ? AND deleted_at IS NULL", id).First(&task)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			logger.Error("Task not found").Uint("task_id", id).Send()
			http.Error(w, "Task not found", http.StatusNotFound)
			return
		}
		logger.Error("Failed to fetch task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	now := time.Now()
	updates := map[string]any{
		"completed_at": &now,
	}

	// Handle recurring tasks
	if task.Recurrence != "" {
		// Calculate next due date/datetime
		var currentDue *time.Time
		if task.DueDatetime != nil {
			currentDue = task.DueDatetime
		} else if task.DueDate != nil {
			currentDue = task.DueDate
		}

		nextDue, err := utils.CalculateNextDueDate(task.Recurrence, currentDue)
		if err != nil {
			logger.Error("Failed to calculate next due date").Str("recurrence", task.Recurrence).Err(err).Send()
			http.Error(w, fmt.Sprintf("Failed to calculate next due date: %s", err.Error()), http.StatusInternalServerError)
			return
		}

		if nextDue != nil {
			// Update the appropriate due field
			if task.DueDatetime != nil {
				updates["due_datetime"] = nextDue
			} else if task.DueDate != nil {
				// For date-only, set to date part only
				dateOnly := time.Date(nextDue.Year(), nextDue.Month(), nextDue.Day(), 0, 0, 0, 0, nextDue.Location())
				updates["due_date"] = &dateOnly
			}
		}

		// For recurring tasks, clear completed_at to keep them active
		updates["completed_at"] = nil
		logger.Info("Recurring task - updated due date and cleared completion").Uint("task_id", id).Send()
	}

	result = database.DB.Model(&task).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		logger.Error("Failed to complete task").Uint("task_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully completed task").Uint("task_id", id).Send()
	w.WriteHeader(http.StatusOK)
}

func listProjects(w http.ResponseWriter, r *http.Request) {
	logger.Info("Listing projects").Send()

	var projects []database.Project
	result := database.DB.Preload("Tasks", "deleted_at IS NULL").Where("deleted_at IS NULL").Find(&projects)
	if result.Error != nil {
		logger.Error("Failed to retrieve projects").Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully retrieved projects").Int64("count", result.RowsAffected).Send()
	json.NewEncoder(w).Encode(projects)
}

func createProject(w http.ResponseWriter, r *http.Request) {
	logger.Info("Creating new project").Send()

	var p database.Project
	err := json.NewDecoder(r.Body).Decode(&p)
	if err != nil {
		logger.Error("Failed to decode project request").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Set order if not provided
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

	logger.Info("Successfully created project").Uint("project_id", p.ID).Str("name", p.Name).Send()
	json.NewEncoder(w).Encode(p)
}

func updateProject(w http.ResponseWriter, r *http.Request) {
	logger.Info("Updating project").Send()

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

	logger.Info("Successfully updated project").Uint("project_id", id).Send()
	w.WriteHeader(http.StatusOK)
}

func deleteProject(w http.ResponseWriter, r *http.Request) {
	logger.Info("Deleting project").Send()

	id, ok := utils.ParseProjectID(r, w)
	if !ok {
		return
	}

	result := database.DB.Model(&database.Project{}).Where("id = ?", id).Updates(map[string]any{
		"deleted_at": time.Now(),
		"updated_at": time.Now(),
	})
	if result.Error != nil {
		logger.Error("Failed to delete project").Uint("project_id", id).Err(result.Error).Send()
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully deleted project").Uint("project_id", id).Send()
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
	logger.Info("Reordering projects").Send()

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

	logger.Info("Successfully reordered projects").Int("count", len(projectIDs)).Send()
	w.WriteHeader(http.StatusOK)
}

func reorderTasks(w http.ResponseWriter, r *http.Request) {

	id, ok := utils.ParseProjectID(r, w)
	if !ok {
		return
	}
	logger.Info("Reordering tasks for project").Uint("project_id", id).Send()

	var taskIDs []uint
	err := json.NewDecoder(r.Body).Decode(&taskIDs)
	if err != nil {
		logger.Error("Failed to decode task IDs").Err(err).Send()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	logger.Info("Task IDs").Interface("task_ids", taskIDs).Send()

	err = updateOrderBatch(&database.Task{}, taskIDs, "project_id = ?", id)
	if err != nil {
		logger.Error("Failed to reorder tasks").Uint("project_id", id).Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully reordered tasks").Uint("project_id", id).Int("count", len(taskIDs)).Send()
	w.WriteHeader(http.StatusOK)
}

type SyncResponse struct {
	Projects          []database.Project `json:"projects"`
	Tasks             []database.Task    `json:"tasks"`
	DeletedProjectIds []uint             `json:"deleted_project_ids"`
	DeletedTaskIds    []uint             `json:"deleted_task_ids"`
	SyncToken         string             `json:"sync_token"`
}

func syncData(w http.ResponseWriter, r *http.Request) {
	logger.Info("Syncing data").Send()

	syncToken := r.URL.Query().Get("sync_token")

	var projects []database.Project
	var tasks []database.Task
	var deletedProjectIds []uint
	var deletedTaskIds []uint

	// Parse sync token if provided
	var syncTime time.Time
	if syncToken != "" {
		var err error
		syncTime, err = time.Parse(time.RFC3339, syncToken)
		if err != nil {
			logger.Error("Invalid sync token format").Str("sync_token", syncToken).Err(err).Send()
			http.Error(w, "Invalid sync token format", http.StatusBadRequest)
			return
		}
		logger.Info("Syncing from timestamp").Time("sync_time", syncTime).Send()
	}

	// Query active projects modified after sync token
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

	// Query active tasks modified after sync token
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

	// Query deleted items if sync token is provided
	if syncToken != "" {
		// Get deleted project IDs
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

		// Get deleted task IDs
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

	// Generate new sync token (current timestamp)
	newSyncToken := time.Now().Format(time.RFC3339)

	response := SyncResponse{
		Projects:          projects,
		Tasks:             tasks,
		DeletedProjectIds: deletedProjectIds,
		DeletedTaskIds:    deletedTaskIds,
		SyncToken:         newSyncToken,
	}

	logger.Info("Successfully synced data").
		Int("projects", len(projects)).
		Int("tasks", len(tasks)).
		Int("deleted_projects", len(deletedProjectIds)).
		Int("deleted_tasks", len(deletedTaskIds)).
		Str("new_sync_token", newSyncToken).
		Send()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
