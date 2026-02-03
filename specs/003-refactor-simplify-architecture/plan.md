# Plan: Simplify Architecture

## Problems Found

### Backend

1. **All handlers live in `main.go` (586 lines).** Route setup, request parsing, DB queries, calendar sync, and response writing are all mixed together. Every handler repeats the same decode-validate-query-respond pattern.

2. **`database.DB` is a global variable.** Every package that needs the database imports it directly. This makes testing hard and hides dependencies.

3. **Sync logic is duplicated.** Both `TaskRepository.syncTasks()` and `ProjectRepository.syncAndGetProjects()` in the frontend contain the same sync loop (upsert projects, upsert tasks, delete projects, delete tasks, save token). Same code in two places.

4. **Excessive logging in repositories.** Every repository method logs entry, success, and error with verbose prefixed messages. This is noise, not signal. The API service and HTTP middleware already log requests.

### Frontend

5. **Repository interfaces serve no purpose.** `ITaskRepository` and `IProjectRepository` exist but have exactly one implementation each. No tests use mocks. This is a shallow wrapper (violates IMPLEMENTATION.md rule 5: "avoid shallow wrappers that just pass data through").

6. **Repository layer is mostly pass-through.** Most read methods in `TaskRepository` just call `_database.sameMethod()` with the same arguments. The write methods add API call + local DB update, but this pattern could live directly in the provider or a simpler service.

## Approach

### Phase 1: Frontend — Remove repository interfaces, merge into providers

**What changes:**
- Delete `lib/repositories/interfaces/` directory (2 files)
- Delete `lib/repositories/task_repository.dart` and `project_repository.dart`
- Move the useful logic (API call + local DB update) into the providers directly, or into the existing services
- Update `providers.dart` to remove repository providers
- Update `task_provider.dart` and `project_provider.dart` to use `ApiService` and `AppDatabase` directly

**Why:** The repository layer adds a file and an interface for every operation but does nothing the provider can't do. Read operations are pure pass-through to `AppDatabase`. Write operations are "call API, then update local DB" — a 3-line pattern that doesn't need its own class.

**Risk:** If you later want to swap implementations (e.g., offline-first mode), you lose the interface. Mitigation: you can add it back when you actually need it. Right now it's speculative architecture.

### Phase 2: Frontend — Deduplicate sync logic

**What changes:**
- Extract the sync loop (upsert projects/tasks, delete, save token) into a single method on `AppDatabase` or a small `SyncService`
- Both `syncTasks()` (in task provider) and `syncAndGetProjects()` (in project provider) call this one method
- Remove duplicate sync code from both repositories

**Why:** The same 20-line sync loop exists in two places. When the sync format changes, you have to update both. DRY (IMPLEMENTATION.md rule 4).

### Phase 3: Frontend — Strip verbose repository logging

**What changes:**
- Remove the `LoggingService.logger.info('TaskRepository: ...')` calls that log entry/exit of every method
- Keep error logging only
- The HTTP layer and provider layer already provide request-level visibility

**Why:** Debug with logs that matter, not logs that repeat what the call stack already tells you (IMPLEMENTATION.md rule 2).

### Phase 4: Backend — Extract handlers from main.go

**What changes:**
- Move task handlers into `backend/handlers/tasks.go`
- Move project handlers into `backend/handlers/projects.go`
- Move sync handler into `backend/handlers/sync.go`
- Move `updateOrderBatch` and reorder handlers into `backend/handlers/reorder.go`
- `main.go` becomes only: init env, init DB, set up router, start server (~40 lines)
- Handlers still use `database.DB` directly (no new service layer — keep it simple)

**Why:** Splitting by domain makes files easier to find and change. But we stop short of adding a service layer — the handlers are already thin enough that an extra layer would be a shallow wrapper.

**Risk:** Moving functions between files can break imports. Mitigation: `go build` catches this immediately.

### Phase 5: Backend — Pass DB as function parameter instead of global

**What changes:**
- Change handler functions to accept `*gorm.DB` (or a struct that holds it) via closure
- Example: `func taskHandlers(db *gorm.DB) http.HandlerFunc { ... }`
- Remove `var DB *gorm.DB` global from `database` package
- `InitDB` returns `*gorm.DB` instead of setting a global

**Why:** Explicit dependencies are easier to reason about and test.

**Risk:** Touches every handler. Do this after Phase 4 so the files are already separated.

## Order of Operations

1. Phase 1 (frontend repos) — biggest reduction in files and indirection
2. Phase 2 (dedup sync) — fixes the most likely source of future bugs
3. Phase 3 (strip logging) — small, safe cleanup
4. Phase 4 (backend split) — organizational improvement
5. Phase 5 (remove global DB) — architectural improvement, do last since it touches everything

Each phase is independently deployable. No phase depends on another.

## What This Plan Does NOT Do

- Add tests. That's a separate effort.
- Add API versioning. Not needed for a single-user app.
- Refactor the AI/WebSocket system. It's complex but self-contained in `backend/ai/`.
- Change the database schema or datetime handling. Working code that handles edge cases should not be rewritten for aesthetics.
