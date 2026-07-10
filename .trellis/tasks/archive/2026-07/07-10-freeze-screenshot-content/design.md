# Design: Frozen Screenshot Content

## Approach

Treat the full-display `CGImage` captured before the overlay appears as an
immutable capture-session snapshot. The snapshot has three consumers:

1. A full-window SwiftUI image background.
2. The existing cursor magnifier and pixel color sampler.
3. A new synchronous crop path used by copy and pin.

## Data Flow

1. `ScreenshotOverlayController` captures one snapshot for each `NSScreen`.
2. Only targets with a snapshot receive a selection window, preventing fallback
   to a transparent view of live content.
3. Each window remains transparent while its SwiftUI hierarchy performs a
   forced layout and display pass.
4. All prepared windows are revealed together with window animations disabled.
   Application activation is deferred to the next main-loop turn and only makes
   the first visible overlay key; it does not order the window a second time.
5. `ScreenshotSelectionView` renders the snapshot edge-to-edge below its dimming
   mask and selection controls.
6. Copy or pin returns the selection rectangle and annotations to the controller.
7. `ScreenshotService` converts the display-point rectangle to snapshot pixels,
   crops the snapshot, and renders annotations on that crop.
8. The controller closes the overlays and copies or pins the already-produced
   image without sleeping or re-capturing the display.

## Coordinate Contract

- Selection rectangles use display points with a top-left origin, matching the
  SwiftUI overlay and the existing ScreenCaptureKit `sourceRect` contract.
- Snapshot pixel scale is derived independently for X and Y from
  `image.width / displaySize.width` and `image.height / displaySize.height`.
- The requested rectangle is clamped to display bounds, then expanded outward
  to integral pixel edges so fractional point selections do not lose edge
  pixels.
- Annotation rendering continues to receive the requested and pixel-aligned
  rectangles in display points, preserving the existing mapping behavior.

## Compatibility And Failure Behavior

- No persisted model or project configuration changes are required.
- Multi-display behavior remains one immutable snapshot per display.
- A failed display snapshot is omitted rather than exposing live content through
  a transparent overlay.
- The existing live `capture` API can be removed if it has no other callers;
  ScreenCaptureKit remains responsible for initial full-display snapshots.

## Trade-Offs

- Full-resolution display snapshots consume memory for the lifetime of the
  selection session. This is already the current preview behavior and is needed
  for pixel-accurate output.
- Displays are captured sequentially, so separate screens can represent slightly
  different instants. Each individual screen remains internally consistent.
