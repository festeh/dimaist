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

	"github.com/dima-b/go-task-backend/logger"
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

// ExecuteWithMessagesAndSSE runs the agent with pre-built messages and SSE streaming support
func (a *Agent) ExecuteWithMessagesAndSSE(messages []ChatCompletionMessage, sseWriter SSEWriter, ctx context.Context) (string, error) {
	logger.Info("Starting AI agent execution with messages and SSE").
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
			return "", ctx.Err()
		default:
		}

		// Send thinking event
		if err := sseWriter.Send("thinking", map[string]string{
			"message": fmt.Sprintf("Processing request (iteration %d/%d)...", i+1, maxIterations),
		}); err != nil {
			logger.Error("Failed to send thinking event").Err(err).Send()
			return "", err
		}

		// Call model with timeout and track timing
		modelStartTime := time.Now()
		response, err := a.callModelWithTimeout(ctx, messages)
		modelDuration := time.Since(modelStartTime).Seconds()
		
		if err != nil {
			logger.Error("Model call failed").Err(err).Send()
			if err := sseWriter.Send("error", map[string]any{
				"error": fmt.Sprintf("AI call failed: %v", err),
				"duration": modelDuration,
			}); err != nil {
				logger.Error("Failed to send error event").Err(err).Send()
			}
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
			// No tool calls, return the response content
			logger.Info("No tool calls found, returning response").Send()
			responseText := response.Choices[0].Message.Content
			if err := sseWriter.Send("final_response", map[string]any{
				"response": responseText,
				"duration": modelDuration,
			}); err != nil {
				logger.Error("Failed to send final_response event").Err(err).Send()
				return "", err
			}
			return responseText, nil
		}

		// Process tool calls
		messages = append(messages, response.Choices[0].Message)

		for _, toolCall := range response.Choices[0].Message.ToolCalls {
			logger.Info("Tool call detected").Str("tool", toolCall.Function.Name).Send()

			// Check for respond tool (final response)
			if toolCall.Function.Name == "respond" {
				var args map[string]any
				if err := json.Unmarshal([]byte(toolCall.Function.Arguments), &args); err == nil {
					if text, ok := args["text"].(string); ok {
						if err := sseWriter.Send("final_response", map[string]any{
							"response": text,
							"duration": modelDuration,
						}); err != nil {
							logger.Error("Failed to send final_response event").Err(err).Send()
							return "", err
						}
						logger.Info("Agent execution completed with respond tool").Send()
						return text, nil
					}
				}
				if err := sseWriter.Send("final_response", map[string]any{
					"response": "Invalid response format",
					"duration": modelDuration,
				}); err != nil {
					logger.Error("Failed to send final_response event").Err(err).Send()
				}
				return "Invalid response format", nil
			}

			// Send tool call event with model duration (how long it took to decide to call the tool)
			if err := sseWriter.Send("tool_call", map[string]any{
				"tool":      toolCall.Function.Name,
				"arguments": toolCall.Function.Arguments,
				"duration":  modelDuration,
			}); err != nil {
				logger.Error("Failed to send tool_call event").Err(err).Send()
				return "", err
			}

			toolStartTime := time.Now()
			toolResult, err := a.executeTool(toolCall)
			toolDuration := time.Since(toolStartTime).Seconds()
			
			if err != nil {
				logger.Error("Tool execution failed").Str("tool", toolCall.Function.Name).Err(err).Send()

				// Send error event with timing
				if err := sseWriter.Send("error", map[string]any{
					"error": fmt.Sprintf("Tool execution failed: %v", err),
					"duration": toolDuration,
				}); err != nil {
					logger.Error("Failed to send error event").Err(err).Send()
					return "", err
				}

				// Add error to conversation for recovery
				messages = append(messages, ChatCompletionMessage{
					Role:       "tool",
					Content:    fmt.Sprintf("Error: %v", err),
					ToolCallID: toolCall.ID,
				})
				continue
			}

			// Send tool result event without duration
			if err := sseWriter.Send("tool_result", map[string]any{
				"result": toolResult,
			}); err != nil {
				logger.Error("Failed to send tool_result event").Err(err).Send()
				return "", err
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
	if err := sseWriter.Send("error", map[string]string{
		"error": "Maximum iterations reached without final response",
	}); err != nil {
		logger.Error("Failed to send error event").Err(err).Send()
	}
	return "", fmt.Errorf("maximum iterations reached without final response")
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
			logger.Info("Tool call detected").Str("tool", toolCall.Function.Name).Send()

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
		ToolChoice:  "required",
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
