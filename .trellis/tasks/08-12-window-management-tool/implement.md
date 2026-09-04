# Window Management Tool Implementation

1. Add the window operation model, invocation encoding, focused-window AX
   execution, display geometry, and session restore storage under
   `KeyMaster/Tools/WindowManagement/`.
2. Add the reusable AppKit configuration-window controller and compact SwiftUI
   operation grid with binding display, recording, conflict confirmation, and
   removal.
3. Add the minimum `AppState` API needed to save a captured `KeyTrigger` and
   query window-operation rules without duplicating persistence logic.
4. Register the built-in tool and add `Window Management...` to the existing
   status-item right-click menu.
5. Add focused unit tests for operation invocation parsing and pure display
   frame calculations.
6. Run `./scripts/dev-run.sh`. Leave visual and live third-party-window behavior
   verification to the user per project policy.

## Rollback Points

- Tool execution and geometry are isolated in the new tool folder.
- The only existing-file integration points are `AppState`, `ToolRegistry`, and
  `KeyMasterApplicationDelegate`.
- No persistence migration or project source-list edit is required because the
  target already includes the `KeyMaster/Tools` directory.
