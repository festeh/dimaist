package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/dima-b/go-task-backend/logger"
)

type Tool struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	Parameters  map[string]interface{} `json:"parameters"`
	Function    func(args map[string]interface{}) (string, error)
}

type Agent struct {
	apiKey        string
	endpoint      string
	context       string
	tools         []Tool
	initialPrompt string
	model         string
	client        *http.Client
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ToolCall struct {
	Name      string                 `json:"name"`
	Arguments map[string]interface{} `json:"arguments"`
}

// OpenAI-compatible API structures
type ChatCompletionRequest struct {
	Model       string                   `json:"model"`
	Messages    []ChatCompletionMessage  `json:"messages"`
	MaxTokens   int                      `json:"max_tokens,omitempty"`
	Temperature float64                  `json:"temperature,omitempty"`
}

type ChatCompletionMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatCompletionResponse struct {
	Choices []ChatCompletionChoice `json:"choices"`
}

type ChatCompletionChoice struct {
	Message ChatCompletionMessage `json:"message"`
}

func NewAgent(apiKey, endpoint, context, initialPrompt string, tools []Tool) *Agent {
	return &Agent{
		apiKey:        apiKey,
		endpoint:      endpoint,
		context:       context,
		tools:         tools,
		initialPrompt: initialPrompt,
		model:         "google/gemini-2.0-flash-001",
		client:        &http.Client{Timeout: 60 * time.Second},
	}
}

// ExecuteWithSSE runs the agent with SSE streaming support
func (a *Agent) ExecuteWithSSE(userInput string, sseWriter SSEWriter, ctx context.Context) (string, error) {
	logger.Info("Starting AI agent execution with SSE").
		Str("user_input", userInput).
		Str("model", a.model).
		Send()

	messages := []Message{
		{
			Role:    "system",
			Content: a.buildSystemPrompt(),
		},
		{
			Role:    "user",
			Content: userInput,
		},
	}

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

		// Call model with timeout
		response, err := a.callModelWithTimeout(ctx, messages)
		if err != nil {
			logger.Error("Model call failed").Err(err).Send()
			if err := sseWriter.Send("error", map[string]string{
				"error": fmt.Sprintf("AI call failed: %v", err),
			}); err != nil {
				logger.Error("Failed to send error event").Err(err).Send()
			}
			return "", fmt.Errorf("model call failed: %w", err)
		}

		logger.Info("Model response received").Str("response", response).Send()

		toolCall, hasToolCall := a.parseToolCall(response)
		if !hasToolCall {
			logger.Warn("No tool call found, prompting AI to use tools").Send()
			
			messages = append(messages, Message{
				Role:    "assistant",
				Content: response,
			})
			messages = append(messages, Message{
				Role:    "user",
				Content: "You must call a tool. If you want to respond to the user, use the 'respond' tool with your message.",
			})
			continue
		}

		logger.Info("Tool call detected").Str("tool", toolCall.Name).Send()

		// Send tool call event
		if err := sseWriter.Send("tool_call", map[string]interface{}{
			"tool":      toolCall.Name,
			"arguments": toolCall.Arguments,
		}); err != nil {
			logger.Error("Failed to send tool_call event").Err(err).Send()
			return "", err
		}

		// Check for respond tool (final response)
		if toolCall.Name == "respond" {
			if text, ok := toolCall.Arguments["text"].(string); ok {
				if err := sseWriter.Send("final_response", map[string]string{
					"response": text,
				}); err != nil {
					logger.Error("Failed to send final_response event").Err(err).Send()
					return "", err
				}
				logger.Info("Agent execution completed with respond tool").Send()
				return text, nil
			} else {
				if err := sseWriter.Send("final_response", map[string]string{
					"response": "Invalid response format",
				}); err != nil {
					logger.Error("Failed to send final_response event").Err(err).Send()
				}
				return "Invalid response format", nil
			}
		}

		toolResult, err := a.executeTool(toolCall)
		if err != nil {
			logger.Error("Tool execution failed").Str("tool", toolCall.Name).Err(err).Send()
			
			// Send error event
			if err := sseWriter.Send("error", map[string]string{
				"error": fmt.Sprintf("Tool execution failed: %v", err),
			}); err != nil {
				logger.Error("Failed to send error event").Err(err).Send()
				return "", err
			}

			// Add error to conversation for recovery
			messages = append(messages, Message{
				Role:    "assistant",
				Content: response,
			})
			messages = append(messages, Message{
				Role:    "user",
				Content: fmt.Sprintf("Tool execution failed with error: %v. Please try a different approach.", err),
			})
			continue
		}

		// Send tool result event
		if err := sseWriter.Send("tool_result", map[string]string{
			"result": toolResult,
		}); err != nil {
			logger.Error("Failed to send tool_result event").Err(err).Send()
			return "", err
		}

		messages = append(messages, Message{
			Role:    "assistant",
			Content: response,
		})

		messages = append(messages, Message{
			Role:    "user",
			Content: fmt.Sprintf("Tool result: %s", toolResult),
		})

		logger.Info("Tool executed successfully").Str("tool", toolCall.Name).Str("result", toolResult).Send()
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

	messages := []Message{
		{
			Role:    "system",
			Content: a.buildSystemPrompt(),
		},
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

		logger.Info("Model response received").Str("response", response).Send()

		toolCall, hasToolCall := a.parseToolCall(response)
		if !hasToolCall {
			logger.Info("No tool call found, returning response").Send()
			return response, nil
		}

		logger.Info("Tool call detected").Str("tool", toolCall.Name).Send()

		toolResult, err := a.executeTool(toolCall)
		if err != nil {
			logger.Error("Tool execution failed").Str("tool", toolCall.Name).Err(err).Send()
			return "", fmt.Errorf("tool execution failed: %w", err)
		}

		messages = append(messages, Message{
			Role:    "assistant",
			Content: response,
		})

		messages = append(messages, Message{
			Role:    "user",
			Content: fmt.Sprintf("Tool result: %s", toolResult),
		})

		logger.Info("Tool executed successfully").Str("tool", toolCall.Name).Str("result", toolResult).Send()
	}

	return "", fmt.Errorf("maximum iterations reached without final response")
}

func (a *Agent) buildSystemPrompt() string {
	var toolsDesc strings.Builder
	toolsDesc.WriteString("Available tools:\n")

	for _, tool := range a.tools {
		toolsDesc.WriteString(fmt.Sprintf("- %s: %s\n", tool.Name, tool.Description))
	}

	toolsDesc.WriteString("\nTo use a tool, respond with: TOOL_CALL: {\"name\": \"tool_name\", \"arguments\": {\"arg1\": \"value1\"}}\n")

	return fmt.Sprintf(`%s

Context: %s

%s

Instructions:
- Use the available tools to complete tasks
- Always respond with either a tool call or a final answer
- If you need to use a tool, format your response as specified above
- Provide clear and helpful responses`, a.initialPrompt, a.context, toolsDesc.String())
}

func (a *Agent) callModel(messages []Message) (string, error) {
	return a.callModelWithTimeout(context.Background(), messages)
}

func (a *Agent) callModelWithTimeout(ctx context.Context, messages []Message) (string, error) {
	// Strip "chutes/" prefix from model name
	model := a.model
	if strings.HasPrefix(model, "chutes/") {
		model = strings.TrimPrefix(model, "chutes/")
	}

	request := ChatCompletionRequest{
		Model:       model,
		MaxTokens:   10000,
		Temperature: 0.1,
	}

	for _, msg := range messages {
		request.Messages = append(request.Messages, ChatCompletionMessage{
			Role:    msg.Role,
			Content: msg.Content,
		})
	}

	// Marshal request to JSON
	requestBody, err := json.Marshal(request)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	// Create HTTP request
	httpReq, err := http.NewRequestWithContext(ctx, "POST", a.endpoint, bytes.NewBuffer(requestBody))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+a.apiKey)

	// Make the request
	httpResp, err := a.client.Do(httpReq)
	if err != nil {
		return "", fmt.Errorf("HTTP request failed: %w", err)
	}
	defer httpResp.Body.Close()

	// Check status code
	if httpResp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API request failed with status %d", httpResp.StatusCode)
	}

	// Parse response
	var response ChatCompletionResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&response); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	if len(response.Choices) == 0 {
		return "", fmt.Errorf("no choices in response")
	}

	return response.Choices[0].Message.Content, nil
}

func (a *Agent) parseToolCall(response string) (ToolCall, bool) {
	const toolCallPrefix = "TOOL_CALL: "

	if !strings.Contains(response, toolCallPrefix) {
		return ToolCall{}, false
	}

	start := strings.Index(response, toolCallPrefix)
	if start == -1 {
		return ToolCall{}, false
	}

	jsonStr := response[start+len(toolCallPrefix):]

	lines := strings.Split(jsonStr, "\n")
	if len(lines) > 0 {
		jsonStr = lines[0]
	}

	var toolCall ToolCall
	if err := json.Unmarshal([]byte(jsonStr), &toolCall); err != nil {
		logger.Error("Failed to parse tool call").Str("json", jsonStr).Err(err).Send()
		return ToolCall{}, false
	}

	return toolCall, true
}

func (a *Agent) executeTool(toolCall ToolCall) (string, error) {
	for _, tool := range a.tools {
		if tool.Name == toolCall.Name {
			return tool.Function(toolCall.Arguments)
		}
	}

	return "", fmt.Errorf("tool not found: %s", toolCall.Name)
}

func (a *Agent) AddTool(tool Tool) {
	a.tools = append(a.tools, tool)
}

func (a *Agent) SetModel(model string) {
	a.model = model
}

func (a *Agent) SetContext(context string) {
	a.context = context
}
