# KeyFlow

KeyFlow is a native macOS keyboard shortcut automation app. It is intended as a visual, focused alternative to maintaining Hammerspoon automation scripts.

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
- XcodeGen for regenerating `KeyFlow.xcodeproj` from `project.yml`.
- macOS 26.0 deployment target for SwiftUI Liquid Glass.
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
open KeyFlow.xcodeproj
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
xcodebuild -project KeyFlow.xcodeproj \
  -scheme KeyFlow \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KeyFlowDerived \
  build
```

For permission testing, prefer a stable app path:

```sh
./scripts/dev-run.sh
```

This regenerates `KeyFlow.xcodeproj`, builds the app, copies it to `dist/KeyFlow.app`, clears extended attributes, and opens that stable app bundle. Grant macOS permissions to `dist/KeyFlow.app`, not to the temporary DerivedData app.

## Permissions

Global keyboard shortcuts need macOS privacy permissions. In the app, use the permission banner buttons to request permission, open the matching System Settings page, then click Refresh after enabling KeyFlow.

Required for the current shortcut engine:

- Accessibility
- Input Monitoring / Listen Events

Post Events is shown because future key remapping will need it, but the current App/Web/Command actions do not depend on it.

If Accessibility is checked but KeyFlow still shows it as missing, you are probably running a different app bundle than the one you authorized. Use the in-app `Running:` path and Finder button to confirm the exact bundle.

## Documentation

- [Product Requirements](docs/PRODUCT_REQUIREMENTS.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
