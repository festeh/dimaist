package main

import (
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"time"

	"github.com/dima-b/go-task-backend/ai"
	"github.com/dima-b/go-task-backend/logger"
)

func transcribeAudio(w http.ResponseWriter, r *http.Request) {
	logger.Info("Transcribing audio").Send()

	// Parse multipart form
	err := r.ParseMultipartForm(32 << 20) // 32MB max
	if err != nil {
		logger.Error("Failed to parse multipart form").Err(err).Send()
		http.Error(w, "Invalid multipart form", http.StatusBadRequest)
		return
	}

	// Get audio file from form
	file, fileHeader, err := r.FormFile("audio")
	if err != nil {
		logger.Error("Failed to get audio file from form").Err(err).Send()
		http.Error(w, "audio file is required", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Get optional model parameter from form
	model := r.FormValue("model")
	if model == "" {
		model = ai.DefaultAIModel
	}

	// Get optional previous messages from form
	var previousMessages []ai.ChatCompletionMessage
	messagesJson := r.FormValue("messages")
	if messagesJson != "" {
		if err := json.Unmarshal([]byte(messagesJson), &previousMessages); err != nil {
			logger.Error("Failed to parse messages JSON").Err(err).Send()
			http.Error(w, "Invalid messages format", http.StatusBadRequest)
			return
		}
	}

	// Create streaming pipe to ASR service
	pipeReader, pipeWriter := io.Pipe()
	writer := multipart.NewWriter(pipeWriter)

	// Stream multipart form to ASR service in goroutine
	go func() {
		defer pipeWriter.Close()
		defer writer.Close()

		fileWriter, err := writer.CreateFormFile("audio", fileHeader.Filename)
		if err != nil {
			pipeWriter.CloseWithError(err)
			return
		}

		if _, err = io.Copy(fileWriter, file); err != nil {
			pipeWriter.CloseWithError(err)
		}
	}()

	// Create and send request to ASR service
	req, err := http.NewRequest("POST", appEnv.AsrUrl, pipeReader)
	if err != nil {
		logger.Error("Failed to create ASR request").Err(err).Send()
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		logger.Error("Failed to call ASR API").Err(err).Send()
		http.Error(w, "Failed to transcribe audio", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		logger.Error("ASR API error").Int("status", resp.StatusCode).Str("body", string(body)).Send()
		http.Error(w, "Transcription service error", http.StatusInternalServerError)
		return
	}

	// Parse and return response
	var result struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		logger.Error("Failed to decode ASR response").Err(err).Send()
		http.Error(w, "Invalid response from transcription service", http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully transcribed audio, redirecting to AI text handler").Str("text", result.Text).Str("model", model).Int("previous_messages", len(previousMessages)).Send()

	// Setup SSE headers by default
	ai.SetupSSEHeaders(w)

	// Create SSE writer
	sseWriter := ai.NewSSEWriter(w)

	// Send transcription event
	if err := sseWriter.Send("transcription", map[string]string{
		"text": result.Text,
	}); err != nil {
		logger.Error("Failed to send transcription SSE event").Err(err).Send()
		return
	}

	// Build messages array: previous messages + new user message with transcribed text
	messages := append(previousMessages, ai.ChatCompletionMessage{
		Role:    "user",
		Content: result.Text,
	})

	// Call the AI text handler with complete messages array
	ai.HandleAITextWithWriter(sseWriter, messages, model)
}
