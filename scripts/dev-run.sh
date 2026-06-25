#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="/private/tmp/KeyFlowDerived"
SOURCE_APP="$DERIVED_DATA/Build/Products/Debug/KeyFlow.app"
INSTALL_APP="/Applications/KeyFlow.app"
BUNDLE_IDENTIFIER="app.keyflow.mac"
CODE_REQUIREMENT="=designated => identifier \"$BUNDLE_IDENTIFIER\""

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

"$ROOT_DIR/scripts/generate-xcodeproj.sh"

xcodebuild \
  -project "$ROOT_DIR/KeyFlow.xcodeproj" \
  -scheme KeyFlow \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

osascript -e 'tell application "KeyFlow" to quit' >/dev/null 2>&1 || true

rm -rf "$INSTALL_APP"
ditto "$SOURCE_APP" "$INSTALL_APP"
xattr -cr "$INSTALL_APP"
codesign --force --sign - --requirements "$CODE_REQUIREMENT" "$INSTALL_APP"
codesign --verify --deep --strict "$INSTALL_APP"

open -n "$INSTALL_APP"
