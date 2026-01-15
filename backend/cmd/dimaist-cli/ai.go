package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"dimaist/ai"

	"github.com/spf13/cobra"
)

var aiCmd = &cobra.Command{
	Use:   "ai [message]",
	Short: "Generate AI request with tools",
	Long:  "Generate an AI request with task management tools and context. Message can be provided as argument or via stdin.",
	RunE: func(cmd *cobra.Command, args []string) error {
		includeCompleted, _ := cmd.Flags().GetBool("include-completed")

		var userInput string
		if len(args) > 0 {
			userInput = strings.Join(args, " ")
		} else {
			// Read from stdin
			fmt.Fprint(os.Stderr, "Enter message: ")
			reader := bufio.NewReader(os.Stdin)
			input, err := reader.ReadString('\n')
			if err != nil {
				return fmt.Errorf("failed to read input: %w", err)
			}
			userInput = strings.TrimSpace(input)
		}

		if userInput == "" {
			return fmt.Errorf("message cannot be empty")
		}

		// Load tasks and projects using ai package
		tasks, err := ai.LoadRecentTasks(1000, includeCompleted)
		if err != nil {
			return fmt.Errorf("failed to load tasks: %w", err)
		}

		projects, err := ai.LoadRecentProjects(100)
		if err != nil {
			return fmt.Errorf("failed to load projects: %w", err)
		}

		// Build system prompt using ai package (no current project context in CLI)
		systemPrompt, err := ai.BuildSystemPrompt(tasks, projects, nil)
		if err != nil {
			return fmt.Errorf("failed to build system prompt: %w", err)
		}

		// Build LLM request (model set via general CLI's -t flag)
		request := map[string]any{
			"messages": []map[string]string{
				{"role": "system", "content": systemPrompt},
				{"role": "user", "content": userInput},
			},
			"tools":       ai.GetToolDefinitions(),
			"tool_choice": "auto",
		}

		printJSON(request)
		return nil
	},
}

func init() {
	aiCmd.Flags().Bool("include-completed", false, "Include completed tasks in context")
}
