# Implementation Plan: Universal App Command Palette

## Checklist

- [x] Add pure command metadata, menu-leaf filtering, token search, ranking, and
  shortcut-label formatting with focused unit tests.
- [x] Add `ApplicationMenuSession` actor ownership for one activation snapshot,
  bounded `AXMenuBar` traversal, cancellation, structural item locators, and
  fresh-element `AXPick`/`AXPress` execution.
- [x] Add target capture for frontmost application metadata, focused-window
  display resolution, and fallback display selection.
- [x] Add the non-activating panel, observable loading/results/error state,
  upper-center display placement, automatic search focus, collapsed
  Spotlight-style search state, downward result expansion, and keyboard
  selection/activation.
- [x] Add controller lifecycle for toggle behavior, async scan delivery,
  session cancellation, outside-click monitors, target-app switch observation,
  successful close, and failed-execution retention.
- [x] Register `ApplicationCommandPaletteTool` in `ToolRegistry` and verify it
  appears in the existing built-in tool picker without action-model changes.
- [x] Run focused unit tests, regenerate the Xcode project, and run the complete
  test scheme.
- [ ] Run `./scripts/dev-run.sh` and manually verify Finder and Android Studio on
  the stable `/Applications/KeyMaster.app` bundle.

## Validation Commands

```sh
./scripts/generate-xcodeproj.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyMasterDerived
./scripts/dev-run.sh
```

## Manual Verification

- Bind `App Commands` to a global shortcut and trigger it in Finder.
- Confirm Finder remains the active application while typing in the palette.
- Search a nested Finder command by title and by parent-path token; invoke it
  with `Enter` and cancel another search with `Esc`.
- Trigger in Android Studio, type during loading, and find a nested command such
  as `View > Tool Windows > Logcat` using `tool log`.
- Verify disabled rows are visibly unavailable and do not invoke a fallback.
- Verify empty queries show no rows, eight rows fit in the panel, and additional
  results remain reachable by scrolling and arrow-key selection.
- Verify menu-command rows remain icon-free, the panel reads as translucent
  white, and the neutral selected row remains obvious without an accent fill.
- Verify the panel appears on the focused window's display.
- Verify outside click, `Command-Tab`, and the bound shortcut toggle close it.
- Verify a successful action closes the palette while an AX failure retains the
  query and displays an unavailable state.

## Review Gates

- The target application stays active while search text is entered.
- Menu scanning and AX calls do not block the main actor.
- Execution uses only the snapshot locator, validates the fresh item's original
  title, and invokes `AXPick`/`AXPress` without rebuilding search results.
- Search uses original menu text and the approved all-token matching/ranking
  contract.
- No history, aliasing, translation, semantic search, or persistence migration
  enters the MVP.
- Existing Screen Navigation behavior and files remain unchanged.

## Risk And Rollback Points

- Verify non-activating panel text entry before building additional UI states.
- Keep the scan actor session-local; stale task completions must not overwrite a
  newer activation.
- Treat unsupported AX attributes as absent and return bounded partial results.
- If a target application exposes lazy menus incompletely, document the
  limitation instead of opening menus during scanning.
- The feature can be removed by deleting its tool directory and test file and
  removing its single registry entry; persisted rules referencing the removed
  tool would then surface the existing tool-not-found behavior.
