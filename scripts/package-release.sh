#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/keymaster-env.sh"

EXPECTED_VERSION=""
BUILD_NUMBER=""
OUTPUT_DIR="$ROOT_DIR/dist"
KEEP_WORK_DIR=false
WORK_DIR=""
MOUNT_POINT=""
DMG_ATTACHED=false
DMG_PATH=""
CHECKSUM_PATH=""
ARTIFACTS_COMPLETE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/package-release.sh [options]

Options:
  --expected-version VERSION  Require the built marketing version to match.
  --build-number NUMBER       Override CFBundleVersion for this build.
  --output-dir DIRECTORY      Write artifacts here (default: dist/).
  --keep-work-dir             Preserve the temporary archive and staging files.
  -h, --help                  Show this help.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

is_release_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

read_plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"
}

verify_app() {
  local app_path="$1"
  local expected_version="$2"
  local expected_build="$3"
  local identifier version build minimum_system executable architectures signature_info

  [[ -d "$app_path" ]] || die "app bundle not found: $app_path"

  identifier="$(read_plist_value "$app_path" CFBundleIdentifier)"
  version="$(read_plist_value "$app_path" CFBundleShortVersionString)"
  build="$(read_plist_value "$app_path" CFBundleVersion)"
  minimum_system="$(read_plist_value "$app_path" LSMinimumSystemVersion)"
  executable="$(read_plist_value "$app_path" CFBundleExecutable)"

  [[ "$identifier" == "$KEYMASTER_BUNDLE_IDENTIFIER" ]] || \
    die "unexpected bundle identifier: $identifier"
  [[ "$version" == "$expected_version" ]] || \
    die "built version $version does not match expected version $expected_version"
  [[ "$build" == "$expected_build" ]] || \
    die "built number $build does not match expected build number $expected_build"
  [[ -n "$minimum_system" ]] || die "built app has no minimum macOS version"
  [[ -x "$app_path/Contents/MacOS/$executable" ]] || \
    die "main executable not found: $executable"

  architectures="$(lipo -archs "$app_path/Contents/MacOS/$executable")"
  [[ " $architectures " == *" arm64 "* ]] || die "built app is missing arm64"
  [[ " $architectures " == *" x86_64 "* ]] || die "built app is missing x86_64"

  codesign --verify --deep --strict "$app_path"
  signature_info="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
  [[ "$signature_info" == *"Signature=adhoc"* ]] || \
    die "built app does not have an ad-hoc signature"

  echo "Verified $KEYMASTER_APP_NAME $version ($build), macOS $minimum_system+, $architectures"
}

cleanup() {
  local status=$?
  trap - EXIT
  set +e

  if [[ "$DMG_ATTACHED" == true ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet
  fi

  if [[ "$ARTIFACTS_COMPLETE" != true ]]; then
    [[ -z "$DMG_PATH" ]] || rm -f "$DMG_PATH"
    [[ -z "$CHECKSUM_PATH" ]] || rm -f "$CHECKSUM_PATH"
  fi

  if [[ -n "$WORK_DIR" ]]; then
    if [[ "$KEEP_WORK_DIR" == true ]]; then
      echo "Preserved release workspace: $WORK_DIR"
    else
      rm -rf "$WORK_DIR"
    fi
  fi

  exit "$status"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-version)
      [[ $# -ge 2 ]] || die "--expected-version requires a value"
      EXPECTED_VERSION="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || die "--build-number requires a value"
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --keep-work-dir)
      KEEP_WORK_DIR=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [[ -n "$EXPECTED_VERSION" ]]; then
  is_release_version "$EXPECTED_VERSION" || \
    die "version must use MAJOR.MINOR.PATCH with numeric components"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)"
fi
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "build number must be a positive integer"

for command_name in xcodebuild xcodegen hdiutil ditto codesign lipo shasum; do
  require_command "$command_name"
done
[[ -x /usr/libexec/PlistBuddy ]] || die "required tool not found: /usr/libexec/PlistBuddy"

if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$PWD/$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/KeyMasterRelease.XXXXXX")"
MOUNT_POINT="$WORK_DIR/mount"
trap cleanup EXIT

ARCHIVE_PATH="$WORK_DIR/$KEYMASTER_APP_NAME.xcarchive"
DERIVED_DATA="$WORK_DIR/DerivedData"
SOURCE_APP="$ARCHIVE_PATH/Products/Applications/$KEYMASTER_APP_NAME.app"
STAGING_DIR="$WORK_DIR/dmg-root"
PACKAGED_APP="$STAGING_DIR/$KEYMASTER_APP_NAME.app"

"$ROOT_DIR/scripts/generate-xcodeproj.sh"

xcodebuild \
  -project "$ROOT_DIR/KeyMaster.xcodeproj" \
  -scheme "$KEYMASTER_APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  archive \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

[[ -d "$SOURCE_APP" ]] || die "archive did not contain $KEYMASTER_APP_NAME.app"

mkdir -p "$STAGING_DIR"
ditto "$SOURCE_APP" "$PACKAGED_APP"
codesign \
  --force \
  --deep \
  --sign - \
  --requirements "$KEYMASTER_CODE_REQUIREMENT" \
  "$PACKAGED_APP"

BUILT_VERSION="$(read_plist_value "$PACKAGED_APP" CFBundleShortVersionString)"
if [[ -z "$EXPECTED_VERSION" ]]; then
  EXPECTED_VERSION="$BUILT_VERSION"
fi
is_release_version "$EXPECTED_VERSION" || \
  die "built marketing version must use MAJOR.MINOR.PATCH"

verify_app "$PACKAGED_APP" "$EXPECTED_VERSION" "$BUILD_NUMBER"

ln -s /Applications "$STAGING_DIR/Applications"

DMG_NAME="$KEYMASTER_APP_NAME-$EXPECTED_VERSION-macos-universal.dmg"
CHECKSUM_NAME="$DMG_NAME.sha256"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
CHECKSUM_PATH="$OUTPUT_DIR/$CHECKSUM_NAME"

rm -f "$DMG_PATH" "$CHECKSUM_PATH"
hdiutil create \
  -volname "$KEYMASTER_APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"
hdiutil verify "$DMG_PATH"

mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_POINT" >/dev/null
DMG_ATTACHED=true

[[ -d "$MOUNT_POINT/$KEYMASTER_APP_NAME.app" ]] || die "DMG is missing $KEYMASTER_APP_NAME.app"
[[ -L "$MOUNT_POINT/Applications" ]] || die "DMG is missing the Applications link"
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] || \
  die "DMG Applications link has an unexpected target"
verify_app "$MOUNT_POINT/$KEYMASTER_APP_NAME.app" "$EXPECTED_VERSION" "$BUILD_NUMBER"

hdiutil detach "$MOUNT_POINT" -quiet
DMG_ATTACHED=false

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$DMG_NAME" > "$CHECKSUM_NAME"
)
ARTIFACTS_COMPLETE=true

echo "Created release artifacts:"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
