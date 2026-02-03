# Plan: Fix Clumsy Top Bar UX

**Spec**: specs/004-fix-clumsy-top-bar-ux/spec.md

## Tech Stack

- Language: Dart
- Framework: Flutter
- Testing: `just analyze`

## Structure

Files to change:

```
frontend/lib/
├── screens/
│   └── task_screen.dart          # Remove inline toolbar, pass actions via AppBarConfig
├── widgets/
│   └── view_options_menu.dart    # Add showCompletedTasks toggle + onShowCompletedToggle callback
```

No new files needed.

## Approach

1. **Add "Show Completed Tasks" toggle to ViewOptionsMenu**
   - Add `showCompletedTasks` (bool) and `onShowCompletedToggle` (VoidCallback) parameters to `ViewOptionsMenu`
   - Add a new `PopupMenuItem` with a checkmark icon that toggles completed task visibility

2. **Move `+` button and ViewOptionsMenu into AppBarConfig actions**
   - In `_updateAppBarConfig`, change `title` from a `Row` (text + menu) to plain `Text`
   - Set `actions` on `AppBarConfig` to contain the `+` IconButton and a single `ViewOptionsMenu`
   - Pass `_showAddTaskDialog`, sort toggle, schedule toggle, and show-completed toggle callbacks through the config

3. **Remove the inline toolbar row**
   - Delete the `Padding` block (lines 336-373) containing the duplicate `+` button and `ViewOptionsMenu` from `_buildTaskContent`

4. **Remove the inline "Completed" section header**
   - The completed tasks section currently has its own tap-to-toggle header in the list. Keep that as-is — the menu toggle controls whether completed tasks appear at all, the inline header is just a visual separator within the list.

## Risks

- **AppBarConfig callbacks and state**: The `_showAddTaskDialog` method needs `context` and `ref`, which are available in `TaskScreenState`. Since `_updateAppBarConfig` already captures closures from the state, this works the same way.
- **Stale closures**: `_updateAppBarConfig` is called from `addPostFrameCallback` on every build, so the closures will stay up to date with current `_showCompletedTasks` and `_isScheduleView` state.
