# KeyMaster Roadmap

This is the active product and engineering roadmap. The older phase-by-phase
implementation plan is archived at `docs/archive/IMPLEMENTATION_PLAN.md`.

## Current Status

KeyMaster is an early native macOS build with these core pieces in place:

- Menu bar status item and custom panel window.
- Visual keyboard layout.
- Modifier-layer rule editing.
- App, web, command, key mapping, lock-screen, and built-in tool actions.
- Local app discovery with search.
- JSON rule and action-history persistence under Application Support.
- CoreGraphics event tap for global shortcut interception.
- Accessibility and Input Monitoring permission checks.
- Built-in screenshot-area and Pomodoro tools.

## Next Priorities

1. Reliability and diagnostics
   - Surface event tap failures in the UI.
   - Detect Secure Input limitations when possible.
   - Add lightweight structured logging for permission and engine state.

2. Rule editing safety
   - Add conflict detection for duplicate modifier/key bindings.
   - Add stronger URL validation.
   - Add explicit trust/confirmation affordances for shell commands.

3. Test coverage
   - Cover rule persistence migration.
   - Cover rule indexing and modifier matching.
   - Cover action history trimming and deletion.
   - Cover event repeat policy.

4. Onboarding and distribution
   - Add a first-run permission guide.
   - GitHub draft-release packaging is available for ad-hoc signed early builds.
   - Add Developer ID signing, Hardened Runtime, notarization, and stapling.

5. Larger features
   - Profiles and app-specific mappings.
   - Keyboard layout variants.
   - Launch at login.
   - Import/export for rules.

## Deferred

- Mac App Store distribution.
- iCloud sync.
- Cloud backup.
- User analytics.
- Full JIS/ISO keyboard layout support.
