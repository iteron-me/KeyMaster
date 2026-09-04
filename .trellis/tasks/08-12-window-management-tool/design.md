# Window Management Tool Design

## Boundaries

Window management is one registry-backed built-in tool with stable ID
`window.management`. Each saved rule uses the existing `runTool` action and a
string `operation` in `ToolInvocation.configuration`; no action enum, JSON
schema, archive format, or event-engine changes are needed.

`WindowManagementController` owns both the configuration window and execution.
The configuration window receives the existing application-wide `AppState`, so
all additions and removals flow through the current rule persistence and engine
sync methods. No second shortcut store is introduced.

## Configuration Window

The status-item right-click menu adds `Window Management...`. Its controller
owns one titled, closable window and brings the same instance forward on repeat
invocation.

The SwiftUI content shows four visual placement choices in a stable two-column
grid, followed by Next Display and Restore rows. Each choice lists matching
`AppState.rules` bindings and exposes an icon-only add button. Each binding is a
compact shortcut label with an icon-only remove button and tooltips.

While recording, a local AppKit key monitor consumes the next key-down. Escape
cancels. Modifier-only input is ignored, and a non-modifier key without Control,
Option, Shift, or Command is rejected visibly. A conflict with another rule is
shown in a confirmation alert before `AppState.saveRule` replaces it.

## Window Execution

Execution captures the current frontmost application's focused AX window before
KeyMaster activates any UI. It reads and writes `kAXPositionAttribute` and
`kAXSizeAttribute` and resolves the display by maximum frame intersection.

Accessibility frames use the global CoreGraphics top-left coordinate system.
`NSScreen.visibleFrame` is converted to the same coordinate system before frame
math. Left/right split the visible width evenly; Fill uses the visible frame;
Center preserves the current size while clamping it to the visible frame.

Next Display chooses the next `NSScreen` in stable screen order, maps the
window's relative origin between visible frames, preserves its size up to the
destination bounds, and clamps the result inside the destination visible frame.

Before a successful non-Restore operation, the controller keeps the window's
current frame in process memory, keyed by AX window identity. Restore applies
and removes that frame. This deliberately avoids a persistence format and stale
window identifiers across application launches.

## Compatibility And Failure

Existing rules and tools remain unchanged. A missing operation, missing focused
window, missing Accessibility permission, or an AX window that rejects position
or size updates results in no window mutation. Configuration remains available
even when Accessibility is missing, because assigning shortcuts does not itself
require that permission.

Rollback removes the new tool folder, its registry entry, and the right-click
menu item. Persisted invocations then follow the existing tool-not-found path;
all unrelated rules remain intact.
