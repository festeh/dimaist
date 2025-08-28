package ai

import (
	"fmt"
	"time"

	"github.com/dima-b/go-task-backend/database"
	"github.com/dima-b/go-task-backend/utils"
	"github.com/lib/pq"
)

func CreateCRUDTools() []Tool {
	return []Tool{
		// Special tool to end conversation
		{
			Name:        "respond",
			Description: "Send final response to user and end conversation",
			Parameters: map[string]interface{}{
				"text": "string (required) - The message to send to the user",
			},
			Function: respondTool,
		},

		// Task CRUD operations
		{
			Name:        "create_task",
			Description: "Create a new task",
			Parameters: map[string]interface{}{
				"description":    "string (required) - Task description",
				"project_id":     "number (optional) - Project ID to assign task to",
				"due_date":       "string (optional) - Due date in YYYY-MM-DD format",
				"due_datetime":   "string (optional) - Due datetime in RFC3339 format",
				"start_datetime": "string (optional) - Start datetime in RFC3339 format",
				"end_datetime":   "string (optional) - End datetime in RFC3339 format",
				"labels":         "array of strings (optional) - Task labels",
				"reminders":      "array of strings (optional) - Reminder times in RFC3339 format",
				"recurrence":     "string (optional) - Recurrence pattern",
			},
			Function: createTaskCRUDTool,
		},
		{
			Name:        "update_task",
			Description: "Update an existing task",
			Parameters: map[string]interface{}{
				"task_id":        "number (required) - ID of the task to update",
				"description":    "string (optional) - New task description",
				"project_id":     "number (optional) - New project ID",
				"due_date":       "string (optional) - New due date in YYYY-MM-DD format",
				"due_datetime":   "string (optional) - New due datetime in RFC3339 format",
				"start_datetime": "string (optional) - New start datetime in RFC3339 format",
				"end_datetime":   "string (optional) - New end datetime in RFC3339 format",
				"labels":         "array of strings (optional) - New task labels",
				"reminders":      "array of strings (optional) - New reminder times in RFC3339 format",
				"recurrence":     "string (optional) - New recurrence pattern",
			},
			Function: updateTaskCRUDTool,
		},
		{
			Name:        "delete_task",
			Description: "Delete a task (soft delete)",
			Parameters: map[string]interface{}{
				"task_id": "number (required) - ID of the task to delete",
			},
			Function: deleteTaskCRUDTool,
		},
		{
			Name:        "complete_task",
			Description: "Mark a task as completed (handles recurring tasks)",
			Parameters: map[string]interface{}{
				"task_id": "number (required) - ID of the task to complete",
			},
			Function: completeTaskCRUDTool,
		},

		// Project CRUD operations
		{
			Name:        "create_project",
			Description: "Create a new project",
			Parameters: map[string]interface{}{
				"name":  "string (required) - Project name",
				"color": "string (optional) - Project color",
			},
			Function: createProjectCRUDTool,
		},
		{
			Name:        "update_project",
			Description: "Update an existing project",
			Parameters: map[string]interface{}{
				"project_id": "number (required) - ID of the project to update",
				"name":       "string (optional) - New project name",
				"color":      "string (optional) - New project color",
			},
			Function: updateProjectCRUDTool,
		},
		{
			Name:        "delete_project",
			Description: "Delete a project (soft delete)",
			Parameters: map[string]interface{}{
				"project_id": "number (required) - ID of the project to delete",
			},
			Function: deleteProjectCRUDTool,
		},
	}
}

// Special respond tool
func respondTool(args map[string]interface{}) (string, error) {
	text, ok := args["text"].(string)
	if !ok {
		return "", fmt.Errorf("text parameter is required")
	}
	return text, nil
}

// Task CRUD Tools
func createTaskCRUDTool(args map[string]interface{}) (string, error) {
	description, ok := args["description"].(string)
	if !ok {
		return "", fmt.Errorf("description is required")
	}

	task := database.Task{
		Description: description,
	}

	// Optional project ID
	if projectIDFloat, ok := args["project_id"].(float64); ok {
		projectID := uint(projectIDFloat)
		task.ProjectID = &projectID
	}

	// Optional due date
	if dueDateStr, ok := args["due_date"].(string); ok {
		dueDate, err := time.Parse("2006-01-02", dueDateStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_date format, use YYYY-MM-DD: %w", err)
		}
		task.DueDate = &dueDate
	}

	// Optional due datetime
	if dueDatetimeStr, ok := args["due_datetime"].(string); ok {
		dueDatetime, err := time.Parse(time.RFC3339, dueDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_datetime format, use RFC3339: %w", err)
		}
		task.DueDatetime = &dueDatetime
	}

	// Optional start datetime
	if startDatetimeStr, ok := args["start_datetime"].(string); ok {
		startDatetime, err := time.Parse(time.RFC3339, startDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid start_datetime format, use RFC3339: %w", err)
		}
		task.StartDatetime = &startDatetime
	}

	// Optional end datetime
	if endDatetimeStr, ok := args["end_datetime"].(string); ok {
		endDatetime, err := time.Parse(time.RFC3339, endDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid end_datetime format, use RFC3339: %w", err)
		}
		task.EndDatetime = &endDatetime
	}

	// Optional labels
	if labelsInterface, ok := args["labels"].([]interface{}); ok {
		labels := make([]string, len(labelsInterface))
		for i, label := range labelsInterface {
			if labelStr, ok := label.(string); ok {
				labels[i] = labelStr
			} else {
				return "", fmt.Errorf("all labels must be strings")
			}
		}
		task.Labels = pq.StringArray(labels)
	}

	// Optional reminders
	if remindersInterface, ok := args["reminders"].([]interface{}); ok {
		reminders := make(database.TimeArray, len(remindersInterface))
		for i, reminder := range remindersInterface {
			if reminderStr, ok := reminder.(string); ok {
				reminderTime, err := time.Parse(time.RFC3339, reminderStr)
				if err != nil {
					return "", fmt.Errorf("invalid reminder format, use RFC3339: %w", err)
				}
				reminders[i] = reminderTime
			} else {
				return "", fmt.Errorf("all reminders must be RFC3339 strings")
			}
		}
		task.Reminders = reminders
	}

	// Optional recurrence
	if recurrence, ok := args["recurrence"].(string); ok {
		task.Recurrence = recurrence
	}

	// Validate recurrence pattern
	if err := utils.ValidateTaskRecurrence(task.Recurrence, task.DueDate, task.DueDatetime); err != nil {
		return "", fmt.Errorf("invalid recurrence pattern: %w", err)
	}

	// Set order
	var maxOrder int
	orderResult := database.DB.Model(&database.Task{}).Select("COALESCE(MAX(\"order\"), 0)").Where("project_id = ? AND deleted_at IS NULL", task.ProjectID).Scan(&maxOrder)
	if orderResult.Error != nil {
		return "", fmt.Errorf("failed to get max order: %w", orderResult.Error)
	}
	task.Order = maxOrder + 1

	// Create the task
	result := database.DB.Create(&task)
	if result.Error != nil {
		return "", fmt.Errorf("failed to create task: %w", result.Error)
	}

	return fmt.Sprintf("Task created successfully with ID %d: %s", task.ID, task.Description), nil
}

func updateTaskCRUDTool(args map[string]interface{}) (string, error) {
	taskIDFloat, ok := args["task_id"].(float64)
	if !ok {
		return "", fmt.Errorf("task_id is required")
	}
	taskID := uint(taskIDFloat)

	// Get existing task
	var task database.Task
	if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
		return "", fmt.Errorf("task not found: %w", err)
	}

	// Update fields if provided
	updates := make(map[string]interface{})

	if description, ok := args["description"].(string); ok {
		updates["description"] = description
	}

	if projectIDFloat, ok := args["project_id"].(float64); ok {
		projectID := uint(projectIDFloat)
		updates["project_id"] = &projectID
	}

	if dueDateStr, ok := args["due_date"].(string); ok {
		dueDate, err := time.Parse("2006-01-02", dueDateStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_date format: %w", err)
		}
		updates["due_date"] = &dueDate
	}

	if dueDatetimeStr, ok := args["due_datetime"].(string); ok {
		dueDatetime, err := time.Parse(time.RFC3339, dueDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_datetime format: %w", err)
		}
		updates["due_datetime"] = &dueDatetime
	}

	if startDatetimeStr, ok := args["start_datetime"].(string); ok {
		startDatetime, err := time.Parse(time.RFC3339, startDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid start_datetime format: %w", err)
		}
		updates["start_datetime"] = &startDatetime
	}

	if endDatetimeStr, ok := args["end_datetime"].(string); ok {
		endDatetime, err := time.Parse(time.RFC3339, endDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid end_datetime format: %w", err)
		}
		updates["end_datetime"] = &endDatetime
	}

	if labelsInterface, ok := args["labels"].([]interface{}); ok {
		labels := make([]string, len(labelsInterface))
		for i, label := range labelsInterface {
			if labelStr, ok := label.(string); ok {
				labels[i] = labelStr
			} else {
				return "", fmt.Errorf("all labels must be strings")
			}
		}
		updates["labels"] = pq.StringArray(labels)
	}

	if remindersInterface, ok := args["reminders"].([]interface{}); ok {
		reminders := make(database.TimeArray, len(remindersInterface))
		for i, reminder := range remindersInterface {
			if reminderStr, ok := reminder.(string); ok {
				reminderTime, err := time.Parse(time.RFC3339, reminderStr)
				if err != nil {
					return "", fmt.Errorf("invalid reminder format: %w", err)
				}
				reminders[i] = reminderTime
			} else {
				return "", fmt.Errorf("all reminders must be RFC3339 strings")
			}
		}
		updates["reminders"] = reminders
	}

	if recurrence, ok := args["recurrence"].(string); ok {
		updates["recurrence"] = recurrence
	}

	if len(updates) == 0 {
		return "No fields to update", nil
	}

	// Perform update
	if err := database.DB.Model(&task).Where("id = ? AND deleted_at IS NULL", taskID).Updates(updates).Error; err != nil {
		return "", fmt.Errorf("failed to update task: %w", err)
	}

	return fmt.Sprintf("Task %d updated successfully", taskID), nil
}

func deleteTaskCRUDTool(args map[string]interface{}) (string, error) {
	taskIDFloat, ok := args["task_id"].(float64)
	if !ok {
		return "", fmt.Errorf("task_id is required")
	}
	taskID := uint(taskIDFloat)

	result := database.DB.Model(&database.Task{}).Where("id = ?", taskID).Updates(map[string]any{
		"deleted_at": time.Now(),
		"updated_at": time.Now(),
	})
	if result.Error != nil {
		return "", fmt.Errorf("failed to delete task: %w", result.Error)
	}

	if result.RowsAffected == 0 {
		return "", fmt.Errorf("task not found")
	}

	return fmt.Sprintf("Task %d deleted successfully", taskID), nil
}

func completeTaskCRUDTool(args map[string]interface{}) (string, error) {
	taskIDFloat, ok := args["task_id"].(float64)
	if !ok {
		return "", fmt.Errorf("task_id is required")
	}
	taskID := uint(taskIDFloat)

	// Get the task first to handle recurring tasks
	var task database.Task
	if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
		return "", fmt.Errorf("task not found: %w", err)
	}

	if task.CompletedAt != nil {
		return "Task is already completed", nil
	}

	now := time.Now()
	updates := map[string]any{
		"completed_at": &now,
	}

	// Handle recurring tasks
	if task.Recurrence != "" {
		var currentDue *time.Time
		if task.DueDatetime != nil {
			currentDue = task.DueDatetime
		} else if task.DueDate != nil {
			currentDue = task.DueDate
		}

		nextDue, err := utils.CalculateNextDueDate(task.Recurrence, currentDue)
		if err != nil {
			return "", fmt.Errorf("failed to calculate next due date: %w", err)
		}

		if nextDue != nil {
			if task.DueDatetime != nil {
				updates["due_datetime"] = nextDue
			} else if task.DueDate != nil {
				dateOnly := time.Date(nextDue.Year(), nextDue.Month(), nextDue.Day(), 0, 0, 0, 0, nextDue.Location())
				updates["due_date"] = &dateOnly
			}
		}

		// For recurring tasks, clear completed_at to keep them active
		updates["completed_at"] = nil
	}

	if err := database.DB.Model(&task).Where("id = ?", taskID).Updates(updates).Error; err != nil {
		return "", fmt.Errorf("failed to complete task: %w", err)
	}

	if task.Recurrence != "" {
		return fmt.Sprintf("Recurring task %d completed and scheduled for next occurrence", taskID), nil
	}
	return fmt.Sprintf("Task %d completed successfully", taskID), nil
}


// Project CRUD Tools
func createProjectCRUDTool(args map[string]interface{}) (string, error) {
	name, ok := args["name"].(string)
	if !ok {
		return "", fmt.Errorf("name is required")
	}

	project := database.Project{
		Name:  name,
		Color: "gray", // Default color
	}

	// Optional color
	if color, ok := args["color"].(string); ok {
		project.Color = color
	}

	// Set order
	var maxOrder int
	database.DB.Model(&database.Project{}).Select("COALESCE(MAX(\"order\"), 0)").Where("deleted_at IS NULL").Scan(&maxOrder)
	project.Order = maxOrder + 1

	if err := database.DB.Create(&project).Error; err != nil {
		return "", fmt.Errorf("failed to create project: %w", err)
	}

	return fmt.Sprintf("Project created successfully with ID %d: %s", project.ID, project.Name), nil
}

func updateProjectCRUDTool(args map[string]interface{}) (string, error) {
	projectIDFloat, ok := args["project_id"].(float64)
	if !ok {
		return "", fmt.Errorf("project_id is required")
	}
	projectID := uint(projectIDFloat)

	updates := make(map[string]interface{})

	if name, ok := args["name"].(string); ok {
		updates["name"] = name
	}

	if color, ok := args["color"].(string); ok {
		updates["color"] = color
	}

	if len(updates) == 0 {
		return "No fields to update", nil
	}

	result := database.DB.Model(&database.Project{}).Where("id = ? AND deleted_at IS NULL", projectID).Updates(updates)
	if result.Error != nil {
		return "", fmt.Errorf("failed to update project: %w", result.Error)
	}

	if result.RowsAffected == 0 {
		return "", fmt.Errorf("project not found")
	}

	return fmt.Sprintf("Project %d updated successfully", projectID), nil
}

func deleteProjectCRUDTool(args map[string]interface{}) (string, error) {
	projectIDFloat, ok := args["project_id"].(float64)
	if !ok {
		return "", fmt.Errorf("project_id is required")
	}
	projectID := uint(projectIDFloat)

	result := database.DB.Model(&database.Project{}).Where("id = ?", projectID).Updates(map[string]any{
		"deleted_at": time.Now(),
		"updated_at": time.Now(),
	})
	if result.Error != nil {
		return "", fmt.Errorf("failed to delete project: %w", result.Error)
	}

	if result.RowsAffected == 0 {
		return "", fmt.Errorf("project not found")
	}

	return fmt.Sprintf("Project %d deleted successfully", projectID), nil
}

