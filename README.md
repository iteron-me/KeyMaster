# KeyMaster

[Chinese](README.zh-CN.md) | English

KeyMaster is a native macOS menu bar app for visually configuring global
keyboard shortcuts. It turns your keyboard into a launcher: click a key in the
visual layout, choose an action, then trigger it anywhere with a modifier-key
shortcut.

It is built for people who like the power of Hammerspoon, launchers, and shell
scripts, but want a focused UI instead of maintaining handwritten config.

## Screenshots

Screenshot placeholders for the public README:

| Keyboard Panel | Action Menu | Permission State |
| --- | --- | --- |
| `docs/screenshots/keyboard-panel.png` | `docs/screenshots/action-menu.png` | `docs/screenshots/permissions.png` |

## What It Does

- Configure shortcuts from a visual ANSI keyboard layout.
- Bind modifier-key combinations such as `Control + K` or `Command + Shift + P`.
- Open installed macOS apps discovered from local Applications folders.
- Open named URLs.
- Run explicit shell commands through `/bin/zsh -lc`.
- Send another key stroke as a simple key mapping.
- Trigger built-in tools such as area screenshot capture and Pomodoro timer.
- Store rules locally as JSON in your user Application Support directory.

## How To Use

1. Launch KeyMaster from the menu bar.
2. Grant the required macOS permissions when prompted.
3. Click a key in the visual keyboard.
4. Choose the modifier layer and action type.
5. Pick an app, URL, command, key mapping, or built-in tool.
6. Press the saved shortcut anywhere on macOS.

If you open the action menu without holding a modifier key, KeyMaster defaults
to the `Control` layer. Hold `Control`, `Option`, `Shift`, or `Command` while
editing to work on that layer directly.

## Permissions

Global keyboard interception depends on macOS privacy permissions:

- Accessibility: required for low-level shortcut handling.
- Input Monitoring: required to listen for global keyboard events.
- Screen Recording: required only when using the screenshot tool.
- Notifications: optional for Pomodoro timer alerts.

For local development and permission testing, always launch the stable app
bundle installed by:

```sh
./scripts/dev-run.sh
```

Grant permissions to `/Applications/KeyMaster.app`, not to a temporary
DerivedData build.

## Safety Notes

Shell commands are powerful. KeyMaster keeps command actions explicit and
visible, and runs them only after you bind them yourself. Do not bind commands
you do not understand.

KeyMaster is local-first. Shortcut rules and action history are stored locally:

```text
~/Library/Application Support/KeyMaster/rules.json
~/Library/Application Support/KeyMaster/action-history.json
```

## Requirements

- macOS 15.0 or newer.
- Xcode 26.5 or newer for building from source.
- XcodeGen for regenerating the Xcode project.
- Accessibility and Input Monitoring permissions for real shortcut interception.

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

## Build From Source

`project.yml` is the source of truth for the Xcode project. Regenerate the
project after changing targets, source groups, build settings, schemes, or
resources.

```sh
./scripts/generate-xcodeproj.sh
```

Build from the command line:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyMasterDerived \
  build
```

For day-to-day development, use:

```sh
./scripts/dev-run.sh
```

This regenerates the project, builds the app, installs it to
`/Applications/KeyMaster.app`, applies a stable local signing requirement, and
opens the installed app.

## Documentation

- [Product Requirements](docs/PRODUCT_REQUIREMENTS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Brand Notes](docs/brand/BRAND.md)
- [Archived Implementation Plan](docs/archive/IMPLEMENTATION_PLAN.md)

## License

License is not specified yet. Add a `LICENSE` file before publishing the
repository broadly.
