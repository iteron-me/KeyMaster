# KeyFlow Agent Notes

## Project Summary

KeyFlow is a native macOS menu bar app for configuring launcher-key keyboard shortcuts visually. It is intended as a focused alternative to maintaining Hammerspoon scripts.

The current app lets users click keys in a visual keyboard layout and bind `Control` plus that key to one of three actions:

- Open a discovered local app.
- Open a URL.
- Run a shell command.

The runtime shortcut engine uses a CoreGraphics event tap, so real shortcut interception depends on macOS Accessibility and Input Monitoring permissions.

## Tech Stack

- Swift 6.0
- SwiftUI macOS app
- MenuBarExtra window-style UI
- CoreGraphics event taps for global keyboard monitoring
- XcodeGen project definition in `project.yml`
- Deployment target: macOS 26.0
- Bundle identifier: `app.keyflow.mac`

`project.yml` is the source of truth for the Xcode project. Regenerate `KeyFlow.xcodeproj` after changing targets, file groups, build settings, schemes, or resources.

## Important Commands

Regenerate the Xcode project:

```sh
./scripts/generate-xcodeproj.sh
```

Build from CLI:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project KeyFlow.xcodeproj -scheme KeyFlow -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/KeyFlowDerived build
```

Run a local development build with a stable installed app bundle and local signing requirement:

```sh
./scripts/dev-run.sh
```

Prefer `./scripts/dev-run.sh` for permission testing. Grant macOS permissions to `/Applications/KeyFlow.app`, not a temporary DerivedData bundle.

## Source Layout

- `KeyFlow/App/KeyFlowApp.swift`: app entry point and menu bar extra.
- `KeyFlow/App/AppState.swift`: central `ObservableObject`; owns UI state, loaded rules, installed apps, permission status, action history, and keyboard engine sync.
- `KeyFlow/Models/KeyRule.swift`: shortcut rules, triggers, actions, launcher key, and action history models.
- `KeyFlow/Models/KeyCatalog.swift`: visual keyboard key catalog and macOS virtual key codes.
- `KeyFlow/Services/KeyboardEventEngine.swift`: CoreGraphics event tap, active launcher-key detection, rule matching, event suppression, and action dispatch.
- `KeyFlow/Services/PermissionService.swift`: Accessibility and Input Monitoring checks/requests plus System Settings deep links.
- `KeyFlow/Services/KeyRuleStore.swift`: JSON persistence for rules and action history.
- `KeyFlow/Services/AppDiscoveryService.swift`: scans `/Applications`, `~/Applications`, and `/System/Applications` for app bundles.
- `KeyFlow/Views/ContentView.swift`: menu bar panel root.
- `KeyFlow/Views/KeyboardLayoutView.swift`: visual keyboard layout, key buttons, permission overlay, and action editor presentation.
- `KeyFlow/Views/LiquidGlassStyle.swift`: shared macOS 26 visual styling helpers.
- `KeyFlow/Views/WindowGlassConfigurator.swift`: native window glass configuration.
- `docs/`: product, implementation, and architecture notes.
- `scripts/`: project generation and development run helpers.

## Runtime Flow

1. `KeyFlowApp` creates `AppState` and shows `KeyFlowPanelView` inside a menu bar extra.
2. `AppState` loads persisted rules and action history from Application Support.
3. `AppState` refreshes permissions and starts or stops `KeyboardEventEngine`.
4. `KeyboardEventEngine` compiles enabled rules into lookup dictionaries keyed by launcher key code and target key code.
5. The event tap observes `keyDown`, `keyUp`, and `flagsChanged`.
6. If a pressed key matches an enabled launcher-key rule, the engine performs the action and suppresses the original event.

## Persistence

Rules are stored as JSON under the user Application Support directory:

- `~/Library/Application Support/KeyFlow/rules.json`
- `~/Library/Application Support/KeyFlow/action-history.json`

JSON uses pretty printed, sorted keys and ISO-8601 dates.

## Current Behavior And Limits

- The launcher key is currently fixed to Control (`LauncherKey.defaultKey`).
- The UI supports app, web, and command actions.
- Installed app discovery is enabled and performed asynchronously.
- App discovery has no search yet.
- The event engine normalizes left/right modifier variants for matching.
- Key repeat policy is not fully modeled yet.
- Secure Input and some system shortcuts may prevent reliable interception.
- Command execution is intentionally explicit and should stay treated as a high-risk capability.

## Development Guidance

- Keep `project.yml` and the generated Xcode project in sync when project structure changes.
- Keep `AppState` as the coordination boundary between SwiftUI and services unless there is a strong reason to split it.
- Avoid doing expensive work in the event tap callback. Dispatch side effects out of the callback path as the current engine does.
- Treat Accessibility and Input Monitoring state as dynamic; refresh permission status when the app becomes active or when the panel appears.
- Preserve user rules and history formats unless a migration is added.
- Be careful with user-facing command execution features. Do not silently add implicit shell behavior.
- Do not rely on ad-hoc DerivedData app bundles when debugging macOS privacy permissions; use the stable `/Applications/KeyFlow.app` path from `dev-run.sh`.

## Related Docs

- `README.md`: setup, build, run, and permission instructions.
- `docs/ARCHITECTURE.md`: high-level layers and event flow.
- `docs/PRODUCT_REQUIREMENTS.md`: product direction.
- `docs/IMPLEMENTATION_PLAN.md`: staged implementation plan.
