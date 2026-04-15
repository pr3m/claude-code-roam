#!/bin/bash
# helpers.sh — shared utilities for claude-code-roam
# sourced by all bin/ scripts

set -u

# --- Paths ---

roam_data_dir() {
  # Prefer CLAUDE_PLUGIN_DATA, else a stable fallback so watchdog (which has
  # no CLAUDE_PLUGIN_DATA) can find state.
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_DATA"
  else
    printf '%s\n' "$HOME/.claude/roam"
  fi
}

roam_state_file() { printf '%s/state.json\n' "$(roam_data_dir)"; }
roam_config_file() { printf '%s/config.json\n' "$(roam_data_dir)"; }
roam_log_file() { printf '%s/roam.log\n' "$(roam_data_dir)"; }

roam_ensure_dir() {
  mkdir -p "$(roam_data_dir)"
}

# --- Platform detection ---

roam_platform() {
  case "$(uname -s)" in
    Darwin) printf 'darwin\n' ;;
    Linux) printf 'linux\n' ;;
    MINGW*|MSYS*|CYGWIN*) printf 'win32\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

roam_require_macos() {
  if [ "$(roam_platform)" != "darwin" ]; then
    printf '⚠️  roam v0.1 supports macOS only. Windows/Linux coming in v0.2 — PRs welcome.\n' >&2
    return 2
  fi
  return 0
}

# --- Logging ---

roam_log() {
  roam_ensure_dir
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$(roam_log_file)"
}

# --- State read/write (minimal JSON via jq if available, else naive) ---

roam_has_jq() { command -v jq >/dev/null 2>&1; }

roam_state_read() {
  # $1 = jq path like '.active'. Requires jq.
  local path="$1"
  local f
  f="$(roam_state_file)"
  [ -f "$f" ] || { printf ''; return 0; }
  if roam_has_jq; then
    jq -r "$path // empty" "$f" 2>/dev/null
  else
    printf ''
  fi
}

roam_config_read() {
  local path="$1"
  local f
  f="$(roam_config_file)"
  [ -f "$f" ] || { printf ''; return 0; }
  if roam_has_jq; then
    jq -r "$path // empty" "$f" 2>/dev/null
  else
    printf ''
  fi
}

roam_active() {
  local f
  f="$(roam_state_file)"
  [ -f "$f" ] || return 1
  # state file exists — check active flag
  local act
  act="$(roam_state_read '.active')"
  [ "$act" = "true" ]
}

roam_pid_alive() {
  local pid
  pid="$(roam_state_read '.pid')"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

# --- macOS-specific helpers ---

roam_current_ssid() {
  # Sequoia-safe: airport is gone, use ipconfig getsummary.
  ipconfig getsummary en0 2>/dev/null \
    | awk -F ' SSID : ' '/ SSID : / {print $2; exit}'
}

roam_battery_pct() {
  # Returns integer battery % or empty if not on battery/no power info.
  pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 | tr -d '%'
}

roam_on_ac() {
  pmset -g ps 2>/dev/null | head -1 | grep -qi 'AC Power'
}

roam_lid_open() {
  # AppleClamshellState: false = open, true = closed
  local s
  s="$(ioreg -r -k AppleClamshellState 2>/dev/null \
        | awk -F '= ' '/AppleClamshellState/ {gsub(/ /,"",$2); print $2; exit}')"
  # If we can't read it, assume open (safer for false-positive suppression).
  [ "$s" = "No" ] || [ "$s" = "false" ] || [ -z "$s" ]
}

roam_hid_idle_seconds() {
  # HIDIdleTime is in nanoseconds.
  local ns
  ns="$(ioreg -c IOHIDSystem 2>/dev/null \
        | awk '/HIDIdleTime/ {print $NF; exit}')"
  if [ -n "$ns" ]; then
    # integer division
    printf '%s\n' "$((ns / 1000000000))"
  else
    printf '0\n'
  fi
}

roam_ssh_session() {
  # Returns 0 if current process tree looks like an SSH session.
  [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]
}

# --- Hotspot detection ---
#
# We need to tell apart a phone hotspot ("roam-friendly") from a regular Wi-Fi
# network ("you'll lose signal 20 meters from the door"). Gateway IP is the
# most reliable signal — phone hotspots use well-known default ranges.
#
#   iOS Personal Hotspot   → 172.20.10.1/28
#   Android Hotspot        → 192.168.43.1  (default; some OEMs vary)
#   Windows Mobile Hotspot → 192.168.137.1
#
# Returns one of: iphone, android, windows, unknown, none

roam_default_gateway() {
  # Prints the IPv4 default gateway, or empty string.
  route -n get default 2>/dev/null | awk '/gateway:/ {print $2; exit}'
}

roam_hotspot_kind() {
  local gw
  gw="$(roam_default_gateway)"
  case "$gw" in
    172.20.10.*) printf 'iphone' ;;
    192.168.43.*) printf 'android' ;;
    192.168.137.*) printf 'windows' ;;
    '') printf 'none' ;;
    *) printf 'unknown' ;;
  esac
}

roam_on_hotspot() {
  # 0 = on a recognized phone/OS hotspot; 1 = not.
  case "$(roam_hotspot_kind)" in
    iphone|android|windows) return 0 ;;
    *) return 1 ;;
  esac
}
