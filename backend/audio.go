package main

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"time"

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
		model = DefaultAIModel
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

	logger.Info("Successfully transcribed audio, redirecting to AI text handler").Str("text", result.Text).Str("model", model).Send()
	
	// Create a new request for the AI text handler
	textRequest := TextRequest{
		Text:  result.Text,
		Model: model,
	}
	
	// Marshal the request to JSON
	requestBody, err := json.Marshal(textRequest)
	if err != nil {
		logger.Error("Failed to marshal text request").Err(err).Send()
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	
	// Create a new HTTP request with the transcribed text
	newReq, err := http.NewRequestWithContext(r.Context(), "POST", "/ai/text", bytes.NewReader(requestBody))
	if err != nil {
		logger.Error("Failed to create new request").Err(err).Send()
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	
	// Copy relevant headers
	newReq.Header.Set("Content-Type", "application/json")
	
	// Forward to the AI text handler
	handleAIText(w, newReq)
}
