#!/usr/bin/env bash
set -euo pipefail

COVERAGE_FILE="${1:-coverage/lcov.info}"
MIN_LINE_COVERAGE="${FRONTEND_MIN_LINE_COVERAGE:-2.5}"

if [[ ! -f "$COVERAGE_FILE" ]]; then
  echo "Coverage file not found: $COVERAGE_FILE"
  exit 1
fi

LINE_COVERAGE="$(awk -F: 'BEGIN{LF=0;LH=0} /^LF:/{LF+=$2} /^LH:/{LH+=$2} END{printf "%.2f", (LF?LH*100/LF:0)}' "$COVERAGE_FILE")"

if ! awk -v current="$LINE_COVERAGE" -v min="$MIN_LINE_COVERAGE" 'BEGIN { exit !(current + 0 >= min + 0) }'; then
  echo "Frontend coverage check failed: line coverage ${LINE_COVERAGE}% is below ${MIN_LINE_COVERAGE}%"
  exit 1
fi

echo "Frontend coverage check passed: line coverage ${LINE_COVERAGE}% (min ${MIN_LINE_COVERAGE}%)"
