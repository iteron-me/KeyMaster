# Implementation Plan: Fix screen navigation targeting

## Checklist

- [ ] Add failing tests for prefix-free hint generation at 1, 26, 27, and 200
  targets; change `HintGenerator` to session-wide fixed-length codes.
- [ ] Add pure display-geometry and hint-layout helpers with tests covering main
  display coordinates, displays on every side, target avoidance, edge clamping,
  and adjacent badge collisions.
- [ ] Update overlay models/controller/view so each window receives CG display
  bounds, converts AX frames once, and renders precomputed hint rectangles.
- [ ] Refactor the scanner behind a minimal test seam, select only the focused AX
  window, expand visible/navigation child discovery and actionable/focusable
  classification, and separate bounded traversal from the 200-target output cap.
- [ ] Add scanner regression tests for a synthetic tree containing more than
  1,200 structural nodes, expanded control kinds, hidden/off-window elements,
  and focused-window-only behavior.
- [ ] Verify the executor still receives global AX frames and that keyboard
  cancellation, Backspace, letter matching, and arrow pass-through code paths
  are unchanged.
- [ ] Regenerate the Xcode project and run the complete unit-test scheme.
- [ ] Run `./scripts/dev-run.sh`, confirm it installs and opens
  `/Applications/KeyMaster.app`, and manually inspect initial placement and
  target coverage in representative native and browser/Electron windows.

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

## Review Gates

- Generated hints are prefix-free for every supported target count.
- AX global frames never enter code that expects AppKit screen coordinates.
- The 200-target display limit does not also cap structural node traversal.
- The focused window is the only scan root.
- Hints avoid their targets whenever a valid adjacent rectangle exists.
- No implementation adds scroll-triggered rescanning or positioning.

## Risk And Rollback Points

- AX attribute reads vary by application. Treat unsupported attributes as empty
  and retain ordinary `AXChildren` fallback behavior.
- A larger traversal budget can increase launch latency. Keep explicit limits
  and measure manually before accepting the development build.
- Dense layouts may have no collision-free badge position. The deterministic
  minimum-overlap fallback must remain bounded and testable.
- If expanded role matching introduces passive targets, narrow the classifier
  without reverting coordinate or hint-encoding fixes.
