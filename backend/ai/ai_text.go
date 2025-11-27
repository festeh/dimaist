package ai

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"dimaist/database"
	"dimaist/env"
	"dimaist/logger"
)

var appEnv *env.Env

// SetEnv sets the environment configuration for the ai package
func SetEnv(e *env.Env) {
	appEnv = e
}

func LoadRecentTasks(limit int) ([]database.Task, error) {
	var tasks []database.Task

	// Get date 30 days ago for filtering completed tasks
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	result := database.DB.Preload("Project").
		Where("deleted_at IS NULL").
		Where("completed_at IS NULL OR completed_at > ?", thirtyDaysAgo).
		Order("updated_at DESC").
		Limit(limit).
		Find(&tasks)

	if result.Error != nil {
		return nil, result.Error
	}

	logger.Info("Loaded recent tasks").Int("count", len(tasks)).Send()
	return tasks, nil
}

func LoadRecentProjects(limit int) ([]database.Project, error) {
	var projects []database.Project

	// Get date 30 days ago for filtering completed tasks
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	result := database.DB.Preload("Tasks", "deleted_at IS NULL AND (completed_at IS NULL OR completed_at > ?)", thirtyDaysAgo).
		Where("deleted_at IS NULL").
		Order("updated_at DESC").
		Limit(limit).
		Find(&projects)

	if result.Error != nil {
		return nil, result.Error
	}

	logger.Info("Loaded recent projects").Int("count", len(projects)).Send()
	return projects, nil
}

func buildSystemPrompt(tasks []database.Task, projects []database.Project) (string, error) {
	tasksJSON, err := json.Marshal(tasks)
	if err != nil {
		return "", fmt.Errorf("failed to marshal tasks: %w", err)
	}

	projectsJSON, err := json.Marshal(projects)
	if err != nil {
		return "", fmt.Errorf("failed to marshal projects: %w", err)
	}

	var toolsDesc strings.Builder
	toolsDesc.WriteString("Available tools:\n")

	tools := CreateCRUDTools()
	for _, tool := range tools {
		toolsDesc.WriteString(fmt.Sprintf("- %s: %s\n", tool.Function.Name, tool.Function.Description))

		// Add parameter descriptions
		for param, prop := range tool.Function.Parameters.Properties {
			requiredText := ""
			for _, req := range tool.Function.Parameters.Required {
				if req == param {
					requiredText = " (required)"
					break
				}
			}
			toolsDesc.WriteString(fmt.Sprintf("  * %s: %s%s - %s\n", param, prop.Type, requiredText, prop.Description))
		}
		toolsDesc.WriteString("\n")
	}

	return fmt.Sprintf(`You are an AI assistant for a task management system called "Dimaist".
You help users to be more productive.

ALWAYS ADHERE TO THESE RULES:
1. Use the 'respond' tool to send final answers to the user. This tool DOES NOT MODIFY TASKS OR PROJECTS
2. If user requests to modify tasks or projects, use MUST use any tools EXCEPT 'respond'
3. ALL TASK/PROJECT DATA IS ALREADY PROVIDED in the context - you do not need to use tools to retrieve or list existing tasks, projects, or other information
4. The content of 'respond' tool should ONLY include user-visible text, never put your thoughts in it
5. You can ONLY complete a task if the user EXPLICITLY asks you to complete a specific task or says they have done it. NEVER auto complete overdue tasks, you will disappoint user if a task that was not actually completed will be marked as completed
6. When user asks to add a task to their calendar, add the "calendar" label to the task - this will automatically sync it to Google Calendar

Current Local Time: %s

Current System State:
Tasks: %s

Projects: %s

%s
`,
		time.Now().Format("2006-01-02 15:04:05 MST"), tasksJSON, projectsJSON, toolsDesc.String()), nil
}

func createAIAgent(provider, model string) *Agent {
	tools := CreateCRUDTools()

	// Select endpoint and token based on provider
	var apiKey, endpoint string
	if provider == "chutes" {
		apiKey = appEnv.ChutesToken
		endpoint = appEnv.ChutesEndpoint
	} else {
		apiKey = appEnv.OpenrouterToken
		endpoint = appEnv.OpenrouterEndpoint
	}

	// Create agent using environment configuration
	agent := NewAgent(
		apiKey,   // API key
		endpoint, // Custom AI endpoint
		tools,
		model, // model (full name including provider prefix like "zhipu/GLM-4.6")
	)

	return agent
}
