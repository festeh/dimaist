# Plan: Image Attachments in AI Chat

## Tech Stack

- **Backend**: Go (existing), `github.com/festeh/general` library (needs update)
- **Frontend**: Flutter (existing), `image_picker` package (new dependency)
- **Protocol**: WebSocket (existing), base64-encoded images in JSON messages
- **Storage**: None — images are ephemeral, sent to AI providers and not persisted

## Key Constraint

The `general` library's `ChatCompletionMessage.Content` is a plain `string`. Most LLM APIs (OpenAI, Google, etc.) accept multipart content as a JSON array of `{type: "text", text: "..."}` and `{type: "image_url", image_url: {url: "data:image/png;base64,..."}}` objects. The `Content` field must change from `string` to `any` (or a union type) to support this.

## Structure

```
backend/
├── ai/
│   ├── websocket.go          # Update ChatCompletionMessage, WSMessage to carry images
│   └── parallel.go           # Build multipart content when images present
│
frontend/lib/
├── widgets/
│   └── chat_input_widget.dart # Add image picker button
├── screens/
│   └── ai_chat_screen.dart    # Handle image attachments, show image previews
├── services/
│   └── ai_websocket_service.dart # Send images as base64 in WS messages
└── models/
    └── ws_message_type.dart   # (no changes needed — images ride on existing message types)
```

## Approach

### 1. Update `general` library to support multipart content

The `ChatCompletionMessage.Content` field is currently `string`. Change it to `any` so it can hold either a plain string or an array of content parts. Update JSON marshaling to handle both cases.

**In `general/types.go`:**
```go
type ChatCompletionMessage struct {
    Role       string     `json:"role"`
    Content    any        `json:"content,omitempty"`  // string or []ContentPart
    ToolCalls  []ToolCall `json:"tool_calls,omitempty"`
    ToolCallID string     `json:"tool_call_id,omitempty"`
}

type ContentPart struct {
    Type     string    `json:"type"`               // "text" or "image_url"
    Text     string    `json:"text,omitempty"`
    ImageURL *ImageURL `json:"image_url,omitempty"`
}

type ImageURL struct {
    URL string `json:"url"`  // "data:image/png;base64,..." or a URL
}
```

This format is the OpenAI-compatible standard that OpenRouter, Google AI (via compatibility layer), and most providers accept.

### 2. Backend: accept images in WebSocket messages

Add an `images` field to `WSMessage` and the local `ChatCompletionMessage` alias. Images arrive as base64 strings from the frontend.

**In `websocket.go`:**
- Add `Images []string` field to `WSMessage` (base64-encoded image data)

**In `parallel.go` (`streamRequests`):**
- When converting messages for the `general` library, check if images are present
- If images exist, build `Content` as `[]ContentPart` (text part + image parts)
- If no images, keep `Content` as a plain string (backward compatible)

**In `websocket.go` (main loop):**
- When receiving `start` or `continue` messages with images, store them alongside the text content in the session messages

### 3. Frontend: add image picker to chat input

Add an image attachment button to `ChatInputWidget` next to the voice button.

**In `chat_input_widget.dart`:**
- Add `image_picker` dependency to `pubspec.yaml`
- Add an image button (camera/gallery icon) to the left of the voice button
- On tap: show bottom sheet with "Camera" and "Gallery" options
- Store selected image bytes as state
- Show a small thumbnail preview above the input when an image is attached
- Pass image bytes alongside text when sending

**New callback:** `Function(List<int> imageBytes)? onImageAttached`
**Updated callback:** `Function(String text, List<List<int>>? images) onSendMessage` — or keep text-only and add a separate images parameter

### 4. Frontend: send images over WebSocket

**In `ai_websocket_service.dart`:**
- Update `sendStart()` and `sendContinue()` to accept optional `List<String> images` (base64-encoded)
- Include `images` field in the JSON message when present

**In `ai_chat_screen.dart`:**
- Track attached images as `List<Uint8List>` state
- Convert to base64 before sending
- Clear attachments after sending
- Show image thumbnails in user message bubbles

### 5. Frontend: display images in chat

**In `ai_chat_screen.dart` (`_buildUserMessage`):**
- Update `ChatMessage` to include optional `List<Uint8List> images`
- Render attached images as thumbnails above the message text
- Constrain image size (max ~200px wide)

## Data Flow

```
User picks image → image_picker → Uint8List bytes
                                        ↓
User taps send → base64 encode → WebSocket JSON:
  {
    "type": "continue",
    "new_message": "What's in this image?",
    "images": ["data:image/jpeg;base64,/9j/4AAQ..."]
  }
                                        ↓
Backend receives → builds multipart content:
  Content: [
    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}},
    {"type": "text", "text": "What's in this image?"}
  ]
                                        ↓
Sent to AI provider → model responds with text
```

## Image Size Handling

- Resize images on the frontend before encoding: max 1024px on the longest edge
- Use JPEG compression at 85% quality to reduce payload size
- Cap at 1 image per message initially (can expand later)
- Estimated max payload: ~500KB base64 for a 1024px JPEG — well within WebSocket frame limits

## Risks

- **`general` library update**: This is the main blocker. The `Content` field type change could break existing serialization. Mitigation: change `Content` to `any`, which marshals correctly for both `string` and `[]ContentPart`.
- **Provider compatibility**: Not all models support vision. Mitigation: send images anyway — models that don't support vision will ignore image parts or return an error, which already gets handled by the existing error flow.
- **Large payloads over WebSocket**: Base64 adds ~33% overhead. Mitigation: resize and compress on frontend before sending. A 1024px JPEG at 85% quality is typically 100-300KB, yielding ~130-400KB base64.
- **Mobile memory**: Loading large images into memory. Mitigation: resize before encoding, limit to 1 image per message.

## Open Questions

- **Multiple images per message?** Start with 1, expand to multiple later if needed.
- **Clipboard paste support on desktop?** Could add later — keep the image picker pattern generic enough to support it.
- **Should the `general` library fork be a separate PR?** Depends on whether it's owned by you. If so, update it first, then bump the dependency.
