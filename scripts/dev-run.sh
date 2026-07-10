#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/keymaster-env.sh"

DERIVED_DATA="/private/tmp/KeyMasterDerived"
SOURCE_APP="$DERIVED_DATA/Build/Products/Debug/$KEYMASTER_APP_NAME.app"
INSTALL_APP="/Applications/$KEYMASTER_APP_NAME.app"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

"$ROOT_DIR/scripts/generate-xcodeproj.sh"

xcodebuild \
  -project "$ROOT_DIR/KeyMaster.xcodeproj" \
  -scheme KeyMaster \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

osascript -e 'tell application "KeyMaster" to quit' >/dev/null 2>&1 || true

rm -rf "$INSTALL_APP"
ditto "$SOURCE_APP" "$INSTALL_APP"
xattr -cr "$INSTALL_APP"
codesign --force --sign - --requirements "$KEYMASTER_CODE_REQUIREMENT" "$INSTALL_APP"
codesign --verify --deep --strict "$INSTALL_APP"

open -n "$INSTALL_APP"
