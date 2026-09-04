# 规划窗口管理工具

## Goal

Define a small, useful window-management tool for KeyMaster that lets users
move and resize the currently focused macOS window from global shortcuts,
without turning KeyMaster into a full tiling window manager.

## Background

- KeyMaster already binds global shortcuts to built-in tools through
  `KeyAction.runTool`, `ToolInvocation`, and `ToolRegistry`.
- KeyMaster already requires and checks macOS Accessibility permission, which
  is also the native mechanism needed to read and update another app's focused
  window.
- `ToolInvocation.configuration` can persist a stable operation value, so the
  existing rule format can represent window actions without a new action kind
  or persistence migration.
- The product request prioritizes the common core of established window
  managers and explicitly excludes unnecessary complexity.

## Requirements

- Window operations target the focused standard window of the app that was
  frontmost when the shortcut fired.
- Operations use the target display's visible frame so they respect the menu
  bar and Dock.
- The MVP favors direct, memorable shortcut actions over layouts, automation,
  or a persistent window-manager mode.
- Window management is configured as a set of fixed shortcut commands. Running
  a configured command performs the operation immediately and never opens a
  runtime window-management palette or overlay.
- The menu-bar right-click menu contains `Window Management...`, which opens one
  standard KeyMaster configuration window. Repeated use brings the same window
  forward instead of creating duplicates.
- The window uses compact desktop/window diagrams for spatial operations such
  as left half, right half, fill, and center. Non-spatial operations such as
  next display and restore appear as compact command rows below the diagram.
- Each operation displays any shortcuts already bound to it so the user can see
  the current configuration before assigning the selected keyboard trigger.
- Multiple keyboard triggers may bind the same window operation. Assigning the
  currently selected trigger does not silently remove any existing binding.
- Each operation provides a `+` control that records the next non-modifier key
  together with the held Control, Option, Shift, and Command modifiers.
- A recorded shortcut must contain at least one supported modifier. Escape
  cancels recording.
- If a recorded shortcut already belongs to another rule, the user must confirm
  replacement; cancellation preserves the existing rule.
- Each displayed binding provides a remove control that deletes only that rule.
- The six MVP operations are Left Half, Right Half, Fill, Center, Next Display,
  and Restore.
- Left Half, Right Half, Fill, and Center use the focused window's current
  display visible frame. Next Display preserves the window's relative size and
  position as far as the destination visible frame allows. Restore returns the
  same window to the frame captured before its most recent KeyMaster window
  operation during the current process; it is a no-op when no frame is known.
- The implementation, if approved later, reuses the existing built-in tool,
  invocation, shortcut, and Accessibility infrastructure.
- Existing rules, tools, and persisted data remain compatible.

## Acceptance Criteria

- [x] The final plan identifies a deliberately small MVP operation set.
- [x] The final plan recommends a coherent default shortcut scheme and notes
  likely macOS or application conflicts.
- [x] The configuration window provides a visual operation picker whose regions
  communicate the resulting window placement without relying on text alone.
- [x] Existing shortcut bindings are visible beside their corresponding window
  operations while configuring a new binding.
- [x] A user can add and remove multiple bindings per operation; plain keys are
  rejected, Escape cancels capture, and conflicting rules require confirmation.
- [x] The right-click menu opens one reusable standard configuration window.
- [x] Each proposed operation has defined focused-window and multi-display
  behavior.
- [x] Unsupported or intentionally deferred window-manager features are listed
  explicitly.
- [x] The plan describes how the feature fits the existing tool model without
  adding an unneeded dependency or persistence migration.

## Out of Scope

- Automatic tiling layouts and background window rearrangement.
- Per-app rules, saved workspaces, window gaps, and custom size ratios.
- Mouse dragging or screen-edge snapping.
- A standalone replacement for full window managers such as Rectangle, Magnet,
  or Moom.
- A duplicate `Command > Window Management` path in the key-first action editor.
- Persistent restore history across KeyMaster relaunches.
