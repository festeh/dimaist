package ai

import (
	"encoding/json"
	"fmt"
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

	return fmt.Sprintf(`You are a task management assistant for "Dimaist".

RULES:
1. Use 'respond' tool for final answers (does NOT modify data)
2. To modify tasks/projects, use the appropriate tools - never just 'respond'
3. Task and project data is already provided below - don't fetch it
4. Only complete tasks when user explicitly says they finished something
5. To sync a task to Google Calendar, add label "calendar"

Current time: %s

Tasks: %s

Projects: %s
`,
		time.Now().Format("2006-01-02 15:04 MST"), tasksJSON, projectsJSON), nil
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
