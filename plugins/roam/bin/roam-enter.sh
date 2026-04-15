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

# AC is a recommendation, not a requirement. The watchdog auto-exits at
# the configured battery threshold (default 10%), so running on battery
# is legitimate — e.g. "I was working on battery and decided to take a walk".
# We just surface the current state so the user knows what they're in for.
BATTERY_WARNING=""
if ! roam_on_ac; then
  BAT="$(roam_battery_pct)"
  BAT_THRESH="$(roam_config_read '.batteryThreshold')"
  BAT_THRESH="${BAT_THRESH:-10}"
  BATTERY_WARNING="⚠️  You're on battery (${BAT:-?}%). Roam will auto-exit at ${BAT_THRESH}% to save your work. Plug in whenever you can — sustained CPU with the lid closed heats up fast regardless of power source."
fi

HOTSPOT_SSID="$(roam_config_read '.hotspot_ssid')"
CURRENT_SSID="$(roam_current_ssid)"

# --- Snapshot current state ---

ORIG_DISABLESLEEP="$(pmset -g | awk '/disablesleep/ {print $2; exit}')"
ORIG_DISABLESLEEP="${ORIG_DISABLESLEEP:-0}"

# --- Apply keep-awake ---
#
# sudo strategy (tries cheapest to most interactive, picks the first that works):
#   1. sudo -n  — succeeds if the optional sudoers rule is installed
#                 (/roam:install offers it) or the credential is cached.
#   2. sudo -A  — with SUDO_ASKPASS pointing at sudo-askpass.sh. On Apple
#                 Silicon with pam_tid configured, sudo shows TouchID first;
#                 otherwise (or on fallback) the askpass GUI dialog appears.
#                 No TTY required — works inside Claude Code's Bash tool.
#   3. Fail with code 5 — only if -A is also declined.

if sudo -n pmset -a disablesleep 1 >/dev/null 2>&1; then
  :
else
  export SUDO_ASKPASS="$SELF_DIR/sudo-askpass.sh"
  if ! sudo -A pmset -a disablesleep 1 >/dev/null 2>&1; then
    printf '❌ sudo declined or cancelled — roam not enabled.\n' >&2
    printf '   Tip: accept the one-time sudoers offer during /roam:install\n' >&2
    printf '   to make all future /roam invocations silent.\n' >&2
    exit 5
  fi
fi

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

# --- Ensure watchdog is loaded (install-watchdog.sh is itself idempotent and
#     non-disruptive — it only loads the LaunchAgent if not already running).

# --- Ensure watchdog is running ---
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
if roam_on_ac; then
  BAT_MSG="${BAT:-?}% on AC"
  POWER_LINE="Sleep blocked · Watchdog running · Battery: $BAT_MSG"
else
  BAT_MSG="${BAT:-?}% on battery"
  POWER_LINE="Sleep blocked · Watchdog running · Battery: $BAT_MSG"
fi

cat <<EOF

🎒 Roam is on.

  → /remote-control   — control this session from your phone
  → /roam:off          — exit roam, resume normal sleep

  $POWER_LINE

${BATTERY_WARNING}
${SSID_MATCH_MSG}
EOF
