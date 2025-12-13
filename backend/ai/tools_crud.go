package ai

import (
	"fmt"
	"time"

	"dimaist/calendar"
	"dimaist/database"
	"dimaist/utils"

	"github.com/festeh/general"
	"github.com/lib/pq"
)

// parseDatetime tries multiple formats to parse datetime strings from AI
// For formats without timezone, assumes local timezone
func parseDatetime(s string) (time.Time, error) {
	// Formats with timezone
	for _, f := range []string{time.RFC3339, "2006-01-02T15:04Z07:00", "2006-01-02T15:04:05Z07:00"} {
		if t, err := time.Parse(f, s); err == nil {
			return t, nil
		}
	}
	// Formats without timezone - parse in local timezone
	for _, f := range []string{"2006-01-02T15:04:05", "2006-01-02T15:04", "2006-01-02 15:04:05", "2006-01-02 15:04", "2006-01-02T15:04:05.000"} {
		if t, err := time.ParseInLocation(f, s, time.Local); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("unable to parse datetime: %s", s)
}

// parseDueDate parses a due_date string, returning (dueDate, dueDatetime, error).
// If the string is date-only, returns (date, nil, nil).
// If the string is datetime (AI mistake), returns (nil, datetime, nil).
func parseDueDate(s string) (*time.Time, *time.Time, error) {
	// Try date-only first
	if dueDate, err := time.Parse("2006-01-02", s); err == nil {
		return &dueDate, nil, nil
	}
	// Fallback: AI sent datetime to due_date field
	if dueDatetime, err := parseDatetime(s); err == nil {
		return nil, &dueDatetime, nil
	}
	return nil, nil, fmt.Errorf("invalid due_date format, use YYYY-MM-DD")
}

// GetToolDefinitions returns tool definitions without handlers (for API requests)
func GetToolDefinitions() []general.Tool {
	tools := CreateCRUDTools()
	defs := make([]general.Tool, len(tools))
	for i, t := range tools {
		defs[i] = t.Tool
	}
	return defs
}

func CreateCRUDTools() []Tool {
	return []Tool{
		// Special tool to end conversation
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "respond",
					Description: "Send final response to user and end conversation",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"text": {
								Type:        "string",
								Description: "The message to send to the user",
							},
						},
						Required: []string{"text"},
					},
				},
			},
			Handler: respondTool,
		},

		// Task CRUD operations
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "create_task",
					Description: "Create a new task",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"title": {
								Type:        "string",
								Description: "Task title",
							},
							"description": {
								Type:        "string",
								Description: "Optional task description/notes",
							},
							"project_id": {
								Type:        "number",
								Description: "Project ID to assign task to",
							},
							"due_date": {
								Type:        "string",
								Description: "Due date in YYYY-MM-DD format",
							},
							"due_datetime": {
								Type:        "string",
								Description: "Due datetime in RFC3339 format",
							},
							"start_datetime": {
								Type:        "string",
								Description: "Start datetime in RFC3339 format",
							},
							"end_datetime": {
								Type:        "string",
								Description: "End datetime in RFC3339 format",
							},
							"labels": {
								Type:        "array",
								Description: "Task labels",
							},
							"reminders": {
								Type:        "array",
								Description: "Reminder times in RFC3339 format",
							},
							"recurrence": {
								Type:        "string",
								Description: "Recurrence pattern",
							},
						},
						Required: []string{"title"},
					},
				},
			},
			Handler: createTaskCRUDTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "update_task",
					Description: "Update an existing task",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"id": {
								Type:        "number",
								Description: "ID of the task to update",
							},
							"title": {
								Type:        "string",
								Description: "New task title",
							},
							"description": {
								Type:        "string",
								Description: "New task description/notes",
							},
							"project_id": {
								Type:        "number",
								Description: "New project ID",
							},
							"due_date": {
								Type:        "string",
								Description: "New due date in YYYY-MM-DD format",
							},
							"due_datetime": {
								Type:        "string",
								Description: "New due datetime in RFC3339 format",
							},
							"start_datetime": {
								Type:        "string",
								Description: "New start datetime in RFC3339 format",
							},
							"end_datetime": {
								Type:        "string",
								Description: "New end datetime in RFC3339 format",
							},
							"labels": {
								Type:        "array",
								Description: "New task labels",
							},
							"reminders": {
								Type:        "array",
								Description: "New reminder times in RFC3339 format",
							},
							"recurrence": {
								Type:        "string",
								Description: "New recurrence pattern",
							},
						},
						Required: []string{"id"},
					},
				},
			},
			Handler: updateTaskCRUDTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "delete_task",
					Description: "Delete a task (soft delete)",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"id": {
								Type:        "number",
								Description: "ID of the task to delete",
							},
						},
						Required: []string{"id"},
					},
				},
			},
			Handler: deleteTaskCRUDTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "complete_task",
					Description: "Mark a task as completed (handles recurring tasks)",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"id": {
								Type:        "number",
								Description: "ID of the task to complete",
							},
						},
						Required: []string{"id"},
					},
				},
			},
			Handler: completeTaskCRUDTool,
		},

		// Project CRUD operations
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "create_project",
					Description: "Create a new project",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"name": {
								Type:        "string",
								Description: "Project name",
							},
							"color": {
								Type:        "string",
								Description: "Project color",
							},
						},
						Required: []string{"name"},
					},
				},
			},
			Handler: createProjectCRUDTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "update_project",
					Description: "Update an existing project",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"project_id": {
								Type:        "number",
								Description: "ID of the project to update",
							},
							"name": {
								Type:        "string",
								Description: "New project name",
							},
							"color": {
								Type:        "string",
								Description: "New project color",
							},
						},
						Required: []string{"project_id"},
					},
				},
			},
			Handler: updateProjectCRUDTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "delete_project",
					Description: "Delete a project (soft delete)",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"project_id": {
								Type:        "number",
								Description: "ID of the project to delete",
							},
						},
						Required: []string{"project_id"},
					},
				},
			},
			Handler: deleteProjectCRUDTool,
		},
	}
}

// Special respond tool
func respondTool(args map[string]any) (string, error) {
	text, ok := args["text"].(string)
	if !ok {
		return "", fmt.Errorf("text parameter is required")
	}
	return text, nil
}

// Task CRUD Tools
func createTaskCRUDTool(args map[string]any) (string, error) {
	title, ok := args["title"].(string)
	if !ok {
		return "", fmt.Errorf("title is required")
	}

	task := database.Task{
		Title: title,
	}

	// Optional description
	if description, ok := args["description"].(string); ok {
		task.Description = &description
	}

	// Optional project ID - if not provided, assign to Inbox
	if projectIDFloat, ok := args["project_id"].(float64); ok {
		projectID := uint(projectIDFloat)
		task.ProjectID = &projectID
	} else {
		// Find Inbox project and assign task to it
		var inboxProject database.Project
		if err := database.DB.Where("name = ? AND deleted_at IS NULL", "Inbox").First(&inboxProject).Error; err != nil {
			return "", fmt.Errorf("failed to find Inbox project: %w", err)
		}
		task.ProjectID = &inboxProject.ID
	}

	// Optional due date
	if dueDateStr, ok := args["due_date"].(string); ok {
		dueDate, dueDatetime, err := parseDueDate(dueDateStr)
		if err != nil {
			return "", err
		}
		task.DueDate = dueDate
		task.DueDatetime = dueDatetime
	}

	// Optional due datetime
	if dueDatetimeStr, ok := args["due_datetime"].(string); ok {
		dueDatetime, err := parseDatetime(dueDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_datetime format: %w", err)
		}
		task.DueDatetime = &dueDatetime
	}

	// Optional start datetime
	if startDatetimeStr, ok := args["start_datetime"].(string); ok {
		startDatetime, err := parseDatetime(startDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid start_datetime format: %w", err)
		}
		task.StartDatetime = &startDatetime
	}

	// Optional end datetime
	if endDatetimeStr, ok := args["end_datetime"].(string); ok {
		endDatetime, err := parseDatetime(endDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid end_datetime format: %w", err)
		}
		task.EndDatetime = &endDatetime
	}

	// Optional labels
	if labelsInterface, ok := args["labels"].([]any); ok {
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
	if remindersInterface, ok := args["reminders"].([]any); ok {
		reminders := make(database.TimeArray, len(remindersInterface))
		for i, reminder := range remindersInterface {
			if reminderStr, ok := reminder.(string); ok {
				reminderTime, err := parseDatetime(reminderStr)
				if err != nil {
					return "", fmt.Errorf("invalid reminder format: %w", err)
				}
				reminders[i] = reminderTime
			} else {
				return "", fmt.Errorf("all reminders must be datetime strings")
			}
		}
		task.Reminders = reminders
	}

	// Optional recurrence
	if recurrence, ok := args["recurrence"].(string); ok {
		task.Recurrence = recurrence
	}

	// Validate recurrence pattern
	if err := utils.ValidateTaskRecurrence(task.Recurrence, task.Due()); err != nil {
		return "", fmt.Errorf("invalid recurrence pattern: %w", err)
	}

	// Create the task
	if err := database.CreateTask(&task); err != nil {
		return "", fmt.Errorf("failed to create task: %w", err)
	}

	// Sync to Google Calendar if task has "calendar" label
	if err := calendar.SyncTask(&task); err != nil {
		return fmt.Sprintf("Task created with ID %d but calendar sync failed: %s", task.ID, err.Error()), nil
	}

	return fmt.Sprintf("Task created successfully with ID %d: %s", task.ID, task.Title), nil
}

func updateTaskCRUDTool(args map[string]any) (string, error) {
	taskIDFloat, ok := args["id"].(float64)
	if !ok {
		return "", fmt.Errorf("id is required")
	}
	taskID := uint(taskIDFloat)

	// Get existing task
	var task database.Task
	if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
		return "", fmt.Errorf("task not found: %w", err)
	}

	// Update fields if provided
	updates := make(map[string]any)

	if title, ok := args["title"].(string); ok {
		updates["title"] = title
	}

	if description, ok := args["description"].(string); ok {
		updates["description"] = description
	}

	if projectIDFloat, ok := args["project_id"].(float64); ok {
		projectID := uint(projectIDFloat)
		updates["project_id"] = &projectID
	}

	if dueDateStr, ok := args["due_date"].(string); ok {
		dueDate, dueDatetime, err := parseDueDate(dueDateStr)
		if err != nil {
			return "", err
		}
		if dueDate != nil {
			updates["due_date"] = dueDate
		}
		if dueDatetime != nil {
			updates["due_datetime"] = dueDatetime
		}
	}

	if dueDatetimeStr, ok := args["due_datetime"].(string); ok {
		dueDatetime, err := parseDatetime(dueDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_datetime format: %w", err)
		}
		updates["due_datetime"] = &dueDatetime
	}

	if startDatetimeStr, ok := args["start_datetime"].(string); ok {
		startDatetime, err := parseDatetime(startDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid start_datetime format: %w", err)
		}
		updates["start_datetime"] = &startDatetime
	}

	if endDatetimeStr, ok := args["end_datetime"].(string); ok {
		endDatetime, err := parseDatetime(endDatetimeStr)
		if err != nil {
			return "", fmt.Errorf("invalid end_datetime format: %w", err)
		}
		updates["end_datetime"] = &endDatetime
	}

	if labelsInterface, ok := args["labels"].([]any); ok {
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

	if remindersInterface, ok := args["reminders"].([]any); ok {
		reminders := make(database.TimeArray, len(remindersInterface))
		for i, reminder := range remindersInterface {
			if reminderStr, ok := reminder.(string); ok {
				reminderTime, err := parseDatetime(reminderStr)
				if err != nil {
					return "", fmt.Errorf("invalid reminder format: %w", err)
				}
				reminders[i] = reminderTime
			} else {
				return "", fmt.Errorf("all reminders must be datetime strings")
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

	// Re-fetch task with updated values for calendar sync
	if err := database.DB.Where("id = ?", taskID).First(&task).Error; err != nil {
		return "", fmt.Errorf("failed to reload task: %w", err)
	}

	// Sync to Google Calendar if task has "calendar" label
	if err := calendar.SyncTask(&task); err != nil {
		return fmt.Sprintf("Task %d updated but calendar sync failed: %s", taskID, err.Error()), nil
	}

	return fmt.Sprintf("Task %d updated successfully", taskID), nil
}

func deleteTaskCRUDTool(args map[string]any) (string, error) {
	taskIDFloat, ok := args["id"].(float64)
	if !ok {
		return "", fmt.Errorf("id is required")
	}
	taskID := uint(taskIDFloat)

	rowsAffected, err := database.SoftDelete(&database.Task{}, taskID)
	if err != nil {
		return "", fmt.Errorf("failed to delete task: %w", err)
	}

	if rowsAffected == 0 {
		return "", fmt.Errorf("task not found")
	}

	return fmt.Sprintf("Task %d deleted successfully", taskID), nil
}

func completeTaskCRUDTool(args map[string]any) (string, error) {
	taskIDFloat, ok := args["id"].(float64)
	if !ok {
		return "", fmt.Errorf("id is required")
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

	updates, isRecurring, err := database.CompleteTask(&task)
	if err != nil {
		return "", fmt.Errorf("failed to calculate next due date: %w", err)
	}

	if err := database.DB.Model(&task).Where("id = ?", taskID).Updates(updates).Error; err != nil {
		return "", fmt.Errorf("failed to complete task: %w", err)
	}

	if isRecurring {
		return fmt.Sprintf("Recurring task %d completed and scheduled for next occurrence", taskID), nil
	}
	return fmt.Sprintf("Task %d completed successfully", taskID), nil
}

// Project CRUD Tools
func createProjectCRUDTool(args map[string]any) (string, error) {
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

func updateProjectCRUDTool(args map[string]any) (string, error) {
	projectIDFloat, ok := args["project_id"].(float64)
	if !ok {
		return "", fmt.Errorf("project_id is required")
	}
	projectID := uint(projectIDFloat)

	updates := make(map[string]any)

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

func deleteProjectCRUDTool(args map[string]any) (string, error) {
	projectIDFloat, ok := args["project_id"].(float64)
	if !ok {
		return "", fmt.Errorf("project_id is required")
	}
	projectID := uint(projectIDFloat)

	rowsAffected, err := database.SoftDelete(&database.Project{}, projectID)
	if err != nil {
		return "", fmt.Errorf("failed to delete project: %w", err)
	}

	if rowsAffected == 0 {
		return "", fmt.Errorf("project not found")
	}

	return fmt.Sprintf("Project %d deleted successfully", projectID), nil
}
