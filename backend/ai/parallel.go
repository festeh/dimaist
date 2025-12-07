package ai

import (
	"encoding/json"
	"sync"
	"time"

	"dimaist/logger"

	"github.com/festeh/general"
)

// ParallelResult stores the result from one model in parallel mode
type ParallelResult struct {
	TargetID  string
	Response  *general.ChatCompletionResponse
	Error     error
	Duration  time.Duration
	ToolCalls []PendingToolCall
}

// HandleParallelAI runs multiple AI models in parallel and streams results
func HandleParallelAI(ws *WSWriter, messages []ChatCompletionMessage, targets []TargetSpec, includeCompleted bool) {
	logger.Info("Starting parallel AI execution").
		Int("targets", len(targets)).
		Int("messages", len(messages)).
		Send()

	// Send initial thinking event
	if err := ws.SendThinking("Loading task context...", 0); err != nil {
		logger.Error("Failed to send thinking event").Err(err).Send()
		return
	}

	// Load context once (shared across all models)
	contextStartTime := time.Now()
	tasks, err := LoadRecentTasks(1000, includeCompleted)
	if err != nil {
		logger.Error("Failed to load tasks").Err(err).Send()
		ws.SendError("Failed to load tasks: " + err.Error())
		return
	}

	projects, err := LoadRecentProjects(100)
	if err != nil {
		logger.Error("Failed to load projects").Err(err).Send()
		ws.SendError("Failed to load projects: " + err.Error())
		return
	}
	contextDuration := time.Since(contextStartTime).Seconds()

	// Build system prompt
	systemPrompt, err := BuildSystemPrompt(tasks, projects)
	if err != nil {
		logger.Error("Failed to build system prompt").Err(err).Send()
		ws.SendError("Failed to build system prompt: " + err.Error())
		return
	}

	// Prepend system message
	messagesWithSystem := []ChatCompletionMessage{
		{Role: "system", Content: systemPrompt},
	}
	messagesWithSystem = append(messagesWithSystem, messages...)

	// Send thinking event with context loading duration
	if err := ws.SendThinking("Context loaded, querying AI models...", contextDuration); err != nil {
		logger.Error("Failed to send thinking event").Err(err).Send()
		return
	}

	// Execute parallel requests and wait for all results
	results := executeParallelRequests(targets, messagesWithSystem)

	// Track success/failure
	var successfulTargets []string
	var failedTargets []string
	responsesByTarget := make(map[string]*ParallelResult)

	// Process results as they arrive (already collected, now stream to client)
	for _, result := range results {
		responsesByTarget[result.TargetID] = result

		if result.Error != nil {
			failedTargets = append(failedTargets, result.TargetID)
			ws.SendModelError(result.TargetID, result.Error.Error(), result.Duration.Seconds())
			logger.Info("Model failed").Str("target", result.TargetID).Err(result.Error).Send()
		} else {
			successfulTargets = append(successfulTargets, result.TargetID)

			// Check if model wants tools
			if len(result.ToolCalls) > 0 {
				ws.SendToolsPendingForModel(result.TargetID, result.ToolCalls, result.Duration.Seconds())
				logger.Info("Model requested tools").Str("target", result.TargetID).Int("tools", len(result.ToolCalls)).Send()
			} else {
				responseText := ""
				if result.Response != nil && len(result.Response.Choices) > 0 {
					responseText = result.Response.Choices[0].Message.Content
				}
				ws.SendModelResponse(result.TargetID, responseText, result.Duration.Seconds())
				logger.Info("Model responded").Str("target", result.TargetID).Send()
			}
		}
	}

	// Signal all models complete
	ws.SendAllComplete(successfulTargets, failedTargets)

	// Wait for user action
	handleParallelUserActions(ws, responsesByTarget, messagesWithSystem, targets, includeCompleted)
}

// executeParallelRequests runs requests to all targets in parallel
func executeParallelRequests(targets []TargetSpec, messages []ChatCompletionMessage) []*ParallelResult {
	// Convert to general.ChatCompletionMessage
	generalMessages := make([]general.ChatCompletionMessage, len(messages))
	for i, m := range messages {
		generalMessages[i] = general.ChatCompletionMessage{
			Role:       m.Role,
			Content:    m.Content,
			ToolCallID: m.ToolCallID,
		}
		// Copy tool calls if present
		if len(m.ToolCalls) > 0 {
			generalMessages[i].ToolCalls = m.ToolCalls
		}
	}

	// Build general.Target slice
	generalTargets := make([]general.Target, len(targets))
	for i, t := range targets {
		provider := getProvider(t.Provider)
		generalTargets[i] = general.Target{
			Provider: provider,
			Model:    t.Model,
		}
	}

	// Create command with all targets
	cmd := general.NewCommandWithTimeout(generalTargets, nil, 2*time.Minute)

	// Build request
	tools := GetToolDefinitions()
	request := general.ChatCompletionRequest{
		MaxTokens:   10000,
		Temperature: 0.1,
		Messages:    generalMessages,
		Tools:       tools,
		ToolChoice:  "auto",
	}

	// Execute parallel requests
	resultsChan := cmd.Execute(request)

	// Collect all results
	var results []*ParallelResult
	var mu sync.Mutex

	for result := range resultsChan {
		targetID := targets[findTargetIndex(generalTargets, result.Target)].ID()

		parallelResult := &ParallelResult{
			TargetID: targetID,
			Duration: result.Duration,
		}

		if result.Error != nil {
			parallelResult.Error = result.Error
		} else {
			parallelResult.Response = &result.Response

			// Extract tool calls if present
			if len(result.Response.Choices) > 0 {
				toolCalls := result.Response.Choices[0].Message.ToolCalls
				if len(toolCalls) > 0 {
					pendingTools := make([]PendingToolCall, 0, len(toolCalls))
					for _, tc := range toolCalls {
						// Parse arguments
						var args map[string]any
						if err := json.Unmarshal([]byte(tc.Function.Arguments), &args); err != nil {
							logger.Error("Failed to parse tool arguments").Str("tool", tc.Function.Name).Err(err).Send()
							continue
						}

						// Skip respond tool - treat as regular response
						if tc.Function.Name == "respond" {
							continue
						}

						// Resolve defaults for preview
						argsForPreview := resolveToolDefaults(tc.Function.Name, args)

						pendingTools = append(pendingTools, PendingToolCall{
							ToolCallID: tc.ID,
							Name:       tc.Function.Name,
							Arguments:  argsForPreview,
						})
					}

					// If only respond tool was called, extract the response text
					if len(pendingTools) == 0 && len(toolCalls) > 0 {
						for _, tc := range toolCalls {
							if tc.Function.Name == "respond" {
								var args map[string]any
								if err := json.Unmarshal([]byte(tc.Function.Arguments), &args); err == nil {
									if text, ok := args["text"].(string); ok {
										parallelResult.Response.Choices[0].Message.Content = text
									}
								}
								break
							}
						}
					} else {
						parallelResult.ToolCalls = pendingTools
					}
				}
			}
		}

		mu.Lock()
		results = append(results, parallelResult)
		mu.Unlock()
	}

	return results
}

// findTargetIndex finds the index of a target in the slice
func findTargetIndex(targets []general.Target, target general.Target) int {
	for i, t := range targets {
		if t.Provider.Endpoint == target.Provider.Endpoint && t.Model == target.Model {
			return i
		}
	}
	return 0
}

// getProvider returns the provider configuration for a given provider name
func getProvider(providerName string) general.Provider {
	switch providerName {
	case "chutes":
		return general.Provider{
			Endpoint: appEnv.ChutesEndpoint,
			APIKey:   appEnv.ChutesToken,
		}
	case "google":
		return general.Provider{
			Endpoint: appEnv.GoogleAIEndpoint,
			APIKey:   appEnv.GoogleAIToken,
		}
	case "groq":
		return general.Provider{
			Endpoint: appEnv.GroqEndpoint,
			APIKey:   appEnv.GroqToken,
		}
	default: // openrouter
		return general.Provider{
			Endpoint: appEnv.OpenrouterEndpoint,
			APIKey:   appEnv.OpenrouterToken,
		}
	}
}

// handleParallelUserActions waits for user to either select a model or send a new message
func handleParallelUserActions(ws *WSWriter, responsesByTarget map[string]*ParallelResult,
	messagesWithSystem []ChatCompletionMessage, targets []TargetSpec, includeCompleted bool) {

	for {
		msg, err := ws.WaitForNextMessage()
		if err != nil {
			logger.Error("Failed to wait for user message").Err(err).Send()
			return
		}

		switch msg.Type {
		case WSMsgSelectModel:
			// User engaged with tools from this model - switch to single model mode
			logger.Info("User selected model").Str("target", msg.TargetID).Send()
			handleModelSelection(ws, msg.TargetID, responsesByTarget, messagesWithSystem, includeCompleted)
			return

		case WSMsgBatchConfirm:
			// User confirmed tools from a specific model
			logger.Info("User confirmed tools for model").Str("target", msg.TargetID).Send()
			handleToolConfirmationParallel(ws, msg.TargetID, msg.Statuses, msg.NewMessage,
				responsesByTarget, messagesWithSystem, targets, includeCompleted)
			return

		case WSMsgStart:
			// User sent a new message - restart parallel mode with all models
			logger.Info("User sent new message, restarting parallel mode").Send()
			newUserMessage := ChatCompletionMessage{Role: "user", Content: ""}
			if len(msg.Messages) > 0 {
				newUserMessage = msg.Messages[len(msg.Messages)-1]
			}
			messagesWithSystem = append(messagesWithSystem, newUserMessage)
			HandleParallelAI(ws, messagesWithSystem[1:], targets, includeCompleted) // Skip system message, it will be rebuilt
			return

		default:
			logger.Warn("Unexpected message type in parallel mode").Str("type", string(msg.Type)).Send()
		}
	}
}

// handleModelSelection switches from parallel to single model mode
func handleModelSelection(ws *WSWriter, targetID string, responsesByTarget map[string]*ParallelResult,
	messages []ChatCompletionMessage, includeCompleted bool) {

	result, ok := responsesByTarget[targetID]
	if !ok {
		ws.SendError("Unknown target: " + targetID)
		return
	}

	// Extract provider and model from targetID (format: "provider:model")
	provider, model := parseTargetID(targetID)

	// If the model had tool calls, we need to continue with tool confirmation flow
	if len(result.ToolCalls) > 0 {
		// The tools are already sent to client, just wait for confirmation
		// This is handled by the existing batch confirmation flow
		return
	}

	// Otherwise, just continue in single model mode
	HandleAIWithWS(ws, messages[1:], provider, model, includeCompleted) // Skip system message
}

// handleToolConfirmationParallel handles tool confirmation and continues with single model
func handleToolConfirmationParallel(ws *WSWriter, targetID string, statuses []ToolStatus, newMessage string,
	responsesByTarget map[string]*ParallelResult, messages []ChatCompletionMessage,
	targets []TargetSpec, includeCompleted bool) {

	result, ok := responsesByTarget[targetID]
	if !ok {
		ws.SendError("Unknown target: " + targetID)
		return
	}

	provider, model := parseTargetID(targetID)

	// Create agent for tool execution
	agent := createAIAgent(provider, model)

	// Add the assistant message with tool calls to conversation
	assistantMsg := ChatCompletionMessage{
		Role:      "assistant",
		ToolCalls: convertToToolCalls(result.ToolCalls, result.Response),
	}
	messages = append(messages, assistantMsg)

	// Process each tool based on status
	for _, status := range statuses {
		// Find the tool call
		var toolCall *PendingToolCall
		for _, tc := range result.ToolCalls {
			if tc.ToolCallID == status.ToolCallID {
				toolCall = &tc
				break
			}
		}
		if toolCall == nil {
			continue
		}

		if status.Status == "confirmed" {
			// Use modified args if provided
			args := toolCall.Arguments
			if status.Arguments != nil {
				args = status.Arguments
			}

			// Execute the tool
			toolStartTime := time.Now()
			toolResult, err := agent.executeToolWithArgs(toolCall.Name, args)
			toolDuration := time.Since(toolStartTime).Seconds()

			if err != nil {
				logger.Error("Tool execution failed").Str("tool", toolCall.Name).Err(err).Send()
				messages = append(messages, ChatCompletionMessage{
					Role:       "tool",
					Content:    "Error: " + err.Error(),
					ToolCallID: status.ToolCallID,
				})
				continue
			}

			ws.SendToolResult(toolResult, toolDuration)
			messages = append(messages, ChatCompletionMessage{
				Role:       "tool",
				Content:    toolResult,
				ToolCallID: status.ToolCallID,
			})
		} else {
			// Rejected
			messages = append(messages, ChatCompletionMessage{
				Role:       "tool",
				Content:    "User rejected this action",
				ToolCallID: status.ToolCallID,
			})
		}
	}

	// Add new message if provided
	if newMessage != "" {
		messages = append(messages, ChatCompletionMessage{
			Role:    "user",
			Content: newMessage,
		})
	}

	// Continue with single model mode
	HandleAIWithWS(ws, messages[1:], provider, model, includeCompleted) // Skip system message
}

// parseTargetID extracts provider and model from "provider:model" format
func parseTargetID(targetID string) (provider, model string) {
	for i := 0; i < len(targetID); i++ {
		if targetID[i] == ':' {
			return targetID[:i], targetID[i+1:]
		}
	}
	return "", targetID
}

// convertToToolCalls converts PendingToolCall slice to general.ToolCall slice
func convertToToolCalls(pending []PendingToolCall, response *general.ChatCompletionResponse) []general.ToolCall {
	if response != nil && len(response.Choices) > 0 {
		return response.Choices[0].Message.ToolCalls
	}
	return nil
}
