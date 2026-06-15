#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: xcodegen is not installed.

Install it with:
  brew install xcodegen

Then rerun:
  ./scripts/generate-xcodeproj.sh
EOF
  exit 127
fi

xcodegen generate --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR"
