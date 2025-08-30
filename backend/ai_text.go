package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/dima-b/go-task-backend/ai"
	"github.com/dima-b/go-task-backend/database"
	"github.com/dima-b/go-task-backend/logger"
)

func setupSSEHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cache-Control")
}

type TextRequest struct {
	Text  string `json:"text"`
	Model string `json:"model,omitempty"` // Optional AI model, defaults to DefaultAIModel
}

func handleAIText(w http.ResponseWriter, r *http.Request) {
	logger.Info("Handling AI text request").Send()

	// Parse request
	var req TextRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		logger.Error("Failed to decode request").Err(err).Send()
		http.Error(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	if req.Text == "" {
		logger.Error("Empty text in request").Send()
		http.Error(w, "Text field is required", http.StatusBadRequest)
		return
	}

	// Use provided model or default
	model := req.Model
	if model == "" {
		model = DefaultAIModel
	}

	// Setup SSE headers
	setupSSEHeaders(w)

	// Create SSE writer
	sseWriter := ai.NewSSEWriter(w)

	// Call the shared handler
	handleAITextWithWriter(sseWriter, req.Text, model)
}

func handleAITextWithWriter(sseWriter ai.SSEWriter, text string, model string) {
	logger.Info("Handling AI text with writer").Str("text", text).Str("model", model).Send()

	// Send initial thinking event
	if err := sseWriter.Send("thinking", map[string]string{
		"message": "Loading task context...",
	}); err != nil {
		logger.Error("Failed to send initial SSE event").Err(err).Send()
		return
	}

	// Load context with limits
	tasks, err := loadRecentTasks(1000)
	if err != nil {
		logger.Error("Failed to load tasks").Err(err).Send()
		sseWriter.Send("error", map[string]string{
			"error": fmt.Sprintf("Failed to load tasks: %v", err),
		})
		return
	}

	projects, err := loadRecentProjects(100)
	if err != nil {
		logger.Error("Failed to load projects").Err(err).Send()
		sseWriter.Send("error", map[string]string{
			"error": fmt.Sprintf("Failed to load projects: %v", err),
		})
		return
	}

	// Build system prompt
	systemPrompt, err := buildSystemPrompt(tasks, projects)
	if err != nil {
		logger.Error("Failed to build system prompt").Err(err).Send()
		sseWriter.Send("error", map[string]string{
			"error": fmt.Sprintf("Failed to build system prompt: %v", err),
		})
		return
	}

	// Create agent with the system prompt and specified model
	agent := createAIAgent(systemPrompt, model)

	// Send thinking event before starting
	if err := sseWriter.Send("thinking", map[string]string{
		"message": "Starting AI agent...",
	}); err != nil {
		logger.Error("Failed to send thinking event").Err(err).Send()
		return
	}

	// Create context with timeout for the entire request (5 minutes max)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// Execute agent with SSE streaming
	_, err = agent.ExecuteWithSSE(text, sseWriter, ctx)
	if err != nil {
		logger.Error("Agent execution failed").Err(err).Send()
		// Error events are already sent by the agent, so we don't need to send another one
	}
}

func loadRecentTasks(limit int) ([]database.Task, error) {
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

func loadRecentProjects(limit int) ([]database.Project, error) {
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

	tools := ai.CreateCRUDTools()
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
You help users manage their tasks and projects efficiently.

IMPORTANT RULES:
1. Use the 'respond' tool to send final answers to the user. This tool DOES NOT MODIFY TASKS OR PROJECTS
2. Use MUST use tools (other than 'respond') to perform modifications on tasks and projects
3. ALL TASK/PROJECT DATA IS ALREADY PROVIDED BELOW - you do not need to use tools to retrieve or list existing tasks, projects, or other information
4. Never complete tasks without user's explicit ask

Current Local Time: %s

Current System State:
Tasks: %s

Projects: %s

%s

Examples of proper responses:
- To answer a question: Use the respond tool with your answer
- To create a task: Use the create_task tool with the task details

The tools will be called automatically based on your function calls.`,
		time.Now().Format("2006-01-02 15:04:05 MST"), tasksJSON, projectsJSON, toolsDesc.String()), nil
}

func createAIAgent(systemPrompt string, model string) *ai.Agent {
	tools := ai.CreateCRUDTools()

	// Select endpoint and token based on model prefix
	var apiKey, endpoint string
	if strings.HasPrefix(model, "chutes/") {
		apiKey = appEnv.ChutesToken
		endpoint = appEnv.ChutesEndpoint
	} else {
		apiKey = appEnv.OpenrouterToken
		endpoint = appEnv.OpenrouterEndpoint
	}
	
	// Trim any prefix (everything before and including the first "/")
	if slashIndex := strings.Index(model, "/"); slashIndex != -1 {
		model = model[slashIndex+1:]
	}

	// Create agent using environment configuration
	agent := ai.NewAgent(
		apiKey,       // API key
		endpoint,     // Custom AI endpoint
		systemPrompt, // initial prompt contains our full system prompt
		tools,
		model, // model
	)

	return agent
}
