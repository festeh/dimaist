package ai

import (
	"sync"

	"github.com/gorilla/websocket"
)

// WSWriter handles WebSocket message writing with thread-safety
type WSWriter struct {
	conn    *websocket.Conn
	mu      sync.Mutex
	msgChan chan *WSMessage // Channel for incoming messages
	errChan chan error      // Channel for read errors
}

// NewWSWriter creates a new WebSocket writer
func NewWSWriter(conn *websocket.Conn) *WSWriter {
	return &WSWriter{
		conn:    conn,
		msgChan: make(chan *WSMessage, 10),
		errChan: make(chan error, 1),
	}
}

// StartReading starts a goroutine to read messages into channel
func (w *WSWriter) StartReading() {
	go func() {
		for {
			var msg WSMessage
			if err := w.conn.ReadJSON(&msg); err != nil {
				w.errChan <- err
				close(w.msgChan)
				return
			}
			w.msgChan <- &msg
		}
	}()
}

// MsgChan returns the message channel for select
func (w *WSWriter) MsgChan() <-chan *WSMessage {
	return w.msgChan
}

// ErrChan returns the error channel for select
func (w *WSWriter) ErrChan() <-chan error {
	return w.errChan
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

// SendToolResult sends a tool execution result
func (w *WSWriter) SendToolResult(result string, duration float64) error {
	return w.write(WSMessage{
		Type:     WSMsgToolResult,
		Result:   result,
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

// SendModelResponse sends a single model's response in parallel mode
func (w *WSWriter) SendModelResponse(targetID, response string, duration float64, turnID int) error {
	return w.write(WSMessage{
		Type:     WSMsgModelResponse,
		TargetID: targetID,
		Response: response,
		Duration: duration,
		TurnID:   turnID,
	})
}

// SendModelError sends a single model's error in parallel mode
func (w *WSWriter) SendModelError(targetID, errMsg string, duration float64, turnID int) error {
	return w.write(WSMessage{
		Type:     WSMsgModelError,
		TargetID: targetID,
		Error:    errMsg,
		Duration: duration,
		TurnID:   turnID,
	})
}

// SendToolsPendingForModel sends tools pending with a target ID for parallel mode
func (w *WSWriter) SendToolsPendingForModel(targetID string, tools []PendingToolCall, duration float64, turnID int) error {
	return w.write(WSMessage{
		Type:      WSMsgToolsPending,
		TargetID:  targetID,
		ToolCalls: tools,
		Duration:  duration,
		TurnID:    turnID,
	})
}

// SendAllComplete signals that all parallel models have finished
func (w *WSWriter) SendAllComplete(successful, failed []string, turnID int) error {
	return w.write(WSMessage{
		Type:              WSMsgAllComplete,
		SuccessfulTargets: successful,
		FailedTargets:     failed,
		TurnID:            turnID,
	})
}
