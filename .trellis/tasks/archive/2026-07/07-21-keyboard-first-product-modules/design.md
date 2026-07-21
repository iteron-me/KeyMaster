# 屏幕元素键盘导航设计

## Overview

该模块作为一个新的 `KeyMasterTool` 实现，沿用现有工具注册、快捷键触发和 overlay 控制器模式。核心路径是：

1. 快捷键触发 `ScreenNavigationTool.run(...)`。
2. `ScreenNavigationController` 检查 Accessibility 权限并开始 session。
3. `AccessibilityElementScanner` 扫描前台 App 的可见窗口元素。
4. `HintGenerator` 为候选元素分配短字母码。
5. `ScreenNavigationOverlayController` 在对应屏幕显示 hint overlay，并捕获键盘输入。
6. 输入匹配唯一 hint 后，`AccessibilityElementExecutor` 执行 `AXPress`、focus 或坐标点击兜底。
7. 关闭 overlay，结束 session。

## Proposed Files

- `KeyMaster/Tools/ScreenNavigation/ScreenNavigationTool.swift`
- `KeyMaster/Tools/ScreenNavigation/ScreenNavigationController.swift`
- `KeyMaster/Tools/ScreenNavigation/ScreenNavigationElement.swift`
- `KeyMaster/Tools/ScreenNavigation/AccessibilityElementScanner.swift`
- `KeyMaster/Tools/ScreenNavigation/AccessibilityElementExecutor.swift`
- `KeyMaster/Tools/ScreenNavigation/HintGenerator.swift`
- `KeyMaster/Tools/ScreenNavigation/ScreenNavigationOverlayController.swift`
- `KeyMaster/Tools/ScreenNavigation/ScreenNavigationOverlayView.swift`

If new source groups are added, `project.yml` remains the source of truth and `./scripts/generate-xcodeproj.sh` must be run through `./scripts/dev-run.sh`.

## Tool Integration

`ToolRegistry` should register `ScreenNavigationTool()` next to existing tools:

```swift
init(tools: [any KeyMasterTool] = [ScreenshotAreaTool(), PomodoroTool(), ScreenNavigationTool()])
```

The default invocation should be plain and stable:

```swift
ToolInvocation(toolID: "screen.navigation", displayName: "Screen Navigation")
```

No custom configuration is required for MVP.

## Element Scanning

The scanner should:

- Get the frontmost app from `NSWorkspace.shared.frontmostApplication`.
- Create an app AX element with `AXUIElementCreateApplication(pid)`.
- Read windows via `kAXWindowsAttribute`, falling back to focused window when available.
- Traverse descendants breadth-first with a depth and count cap.
- Keep only visible/enabled/actionable candidates with usable frames.
- Normalize frames into global screen coordinates.

Candidate roles for MVP:

- `AXButton`
- `AXLink`
- `AXTextField`
- `AXTextArea`
- `AXCheckBox`
- `AXRadioButton`
- `AXPopUpButton`
- `AXMenuButton`
- `AXMenuItem`
- selectable or pressable list/table rows when frame and action are available

Filtering rules:

- Drop elements with zero or tiny frames.
- Drop elements outside visible screen frames.
- Prefer children over parents when frames substantially overlap.
- Skip KeyMaster's own overlay windows to avoid self-targeting.
- Keep the candidate count capped, for example 120, to avoid unusable hint clutter.

## Hint Generation

MVP should generate deterministic hint codes from a fixed alphabet. Recommended alphabet:

```text
A S D F J K L Q W E R U I O
```

Generation strategy:

- For up to N elements, generate one-letter codes first.
- Then generate two-letter codes in lexical order from the same alphabet.
- Assign hints by visual order: top-to-bottom, left-to-right.
- During input, dim non-matching hints and execute immediately when exactly one complete hint matches.

## Overlay Behavior

Reuse the screenshot overlay pattern:

- One borderless transparent `NSWindow` per screen.
- Window level high enough to appear above normal app windows.
- `collectionBehavior` should join all spaces and support full-screen auxiliary behavior.
- Overlay should become key temporarily to receive hint keystrokes.
- `Esc` closes all overlay windows.

Unlike screenshot selection, this overlay should ignore mouse behavior conceptually; MVP does not need mouse interaction.

Hint UI should be compact:

- Small dark rounded rectangle with bright text.
- Anchor near the target element center or top-left, clamped inside the screen.
- Use enough contrast for light and dark apps.
- Avoid covering the entire element when possible.

## Execution Behavior

Execution order:

1. If element supports `kAXPressAction`, call `AXUIElementPerformAction(element, kAXPressAction)`.
2. If the role is text input or focusable, set `kAXFocusedAttribute` to `true`.
3. If AX action/focus fails and the element has a valid frame, post a left mouse down/up at the element center as explicit fallback.

The fallback click is allowed because the user intent is still keyboard-first operation, but it must remain a fallback rather than the primary mechanism.

## Permissions

MVP requires:

- Accessibility: scanning AX tree and performing AX actions.
- Input Monitoring: already required by KeyMaster's global shortcut engine.

Screen Recording is not required for MVP because there is no OCR or screenshot-based recognition.

When Accessibility is missing, the tool should not open an empty overlay. It should request permission or route users to the existing Accessibility settings flow.

## Failure Handling

- No frontmost app: show a short "No active app" state and exit.
- No candidates: show "No keyboard targets found" and exit after a short delay, or remain until `Esc`.
- AX scan timeout or too many elements: use partial results rather than blocking.
- Target disappears before execution: close overlay and do nothing.
- Foreground app changes during session: close overlay to avoid acting on stale coordinates.

## Risks

- Some apps expose poor Accessibility trees, especially custom-rendered views.
- Full-screen spaces and multi-display coordinate conversion need careful testing.
- Overlay becoming key may change the frontmost application; the controller must capture the original frontmost PID before showing overlay.
- Simulated click fallback can be surprising if coordinates are stale, so stale-session cancellation is important.
