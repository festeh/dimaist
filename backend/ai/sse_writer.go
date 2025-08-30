package ai

import (
	"encoding/json"
	"fmt"
	"net/http"
)

type SSEWriter interface {
	Send(event string, data any) error
	Flush()
}

type SSEEvent struct {
	Event string      `json:"event"`
	Data  any `json:"data"`
}

type sseWriter struct {
	writer  http.ResponseWriter
	flusher http.Flusher
}

func NewSSEWriter(w http.ResponseWriter) SSEWriter {
	flusher, ok := w.(http.Flusher)
	if !ok {
		// If flusher is not available, we'll still work but without flushing
		flusher = nil
	}

	return &sseWriter{
		writer:  w,
		flusher: flusher,
	}
}

func (s *sseWriter) Send(event string, data any) error {
	sseEvent := SSEEvent{
		Event: event,
		Data:  data,
	}

	eventData, err := json.Marshal(sseEvent)
	if err != nil {
		return fmt.Errorf("failed to marshal SSE event: %w", err)
	}

	// Write SSE format: data: {json}\n\n
	_, err = fmt.Fprintf(s.writer, "data: %s\n\n", eventData)
	if err != nil {
		return fmt.Errorf("failed to write SSE event: %w", err)
	}

	// Flush immediately to ensure client receives the event
	s.Flush()

	return nil
}

func (s *sseWriter) Flush() {
	if s.flusher != nil {
		s.flusher.Flush()
	}
}
