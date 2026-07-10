# Improve permission onboarding

## Goal

Make the first-run permission flow explicit so users can understand and grant
the two macOS permissions independently, see which permission has already been
granted, and reach the keyboard UI automatically once both permissions are
available.

## Background

- The keyboard engine requires both Accessibility and Input Monitoring.
- `PermissionStatus.canRunShortcutEngine` already represents the conjunction of
  those permissions in `KeyMaster/Services/PermissionService.swift`.
- `AppState` already exposes separate request methods for Accessibility and
  Input Monitoring in `KeyMaster/App/AppState.swift`.
- The current overlay in `KeyMaster/Views/KeyboardLayoutView.swift` presents a
  single `Grant Permissions` button, which makes the two-step system flow and
  partial completion state unclear.

## Requirements

- Replace the single permission action with two clearly separated permission
  items: Accessibility and Input Monitoring.
- Explain that Accessibility lets KeyMaster intercept configured shortcuts and
  that Input Monitoring lets KeyMaster detect global keyboard input.
- Each missing permission must have its own action that requests that specific
  permission and opens the matching System Settings pane.
- A granted permission must remain visible in the onboarding overlay with a
  clear success indicator and must not offer another grant action.
- Continue blocking interaction with the keyboard while either required
  permission is missing.
- Preserve the existing behavior that removes the overlay and reveals the main
  keyboard UI when both permissions are granted.
- Match the existing compact macOS panel and English interface style.

## Acceptance Criteria

- [x] With neither permission granted, the overlay shows two distinct grant
      actions with accurate names and purpose descriptions.
- [x] Granting Accessibility changes only its item to a granted success state;
      Input Monitoring remains actionable until granted.
- [x] Granting Input Monitoring changes only its item to a granted success
      state; Accessibility remains actionable until granted.
- [x] Each grant action invokes the existing permission-specific request and
      System Settings navigation path.
- [x] When both permissions are reported as granted, the permission overlay is
      no longer rendered and the keyboard UI is usable.
- [x] The layout fits within the existing fixed-size menu bar panel without
      clipping or overlapping controls.
- [x] `./scripts/dev-run.sh` completes successfully after the change.

## Out Of Scope

- Changing macOS permission APIs, entitlement behavior, or the stable installed
  app path used for privacy permissions.
- Adding localization infrastructure or translating the rest of the app.
- Changing the keyboard engine's requirement that both permissions are present.
