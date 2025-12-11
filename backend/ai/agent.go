package ai

import (
	"fmt"
	"time"

	"dimaist/database"

	"github.com/festeh/general"
)

// Tool wraps general.Tool with a local Handler for execution.
type Tool struct {
	general.Tool
	Handler func(args map[string]any) (string, error)
}

// Convenience type aliases for cleaner code
type (
	ChatCompletionMessage  = general.ChatCompletionMessage
	ChatCompletionResponse = general.ChatCompletionResponse
	ChatCompletionRequest  = general.ChatCompletionRequest
	ToolCall               = general.ToolCall
)

type Agent struct {
	target general.Target
	tools  []Tool
	cmd    *general.Command
}

func NewAgent(apiKey, endpoint string, tools []Tool, model string) *Agent {
	provider := general.Provider{
		Endpoint: endpoint,
		APIKey:   apiKey,
	}
	target := general.Target{
		Provider: provider,
		Model:    model,
	}
	return &Agent{
		target: target,
		tools:  tools,
		cmd:    general.NewCommand([]general.Target{target}, nil),
	}
}

// executeToolWithArgs executes a tool with pre-parsed arguments
func (a *Agent) executeToolWithArgs(toolName string, args map[string]any) (string, error) {
	for _, tool := range a.tools {
		if tool.Function.Name == toolName {
			return tool.Handler(args)
		}
	}
	return "", fmt.Errorf("tool not found: %s", toolName)
}

// resolveToolDefaults adds default values to tool arguments for frontend preview
func resolveToolDefaults(toolName string, args map[string]any) map[string]any {
	// Copy args to avoid modifying original
	result := make(map[string]any)
	for k, v := range args {
		result[k] = v
	}

	// For create_task, default to Inbox project if not specified
	if toolName == "create_task" {
		if _, hasProject := result["project_id"]; !hasProject {
			var inboxProject database.Project
			if err := database.DB.Where("name = ? AND deleted_at IS NULL", "Inbox").First(&inboxProject).Error; err == nil {
				result["project_id"] = float64(inboxProject.ID)
			}
		}
	}

	// For task operations, fetch task details for preview
	if toolName == "complete_task" || toolName == "delete_task" || toolName == "update_task" {
		if taskID, ok := result["id"].(float64); ok {
			var task database.Task
			if err := database.DB.Where("deleted_at IS NULL").First(&task, int(taskID)).Error; err != nil {
				// Task not found - add error info for frontend
				result["_error"] = fmt.Sprintf("Task #%d not found", int(taskID))
			} else {
				// For update_task, only fill missing fields (preserve AI-provided updates)
				// For complete/delete, always set fields (they don't modify anything)
				if _, exists := result["description"]; !exists {
					result["description"] = task.Description
				}
				if _, exists := result["project_id"]; !exists && task.ProjectID != nil {
					result["project_id"] = float64(*task.ProjectID)
				}
				if _, hasDue := result["due_datetime"]; !hasDue {
					if _, hasDate := result["due_date"]; !hasDate && task.Due() != nil {
						if task.HasTime() {
							result["due_datetime"] = task.Due().Format(time.RFC3339)
						} else {
							result["due_date"] = task.Due().Format("2006-01-02")
						}
					}
				}
				if _, exists := result["labels"]; !exists && len(task.Labels) > 0 {
					result["labels"] = task.Labels
				}
			}
		}
	}

	return result
}
