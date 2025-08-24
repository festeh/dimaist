package main

import (
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"

	"github.com/dima-b/go-task-backend/compression"
	"github.com/dima-b/go-task-backend/database"
	"github.com/dima-b/go-task-backend/logger"
	"github.com/dima-b/go-task-backend/transcription"
)

type AudioTranscriptionRequest struct {
	PCMData []byte `json:"pcm_data"`
}

func transcribeAudio(w http.ResponseWriter, r *http.Request) {
	logger.Info("Transcribing audio").Send()

	// Check if it's multipart form data (frontend) or JSON (CLI via backend)
	contentType := r.Header.Get("Content-Type")

	if contentType == "application/json" {
		// Handle JSON request (for backward compatibility)
		var req AudioTranscriptionRequest
		err := json.NewDecoder(r.Body).Decode(&req)
		if err != nil {
			logger.Error("Failed to decode audio transcription request").Err(err).Send()
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		if len(req.PCMData) == 0 {
			logger.Error("No PCM data provided").Send()
			http.Error(w, "pcm_data is required", http.StatusBadRequest)
			return
		}

		// Use shared transcription function for PCM
		result, err := transcription.TranscribePCM(req.PCMData, appEnv.ElevenLabsAPIKey)
		if err != nil {
			logger.Error("Failed to transcribe audio").Err(err).Send()
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		logger.Info("Successfully transcribed audio").Str("text", result.Text).Send()

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
		return
	}

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

	// Compress the audio data
	compressedData, err := compression.CompressAudio(wavData)
	if err != nil {
		logger.Error("Failed to compress audio").Err(err).Send()
		http.Error(w, "Failed to compress audio", http.StatusInternalServerError)
		return
	}

	// Encode compressed audio to base64
	base64Data := base64.StdEncoding.EncodeToString(compressedData)

	// Save base64 encoded audio to database
	audio := database.Audio{
		Data: base64Data,
	}

	dbResult := database.DB.Create(&audio)
	if dbResult.Error != nil {
		logger.Error("Failed to save audio to database").Err(dbResult.Error).Send()
		http.Error(w, "Failed to save audio", http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully saved compressed audio to database").
		Uint("audio_id", audio.ID).
		Int("original_size", len(wavData)).
		Int("compressed_size", len(compressedData)).
		Int("base64_size", len(base64Data)).
		Send()

	// Use shared transcription function for WAV
	result, err := transcription.TranscribeWAV(wavData, appEnv.ElevenLabsAPIKey)
	if err != nil {
		logger.Error("Failed to transcribe audio").Err(err).Send()
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	logger.Info("Successfully transcribed audio").Str("text", result.Text).Send()

	// Return just the transcription result
	logger.Info("Successfully transcribed audio").
		Uint("audio_id", audio.ID).
		Str("transcribed_text", result.Text).
		Send()

	response := map[string]interface{}{
		"content":  result.Text,
		"audio_id": audio.ID,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
