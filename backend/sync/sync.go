// Package sync implements incremental data sync over a per-row monotonic
// revision counter. Token semantics:
//
//   - The token is a BIGINT (encoded as a string in JSON) representing
//     a high-water mark in the dimaist_revision_seq sequence.
//   - Read returns every row with revision > token, including soft-deleted
//     rows (deleted_at is set on those — clients delete their local copy).
//   - The new token is max(revision) seen in this batch, or the input token
//     if nothing changed. Always non-decreasing.
//
// Concurrency: Read runs in a REPEATABLE READ READ ONLY transaction with
// pg_advisory_xact_lock(database.SyncLockID) held against writers. The lock
// makes /sync's snapshot stable with respect to commit ordering, so a writer
// that drew revision N+1 cannot commit between sync's snapshot and the next
// poll while a writer with revision N is still in flight.
package sync

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"dimaist/database"

	"gorm.io/gorm"
)

// Page is the result of one Read call. Projects and Tasks include
// soft-deleted rows (deleted_at non-null) — clients reconcile inline.
type Page struct {
	Projects  []database.Project `json:"projects"`
	Tasks     []database.Task    `json:"tasks"`
	SyncToken int64              `json:"-"`
	HasMore   bool               `json:"has_more"`
}

// DefaultLimit caps rows returned per table per call. Picked to keep first-
// sync responses bounded; clients page via has_more.
const DefaultLimit = 1000

// Read pulls everything with revision > token. Pass token=0 for an initial
// full sync. Pass limit<=0 to use DefaultLimit.
func Read(ctx context.Context, token int64, limit int) (*Page, error) {
	if limit <= 0 {
		limit = DefaultLimit
	}
	if token < 0 {
		return nil, fmt.Errorf("sync: token must be non-negative, got %d", token)
	}

	page := &Page{SyncToken: token}

	err := database.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec("SELECT pg_advisory_xact_lock(?)", database.SyncLockID).Error; err != nil {
			return fmt.Errorf("acquire sync lock: %w", err)
		}

		// Use Unscoped so soft-deleted rows (deleted_at non-null) are
		// returned — that's how clients learn about deletions.
		if err := tx.Unscoped().
			Where("revision > ?", token).
			Order("revision ASC").
			Limit(limit).
			Find(&page.Projects).Error; err != nil {
			return fmt.Errorf("query projects: %w", err)
		}
		if err := tx.Unscoped().
			Where("revision > ?", token).
			Order("revision ASC").
			Limit(limit).
			Find(&page.Tasks).Error; err != nil {
			return fmt.Errorf("query tasks: %w", err)
		}

		page.HasMore = len(page.Projects) == limit || len(page.Tasks) == limit

		next := token
		for _, p := range page.Projects {
			if p.Revision > next {
				next = p.Revision
			}
		}
		for _, t := range page.Tasks {
			if t.Revision > next {
				next = t.Revision
			}
		}
		page.SyncToken = next

		return nil
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	if err != nil {
		return nil, err
	}
	if page == nil {
		return nil, errors.New("sync: nil page after successful read")
	}
	return page, nil
}
