# Implementation Plan

1. Add a frozen-image crop API in `ScreenshotService` that clamps and
   pixel-aligns a display-point selection, crops the supplied `CGImage`, and
   reuses annotation rendering.
2. Render `screenImage` as an edge-to-edge background in
   `ScreenshotSelectionView`, below the existing dimming and selection layers.
3. Update `ScreenshotOverlayController` to pass each frozen image into copy and
   pin callbacks, export synchronously from that image, remove the delayed live
   recapture path, and omit targets without a snapshot.
4. Prepare overlay windows offscreen, force their first layout/display pass,
   reveal them together without animation, and defer application activation so
   key-window changes happen behind the frozen frame.
5. Add focused tests for crop dimensions, edge clamping, Retina scaling, and
   frozen-frame pixel identity where practical through the app test target.
6. Run focused tests, then run `./scripts/dev-run.sh` as the required final
   verification.

## Risk And Rollback Points

- Verify top-left coordinate orientation with asymmetric test pixels; a vertical
  flip would make the output disagree with the selected area.
- Verify annotation mapping after crop refactoring.
- If SwiftUI image interpolation or sizing causes visual mismatch, use explicit
  resizable sizing to the geometry bounds without changing aspect ratio.
