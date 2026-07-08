# KeyMaster

KeyMaster is a native macOS keyboard shortcut automation app. It is intended as a visual, focused alternative to maintaining Hammerspoon automation scripts.

## Current Status

This repository contains the first buildable Xcode project:

- SwiftUI macOS app shell.
- Menu bar extra.
- Minimal single-window visual keyboard layout.
- Launcher key capture.
- Per-key action popovers.
- App, web, and command actions.
- Installed app discovery from local Applications folders.
- Permission status checks.
- CoreGraphics event tap engine for launcher-key combinations.
- Product and implementation docs.

## Requirements

- Xcode 26.5 or newer.
- XcodeGen for regenerating `KeyMaster.xcodeproj` from `project.yml`.
- macOS 15.0 deployment target with custom SwiftUI glass styling.
- Accessibility / input permissions for real keyboard interception.

Install XcodeGen with:

```sh
brew install xcodegen
```

## Project Generation

`project.yml` is the source of truth for Xcode project configuration. Regenerate the Xcode project after changing targets, files, build settings, or schemes:

```sh
./scripts/generate-xcodeproj.sh
```

## Open in Xcode

Open:

```sh
open KeyMaster.xcodeproj
```

If `xcode-select` still points at Command Line Tools, either switch it manually:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

or prefix CLI builds with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## CLI Build

Regenerate the project first, then use a DerivedData path outside the Desktop folder to avoid local file-provider extended attributes affecting code signing:

```sh
./scripts/generate-xcodeproj.sh

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project KeyMaster.xcodeproj \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyMasterDerived \
  build
```

For permission testing, prefer a stable app path:

```sh
./scripts/dev-run.sh
```

This regenerates `KeyMaster.xcodeproj`, builds the app, copies it to `/Applications/KeyMaster.app`, clears extended attributes, applies a stable local code requirement for `app.keymaster.mac`, and opens that stable app bundle. Grant macOS permissions to `/Applications/KeyMaster.app`, not to the temporary DerivedData app.

## Permissions

Global keyboard shortcuts need macOS privacy permissions. In the app, use the permission banner buttons to request permission, open the matching System Settings page, then click Refresh after enabling KeyMaster.

Required for the current shortcut engine:

- Accessibility
- Input Monitoring / Listen Events

Post Events is shown because future key remapping will need it, but the current App/Web/Command actions do not depend on it.

If Accessibility is checked but KeyMaster still shows it as missing, you are probably running a different app bundle than the one you authorized. Use the in-app `Running:` path and Finder button to confirm the exact bundle.

For local development, always launch through `./scripts/dev-run.sh`. Plain ad-hoc Debug builds are identified by a changing code hash, which can make macOS privacy permissions look like they disappeared after every rebuild. The dev-run script re-signs the installed app with a stable requirement so one authorization can survive rebuilds.

## Documentation

- [Product Requirements](docs/PRODUCT_REQUIREMENTS.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
