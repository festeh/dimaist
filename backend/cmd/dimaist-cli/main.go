package main

import (
	"encoding/json"
	"fmt"
	"os"

	"dimaist/database"

	"github.com/joho/godotenv"
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "dimaist-cli",
	Short: "CLI for Dimaist task management",
	Long:  "A command-line interface for managing tasks, projects, and AI interactions in Dimaist.",
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		// Skip DB init for help commands
		if cmd.Name() == "help" || cmd.Name() == "completion" {
			return nil
		}

		godotenv.Load()

		databaseURL := os.Getenv("DATABASE_URL")
		if databaseURL == "" {
			return fmt.Errorf("DATABASE_URL environment variable is required")
		}

		if err := database.InitDBLight(databaseURL); err != nil {
			return fmt.Errorf("failed to connect to database: %w", err)
		}

		return nil
	},
}

func init() {
	rootCmd.AddCommand(taskCmd)
	rootCmd.AddCommand(projectCmd)
	rootCmd.AddCommand(aiCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
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
