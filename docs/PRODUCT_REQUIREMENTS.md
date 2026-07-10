# KeyMaster Product Requirements

## Goal

KeyMaster is a native macOS utility for visual keyboard shortcuts and local
automation. It targets users who currently rely on Hammerspoon, shell scripts,
or app launchers, but want a focused UI instead of handwritten configuration.

## Target Users

- Developers who use keyboard-first workflows.
- Keyboard-heavy macOS users who want reliable global shortcuts.
- Users who want Hammerspoon-like automation without Lua.
- Power users who want local, inspectable shortcut rules.

## Current Product Scope

KeyMaster should support:

- A visual ANSI keyboard layout as the primary configuration surface.
- Modifier-layer shortcuts using Control, Option, Shift, Command, or
  combinations of those modifiers.
- Click a key to configure an action for that shortcut.
- Open an installed app selected from the local app list.
- Search discovered local apps.
- Open a named URL.
- Run a named shell command explicitly through `/bin/zsh -lc`.
- Send a target key stroke as a simple key mapping.
- Trigger built-in tools.
- Lock the screen.
- Detect required Accessibility and Input Monitoring permissions.
- Persist rules and action history locally.

## Out of Scope For Now

- Mac App Store distribution.
- iCloud sync.
- Cloud backup.
- User behavior analytics.
- App-specific profiles.
- Complex chords and sequences.
- Full JIS / ISO keyboard layout support.

## Product Principles

- The keyboard layout is the primary configuration surface.
- Rules should be understandable without reading code.
- The app must be local-first and should not upload input data.
- Potentially dangerous automation, especially shell commands, must be explicit
  and visible.
- The event engine must be fast enough to feel native.

## Core Workflows

### Launch an App

1. User opens the menu bar panel.
2. User clicks a key in the keyboard layout.
3. User selects a modifier layer.
4. User selects App.
5. User chooses an installed app.
6. The saved shortcut opens that app globally.

### Run a Command

1. User opens the menu bar panel.
2. User clicks a key in the keyboard layout.
3. User selects a modifier layer.
4. User selects Command.
5. User enters a trusted shell command.
6. The saved shortcut runs through `/bin/zsh -lc`.

### Trigger a Built-In Tool

1. User opens the menu bar panel.
2. User clicks a key in the keyboard layout.
3. User selects a modifier layer.
4. User selects Command.
5. User chooses a built-in tool such as Screenshot Area or Pomodoro Timer.
6. The saved shortcut invokes the tool globally.

## System Permissions

KeyMaster depends on macOS privacy permissions:

- Accessibility: required for low-level keyboard control.
- Input Monitoring: required for global keyboard event listening.
- Screen Recording: required only for screenshot tools.
- Notifications: optional for Pomodoro alerts.

The app should detect permission status, explain missing permissions, and open
the relevant System Settings pane.

## Distribution Assumption

KeyMaster should be distributed with Developer ID signing and notarization. The
sandbox is disabled because global keyboard event taps, command execution, and
deep automation are not a good fit for the Mac App Store sandbox model.
