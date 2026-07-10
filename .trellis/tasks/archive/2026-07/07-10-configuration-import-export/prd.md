# Add configuration import and export

## Goal

Let users back up KeyMaster configuration to a portable local file and restore
it on another Mac without manually recreating shortcut rules.

## Background

- Shortcut rules and action history are currently stored as separate JSON files
  under Application Support through `FileKeyRuleStore`.
- Rules are portable because app actions reference bundle identifiers rather
  than machine-specific application paths.
- `AppState` is the existing coordination boundary for UI actions, persistence,
  rule indexing, and keyboard-engine synchronization.
- KeyMaster is local-first; importing and exporting must not upload data.
- Rule actions may contain URLs and explicit shell commands, so exported files
  can contain sensitive user-authored content.

## Requirements

- Keep left-click on the menu bar icon opening the keyboard panel. Add Import
  Configuration and Export Configuration commands to its right-click menu so
  the keyboard panel remains uncluttered.
- Export a single human-inspectable, versioned JSON file using a dedicated
  KeyMaster file extension.
- Default export names follow the short, sortable local-time pattern
  `KM-yyyyMMdd.config` with exactly one file extension.
- Include all currently persisted portable user data: shortcut rules and action
  history. Rule actions include apps, websites, commands, key mappings, lock
  screen actions, and built-in tool invocations.
- Export only portable configuration fields. Do not include rule UUIDs, derived
  display names, creation/update timestamps, or an export timestamp.
- Use native macOS open/save panels and explicit user-selected file locations.
- Validate imported data and reject malformed files, unsupported versions, and
  duplicate shortcut triggers without changing the current configuration.
- Make import transactional: only update in-memory state, persisted files, rule
  indexes, and the keyboard engine after the complete file is accepted.
- Import replaces all current shortcut rules and action history. Clearly warn
  about replacement and require confirmation before applying it.
- Show concise success and failure feedback in the app.
- Preserve imported app rules even when the referenced app is not installed on
  the destination Mac.
- Do not export permissions, machine paths, or other macOS-specific state.

## Acceptance Criteria

- [x] The menu bar icon's right-click menu exposes import and export commands
      without changing the visual keyboard workflow.
- [x] Export writes a versioned, portable KeyMaster configuration file selected
      through `NSSavePanel`.
- [x] The default export filename is short, time-based, sortable, and contains
      only one `.config` extension.
- [x] Import selects a file through `NSOpenPanel`, validates it before mutation,
      and requires replacement confirmation.
- [x] A successful import replaces the selected configuration data, persists it,
      rebuilds rule indexes, and resynchronizes the shortcut engine immediately.
- [x] Invalid, unsupported, or duplicate-trigger files leave the current rules
      untouched and present an actionable error.
- [x] Export followed by import preserves all supported configuration fields.
- [x] URL and command action history is preserved along with shortcut rules.
- [x] Exported rules omit internal UUID, derived-name, and timestamp metadata.
- [x] `./scripts/dev-run.sh` completes successfully.

## Out Of Scope

- Automatic sync, cloud backup, or background file watching.
- Exporting macOS privacy permissions or installed application binaries.
- Exporting transient runtime state such as active modifier keys, permission
  status, keyboard-engine state, or the current Pomodoro countdown.
- Automatically installing apps that are missing on the destination Mac.
