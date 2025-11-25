package ai

import (
	"fmt"
	"sync"

	"github.com/gorilla/websocket"
)

// WSWriter handles WebSocket message writing with thread-safety
type WSWriter struct {
	conn *websocket.Conn
	mu   sync.Mutex
}

// NewWSWriter creates a new WebSocket writer
func NewWSWriter(conn *websocket.Conn) *WSWriter {
	return &WSWriter{conn: conn}
}

// write sends a message with mutex protection
func (w *WSWriter) write(msg WSMessage) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.conn.WriteJSON(msg)
}

// SendThinking sends a thinking/progress message
func (w *WSWriter) SendThinking(message string, duration float64) error {
	return w.write(WSMessage{
		Type:     WSMsgThinking,
		Message:  message,
		Duration: duration,
	})
}

// SendToolPending sends a tool pending message requesting user confirmation
func (w *WSWriter) SendToolPending(tool string, args map[string]any, duration float64) error {
	return w.write(WSMessage{
		Type:      WSMsgToolPending,
		Tool:      tool,
		Arguments: args,
		Duration:  duration,
	})
}

// SendToolResult sends a tool execution result
func (w *WSWriter) SendToolResult(result string, duration float64) error {
	return w.write(WSMessage{
		Type:     WSMsgToolResult,
		Result:   result,
		Duration: duration,
	})
}

// SendFinalResponse sends the final AI response
func (w *WSWriter) SendFinalResponse(response string, duration float64) error {
	return w.write(WSMessage{
		Type:     WSMsgFinalResponse,
		Response: response,
		Duration: duration,
	})
}

// SendError sends an error message
func (w *WSWriter) SendError(errMsg string) error {
	return w.write(WSMessage{
		Type:  WSMsgError,
		Error: errMsg,
	})
}

// SendCancelled sends a cancellation message
func (w *WSWriter) SendCancelled() error {
	return w.write(WSMessage{
		Type:    WSMsgCancelled,
		Message: "Action cancelled by user",
	})
}

// WaitForConfirmation blocks until user confirms or rejects
// Returns: confirmed (bool), modifiedArgs (if user edited), error
func (w *WSWriter) WaitForConfirmation() (bool, map[string]any, error) {
	var msg WSMessage
	if err := w.conn.ReadJSON(&msg); err != nil {
		return false, nil, fmt.Errorf("failed to read confirmation: %w", err)
	}

	switch msg.Type {
	case WSMsgConfirm:
		return true, msg.Arguments, nil
	case WSMsgReject:
		return false, nil, nil
	default:
		return false, nil, fmt.Errorf("unexpected message type: %s", msg.Type)
	}
}
