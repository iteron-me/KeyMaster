# KeyMaster Product Requirements

## Goal

KeyMaster is a native macOS utility for visual keyboard shortcuts and automation. It targets users who currently rely on Hammerspoon, shell scripts, or app launchers, but want a focused UI instead of handwritten configuration.

## Target Users

- Developers who use `Control + H/J/K/L` style navigation.
- Keyboard-heavy macOS users who want reliable global shortcuts.
- Users who want Hammerspoon-like automation without Lua.
- Power users who want profile-based mappings per workflow or app.

## MVP Scope

The MVP must support:

- A visual ANSI keyboard layout.
- A user-selected launcher key captured from keyboard input.
- Click a key to configure a launcher-key combination.
- Open an installed app selected from the local app list.
- Open a named URL.
- Run a named shell command.
- Pause and resume all mappings from the menu bar.
- Detect Accessibility, listen-event, and post-event permissions.
- Persist rules locally.

## Out of Scope for MVP

- Mac App Store distribution.
- iCloud sync.
- Caps Lock as a custom layer.
- Key remapping.
- Complex chords and sequences.
- Cloud backup.
- User behavior analytics.
- Full JIS / ISO keyboard layout support.

## Product Principles

- The keyboard layout is the primary configuration surface.
- Rules should be understandable without reading code.
- The app must be local-first and should not upload input data.
- Potentially dangerous automation, especially shell commands, must be explicit and visible.
- The event engine must be fast enough to feel native.

## Core Workflows

### Launch an App

1. User captures a launcher key.
2. User clicks a key.
3. User selects App.
4. User chooses an installed app.
5. User saves.
6. The launcher-key combination opens that app globally.

### Run a Command

1. User captures a launcher key.
2. User clicks a key.
3. User selects Command.
4. User enters a trusted shell command.
5. User saves.
6. The launcher-key combination runs through `/bin/zsh -lc`.

## System Permissions

KeyMaster depends on macOS privacy permissions:

- Accessibility: required for low-level keyboard control.
- Listen Event Access: required for global event listening on modern macOS.
- Post Event Access: required for synthetic key output.

The app should detect permission status, explain missing permissions, and open the relevant System Settings pane.

## Distribution Assumption

KeyMaster should be distributed with Developer ID signing and notarization. The sandbox is disabled because global keyboard event taps, command execution, and deep automation are not a good fit for the Mac App Store sandbox model.
