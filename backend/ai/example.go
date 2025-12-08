package ai

import (
	"fmt"
	"os"
	"time"

	"dimaist/database"
	"dimaist/logger"

	"github.com/festeh/general"
)

func CreateExampleAgent() *Agent {
	apiKey := os.Getenv("OPENROUTER_API_KEY")
	if apiKey == "" {
		logger.Warn("OPENROUTER_API_KEY not set, agent will not work").Send()
	}

	tools := []Tool{
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "create_task",
					Description: "Create a new task with description and optional project ID",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"description": {Type: "string", Description: "Task description"},
							"project_id":  {Type: "number", Description: "Project ID (optional)"},
							"due_date":    {Type: "string", Description: "Due date in YYYY-MM-DD format (optional)"},
						},
						Required: []string{"description"},
					},
				},
			},
			Handler: createTaskTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "list_tasks",
					Description: "List all tasks or tasks for a specific project",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"project_id": {Type: "number", Description: "Project ID (optional)"},
						},
					},
				},
			},
			Handler: listTasksTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "create_project",
					Description: "Create a new project with name",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"name": {Type: "string", Description: "Project name"},
						},
						Required: []string{"name"},
					},
				},
			},
			Handler: createProjectTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "list_projects",
					Description: "List all projects",
					Parameters: general.ToolParameters{
						Type:       "object",
						Properties: map[string]general.ToolParameterProperty{},
					},
				},
			},
			Handler: listProjectsTool,
		},
		{
			Tool: general.Tool{
				Type: "function",
				Function: general.ToolFunc{
					Name:        "complete_task",
					Description: "Mark a task as completed",
					Parameters: general.ToolParameters{
						Type: "object",
						Properties: map[string]general.ToolParameterProperty{
							"id": {Type: "number", Description: "Task ID"},
						},
						Required: []string{"id"},
					},
				},
			},
			Handler: completeTaskTool,
		},
	}

	// Use a default endpoint for the example - this should be replaced with actual endpoint
	endpoint := os.Getenv("OPENROUTER_ENDPOINT")
	if endpoint == "" {
		endpoint = "https://openrouter.ai/api/v1/chat/completions" // fallback
	}

	model := "google/gemini-2.0-flash-001" // default model
	return NewAgent(apiKey, endpoint, tools, model)
}

func createTaskTool(args map[string]any) (string, error) {
	description, ok := args["description"].(string)
	if !ok {
		return "", fmt.Errorf("description is required")
	}

	task := database.Task{
		Description: description,
	}

	if projectID, ok := args["project_id"].(float64); ok {
		projectIDUint := uint(projectID)
		task.ProjectID = &projectIDUint
	}

	if dueDateStr, ok := args["due_date"].(string); ok {
		dueDate, err := time.Parse("2006-01-02", dueDateStr)
		if err != nil {
			return "", fmt.Errorf("invalid due_date format, use YYYY-MM-DD")
		}
		task.DueDate = &dueDate
	}

	var maxOrder int
	database.DB.Model(&database.Task{}).Select("COALESCE(MAX(\"order\"), 0)").Where("project_id = ?", task.ProjectID).Scan(&maxOrder)
	task.Order = maxOrder + 1

	result := database.DB.Create(&task)
	if result.Error != nil {
		return "", fmt.Errorf("failed to create task: %w", result.Error)
	}

	return fmt.Sprintf("Task created successfully with ID %d: %s", task.ID, task.Description), nil
}

func listTasksTool(args map[string]any) (string, error) {
	var tasks []database.Task
	query := database.DB.Preload("Project")

	if projectID, ok := args["project_id"].(float64); ok {
		query = query.Where("project_id = ?", uint(projectID))
	}

	result := query.Find(&tasks)
	if result.Error != nil {
		return "", fmt.Errorf("failed to list tasks: %w", result.Error)
	}

	if len(tasks) == 0 {
		return "No tasks found", nil
	}

	response := fmt.Sprintf("Found %d tasks:\n", len(tasks))
	for _, task := range tasks {
		projectName := "No Project"
		if task.Project != nil {
			projectName = task.Project.Name
		}

		status := "Pending"
		if task.CompletedAt != nil {
			status = "Completed"
		}

		response += fmt.Sprintf("- ID: %d, Description: %s, Project: %s, Status: %s",
			task.ID, task.Description, projectName, status)

		if task.DueDate != nil {
			response += fmt.Sprintf(", Due: %s", task.DueDate.Format("2006-01-02"))
		}
		response += "\n"
	}

	return response, nil
}

func createProjectTool(args map[string]any) (string, error) {
	name, ok := args["name"].(string)
	if !ok {
		return "", fmt.Errorf("name is required")
	}

	project := database.Project{
		Name: name,
	}

	var maxOrder int
	database.DB.Model(&database.Project{}).Select("COALESCE(MAX(\"order\"), 0)").Scan(&maxOrder)
	project.Order = maxOrder + 1

	result := database.DB.Create(&project)
	if result.Error != nil {
		return "", fmt.Errorf("failed to create project: %w", result.Error)
	}

	return fmt.Sprintf("Project created successfully with ID %d: %s", project.ID, project.Name), nil
}

func listProjectsTool(args map[string]any) (string, error) {
	var projects []database.Project
	result := database.DB.Preload("Tasks").Find(&projects)
	if result.Error != nil {
		return "", fmt.Errorf("failed to list projects: %w", result.Error)
	}

	if len(projects) == 0 {
		return "No projects found", nil
	}

	response := fmt.Sprintf("Found %d projects:\n", len(projects))
	for _, project := range projects {
		taskCount := len(project.Tasks)
		response += fmt.Sprintf("- ID: %d, Name: %s, Tasks: %d\n",
			project.ID, project.Name, taskCount)
	}

	return response, nil
}

func completeTaskTool(args map[string]any) (string, error) {
	taskIDFloat, ok := args["id"].(float64)
	if !ok {
		return "", fmt.Errorf("id is required")
	}

	taskID := uint(taskIDFloat)

	var task database.Task
	result := database.DB.Where("id = ?", taskID).First(&task)
	if result.Error != nil {
		return "", fmt.Errorf("task not found: %w", result.Error)
	}

	if task.CompletedAt != nil {
		return "Task is already completed", nil
	}

	now := time.Now()
	result = database.DB.Model(&task).Where("id = ?", taskID).Update("completed_at", &now)
	if result.Error != nil {
		return "", fmt.Errorf("failed to complete task: %w", result.Error)
	}

	return fmt.Sprintf("Task completed successfully: %s", task.Description), nil
}

func ExampleUsage() {
	if database.DB == nil {
		logger.Error("Database not initialized").Send()
		return
	}

	agent := CreateExampleAgent()

	examples := []string{
		"Create a new project called 'Website Redesign'",
		"List all projects",
		"Create a task 'Design homepage mockup' for project 1",
		"List all tasks",
		"Complete task 1",
		"Create a task 'Write documentation' with due date 2024-01-15",
	}

	for _, example := range examples {
		fmt.Printf("\n=== User: %s ===\n", example)

		response, err := agent.Execute(example)
		if err != nil {
			fmt.Printf("Error: %v\n", err)
			continue
		}

		fmt.Printf("Agent: %s\n", response)
	}
}
