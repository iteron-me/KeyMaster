# Calendar Todo Tool Design

## Architecture and boundaries

Keep the feature inside a new `KeyMaster/Tools/CalendarTodo/` directory and add
one registration entry to `ToolRegistry`. It remains independent from
`AppState`, shortcut configuration persistence, and configuration archives.

- `CalendarTodoTool` implements the existing `KeyMasterTool` protocol and asks
  the shared window controller to show its window.
- `CalendarTodoWindowController` owns one standard `NSWindow`, the shared Todo
  store, and session-only calendar view state. Closing releases/hides the window
  without resetting that state; a process restart naturally resets it.
- `CalendarTodoView` owns the SwiftUI day, week, month, and year presentation and
  edit/delete sheets or alerts.
- `CalendarTodoStore` is the observable source of truth for mutations,
  persistence, validation, and date grouping.

No database, repository protocol, sync service, or iCloud entitlement is needed.
`project.yml` already includes the entire `KeyMaster/Tools` source directory.

## Data contract

`CalendarTodo` contains:

- stable UUID
- trimmed title
- optional trimmed multi-line content
- an all-day `CalendarTodoDay` value (`year`, `month`, `day`)
- completion flag
- creation and update timestamps

The date-only value prevents an all-day Todo from moving to another calendar
date when the system time zone changes. Conversion to `Date` uses a Gregorian
`Calendar` configured with the current locale, time zone, and first weekday for
display and navigation.

Incomplete Todos sort before completed Todos. Within each group, creation time
and UUID provide stable ordering.

## Persistence

Use one Codable, versioned JSON document shape for the live store:

```text
{ "version": 1, "todos": [...] }
```

The live file is `~/Library/Application Support/KeyMaster/todos.json`. Writes
create the directory when needed and use atomic replacement, matching the
existing rule store. Mutations first build and persist a candidate array, then
publish it, so a failed write does not present unsaved state as successful.

Todo data never enters `KeyMasterConfiguration` or its import/export flow.

## Window and interaction

The controller creates one titled, closable, miniaturizable, resizable window,
centers it initially, and enforces a minimum content size. Repeated shortcut
invocation activates KeyMaster and brings the same window forward.

The fixed toolbar contains previous and next icon buttons, a compact Today
command, the current period title, and a direct custom day/week/month/year
chooser. The chooser presents all four options in one layer. The toolbar has no
Todo import/export menu, keeps a stable height, and the switched content always
fills the remaining window from the top.

- Day: new-title field plus the full task list and edit/delete controls.
- Week: seven stable columns containing all-day task titles.
- Month: an edge-to-edge calendar grid with seven columns and the five or six
  complete week rows needed for that month; each date shows up to three titles
  and `+N`.
  Selecting a date opens a focused quick-add popover to the right of that cell
  without changing views. Quick add contains separate title and content fields
  with custom quiet surfaces and one Add action. Saved Todos render as compact
  event rows; the complete row is a button that anchors the shared editor
  popover to its right instead of triggering date selection.
- Year: twelve mini-months; dates show a task marker/count instead of titles.

The toolbar remains outside the switched content so its position is stable. Its
period title leads on the left and compact view/navigation controls sit on the
right. Calendar cells stay unframed; full grid separators, muted adjacent-month
dates, neutral current-day emphasis, and tinted event rows provide hierarchy.
Selecting a year-view month heading opens that month. Calendar layout follows
the user's current first-weekday convention.

Todo completion uses a checkbox-style control and struck-through title. Editing
uses a visually consistent task-row popover with title, multi-line content, and
a native date control. Day, week, and month task rows share the same direct
popover anchor with `arrowEdge: .trailing`, placing the editor to the row's right.
The editor places Delete opposite Save and omits a redundant Cancel action; Esc
or normal popover dismissal closes without saving. Permanent deletion requires
confirmation. Persistence and validation failures remain visible in the window
rather than failing silently.

## Compatibility and rollback

This is a new isolated data file with no migration and no change to existing
rules or history formats. Removing the tool registration and new source folder
rolls back the feature; an existing `todos.json` can remain untouched for a
future reinstall.

## Verification

Focused XCTest coverage will verify date-only round trips/grouping, stable
completion ordering, mutation persistence, and validation. The required
end-to-end build/install check is
`./scripts/dev-run.sh`; runtime visual verification remains with the user per
project guidance.
