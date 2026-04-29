package database

import (
	"fmt"

	"gorm.io/gorm"
)

// SyncLockID is the application-wide pg_advisory_xact_lock key that
// serializes writers against /sync readers. Picked as the ASCII bytes
// "DIMASYNC" so it's recognizable in pg_locks dumps.
const SyncLockID int64 = 0x44494D4153594E43

// WriteTx runs fn inside a single transaction. Useful when callers need
// multiple writes to share one commit — the GORM callbacks installed by
// RegisterSyncCallbacks already cover single-statement writes. Advisory
// locks are re-entrant within a session, so nesting is safe.
func WriteTx(fn func(tx *gorm.DB) error) error {
	return DB.Transaction(fn)
}

// RegisterSyncCallbacks installs the GORM callbacks that power /sync:
//
//   - Every Create/Update/Delete acquires pg_advisory_xact_lock so
//     /sync's REPEATABLE READ snapshot is consistent with commit order.
//   - Every Create/Update allocates the next revision via nextval() and
//     puts it on the statement so both the DB row and the in-memory
//     struct see the correct value.
//
// Postgres sequences advance independent of transaction outcome, so a
// rolled-back write burns its revision number — that's expected. The
// advisory lock is xact-scoped: released automatically on commit/rollback
// and re-entrant within the same session, so nested WriteTx calls work.
func RegisterSyncCallbacks(db *gorm.DB) error {
	lock := func(d *gorm.DB) error {
		if err := d.Exec("SELECT pg_advisory_xact_lock(?)", SyncLockID).Error; err != nil {
			return fmt.Errorf("acquire sync lock: %w", err)
		}
		return nil
	}

	bumpRevision := func(d *gorm.DB) {
		if err := lock(d); err != nil {
			_ = d.AddError(err)
			return
		}
		var rev int64
		row := d.Statement.ConnPool.QueryRowContext(
			d.Statement.Context,
			"SELECT nextval('dimaist_revision_seq')",
		)
		if err := row.Scan(&rev); err != nil {
			_ = d.AddError(fmt.Errorf("allocate revision: %w", err))
			return
		}
		d.Statement.SetColumn("revision", rev)
	}

	lockOnly := func(d *gorm.DB) {
		if err := lock(d); err != nil {
			_ = d.AddError(err)
		}
	}

	if err := db.Callback().Create().Before("gorm:before_create").Register("dimaist:sync_revision", bumpRevision); err != nil {
		return err
	}
	if err := db.Callback().Update().Before("gorm:before_update").Register("dimaist:sync_revision", bumpRevision); err != nil {
		return err
	}
	// Delete: soft-deletes go through the Update path (with deleted_at),
	// so the bumpRevision callback already covers them. Hard deletes
	// (Unscoped().Delete) destroy the row, so there's nothing to bump —
	// just take the lock so /sync sees the deletion atomically.
	if err := db.Callback().Delete().Before("gorm:before_delete").Register("dimaist:sync_lock", lockOnly); err != nil {
		return err
	}
	return nil
}
