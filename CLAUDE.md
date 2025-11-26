# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a task management application called "Dimaist" (described as "Todoist, but make it vibe-coded") with both backend and frontend components:
- **Backend**: Go REST API server with PostgreSQL database
- **Frontend**: Flutter app with support for both phone and Wear OS devices
- **CLI Tool**: Standalone audio recording and transcription CLI

## Development Commands

### Backend (Go)
```bash
cd backend
go run main.go                    # Run development server (default port 3000)
go run main.go -port=8080        # Run server on custom port
```

### Frontend (Flutter)

Use `just` commands from the `frontend/` directory:

```bash
cd frontend
just run-phone        # Run the phone app
just run-wear         # Run the Wear OS app
just run-linux        # Run Linux desktop app
just build-phone      # Build APK for phone
just build-wear       # Build APK for Wear OS
just build-linux      # Build Linux app for release
just install-phone    # Build and install phone APK
just analyze          # Lint/analyze code
just test             # Run tests
just deps             # Get dependencies (flutter pub get)
just upgrade          # Upgrade dependencies
just clean            # Clean build artifacts
just release 1.1.0    # Create a release with version tag
```

### Audio CLI Tool
```bash
cd backend/cmd/audio-cli
./build.sh                      # Build the CLI tool
export ELEVENLABS_API_KEY=your_key_here
./audiocli                      # Start recording (press any key to stop)
```

## Architecture

### Backend Structure
- **Database Models**: `backend/database/models.go` - Task, Project, Note, Audio entities with GORM
- **Main Server**: `backend/main.go` - Chi router with REST endpoints for tasks, projects, notes, AI transcription
- **Key Features**:
  - Task management with recurring tasks support
  - Project organization with drag-and-drop ordering
  - Audio transcription using ElevenLabs API
  - Search functionality across tasks, projects, and notes
  - Sync endpoint with timestamp-based incremental updates

### Frontend Structure
- **Models**: Dart classes in `lib/models/` mirror backend entities
- **Services**: API client, local database (Drift/SQLite), logging, tray management
- **Screens**: Task management UI with support for both mobile and Wear OS
- **Key Features**:
  - Cross-platform Flutter app (Android, Linux, Wear OS)
  - Local-first with server sync
  - Audio recording and transcription integration
  - System tray support for desktop

### API Endpoints
- `GET/POST /tasks` - Task CRUD operations
- `POST /tasks/{id}/complete` - Mark task complete (handles recurring tasks)
- `GET/POST /projects` - Project CRUD operations  
- `PUT /projects/{id}/tasks/reorder` - Reorder tasks within project
- `PUT /projects-reorder` - Reorder projects
- `GET/POST /notes` - Note CRUD operations
- `POST /ai/audio` - Audio transcription (multipart form or JSON)
- `GET /sync?sync_token=` - Incremental data sync
- `GET /find?q=` - Search across all entities

### Database Schema
- **Tasks**: description, project_id, due_date/due_datetime, labels (array), reminders (timestamp array), recurrence, order, completed_at
- **Projects**: name, color, order
- **Notes**: title, content, audio_id reference
- **Audio**: base64-encoded compressed audio data

### Environment Setup
Backend requires PostgreSQL connection and ElevenLabs API key via environment variables or `.env` file.

### Key Technical Decisions
- Go backend uses Chi router, GORM ORM, and PostgreSQL arrays for labels/reminders
- Flutter frontend uses Drift for local SQLite storage
- Audio is compressed and stored as base64 in database
- Recurring tasks are handled by updating due dates rather than creating new tasks
- Search uses PostgreSQL ILIKE for case-insensitive matching
- Sync uses RFC3339 timestamps for incremental updates