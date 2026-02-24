package ai

// WSMessageType represents WebSocket message types for type-safe communication
type WSMessageType string

const (
	// Client → Server message types
	WSMsgStart       WSMessageType = "start"        // Initial message with targets
	WSMsgToolConfirm WSMessageType = "tool_confirm" // Confirm single tool execution
	WSMsgContinue    WSMessageType = "continue"     // User sends new message
	WSMsgSelectModel WSMessageType = "select_model" // User selected winning model

	// Server → Client message types
	WSMsgThinking      WSMessageType = "thinking"
	WSMsgToolsPending  WSMessageType = "tools_pending" // Batch tools awaiting confirmation
	WSMsgToolResult    WSMessageType = "tool_result"
	WSMsgError         WSMessageType = "error"
	WSMsgModelResponse WSMessageType = "model_response" // Model text response
	WSMsgModelError    WSMessageType = "model_error"    // Model error
	WSMsgAllComplete   WSMessageType = "all_complete"   // All models finished
)

// ConfirmationRequiredTools lists tools that require user confirmation before execution
var ConfirmationRequiredTools = map[string]bool{
	"create_task":    true,
	"update_task":    true,
	"delete_task":    true,
	"complete_task":  true,
	"create_project": true,
	"update_project": true,
	"delete_project": true,
}
