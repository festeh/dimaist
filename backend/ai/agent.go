package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"dimaist/database"
	"dimaist/logger"

	"github.com/festeh/general"
)

// Tool wraps general.Tool with a local Handler for execution.
type Tool struct {
	general.Tool
	Handler func(args map[string]any) (string, error)
}

// Convenience type aliases for cleaner code
type (
	ChatCompletionMessage  = general.ChatCompletionMessage
	ChatCompletionResponse = general.ChatCompletionResponse
	ChatCompletionRequest  = general.ChatCompletionRequest
	ToolCall               = general.ToolCall
)

type Agent struct {
	target general.Target
	tools  []Tool
	cmd    *general.Command
}

func NewAgent(apiKey, endpoint string, tools []Tool, model string) *Agent {
	provider := general.Provider{
		Endpoint: endpoint,
		APIKey:   apiKey,
	}
	target := general.Target{
		Provider: provider,
		Model:    model,
	}
	return &Agent{
		target: target,
		tools:  tools,
		cmd:    general.NewCommand([]general.Target{target}, nil),
	}
}

func (a *Agent) Execute(userInput string) (string, error) {
	logger.Info("Starting AI agent execution").
		Str("user_input", userInput).
		Str("model", a.target.Model).
		Send()

	messages := []ChatCompletionMessage{
		{
			Role:    "user",
			Content: userInput,
		},
	}

	maxIterations := 10
	for i := 0; i < maxIterations; i++ {
		logger.Info("Agent iteration").Int("iteration", i+1).Send()

		response, err := a.callModel(messages)
		if err != nil {
			logger.Error("Model call failed").Err(err).Send()
			return "", fmt.Errorf("model call failed: %w", err)
		}

		logEvent := logger.Info("Model response received").
			Str("content", response.Choices[0].Message.Content).
			Int("tool_calls_count", len(response.Choices[0].Message.ToolCalls))
		
		if len(response.Choices[0].Message.ToolCalls) > 0 {
			toolNames := make([]string, len(response.Choices[0].Message.ToolCalls))
			for i, toolCall := range response.Choices[0].Message.ToolCalls {
				toolNames[i] = toolCall.Function.Name
			}
			logEvent = logEvent.Strs("tool_calls", toolNames)
		}
		
		logEvent.Send()

		if !a.hasToolCalls(response) {
			logger.Info("No tool call found, returning response").Send()
			return response.Choices[0].Message.Content, nil
		}

		// Process tool calls
		messages = append(messages, response.Choices[0].Message)

		for _, toolCall := range response.Choices[0].Message.ToolCalls {
			logger.Info("Tool call detected").
				Str("tool", toolCall.Function.Name).
				Str("arguments", toolCall.Function.Arguments).
				Send()

			// Check for respond tool (final response)
			if toolCall.Function.Name == "respond" {
				var args map[string]any
				if err := json.Unmarshal([]byte(toolCall.Function.Arguments), &args); err == nil {
					if text, ok := args["text"].(string); ok {
						return text, nil
					}
				}
				return "Invalid response format", nil
			}

			toolResult, err := a.executeTool(toolCall)
			if err != nil {
				logger.Error("Tool execution failed").Str("tool", toolCall.Function.Name).Err(err).Send()
				return "", fmt.Errorf("tool execution failed: %w", err)
			}

			// Add tool result to conversation
			messages = append(messages, ChatCompletionMessage{
				Role:       "tool",
				Content:    toolResult,
				ToolCallID: toolCall.ID,
			})

			logger.Info("Tool executed successfully").Str("tool", toolCall.Function.Name).Str("result", toolResult).Send()
		}
	}

	return "", fmt.Errorf("maximum iterations reached without final response")
}

func (a *Agent) callModel(messages []ChatCompletionMessage) (*ChatCompletionResponse, error) {
	return a.callModelWithTimeout(context.Background(), messages)
}

func (a *Agent) callModelWithTimeout(ctx context.Context, messages []ChatCompletionMessage) (*ChatCompletionResponse, error) {
	// Convert local tools to general.Tool (without handlers)
	generalTools := make([]general.Tool, len(a.tools))
	for i, t := range a.tools {
		generalTools[i] = t.Tool
	}

	request := ChatCompletionRequest{
		Model:       a.target.Model,
		MaxTokens:   10000,
		Temperature: 0.1,
		Messages:    messages,
		Tools:       generalTools,
		ToolChoice:  "auto",
	}

	// Debug: Log the request being sent
	logger.Info("Sending request to LLM").
		Str("endpoint", a.target.Provider.Endpoint).
		Str("model", request.Model).
		Int("tools_count", len(request.Tools)).
		Send()

	// Debug: Log full request (only visible with --verbose flag)
	logger.Debug("AI request").Interface("request", request).Send()

	// Use general.Command for the HTTP call with retry
	resp, err := a.cmd.ExecuteOne(request)
	if err != nil {
		return nil, err
	}

	// Debug: Log full response (only visible with --verbose flag)
	logger.Debug("AI response").Interface("response", resp).Send()

	return &resp, nil
}

func (a *Agent) hasToolCalls(response *ChatCompletionResponse) bool {
	if len(response.Choices) == 0 {
		return false
	}
	return len(response.Choices[0].Message.ToolCalls) > 0
}

func (a *Agent) executeTool(toolCall ToolCall) (string, error) {
	for _, tool := range a.tools {
		if tool.Function.Name == toolCall.Function.Name {
			// Parse arguments from JSON string
			var args map[string]any
			if err := json.Unmarshal([]byte(toolCall.Function.Arguments), &args); err != nil {
				return "", fmt.Errorf("failed to parse tool arguments: %w", err)
			}
			return tool.Handler(args)
		}
	}

	return "", fmt.Errorf("tool not found: %s", toolCall.Function.Name)
}

func (a *Agent) AddTool(tool Tool) {
	a.tools = append(a.tools, tool)
}

// executeToolWithArgs executes a tool with pre-parsed arguments
func (a *Agent) executeToolWithArgs(toolName string, args map[string]any) (string, error) {
	for _, tool := range a.tools {
		if tool.Function.Name == toolName {
			return tool.Handler(args)
		}
	}
	return "", fmt.Errorf("tool not found: %s", toolName)
}

func (a *Agent) SetModel(model string) {
	a.target.Model = model
}

// ExecuteOneStep executes just one step of the conversation and returns the tool calls
// This is useful for testing to see what tools the LLM would call without executing them
func (a *Agent) ExecuteOneStep(userInput string) ([]ToolCall, error) {
	messages := []ChatCompletionMessage{
		{
			Role:    "user",
			Content: userInput,
		},
	}

	response, err := a.callModel(messages)
	if err != nil {
		return nil, fmt.Errorf("model call failed: %w", err)
	}

	if !a.hasToolCalls(response) {
		// No tool calls, return empty slice
		return []ToolCall{}, nil
	}

	return response.Choices[0].Message.ToolCalls, nil
}

// resolveToolDefaults adds default values to tool arguments for frontend preview
func resolveToolDefaults(toolName string, args map[string]any) map[string]any {
	// Copy args to avoid modifying original
	result := make(map[string]any)
	for k, v := range args {
		result[k] = v
	}

	// For create_task, default to Inbox project if not specified
	if toolName == "create_task" {
		if _, hasProject := result["project_id"]; !hasProject {
			var inboxProject database.Project
			if err := database.DB.Where("name = ? AND deleted_at IS NULL", "Inbox").First(&inboxProject).Error; err == nil {
				result["project_id"] = float64(inboxProject.ID)
			}
		}
	}

	// For task operations, fetch task details for preview
	if toolName == "complete_task" || toolName == "delete_task" || toolName == "update_task" {
		if taskID, ok := result["id"].(float64); ok {
			var task database.Task
			if err := database.DB.Where("deleted_at IS NULL").First(&task, int(taskID)).Error; err != nil {
				// Task not found - add error info for frontend
				result["_error"] = fmt.Sprintf("Task #%d not found", int(taskID))
			} else {
				// For update_task, only fill missing fields (preserve AI-provided updates)
				// For complete/delete, always set fields (they don't modify anything)
				if _, exists := result["description"]; !exists {
					result["description"] = task.Description
				}
				if _, exists := result["project_id"]; !exists && task.ProjectID != nil {
					result["project_id"] = float64(*task.ProjectID)
				}
				if _, hasDue := result["due_datetime"]; !hasDue {
					if _, hasDate := result["due_date"]; !hasDate && task.Due() != nil {
						if task.HasTime() {
							result["due_datetime"] = task.Due().Format(time.RFC3339)
						} else {
							result["due_date"] = task.Due().Format("2006-01-02")
						}
					}
				}
				if _, exists := result["labels"]; !exists && len(task.Labels) > 0 {
					result["labels"] = task.Labels
				}
			}
		}
	}

	return result
}
