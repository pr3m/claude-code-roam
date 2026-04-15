#!/bin/bash
# roam-status.sh — inspect roam state.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

if ! roam_require_macos; then
  exit 2
fi

CONFIG_FILE="$(roam_config_file)"
STATE_FILE="$(roam_state_file)"

printf '\nclaude-code-roam — status\n\n'

# Config
if [ -f "$CONFIG_FILE" ]; then
  SSID="$(roam_config_read '.hotspot_ssid')"
  YOLO="$(roam_config_read '.yolo_enabled')"
  AUTODET="$(roam_config_read '.autoDetectLocalUse')"
  printf '  Config:        %s\n' "$CONFIG_FILE"
  printf '    hotspot:     %s\n' "${SSID:-(not set)}"
  printf '    yolo:        %s\n' "${YOLO:-false}"
  printf '    auto-detect: %s\n' "${AUTODET:-true}"
else
  printf '  Config:        (no config — first /roam will run setup)\n'
fi

printf '\n'

# State
if roam_active; then
  STARTED="$(roam_state_read '.started_at')"
  PID="$(roam_state_read '.pid')"
  CAFF="$(roam_state_read '.caffeinate_pid')"
  BAT="$(roam_battery_pct)"
  CUR_SSID="$(roam_current_ssid)"

  if roam_pid_alive; then
    ALIVE="✓ alive"
  else
    ALIVE="⚠️ dead — run /roam:off to cleanup"
  fi

  printf '  Roam:          🎒 ON\n'
  printf '    started:     %s\n' "$STARTED"
  printf '    pid:         %s (%s)\n' "$PID" "$ALIVE"
  printf '    caffeinate:  %s\n' "$CAFF"
  printf '    battery:     %s%%\n' "${BAT:-?}"
  printf '    ac power:    %s\n' "$(roam_on_ac && printf 'yes' || printf 'no')"
  printf '    current ssid:%s\n' "${CUR_SSID:- unknown}"
  printf '    lid:         %s\n' "$(roam_lid_open && printf 'open' || printf 'closed')"
else
  printf '  Roam:          off\n'
fi

printf '\n'
