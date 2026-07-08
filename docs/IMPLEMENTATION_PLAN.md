# KeyMaster Implementation Plan

## Technology Stack

- App platform: native macOS app.
- Language: Swift 6.
- UI: SwiftUI.
- State observation: `ObservableObject` for the initial build, with Observation framework as a later cleanup once macro execution is stable in the build environment.
- Menu bar: SwiftUI `MenuBarExtra`.
- Keyboard event engine: CoreGraphics `CGEvent.tapCreate`.
- App launching and System Settings integration: AppKit `NSWorkspace`.
- Command execution: Foundation `Process`.
- Persistence: SwiftData after the prototype model stabilizes.
- Build system: Xcode 26 project.
- Distribution: Developer ID signing and notarization.

## Phase 0: Project Foundation

Status: complete for the initial scaffold.

- Create Xcode macOS App project.
- Add SwiftUI shell with a minimal single-window keyboard layout.
- Add menu bar controls.
- Add permission service.
- Add event engine skeleton.
- Add documentation.
- Verify command-line build with Xcode.

Verified command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -derivedDataPath /private/tmp/KeyMasterDerived \
  build
```

## Phase 1: Event Engine

- Match launcher-key combinations.
- Avoid repeated triggers from key repeat unless the rule allows it.
- Move slow actions off the event callback path.
- Add an engine health state and error surface.
- Add tests for trigger matching and rule compilation.

## Phase 2: Persistence

- Introduce SwiftData models for profiles, rules, triggers, and actions.
- Add JSON import/export.
- Add default rules for Control H/J/K/L.
- Add migration strategy before 1.0.

## Phase 3: Rule Editing UX

- Replace free-form bundle identifier input with an app picker.
- Add validation for URLs and commands.
- Add conflict detection inside the current profile.
- Add command confirmation and per-command trust state.

## Phase 4: Profiles

- Add multiple profiles.
- Support global default profile.
- Support app-specific profiles by frontmost bundle identifier.
- Add profile switching from the menu bar.

## Phase 5: Reliability

- Detect Secure Input limitations and display a clear status.
- Restart event tap if macOS disables it.
- Add structured logging.
- Add crash-safe command execution behavior.
- Add release signing and notarization scripts.

## Phase 6: Polish

- Add custom app icon.
- Add onboarding and permission guide.
- Add keyboard layout variants.
- Add automatic launch at login.
- Add a compact menu-bar-only mode.

## Open Decisions

- Minimum macOS version: currently set to macOS 26.0 so the UI can use SwiftUI Liquid Glass APIs directly.
- Persistence timing: prototype currently keeps rules in memory; SwiftData should be introduced after action schemas settle.
- Caps Lock support: intentionally deferred because it may require a lower-level approach to be reliable.
- Key remapping support: intentionally deferred until the remapping model supports arbitrary source and destination combinations.
- App Store: not targeted for MVP.
