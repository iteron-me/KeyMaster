# KeyMaster Agent Notes

## Project Summary

KeyMaster is a native macOS menu bar app for configuring global keyboard
shortcuts visually. It is intended as a focused alternative to maintaining
Hammerspoon scripts.

The current app lets users click keys in a visual keyboard layout and bind
modifier-key combinations to actions:

- Open a discovered local app.
- Open a URL.
- Run an explicit shell command.
- Send another key stroke.
- Run a built-in tool such as screenshot area capture or Pomodoro timer.
- Lock the screen.

The runtime shortcut engine uses a CoreGraphics event tap, so real shortcut
interception depends on macOS Accessibility and Input Monitoring permissions.

## Tech Stack

- Swift 6.0
- SwiftUI macOS app
- AppKit `NSStatusItem` plus a custom borderless panel window
- CoreGraphics event taps for global keyboard monitoring
- XcodeGen project definition in `project.yml`
- Deployment target: macOS 15.0
- Bundle identifier: `app.keymaster.mac`

`project.yml` is the source of truth for the Xcode project. Regenerate
`KeyMaster.xcodeproj` after changing targets, file groups, build settings,
schemes, or resources.

## Important Commands

Regenerate the Xcode project:

```sh
./scripts/generate-xcodeproj.sh
```

Build from CLI:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KeyMaster.xcodeproj -scheme KeyMaster -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/KeyMasterDerived build
```

Run a local development build with a stable installed app bundle and local
signing requirement:

```sh
./scripts/dev-run.sh
```

Prefer `./scripts/dev-run.sh` for permission testing. Grant macOS permissions to
`/Applications/KeyMaster.app`, not a temporary DerivedData bundle.

## Completion Verification

- After making code, project configuration, or source layout changes, run the
  development script before the final response:

```sh
./scripts/dev-run.sh
```

- This is the default verification path because it regenerates the project,
  builds the app, installs the stable bundle at `/Applications/KeyMaster.app`,
  applies the local signing requirement, and opens the installed app for
  permission-sensitive testing.
- If `./scripts/dev-run.sh` fails, include the relevant error lines and either
  fix the failure or clearly explain the blocker.
- If the user explicitly asks for build-only verification, use the CLI build
  command instead:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KeyMaster.xcodeproj -scheme KeyMaster -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/KeyMasterDerived build
```

- If the task only changes docs, comments, or asks for analysis without file
  edits, running `./scripts/dev-run.sh` is not required unless the user asks for
  it.
- Report whether the verification script or build succeeded.

## Source Layout

- `KeyMaster/App/KeyMasterApp.swift`: app entry point.
- `KeyMaster/App/KeyMasterApplicationDelegate.swift`: status item, panel window,
  outside-click closing, and status item updates.
- `KeyMaster/App/AppState.swift`: central `ObservableObject`; owns UI state,
  loaded rules, installed apps, permission status, action history, and keyboard
  engine sync.
- `KeyMaster/Actions/ActionDispatcher.swift`: app/URL/command/tool/key-stroke
  action execution.
- `KeyMaster/Models/KeyRule.swift`: shortcut rules, triggers, actions, modifier
  keys, key strokes, and action history models.
- `KeyMaster/Models/KeyCatalog.swift`: visual keyboard key catalog and macOS
  virtual key codes.
- `KeyMaster/Services/KeyboardEventEngine.swift`: CoreGraphics event tap, rule
  matching, event suppression, synthetic event ignoring, and action dispatch.
- `KeyMaster/Services/PermissionService.swift`: Accessibility and Input
  Monitoring checks/requests plus System Settings deep links.
- `KeyMaster/Services/KeyRuleStore.swift`: JSON persistence for rules and
  action history.
- `KeyMaster/Services/AppDiscoveryService.swift`: scans `/Applications`,
  `~/Applications`, and `/System/Applications` for app bundles.
- `KeyMaster/Services/KeyCaptureMonitor.swift`: local key capture and active
  modifier monitoring.
- `KeyMaster/Tools/`: built-in tools and tool invocation registry.
- `KeyMaster/Views/ContentView.swift`: panel root.
- `KeyMaster/Views/KeyboardLayoutView.swift`: visual keyboard layout, key
  buttons, permission overlay, and action editor presentation.
- `KeyMaster/Views/KeyActionMenuOverlay.swift`: action editor UI.
- `KeyMaster/Views/LiquidGlassStyle.swift`: shared visual styling helpers.
- `KeyMaster/Views/WindowGlassConfigurator.swift`: native window glass
  configuration.
- `docs/`: product, architecture, roadmap, brand, and archived notes.
- `scripts/`: project generation and development run helpers.

## Runtime Flow

1. `KeyMasterApp` delegates lifecycle to `KeyMasterApplicationDelegate`.
2. The delegate creates `AppState`, owns the menu bar status item, and opens
   `KeyMasterPanelView` in a custom panel window.
3. `AppState` loads persisted rules and action history from Application Support.
4. `AppState` refreshes permissions and starts or stops `KeyboardEventEngine`.
5. `KeyboardEventEngine` compiles enabled rules into a lookup keyed by modifier
   set and target key code.
6. The event tap observes `keyDown`, `keyUp`, and `flagsChanged`.
7. If a pressed key matches an enabled rule, the engine suppresses the original
   event and dispatches the action through `ActionDispatcher`.

## Persistence

Rules are stored as JSON under the user Application Support directory:

- `~/Library/Application Support/KeyMaster/rules.json`
- `~/Library/Application Support/KeyMaster/action-history.json`

JSON uses pretty printed, sorted keys and ISO-8601 dates.

## Current Behavior And Limits

- The editor defaults to the Control layer when no modifier is active.
- Rules can target Control, Option, Shift, Command, or combinations of these
  modifiers.
- The UI supports app, web, command, key mapping, lock-screen, and built-in tool
  actions.
- Installed app discovery is enabled, asynchronous, and searchable in the action
  picker.
- The event engine normalizes left/right modifier variants for matching.
- Auto-repeat is suppressed for non-repeatable actions and allowed for key
  stroke mappings.
- Secure Input and some system shortcuts may prevent reliable interception.
- Command execution is intentionally explicit and should stay treated as a
  high-risk capability.

## Development Guidance

- Keep `project.yml` and the generated Xcode project in sync when project
  structure changes.
- Keep `AppState` as the coordination boundary between SwiftUI and services
  unless there is a strong reason to split it.
- Avoid doing expensive work in the event tap callback. Dispatch side effects
  out of the callback path as the current engine does.
- Treat Accessibility and Input Monitoring state as dynamic; refresh permission
  status when the app becomes active or when the panel appears.
- Preserve user rules and history formats unless a migration is added.
- Be careful with user-facing command execution features. Do not silently add
  implicit shell behavior.
- Do not rely on ad-hoc DerivedData app bundles when debugging macOS privacy
  permissions; use the stable `/Applications/KeyMaster.app` path from
  `dev-run.sh`.

## Related Docs

- `README.md`: Chinese GitHub-facing setup, usage, and build guide.
- `README.en.md`: English GitHub-facing setup, usage, and build guide.
- `docs/PRODUCT_REQUIREMENTS.md`: product direction.
- `docs/ARCHITECTURE.md`: architecture, module map, and runtime flows.
- `docs/ROADMAP.md`: active roadmap.
- `docs/brand/BRAND.md`: brand notes.
- `docs/archive/IMPLEMENTATION_PLAN.md`: archived historical implementation plan.
