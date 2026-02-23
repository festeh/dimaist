# Plan: Switch AI Provider to ai.dimalip.in

## Tech Stack

- Backend: Go (Chi router, `github.com/festeh/general` library)
- Frontend: Flutter (Riverpod state management)
- AI Proxy: CLIProxyAPI at `ai.dimalip.in` (OpenAI-compatible)

## Current State

- 4 separate AI providers (Kimi, OpenRouter, Google, Groq) each with their own endpoint + token
- Hard-coded model list in frontend (`ai_model_provider.dart`)
- Backend routes requests to different providers based on `TargetSpec.Provider` field
- Frontend `AiModel` has a `provider` field and `AiProvider` enum with display names and icons

## Target State

- Single AI proxy: `ai.dimalip.in` (CLIProxyAPI handles all provider routing internally)
- One endpoint + one API key for everything
- Dynamic model list fetched from `ai.dimalip.in/v1/models`, cached locally
- Default model is just `"default"` until list is fetched
- No provider concept in frontend — just model names

## Structure

Files to change:

```
backend/
├── env/env.go                    # Replace 4 provider configs with single AI_ENDPOINT + AI_TOKEN
├── ai/ai_text.go                 # Simplify createAIAgent() — single endpoint
├── ai/parallel.go                # Simplify getProvider() — single provider
│                                 # Add /v1/models proxy endpoint
├── ai/websocket.go               # TargetSpec loses Provider field — just model name
├── ai/ws_message_types.go        # (minor) Update TargetSpec if needed
├── main.go                       # Add GET /ai/models endpoint
│
frontend/
├── lib/models/ai_model.dart      # Remove AiProvider enum, simplify AiModel to just model name
├── lib/providers/ai_model_provider.dart  # Fetch models from backend, cache in SharedPreferences
├── lib/providers/parallel_ai_provider.dart # Update to work with new model IDs (no provider prefix)
├── lib/services/ai_websocket_service.dart  # TargetSpec drops provider field
├── lib/screens/ai_chat_screen.dart  # Update target building (no provider)
├── lib/widgets/model_list_dialog.dart   # Remove provider icons, show model names only
├── lib/widgets/model_display.dart       # Remove provider icon, show model name
├── lib/widgets/settings_dialog.dart     # Update AI model preview
├── lib/widgets/parallel_response_widget.dart # Update _getModelDisplayName (no provider: prefix)
```

## Approach

### 1. Backend: Simplify env config

Replace all provider-specific fields in `env.go` with two:

```go
AIEndpoint string  // default: "https://ai.dimalip.in/v1/chat/completions"
AIToken    string  // required: AI_TOKEN env var
```

Remove: `KimiEndpoint`, `KimiToken`, `OpenrouterEndpoint`, `OpenrouterToken`, `GoogleAIEndpoint`, `GoogleAIToken`, `GroqEndpoint`, `GroqToken`.

### 2. Backend: Simplify provider routing

In `parallel.go`, replace `getProvider()` switch statement with a single provider:

```go
func getProvider() general.Provider {
    return general.Provider{Endpoint: appEnv.AIEndpoint, APIKey: appEnv.AIToken}
}
```

In `ai_text.go`, simplify `createAIAgent()` — no more provider switch, just use the single endpoint.

### 3. Backend: Simplify TargetSpec

`TargetSpec` becomes just a model name. The `Provider` field is removed. The `ID()` method returns just the model name.

Update `parseTargetID()` — no more `provider:model` splitting.

Update `streamRequests()` — all targets use the same single provider.

### 4. Backend: Add /ai/models endpoint

New HTTP handler that proxies `GET https://ai.dimalip.in/v1/models` (with the API key) and returns the model list to the frontend. This keeps the API key server-side.

```go
// GET /ai/models
func HandleModels(w http.ResponseWriter, r *http.Request) {
    // Proxy request to ai.dimalip.in/v1/models with auth header
    // Return response as-is
}
```

Register in `main.go`: `r.Get("/ai/models", ai.HandleModels)`

### 5. Frontend: Simplify AiModel

Remove `AiProvider` enum entirely. `AiModel` becomes:

```dart
class AiModel {
  final String id;  // model name, e.g. "default", "kimi-for-code", "qwen/qwen3-32b"

  String get displayName => id.split('/').last;
}
```

### 6. Frontend: Dynamic model list with caching

Rewrite `AiModelNotifier` to:

1. On init: load cached model list from SharedPreferences. If empty, use `["default"]`.
2. On app start: fire async HTTP request to `GET /ai/models` on the backend.
3. On response: update model list, save to SharedPreferences cache.
4. If fetch fails: keep using cached list (or `["default"]`).

```dart
class AiModelNotifier extends StateNotifier<AiModelState> {
  static const _cacheKey = 'cached_model_ids';

  AiModelNotifier(this._apiService) : super(_loadCachedState()) {
    _refreshModels();  // async, non-blocking
  }

  Future<void> _refreshModels() async {
    final models = await _apiService.fetchModels();
    if (models != null) {
      state = AiModelState(models: models);
      _saveCache(models);
    }
  }
}
```

### 7. Frontend: Update WebSocket service

`TargetSpec` drops `provider` field. Becomes:

```dart
class TargetSpec {
  final String model;
  String get id => model;
  Map<String, dynamic> toJson() => {'model': model};
}
```

### 8. Frontend: Update UI widgets

- `ModelListDialog`: Remove provider icon (`Image.asset`). Show model name only.
- `ModelDisplay`: Remove provider icon. Show model name text.
- `ParallelResponseWidget._getModelDisplayName()`: No more `provider:model` parsing. Just extract short name from model ID.
- `SettingsDialog`: Update AI model preview (no `ModelDisplay` with provider icon).
- `AiChatScreen._sendParallelMessage()`: Build targets without provider.
- `AiChatScreen` app bar: Show model name instead of `ModelDisplay` widget.

### 9. Frontend: Update parallel_ai_provider

`_loadInitialState()` validates saved IDs against current model list. With dynamic models, it should validate against cached models (which may not be loaded yet). Change to: accept any saved IDs, let them be cleaned up when model list is fetched.

### 10. Clean up

- Delete provider icon assets (`assets/icons/kimi.png`, `openrouter.png`, `google.png`, `groq.png`).
- Update `.env` / `.env.example` if they exist.
- Remove unused imports.

## Order of Implementation

1. Backend env simplification (env.go)
2. Backend provider simplification (parallel.go, ai_text.go, websocket.go)
3. Backend /ai/models endpoint (new handler + main.go route)
4. Frontend AiModel simplification (ai_model.dart)
5. Frontend dynamic model fetching (ai_model_provider.dart, api_service.dart)
6. Frontend WebSocket + parallel updates (ai_websocket_service.dart, parallel_ai_provider.dart)
7. Frontend UI updates (all widgets + ai_chat_screen.dart)
8. Clean up (delete icons, remove unused code)

## Risks

- **Saved model selections become invalid**: Old saved IDs like `"kimi:kimi-for-coding"` won't match new IDs like `"kimi-for-coding"`. Mitigation: clear saved selection on first run with new format (or handle gracefully by falling back to "default").
- **CLIProxyAPI /v1/models requires auth**: The frontend can't call it directly. Mitigation: proxy through our backend (step 4).
- **Model list could be empty or slow**: Mitigation: default to `["default"]` — CLIProxyAPI has `kimi-for-code` aliased as `"default"`, so this always works.

## Open Questions

None — the approach is straightforward. CLIProxyAPI is already running and configured with all providers.
