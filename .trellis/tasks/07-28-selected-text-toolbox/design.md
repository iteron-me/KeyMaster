# Action Palette Technical Design

## Scope

Action Palette is a registry-backed KeyMaster built-in tool. Its name and
entry surface can support other selection types later, but the first version
implements one concrete path only: capture selected text, show a Search action,
and display Google results in an embedded web preview.

No generic selection payload, plugin protocol, action registry, AI provider, or
image capture layer is introduced in this version. Those contracts should be
designed only when a second concrete action or input type exists.

## Existing Boundaries To Reuse

- `KeyMasterTool`, `ToolInvocation`, and `ToolRegistry` already provide stable
  persistence and action-picker integration. Add one tool registration; do not
  change the stored rule format.
- `ApplicationCommandPaletteController` is the interaction precedent for
  capturing the foreground target before showing a non-activating panel,
  handling keyboard commands, placing the panel, closing on outside activity,
  and cleaning up event monitors.
- `NSWorkspace.shared.open` already represents the project's default-browser
  behavior.
- WebKit is a native system framework. No dependency or provider abstraction is
  needed.

The App Commands controller remains unchanged. Its panel lifecycle is followed
as a local pattern rather than extracted into a shared abstraction because the
two panels have different content, sizing, navigation, and session behavior.

## Components

### Tool Entry

`ActionPaletteTool` uses a stable `action.palette` identifier, the user-facing
title `Action Palette`, and a concise subtitle describing selection actions.
Running it toggles a shared `ActionPaletteController`.

### Selection Capture

Before presenting any KeyMaster UI, the controller captures the current
frontmost application and reads its focused Accessibility element through an
application-scoped `AXUIElement`. It reads `kAXSelectedTextAttribute`, trims
only for empty-selection validation, and retains the original text as the
search query. When available, it also reads `kAXSelectedTextRangeAttribute`
and resolves `kAXBoundsForRangeParameterizedAttribute` for palette placement.

The captured session contains only the source process identifier, selected
text, optional selection bounds, and display placement information. KeyMaster
never writes an AX value, sends a synthetic copy command, or reads or changes
the clipboard.

Capture produces one of these results:

- selected text ready for actions;
- Accessibility permission required;
- no eligible foreground application;
- no focused element or non-text/empty selection.

All failure results open the same compact panel with a concise non-destructive
state. The source application is rejected if it is KeyMaster itself or has
terminated.

### Action Chooser

The initial compact panel always shows an action chooser, even while Search is
the only action. Search is selected by default. Return runs it, arrow keys move
the selection when more actions exist, and Escape closes the entire palette.
Pointer activation remains available for accessibility and normal macOS use.

The chooser displays one direct Search row. It does not repeat the selected
content or contain explanatory copy, provider settings, or disabled future
actions.

### Web Preview

Choosing Search is the explicit remote-processing boundary. Only then does the
controller construct an HTTPS Google search URL with `URLComponents` and load
it in a `WKWebView` hosted by the same panel. This transition expands the panel
to a stable preview size on the captured display.

The preview toolbar contains native symbol buttons for browser back, forward,
reload, open in browser, and close. Disabled navigation buttons reflect
`WKWebView.canGoBack` and `canGoForward`; each icon has a tooltip and
accessibility label. Escape closes the palette without changing the source
selection.

HTTP and HTTPS links continue inside the existing web view, including links
that request a new browsing context. Unsupported URL schemes are cancelled so
only the explicit open-in-browser control can activate another application.
Open in browser passes the current page URL to `NSWorkspace.shared.open`, which
uses the user's default browser.

WebKit navigation errors retain the panel and show a concise retryable state.
No selection text, URL, or browsing history is persisted.

## Window And Session Lifecycle

Use a borderless non-activating `NSPanel` that can become key, matching the App
Commands behavior. This lets KeyMaster receive keyboard and WebKit interaction
without replacing the captured source application as the active application.

Place the compact chooser below the selection when space permits, above it when
needed, and clamp it to the source display's visible frame. If Accessibility
does not expose reliable bounds, fall back to the upper center of that display.
The web preview expands at a stable, fully visible position on the same display
rather than remaining constrained to the small selection anchor. A second
invocation toggles the palette closed. Outside clicks and activation of a
different application close the session. Closing removes monitors, clears the
web view and captured text, and prevents stale navigation callbacks from
updating a later session.

## Data Flow

```text
Shortcut
  -> ActionDispatcher
  -> ToolRegistry
  -> ActionPaletteTool
  -> capture source app + selected text locally
  -> show action chooser
  -> user chooses Search
  -> build Google URL
  -> WKWebView preview
  -> optional explicit open in default browser
```

## Compatibility And Migration

- Existing rule and history JSON formats do not change.
- Existing configured shortcuts and built-in tools are unaffected.
- Accessibility and Input Monitoring remain the only required permissions.
- The app sandbox remains disabled as in the current project configuration.
- Removing the tool requires deleting its feature files and registry entry; no
  persisted-data migration is needed.

## Verification

Keep automated checks around pure behavior only: selected-text normalization,
Google URL construction and encoding, selection-anchor placement, and keyboard
command mapping. AX capture, non-activation, WebKit rendering, navigation
controls, source-app focus, and default-browser opening require manual
verification in the installed development app.

## Risks

- Some applications and web content do not expose selected text through
  Accessibility. Report the failure without a clipboard fallback.
- Google can change or reject embedded browser behavior. Treat that as a load
  failure; do not add alternate providers in this task.
- A non-activating panel with an interactive web view must be verified on a
  stable installed bundle. If WebKit cannot accept interaction while retaining
  source-app activation, revisit the panel mechanism instead of silently
  changing the focus contract.
