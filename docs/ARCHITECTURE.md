# KeyMaster Architecture

This document is the current architecture and module map for KeyMaster. It
describes the code as it exists now, not a future target design.

## Top-Level Shape

```text
KeyMaster/
|-- App/        App lifecycle, status item window, central state coordination
|-- Models/     Shortcut rules, keyboard catalog, actions, and action history
|-- Services/   macOS system boundaries, permissions, persistence, discovery
|-- Actions/    Runtime action dispatch and side-effect implementations
|-- Tools/      Built-in command tools invoked through shortcut actions
|-- Views/      SwiftUI panel, keyboard, popovers, visual styling, AppKit bridges
`-- Resources/  Assets and app icon catalog
```

`project.yml` is the source of truth for the Xcode target. Update it when
adding source groups, resources, targets, build settings, or schemes, then
regenerate the Xcode project.

## Module Map

| Module | Main Files | Responsibility |
| --- | --- | --- |
| App lifecycle | `KeyMasterApp.swift`, `KeyMasterApplicationDelegate.swift` | Creates the app, owns the menu bar status item, creates and positions the borderless panel window, closes on outside click, and reflects Pomodoro status in the status item. |
| App state | `AppState.swift` | Main coordination boundary between SwiftUI and services. Loads rules/history, tracks active modifiers, indexes rules for UI lookup, refreshes permissions, starts/stops the event engine, and triggers app discovery. |
| Domain models | `KeyRule.swift`, `KeyCatalog.swift` | Defines shortcut rules, triggers, key strokes, modifier keys, action types, action history, action kinds, keyboard layout, and macOS virtual key codes. |
| Permission and event services | `PermissionService.swift`, `KeyboardEventEngine.swift`, `KeyCaptureMonitor.swift` | Wraps Accessibility/Input Monitoring permission APIs, owns the CoreGraphics event tap, normalizes modifier flags, suppresses matched events, and tracks active modifier layers. |
| Persistence and discovery | `KeyRuleStore.swift`, `AppDiscoveryService.swift` | Persists rules and action history under Application Support, migrates legacy KeyFlow files, scans application folders, and resolves localized app display names. |
| Action dispatch | `ActionDispatcher.swift` | Executes matched rule actions: open apps, open URLs, run shell commands, invoke built-in tools, synthesize key strokes, and lock the screen. |
| Built-in tools | `Tools/` | Provides shortcut-invoked tools through `KeyMasterTool`, `ToolInvocation`, and `ToolRegistry`. Current tools are area screenshot capture and Pomodoro timer. |
| Panel and keyboard UI | `ContentView.swift`, `KeyboardLayoutView.swift` | Renders the menu bar panel, visual keyboard layout, active modifier overlay, permission overlay, rule badges, and key interaction surface. |
| Action editor UI | `KeyActionMenuOverlay.swift`, `KeyActionMenuPopoverPresenter.swift`, `AnchoredFloatingWindowPresenter.swift` | Presents the floating action menu, modifier binding strip, action-kind submenu, app search, URL/command history, built-in tool rows, and key mapping picker. |
| Visual system | `LiquidGlassStyle.swift`, `WindowGlassConfigurator.swift`, `AppIconCache.swift` | Centralizes glass styling helpers, native window appearance configuration, and async app icon loading/cache. |

## Runtime Flows

### Launch and Panel Display

1. `KeyMasterApp` delegates lifecycle to `KeyMasterApplicationDelegate`.
2. The delegate creates an `NSStatusItem`, observes app/timer state, and lazily
   creates a borderless `KeyMasterPanelWindow`.
3. `KeyMasterPanelView` hosts `KeyboardLayoutView` and injects the shared
   `AppState`.
4. When the panel appears, `AppState` refreshes permissions and reloads local
   applications if needed.

### Rule Creation and Editing

1. `KeyboardLayoutView` opens `KeyActionMenuPopoverPresenter` for the clicked key.
2. `KeyActionMenuContent` selects a modifier combination and action kind.
3. The action submenu saves an app, URL, command, tool invocation, key mapping,
   or lock-screen action through `AppState.saveRule`.
4. `AppState` records action history when relevant, persists rules/history via
   `FileKeyRuleStore`, rebuilds its rule indexes, and syncs the event engine.

### Shortcut Execution

1. `AppState.syncKeyboardEngine` starts `KeyboardEventEngine` only when required
   permissions are present and at least one enabled rule exists.
2. `KeyboardEventEngine.start` compiles enabled rules into a shortcut lookup.
3. The CoreGraphics event tap handles key events, ignores synthetic events,
   normalizes modifier flags, and checks the lookup on key down.
4. A matching rule suppresses the original key event and dispatches work back to
   the main actor.
5. `ActionDispatcher` performs the selected side effect outside the event tap
   callback path.

### Built-In Tool Execution

1. The action editor exposes `ToolRegistry.shared.tools` as command-kind rows.
2. Saving a tool stores `KeyAction.runTool(ToolInvocation)` in the rule.
3. Runtime dispatch calls `ToolRegistry.run`.
4. The concrete tool runs on the main actor:
   - `ScreenshotAreaTool` starts `ScreenshotOverlayController`.
   - `PomodoroTool` starts or toggles the Pomodoro panel/timer.

## Ownership Boundaries

- `AppState` should remain the coordination boundary for UI-facing state and
  service synchronization.
- SwiftUI views should prefer calling `AppState` instead of directly starting
  services or mutating stores.
- `KeyboardEventEngine` should stay lightweight inside the event tap callback.
  Expensive side effects should continue to be dispatched out of the callback.
- `ActionDispatcher` owns runtime side effects. This keeps app launch, URL open,
  shell command execution, tool invocation, and synthetic keystrokes away from
  the rule model.
- `Tools/` is the extension point for built-in commands. New tools should add a
  `KeyMasterTool` implementation and register it in `ToolRegistry`.

## Important Risks

- Secure Input can prevent reliable keyboard monitoring.
- Some system shortcuts may not be interceptable.
- Accessibility and Input Monitoring permissions can change while the app is
  running.
- Screen capture requires additional macOS permission when using screenshot
  tools.
- Shell command execution is powerful and must remain explicit and visible.

## Cleanup Candidates

- Split `KeyActionMenuOverlay.swift` into focused files by responsibility:
  binding strip, app picker, URL/history picker, command/tool picker, key
  mapping picker, and shared menu metrics.
- Consider promoting the duplicated private `ShortcutKey` value in `AppState`
  and `KeyboardEventEngine` into a shared domain type if more modules need it.
- Add focused tests around rule persistence migration, rule indexing, action
  history trimming, and event repeat policy before expanding shortcut behavior.
