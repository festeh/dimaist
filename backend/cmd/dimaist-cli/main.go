package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"dimaist/ai"
	"dimaist/database"
	"dimaist/utils"

	"github.com/joho/godotenv"
	"github.com/lib/pq"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	resource := os.Args[1]

	// Handle 'ai' command separately (doesn't need second arg)
	if resource == "ai" {
		handleAI()
		return
	}

	if len(os.Args) < 3 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[2]

	// Load .env file
	godotenv.Load()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		fmt.Fprintf(os.Stderr, "error: DATABASE_URL environment variable is required\n")
		os.Exit(1)
	}

	if err := database.InitDBLight(databaseURL); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to connect to database: %v\n", err)
		os.Exit(1)
	}

	switch resource {
	case "task", "tasks":
		handleTask(command)
	case "project", "projects":
		handleProject(command)
	default:
		fmt.Fprintf(os.Stderr, "error: unknown resource '%s'\n", resource)
		printUsage()
		os.Exit(1)
	}
}

func handleTask(command string) {
	switch command {
	case "list":
		// Parse --due flag
		var dueFilter string
		args := os.Args[3:]
		for i := 0; i < len(args); i++ {
			if args[i] == "--due" {
				if i+1 >= len(args) {
					fmt.Fprintf(os.Stderr, "error: --due requires a value\n")
					os.Exit(1)
				}
				dueFilter = args[i+1]
				i++
			} else if strings.HasPrefix(args[i], "--") {
				fmt.Fprintf(os.Stderr, "error: unknown flag: %s\n", args[i])
				fmt.Fprintf(os.Stderr, "usage: dimaist-cli task list [--due YYYY-MM-DD|today]\n")
				os.Exit(1)
			}
		}

		query := database.DB.Preload("Project").Where("deleted_at IS NULL")

		if dueFilter != "" {
			var dueDate time.Time
			if dueFilter == "today" {
				now := time.Now()
				dueDate = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
			} else {
				var err error
				dueDate, err = time.Parse("2006-01-02", dueFilter)
				if err != nil {
					fmt.Fprintf(os.Stderr, "error: invalid due date (use YYYY-MM-DD or 'today'): %v\n", err)
					os.Exit(1)
				}
			}
			nextDay := dueDate.AddDate(0, 0, 1)
			query = query.Where(
				"(due_date >= ? AND due_date < ?) OR (due_datetime >= ? AND due_datetime < ?)",
				dueDate, nextDay, dueDate, nextDay,
			)
		}

		var tasks []database.Task
		result := query.Order("\"order\"").Find(&tasks)
		if result.Error != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", result.Error)
			os.Exit(1)
		}
		printJSON(tasks)

	case "get":
		if len(os.Args) < 4 {
			fmt.Fprintf(os.Stderr, "error: task get requires task ID\n")
			fmt.Fprintf(os.Stderr, "usage: dimaist-cli task get <id>\n")
			os.Exit(1)
		}
		taskID, err := strconv.ParseUint(os.Args[3], 10, 32)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: invalid task ID: %v\n", err)
			os.Exit(1)
		}
		var task database.Task
		result := database.DB.Preload("Project").Where("id = ? AND deleted_at IS NULL", taskID).First(&task)
		if result.Error != nil {
			fmt.Fprintf(os.Stderr, "error: task not found: %v\n", result.Error)
			os.Exit(1)
		}
		printJSON(task)

	case "create":
		args := os.Args[3:]
		title, due, projectID := parseTaskFlags(args)
		if title == "" {
			fmt.Fprintf(os.Stderr, "error: --title is required\n")
			fmt.Fprintf(os.Stderr, "usage: dimaist-cli task create --title \"...\" [--due YYYY-MM-DD] [--project-id N]\n")
			os.Exit(1)
		}

		task := database.Task{Title: title}

		if due != "" {
			dueDate, err := time.Parse("2006-01-02", due)
			if err != nil {
				fmt.Fprintf(os.Stderr, "error: invalid due date format (use YYYY-MM-DD): %v\n", err)
				os.Exit(1)
			}
			task.DueDate = utils.NewFlexibleTime(dueDate)
		}

		if projectID > 0 {
			pid := uint(projectID)
			task.ProjectID = &pid
		} else {
			// Default to Inbox
			var inbox database.Project
			if err := database.DB.Where("name = ? AND deleted_at IS NULL", "Inbox").First(&inbox).Error; err == nil {
				task.ProjectID = &inbox.ID
			}
		}

		if err := database.CreateTask(&task); err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to create task: %v\n", err)
			os.Exit(1)
		}
		printJSON(task)

	case "complete":
		if len(os.Args) < 4 {
			fmt.Fprintf(os.Stderr, "error: task complete requires task ID\n")
			fmt.Fprintf(os.Stderr, "usage: dimaist-cli task complete <id>\n")
			os.Exit(1)
		}
		taskID, err := strconv.ParseUint(os.Args[3], 10, 32)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: invalid task ID: %v\n", err)
			os.Exit(1)
		}

		var task database.Task
		if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
			fmt.Fprintf(os.Stderr, "error: task not found: %v\n", err)
			os.Exit(1)
		}

		if task.CompletedAt != nil {
			fmt.Fprintf(os.Stderr, "task already completed\n")
			os.Exit(0)
		}

		updates, isRecurring, err := database.CompleteTask(&task)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to complete task: %v\n", err)
			os.Exit(1)
		}

		if err := database.DB.Model(&task).Updates(updates).Error; err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to update task: %v\n", err)
			os.Exit(1)
		}

		// Reload task
		database.DB.Preload("Project").First(&task, taskID)

		result := map[string]any{
			"task":        task,
			"is_recurring": isRecurring,
		}
		printJSON(result)

	case "update":
		if len(os.Args) < 4 {
			fmt.Fprintf(os.Stderr, "error: task update requires task ID\n")
			fmt.Fprintf(os.Stderr, "usage: dimaist-cli task update <id> [--title \"...\"] [--due YYYY-MM-DD] [--project-id N]\n")
			os.Exit(1)
		}
		taskID, err := strconv.ParseUint(os.Args[3], 10, 32)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: invalid task ID: %v\n", err)
			os.Exit(1)
		}

		var task database.Task
		if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
			fmt.Fprintf(os.Stderr, "error: task not found: %v\n", err)
			os.Exit(1)
		}

		args := os.Args[4:]
		title, due, projectID := parseTaskFlags(args)

		updates := make(map[string]any)
		if title != "" {
			updates["title"] = title
		}
		if due != "" {
			dueDate, err := time.Parse("2006-01-02", due)
			if err != nil {
				fmt.Fprintf(os.Stderr, "error: invalid due date format (use YYYY-MM-DD): %v\n", err)
				os.Exit(1)
			}
			updates["due_date"] = utils.NewFlexibleTime(dueDate)
		}
		if projectID > 0 {
			pid := uint(projectID)
			updates["project_id"] = &pid
		}

		if len(updates) == 0 {
			fmt.Fprintf(os.Stderr, "error: no fields to update\n")
			os.Exit(1)
		}

		if err := database.DB.Model(&task).Updates(updates).Error; err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to update task: %v\n", err)
			os.Exit(1)
		}

		// Reload task
		database.DB.Preload("Project").First(&task, taskID)
		printJSON(task)

	case "delete":
		if len(os.Args) < 4 {
			fmt.Fprintf(os.Stderr, "error: task delete requires task ID\n")
			fmt.Fprintf(os.Stderr, "usage: dimaist-cli task delete <id>\n")
			os.Exit(1)
		}
		taskID, err := strconv.ParseUint(os.Args[3], 10, 32)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: invalid task ID: %v\n", err)
			os.Exit(1)
		}

		rowsAffected, err := database.SoftDelete(&database.Task{}, uint(taskID))
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to delete task: %v\n", err)
			os.Exit(1)
		}
		if rowsAffected == 0 {
			fmt.Fprintf(os.Stderr, "error: task not found\n")
			os.Exit(1)
		}
		printJSON(map[string]any{"deleted": true, "id": taskID})

	case "cleanup-labels":
		// Find and fix tasks with empty string labels
		var tasks []database.Task
		result := database.DB.Where("deleted_at IS NULL AND '' = ANY(labels)").Find(&tasks)
		if result.Error != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", result.Error)
			os.Exit(1)
		}

		if len(tasks) == 0 {
			fmt.Println("No tasks with empty labels found")
			return
		}

		fmt.Fprintf(os.Stderr, "Found %d tasks with empty labels:\n", len(tasks))
		for _, t := range tasks {
			// Filter out empty labels
			var cleaned []string
			for _, l := range t.Labels {
				if l != "" {
					cleaned = append(cleaned, l)
				}
			}
			fmt.Fprintf(os.Stderr, "  [%d] %s: %v -> %v\n", t.ID, t.Description, t.Labels, cleaned)

			// Update in database using pq.StringArray for proper serialization
			if err := database.DB.Model(&t).Update("labels", pq.StringArray(cleaned)).Error; err != nil {
				fmt.Fprintf(os.Stderr, "error updating task %d: %v\n", t.ID, err)
				os.Exit(1)
			}
		}
		fmt.Fprintf(os.Stderr, "Fixed %d tasks\n", len(tasks))

	default:
		fmt.Fprintf(os.Stderr, "error: unknown command '%s' for task\n", command)
		os.Exit(1)
	}
}

// parseTaskFlags extracts --title, --due, and --project-id from args
func parseTaskFlags(args []string) (title, due string, projectID int) {
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--title":
			if i+1 < len(args) {
				title = args[i+1]
				i++
			}
		case "--due":
			if i+1 < len(args) {
				due = args[i+1]
				i++
			}
		case "--project-id":
			if i+1 < len(args) {
				if id, err := strconv.Atoi(args[i+1]); err == nil {
					projectID = id
				}
				i++
			}
		}
	}
	return
}

func handleProject(command string) {
	switch command {
	case "list":
		var projects []database.Project
		result := database.DB.Preload("Tasks", "deleted_at IS NULL").Where("deleted_at IS NULL").Order("\"order\"").Find(&projects)
		if result.Error != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", result.Error)
			os.Exit(1)
		}
		printJSON(projects)
	default:
		fmt.Fprintf(os.Stderr, "error: unknown command '%s' for project\n", command)
		os.Exit(1)
	}
}

func printJSON(v any) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(v); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to encode JSON: %v\n", err)
		os.Exit(1)
	}
}

func handleAI() {
	var userInput string
	includeCompleted := false

	// Parse --include-completed flag
	args := os.Args[2:]
	var filteredArgs []string
	for _, arg := range args {
		if arg == "--include-completed" {
			includeCompleted = true
		} else {
			filteredArgs = append(filteredArgs, arg)
		}
	}

	// Check if input provided as args
	if len(filteredArgs) > 0 {
		userInput = strings.Join(filteredArgs, " ")
	} else {
		// Read from stdin
		fmt.Fprint(os.Stderr, "Enter message: ")
		reader := bufio.NewReader(os.Stdin)
		input, err := reader.ReadString('\n')
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: failed to read input: %v\n", err)
			os.Exit(1)
		}
		userInput = strings.TrimSpace(input)
	}

	if userInput == "" {
		fmt.Fprintf(os.Stderr, "error: message cannot be empty\n")
		os.Exit(1)
	}

	// Load .env and connect to database for context
	godotenv.Load()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		fmt.Fprintf(os.Stderr, "error: DATABASE_URL environment variable is required\n")
		os.Exit(1)
	}

	if err := database.InitDBLight(databaseURL); err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to connect to database: %v\n", err)
		os.Exit(1)
	}

	// Load tasks and projects using ai package
	tasks, err := ai.LoadRecentTasks(1000, includeCompleted)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to load tasks: %v\n", err)
		os.Exit(1)
	}

	projects, err := ai.LoadRecentProjects(100)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to load projects: %v\n", err)
		os.Exit(1)
	}

	// Build system prompt using ai package (no current project context in CLI)
	systemPrompt, err := ai.BuildSystemPrompt(tasks, projects, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to build system prompt: %v\n", err)
		os.Exit(1)
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
}

func printUsage() {
	fmt.Fprintf(os.Stderr, `Usage: dimaist-cli <resource> <command> [args]

Resources:
  task, tasks       Manage tasks
  project, projects Manage projects
  ai                Generate AI request

Task Commands:
  list [--due YYYY-MM-DD|today]           List tasks (optionally filter by due date)
  get <id>                                Get a single task
  create --title "..." [--due YYYY-MM-DD] [--project-id N]
                                          Create a new task
  complete <id>                           Mark task as complete
  update <id> [--title "..."] [--due YYYY-MM-DD] [--project-id N]
                                          Update a task
  delete <id>                             Delete a task (soft delete)

Project Commands:
  list                                    List all projects

AI Commands:
  ai "message"                            Generate AI request with tools
  ai --include-completed "message"        Include completed tasks in context

Examples:
  dimaist-cli task list
  dimaist-cli task list --due today
  dimaist-cli task create --title "Buy milk" --due 2026-01-15
  dimaist-cli task complete 42
  dimaist-cli task update 42 --title "Buy groceries"
  dimaist-cli task delete 42
  dimaist-cli project list
  dimaist-cli ai "add task buy milk tomorrow"
`)
}
