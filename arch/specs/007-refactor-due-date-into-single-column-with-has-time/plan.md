# Plan: Unify due_date/due_datetime into due + has_time

## Tech Stack

- Backend: Go, Chi router, GORM, PostgreSQL
- Frontend: Flutter, Drift ORM, SQLite
- No explicit migration files — GORM auto-migrates, Drift uses in-code migrations

## Current State

Two mutually exclusive nullable timestamp columns:
- `due_date` — date only (e.g., "2025-07-08")
- `due_datetime` — date with time (e.g., "2025-07-08T15:30:00")

Every consumer already accesses them through unified helpers:
- Go: `task.Due()` returns whichever is set, `task.HasTime()` checks if datetime is non-nil
- Dart: `task.due` getter returns `_dueDatetime ?? _dueDate`, `task.hasTime` checks `_dueDatetime != null`

## Target State

One timestamp column + one boolean:
- `due` — the actual date/time value
- `has_time` — whether a specific time was set (controls display format, missed threshold, recurrence behavior)

## Structure

Files that change:

```
backend/
├── database/
│   ├── models.go              # Task struct: replace two fields with due + has_time
│   └── task_operations.go     # CompleteTask(): simplify recurring logic
├── tasks.go                   # Minor — validation already uses Due()
├── ai/
│   ├── tools_crud.go          # AI tool params: accept due + has_time
│   └── ai_text.go             # taskForAI DTO: single due field + has_time
├── calendar/calendar.go       # HasTime() method → field access
└── cmd/dimaist-cli/task.go    # CLI queries and task creation

frontend/lib/
├── models/task.dart           # Replace _dueDate/_dueDatetime with _due/_hasTime
├── services/app_database.dart # Drift schema: new columns, migration v8→v9
├── widgets/
│   ├── task_form_dialog.dart  # Task construction on save
│   └── due_widget.dart        # Already uses getters — verify only
```

## Approach

### 1. Backend model + PostgreSQL migration

Update `Task` struct in `models.go`:
```go
Due     *utils.FlexibleTime `json:"due,omitempty" gorm:"column:due"`
HasTime bool                `json:"has_time" gorm:"column:has_time;default:false"`
```

Remove `Due()` method (now a field). Remove `HasTime()` method (now a field).

Add a one-time migration function that runs before GORM auto-migrate:
```sql
-- Add new columns
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due TIMESTAMP;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS has_time BOOLEAN DEFAULT false;

-- Copy data
UPDATE tasks SET due = COALESCE(due_datetime, due_date),
                 has_time = (due_datetime IS NOT NULL);

-- Drop old columns
ALTER TABLE tasks DROP COLUMN IF EXISTS due_date;
ALTER TABLE tasks DROP COLUMN IF EXISTS due_datetime;
```

### 2. Backend handlers and logic

**task_operations.go** — `CompleteTask()` simplifies:
```go
if task.HasTime {
    updates["due"] = nextDue
} else {
    dateOnly := time.Date(nextDue.Year(), nextDue.Month(), nextDue.Day(), 0, 0, 0, 0, nextDue.Location())
    updates["due"] = &dateOnly
}
// has_time stays unchanged — no need to update it
```

**ai/tools_crud.go** — Merge `due_date` and `due_datetime` tool params into `due` + `has_time`. Keep accepting old param names for AI backward compat (LLM might use cached tool descriptions).

**ai/ai_text.go** — Update `taskForAI` struct to use `due` + `has_time`. Format `due` as `"2025-07-08"` when `has_time` is false, `"2025-07-08T15:04"` when true.

**calendar/calendar.go** — Change `task.HasTime()` calls to `task.HasTime`.

**cmd/dimaist-cli/task.go** — Update queries from `due_date`/`due_datetime` to `due`.

### 3. Frontend Drift schema migration (v8 → v9)

Update table definition:
```dart
DateTimeColumn get due => dateTime().nullable()();
BoolColumn get hasTime => boolean().withDefault(const Constant(false))();
```

Migration in `onUpgrade`:
```dart
if (from < 9) {
  await m.addColumn(tasks, tasks.due);
  await m.addColumn(tasks, tasks.hasTime);
  await customStatement(
    'UPDATE tasks SET due = COALESCE(due_datetime, due_date), '
    'has_time = (due_datetime IS NOT NULL)'
  );
}
```

Drop old columns after data migration:
```dart
if (from < 9) {
  await m.addColumn(tasks, tasks.due);
  await m.addColumn(tasks, tasks.hasTime);
  await customStatement(
    'UPDATE tasks SET due = COALESCE(due_datetime, due_date), '
    'has_time = (due_datetime IS NOT NULL)'
  );
  await customStatement('ALTER TABLE tasks DROP COLUMN due_date');
  await customStatement('ALTER TABLE tasks DROP COLUMN due_datetime');
}
```
SQLite has supported DROP COLUMN since 3.35.0 (2021). Flutter ships a recent enough version.

### 4. Frontend Task model

Replace private fields:
```dart
final DateTime? _due;
final bool _hasTime;

DateTime? get due => _due;
bool get hasTime => _hasTime;
```

Update `fromJson()` to accept both old format (for sync compat with older backends) and new format:
```dart
// New format
if (json['due'] != null) {
  _due = _parseDate(json['due']);
  _hasTime = json['has_time'] ?? false;
}
// Old format fallback
else {
  _due = _parseDate(json['due_datetime'] ?? json['due_date']);
  _hasTime = json['due_datetime'] != null;
}
```

Update `toJson()` to output new format only:
```dart
'due': due?.toIso8601String(),
'has_time': hasTime,
```

Update `copyWith()` — already takes `due` + `hasTime` params, simplify internals.

### 5. Frontend queries

Update all Drift queries in `app_database.dart` from:
```dart
(t.dueDate.isNotNull() & t.dueDate.isSmallerThan(...)) |
(t.dueDatetime.isNotNull() & t.dueDatetime.isSmallerThan(...))
```
to:
```dart
t.due.isNotNull() & t.due.isSmallerThan(...)
```

Update `_taskToCompanion()` to write `due` and `hasTime` instead of `dueDate`/`dueDatetime`.

### 6. Regenerate Drift code

Run `dart run build_runner build` to regenerate `app_database.g.dart`.

### 7. Frontend widgets — verify only

`task_form_dialog.dart` and `due_widget.dart` already use `task.due` and `task.hasTime` getters. The save logic in the form dialog constructs a Task — update field names in constructor call.

## Implementation Order

1. Backend model + migration (must be first — database schema drives everything)
2. Backend logic (handlers, AI tools, calendar, CLI)
3. Frontend Drift schema + migration
4. Frontend Task model
5. Frontend queries
6. Regenerate Drift code
7. Frontend widgets — verify and fix constructor calls
8. Test end-to-end

## Risks

- **Data loss during migration**: Mitigate by running `COALESCE(due_datetime, due_date)` — covers all cases including both-null (stays null)
- **Sync between old frontend and new backend**: Frontend `fromJson()` accepts both formats, so an updated frontend works with both old and new backends. An old frontend hitting a new backend would fail — deploy backend with backward-compat JSON output first if needed.
- **SQLite DROP COLUMN**: Requires SQLite 3.35.0+ (2021). Flutter ships a recent version, so this is safe.
- **GORM auto-migrate vs explicit migration**: GORM can add columns but won't drop them or run data migrations. Need an explicit migration step before auto-migrate runs.

## Open Questions

None — clean cut, no backward compat needed.
