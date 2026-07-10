#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/keymaster-env.sh"

VERSION=""
PUSH_RELEASE=false
PRIMARY_BRANCH="${KEYMASTER_RELEASE_BRANCH:-main}"
PREFLIGHT_DIR=""

usage() {
  cat <<'EOF'
Usage: ./scripts/release.sh VERSION [--push]

Without --push, the command prepares a local release commit and annotated tag.
With --push, it atomically pushes the branch and tag to trigger the draft release.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT

  if [[ -n "$PREFLIGHT_DIR" ]]; then
    if [[ "$status" == 0 ]]; then
      rm -rf "$PREFLIGHT_DIR"
    else
      echo "Preserved failed test results: $PREFLIGHT_DIR" >&2
    fi
  fi

  exit "$status"
}

is_release_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

version_is_greater() {
  awk -v candidate="$1" -v current="$2" 'BEGIN {
    split(candidate, a, ".")
    split(current, b, ".")
    for (i = 1; i <= 3; i++) {
      if ((a[i] + 0) > (b[i] + 0)) exit 0
      if ((a[i] + 0) < (b[i] + 0)) exit 1
    }
    exit 1
  }'
}

read_project_version() {
  awk '$1 == "MARKETING_VERSION:" { print $2 }' "$ROOT_DIR/project.yml"
}

remote_tag_exists() {
  local status
  set +e
  git ls-remote --exit-code --tags origin "refs/tags/$1" >/dev/null 2>&1
  status=$?
  set -e

  case "$status" in
    0) return 0 ;;
    2) return 1 ;;
    *) die "could not inspect remote tag $1" ;;
  esac
}

verify_release_changes() {
  local entry path
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    path="${entry:3}"
    case "$path" in
      project.yml|KeyMaster.xcodeproj/*) ;;
      *) die "unexpected release change: $path" ;;
    esac
  done < <(git status --porcelain --untracked-files=all)
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)
      PUSH_RELEASE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -* )
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$VERSION" ]] || die "only one version may be provided"
      VERSION="$1"
      shift
      ;;
  esac
done

[[ -n "$VERSION" ]] || {
  usage >&2
  exit 2
}
is_release_version "$VERSION" || die "version must use MAJOR.MINOR.PATCH with numeric components"

for command_name in git awk perl xcodebuild xcodegen; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command not found: $command_name"
done

cd "$ROOT_DIR"
trap cleanup EXIT

[[ -z "$(git status --porcelain)" ]] || die "working tree must be clean before preparing a release"

CURRENT_BRANCH="$(git branch --show-current)"
[[ "$CURRENT_BRANCH" == "$PRIMARY_BRANCH" ]] || \
  die "release must run from $PRIMARY_BRANCH, currently on $CURRENT_BRANCH"
git remote get-url origin >/dev/null 2>&1 || die "origin remote is not configured"

git fetch origin "$PRIMARY_BRANCH" --tags

TAG="v$VERSION"
EXPECTED_SUBJECT="chore(release): $VERSION"
CURRENT_VERSION="$(read_project_version)"
VERSION_COUNT="$(printf '%s\n' "$CURRENT_VERSION" | awk 'NF { count++ } END { print count + 0 }')"
[[ "$VERSION_COUNT" == "1" ]] || die "project.yml must contain exactly one MARKETING_VERSION"
is_release_version "$CURRENT_VERSION" || die "current MARKETING_VERSION is invalid: $CURRENT_VERSION"

if git show-ref --verify --quiet "refs/tags/$TAG"; then
  TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
  HEAD_SUBJECT="$(git log -1 --format=%s)"

  [[ "$TAG_COMMIT" == "$(git rev-parse HEAD)" ]] || die "$TAG already exists on another commit"
  [[ "$CURRENT_VERSION" == "$VERSION" ]] || die "$TAG does not match project version $CURRENT_VERSION"
  [[ "$HEAD_SUBJECT" == "$EXPECTED_SUBJECT" ]] || die "$TAG is not attached to the expected release commit"

  if remote_tag_exists "$TAG"; then
    echo "$TAG is already present on origin. No release state changed."
    exit 0
  fi

  [[ "$PUSH_RELEASE" == true ]] || {
    echo "$TAG is already prepared locally. To publish it, run:"
    echo "  ./scripts/release.sh $VERSION --push"
    exit 0
  }

  [[ "$(git rev-parse HEAD^)" == "$(git rev-parse "origin/$PRIMARY_BRANCH")" ]] || \
    die "prepared release is not exactly one commit ahead of origin/$PRIMARY_BRANCH"
  git push --atomic origin "$PRIMARY_BRANCH" "$TAG"
  echo "Pushed $TAG. GitHub Actions will create or update the draft release."
  exit 0
fi

remote_tag_exists "$TAG" && die "$TAG already exists on origin"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse "origin/$PRIMARY_BRANCH")" ]] || \
  die "local $PRIMARY_BRANCH must exactly match origin/$PRIMARY_BRANCH"

if [[ "$VERSION" != "$CURRENT_VERSION" ]]; then
  version_is_greater "$VERSION" "$CURRENT_VERSION" || \
    die "new version $VERSION must be greater than current version $CURRENT_VERSION"

  OLD_VERSION="$CURRENT_VERSION" NEW_VERSION="$VERSION" perl -0pi -e \
    's/^(\s*MARKETING_VERSION:\s*)\Q$ENV{OLD_VERSION}\E(\s*)$/$1$ENV{NEW_VERSION}$2/m' \
    project.yml
fi

"$ROOT_DIR/scripts/generate-xcodeproj.sh"

[[ "$(read_project_version)" == "$VERSION" ]] || die "failed to update MARKETING_VERSION"
git diff --check
verify_release_changes

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

PREFLIGHT_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/KeyMasterReleasePreflight.XXXXXX")"
xcodebuild \
  -project "$ROOT_DIR/KeyMaster.xcodeproj" \
  -scheme "$KEYMASTER_APP_NAME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$PREFLIGHT_DIR" \
  test
rm -rf "$PREFLIGHT_DIR"
PREFLIGHT_DIR=""

verify_release_changes
git add project.yml KeyMaster.xcodeproj
git diff --cached --check
git commit --allow-empty -m "$EXPECTED_SUBJECT"
git tag -a "$TAG" -m "$KEYMASTER_APP_NAME $VERSION"

if [[ "$PUSH_RELEASE" == true ]]; then
  git push --atomic origin "$PRIMARY_BRANCH" "$TAG"
  echo "Pushed $TAG. GitHub Actions will create or update the draft release."
else
  echo "Prepared $TAG locally. Review the release commit, then publish with:"
  echo "  ./scripts/release.sh $VERSION --push"
fi
