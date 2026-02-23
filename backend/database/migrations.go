package database

import "dimaist/logger"

// migrateDueFields migrates from separate due_date/due_datetime columns
// to a unified due + has_time schema. Safe to run multiple times.
func migrateDueFields() error {
	// Check if old columns exist
	var count int64
	DB.Raw("SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'due_date'").Scan(&count)
	if count == 0 {
		return nil // Already migrated
	}

	logger.Info("Migrating due_date/due_datetime to due + has_time").Send()

	// Add new columns if they don't exist
	if err := DB.Exec("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due TIMESTAMP").Error; err != nil {
		return err
	}
	if err := DB.Exec("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS has_time BOOLEAN DEFAULT false").Error; err != nil {
		return err
	}

	// Copy data: due_datetime takes precedence over due_date
	if err := DB.Exec(`
		UPDATE tasks SET
			due = COALESCE(due_datetime, due_date),
			has_time = (due_datetime IS NOT NULL)
	`).Error; err != nil {
		return err
	}

	// Drop old columns
	if err := DB.Exec("ALTER TABLE tasks DROP COLUMN IF EXISTS due_date").Error; err != nil {
		return err
	}
	if err := DB.Exec("ALTER TABLE tasks DROP COLUMN IF EXISTS due_datetime").Error; err != nil {
		return err
	}

	logger.Info("Due fields migration completed").Send()
	return nil
}
