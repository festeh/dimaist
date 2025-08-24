package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"time"

	"github.com/dima-b/go-task-backend/logger"
)

type AsrResponse struct {
	Text string `json:"text"`
}

// TranscribeWAV transcribes WAV audio data using external ASR service
func TranscribeWAV(wavData []byte, asrUrl string) (*AsrResponse, error) {

	// Create multipart form data
	var buf bytes.Buffer
	writer := multipart.NewWriter(&buf)

	// Add audio file
	fileWriter, err := writer.CreateFormFile("audio", "audio.wav")
	if err != nil {
		return nil, fmt.Errorf("failed to create form file: %v", err)
	}

	_, err = fileWriter.Write(wavData)
	if err != nil {
		return nil, fmt.Errorf("failed to write audio data: %v", err)
	}

	err = writer.Close()
	if err != nil {
		return nil, fmt.Errorf("failed to close multipart writer: %v", err)
	}

	// Create request to external ASR service
	req, err := http.NewRequest("POST", asrUrl, &buf)
	if err != nil {
		return nil, fmt.Errorf("failed to create ASR request: %v", err)
	}

	req.Header.Set("Content-Type", writer.FormDataContentType())

	// Make request to ASR service
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call ASR API: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ASR API error (status %d): %s", resp.StatusCode, string(body))
	}

	// Parse ASR response
	var asrResponse AsrResponse
	err = json.NewDecoder(resp.Body).Decode(&asrResponse)
	if err != nil {
		return nil, fmt.Errorf("failed to decode ASR response: %v", err)
	}

	return &asrResponse, nil
}

type AudioTranscriptionRequest struct {
	PCMData []byte `json:"pcm_data"`
}

func transcribeAudio(w http.ResponseWriter, r *http.Request) {
	logger.Info("Transcribing audio").Send()

	// Handle multipart form data (frontend)
	err := r.ParseMultipartForm(32 << 20) // 32MB max
	if err != nil {
		logger.Error("Failed to parse multipart form").Err(err).Send()
		http.Error(w, "Invalid multipart form", http.StatusBadRequest)
		return
	}

	// Get the audio file from the form
	file, _, err := r.FormFile("audio")
	if err != nil {
		logger.Error("Failed to get audio file from form").Err(err).Send()
		http.Error(w, "audio file is required", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Read the WAV file data
	wavData, err := io.ReadAll(file)
	if err != nil {
		logger.Error("Failed to read audio file").Err(err).Send()
		http.Error(w, "Failed to read audio file", http.StatusInternalServerError)
		return
	}

	if len(wavData) == 0 {
		logger.Error("Empty audio file provided").Send()
		http.Error(w, "audio file is empty", http.StatusBadRequest)
		return
	}

	result, err := TranscribeWAV(wavData, appEnv.AsrUrl)
	if err != nil {
		logger.Error("Failed to transcribe audio").Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully transcribed audio").Str("text", result.Text).Send()

	// Return just the transcription result
	logger.Info("Successfully transcribed audio").
		Str("text", result.Text).
		Send()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}
