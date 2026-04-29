package sync

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"dimaist/database"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

// setupPostgres connects to DIMAIST_TEST_DATABASE_URL, drops any existing
// dimaist tables/sequence in that database, then re-runs the production
// migration path. Skips the test if the env var is not set.
//
// The test database is destroyed at end of run via t.Cleanup. Never point
// this at a database you care about.
func setupPostgres(t *testing.T) {
	t.Helper()
	dsn := os.Getenv("DIMAIST_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("DIMAIST_TEST_DATABASE_URL not set; skipping Postgres-backed sync test")
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: gormlogger.Default.LogMode(gormlogger.Silent),
	})
	if err != nil {
		t.Fatalf("connect: %v", err)
	}

	// Hard reset: drop everything we own, then run InitDB-equivalent setup.
	// Includes legacy trigger artifacts in case the test DB still has them
	// from an earlier schema.
	for _, stmt := range []string{
		`DROP TRIGGER IF EXISTS projects_bump_revision ON projects`,
		`DROP TRIGGER IF EXISTS tasks_bump_revision ON tasks`,
		`DROP TABLE IF EXISTS tasks CASCADE`,
		`DROP TABLE IF EXISTS projects CASCADE`,
		`DROP FUNCTION IF EXISTS dimaist_bump_revision()`,
		`DROP SEQUENCE IF EXISTS dimaist_revision_seq`,
	} {
		if err := db.Exec(stmt).Error; err != nil {
			t.Fatalf("reset (%q): %v", stmt, err)
		}
	}

	database.DB = db
	if err := db.AutoMigrate(&database.Project{}, &database.Task{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}
	if err := runMigrateRevision(db); err != nil {
		t.Fatalf("migrate revision: %v", err)
	}
	if err := database.RegisterSyncCallbacks(db); err != nil {
		t.Fatalf("register callbacks: %v", err)
	}

	t.Cleanup(func() {
		// Best-effort teardown so a re-run starts fresh.
		_ = db.Exec(`DROP TABLE IF EXISTS tasks CASCADE`).Error
		_ = db.Exec(`DROP TABLE IF EXISTS projects CASCADE`).Error
		_ = db.Exec(`DROP SEQUENCE IF EXISTS dimaist_revision_seq`).Error
	})
}

// runMigrateRevision is a private mirror of database.migrateRevision,
// duplicated here so the test can run without exporting the migration
// function. Keep in sync with backend/database/migrations.go.
func runMigrateRevision(db *gorm.DB) error {
	stmts := []string{
		`CREATE SEQUENCE IF NOT EXISTS dimaist_revision_seq`,
		`ALTER TABLE projects ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0`,
		`ALTER TABLE tasks ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0`,
		`UPDATE projects SET revision = nextval('dimaist_revision_seq') WHERE revision = 0`,
		`UPDATE tasks SET revision = nextval('dimaist_revision_seq') WHERE revision = 0`,
	}
	for _, s := range stmts {
		if err := db.Exec(s).Error; err != nil {
			return fmt.Errorf("%s: %w", s, err)
		}
	}
	return nil
}

func TestRead_BasicIncremental(t *testing.T) {
	setupPostgres(t)
	ctx := context.Background()

	// Empty DB → no rows, token unchanged.
	page, err := Read(ctx, 0, 0)
	if err != nil {
		t.Fatalf("read empty: %v", err)
	}
	if len(page.Projects) != 0 || len(page.Tasks) != 0 {
		t.Fatalf("empty DB returned rows: %+v", page)
	}
	if page.SyncToken != 0 {
		t.Fatalf("empty token should be 0, got %d", page.SyncToken)
	}

	// Insert a project. First sync sees it.
	p := &database.Project{Name: "P1", Color: "blue"}
	if err := database.DB.Create(p).Error; err != nil {
		t.Fatalf("create project: %v", err)
	}

	page, err = Read(ctx, 0, 0)
	if err != nil {
		t.Fatalf("read after insert: %v", err)
	}
	if len(page.Projects) != 1 || page.Projects[0].Name != "P1" {
		t.Fatalf("expected one project P1, got %+v", page.Projects)
	}
	tok1 := page.SyncToken
	if tok1 == 0 {
		t.Fatalf("token should advance after insert")
	}

	// Second sync with tok1 → no rows.
	page, err = Read(ctx, tok1, 0)
	if err != nil {
		t.Fatalf("read after token: %v", err)
	}
	if len(page.Projects) != 0 || len(page.Tasks) != 0 {
		t.Fatalf("expected empty delta, got %+v", page)
	}
	if page.SyncToken != tok1 {
		t.Fatalf("token should be unchanged when nothing new, got %d want %d", page.SyncToken, tok1)
	}

	// Update the project. Sync sees it again with a higher revision.
	if err := database.DB.Model(&database.Project{}).Where("id = ?", p.ID).Update("color", "red").Error; err != nil {
		t.Fatalf("update: %v", err)
	}
	page, err = Read(ctx, tok1, 0)
	if err != nil {
		t.Fatalf("read after update: %v", err)
	}
	if len(page.Projects) != 1 || page.Projects[0].Color != "red" {
		t.Fatalf("expected updated project, got %+v", page.Projects)
	}
	if page.SyncToken <= tok1 {
		t.Fatalf("token should advance, got %d want > %d", page.SyncToken, tok1)
	}
}

func TestRead_SoftDeletePropagates(t *testing.T) {
	setupPostgres(t)
	ctx := context.Background()

	p := &database.Project{Name: "to-delete"}
	if err := database.DB.Create(p).Error; err != nil {
		t.Fatalf("create: %v", err)
	}

	page, _ := Read(ctx, 0, 0)
	tok := page.SyncToken

	// Soft delete via the production helper.
	if _, err := database.SoftDelete(&database.Project{}, p.ID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	page, err := Read(ctx, tok, 0)
	if err != nil {
		t.Fatalf("read after delete: %v", err)
	}
	if len(page.Projects) != 1 {
		t.Fatalf("expected soft-deleted row in page, got %+v", page.Projects)
	}
	if page.Projects[0].DeletedAt == nil {
		t.Fatalf("expected deleted_at set, got nil")
	}
}

func TestRead_Pagination(t *testing.T) {
	setupPostgres(t)
	ctx := context.Background()

	// Insert 5 projects, page with limit=2.
	for i := 0; i < 5; i++ {
		p := &database.Project{Name: fmt.Sprintf("p%d", i)}
		if err := database.DB.Create(p).Error; err != nil {
			t.Fatalf("create %d: %v", i, err)
		}
	}

	var collected []database.Project
	token := int64(0)
	for {
		page, err := Read(ctx, token, 2)
		if err != nil {
			t.Fatalf("read page: %v", err)
		}
		collected = append(collected, page.Projects...)
		if !page.HasMore {
			break
		}
		if page.SyncToken == token {
			t.Fatalf("token didn't advance with has_more=true, infinite loop")
		}
		token = page.SyncToken
	}
	if len(collected) != 5 {
		t.Fatalf("expected 5 projects via pagination, got %d", len(collected))
	}
}

// TestRead_ConcurrentWrites stresses the advisory-lock invariant. While many
// goroutines insert tasks, a polling reader must never miss a committed row.
func TestRead_ConcurrentWrites(t *testing.T) {
	setupPostgres(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	const writers = 8
	const insertsPerWriter = 50
	const totalInserts = writers * insertsPerWriter

	// One project all tasks attach to.
	parent := &database.Project{Name: "parent"}
	if err := database.DB.Create(parent).Error; err != nil {
		t.Fatalf("create parent: %v", err)
	}

	var (
		writeWG    sync.WaitGroup
		readDone   = make(chan struct{})
		seenTaskID sync.Map // map[uint]bool
		readErr    atomic.Value
		writesDone atomic.Bool
	)

	// Reader: poll until writer-side signals done AND one final drain returns
	// nothing new. Verify monotonic token throughout.
	go func() {
		defer close(readDone)
		var token int64
		var lastToken int64
		for {
			page, err := Read(ctx, token, 1000)
			if err != nil {
				readErr.Store(err)
				return
			}
			if page.SyncToken < lastToken {
				readErr.Store(errors.New("token went backwards"))
				return
			}
			lastToken = page.SyncToken
			for _, ts := range page.Tasks {
				seenTaskID.Store(ts.ID, true)
			}
			token = page.SyncToken
			if writesDone.Load() && !page.HasMore && len(page.Projects)+len(page.Tasks) == 0 {
				return
			}
			select {
			case <-ctx.Done():
				readErr.Store(ctx.Err())
				return
			default:
			}
		}
	}()

	// Writers: each inserts insertsPerWriter tasks.
	for w := 0; w < writers; w++ {
		writeWG.Add(1)
		go func(wid int) {
			defer writeWG.Done()
			for i := 0; i < insertsPerWriter; i++ {
				t := &database.Task{
					Title:     fmt.Sprintf("w%d-i%d", wid, i),
					ProjectID: &parent.ID,
				}
				if err := database.DB.Create(t).Error; err != nil {
					readErr.Store(fmt.Errorf("writer %d insert %d: %w", wid, i, err))
					return
				}
			}
		}(w)
	}

	writeWG.Wait()
	writesDone.Store(true)

	select {
	case <-readDone:
	case <-ctx.Done():
		t.Fatalf("reader did not finish: %v", ctx.Err())
	}

	if v := readErr.Load(); v != nil {
		t.Fatalf("error: %v", v)
	}

	// Verify every inserted task ID was seen by the reader.
	var allTasks []database.Task
	if err := database.DB.Find(&allTasks).Error; err != nil {
		t.Fatalf("list tasks: %v", err)
	}
	if len(allTasks) != totalInserts {
		t.Fatalf("expected %d tasks in db, got %d", totalInserts, len(allTasks))
	}
	missing := 0
	for _, ts := range allTasks {
		if _, ok := seenTaskID.Load(ts.ID); !ok {
			missing++
		}
	}
	if missing > 0 {
		t.Fatalf("reader missed %d/%d tasks — sync lost updates under concurrency", missing, totalInserts)
	}
}
