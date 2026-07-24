# Universal App Command Palette

## Goal

Add a keyboard-only built-in tool that searches and invokes the original menu
commands exposed by the current frontmost macOS application. The palette should
make nested and infrequently used menu commands reachable without opening menus
with the pointer or memorizing application-specific shortcuts.

## Background

- KeyMaster already binds built-in tools through `KeyAction.runTool` and
  `ToolRegistry`; adding a tool does not require a new action kind or persistence
  migration (`KeyMaster/Models/KeyRule.swift:174-225`,
  `KeyMaster/Tools/ToolRegistry.swift:4-25`).
- Global shortcuts dispatch tools on the main actor after suppressing the source
  keystroke (`KeyMaster/Services/KeyboardEventEngine.swift:107-129`).
- `PermissionService` already owns the Accessibility trust check and settings
  deep link (`KeyMaster/Services/PermissionService.swift:13-35`).
- macOS exposes an application's menu bar through `kAXMenuBarAttribute`, menu
  descendants through `kAXChildrenAttribute`, enabled state and shortcut
  metadata through menu item attributes, and invocation through
  `kAXPressAction`.
- Existing visual-only Screen Navigation overlays are not suitable for this
  feature because the palette needs an editable search field. The command
  palette should instead use a non-activating key panel so the target
  application remains active while the user types.

## Requirements

- R1: Register a built-in tool with a stable ID such as `app.commands` and the
  display name `App Commands`. Users can bind it through the existing built-in
  tool picker without changing the rule model.
- R2: Each activation captures exactly one target: the application that is
  frontmost when the bound shortcut fires, its focused window when available,
  and the display containing that window.
- R3: Present the palette immediately at a Spotlight-like upper-middle position
  on the target display, centered horizontally with a fully rounded search
  surface. It must not follow the pointer or default to another display when
  the focused window's display can be resolved.
- R4: Keep the target application active while accepting search input. The
  palette must not change which application's menu state is being searched.
- R5: Scan the captured application's Accessibility menu tree once per
  activation to create the searchable result snapshot. Search-time application
  or menu changes do not trigger live updates or change those results. Execution
  may follow a stored structural locator to obtain a fresh AX menu element.
- R6: Traverse nested menus and collect every executable leaf menu item exposed
  in the activation snapshot, including dynamic recent-document, window, and
  Services entries when the target application exposes them. Exclude the
  system-owned Apple menu, separators, and items that only contain a submenu.
- R7: Preserve each command's original displayed title, parent menu path,
  enabled state, available keyboard shortcut, menu order, an opaque
  session-local execution ID, and a structural child-index locator. Do not
  translate, alias, or semantically rewrite command names.
- R8: Show the palette and focused search field while scanning continues off the
  main actor. Text entered during loading is retained and applied when results
  arrive. A failed or empty scan leaves the palette open with a concise status
  until the user dismisses it.
- R9: An empty query shows no command rows. For a non-empty query, split the
  original query on whitespace, compare case-insensitively, and require every
  token to occur in either the command title or full menu path.
- R10: Rank matches by title exactness, then title prefix, title containment,
  and finally path-only containment; preserve menu order as the deterministic
  tie-breaker. Keep all matches available to the result list.
- R11: The collapsed palette shows only a Spotlight-style search bar containing
  the captured application's icon and name. Once the query is non-empty, the
  panel expands downward to show rows with the command title, parent menu path,
  native shortcut when available, and a visibly disabled state when the command
  was disabled in the snapshot. Do not add icons to menu-command rows. Use a
  translucent white material surface and a neutral translucent selection layer
  instead of a saturated accent color. Show at most eight rows at once and
  scroll for additional matches.
- R12: The first result is selected by default. `Up` and `Down` move selection,
  `Enter` explicitly invokes the selected enabled command, and `Esc` dismisses
  the palette. A unique result must never execute automatically.
- R13: At execution, follow the stored child-index locator from a fresh menu bar
  and require the resolved item's title to equal the snapshot title. Execute
  that fresh item using `AXUIElementPerformAction`, preferring the menu-specific
  `kAXPickAction` and falling back to `kAXPressAction` only when Pick is not
  exposed. Do not open parent menus, synthesize pointer clicks, send the
  advertised shortcut, or rebuild the search snapshot.
- R14: A successful invocation closes the palette. A disabled item or failed AX
  action keeps the palette and query visible and reports that the command is
  unavailable. KeyMaster adds no generic confirmation for destructive command
  names; the target application remains responsible for its own confirmation
  UI.
- R15: Close the palette on `Esc`, outside click, target-application switch,
  successful execution, or invocation of the same tool shortcut while the
  palette is already open.
- R16: Keep menu traversal bounded and cancellable so a malformed or very large
  Accessibility tree cannot leave the UI blocked. Bounded partial results are
  acceptable when the target application exposes an unusually large tree.
- R17: Remain local-only. Menu titles and paths are not persisted, uploaded, or
  added to action history.

## Acceptance Criteria

- [ ] AC1: The existing action picker exposes `App Commands`, and a saved rule
  launches the palette without a rule-schema change.
- [ ] AC2: Invoking the tool in Finder and Android Studio captures that
  application, keeps it active, and places the palette on its focused window's
  display.
- [ ] AC3: The palette appears before scanning finishes, accepts input during
  loading, and applies the retained query when the snapshot arrives.
- [ ] AC4: A nested command such as `View > Tool Windows > Logcat` is returned by
  `log`, `tool log`, and `view logcat`, but not by translated or misspelled text.
- [ ] AC5: Empty queries return no rows; non-empty queries expose every
  deterministically ranked match with title, parent path, enabled state, and
  available shortcut metadata. Rows remain icon-free and use a clear neutral
  selection state. The panel shows at most eight rows at once and scrolls through
  the remainder.
- [ ] AC6: Dynamic executable leaves exposed at activation participate in the
  same search, while separators and submenu-only parents do not.
- [ ] AC7: Arrow keys change selection, `Enter` invokes exactly the selected
  enabled AX menu item, unique matches never auto-run, and `Esc` cancels.
- [ ] AC8: Disabled or stale commands do not trigger a keyboard or pointer
  fallback. Failure leaves the query visible with an unavailable status.
- [ ] AC9: Outside click, switching away from the captured application, and
  pressing the tool shortcut again close the palette and cancel unfinished scan
  work.
- [ ] AC10: Focused unit tests cover token matching, ranking, tie-breaking,
  result limits, empty queries, and command-tree leaf filtering.
- [ ] AC11: `./scripts/dev-run.sh` succeeds, installs, and opens the stable
  `/Applications/KeyMaster.app` development build.

## Out Of Scope

- Files, applications, URLs, settings databases, toolbar buttons, contextual
  menus that are not exposed in the captured menu bar tree, and IDE-internal
  actions absent from that tree.
- Translation, aliases, synonyms, spelling correction, semantic or AI search.
- Recent-use ranking, favorites, command history, plugins, or cloud sync.
- Live menu observation, search-time rescanning, and execution-time full-tree
  rescanning that would rebuild the search snapshot.
- Synthetic keyboard, pointer, AppleScript, or shell-command execution fallbacks.
- Changes to Screen Navigation or the current screen-navigation targeting task.
