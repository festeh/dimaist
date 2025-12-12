package ai

import (
	"encoding/json"
	"fmt"

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

	// For task operations, fetch full task from DB for preview
	if toolName == "complete_task" || toolName == "delete_task" || toolName == "update_task" {
		if taskID, ok := result["id"].(float64); ok {
			var task database.Task
			if err := database.DB.Where("deleted_at IS NULL").First(&task, int(taskID)).Error; err != nil {
				result["_error"] = fmt.Sprintf("Task #%d not found", int(taskID))
			} else {
				// Marshal task to JSON, then unmarshal to map - gets all fields automatically
				taskJSON, _ := json.Marshal(task)
				var taskData map[string]any
				json.Unmarshal(taskJSON, &taskData)

				// For update_task, overlay AI-provided fields on top of DB data
				if toolName == "update_task" {
					for k, v := range result {
						taskData[k] = v
					}
				}
				result = taskData
			}
		}
	}

	return result
}
