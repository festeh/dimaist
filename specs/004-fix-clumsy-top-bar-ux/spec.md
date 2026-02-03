# Fix Clumsy Top Bar UX

## Problem

The task screen top bar has two identical three-dot menus — one next to the title in the app bar, and another in an inline toolbar row below. Both show the same options (sort toggle, schedule view toggle). The "+" add task button sits in that second row, making the whole area feel cluttered and redundant.

Current layout:

```
[hamburger]  Today  [⋮]              ← app bar with ViewOptionsMenu
                           [+]  [⋮]  ← inline toolbar with same ViewOptionsMenu again
```

## What Users Can Do

1. **See a clean, single-row top bar**

   - **Scenario: Viewing a task list**
     - **Given:** User opens any task list (Today, project, etc.)
     - **When:** The screen loads
     - **Then:** There is one app bar row with no duplicate controls below it

2. **Add a new task from the top bar**

   - **Scenario: Tapping the add button**
     - **Given:** User is viewing a task list
     - **When:** User taps the "+" button in the app bar
     - **Then:** The add task dialog opens (same behavior as today)

3. **Access view options from the top bar**

   - **Scenario: Changing sort or view mode**
     - **Given:** User is viewing a task list
     - **When:** User taps the three-dot menu in the app bar
     - **Then:** A popup shows sort and view options (same options as today)

## Target Layout

```
[hamburger]  Today           [+]  [⋮]
```

- Hamburger: opens drawer (unchanged)
- Title: view name (unchanged)
- `+` button: opens add task dialog (moved to app bar actions)
- Single three-dot menu: sort toggle + schedule view toggle (deduplicated)

## Requirements

- [ ] Remove the inline toolbar row below the app bar
- [ ] Move the "+" add task button into the app bar as an action
- [ ] Keep one ViewOptionsMenu in the app bar as an action (remove the one embedded in the title)
- [ ] Title shows plain text without a menu button next to it
- [ ] All existing functionality is preserved (add task, sort toggle, schedule view toggle)
- [ ] Add "Show Completed Tasks" toggle to the ViewOptionsMenu
- [ ] Works on both Today view (with schedule toggle) and project views (without it)
