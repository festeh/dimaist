package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"dimaist/database"
	"dimaist/logger"
)

type Tool struct {
	Type     string                                            `json:"type"`
	Function ToolFunc                                          `json:"function"`
	Handler  func(args map[string]any) (string, error) `json:"-"`
}

type ToolFunc struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  ToolParameters `json:"parameters"`
}

type ToolParameters struct {
	Type       string                           `json:"type"`
	Properties map[string]ToolParameterProperty `json:"properties"`
	Required   []string                         `json:"required,omitempty"`
}

type ToolParameterProperty struct {
	Type        string   `json:"type"`
	Description string   `json:"description,omitempty"`
	Enum        []string `json:"enum,omitempty"`
}

type Agent struct {
	apiKey   string
	endpoint string
	tools    []Tool
	model    string
	client   *http.Client
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ToolCall struct {
	ID       string           `json:"id"`
	Type     string           `json:"type"`
	Function ToolCallFunction `json:"function"`
}

type ToolCallFunction struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

// OpenAI-compatible API structures
type ChatCompletionRequest struct {
	Model       string                  `json:"model"`
	Messages    []ChatCompletionMessage `json:"messages"`
	MaxTokens   int                     `json:"max_tokens,omitempty"`
	Temperature float64                 `json:"temperature,omitempty"`
	Tools       []Tool                  `json:"tools,omitempty"`
	ToolChoice  any             `json:"tool_choice,omitempty"`
}

type ChatCompletionMessage struct {
	Role       string     `json:"role"`
	Content    string     `json:"content,omitempty"`
	ToolCalls  []ToolCall `json:"tool_calls,omitempty"`
	ToolCallID string     `json:"tool_call_id,omitempty"`
}

type ChatCompletionResponse struct {
	Choices []ChatCompletionChoice `json:"choices"`
}

type ChatCompletionChoice struct {
	Message      ChatCompletionMessage `json:"message"`
	FinishReason string                `json:"finish_reason,omitempty"`
}

func NewAgent(apiKey, endpoint string, tools []Tool, model string) *Agent {
	return &Agent{
		apiKey:   apiKey,
		endpoint: endpoint,
		tools:    tools,
		model:    model,
		client:   &http.Client{Timeout: 60 * time.Second},
	}
}

func (a *Agent) Execute(userInput string) (string, error) {
	logger.Info("Starting AI agent execution").
		Str("user_input", userInput).
		Str("model", a.model).
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
	request := ChatCompletionRequest{
		Model:       a.model,
		MaxTokens:   10000,
		Temperature: 0.1,
		Messages:    messages,
		Tools:       a.tools,
		ToolChoice:  "auto",
	}

	// Marshal request to JSON
	requestBody, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Debug: Log the request being sent
	logger.Info("Sending request to LLM").
		Str("endpoint", a.endpoint).
		Str("model", request.Model).
		Int("tools_count", len(request.Tools)).
		Send()

	// Debug: Log full request (only visible with --verbose flag)
	logger.Debug("AI request").Interface("request", request).Send()

	// Execute with retry logic
	return a.executeWithRetryStructured(ctx, requestBody)
}

func (a *Agent) executeWithRetryStructured(ctx context.Context, requestBody []byte) (*ChatCompletionResponse, error) {
	const maxRetries = 3
	const baseDelay = time.Second

	var lastErr error

	for attempt := 0; attempt < maxRetries; attempt++ {
		result, err := a.executeSingleRequestStructured(ctx, requestBody)
		if err == nil {
			return result, nil
		}

		lastErr = err
		logger.Warn("Request attempt failed").Int("attempt", attempt+1).Err(err).Send()

		// Don't retry on last attempt
		if attempt == maxRetries-1 {
			break
		}

		// Check if we should retry based on error type
		if !a.shouldRetry(err) {
			break
		}

		// Wait before retrying with exponential backoff
		if err := a.waitForRetry(ctx, attempt, baseDelay); err != nil {
			return nil, err
		}
	}

	return nil, fmt.Errorf("request failed after %d attempts: %w", maxRetries, lastErr)
}

func (a *Agent) executeSingleRequestStructured(ctx context.Context, requestBody []byte) (*ChatCompletionResponse, error) {
	// Create HTTP request
	httpReq, err := http.NewRequestWithContext(ctx, "POST", a.endpoint, bytes.NewBuffer(requestBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+a.apiKey)

	// Make the request
	httpResp, err := a.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer httpResp.Body.Close()

	// Check status code
	if httpResp.StatusCode != http.StatusOK {
		// Read response body for better error information
		var responseBody []byte
		if httpResp.Body != nil {
			responseBody, _ = io.ReadAll(httpResp.Body)
		}
		logger.Error("API request failed").
			Int("status_code", httpResp.StatusCode).
			Str("response_body", string(responseBody)).
			Str("endpoint", a.endpoint).
			Send()
		return nil, fmt.Errorf("API request failed with status %d: %s", httpResp.StatusCode, string(responseBody))
	}

	// Parse response
	var response ChatCompletionResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	if len(response.Choices) == 0 {
		return nil, fmt.Errorf("no choices in response")
	}

	return &response, nil
}

func (a *Agent) shouldRetry(err error) bool {
	errStr := err.Error()

	// Retry on network errors
	if strings.Contains(errStr, "HTTP request failed") {
		return true
	}

	// Retry on server errors (5xx), but not client errors (4xx)
	if strings.Contains(errStr, "API request failed with status") {
		// Extract status code from error message
		if strings.Contains(errStr, "status 5") {
			return true
		}
		return false
	}

	// Retry on decode errors (could be temporary network issues)
	if strings.Contains(errStr, "failed to decode response") {
		return true
	}

	return false
}

func (a *Agent) waitForRetry(ctx context.Context, attempt int, baseDelay time.Duration) error {
	delay := time.Duration(1<<uint(attempt)) * baseDelay

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(delay):
		return nil
	}
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
		Str("model", a.model).
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

				// Send tool pending event
				if err := ws.SendToolPending(toolCall.Function.Name, argsForPreview); err != nil {
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

			// Add tool result to conversation
			messages = append(messages, ChatCompletionMessage{
				Role:       "tool",
				Content:    toolResult,
				ToolCallID: toolCall.ID,
			})

			logger.Info("Tool executed successfully").Str("tool", toolCall.Function.Name).Str("result", toolResult).Send()
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
	a.model = model
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

	return result
}
