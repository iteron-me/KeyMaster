#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="/private/tmp/KeyFlowDerived"
SOURCE_APP="$DERIVED_DATA/Build/Products/Debug/KeyFlow.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/KeyFlow.app"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

"$ROOT_DIR/scripts/generate-xcodeproj.sh"

xcodebuild \
  -project "$ROOT_DIR/KeyFlow.xcodeproj" \
  -scheme KeyFlow \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP"
ditto "$SOURCE_APP" "$DIST_APP"
xattr -cr "$DIST_APP"

open "$DIST_APP"
