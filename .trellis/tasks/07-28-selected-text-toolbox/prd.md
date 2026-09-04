# Action Palette

## Goal

Add a keyboard-only built-in Action Palette that captures the current
foreground application's selection and lets the user choose a relevant action
without reaching for the pointer. The first version supports selected text
only.

## Background

- KeyMaster can already bind a built-in tool to any supported global shortcut
  through `KeyAction.runTool` and `ToolRegistry`.
- The existing App Commands palette provides a reusable interaction precedent
  for a compact, searchable, keyboard-operated panel.
- KeyMaster already requires Accessibility and Input Monitoring permissions,
  but it does not currently read the focused application's selected text.
- The palette name is intentionally independent of input type so later versions
  can support selections such as images without renaming the feature.
- The first version is intentionally limited to selected-text search.
  Translation remains a possible later AI-backed capability and must not be
  included until its provider and interaction are designed.

## Requirements

- The user can bind and invoke an Action Palette built-in tool.
- Invocation captures the foreground application and its current selected text
  before KeyMaster presents any UI that could change focus.
- The palette is fully operable with the keyboard and can be dismissed without
  modifying the source text.
- Invocation first presents an action chooser even when only one action is
  available, preserving a stable entry point for later selected-text actions.
- The chooser appears adjacent to the selected content when Accessibility
  exposes reliable selection bounds, and otherwise falls back to the upper
  center of the source application's display.
- The first-version tool contains only Search.
- Search loads results in a compact KeyMaster-owned WebKit preview instead of
  activating a full external browser.
- Search uses Google in the first version; there is no search-provider setting.
- Links can be followed inside the preview without leaving the KeyMaster flow.
- The preview provides explicit back, forward, reload, and open-in-browser
  controls. Only the open-in-browser command transfers the current page to an
  external browser.
- Failure to read a selection or load remote content must not modify the source
  text or clipboard contents.
- The source application remains the action target even while the palette UI is
  visible.
- Selected text is sent to Google only after the user explicitly invokes the
  Search tool.

## Acceptance Criteria

- [ ] A configured global shortcut opens the Action Palette for a non-empty
  selection in a supported macOS application.
- [ ] Invoking the tool offers only Search behavior; no translation control or
  provider is present.
- [ ] Invocation shows the action chooser before Search runs.
- [ ] The chooser anchors beside the selection when bounds are available and
  remains usable at its display fallback position when they are not.
- [ ] Search results load in a compact embedded web preview without activating
  an external browser.
- [ ] The user can navigate within the preview and explicitly open the current
  page in an external browser.
- [ ] `Esc` closes the palette without changing the selected text.
- [ ] Missing or inaccessible selected text produces a concise failure state and
  no destructive side effect.

## Out of Scope

- User-authored plugins, macros, or arbitrary transformation scripts.
- Case conversion, JSON formatting, URL encoding, and other local text
  transformations.
- OCR for text that is visible but not exposed as a selectable text value.
- Maintaining a history database of selected text or transformed results.
- Background monitoring of selections before the tool is invoked.
- Translation, including direct translation providers and AI-backed
  translation.
- Image and other non-text selection types.
