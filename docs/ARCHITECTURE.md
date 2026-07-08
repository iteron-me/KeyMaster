# KeyMaster Architecture

## Layers

### UI Layer

SwiftUI renders:

- Launcher key capture.
- Visual keyboard layout.
- Per-key action popovers.

The UI talks to `AppState`, an `ObservableObject` that owns selected UI state and delegates system concerns to services.

### Domain Layer

Current domain types:

- `KeyRule`
- `KeyTrigger`
- `KeyAction`
- `KeyOutput`
- `ModifierKey`
- `KeyboardKey`

The rule trigger is intentionally small: normalized modifiers plus a virtual key code. That keeps runtime matching fast.

### Service Layer

- `PermissionService`: checks macOS privacy and event permissions.
- `KeyboardEventEngine`: owns the CoreGraphics event tap and dispatches matched actions.
- `KeyRuleStore`: persists configured rules to local Application Support storage.
- `KeySender`: emits synthetic key events.
- `AppLauncher`: opens apps and URLs.
- `CommandRunner`: runs trusted shell commands outside the event callback path.

## Runtime Event Flow

1. `KeyboardEventEngine.start` compiles enabled rules into a dictionary.
2. `CGEventTap` receives keyboard events.
3. The callback extracts key code and modifier flags.
4. The engine builds a `KeyTrigger`.
5. If no rule matches, the original event is returned.
6. If a rule matches, KeyMaster performs the action and suppresses the original event.

## Important Risks

- Secure Input can prevent reliable keyboard monitoring.
- Some system shortcuts may not be interceptable.
- Shell command execution is powerful and must remain explicit.
- Accessibility and input permissions can change while the app is running.

## Current Prototype Limitations

- App selection uses discovered local apps but has no search yet.
- The event engine does not yet handle key-repeat policy.
