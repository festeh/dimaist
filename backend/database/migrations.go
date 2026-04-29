package database

import "dimaist/logger"

// migrateRevision installs the revision column, sequence, and indexes
// that power /sync. Idempotent. Revision is bumped from Go via the
// GORM callback in RegisterSyncCallbacks, so no DB trigger is needed.
//
// Drops any previous trigger left from earlier migrations.
func migrateRevision() error {
	if err := DB.Exec("CREATE SEQUENCE IF NOT EXISTS dimaist_revision_seq").Error; err != nil {
		return err
	}

	for _, table := range []string{"projects", "tasks"} {
		if err := DB.Exec(
			"ALTER TABLE " + table + " ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0",
		).Error; err != nil {
			return err
		}
	}

	// Backfill any rows still at revision=0. Safe to re-run: only touches
	// rows that haven't been assigned yet, so reruns are no-ops.
	if err := DB.Exec(
		"UPDATE projects SET revision = nextval('dimaist_revision_seq') WHERE revision = 0",
	).Error; err != nil {
		return err
	}
	if err := DB.Exec(
		"UPDATE tasks SET revision = nextval('dimaist_revision_seq') WHERE revision = 0",
	).Error; err != nil {
		return err
	}

	// Drop trigger artifacts from the earlier (DB-driven) approach if any.
	for _, table := range []string{"projects", "tasks"} {
		trig := table + "_bump_revision"
		if err := DB.Exec("DROP TRIGGER IF EXISTS " + trig + " ON " + table).Error; err != nil {
			return err
		}
	}
	if err := DB.Exec("DROP FUNCTION IF EXISTS dimaist_bump_revision()").Error; err != nil {
		return err
	}

	logger.Info("Revision migration completed").Send()
	return nil
}

// migrateTaskProjectIDNotNull enforces that tasks.project_id is NOT NULL.
//
// The backend's CreateTask helper is supposed to default to Inbox when
// project_id is unset, but bypass paths (direct DB.Create, broken Inbox
// lookup) have leaked in 32+ orphan rows over time. The DB-level
// constraint is the only path that catches all writers.
//
// Idempotent: SET NOT NULL is a no-op if the column already has it. If
// any orphan rows still exist, they're reparented to Inbox first (or the
// migration fails loudly when no Inbox is available — surface the bug).
func migrateTaskProjectIDNotNull() error {
	if err := DB.Exec(`
		UPDATE tasks
		SET project_id = (
			SELECT id FROM projects WHERE name = 'Inbox' AND deleted_at IS NULL LIMIT 1
		)
		WHERE project_id IS NULL
	`).Error; err != nil {
		return err
	}
	if err := DB.Exec(`ALTER TABLE tasks ALTER COLUMN project_id SET NOT NULL`).Error; err != nil {
		return err
	}
	logger.Info("tasks.project_id NOT NULL constraint enforced").Send()
	return nil
}

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
