package main

import (
	"fmt"
	"time"

	"dimaist/database"
	"dimaist/utils"

	"github.com/lib/pq"
	"github.com/spf13/cobra"
)

var taskCmd = &cobra.Command{
	Use:     "task",
	Aliases: []string{"tasks"},
	Short:   "Manage tasks",
}

var taskListCmd = &cobra.Command{
	Use:   "list",
	Short: "List tasks",
	Long:  "List all tasks, optionally filtered by due date.",
	RunE: func(cmd *cobra.Command, args []string) error {
		dueFilter, _ := cmd.Flags().GetString("due")

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
					return fmt.Errorf("invalid due date (use YYYY-MM-DD or 'today'): %w", err)
				}
			}
			nextDay := dueDate.AddDate(0, 0, 1)
			query = query.Where(
				"(due_date >= ? AND due_date < ?) OR (due_datetime >= ? AND due_datetime < ?)",
				dueDate, nextDay, dueDate, nextDay,
			)
		}

		var tasks []database.Task
		if err := query.Order("\"order\"").Find(&tasks).Error; err != nil {
			return fmt.Errorf("failed to list tasks: %w", err)
		}
		printJSON(tasks)
		return nil
	},
}

var taskGetCmd = &cobra.Command{
	Use:   "get <id>",
	Short: "Get a single task",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		var taskID uint
		if _, err := fmt.Sscanf(args[0], "%d", &taskID); err != nil {
			return fmt.Errorf("invalid task ID: %w", err)
		}

		var task database.Task
		if err := database.DB.Preload("Project").Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
			return fmt.Errorf("task not found: %w", err)
		}
		printJSON(task)
		return nil
	},
}

var taskCreateCmd = &cobra.Command{
	Use:   "create",
	Short: "Create a new task",
	RunE: func(cmd *cobra.Command, args []string) error {
		title, _ := cmd.Flags().GetString("title")
		due, _ := cmd.Flags().GetString("due")
		projectID, _ := cmd.Flags().GetInt("project-id")

		if title == "" {
			return fmt.Errorf("--title is required")
		}

		task := database.Task{Title: title}

		if due != "" {
			dueDate, err := time.Parse("2006-01-02", due)
			if err != nil {
				return fmt.Errorf("invalid due date format (use YYYY-MM-DD): %w", err)
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
			return fmt.Errorf("failed to create task: %w", err)
		}
		printJSON(task)
		return nil
	},
}

var taskCompleteCmd = &cobra.Command{
	Use:   "complete <id>",
	Short: "Mark task as complete",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		var taskID uint
		if _, err := fmt.Sscanf(args[0], "%d", &taskID); err != nil {
			return fmt.Errorf("invalid task ID: %w", err)
		}

		var task database.Task
		if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
			return fmt.Errorf("task not found: %w", err)
		}

		if task.CompletedAt != nil {
			fmt.Fprintln(cmd.ErrOrStderr(), "task already completed")
			return nil
		}

		updates, isRecurring, err := database.CompleteTask(&task)
		if err != nil {
			return fmt.Errorf("failed to complete task: %w", err)
		}

		if err := database.DB.Model(&task).Updates(updates).Error; err != nil {
			return fmt.Errorf("failed to update task: %w", err)
		}

		// Reload task
		database.DB.Preload("Project").First(&task, taskID)

		result := map[string]any{
			"task":         task,
			"is_recurring": isRecurring,
		}
		printJSON(result)
		return nil
	},
}

var taskUpdateCmd = &cobra.Command{
	Use:   "update <id>",
	Short: "Update a task",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		var taskID uint
		if _, err := fmt.Sscanf(args[0], "%d", &taskID); err != nil {
			return fmt.Errorf("invalid task ID: %w", err)
		}

		var task database.Task
		if err := database.DB.Where("id = ? AND deleted_at IS NULL", taskID).First(&task).Error; err != nil {
			return fmt.Errorf("task not found: %w", err)
		}

		title, _ := cmd.Flags().GetString("title")
		due, _ := cmd.Flags().GetString("due")
		projectID, _ := cmd.Flags().GetInt("project-id")

		updates := make(map[string]any)
		if title != "" {
			updates["title"] = title
		}
		if due != "" {
			dueDate, err := time.Parse("2006-01-02", due)
			if err != nil {
				return fmt.Errorf("invalid due date format (use YYYY-MM-DD): %w", err)
			}
			updates["due_date"] = utils.NewFlexibleTime(dueDate)
		}
		if projectID > 0 {
			pid := uint(projectID)
			updates["project_id"] = &pid
		}

		if len(updates) == 0 {
			return fmt.Errorf("no fields to update")
		}

		if err := database.DB.Model(&task).Updates(updates).Error; err != nil {
			return fmt.Errorf("failed to update task: %w", err)
		}

		// Reload task
		database.DB.Preload("Project").First(&task, taskID)
		printJSON(task)
		return nil
	},
}

var taskDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete a task (soft delete)",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		var taskID uint
		if _, err := fmt.Sscanf(args[0], "%d", &taskID); err != nil {
			return fmt.Errorf("invalid task ID: %w", err)
		}

		rowsAffected, err := database.SoftDelete(&database.Task{}, taskID)
		if err != nil {
			return fmt.Errorf("failed to delete task: %w", err)
		}
		if rowsAffected == 0 {
			return fmt.Errorf("task not found")
		}
		printJSON(map[string]any{"deleted": true, "id": taskID})
		return nil
	},
}

var taskCleanupLabelsCmd = &cobra.Command{
	Use:   "cleanup-labels",
	Short: "Find and fix tasks with empty string labels",
	RunE: func(cmd *cobra.Command, args []string) error {
		var tasks []database.Task
		if err := database.DB.Where("deleted_at IS NULL AND '' = ANY(labels)").Find(&tasks).Error; err != nil {
			return fmt.Errorf("failed to query tasks: %w", err)
		}

		if len(tasks) == 0 {
			fmt.Println("No tasks with empty labels found")
			return nil
		}

		fmt.Fprintf(cmd.ErrOrStderr(), "Found %d tasks with empty labels:\n", len(tasks))
		for _, t := range tasks {
			// Filter out empty labels
			var cleaned []string
			for _, l := range t.Labels {
				if l != "" {
					cleaned = append(cleaned, l)
				}
			}
			fmt.Fprintf(cmd.ErrOrStderr(), "  [%d] %s: %v -> %v\n", t.ID, t.Description, t.Labels, cleaned)

			if err := database.DB.Model(&t).Update("labels", pq.StringArray(cleaned)).Error; err != nil {
				return fmt.Errorf("failed to update task %d: %w", t.ID, err)
			}
		}
		fmt.Fprintf(cmd.ErrOrStderr(), "Fixed %d tasks\n", len(tasks))
		return nil
	},
}

func init() {
	// task list
	taskListCmd.Flags().String("due", "", "Filter by due date (YYYY-MM-DD or 'today')")
	taskCmd.AddCommand(taskListCmd)

	// task get
	taskCmd.AddCommand(taskGetCmd)

	// task create
	taskCreateCmd.Flags().String("title", "", "Task title (required)")
	taskCreateCmd.Flags().String("due", "", "Due date (YYYY-MM-DD)")
	taskCreateCmd.Flags().Int("project-id", 0, "Project ID")
	taskCmd.AddCommand(taskCreateCmd)

	// task complete
	taskCmd.AddCommand(taskCompleteCmd)

	// task update
	taskUpdateCmd.Flags().String("title", "", "New title")
	taskUpdateCmd.Flags().String("due", "", "New due date (YYYY-MM-DD)")
	taskUpdateCmd.Flags().Int("project-id", 0, "New project ID")
	taskCmd.AddCommand(taskUpdateCmd)

	// task delete
	taskCmd.AddCommand(taskDeleteCmd)

	// task cleanup-labels
	taskCmd.AddCommand(taskCleanupLabelsCmd)
}
