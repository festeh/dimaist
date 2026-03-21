package ai

import (
	"encoding/json"
	"errors"
	"time"

	"dimaist/logger"

	"github.com/festeh/general"
)

var ErrConnectionClosed = errors.New("websocket connection closed")

// ParallelResult stores the result from one model
type ParallelResult struct {
	TargetID  string
	Response  *general.ChatCompletionResponse
	Error     error
	Duration  time.Duration
	ToolCalls []PendingToolCall
}

// HandleAI handles one AI turn - sends to all targets, streams responses, handles tools
// Returns error if session should end (connection closed or fatal error)
func HandleAI(s *Session) error {
	s.TurnID++
	logger.Info("HandleAI starting").
		Int("turn", s.TurnID).
		Int("targets", len(s.Targets)).
		Int("messages", len(s.Messages)).
		Send()

	// Load context
	if err := s.WS.SendThinking("Loading task context...", 0); err != nil {
		logger.Error("Failed to send thinking").Err(err).Send()
		return err
	}

	contextStart := time.Now()
	tasks, err := LoadRecentTasks(1000, s.IncludeCompleted)
	if err != nil {
		logger.Error("Failed to load tasks").Err(err).Send()
		s.WS.SendError("Failed to load tasks: " + err.Error())
		return err
	}

	projects, err := LoadRecentProjects(100)
	if err != nil {
		logger.Error("Failed to load projects").Err(err).Send()
		s.WS.SendError("Failed to load projects: " + err.Error())
		return err
	}

	systemPrompt, err := BuildSystemPrompt(tasks, projects, &PromptContext{
		CurrentProjectID: s.CurrentProjectID,
		CurrentView:      s.CurrentView,
	})
	if err != nil {
		logger.Error("Failed to build system prompt").Err(err).Send()
		s.WS.SendError("Failed to build system prompt: " + err.Error())
		return err
	}
	contextDuration := time.Since(contextStart).Seconds()

	// Build messages with system prompt
	messagesWithSystem := append(
		[]ChatCompletionMessage{{Role: "system", Content: general.TextContent(systemPrompt)}},
		s.Messages...,
	)

	// Log conversation history (excluding system prompt)
	logger.Debug("Conversation history").Int("messages", len(s.Messages)).Send()
	for i, msg := range s.Messages {
		preview := msg.Content.String()
		if len(preview) > 200 {
			preview = preview[:200] + "..."
		}
		if len(msg.ToolCalls) > 0 {
			logger.Debug("Message").Int("idx", i).Str("role", msg.Role).Int("tool_calls", len(msg.ToolCalls)).Send()
		} else {
			logger.Debug("Message").Int("idx", i).Str("role", msg.Role).Str("content", preview).Send()
		}
	}

	if err := s.WS.SendThinking("Querying AI models...", contextDuration); err != nil {
		logger.Error("Failed to send thinking").Err(err).Send()
		return err
	}

	// Send to all targets and stream responses
	resultsChan := streamRequests(s.Targets, messagesWithSystem)

	var successfulTargets, failedTargets []string
	responsesByTarget := make(map[string]*ParallelResult)
	allDone := false

	// Use select to listen for both model results and user messages concurrently
	for !allDone {
		select {
		case result, ok := <-resultsChan:
			if !ok {
				// All models done
				allDone = true
				break
			}

			responsesByTarget[result.TargetID] = result

			if result.Error != nil {
				failedTargets = append(failedTargets, result.TargetID)
				logger.Info("Model error").Str("target", result.TargetID).Err(result.Error).Send()
				s.WS.SendModelError(result.TargetID, result.Error.Error(), result.Duration.Seconds(), s.TurnID)
			} else {
				successfulTargets = append(successfulTargets, result.TargetID)

				if len(result.ToolCalls) > 0 {
					logger.Info("Model tools pending").Str("target", result.TargetID).Int("tools", len(result.ToolCalls)).Send()
					s.WS.SendToolsPendingForModel(result.TargetID, result.ToolCalls, result.Duration.Seconds(), s.TurnID)
				} else {
					responseText := ""
					if result.Response != nil && len(result.Response.Choices) > 0 {
						responseText = result.Response.Choices[0].Message.Content.String()
					}
					logger.Info("Model response").Str("target", result.TargetID).Send()
					s.WS.SendModelResponse(result.TargetID, responseText, result.Duration.Seconds(), s.TurnID)
				}
			}

		case msg := <-s.WS.MsgChan():
			// User sent a message while models are still responding
			if msg == nil {
				// Channel closed (connection error)
				logger.Error("WS channel closed during model responses").Send()
				return ErrConnectionClosed
			}

			logger.Info("User message during model responses").Str("type", string(msg.Type)).Send()

			switch msg.Type {
			case WSMsgContinue:
				logger.Info("Continue during responses").Str("newMessage", msg.NewMessage).Int("responsesReceived", len(responsesByTarget)).Send()
				addModelResponseToSession(s, responsesByTarget, msg)
				return nil

			case WSMsgToolConfirm:
				// User confirmed a tool - handle it
				logger.Info("Tool confirm during responses").Str("target", msg.TargetID).Str("tool", msg.ToolCallID).Send()
				s.SelectedModel = msg.TargetID
				handleToolConfirm(s, responsesByTarget, messagesWithSystem, msg.TargetID, msg.ToolCallID, msg.Arguments)
				return nil

			case WSMsgSelectModel:
				// User selected a model
				logger.Info("Model selected during responses").Str("target", msg.TargetID).Send()
				s.SelectedModel = msg.TargetID
				handleModelSelection(s, responsesByTarget, msg.TargetID)
				return nil

			default:
				logger.Warn("Unexpected message type during responses").Str("type", string(msg.Type)).Send()
			}

		case err := <-s.WS.ErrChan():
			logger.Error("WS read error during model responses").Err(err).Send()
			return ErrConnectionClosed
		}
	}

	logger.Info("All models complete").Int("successful", len(successfulTargets)).Int("failed", len(failedTargets)).Send()
	s.WS.SendAllComplete(successfulTargets, failedTargets, s.TurnID)

	// Wait for user action (all models done, now use channel-based waiting)
	handleUserAction(s, responsesByTarget, messagesWithSystem)
	return nil
}

// addModelResponseToSession picks a model if none selected, adds its response to session messages,
// and optionally appends a user message. Tool calls are added as rejected.
func addModelResponseToSession(s *Session, results map[string]*ParallelResult, msg *WSMessage) {
	// Pick first successful model if none selected
	if s.SelectedModel == "" {
		for id, r := range results {
			if r.Error == nil {
				s.SelectedModel = id
				break
			}
		}
	}

	// Add selected model's response to session
	if result, ok := results[s.SelectedModel]; ok {
		if len(result.ToolCalls) > 0 {
			s.Messages = append(s.Messages, ChatCompletionMessage{
				Role:      "assistant",
				ToolCalls: getToolCalls(result.Response),
			})
			for _, tc := range result.ToolCalls {
				s.Messages = append(s.Messages, ChatCompletionMessage{
					Role:       "tool",
					Content:    general.TextContent("User rejected this action"),
					ToolCallID: tc.ToolCallID,
				})
			}
		} else if result.Response != nil && len(result.Response.Choices) > 0 {
			text := result.Response.Choices[0].Message.Content.String()
			if text != "" {
				s.Messages = append(s.Messages, ChatCompletionMessage{
					Role:    "assistant",
					Content: general.TextContent(text),
				})
			}
		}
	}

	// Add user's new message to session
	if msg != nil && msg.NewMessage != "" {
		s.Messages = append(s.Messages, ChatCompletionMessage{
			Role:    "user",
			Content: buildUserContent(msg.NewMessage, msg.Images),
		})
	}
}

// handleUserAction waits for user to confirm tools or select a model
func handleUserAction(s *Session, results map[string]*ParallelResult, messagesWithSystem []ChatCompletionMessage) {
	for {
		select {
		case msg := <-s.WS.MsgChan():
			if msg == nil {
				logger.Error("WS channel closed during action wait").Send()
				return
			}

			switch msg.Type {
			case WSMsgToolConfirm:
				logger.Info("Tool confirm").Str("target", msg.TargetID).Str("tool", msg.ToolCallID).Send()
				s.SelectedModel = msg.TargetID
				handleToolConfirm(s, results, messagesWithSystem, msg.TargetID, msg.ToolCallID, msg.Arguments)
				return

			case WSMsgSelectModel:
				logger.Info("Model selected").Str("target", msg.TargetID).Send()
				s.SelectedModel = msg.TargetID
				handleModelSelection(s, results, msg.TargetID)
				return

			case WSMsgContinue:
				addModelResponseToSession(s, results, msg)
				logger.Info("Continue during action wait").Str("selected", s.SelectedModel).Str("newMessage", msg.NewMessage).Send()
				return

			default:
				logger.Warn("Unexpected message type").Str("type", string(msg.Type)).Send()
			}

		case err := <-s.WS.ErrChan():
			logger.Error("WS read error during action wait").Err(err).Send()
			return
		}
	}
}

// handleToolConfirm executes confirmed tools and updates session
func handleToolConfirm(s *Session, results map[string]*ParallelResult, messagesWithSystem []ChatCompletionMessage,
	targetID, toolCallID string, modifiedArgs map[string]any) {

	result, ok := results[targetID]
	if !ok {
		s.WS.SendError("Unknown target: " + targetID)
		return
	}

	// Add assistant message with tool calls
	messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
		Role:      "assistant",
		ToolCalls: getToolCalls(result.Response),
	})

	// Track pending tools
	pending := make(map[string]*PendingToolCall)
	for i := range result.ToolCalls {
		pending[result.ToolCalls[i].ToolCallID] = &result.ToolCalls[i]
	}

	// Execute first tool
	if tc, ok := pending[toolCallID]; ok {
		args := tc.Arguments
		if modifiedArgs != nil {
			args = modifiedArgs
		}

		start := time.Now()
		toolResult, err := executeTool(tc.Name, args)
		duration := time.Since(start).Seconds()

		if err != nil {
			logger.Error("Tool failed").Str("tool", tc.Name).Err(err).Send()
			messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
				Role: "tool", Content: general.TextContent("Error: " + err.Error()), ToolCallID: toolCallID,
			})
		} else {
			s.WS.SendToolResult(toolResult, duration)
			messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
				Role: "tool", Content: general.TextContent(toolResult), ToolCallID: toolCallID,
			})
		}
		delete(pending, toolCallID)
	}

	// Wait for more tool confirmations using channel
	for len(pending) > 0 {
		select {
		case msg := <-s.WS.MsgChan():
			if msg == nil {
				logger.Error("WS channel closed during tool wait").Send()
				// Update session messages and return
				s.Messages = messagesWithSystem[1:]
				return
			}

			if msg.Type == WSMsgToolConfirm {
				tc, ok := pending[msg.ToolCallID]
				if !ok {
					continue
				}

				args := tc.Arguments
				if msg.Arguments != nil {
					args = msg.Arguments
				}

				start := time.Now()
				toolResult, err := executeTool(tc.Name, args)
				duration := time.Since(start).Seconds()

				if err != nil {
					messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
						Role: "tool", Content: general.TextContent("Error: " + err.Error()), ToolCallID: msg.ToolCallID,
					})
				} else {
					s.WS.SendToolResult(toolResult, duration)
					messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
						Role: "tool", Content: general.TextContent(toolResult), ToolCallID: msg.ToolCallID,
					})
				}
				delete(pending, msg.ToolCallID)

			} else if msg.Type == WSMsgContinue {
				// Reject remaining tools
				for tcID := range pending {
					messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
						Role: "tool", Content: general.TextContent("User rejected this action"), ToolCallID: tcID,
					})
				}
				// Add user message
				if msg.NewMessage != "" {
					messagesWithSystem = append(messagesWithSystem, ChatCompletionMessage{
						Role: "user", Content: buildUserContent(msg.NewMessage, msg.Images),
					})
				}
				// Update session and return early
				s.Messages = messagesWithSystem[1:]
				return
			}

		case err := <-s.WS.ErrChan():
			logger.Error("WS read error during tool wait").Err(err).Send()
			s.Messages = messagesWithSystem[1:]
			return
		}
	}

	// Update session messages (skip system prompt)
	s.Messages = messagesWithSystem[1:]
}

// handleModelSelection handles when user selects a model's response
func handleModelSelection(s *Session, results map[string]*ParallelResult, targetID string) {
	result, ok := results[targetID]
	if !ok {
		s.WS.SendError("Unknown target: " + targetID)
		return
	}

	// If model has pending tools, wait for tool confirmation (will be handled by next call)
	if len(result.ToolCalls) > 0 {
		return
	}

	// Add text response to session
	if result.Response != nil && len(result.Response.Choices) > 0 {
		text := result.Response.Choices[0].Message.Content.String()
		if text != "" {
			s.Messages = append(s.Messages, ChatCompletionMessage{
				Role:    "assistant",
				Content: general.TextContent(text),
			})
		}
	}
}

// streamRequests sends requests to all targets in parallel
func streamRequests(targets []TargetSpec, messages []ChatCompletionMessage) <-chan *ParallelResult {
	// Build targets - all use the single proxy provider
	provider := general.Provider{Endpoint: appEnv.AIEndpoint, APIKey: appEnv.AIToken}
	generalTargets := make([]general.Target, len(targets))
	for i, t := range targets {
		generalTargets[i] = general.Target{
			Provider: provider,
			Model:    t.Model,
		}
	}

	// Execute
	cmd := general.NewCommandWithTimeout(generalTargets, nil, 2*time.Minute)
	tools := GetToolDefinitions()
	request := general.ChatCompletionRequest{
		MaxTokens:   4000,
		Temperature: 0.1,
		Messages:    messages,
		Tools:       tools,
		ToolChoice:  "auto",
	}

	resultsChan := cmd.Execute(request)
	outChan := make(chan *ParallelResult)

	go func() {
		defer close(outChan)

		for result := range resultsChan {
			targetID := targets[findTargetIndex(generalTargets, result.Target)].ID()

			pr := &ParallelResult{
				TargetID: targetID,
				Duration: result.Duration,
			}

			if result.Error != nil {
				pr.Error = result.Error
			} else {
				pr.Response = &result.Response

				// Extract tool calls
				if len(result.Response.Choices) > 0 {
					toolCalls := result.Response.Choices[0].Message.ToolCalls
					if len(toolCalls) > 0 {
						var respondArgs map[string]any
						pending := make([]PendingToolCall, 0, len(toolCalls))
						for _, tc := range toolCalls {
							var args map[string]any
							if err := json.Unmarshal([]byte(tc.Function.Arguments), &args); err != nil {
								continue
							}

							if tc.Function.Name == "respond" {
								respondArgs = args
								continue
							}

							pending = append(pending, PendingToolCall{
								ToolCallID: tc.ID,
								Name:       tc.Function.Name,
								Arguments:  resolveToolDefaults(tc.Function.Name, args),
							})
						}

						if len(pending) > 0 {
							pr.ToolCalls = pending
						} else if respondArgs != nil {
							if text, ok := respondArgs["text"].(string); ok {
								pr.Response.Choices[0].Message.Content = general.TextContent(text)
							}
						}
					}
				}
			}

			outChan <- pr
		}
	}()

	return outChan
}

func findTargetIndex(targets []general.Target, target general.Target) int {
	for i, t := range targets {
		if t.Provider.Endpoint == target.Provider.Endpoint && t.Model == target.Model {
			return i
		}
	}
	return 0
}


func getToolCalls(response *general.ChatCompletionResponse) []general.ToolCall {
	if response != nil && len(response.Choices) > 0 {
		return response.Choices[0].Message.ToolCalls
	}
	return nil
}
