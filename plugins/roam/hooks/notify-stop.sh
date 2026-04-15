#!/bin/bash
# notify-stop.sh — Stop hook. Pushes a macOS notification when Claude stops,
# but ONLY when roam is active (we don't want to notify during normal desk work).

set -u
BIN_DIR="$(cd "$(dirname "$0")/../bin" && pwd)"
# shellcheck source=../bin/helpers.sh
. "$BIN_DIR/helpers.sh"

[ "$(roam_platform)" = "darwin" ] || exit 0
roam_active || exit 0

# Don't notify if the user is actively typing (they're already watching).
IDLE="$(roam_hid_idle_seconds)"
[ "$IDLE" -ge 30 ] || exit 0

osascript -e 'display notification "Claude has stopped — check your phone to continue." with title "🎒 Roam" sound name "Glass"' 2>/dev/null || true

exit 0
