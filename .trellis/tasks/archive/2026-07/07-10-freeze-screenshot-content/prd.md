# Freeze screenshot capture content

## Goal

Make area capture operate on a frozen screen frame so the selection UI and the
exported result always represent the moment capture began.

## Background

- `ScreenshotOverlayController.beginCapture()` already captures a full-display
  image before showing the overlay (`ScreenshotOverlayController.swift:24-30`).
- `ScreenshotSelectionView` currently uses that image only for the cursor
  inspector; its transparent window leaves live desktop content visible
  (`ScreenshotSelectionView.swift:31-48`,
  `ScreenshotOverlayController.swift:63-67`).
- Copy and pin close the overlay, wait 80 ms, and capture the live display again
  (`ScreenshotOverlayController.swift:97-139`), so the output can differ from
  what the user selected.

## Requirements

- R1. Display the initial full-display capture as the complete background of
  every screenshot selection window.
- R2. Keep the frozen image aligned with the corresponding screen across Retina
  and non-Retina scale factors.
- R3. Produce copy and pin output by cropping the same frozen image shown in the
  overlay, using the selected display-point rectangle.
- R4. Preserve rectangle/text annotations, color sampling, selection resizing,
  multi-display capture, and pinned-image placement behavior.
- R5. Do not perform a second ScreenCaptureKit capture when the user confirms a
  selection.
- R6. If an individual display cannot be captured, do not show a transparent
  live-content overlay for that display.
- R7. Present the prepared overlays atomically without a visible blank frame,
  window animation, or repeated ordering transition.

## Acceptance Criteria

- [x] AC1: After capture mode appears, animations, video, clocks, and other
  desktop content remain visually static behind the selection UI.
- [x] AC2: Moving or resizing the selection does not change the underlying
  pixels.
- [x] AC3: Copied and pinned images contain the exact pixels displayed inside
  the frozen selection, with correct dimensions on Retina and non-Retina
  displays.
- [x] AC4: Rectangle and text annotations remain positioned correctly in the
  exported crop.
- [x] AC5: Multi-display overlays each use and export their own frozen display
  image.
- [x] AC6: Existing screenshot interaction behavior builds successfully and the
  development verification script completes.
- [x] AC7: Entering capture mode does not visibly flash, shake, or momentarily
  reveal an unrendered overlay before the frozen frame appears.

## Out Of Scope

- Simultaneously synchronizing the capture timestamps of separate physical
  displays.
- Changing screenshot permissions, annotation UX, toolbar design, or output
  destination behavior.
