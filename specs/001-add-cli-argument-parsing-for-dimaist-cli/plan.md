# Plan: Cobra CLI Argument Parsing

## Tech Stack

- Language: Go
- Library: github.com/spf13/cobra
- Testing: Manual (no existing CLI tests)

## Structure

Replace manual parsing with cobra command tree:

```
backend/cmd/dimaist-cli/
├── main.go          # Root command setup, Execute()
├── task.go          # task subcommand + list/get/create/complete/update/delete
├── project.go       # project subcommand + list
└── ai.go            # ai subcommand
```

## Approach

1. **Add cobra dependency**
   Run `go get github.com/spf13/cobra` in backend/

2. **Create root command** (main.go)
   - Define rootCmd with app description
   - Add PersistentPreRunE to load .env and init database (shared setup)
   - Call Execute() from main()

3. **Create task command** (task.go)
   - Parent: `task` subcommand
   - Children: `list`, `get`, `create`, `complete`, `update`, `delete`, `cleanup-labels`
   - Flags:
     - `list --due` (string)
     - `create --title` (required string), `--due`, `--project-id`
     - `update --title`, `--due`, `--project-id`
   - Move business logic from handleTask() into RunE functions

4. **Create project command** (project.go)
   - Parent: `project` subcommand
   - Child: `list`
   - Move logic from handleProject()

5. **Create ai command** (ai.go)
   - Single command (no subcommand)
   - Flag: `--include-completed` (bool)
   - Args: remaining args joined as message, or stdin if none
   - Move logic from handleAI()

6. **Delete manual parsing code**
   - Remove parseTaskFlags()
   - Remove printUsage() (cobra generates help)
   - Remove os.Args handling

## Command Mapping

| Current | Cobra |
|---------|-------|
| `dimaist-cli task list --due today` | Same |
| `dimaist-cli task create --title "X"` | Same |
| `dimaist-cli ai "message"` | Same |
| `dimaist-cli` (no args) | Shows cobra help |
| `dimaist-cli task --help` | Shows task subcommands |

## Risks

- **Breaking change for scripts**: Command syntax stays the same, low risk.
- **Database init timing**: PersistentPreRunE runs before subcommands. AI command needs special handling since it currently inits DB inside handleAI().

## Open Questions

None. Cobra is a standard choice, syntax stays the same.
