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
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cache-Control")

	// Create SSE writer
	sseWriter := ai.NewSSEWriter(w)

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
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Minute)
	defer cancel()

	// Execute agent with SSE streaming
	_, err = agent.ExecuteWithSSE(req.Text, sseWriter, ctx)
	if err != nil {
		logger.Error("Agent execution failed").Err(err).Send()
		// Error events are already sent by the agent, so we don't need to send another one
	}
}

func loadRecentTasks(limit int) ([]database.Task, error) {
	var tasks []database.Task
	result := database.DB.Preload("Project").
		Where("deleted_at IS NULL").
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
	result := database.DB.Preload("Tasks", "deleted_at IS NULL").
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
		toolsDesc.WriteString(fmt.Sprintf("- %s: %s\n", tool.Name, tool.Description))
		
		// Add parameter descriptions
		for param, desc := range tool.Parameters {
			toolsDesc.WriteString(fmt.Sprintf("  * %s: %s\n", param, desc))
		}
		toolsDesc.WriteString("\n")
	}

	return fmt.Sprintf(`You are an AI assistant for a task management system called "Dimaist".
You help users manage their tasks and projects efficiently.

IMPORTANT RULES:
1. You MUST ALWAYS call a tool to perform any action or provide a response
2. You CANNOT respond directly to the user - you must use the 'respond' tool for ALL final answers
3. When you want to send a message to the user, you MUST use the 'respond' tool with the text parameter
4. All tool calls must use the format: TOOL_CALL: {"name": "tool_name", "arguments": {"arg1": "value1"}}

Current System State (up to 1000 tasks, 100 projects, most recently updated):
Tasks: %s

Projects: %s

%s

Examples of proper responses:
- To answer a question: TOOL_CALL: {"name": "respond", "arguments": {"text": "You have 5 tasks due today."}}
- To create a task: TOOL_CALL: {"name": "create_task", "arguments": {"description": "Review budget report", "due_date": "2024-01-15"}}

Remember: You cannot respond directly. Always use tools, especially the 'respond' tool for final answers.`, 
		tasksJSON, projectsJSON, toolsDesc.String()), nil
}

func createAIAgent(systemPrompt string, model string) *ai.Agent {
	tools := ai.CreateCRUDTools()
	
	// Create agent using environment configuration
	agent := ai.NewAgent(
		appEnv.AIToken,     // API key
		appEnv.AIEndpoint,  // Custom AI endpoint
		"", // context - we'll override in buildSystemPrompt
		systemPrompt, // initial prompt contains our full system prompt
		tools,
	)
	
	// Configure the agent to use the specified model
	agent.SetModel(model)
	agent.SetContext(systemPrompt)
	
	return agent
}

