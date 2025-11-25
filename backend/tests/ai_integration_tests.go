package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"dimaist/ai"
)

// Mock data structures
type MockTask struct {
	ID          uint      `json:"id"`
	Description string    `json:"description"`
	ProjectID   *uint     `json:"project_id,omitempty"`
	DueDate     *string   `json:"due_date,omitempty"`
	CompletedAt *string   `json:"completed_at,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type MockProject struct {
	ID        uint      `json:"id"`
	Name      string    `json:"name"`
	Color     string    `json:"color"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Test scenarios
type TestScenario struct {
	Name          string
	UserInput     string
	ExpectedTools []string // List of tool names that should be called
	Description   string
}

func createMockData() ([]MockTask, []MockProject) {
	now := time.Now()
	today := now.Format("2006-01-02")
	yesterday := now.AddDate(0, 0, -1).Format("2006-01-02")
	tomorrow := now.AddDate(0, 0, 1).Format("2006-01-02")

	// Mock projects
	projects := []MockProject{
		{
			ID:        1,
			Name:      "Work",
			Color:     "blue",
			CreatedAt: now,
			UpdatedAt: now,
		},
		{
			ID:        2,
			Name:      "Personal",
			Color:     "green",
			CreatedAt: now,
			UpdatedAt: now,
		},
	}

	// Mock tasks
	projectID1 := uint(1)
	projectID2 := uint(2)
	completed := now.AddDate(0, 0, -1).Format(time.RFC3339)

	tasks := []MockTask{
		{
			ID:          1,
			Description: "Review quarterly report",
			ProjectID:   &projectID1,
			DueDate:     &today,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			ID:          2,
			Description: "Team standup meeting",
			ProjectID:   &projectID1,
			DueDate:     &today,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			ID:          3,
			Description: "Buy groceries",
			ProjectID:   &projectID2,
			DueDate:     &tomorrow,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			ID:          4,
			Description: "Completed task from yesterday",
			ProjectID:   &projectID2,
			DueDate:     &yesterday,
			CompletedAt: &completed,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			ID:          5,
			Description: "Task without due date",
			ProjectID:   &projectID1,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
	}

	return tasks, projects
}

func buildMockSystemPrompt(tasks []MockTask, projects []MockProject) string {
	tasksJSON, _ := json.MarshalIndent(tasks, "", "  ")
	projectsJSON, _ := json.MarshalIndent(projects, "", "  ")

	now := time.Now()
	today := now.Format("2006-01-02")

	tools := ai.CreateCRUDTools()
	var toolsDesc strings.Builder
	toolsDesc.WriteString("Available tools:\n")

	for _, tool := range tools {
		toolsDesc.WriteString(fmt.Sprintf("- %s: %s\n", tool.Function.Name, tool.Function.Description))

		// Add parameter descriptions
		for param, prop := range tool.Function.Parameters.Properties {
			requiredText := ""
			for _, req := range tool.Function.Parameters.Required {
				if req == param {
					requiredText = " (required)"
					break
				}
			}
			toolsDesc.WriteString(fmt.Sprintf("  * %s: %s%s - %s\n", param, prop.Type, requiredText, prop.Description))
		}
		toolsDesc.WriteString("\n")
	}

	return fmt.Sprintf(`You are an AI assistant for a task management system called "Dimaist".
You help users manage their tasks and projects efficiently.

IMPORTANT RULES:
1. You can use the available tools to perform actions or provide responses
2. Use the 'respond' tool to send final answers to the user
3. ALL TASK/PROJECT DATA IS ALREADY PROVIDED BELOW - you do not need to use tools to retrieve or list existing tasks, projects, or other information
4. Use the provided current system state to answer questions about existing data directly
5. Today's date is: %s

Current System State:
Tasks: %s

Projects: %s

%s

Examples of proper responses:
- To answer a question about existing data: Use the respond tool with your answer based on the data above
- To create a task: Use the create_task tool with the task details
- To complete a task: Use the complete_task tool with the task ID

The tools will be called automatically based on your function calls.`, today, string(tasksJSON), string(projectsJSON), toolsDesc.String())
}

// Create a real AI agent for testing
func createRealAgent(systemPrompt string) *ai.Agent {
	apiKey := os.Getenv("AI_TOKEN")
	if apiKey == "" {
		fmt.Println("⚠️  AI_TOKEN environment variable not set")
		return nil
	}

	endpoint := os.Getenv("AI_ENDPOINT")
	if endpoint == "" {
		endpoint = "https://llm.chutes.ai/v1/chat/completions" // default
	}

	tools := ai.CreateCRUDTools()
	agent := ai.NewAgent(apiKey, endpoint, tools, "deepseek-ai/DeepSeek-V3.1")

	return agent
}

func runIntegrationTests() {
	fmt.Println("🧪 Starting AI Tool Integration Tests")
	fmt.Println("=====================================")

	// Create mock data
	tasks, projects := createMockData()
	fmt.Printf("📊 Mock data created: %d tasks, %d projects\n", len(tasks), len(projects))

	// Build system prompt
	systemPrompt := buildMockSystemPrompt(tasks, projects)

	// Create real agent
	agent := createRealAgent(systemPrompt)
	if agent == nil {
		fmt.Println("❌ Failed to create AI agent - check environment variables")
		return
	}

	// Define test scenarios
	scenarios := []TestScenario{
		{
			Name:          "List tasks for today",
			UserInput:     "What tasks do I have for today?",
			ExpectedTools: []string{"respond"},
			Description:   "Should respond with today's tasks using mock data",
		},
		{
			Name:          "Add task for tomorrow",
			UserInput:     "Add a new task for tomorrow: Call client about proposal",
			ExpectedTools: []string{"create_task"},
			Description:   "Should call create_task tool with tomorrow's date",
		},
		{
			Name:          "Complete a task",
			UserInput:     "Mark the quarterly report task as complete",
			ExpectedTools: []string{"complete_task"},
			Description:   "Should call complete_task tool with task ID",
		},
		{
			Name:          "Create new project",
			UserInput:     "Create a new project called 'Home Renovation'",
			ExpectedTools: []string{"create_project"},
			Description:   "Should call create_project tool",
		},
		{
			Name:          "General question",
			UserInput:     "What can you help me with?",
			ExpectedTools: []string{"respond"},
			Description:   "Should respond with help information",
		},
		{
			Name:          "Update existing task",
			UserInput:     "Update the quarterly report task description",
			ExpectedTools: []string{"update_task"},
			Description:   "Should call update_task tool with task ID and new info",
		},
		{
			Name:          "Delete a task",
			UserInput:     "Delete the standup meeting task",
			ExpectedTools: []string{"delete_task"},
			Description:   "Should call delete_task tool with task ID",
		},
		{
			Name:          "Check overdue tasks",
			UserInput:     "Show me my overdue tasks",
			ExpectedTools: []string{"respond"},
			Description:   "Should respond with overdue task analysis using mock data",
		},
		{
			Name:          "Create urgent task",
			UserInput:     "Create an urgent high priority task for today",
			ExpectedTools: []string{"create_task"},
			Description:   "Should call create_task with urgent labels and today's date",
		},
	}

	// Run test scenarios
	passed := 0
	total := len(scenarios)

	for i, scenario := range scenarios {
		fmt.Printf("\n🔍 Test %d: %s\n", i+1, scenario.Name)
		fmt.Printf("   Input: %s\n", scenario.UserInput)
		fmt.Printf("   Expected tools: %v\n", scenario.ExpectedTools)

		// Call real LLM using ExecuteOneStep to get tool calls
		toolCalls, err := agent.ExecuteOneStep(scenario.UserInput)
		if err != nil {
			fmt.Printf("   ❌ FAIL - Agent execution failed: %v\n", err)
			continue
		}

		// Extract tool names from calls
		actualTools := make([]string, len(toolCalls))
		for j, call := range toolCalls {
			actualTools[j] = call.Function.Name
		}

		fmt.Printf("   Actual tools: %v\n", actualTools)

		// Check if expected tools match
		success := true
		if len(actualTools) != len(scenario.ExpectedTools) {
			success = false
		} else {
			for j, expected := range scenario.ExpectedTools {
				if j >= len(actualTools) || actualTools[j] != expected {
					success = false
					break
				}
			}
		}

		if success {
			fmt.Printf("   ✅ PASS - Correct tools called\n")
			passed++

			// Show tool details
			for _, call := range toolCalls {
				fmt.Printf("      Tool: %s\n", call.Function.Name)
				if call.Function.Arguments != "" {
					fmt.Printf("      Args: %s\n", call.Function.Arguments)
				}
			}
		} else {
			fmt.Printf("   ❌ FAIL - Expected %v, got %v\n", scenario.ExpectedTools, actualTools)
		}

		fmt.Printf("   Description: %s\n", scenario.Description)
	}

	fmt.Printf("\n📊 Test Results: %d/%d tests passed (%.1f%%)\n", passed, total, float64(passed)/float64(total)*100)

	if passed == total {
		fmt.Println("🎉 All integration tests passed!")
	} else {
		fmt.Println("⚠️  Some tests failed - check implementation")
	}
}

func main() {
	runIntegrationTests()
}
