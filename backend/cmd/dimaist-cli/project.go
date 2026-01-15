package main

import (
	"fmt"

	"dimaist/database"

	"github.com/spf13/cobra"
)

var projectCmd = &cobra.Command{
	Use:     "project",
	Aliases: []string{"projects"},
	Short:   "Manage projects",
}

var projectListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all projects",
	RunE: func(cmd *cobra.Command, args []string) error {
		var projects []database.Project
		if err := database.DB.Preload("Tasks", "deleted_at IS NULL").Where("deleted_at IS NULL").Order("\"order\"").Find(&projects).Error; err != nil {
			return fmt.Errorf("failed to list projects: %w", err)
		}
		printJSON(projects)
		return nil
	},
}

func init() {
	projectCmd.AddCommand(projectListCmd)
}
