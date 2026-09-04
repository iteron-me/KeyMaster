# Screenshot Tool Contract

## Scenario: Frozen Area Capture

### 1. Scope / Trigger

Use this contract whenever screenshot selection, annotation, copy, pin, or save
behavior is changed. The area selector must show and export one immutable frame;
otherwise moving desktop content can differ between selection and output.

### 2. Signatures

The initial full-display capture is owned by `ScreenshotService.previewImage`:

```swift
static func previewImage(
    size: CGSize,
    on displayID: CGDirectDisplayID
) async throws -> CGImage
```

All confirmed selections must use the frozen-image export path:

```swift
static func capture(
    rect requestedRect: CGRect,
    annotations: [ScreenshotAnnotation] = [],
    from screenImage: CGImage,
    displaySize: CGSize
) throws -> NSImage
```

### 3. Contracts

- `screenImage` is the exact full-display image rendered behind the selector.
- `requestedRect` uses display points with a top-left origin.
- `displaySize` is the matching `NSScreen.frame.size` in points.
- Pixel scale is derived from image pixels divided by display points separately
  for X and Y.
- Copy, pin, and future save paths must crop `screenImage`; they must not capture
  the live display again.
- Annotated crops must be rasterized into a bitmap representation before copy or
  pin. Do not hand a lazy drawing-handler `NSImage` to the pasteboard.
- Copy must write PNG pasteboard data. If rasterization, PNG encoding, or the
  pasteboard write fails, throw `ScreenshotError.exportFailed` and show an alert.
- A display without a frozen image must not receive a transparent selection
  window.
- Selection windows must complete layout and display while transparent, then be
  revealed together with window animation disabled. Defer application
  activation until after reveal and use `makeKey()` instead of ordering the key
  window a second time.

### 4. Validation & Error Matrix

| Condition | Result |
|---|---|
| Display size is empty | `ScreenshotError.emptyCapture` |
| Selection is empty after clamping | `ScreenshotError.emptySelection` |
| Frozen image cannot produce a crop | `ScreenshotError.emptyCapture` |
| Initial display capture fails | Omit that display's selection window |
| Annotated export cannot rasterize or encode PNG | `ScreenshotError.exportFailed` |
| Clipboard PNG write fails | Show an alert and keep the overlay open |

### 5. Good / Base / Bad Cases

- Good: a video is playing, capture mode starts, and both the overlay and copied
  crop keep the same video frame.
- Base: a point-aligned selection on a 1x display returns matching pixel
  dimensions and annotations.
- Bad: close the overlay, delay, and call ScreenCaptureKit again to produce the
  confirmed selection.
- Bad: order each hosting window as it is created, then call
  `makeKeyAndOrderFront`, allowing an unrendered first frame or a second ordering
  transition to become visible.
- Bad: copy a large annotated crop as a lazy drawing-handler `NSImage`. Chat
  apps then paste nothing because PNG/TIFF encoding fails.

### 6. Tests Required

- Use asymmetric pixel colors to assert that a top-left selection is not
  vertically flipped.
- Assert Retina point-to-pixel dimensions.
- Assert out-of-bounds selections are clamped and expanded to integral pixel
  edges.
- Assert empty selections return `ScreenshotError.emptySelection`.
- When changing annotations, verify their exported positions against the same
  frozen crop.
- Assert annotated exports keep a bitmap representation and can encode PNG.
- Assert copy writes PNG pasteboard data.

### 7. Wrong vs Correct

```swift
// Wrong: preview one moment, export a later moment.
closeSelection()
try await Task.sleep(for: .milliseconds(80))
let image = try await captureLiveDisplay(rect)

// Correct: preview and export the same immutable frame.
let image = try ScreenshotService.capture(
    rect: rect,
    annotations: annotations,
    from: frozenScreenImage,
    displaySize: displaySize
)

// Wrong: copy a lazy annotated NSImage that cannot encode PNG.
return NSImage(size: imageSize, flipped: true) { rect in
    image.draw(...)
    return true
}

// Correct: rasterize first, then write PNG pasteboard data.
let image = try rasterizedAnnotatedImage(...)
try ScreenshotService.copyToPasteboard(image)

// Correct: render before reveal, then activate without reordering.
window.alphaValue = 0
window.contentView?.layoutSubtreeIfNeeded()
window.contentView?.displayIfNeeded()
window.animationBehavior = .none
window.alphaValue = 1
window.orderFrontRegardless()
DispatchQueue.main.async {
    NSApp.activate(ignoringOtherApps: true)
    window.makeKey()
}
```
