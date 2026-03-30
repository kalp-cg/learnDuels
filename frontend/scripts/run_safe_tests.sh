#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SAFE_ROOT="/tmp/learndules_frontend_test_run"

rm -rf "$SAFE_ROOT"
mkdir -p "$SAFE_ROOT"
rsync -a --delete "$FRONTEND_DIR/" "$SAFE_ROOT/frontend/"

cd "$SAFE_ROOT/frontend"
flutter pub get
flutter analyze
flutter test --coverage
bash scripts/check_coverage.sh coverage/lcov.info

echo "Safe frontend checks passed from $SAFE_ROOT/frontend"
