# KeyMaster

[Chinese](README.zh-CN.md) | English

KeyMaster is a native macOS menu bar app for creating global keyboard shortcuts
from a visual keyboard. Click a key, choose an action, and use the shortcut
anywhere on your Mac.

![KeyMaster keyboard overview](docs/screenshots/keyboard-overview.png)

## Modifier Layers

- **Click a key:** Edit the `Control` layer by default.
- **Hold modifiers:** Show shortcuts for the matching `Control`, `Option`,
  `Shift`, or `Command` layer. Multiple modifiers can be held together.
- **Hold and click:** Add or edit the action for that exact modifier layer.

## Actions

Each shortcut can use one of four action types:

![Choose an action for a key](docs/screenshots/action-picker.png)

### App

Search the apps installed on your Mac and assign one to a shortcut for quick
launching.

### Web

Save a named website and open it from anywhere with a shortcut.

### Command

Run shell commands.

**KeyMaster built-in tools:**

**Screenshot Area**

Select part of the screen, add rectangle or text annotations, then copy the
result or keep it floating as a pinned image.

<img src="docs/screenshots/screenshot-area.png" alt="KeyMaster Screenshot Area tool" width="600">

**Pomodoro Timer**

Run focus and break cycles with pause, skip, stop, notifications, and a live
countdown in the menu bar.

<img src="docs/screenshots/pomodoro-timer.png" alt="KeyMaster Pomodoro timer" width="360">

### Key Mapping

Map a shortcut to another key stroke or key combination. Example:

- `Control + I/J/K/L` → Up, Left, Down, and Right.
- `Control + Shift + I/J/K/L` → Directional text selection.

This layout reduces movement between the main keyboard area and the arrow keys.

## Configuration

Right-click the KeyMaster menu bar icon to import or export all shortcuts and
action history.

## Requirements

- macOS 15.0 or newer.
- Accessibility and Input Monitoring permissions for global shortcuts.

## Build From Source

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
brew install xcodegen
./scripts/dev-run.sh
```

`dev-run.sh` generates the Xcode project, builds KeyMaster, and installs the
development app at `/Applications/KeyMaster.app`.

More details: [Architecture](docs/ARCHITECTURE.md) · [Roadmap](docs/ROADMAP.md)
