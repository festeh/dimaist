# Plan: Sound Sync System

**Branch**: `sound-sync-system`
**Spec**: none (requirements captured in Goals below)

## Goals

The current `GET /sync` endpoint has correctness bugs that will eventually surface as lost or duplicated updates. We want a sync that is:

1. **Correct under concurrent writes.** No lost updates, no duplicated rows.
2. **Cheap.** Polling with no changes returns near-empty.
3. **Simple to reason about.** One source of truth for "what changed since X".
4. **Honest about deletes.** Soft-deletes propagate to clients reliably.

Non-goals: push notifications, multi-user, conflict resolution. This is a single-user system; clients are read-mostly mirrors.

## Current bugs (recap)

In `backend/sync.go`:

- **Token race.** `newSyncToken = time.Now()` is taken *after* queries finish; writes that commit during the query window get `updated_at <= newSyncToken` and are silently skipped on the next poll.
- **Second precision** (`time.RFC3339`) splits same-second writes across syncs.
- **Strict `>` boundary** combined with second precision drops items created at exactly the token instant.
- **Deletes never reported.** GORM auto-injects `deleted_at IS NULL` into every `.Find()`, which AND-s with the explicit `deleted_at > ?` and yields an empty set. The deleted-IDs arrays are always `[]`.
- **Duplicated payload.** `Preload("Tasks", ...)` returns each project's children, then top-level `tasks` returns them again.
- **Project bump re-sends children.** Renaming a project ships every task under it because of the preload.
- **No transactional snapshot.** Four independent queries; a write in between can leak inconsistency to the client.
- **Indexes unconfirmed** on `updated_at` / `deleted_at`.

## Tech Stack

- **Backend**: Go (Chi, GORM), PostgreSQL.
- **Schema change**: one new column + one trigger + one sequence.
- **Clients**: Flutter (`frontend/`), `coach` (Go), `dimaist_client` (Python). All consume `/sync`; all need a one-time full re-sync after deploy.

## Design

### Token: monotonic per-row revision

Replace timestamp-based sync with a per-row monotonic `revision` integer.

- New column `revision BIGINT NOT NULL` on `projects` and `tasks`.
- New sequence `dimaist_revision_seq` (shared across both tables — gives a single global ordering).
- Triggers `BEFORE INSERT OR UPDATE` set `NEW.revision = nextval('dimaist_revision_seq')`. Soft-deletes are `UPDATE`s, so they bump revision automatically.
- Index `(revision)` on both tables.
- Token is a `BIGINT` serialized as a string (so we can change format later without breaking JSON typing). `"0"` or empty means "first sync, send everything".

Why a shared sequence over a per-table one: lets the client treat `sync_token` as a single high-water mark across all entities. Simpler client logic.

### Concurrency: stop the lost-update race

The classic sequence race: writer W1 reserves revision=42 but commits *after* W2 (revision=43). A naive sync between W2's commit and W1's commit sets token=43 and never sees revision=42.

Fix with **two layers**:

1. **REPEATABLE READ snapshot.** Run sync inside a `BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY` transaction. All `SELECT`s see the same snapshot. Anything that commits after our first `SELECT` is invisible to us, but its revision is *also* not in our result set, so our returned `max(revision)` won't lie about it.
2. **Advisory lock against in-flight writes.** Every write transaction takes `pg_advisory_xact_lock(SYNC_LOCK_ID)` immediately after `BEGIN`, before any DML. Sync transaction takes the same lock before its first `SELECT`. This serializes sync against the *commit phase* of writes, defeating the W1/W2 race entirely — by the time sync's snapshot is taken, every transaction that already drew a revision has committed (or rolled back).

The advisory lock is cheap — it's a single fast Postgres call and writes are infrequent. The lock is `xact`-scoped, released automatically on commit.

### Response shape

Drop the parallel "deleted_ids" arrays. Return soft-deleted rows directly with `deleted_at` set.

```jsonc
{
  "projects": [ /* rows where revision > token, including soft-deleted */ ],
  "tasks":    [ /* rows where revision > token, including soft-deleted */ ],
  "sync_token": "12345",
  "has_more": false
}
```

- No `Preload`. Tasks are returned as their own list with `project_id`; clients join locally.
- Soft-deleted rows have non-null `deleted_at`; client deletes its local copy.
- Pagination: `LIMIT 1000` per table, ordered by `revision ASC`. If a query hits the limit, `has_more = true` and the client polls again with the new token. Prevents OOM on the very first sync of large datasets.

### `sync.go` rewrite (deep module shape)

Move logic into `backend/sync/` package with a clear interface:

```go
package sync

type Token int64
type Page struct {
    Projects []database.Project
    Tasks    []database.Task
    NextToken Token
    HasMore  bool
}

func Read(ctx context.Context, token Token, limit int) (*Page, error)
```

The HTTP handler in `backend/sync.go` becomes a thin parse+call+respond wrapper. The transaction, locking, query, and pagination logic lives in `Read`. Clean to test.

### Write-side changes

Every mutating handler (`tasks.go`, `projects.go`, `search.go` if it writes, `database/task_operations.go`, `database/soft_delete.go`) needs to take the advisory lock. Two options:

- **A. Wrap the DB handle.** Add `database.WriteTx(ctx, func(tx *gorm.DB) error)` that begins a transaction, takes the advisory lock, runs the callback, commits. Migrate all writes to use it.
- **B. GORM `BeforeSave` hook on Project/Task.** Convenient but doesn't cover raw `DB.Exec` or multi-statement updates inside a single transaction.

Recommend **A**. It's a "deep module" change in the spirit of `IMPLEMENTATION.md`: writers stop knowing about transactions and locks; they just hand the engine a closure.

### Migration

Single migration in `backend/database/migrations.go`:

1. `CREATE SEQUENCE IF NOT EXISTS dimaist_revision_seq;`
2. `ALTER TABLE projects ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0;`
3. `ALTER TABLE tasks ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0;`
4. Backfill: `UPDATE projects SET revision = nextval('dimaist_revision_seq');` then `UPDATE tasks SET revision = nextval('dimaist_revision_seq');` — order is irrelevant since clients re-sync from `0`.
5. `CREATE INDEX IF NOT EXISTS idx_projects_revision ON projects(revision);` and same for tasks.
6. Install trigger function:
   ```sql
   CREATE OR REPLACE FUNCTION bump_revision() RETURNS TRIGGER AS $$
   BEGIN NEW.revision := nextval('dimaist_revision_seq'); RETURN NEW; END;
   $$ LANGUAGE plpgsql;
   ```
7. Attach `BEFORE INSERT OR UPDATE` triggers to both tables.

Idempotent and safe to re-run.

## Structure

```
backend/
├── sync/
│   ├── sync.go            # Read() — REPEATABLE READ + advisory lock + queries
│   ├── sync_test.go       # concurrency tests with goroutines
│   └── lock.go            # advisory lock IDs as named constants
├── database/
│   ├── migrations.go      # add revision migration + trigger install
│   ├── tx.go              # NEW: WriteTx() helper that takes the lock
│   └── models.go          # add Revision field to Project/Task
├── tasks.go               # migrate writes to WriteTx
├── projects.go            # migrate writes to WriteTx
├── sync.go                # thin HTTP handler around sync.Read()
└── main.go                # unchanged
```

Frontend / coach / Python client:

- `frontend/lib/models/sync_response.dart`: drop `deletedProjectIds`/`deletedTaskIds`, add `hasMore`. Token type stays `String`.
- `frontend/lib/providers/task_provider.dart` / `project_provider.dart`: handle soft-deleted rows inline; loop on `hasMore`. One-time clear of stored `sync_token` (so old timestamps don't get sent to the new endpoint).
- `coach/internal/dimaist/client.go`: same response shape change. Coach uses sync to find today's tasks — verify it still works after the change.
- `dimaist_client/__init__.py`: same. Update return type.

## Approach

### Phase 1 — backend correctness (no client changes yet)

1. Migration: revision column, sequence, trigger, indexes.
2. New `sync` package with `Read()`. Old `/sync` handler keeps the legacy response shape but is sourced from the new engine. Adds `revision` field to rows but nothing else changes for clients yet. Goal: prove correctness under concurrent writes with a Go test.
3. `database.WriteTx` helper. Migrate `tasks.go`, `projects.go`, `database/soft_delete.go`, `database/task_operations.go` to use it. The advisory lock is now taken on every write.
4. Concurrency test: spawn N goroutines doing writes while a goroutine polls `/sync`; assert no revision is missed and `max(token)` is monotonic.

### Phase 2 — new response shape

5. Change `/sync` response: drop `deleted_*_ids`, drop preloads, add `has_more`. Soft-deleted rows ship inline.
6. Update Flutter, coach, Python client. Each clears its stored token once on first launch with the new version.
7. Pagination: enforce `LIMIT 1000`. Confirm clients loop on `has_more`.

### Phase 3 — cleanup

8. Drop `updated_at`-based filtering everywhere it remains. `updated_at` stays on rows (useful as audit) but is no longer sync-relevant.
9. Document the contract in `backend/sync/README.md` (one paragraph): token semantics, concurrency model, why advisory lock.

## Testing

- **Unit**: `sync_test.go` runs against a real Postgres test DB (matches existing `tests/` style). Cases:
  - Empty DB → `token=0` returns nothing, new token=0.
  - Insert row → first sync returns it, second sync returns nothing.
  - Insert N rows past pagination limit → `has_more=true`, second call drains.
  - Soft-delete a row → returned with `deleted_at` set on next sync.
  - Concurrent writes (10 goroutines × 100 inserts) interleaved with sync polling → no row missed, no duplicate, monotonic token.
- **Integration**: existing `tests/context_integration_test.go` style; bring up Postgres via testcontainers or a known local DSN.

## Risks

- **Existing data on prod (your laptop) gets new revision values.** First post-deploy sync from any client must be a full re-sync. Mitigation: clients clear their stored token on version bump. Document in release notes.
- **Trigger overhead.** A `BEFORE INSERT OR UPDATE` trigger on every write costs a `nextval()` call. Negligible (microseconds), but noted.
- **Advisory lock contention.** If a write transaction is held open accidentally (e.g., a long-running migration), sync blocks. Mitigation: use `pg_try_advisory_xact_lock` with a short retry loop in sync; or set a statement timeout. Start with the blocking version, switch only if it bites.
- **`UpdatedAt` may diverge from `revision`.** Some clients (or human eyes) may have used `updated_at` as a proxy for "last touched". Confirm none of them rely on second-precision behavior — the trigger keeps `updated_at` working as before via GORM's existing auto-update.
- **Cross-table revision ordering is artificial.** Sharing one sequence means a project insert and a task insert get globally ordered, even though they're independent. Functionally fine — the client doesn't care about cross-table ordering — but worth knowing so we don't get confused by gaps in per-table revisions.
- **Coach uses `/sync` for "tasks since start of today".** It currently passes a timestamp. After this change, `coach` must either pass `0` (full re-sync each call) or maintain its own cached `revision`. Verify and update.

## Open Questions

- **Single sequence vs per-table sequences?** Plan picks shared. Alternative: per-table tokens combined into a struct token. Less surprising for backend devs reading the DB. Cleaner cross-table ordering vs simpler tokens — pick simpler.
- **Should the sync transaction read from a hot standby/replica?** No — single Postgres, no replicas. Skip.
- **Do we want a `since_id` cursor in addition to a revision token?** Useful if we add per-entity endpoints (e.g. `/tasks?since=X`). Out of scope — wait for a real need.
- **Do we keep `/sync` versioned (e.g. `/v2/sync`) or hard-cut?** Recommend hard-cut. All clients are first-party and we control rollout. The IMPLEMENTATION rule says no compat shims. Add a `version` field to the response so future changes can be detected.

## Order of Implementation

1. Migration + trigger (Phase 1, step 1).
2. `sync.Read()` + handler reuse (steps 2).
3. `database.WriteTx` + writer migration (step 3).
4. Concurrency test (step 4) — gate Phase 2 on this passing.
5. Response-shape change (steps 5–7) across backend + 3 clients in lockstep.
6. Cleanup + docs (steps 8–9).
