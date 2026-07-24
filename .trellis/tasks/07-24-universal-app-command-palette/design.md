# Design: Universal App Command Palette

## Overview

Implement the feature as a new `KeyMasterTool` backed by one session owner, one
Accessibility menu session, and one non-activating SwiftUI panel. Existing rule
dispatch and persistence remain unchanged.

```text
bound shortcut
  -> ApplicationCommandPaletteTool.toggle()
  -> capture frontmost PID + application metadata + focused-window display
  -> show non-activating search panel immediately
  -> ApplicationMenuSession scans AXMenuBar off the main actor
  -> pure metadata snapshot reaches the panel
  -> token search + deterministic ranking
  -> Enter sends command ID back to ApplicationMenuSession
  -> resolve a fresh item from its structural locator
  -> verify its original title, choose AXPick/AXPress, and perform it
```

## Proposed Files

- `KeyMaster/Tools/ApplicationCommands/ApplicationCommandPaletteTool.swift`
  contains the tool entry point.
- `KeyMaster/Tools/ApplicationCommands/ApplicationMenuSession.swift` contains
  menu metadata, the actor-owned AX item table, traversal, shortcut formatting,
  execution, and the pure search function.
- `KeyMaster/Tools/ApplicationCommands/ApplicationCommandPalettePanel.swift`
  contains the main-actor session controller, panel lifetime, placement,
  outside-click/application-switch closing, observable presentation state, and
  SwiftUI views.
- `KeyMasterTests/ApplicationMenuSearchTests.swift` covers pure tree filtering
  and search behavior.
- `KeyMaster/Tools/ToolRegistry.swift` adds the tool to the existing registry.

The source directories are already included recursively by XcodeGen, so
`project.yml` needs no structural change. The generated project is refreshed by
the required development script.

## Tool Integration

Use the existing tool contract:

```swift
struct ApplicationCommandPaletteTool: KeyMasterTool {
    let id = "app.commands"
    let title = "App Commands"
    let subtitle = "Search the current app's menu commands"
    let systemImage = "command.square"
}
```

`run` calls a shared controller's toggle method. The existing tool picker is
registry-driven, so registration is the only picker change. `ToolInvocation`
already persists stable tool IDs and needs no migration.

## Target Capture

Before presenting any KeyMaster window, the controller captures:

- the current `NSWorkspace.frontmostApplication` PID, localized name, and icon;
- the focused AX window frame when available;
- the `CGDirectDisplayID` intersecting that frame, mapped to its `NSScreen`.

If a focused frame cannot be resolved, fall back to the display containing the
target application's topmost ordinary window, then `NSScreen.main`. Target
capture is a small synchronous boundary; recursive menu work begins only after
the panel is visible.

The target must not be KeyMaster itself and must not be terminated. Missing
Accessibility permission or an unavailable target produces a concise panel
state instead of an empty result list.

## Non-Activating Panel

Use an `NSPanel` with `.borderless` and `.nonactivatingPanel`, `canBecomeKey ==
true`, and a SwiftUI search field focused on appearance. This allows KeyMaster
to receive search input without making KeyMaster the active application, so the
captured app retains its context-sensitive menu state.

Handle Return, numeric-keypad Enter, Up, Down, and Esc with an AppKit local
`keyDown` monitor scoped to this panel's window number. Pass other key events to
the SwiftUI text field. A non-activating panel must not rely on SwiftUI
`onSubmit` or `onKeyPress` for command execution.

Place the fully rounded collapsed search bar at a Spotlight-like upper-middle
position in the target screen's `visibleFrame`, centered horizontally and low
enough to avoid looking attached to the menu bar while retaining room for ten
results. Keep its top edge fixed and grow the window downward only after the
user enters a query. Use one light material surface without separate header,
search-field, or result-area backgrounds; the application identity and scan
state live inside the search row. Do not generalize the anchored popover
presenter: this panel is screen-centered and has different lifetime rules.

Install local and global mouse monitors for outside clicks. Observe
`NSWorkspace.didActivateApplicationNotification`; close if the activated PID no
longer matches the captured target. Toggling the tool calls the same close path.
All monitors and pending scan tasks are removed on close.

## Menu Session Ownership

`ApplicationMenuSession` is an actor so Accessibility calls stay off the main
actor and do not cross into SwiftUI state. It owns a session-local table:

```text
UUID -> (child indexes, original title)
```

The UI receives only Sendable metadata:

- ID;
- original title;
- parent path components;
- enabled snapshot;
- formatted shortcut, when exposed;
- original traversal order.

On a new activation, replace the actor's table. On close, cancel the scan and
clear the table. Execution accepts only an ID, follows the stored child indexes
from a fresh menu bar, verifies the original title still matches, and invokes
that fresh element. This preserves the activation search snapshot without
assuming that third-party apps keep scanned AX element objects valid.

## Accessibility Traversal

Create an application AX element from the captured PID and read
`kAXMenuBarAttribute`. Traverse `kAXChildrenAttribute` depth-first in displayed
menu order with explicit visited-node and depth bounds. Before traversal, remove
the top-level system Apple menu identified by its `AXMenuBarItem` role, `Apple`
title, and missing identifier; retain the adjacent application menu.

Collect a node only when all of these hold:

- role is `AXMenuItem`;
- title is non-empty;
- it does not contain a submenu child;
- its supported actions contain `kAXPickAction` or `kAXPressAction`.

Read `kAXEnabledAttribute`, defaulting to enabled only when the target omits the
attribute. Read shortcut data from `kAXMenuItemCmdCharAttribute`,
`kAXMenuItemCmdVirtualKeyAttribute`, `kAXMenuItemCmdGlyphAttribute`, and
`kAXMenuItemCmdModifiersAttribute`; unsupported attributes simply produce no
shortcut label.

Do not invoke `AXShowMenu` or otherwise open parent menus while scanning.
Dynamic entries are included only when they are already exposed through the
captured Accessibility tree. If bounds are reached, return collected partial
results rather than blocking indefinitely.

## Search Contract

Keep search pure and synchronous over metadata:

1. Trim the query and split on whitespace.
2. Normalize tokens, title, and full path for case-insensitive comparison.
3. Reject a command unless every token occurs in either title or full path.
4. Score title exact match above title prefix, title containment, and path-only
   containment.
5. Tie-break by original menu order.
6. Return every matching command.

An empty query returns an empty array. Disabled commands remain in results with
their snapshot state; they are not silently hidden or promoted.

The panel displays at most eight rows at once in a `ScrollView` backed by a
`LazyVStack`. Arrow-key selection scrolls the selected command into view.
Each menu-command row stays icon-free and renders an available shortcut as plain
trailing metadata. The panel layers a translucent white tint over
`ultraThinMaterial`; selection uses a rounded neutral primary-color wash instead
of a saturated accent fill.

## Execution And Failure

The selected row sends its command ID to the actor. For an item disabled in the
snapshot, the controller reports unavailable without calling AX. At execution,
the actor obtains a fresh menu bar, follows the stored child indexes, and rejects
the command if the resolved title no longer equals the snapshot title. It then
reads the fresh item's action names, prefers `kAXPickAction`, and uses
`kAXPressAction` only as a compatibility fallback before calling:

```swift
AXUIElementPerformAction(element, selectedAction)
```

On `.success`, close the palette. On any other `AXError`, keep the panel and
query, and publish an unavailable status. There is no retry, rescan, shortcut,
pointer, AppleScript, or shell fallback.

Because the panel is non-activating, the target application remains frontmost
while the action runs. Any confirmation dialog or application switch caused by
the target command belongs to the target application.

## Compatibility And Persistence

- Accessibility and Input Monitoring remain the only required permissions.
- Existing rules persist the new `ToolInvocation` without changing the JSON
  schema.
- No menu data, query, or execution history is persisted.
- Existing Screen Navigation scanning, overlays, and key monitoring are not
  modified.

## Testing

Keep the logic check small and focused:

- unit-test whitespace token matching across title and path;
- unit-test case-insensitive matching and rejection of translation/typos;
- unit-test exact/prefix/title/path ranking and menu-order tie-breaking;
- unit-test empty query, unbounded default results, and explicit result limits;
- unit-test pure leaf filtering for nested, dynamic, separator, submenu-only,
  disabled, and non-pressable nodes;
- manually verify real AX traversal and `AXPress` in Finder and Android Studio;
- manually verify non-activation, focused-display placement, outside-click,
  `Command-Tab`, toggle, loading, empty, failure, and success states.

## Risks And Rollback

- Some applications lazily create menu descendants only while a menu is open.
  The MVP intentionally reports only what the activation snapshot exposes.
- AX calls are synchronous and application-dependent. Actor isolation,
  cancellation checks, and traversal bounds keep that work off the UI thread.
- Non-activating SwiftUI text input must be verified with standard typing and an
  input method during development. If AppKit cannot maintain search focus, stop
  and revisit the panel mechanism rather than activating KeyMaster and silently
  changing the agreed target semantics.
- Rollback removes the three feature files, one test file, and one registry
  entry; no stored configuration migration is involved.
