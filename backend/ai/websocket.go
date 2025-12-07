package ai

import (
	"context"
	"net/http"
	"time"

	"dimaist/logger"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// PendingToolCall represents a tool call awaiting user confirmation
type PendingToolCall struct {
	ToolCallID string         `json:"tool_call_id"`
	Name       string         `json:"name"`
	Arguments  map[string]any `json:"arguments"`
}

// WSMessage represents a WebSocket message for AI chat
type WSMessage struct {
	Type WSMessageType `json:"type"`

	// Start message fields (client → server)
	Messages         []ChatCompletionMessage `json:"messages,omitempty"`
	Provider         string                  `json:"provider,omitempty"`
	Model            string                  `json:"model,omitempty"`
	IncludeCompleted bool                    `json:"include_completed,omitempty"`

	// Tool pending fields (server → client) - single tool (legacy)
	Tool      string         `json:"tool,omitempty"`
	Arguments map[string]any `json:"arguments,omitempty"`

	// Batch tool fields (server → client)
	ToolCalls []PendingToolCall `json:"tool_calls,omitempty"`

	// Batch confirmation fields (client → server)
	Statuses   []ToolStatus `json:"statuses,omitempty"`
	NewMessage string       `json:"new_message,omitempty"`

	// Response fields (server → client)
	Message  string  `json:"message,omitempty"`
	Response string  `json:"response,omitempty"`
	Result   string  `json:"result,omitempty"`
	Error    string  `json:"error,omitempty"`
	Duration float64 `json:"duration,omitempty"`
}

// HandleWebSocket handles WebSocket connections for AI chat
func HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.Error("Failed to upgrade WebSocket").Err(err).Send()
		return
	}
	defer conn.Close()

	// Read start message
	var startMsg WSMessage
	if err := conn.ReadJSON(&startMsg); err != nil {
		logger.Error("Failed to read start message").Err(err).Send()
		conn.WriteJSON(WSMessage{Type: WSMsgError, Error: "Failed to read start message"})
		return
	}

	if startMsg.Type != WSMsgStart {
		logger.Error("Expected start message").Str("got", string(startMsg.Type)).Send()
		conn.WriteJSON(WSMessage{Type: WSMsgError, Error: "Expected start message"})
		return
	}

	if startMsg.Provider == "" || startMsg.Model == "" {
		logger.Error("Missing provider or model").Send()
		conn.WriteJSON(WSMessage{Type: WSMsgError, Error: "Provider and model are required"})
		return
	}

	if len(startMsg.Messages) == 0 {
		logger.Error("Empty messages").Send()
		conn.WriteJSON(WSMessage{Type: WSMsgError, Error: "Messages are required"})
		return
	}

	logger.Info("WebSocket AI chat started").
		Str("provider", startMsg.Provider).
		Str("model", startMsg.Model).
		Int("messages", len(startMsg.Messages)).
		Send()

	// Create WebSocket writer
	wsWriter := NewWSWriter(conn)

	// Run AI agent loop
	HandleAIWithWS(wsWriter, startMsg.Messages, startMsg.Provider, startMsg.Model, startMsg.IncludeCompleted)
}

// HandleAIWithWS runs the AI agent loop with WebSocket communication
func HandleAIWithWS(ws *WSWriter, messages []ChatCompletionMessage, provider, model string, includeCompleted bool) {
	logger.Info("Handling AI with WebSocket").
		Int("messages_count", len(messages)).
		Str("provider", provider).
		Str("model", model).
		Bool("includeCompleted", includeCompleted).
		Send()

	// Send initial thinking event
	if err := ws.SendThinking("Loading task context...", 0); err != nil {
		logger.Error("Failed to send thinking event").Err(err).Send()
		return
	}

	// Load context with limits and track timing
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

	// Build system prompt and prepend to messages
	systemPrompt, err := BuildSystemPrompt(tasks, projects)
	if err != nil {
		logger.Error("Failed to build system prompt").Err(err).Send()
		ws.SendError("Failed to build system prompt: " + err.Error())
		return
	}

	// Prepend system message to the messages array
	messagesWithSystem := []ChatCompletionMessage{
		{Role: "system", Content: systemPrompt},
	}
	messagesWithSystem = append(messagesWithSystem, messages...)

	// Create agent
	agent := createAIAgent(provider, model)

	// Send thinking event with context loading duration
	if err := ws.SendThinking("Context loaded, starting AI agent...", contextDuration); err != nil {
		logger.Error("Failed to send thinking event").Err(err).Send()
		return
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// Execute agent with WebSocket (context is reloaded on each iteration)
	if err := agent.ExecuteWithWS(messagesWithSystem, ws, ctx, includeCompleted); err != nil {
		logger.Error("Agent execution failed").Err(err).Send()
		// Error events are already sent by the agent
	}
}
