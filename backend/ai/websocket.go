package ai

import (
	"net/http"

	"dimaist/logger"

	"github.com/festeh/general"
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

// TargetSpec represents a provider+model combination for requests
type TargetSpec struct {
	Provider string `json:"provider"`
	Model    string `json:"model"`
}

// ID returns a unique identifier for this target
func (t TargetSpec) ID() string {
	return t.Provider + ":" + t.Model
}

// Session holds all context for an AI conversation
type Session struct {
	WS               *WSWriter
	Messages         []ChatCompletionMessage
	Targets          []TargetSpec
	SelectedModel    string // "provider:model" format, empty = not yet selected
	IncludeCompleted bool
	CurrentProjectID *uint // Project user is currently viewing (nil = Inbox/all tasks)
	TurnID           int   // Increments each turn, used to filter stale responses
}

// WSMessage represents a WebSocket message for AI chat
type WSMessage struct {
	Type WSMessageType `json:"type"`

	// Start message fields (client → server)
	Messages         []ChatCompletionMessage `json:"messages,omitempty"`
	Targets          []TargetSpec            `json:"targets,omitempty"`
	IncludeCompleted bool                    `json:"include_completed,omitempty"`
	CurrentProjectID *uint                   `json:"current_project_id,omitempty"`

	// Target identification
	TargetID string `json:"target_id,omitempty"`

	// Tool fields
	ToolCalls  []PendingToolCall `json:"tool_calls,omitempty"`
	ToolCallID string            `json:"tool_call_id,omitempty"`
	Arguments  map[string]any    `json:"arguments,omitempty"`

	// Message fields
	Message    string  `json:"message,omitempty"`
	NewMessage string  `json:"new_message,omitempty"`
	Response   string  `json:"response,omitempty"`
	Result     string  `json:"result,omitempty"`
	Error      string  `json:"error,omitempty"`
	Duration   float64 `json:"duration,omitempty"`

	// Image attachments (base64 data URIs)
	Images []string `json:"images,omitempty"`

	// All complete event fields
	SuccessfulTargets []string `json:"successful_targets,omitempty"`
	FailedTargets     []string `json:"failed_targets,omitempty"`

	// Turn tracking
	TurnID int `json:"turn_id,omitempty"`
}

// buildUserContent creates a MessageContent from text and optional images.
// Returns multipart content when images are present, plain text otherwise.
func buildUserContent(text string, images []string) general.MessageContent {
	if len(images) == 0 {
		return general.TextContent(text)
	}

	parts := make([]general.ContentPart, 0, len(images)+1)
	for _, img := range images {
		parts = append(parts, general.ContentPart{
			Type:     "image_url",
			ImageURL: &general.ImageURL{URL: img},
		})
	}
	if text != "" {
		parts = append(parts, general.ContentPart{
			Type: "text",
			Text: text,
		})
	}
	return general.MultiContent(parts...)
}

// HandleWebSocket handles WebSocket connections for AI chat
// Connection stays open for entire chat session
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

	if len(startMsg.Messages) == 0 {
		logger.Error("Empty messages").Send()
		conn.WriteJSON(WSMessage{Type: WSMsgError, Error: "Messages are required"})
		return
	}

	if len(startMsg.Targets) == 0 {
		logger.Error("No targets specified").Send()
		conn.WriteJSON(WSMessage{Type: WSMsgError, Error: "At least one target is required"})
		return
	}

	// Log first user message
	for i, msg := range startMsg.Messages {
		if msg.Role == "user" {
			logger.Info("AI request").
				Int("idx", i).
				Str("content", msg.Content.String()).
				Int("targets", len(startMsg.Targets)).
				Send()
		}
	}

	// Initialize session
	ws := NewWSWriter(conn)
	defer ws.Close() // Stop ping goroutine when connection ends
	ws.StartReading() // Start background reader for concurrent message handling

	s := &Session{
		WS:               ws,
		Messages:         startMsg.Messages,
		Targets:          startMsg.Targets,
		IncludeCompleted: startMsg.IncludeCompleted,
		CurrentProjectID: startMsg.CurrentProjectID,
	}

	// Main conversation loop
	for {
		logger.Info("Starting AI turn").
			Int("messages", len(s.Messages)).
			Int("targets", len(s.Targets)).
			Str("selectedModel", s.SelectedModel).
			Send()

		if err := HandleAI(s); err != nil {
			logger.Info("HandleAI returned error, ending session").Err(err).Send()
			return
		}

		// Check if user message was already added during HandleAI (e.g., continue during tool wait)
		if len(s.Messages) > 0 && s.Messages[len(s.Messages)-1].Role == "user" {
			logger.Info("User message already pending, continuing").Send()
			continue
		}

		// Wait for next message using channel
		logger.Info("Turn complete, waiting for continue").Send()
		select {
		case msg := <-s.WS.MsgChan():
			if msg == nil {
				logger.Info("WS channel closed, ending session").Send()
				return
			}

			if msg.Type == WSMsgContinue {
				logger.Info("Continue message received").Str("content", msg.NewMessage).Send()
				s.Messages = append(s.Messages, ChatCompletionMessage{
					Role:    "user",
					Content: buildUserContent(msg.NewMessage, msg.Images),
				})
			} else {
				logger.Warn("Unexpected message type").Str("type", string(msg.Type)).Send()
			}

		case err := <-s.WS.ErrChan():
			logger.Info("Connection closed").Err(err).Send()
			return
		}
	}
}
