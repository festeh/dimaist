package ai

// WSMessageType represents WebSocket message types for type-safe communication
type WSMessageType string

const (
	// Client → Server message types
	WSMsgStart   WSMessageType = "start"
	WSMsgConfirm WSMessageType = "confirm"
	WSMsgReject  WSMessageType = "reject"

	// Server → Client message types
	WSMsgThinking      WSMessageType = "thinking"
	WSMsgToolPending   WSMessageType = "tool_pending"
	WSMsgToolResult    WSMessageType = "tool_result"
	WSMsgFinalResponse WSMessageType = "final_response"
	WSMsgCancelled     WSMessageType = "cancelled"
	WSMsgError         WSMessageType = "error"
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
