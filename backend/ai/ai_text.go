package ai

import (
	"encoding/json"
	"fmt"
	"time"

	"dimaist/database"
	"dimaist/env"
	"dimaist/logger"

	"github.com/lib/pq"
)

// timeMinutes marshals time.Time to local time with minute precision (no seconds/tz)
type timeMinutes time.Time

func (t timeMinutes) MarshalJSON() ([]byte, error) {
	return []byte(`"` + time.Time(t).Local().Format("2006-01-02T15:04") + `"`), nil
}

// Slim DTOs for AI context (excludes created_at/updated_at/order to reduce token usage)
type taskForAI struct {
	ID          uint               `json:"id"`
	Description string             `json:"description"`
	ProjectID   *uint              `json:"project_id,omitempty"`
	DueDate     *timeMinutes       `json:"due_date,omitempty"`
	DueDatetime *timeMinutes       `json:"due_datetime,omitempty"`
	Labels      pq.StringArray     `json:"labels,omitempty"`
	Reminders   database.TimeArray `json:"reminders,omitempty"`
	Recurrence  string             `json:"recurrence,omitempty"`
	CompletedAt *timeMinutes       `json:"completed_at,omitempty"`
}

type projectForAI struct {
	ID   uint   `json:"id"`
	Name string `json:"name"`
}

var appEnv *env.Env

// SetEnv sets the environment configuration for the ai package
func SetEnv(e *env.Env) {
	appEnv = e
}

func LoadRecentTasks(limit int) ([]database.Task, error) {
	var tasks []database.Task

	// Get date 30 days ago for filtering completed tasks
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	result := database.DB.
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

	result := database.DB.
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

func toTimeMinutes(t *time.Time) *timeMinutes {
	if t == nil {
		return nil
	}
	tm := timeMinutes(*t)
	return &tm
}

func BuildSystemPrompt(tasks []database.Task, projects []database.Project) (string, error) {
	// Convert to slim DTOs to reduce token usage
	slimTasks := make([]taskForAI, len(tasks))
	for i, t := range tasks {
		slimTasks[i] = taskForAI{
			ID:          t.ID,
			Description: t.Description,
			ProjectID:   t.ProjectID,
			DueDate:     toTimeMinutes(t.DueDate),
			DueDatetime: toTimeMinutes(t.DueDatetime),
			Labels:      t.Labels,
			Reminders:   t.Reminders,
			Recurrence:  t.Recurrence,
			CompletedAt: toTimeMinutes(t.CompletedAt),
		}
	}

	slimProjects := make([]projectForAI, len(projects))
	for i, p := range projects {
		slimProjects[i] = projectForAI{
			ID:   p.ID,
			Name: p.Name,
		}
	}

	tasksJSON, err := json.Marshal(slimTasks)
	if err != nil {
		return "", fmt.Errorf("failed to marshal tasks: %w", err)
	}

	projectsJSON, err := json.Marshal(slimProjects)
	if err != nil {
		return "", fmt.Errorf("failed to marshal projects: %w", err)
	}

	tz, _ := time.Now().Zone()
	return fmt.Sprintf(`You are a task management assistant for "Dimaist".

RULES:
1. Use 'respond' tool for final answers (does NOT modify data)
2. To modify tasks/projects, use the appropriate tools - never just 'respond'
3. Task and project data is already provided below - don't fetch it
4. Only complete tasks when user explicitly says they finished something
5. To sync a task to Google Calendar, add label "calendar"
6. All datetimes are in %s timezone

Current time: %s

Tasks: %s

Projects: %s
`,
		tz, time.Now().Format("2006-01-02T15:04"), tasksJSON, projectsJSON), nil
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
