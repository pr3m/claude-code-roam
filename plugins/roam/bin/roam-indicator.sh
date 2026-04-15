#!/bin/bash
# roam-indicator.sh — status-line helper. Prints 🎒 (and optional extras) when
# roam is active, empty string otherwise. Must be fast: runs every statusLine
# refresh interval. No jq dependency in the happy path.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

STATE_FILE="$(roam_state_file)"
[ -f "$STATE_FILE" ] || exit 0

# Fast active check without jq: look for "active":true in the file.
grep -q '"active":\s*true' "$STATE_FILE" 2>/dev/null || exit 0

OUT='🎒'

VERBOSE="$(roam_config_read '.statusLineVerbose')"
if [ "$VERBOSE" = "true" ]; then
  # Add battery warning when low, thermal warning is noisier so skip.
  BAT="$(roam_battery_pct)"
  THRESH="$(roam_config_read '.batteryThreshold')"
  THRESH="${THRESH:-10}"
  if [ -n "$BAT" ] && [ "$BAT" -le "$THRESH" ]; then
    OUT="$OUT ⚠️ ${BAT}%"
  fi
fi

printf '%s' "$OUT"
