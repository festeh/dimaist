# Plan: Remove Chutes, Add Kimi Support

## Tech Stack

- Language: Go (backend, general library), Dart (frontend)
- Framework: Chi router, Flutter/Riverpod
- Storage: PostgreSQL (unchanged)
- Testing: manual (no existing test suite for AI providers)

## Structure

Files to change:

```
~/projects/general/                     # Upstream library
├── types.go                            # Add Headers to Provider
├── execute.go                          # Apply custom headers in HTTP requests
├── providers.go                        # Replace Chutes with Kimi
backend/
├── go.mod                              # Update general dependency
├── env/env.go                          # Replace CHUTES_* with KIMI_*
├── ai/ai_text.go                       # Replace chutes case with kimi
├── ai/parallel.go                      # Replace chutes case with kimi
frontend/
├── lib/models/ai_model.dart            # Replace chutes enum with kimi
├── lib/providers/ai_model_provider.dart # Replace chutes models with kimi models
├── assets/icons/chutes.png             # Delete
├── assets/icons/kimi.png               # Add (done)
.github/workflows/deploy.yml            # Replace CHUTES env vars with KIMI
```

## Approach

### 0. general library: Add custom headers support

In `~/projects/general/types.go`:
- Add `Headers map[string]string` field to `Provider` struct

In `~/projects/general/execute.go` `executeSingleRequest()`:
- After setting Content-Type and Authorization, loop over `target.Provider.Headers` and set each on the request

In `~/projects/general/providers.go`:
- Remove `ChutesEndpoint` constant and `Chutes()` function
- Add `KimiEndpoint = "https://api.kimi.com/coding/v1/chat/completions"` (base is `https://api.kimi.com/coding/v1`, we append `/chat/completions` to match the library convention) and `Kimi()` function that sets `Headers: map[string]string{"User-Agent": "KimiCLI/1.3"}`

Then: commit, push, and update go.mod in dimaist backend.

### 1. Backend: Replace Chutes env vars with Kimi

In `backend/env/env.go`:
- Remove `ChutesEndpoint` and `ChutesToken` from `Env` struct
- Add `KimiEndpoint` and `KimiToken`
- Replace CHUTES_ENDPOINT/CHUTES_TOKEN loading with:
  - `KIMI_TOKEN` (required)
  - `KIMI_ENDPOINT` defaults to `https://api.kimi.com/coding/v1/chat/completions`

### 2. Backend: Update provider switch statements

In `backend/ai/ai_text.go` `createAIAgent()`:
- Replace `case "chutes"` with `case "kimi"`, using `appEnv.KimiToken` and `appEnv.KimiEndpoint`

In `backend/ai/parallel.go` `getProvider()`:
- Replace `case "chutes"` with `case "kimi"`, using `appEnv.KimiEndpoint` and `appEnv.KimiToken`
- Add `Headers: map[string]string{"User-Agent": "KimiCLI/1.3"}` to the kimi Provider

### 3. Frontend: Replace chutes provider with kimi

In `frontend/lib/models/ai_model.dart`:
- Rename `AiProvider.chutes` to `AiProvider.kimi`
- Update `displayName` to return `'Kimi'`
- Update `iconPath` to return `'assets/icons/kimi.png'`
- Update `fromJson` fallback from `AiProvider.chutes` to `AiProvider.kimi`

### 4. Frontend: Update default models

In `frontend/lib/providers/ai_model_provider.dart`:
- Remove all Chutes models
- Add one Kimi model:
  - `kimi-for-coding` (provider: kimi)

### 5. Frontend: Swap icons

- Delete `frontend/assets/icons/chutes.png`
- `frontend/assets/icons/kimi.png` already added

### 6. CI: Update deploy workflow

In `.github/workflows/deploy.yml`:
- Replace `CHUTES_ENDPOINT` and `CHUTES_TOKEN` with `KIMI_ENDPOINT` and `KIMI_TOKEN`
- Update secret references and validation

## Risks

- **Kimi endpoint path**: The general library POSTs directly to `Provider.Endpoint` (no path appending). All existing providers store the full `/chat/completions` URL. Kimi's base is `https://api.kimi.com/coding/v1`, so the constant becomes `https://api.kimi.com/coding/v1/chat/completions`.

## Resolved

- **Custom headers**: Will add `Headers map[string]string` to `general.Provider` and apply in HTTP requests.
- **Kimi icon**: Downloaded from dashboardicons.com (512x512 PNG, CC-BY-4.0), already placed at `frontend/assets/icons/kimi.png`.
