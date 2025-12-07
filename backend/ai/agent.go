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

// ExecuteWithWS runs the agent with WebSocket communication and tool confirmation flow
func (a *Agent) ExecuteWithWS(messages []ChatCompletionMessage, ws *WSWriter, ctx context.Context) error {
	logger.Info("Starting AI agent execution with WebSocket").
		Int("messages_count", len(messages)).
		Str("model", a.target.Model).
		Send()

	maxIterations := 15
	for i := 0; i < maxIterations; i++ {
		logger.Info("Agent iteration").Int("iteration", i+1).Send()

		// Check context cancellation
		select {
		case <-ctx.Done():
			logger.Info("Context cancelled, stopping agent").Send()
			return ctx.Err()
		default:
		}

		// Send thinking event
		if err := ws.SendThinking(fmt.Sprintf("Processing request (iteration %d/%d)...", i+1, maxIterations), 0); err != nil {
			logger.Error("Failed to send thinking event").Err(err).Send()
			return err
		}

		// Call model with timeout and track timing
		modelStartTime := time.Now()
		response, err := a.callModelWithTimeout(ctx, messages)
		modelDuration := time.Since(modelStartTime).Seconds()

		if err != nil {
			logger.Error("Model call failed").Err(err).Send()
			ws.SendError(fmt.Sprintf("AI call failed: %v", err))
			return fmt.Errorf("model call failed: %w", err)
		}

		logEvent := logger.Info("Model response received").
			Str("content", response.Choices[0].Message.Content).
			Int("tool_calls_count", len(response.Choices[0].Message.ToolCalls))

		if len(response.Choices[0].Message.ToolCalls) > 0 {
			toolNames := make([]string, len(response.Choices[0].Message.ToolCalls))
			for j, toolCall := range response.Choices[0].Message.ToolCalls {
				toolNames[j] = toolCall.Function.Name
			}
			logEvent = logEvent.Strs("tool_calls", toolNames)
		}

		logEvent.Send()

		if !a.hasToolCalls(response) {
			// No tool calls, return the response content
			logger.Info("No tool calls found, returning response").Send()
			responseText := response.Choices[0].Message.Content
			if err := ws.SendFinalResponse(responseText, modelDuration); err != nil {
				logger.Error("Failed to send final_response event").Err(err).Send()
				return err
			}
			return nil
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
						if err := ws.SendFinalResponse(text, modelDuration); err != nil {
							logger.Error("Failed to send final_response event").Err(err).Send()
							return err
						}
						logger.Info("Agent execution completed with respond tool").Send()
						return nil
					}
				}
				ws.SendFinalResponse("Invalid response format", modelDuration)
				return nil
			}

			// Parse tool arguments
			var args map[string]any
			if err := json.Unmarshal([]byte(toolCall.Function.Arguments), &args); err != nil {
				logger.Error("Failed to parse tool arguments").Err(err).Send()
				messages = append(messages, ChatCompletionMessage{
					Role:       "tool",
					Content:    fmt.Sprintf("Error: failed to parse arguments: %v", err),
					ToolCallID: toolCall.ID,
				})
				continue
			}

			// Check if confirmation is required for this tool
			if ConfirmationRequiredTools[toolCall.Function.Name] {
				logger.Info("Tool requires confirmation").Str("tool", toolCall.Function.Name).Send()

				// Resolve defaults before sending to frontend
				argsForPreview := resolveToolDefaults(toolCall.Function.Name, args)

				// Send tool pending event with LLM duration
				if err := ws.SendToolPending(toolCall.Function.Name, argsForPreview, modelDuration); err != nil {
					logger.Error("Failed to send tool_pending event").Err(err).Send()
					return err
				}

				// Wait for user confirmation
				confirmed, modifiedArgs, err := ws.WaitForConfirmation()
				if err != nil {
					logger.Error("Failed to wait for confirmation").Err(err).Send()
					return err
				}

				if !confirmed {
					logger.Info("Tool execution rejected by user").Str("tool", toolCall.Function.Name).Send()
					ws.SendCancelled()
					return nil
				}

				// Use modified args if provided
				if modifiedArgs != nil {
					args = modifiedArgs
					logger.Info("Using modified arguments from user").Interface("args", args).Send()
				}
			}

			// Execute tool
			toolStartTime := time.Now()
			toolResult, err := a.executeToolWithArgs(toolCall.Function.Name, args)
			toolDuration := time.Since(toolStartTime).Seconds()

			if err != nil {
				logger.Error("Tool execution failed").Str("tool", toolCall.Function.Name).Err(err).Send()

				// Add error to conversation for recovery
				messages = append(messages, ChatCompletionMessage{
					Role:       "tool",
					Content:    fmt.Sprintf("Error: %v", err),
					ToolCallID: toolCall.ID,
				})
				continue
			}

			// Send tool result event
			if err := ws.SendToolResult(toolResult, toolDuration); err != nil {
				logger.Error("Failed to send tool_result event").Err(err).Send()
				return err
			}

			logger.Info("Tool executed successfully").Str("tool", toolCall.Function.Name).Str("result", toolResult).Send()

			// For confirmation-required tools, skip AI response - user already knows what happened
			if ConfirmationRequiredTools[toolCall.Function.Name] {
				logger.Info("Skipping AI confirmation response for confirmed tool").Str("tool", toolCall.Function.Name).Send()
				return nil
			}

			// Add tool result to conversation for non-confirmed tools
			messages = append(messages, ChatCompletionMessage{
				Role:       "tool",
				Content:    toolResult,
				ToolCallID: toolCall.ID,
			})
		}
	}

	// Max iterations reached
	ws.SendError("Maximum iterations reached without final response")
	return fmt.Errorf("maximum iterations reached without final response")
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

	// For complete_task and delete_task, fetch task details for preview
	if toolName == "complete_task" || toolName == "delete_task" {
		if taskID, ok := result["task_id"].(float64); ok {
			var task database.Task
			if err := database.DB.First(&task, int(taskID)).Error; err == nil {
				result["description"] = task.Description
				if task.ProjectID != nil {
					result["project_id"] = float64(*task.ProjectID)
				}
				if task.DueDate != nil {
					result["due_date"] = task.DueDate.Format("2006-01-02")
				}
				if len(task.Labels) > 0 {
					result["labels"] = task.Labels
				}
			}
		}
	}

	return result
}
