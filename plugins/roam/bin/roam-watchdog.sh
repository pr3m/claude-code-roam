#!/bin/bash
# roam-watchdog.sh — polled by LaunchAgent every 60s. Handles auto-exit on
# battery depletion and cleans up stale state from crashed sessions.
#
# Sleep strategy when auto-exiting:
#   1. Kill caffeinate (no sudo needed) → removes the keep-awake assertion.
#   2. Try passwordless pmset revert via sudo -n (works if user set up the
#      optional sudoers rule at install, or if sudo credential is still
#      cached — rare for long-running roam sessions).
#   3. Force sleep via AppleScript `tell application "System Events" to sleep`
#      — this is user-initiated sleep, which works regardless of whether
#      pmset disablesleep is still set. Machine actually goes to sleep and
#      preserves all work. pmset setting (if not reverted) is cleared on the
#      next reboot OR on the user's next interactive /roam:off.
#   4. Write a stale-revert breadcrumb so SessionStart can notify the user
#      on their next Claude Code session.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

[ "$(roam_platform)" = "darwin" ] || exit 0

STATE_FILE="$(roam_state_file)"
[ -f "$STATE_FILE" ] || exit 0

auto_exit() {
  local reason="$1"
  local force_sleep="${2:-false}"

  roam_log "watchdog: auto-exiting ($reason)"

  local CAFF
  CAFF="$(roam_state_read '.caffeinate_pid')"
  [ -n "$CAFF" ] && kill "$CAFF" 2>/dev/null

  local ORIG
  ORIG="$(roam_state_read '.snapshot.disablesleep')"
  ORIG="${ORIG:-0}"

  # Try the passwordless revert. Succeeds only if either sudo creds are
  # cached OR the user opted into the sudoers rule during /roam:install.
  local revert_ok=false
  if sudo -n pmset -a disablesleep "$ORIG" >/dev/null 2>&1; then
    revert_ok=true
  fi

  if [ "$revert_ok" = "false" ]; then
    # Leave a breadcrumb so next SessionStart can offer cleanup.
    mkdir -p "$(roam_data_dir)"
    printf 'watchdog-exit\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" \
      > "$(roam_data_dir)/pending-revert"
    roam_log "watchdog: pmset revert skipped (no passwordless sudo); breadcrumb written"
  fi

  rm -f "$STATE_FILE"

  if [ "$force_sleep" = "true" ]; then
    # User-initiated sleep via AppleScript — works even when disablesleep is
    # still set, and requires no sudo.
    osascript -e 'tell application "System Events" to sleep' >/dev/null 2>&1 || true
  fi
}

# Stale PID → clean up, don't force sleep (user may be at the desk again).
if ! roam_pid_alive; then
  auto_exit "stale state (pid dead)" false
  exit 0
fi

# Battery guard
BAT="$(roam_battery_pct)"
THRESH="$(roam_config_read '.batteryThreshold')"
THRESH="${THRESH:-10}"
if [ -n "$BAT" ] && [ "$BAT" -le "$THRESH" ]; then
  osascript -e "display notification \"Battery at ${BAT}% — exiting roam and sleeping your Mac to save your work.\" with title \"🎒 Roam\" sound name \"Glass\"" 2>/dev/null || true
  auto_exit "battery ${BAT}% ≤ ${THRESH}%" true
  exit 0
fi

exit 0
