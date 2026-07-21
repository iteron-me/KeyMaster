# 屏幕元素键盘导航实现计划

## Phase 1: Tool Shell

- Add `ScreenNavigationTool` implementing `KeyMasterTool`.
- Register it in `ToolRegistry`.
- Verify it appears in the existing built-in tool picker.
- Keep the default invocation unconfigured for MVP.

## Phase 2: Accessibility Scan Model

- Add `ScreenNavigationElement` model containing:
  - stable session-local ID
  - hint string
  - role/title summary
  - screen frame
  - execution kind
  - wrapped `AXUIElement`
- Add `AccessibilityElementScanner`.
- Scan the original frontmost app PID before any overlay window is shown.
- Traverse AX descendants with max depth and max candidate limits.
- Filter actionable candidates and sort by visual position.

## Phase 3: Hint Engine

- Add `HintGenerator`.
- Generate deterministic one- and two-letter hints from the chosen alphabet.
- Add unit tests for hint uniqueness and visual-order assignment if the project has a test target available; otherwise keep the generator pure so tests can be added later.

## Phase 4: Overlay Session

- Add `ScreenNavigationController` as the session owner.
- Add `ScreenNavigationOverlayController` using one transparent window per screen, following the screenshot overlay controller pattern.
- Add `ScreenNavigationOverlayView` to render hints and current typed prefix.
- Capture keyboard input while overlay is active:
  - letters update the prefix
  - `Backspace` removes last letter
  - `Esc` cancels
  - exact unique match executes
- Close every overlay window after execution or cancellation.

## Phase 5: Element Execution

- Add `AccessibilityElementExecutor`.
- Try `AXPress` first for pressable elements.
- Try focus for text fields/text areas.
- Add coordinate click fallback only when AX action/focus fails and the frame is still valid.
- Mark synthetic mouse/keyboard behavior clearly in code comments where needed.

## Phase 6: Permission And Edge Cases

- Reuse existing `PermissionService` Accessibility status.
- If missing permission, route to the existing Accessibility request/settings behavior.
- Close stale sessions when:
  - frontmost app PID changes
  - screen layout changes
  - overlay loses key status unexpectedly
- Handle empty candidate list with visible feedback.

## Phase 7: Verification

- Run `./scripts/dev-run.sh` after code changes.
- Manual checks:
  - bind `Screen Navigation` to a shortcut
  - trigger in Finder
  - trigger in Safari or another browser
  - trigger in System Settings
  - focus a text field by hint
  - press a button by hint
  - cancel with `Esc`
  - test at least one multi-display or full-screen-space scenario if available

## First MVP Boundary

Implement only Accessibility-based current-window navigation. Do not include OCR, browser DOM integration, semantic search, drag gestures, persistent per-app customization, or cloud/AI features in the first implementation pass.
