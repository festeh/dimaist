package ai

// WSMessageType represents WebSocket message types for type-safe communication
type WSMessageType string

const (
	// Client → Server message types
	WSMsgStart        WSMessageType = "start"
	WSMsgConfirm      WSMessageType = "confirm"
	WSMsgReject       WSMessageType = "reject"
	WSMsgBatchConfirm WSMessageType = "batch_confirm" // Batch tool confirmation with statuses

	// Server → Client message types
	WSMsgThinking      WSMessageType = "thinking"
	WSMsgToolPending   WSMessageType = "tool_pending"   // Single tool (legacy)
	WSMsgToolsPending  WSMessageType = "tools_pending"  // Batch tools
	WSMsgToolResult    WSMessageType = "tool_result"
	WSMsgFinalResponse WSMessageType = "final_response"
	WSMsgCancelled     WSMessageType = "cancelled"
	WSMsgError         WSMessageType = "error"

	// Parallel mode message types
	WSMsgModelResponse WSMessageType = "model_response" // Single model responded
	WSMsgModelError    WSMessageType = "model_error"    // Single model errored
	WSMsgAllComplete   WSMessageType = "all_complete"   // All models finished
	WSMsgSelectModel   WSMessageType = "select_model"   // User selected winning model
)

// ToolStatus represents the user's decision on a single tool in a batch
type ToolStatus struct {
	ToolCallID string         `json:"tool_call_id"`
	Status     string         `json:"status"` // "confirmed", "rejected"
	Arguments  map[string]any `json:"arguments,omitempty"`
}

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
