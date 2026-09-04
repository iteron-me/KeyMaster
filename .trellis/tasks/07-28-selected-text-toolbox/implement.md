# Action Palette Implementation Plan

## Checklist

- [x] Add pure selected-text validation, Google search URL construction,
  selection-anchor placement, and palette key-command mapping with focused
  unit tests.
- [x] Add the `ActionPaletteTool` entry point and register its stable
  `action.palette` invocation in `ToolRegistry`.
- [x] Add application-scoped Accessibility capture for the foreground app's
  focused selected text and optional bounds, with explicit permission, target,
  and selection failure results and no clipboard fallback.
- [x] Add the non-activating panel controller, compact Search chooser,
  selection-adjacent placement with upper-center fallback, toggle behavior,
  keyboard handling, outside-click and application-switch closing, and
  complete monitor cleanup.
- [x] Add the same-panel WebKit preview with stable expanded geometry, in-view
  HTTP(S) navigation, back, forward, reload, open-in-default-browser, close,
  loading, and failure states.
- [x] Confirm no generic plugin, provider, image-selection, translation, or
  persistence layer entered the first-version implementation.
- [x] Run focused tests and `./scripts/dev-run.sh`.

## Validation Commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyMasterDerived
./scripts/dev-run.sh
```

## Manual Verification

- Bind Action Palette to a global shortcut and invoke it with selected text in
  Finder or TextEdit and in a browser or Electron application.
- Confirm the chooser appears before any network request and offers only
  Search.
- Use Return to load Google results without activating an external browser;
  follow multiple result links inside the preview.
- Verify back, forward, reload, and open-in-browser behavior, including disabled
  navigation states and the user's default browser.
- Press Escape from the chooser, loading state, loaded preview, and error state;
  confirm the original selection and clipboard remain unchanged.
- Invoke with no selection and without Accessibility permission; confirm a
  concise failure state and no side effect.
- Verify the source application remains active while the palette is used and
  that outside click, application switch, repeated shortcut, and close all end
  the session cleanly.
- Verify selection-adjacent placement near the top, bottom, left, and right
  display edges and upper-center fallback in an app without AX selection bounds.

## Review Gates

- The foreground target and selected text are captured before any KeyMaster UI
  appears.
- No remote request occurs until Search is chosen.
- Only explicit open-in-browser leaves the embedded preview.
- AX and WebKit failures cannot change the source selection or clipboard.
- Existing persistence schemas and existing tool behavior remain unchanged.

## Rollback

Remove the Action Palette feature directory, its focused test file, and its
single `ToolRegistry` entry. No stored data migration or project-structure
rollback is required.
