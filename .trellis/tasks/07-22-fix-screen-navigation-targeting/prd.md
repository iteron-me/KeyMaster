# Fix screen navigation targeting

## Goal

Fix the existing Screen Navigation tool so its initial overlay exposes a useful
set of keyboard targets, places each hint accurately beside its Accessibility
element without obscuring the control, and gives every displayed target a
selectable hint.

## Background

- The current scanner breadth-first traverses at most 1,200 AX elements and 10
  levels, then keeps at most 120 targets. In complex web, Electron, and SwiftUI
  trees this can stop before content controls are reached while retaining the
  window close, minimize, and zoom buttons
  (`AccessibilityElementScanner.swift:107-145,373-399`).
- Candidate recognition uses a narrow role set and reads only `AXChildren` and
  `AXContents`, excluding common actionable or focusable controls exposed through
  other roles or visible-child collections
  (`AccessibilityElementScanner.swift:147-185,380-399`).
- Hint centers are placed eight points right and seven points down from the AX
  frame's top-left corner, which deliberately overlaps small controls and has no
  collision handling (`ScreenNavigationOverlayView.swift:52-67`).
- AX/CG global display coordinates are compared directly with AppKit
  `NSScreen.frame`. This is not a valid multi-display conversion when displays
  have different vertical origins (`AccessibilityElementScanner.swift:215-230`,
  `ScreenNavigationOverlayView.swift:34-67`).
- The generator mixes one-letter hints with two-letter hints that share those
  prefixes. Once more than 26 targets exist, a one-letter target can no longer
  become the sole exact match (`HintGenerator.swift:11-37`,
  `ScreenNavigationController.swift:72-85`).
- The previous feature task explicitly left multi-display placement awaiting
  manual verification.

## Requirements

- R1: Scan only the frontmost application's currently focused AX window. Traverse
  that window's initially visible Accessibility tree far enough to discover
  ordinary content controls in complex windows, rather than commonly returning
  only standard window controls. Do not spend the scan budget on the same
  application's other windows.
- R2: Recognize common actionable and focusable AX controls using their roles,
  supported actions, and relevant visible child collections without turning
  large passive containers into targets.
- R3: Keep scanning bounded so invoking Screen Navigation cannot hang the event
  path or leave the UI unresponsive. Display at most 200 initially visible
  targets; keep the traversal budget separate from this display limit so
  structural AX nodes do not prematurely consume the target allowance. Partial
  results remain acceptable for very large or poorly exposed AX trees.
- R4: Convert AX global frames into the correct per-display overlay coordinate
  space before visibility filtering and hint placement.
- R5: Place hints adjacent to their target frame and avoid covering the target
  whenever screen space permits. Edge clamping and nearby-hint collision handling
  must keep hints readable and associated with the correct target.
- R6: Generate prefix-unambiguous hints so every displayed target can be selected
  using the existing immediate-execution interaction.
- R7: Preserve the existing execution order: `AXPress`, focus for focusable
  controls, then an explicit center-click fallback.
- R8: Keep the tool Accessibility-only. Do not add OCR, screenshot recognition,
  browser DOM integration, or remote processing.
- R9: Do not rescan or reposition targets after the foreground content scrolls.
  Correct initial placement is the scope of this bug fix.
- R10: Preserve the existing keyboard contract for `Esc`, `Backspace`, letters,
  and pass-through arrow keys.

## Acceptance Criteria

- [ ] AC1: A complex AX fixture/tree with more than 1,200 structural nodes still
  yields representative visible content controls, subject to an explicit bounded
  scan policy.
- [ ] AC2: Tests cover common button/link/input controls plus additional
  actionable, focusable, and visible-child cases, while passive oversized
  containers remain excluded.
- [ ] AC3: Initial target frames map correctly into overlay-local coordinates for
  the main display and displays arranged left, right, above, or below it.
- [ ] AC4: Hint placement tests verify that a hint does not intersect its target
  when adjacent screen space exists, remains within its display, and avoids
  identical placement with a nearby hint when alternatives exist.
- [ ] AC5: For every target count from 1 through the 200-target display limit,
  every generated hint is unique and no hint is a prefix of another hint.
- [ ] AC6: Existing cancellation, input filtering, AX execution fallback, and
  arrow-key pass-through behavior continue to work.
- [ ] AC7: `./scripts/dev-run.sh` succeeds and launches the stable
  `/Applications/KeyMaster.app` build.

## Out Of Scope

- Updating hint positions or rescanning targets after scrolling or other UI
  movement.
- Scanning background, unfocused, or otherwise non-current windows, including
  other windows owned by the frontmost application.
- Detecting controls that the target application does not expose through macOS
  Accessibility.
- OCR, image recognition, browser-specific DOM access, drag-and-drop, or Canvas
  element navigation.
- Changing shortcut persistence, tool registration, or the existing permission
  model.
