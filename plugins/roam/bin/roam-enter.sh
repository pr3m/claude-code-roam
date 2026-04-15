#!/bin/bash
# roam-enter.sh — apply mobile mode (keep-awake, snapshot, watchdog).
# Assumes config exists (skill handles first-run wizard before calling this).

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

roam_require_macos || exit 2
roam_ensure_dir

STATE_FILE="$(roam_state_file)"
CONFIG_FILE="$(roam_config_file)"

if [ ! -f "$CONFIG_FILE" ]; then
  printf 'needs-setup\n'
  exit 3
fi

if roam_active && roam_pid_alive; then
  printf '🎒 Roam is already on. Use /roam:status to inspect.\n'
  exit 0
fi

# If a stale state file exists with dead PID, clean it out silently.
if [ -f "$STATE_FILE" ] && ! roam_pid_alive; then
  rm -f "$STATE_FILE"
fi

# --- Pre-flight checks ---

if ! roam_on_ac; then
  cat <<EOF >&2
❌ Roam requires AC power.

Battery alone + lid closed + sustained CPU = thermal + battery damage risk.
Plug in before running /roam.
EOF
  exit 4
fi

HOTSPOT_SSID="$(roam_config_read '.hotspot_ssid')"
CURRENT_SSID="$(roam_current_ssid)"

# --- Snapshot current state ---

ORIG_DISABLESLEEP="$(pmset -g | awk '/disablesleep/ {print $2; exit}')"
ORIG_DISABLESLEEP="${ORIG_DISABLESLEEP:-0}"

# --- Apply keep-awake ---

# Cache sudo credential (one prompt, 5-min cache).
if ! sudo -n true 2>/dev/null; then
  printf '🔐 Roam needs sudo once to block lid-close sleep.\n'
  if ! sudo -v; then
    printf '\n❌ sudo declined — roam not enabled.\n' >&2
    exit 5
  fi
fi

sudo pmset -a disablesleep 1 >/dev/null 2>&1 || {
  printf '❌ Failed to set pmset disablesleep.\n' >&2
  exit 6
}

# caffeinate with -w $PPID dies automatically when parent Claude Code process exits.
# We set parent PID to Claude's PPID (the shell that spawned Claude) — but more
# reliably, track by our own state file and the watchdog.
nohup caffeinate -dimsu >/dev/null 2>&1 &
CAFFEINATE_PID=$!

# --- Write state ---

YOLO_ENABLED="$(roam_config_read '.yolo_enabled')"
YOLO_ENABLED="${YOLO_ENABLED:-false}"

cat > "$STATE_FILE" <<EOF
{
  "version": 1,
  "active": true,
  "pid": $$,
  "caffeinate_pid": $CAFFEINATE_PID,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "$(roam_platform)",
  "snapshot": {
    "disablesleep": $ORIG_DISABLESLEEP,
    "ssid": $(printf '%s' "${CURRENT_SSID:-}" | jq -R .)
  },
  "config_snapshot": {
    "hotspot_ssid": $(printf '%s' "${HOTSPOT_SSID:-}" | jq -R .),
    "yolo_enabled": $YOLO_ENABLED
  },
  "last_auto_detect_prompt": null
}
EOF

# --- Start watchdog (idempotent) ---

bash "$SELF_DIR/install-watchdog.sh" >/dev/null 2>&1 || true

# --- Output ---

roam_log "roam entered (pid=$$, caffeinate=$CAFFEINATE_PID)"

# SSID match check for user-facing message
SSID_MATCH_MSG=""
if [ -n "$HOTSPOT_SSID" ] && [ "$CURRENT_SSID" != "$HOTSPOT_SSID" ]; then
  SSID_MATCH_MSG="⚠️  You're on \"${CURRENT_SSID:-unknown}\" — not your saved hotspot \"$HOTSPOT_SSID\".
    Open wifi menu → tap \"$HOTSPOT_SSID\" → then close the lid.
"
fi

BAT="$(roam_battery_pct)"
BAT_MSG="${BAT:-?}% on AC"

cat <<EOF

🎒 Roam is on.

  → /remote-control   — control this session from your phone
  → /roam:off          — exit roam, resume normal sleep

  Power: AC only · Sleep blocked · Watchdog running · Battery: $BAT_MSG

${SSID_MATCH_MSG}
EOF
