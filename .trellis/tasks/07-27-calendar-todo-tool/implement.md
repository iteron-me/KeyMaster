# Calendar Todo Tool Implementation Plan

## Checklist

1. Add the date-only and Todo models plus the versioned JSON document.
2. Add `CalendarTodoStore` with load, add, complete/reopen, edit/reschedule,
   delete, grouping/sorting, atomic save, and validation.
3. Add focused XCTest coverage for persistence, grouping/sorting, document
   validation, and failed replacement behavior.
4. Add `CalendarTodoTool` and a single standard resizable window controller that
   preserves view/date state for the current process.
5. Build the fixed shared toolbar and day/week/month/year SwiftUI views using
   native `Calendar`, direct custom view selection, focused task forms, and
   accessibility labels. Month-cell selection keeps the grid visible and opens
   quick add next to the selected cell.
6. Register the tool in `ToolRegistry` and confirm it appears in the existing
   built-in action picker without changing shortcut archive formats.
7. Run focused tests, then run the required `./scripts/dev-run.sh` build,
   install, signing, and launch verification.

## Validation commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyMasterDerived \
  test

./scripts/dev-run.sh
```

Manual runtime checks are left to the user as required by `AGENTS.md`: assign
the tool to a shortcut; inspect all four views; create, complete, reopen, edit,
reschedule, and delete Todos; and relaunch.

## Risk and rollback points

- Persistence is the main data-loss boundary. Keep candidate writes atomic and
  do not publish failed mutations or invalid document data.
- Calendar grid calculations must use one calendar configuration consistently,
  especially around month boundaries and the user's first weekday.
- `ToolRegistry.swift` is the only existing source file expected to change.
- Rollback removes the new tool registration and source/tests; it must not delete
  a user's `todos.json` file.
