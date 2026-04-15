#!/bin/bash
# roam-exit.sh — revert mobile mode. Idempotent: safe to run when nothing is active.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

roam_require_macos || exit 2

STATE_FILE="$(roam_state_file)"

if [ ! -f "$STATE_FILE" ]; then
  printf 'ℹ️  Roam is already off — nothing to revert.\n'
  exit 0
fi

# --- Read snapshot ---

ORIG_DISABLESLEEP="$(roam_state_read '.snapshot.disablesleep')"
ORIG_DISABLESLEEP="${ORIG_DISABLESLEEP:-0}"
CAFFEINATE_PID="$(roam_state_read '.caffeinate_pid')"

# --- Restore pmset ---

if sudo -n pmset -a disablesleep "$ORIG_DISABLESLEEP" >/dev/null 2>&1; then
  :
else
  export SUDO_ASKPASS="$SELF_DIR/sudo-askpass.sh"
  if ! sudo -A pmset -a disablesleep "$ORIG_DISABLESLEEP" >/dev/null 2>&1; then
    printf '⚠️  sudo declined — state file preserved, re-run /roam:off when ready.\n' >&2
    exit 5
  fi
fi

# --- Kill caffeinate ---

if [ -n "$CAFFEINATE_PID" ] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
  kill "$CAFFEINATE_PID" 2>/dev/null || true
fi

# --- Clean up ---

rm -f "$STATE_FILE"
roam_log "roam exited cleanly"

cat <<EOF

🎒 Roam is off.

  Sleep settings restored. You can close the lid to sleep as normal.

EOF
