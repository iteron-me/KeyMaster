# Calendar Todo Tool

## Goal

Add a focused built-in calendar Todo tool to KeyMaster so a user can invoke it
with a configured global shortcut, choose a date, and see dated tasks directly
in the calendar instead of maintaining a separate script or app.

## Background

- KeyMaster already exposes built-in tools through the shortcut action picker.
- Built-in tools already own and present their own macOS windows.
- KeyMaster is local-first and does not upload user input data.
- The requested calendar must support day, week, month, and year views.

## Requirements

### Invocation and window

- The Todo tool is available as a KeyMaster built-in tool that can be assigned
  to a keyboard shortcut.
- Invoking the shortcut opens a calendar-style window suitable for viewing and
  editing Todo items.
- The calendar uses a standard titled, closable, resizable macOS window with a
  practical minimum size.
- Repeated invocation shows the existing window and brings it to the front; it
  does not toggle a visible window closed.
- Hiding and reopening the window during the same KeyMaster process preserves
  the selected view and date.
- After a KeyMaster relaunch, the tool starts in month view containing today.

### Calendar navigation

- The user can switch among day, week, month, and year views.
- The user can navigate to previous and next periods and return to today.
- The top toolbar remains fixed while the selected period or view changes; only
  the calendar content below it is replaced.
- The interface uses a quiet, compact macOS presentation without card-like
  decoration around individual calendar cells or oversized empty states.
- Month view uses only the five or six complete weeks needed to cover the
  displayed month, with seven edge-to-edge columns aligned to the weekday row.
- Each view clearly identifies its displayed date range and the current day.
- The year view presents all months as a compact overview.
- Selecting a day in the year view switches to the day view for that date.
- Selecting a month heading in the year view switches to the month view for
  that month.

### Todo interaction

- The user can select a calendar day and add a Todo item assigned to that date.
- A Todo has a required title, optional multi-line content, and an all-day
  calendar date; the first version does not store a specific hour, minute,
  duration, or time zone.
- Saved Todo titles appear in the corresponding date cell or date section.
- The year view may replace titles with a compact task count or marker so the
  full year remains legible.
- A month-view date cell shows at most the first three Todo titles followed by
  a remaining-item count when more Todos exist.
- Selecting a date in month view keeps the month visible and opens a compact
  new-Todo popover immediately to the right of the selected date cell.
- The month-view popover focuses its title field immediately.
- Saved Todos use a subtle event background. Selecting a Todo opens an editor
  immediately to the right of that Todo row, where its complete title, content,
  and date can be read and changed. The complete visible Todo row is clickable.
- Pressing Return saves a non-empty title; empty or whitespace-only titles are
  not created.
- Multiple Todo items may be assigned to the same date.
- The user can mark a Todo complete or incomplete.
- The user can edit a Todo title and assigned date using a native date control,
  and can delete a Todo.
- Deleting a Todo requires explicit confirmation before the permanent change.
- The first version does not require drag-and-drop rescheduling.
- Completed Todos remain visible until deleted, use checked/struck-through
  styling, and sort after incomplete Todos for the same date.
- Todo items persist locally across window closure and app relaunch.

### Product constraints

- The experience remains a focused local Todo tool rather than a general
  project-management system.
- The live Todo store is separate from KeyMaster shortcut configuration and
  action history.
- KeyMaster configuration import/export does not include or replace Todo data.
- The calendar toolbar does not expose Todo import, export, or backup actions.
- View switching opens one direct custom chooser; it must not nest a picker
  inside a menu.
- Task forms use quiet custom SwiftUI surfaces and clear hierarchy rather than
  default legacy-looking field and button styles.
- Add and edit forms omit redundant Cancel buttons. The edit form exposes a
  direct Delete action with destructive confirmation.
- Interaction and text remain usable with keyboard navigation and standard
  macOS accessibility behavior.

## Acceptance Criteria

- [ ] A user can assign the Calendar Todo built-in tool to a KeyMaster shortcut
  and invoke its window with that shortcut.
- [ ] The tool opens one standard resizable window, and invoking it again brings
  the existing window to the front without creating a duplicate.
- [ ] The window provides working day, week, month, and year view controls.
- [ ] Reopening the tool in the same app run restores its last view and date;
  relaunching KeyMaster resets it to the current month.
- [ ] In year view, selecting a date opens that date in day view and selecting
  a month heading opens that month in month view.
- [ ] A user can navigate dates, return to today, select a date, and add a Todo
  title to it.
- [ ] Adding or editing a Todo does not require entering a time.
- [ ] The add and edit interfaces provide separate title and content fields.
- [ ] A saved Todo title is visible on its assigned date in the applicable
  calendar view.
- [ ] Saved Todos have a distinct background and can be selected to read or edit
  their complete title, content, and date.
- [ ] The complete visible Todo row opens an editor popover anchored immediately
  to its right in day, week, and month views.
- [ ] A month cell with more than three Todos shows three titles and the number
  of additional items without resizing or internally scrolling the cell.
- [ ] The month grid uses five or six equal-height week rows as needed, fills
  the available width, and keeps weekday headings aligned with date columns.
- [ ] Selecting a date in month view keeps the month visible and opens a focused
  new-Todo popover beside that cell; Return creates the Todo.
- [ ] Changing the period or calendar view leaves the toolbar fixed and replaces
  only the content below it.
- [ ] Empty or whitespace-only Todo titles cannot be saved.
- [ ] Multiple Todos on one date are retained and presented without corrupting
  or replacing one another.
- [ ] A user can complete, reopen, rename, and delete an existing Todo, and each
  change is reflected in the calendar without reopening the window.
- [ ] Editing a Todo can move it to another date, after which it disappears from
  the old date and appears on the new date.
- [ ] Cancelling a delete confirmation preserves the Todo; confirming removes it
  and persists the deletion.
- [ ] Completed Todos remain visible with distinct checked and struck-through
  styling, sort after incomplete Todos, and can be reopened.
- [ ] Saved Todos remain available after relaunching KeyMaster.
- [ ] Importing or exporting KeyMaster shortcut configuration does not read,
  write, or replace Todo data.
- [ ] The calendar toolbar contains no Todo import/export controls, and its view
  chooser presents day, week, month, and year in one layer.
- [ ] Add and edit forms use a concise custom visual treatment while preserving
  keyboard focus, Return submission, and accessible labels.
- [ ] The edit form offers direct deletion with confirmation and neither task
  form shows a redundant Cancel button.
- [ ] The implementation has focused automated coverage for Todo persistence and
  date grouping, and the project passes `./scripts/dev-run.sh`.

## Out of Scope

- Collaboration and shared Todo lists.
- Automatic cloud backup, live multi-device synchronization, and conflict
  resolution.
- User-facing Todo import, export, and backup controls.
- Integration with Apple Calendar or Reminders unless explicitly requested.
- Timed tasks, durations, and time-zone handling.
- Projects, tags, attachments, recurring tasks, and team assignment unless a
  later product decision requires them.
- Notifications and alarms unless explicitly requested.
