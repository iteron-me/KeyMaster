# Fix action menu vertical jumping

## Goal

Align the key action menu's top edge with the clicked key and keep it stable
after opening. Showing, hiding, or switching the secondary action panel must
lay content out downward from the same top edge instead of vertically
recentering the whole menu.

## Background

- `KeyActionMenuContent` already reserves the widest and tallest required menu
  frame and uses a top-aligned `HStack`
  (`KeyMaster/Views/KeyActionMenuOverlay.swift:15-35`).
- The fixed outer frame uses `alignment: .leading`. In SwiftUI this means
  horizontally leading but vertically centered. The `HStack` height changes
  when a taller secondary panel appears, so its vertical center changes inside
  the fixed frame and moves the primary panel.
- The anchored window receives one fixed content size when it is presented. Its
  horizontal placement is beside the clicked key, while its previous vertical
  placement centered the window on that key
  (`KeyMaster/Views/AnchoredFloatingWindowPresenter.swift:190-218`).

## Requirements

- R1: Top-align the action menu content within its existing fixed frame.
- R2: For left- or right-side placement, align the fixed frame's top edge with
  the clicked key's top edge whenever screen-edge clamping permits.
- R3: Keep the primary panel at the same screen position while secondary panels
  are shown, hidden, or switched.
- R4: Align every secondary panel with the primary panel's top edge and let its
  contents continue downward within the existing maximum-height frame.
- R5: Preserve current horizontal left/right placement, screen-edge clamping,
  menu dimensions, interactions, and action behavior.
- R6: While the keyboard window is active, pressing an unconfigured modified
  shortcut opens the rule editor anchored to its matching visual key.
- R7: Configured shortcuts and unmodified key presses retain existing behavior.
- R8: Escape closes an open rule editor.

## Acceptance Criteria

- [ ] AC1: Opening the menu aligns the fixed frame's top edge with the clicked
  key's top edge unless the frame must be clamped to remain on screen.
- [ ] AC2: Switching between no secondary panel and App, Website, Command, or
  Key Mapping does not move the primary panel vertically.
- [ ] AC3: Each visible secondary panel starts at the same top edge as the
  primary panel, including the taller Command panel.
- [ ] AC4: Left- and right-side submenu placement still works near screen edges.
- [ ] AC5: Pressing an unconfigured shortcut such as Control-Shift-A opens the
  editor at the A key with those modifiers selected.
- [ ] AC6: Configured shortcuts, auto-repeat, and unmodified key presses do not
  open another editor.
- [ ] AC7: Pressing Escape closes the open rule editor.
- [ ] AC8: `./scripts/dev-run.sh` succeeds; runtime and visual verification
  remain with the user.

## Technical Notes

- The content alignment changes from `.leading` to `.topLeading`.
- Horizontal placements use `sourceRect.maxY - contentSize.height` as the
  AppKit window origin, making the window's `maxY` equal the key's `maxY`.
- No dynamic resizing logic, dependency, or dedicated test target is required.

## Out Of Scope

- Redesigning either menu level or changing its dimensions.
- Changing horizontal placement or screen-edge clamping.
- Removing unrelated unused menu metrics or callbacks.
