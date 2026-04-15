#!/bin/bash
# roam-watchdog.sh — polled by LaunchAgent every 60s. Handles auto-exit on
# battery/thermal limits and cleans up stale state from crashed sessions.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

[ "$(roam_platform)" = "darwin" ] || exit 0

STATE_FILE="$(roam_state_file)"
[ -f "$STATE_FILE" ] || exit 0

# Stale PID → clean up pmset + caffeinate, remove state.
if ! roam_pid_alive; then
  roam_log "watchdog: stale state (pid dead), cleaning up"
  CAFF="$(roam_state_read '.caffeinate_pid')"
  [ -n "$CAFF" ] && kill "$CAFF" 2>/dev/null
  ORIG="$(roam_state_read '.snapshot.disablesleep')"
  ORIG="${ORIG:-0}"
  # Non-interactive revert — requires passwordless sudo, otherwise skip.
  # (Best-effort: if sudo asks for password, this silently fails and the
  # state file is preserved for manual /roam:off cleanup on next session.)
  sudo -n pmset -a disablesleep "$ORIG" >/dev/null 2>&1 || \
    roam_log "watchdog: sudo not cached, pmset revert skipped"
  rm -f "$STATE_FILE"
  exit 0
fi

# Battery guard
BAT="$(roam_battery_pct)"
THRESH="$(roam_config_read '.batteryThreshold')"
THRESH="${THRESH:-10}"
if [ -n "$BAT" ] && [ "$BAT" -le "$THRESH" ]; then
  roam_log "watchdog: battery $BAT% ≤ $THRESH%, forcing exit"
  osascript -e "display notification \"Battery at ${BAT}% — exiting roam to save your work.\" with title \"🎒 Roam\" sound name \"Glass\"" 2>/dev/null || true
  # Non-interactive revert attempt, then force sleep to save work.
  sudo -n pmset -a disablesleep 0 >/dev/null 2>&1 || true
  CAFF="$(roam_state_read '.caffeinate_pid')"
  [ -n "$CAFF" ] && kill "$CAFF" 2>/dev/null
  rm -f "$STATE_FILE"
  # Don't force system sleep automatically — user may be mid-flight. Notification + revert is enough.
  exit 0
fi

exit 0
