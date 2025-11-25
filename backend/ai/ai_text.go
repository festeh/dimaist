package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/dima-b/go-task-backend/database"
	"github.com/dima-b/go-task-backend/env"
	"github.com/dima-b/go-task-backend/logger"
)

const (
	// DefaultAIModel is the default AI model used when none is specified in requests
	DefaultAIModel = "google/gemini-2.0-flash-001"
)

var appEnv *env.Env

// SetEnv sets the environment configuration for the ai package
func SetEnv(e *env.Env) {
	appEnv = e
}

func SetupSSEHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cache-Control")
}

type TextRequest struct {
	Messages []ChatCompletionMessage `json:"messages"`
	Provider string                  `json:"provider,omitempty"` // Provider: "chutes" or "openrouter"
	Model    string                  `json:"model,omitempty"`    // Full model name (e.g., "zhipu/GLM-4.6")
}

func HandleAIText(w http.ResponseWriter, r *http.Request) {
	logger.Info("Handling AI text request").Send()

	// Parse request
	var req TextRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		logger.Error("Failed to decode request").Err(err).Send()
		http.Error(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	if len(req.Messages) == 0 {
		logger.Error("Empty messages in request").Send()
		http.Error(w, "Messages field is required", http.StatusBadRequest)
		return
	}

	// Validate required fields
	if req.Provider == "" {
		logger.Error("Missing provider in request").Send()
		http.Error(w, "Provider field is required", http.StatusBadRequest)
		return
	}
	if req.Model == "" {
		logger.Error("Missing model in request").Send()
		http.Error(w, "Model field is required", http.StatusBadRequest)
		return
	}
	provider := req.Provider
	model := req.Model

	// Setup SSE headers
	SetupSSEHeaders(w)

	// Create SSE writer
	sseWriter := NewSSEWriter(w)

	// Call the shared handler
	HandleAITextWithWriter(sseWriter, req.Messages, provider, model)
}

func HandleAITextWithWriter(sseWriter SSEWriter, messages []ChatCompletionMessage, provider, model string) {
	logger.Info("Handling AI text with writer").Int("messages_count", len(messages)).Str("provider", provider).Str("model", model).Send()

	// Send initial thinking event
	if err := sseWriter.Send("thinking", map[string]string{
		"message": "Loading task context...",
	}); err != nil {
		logger.Error("Failed to send initial SSE event").Err(err).Send()
		return
	}

	// Load context with limits and track timing
	contextStartTime := time.Now()
	tasks, err := LoadRecentTasks(1000)
	if err != nil {
		logger.Error("Failed to load tasks").Err(err).Send()
		sseWriter.Send("error", map[string]string{
			"error": fmt.Sprintf("Failed to load tasks: %v", err),
		})
		return
	}

	projects, err := LoadRecentProjects(100)
	if err != nil {
		logger.Error("Failed to load projects").Err(err).Send()
		sseWriter.Send("error", map[string]string{
			"error": fmt.Sprintf("Failed to load projects: %v", err),
		})
		return
	}
	contextDuration := time.Since(contextStartTime).Seconds()

	// Build system prompt and prepend to messages
	systemPrompt, err := buildSystemPrompt(tasks, projects)
	if err != nil {
		logger.Error("Failed to build system prompt").Err(err).Send()
		sseWriter.Send("error", map[string]string{
			"error": fmt.Sprintf("Failed to build system prompt: %v", err),
		})
		return
	}

	// Prepend system message to the messages array
	messagesWithSystem := []ChatCompletionMessage{
		{Role: "system", Content: systemPrompt},
	}
	messagesWithSystem = append(messagesWithSystem, messages...)

	// Create agent for message-based execution
	agent := createAIAgent(provider, model)

	// Send thinking event before starting with context loading duration
	if err := sseWriter.Send("thinking", map[string]any{
		"message":  fmt.Sprintf("Context loaded (%.2fs), starting AI agent...", contextDuration),
		"duration": contextDuration,
	}); err != nil {
		logger.Error("Failed to send thinking event").Err(err).Send()
		return
	}

	// Create context with timeout for the entire request (5 minutes max)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// Execute agent with messages and SSE streaming
	_, err = agent.ExecuteWithMessagesAndSSE(messagesWithSystem, sseWriter, ctx)
	if err != nil {
		logger.Error("Agent execution failed").Err(err).Send()
		// Error events are already sent by the agent, so we don't need to send another one
	}
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
