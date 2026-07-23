# Design: Fix screen navigation targeting

## Scope

Repair the existing Accessibility-based Screen Navigation path. The initial
snapshot is authoritative for the session; scrolling and later UI movement do
not trigger rescans or relayout.

## Data Flow

```text
frontmost process
  -> focused AX window
  -> bounded visible-tree traversal
  -> actionable ScreenNavigationElement values (global AX/CG frames)
  -> visual ordering + 200-target cap + prefix-free hints
  -> per-display global-to-local frame conversion
  -> collision-aware adjacent hint rectangles
  -> SwiftUI overlay
```

The executor continues consuming the original global AX/CG frame. Only overlay
rendering consumes display-local frames, so rendering conversion cannot corrupt
the center-click fallback.

## Scanner Boundary

`AccessibilityElementScanner` will resolve exactly one root from
`kAXFocusedWindowAttribute`. It will not append `kAXWindowsAttribute` results.
If the frontmost application does not expose a focused window, the scan returns
the existing no-candidate result rather than spending a budget on an ambiguous
background window.

Traversal and output limits are separate:

- traversal has explicit depth and visited-node limits large enough for complex
  accessibility trees;
- traversal prefers navigation-order and visible children, while retaining
  ordinary children/contents as compatibility fallbacks;
- element identity uses equality as well as hashing, rather than treating a
  `CFHashCode` collision as identity;
- collection stops when its traversal budget is exhausted, then filters, sorts,
  and returns at most 200 targets.

Candidate classification will use a small testable policy combining:

- known interactive roles, expanded to common combo box, slider, tab,
  disclosure, incrementor, row, and cell variants;
- meaningful supported AX actions such as press, confirm, pick, and show-menu;
- whether `AXFocused` is settable for focusable controls;
- valid frames intersecting both the focused window and a CoreGraphics display;
- existing large text-area and near-duplicate suppression, tightened so a small
  contained child does not automatically erase a distinct actionable parent.

Large passive containers remain excluded. Applications that expose no usable AX
descendants remain outside the capability of this tool.

## Coordinate Contract

Introduce a value describing each overlay display:

- `displayID`;
- global AX/CG bounds from `CGDisplayBounds(displayID)`;
- AppKit window frame from `NSScreen.frame`;
- overlay-local bounds beginning at `(0, 0)`.

AX element frames remain in the global top-left CoreGraphics coordinate space.
For a target intersecting a display, overlay-local coordinates are calculated by
subtracting that display's `CGDisplayBounds` origin. `NSScreen.frame` is used
only to position the overlay `NSWindow`; it is never compared directly with an
AX frame.

This supports displays placed left, right, above, or below the main display and
keeps click execution in the coordinate system expected by `CGEvent`.

## Hint Layout

Move placement out of `ScreenNavigationOverlayView` into a pure layout helper.
For each target, generate nearby candidate rectangles above, below, right, and
left of the target, including edge-aligned variants. Select the nearest candidate
that:

1. stays inside the display;
2. does not intersect the target;
3. does not intersect an already placed hint.

When no collision-free candidate exists, choose the candidate with the lowest
combined target/hint overlap and clamp it inside the display. This keeps dense
interfaces usable without promising impossible non-overlap. Badge dimensions
are stable for one- and two-character hints so placement cannot shift during
rendering.

The overlay receives already converted target frames and hint rectangles. The
SwiftUI view renders the badge at the rectangle midpoint and no longer owns
coordinate math.

## Hint Encoding

`HintGenerator` will emit codes of one uniform length for a given session:

- up to 26 targets: one letter;
- 27 through 200 targets: two letters.

Uniform-length codes are prefix-free, preserve the current immediate-execution
controller logic, and stay within the agreed 200-target limit.

## Compatibility

- Preserve the existing tool ID, permission model, overlay window behavior,
  key monitor contract, and action execution order.
- Preserve pass-through arrow keys, but do not rescan after scrolling.
- No persistence or migration is needed.
- New Swift source/test files are included through existing XcodeGen source
  directories; regenerate `KeyMaster.xcodeproj` through the development script.

## Testing

Add focused unit coverage for:

- prefix-free hint generation at boundary counts 1, 26, 27, and 200;
- focused-window-only root selection and bounded traversal using a synthetic
  tree seam rather than relying on the host Mac's live AX tree;
- candidate classification for expanded actions/roles and passive containers;
- CoreGraphics global-to-overlay-local conversion for all display arrangements;
- adjacent hint placement, display clamping, and nearby-hint collision fallback.

Manual verification uses the stable `/Applications/KeyMaster.app` build against
at least one native window and one complex browser/Electron window. Multi-display
behavior is unit-tested geometrically; real multi-display testing is performed
when hardware is available and is not a blocker for this machine.

## Rollback

Changes remain confined to `Tools/ScreenNavigation`, focused unit tests, and the
generated Xcode project. The scanner, layout helper, and hint generator can be
reverted independently because persistence and public tool registration do not
change.
