#!/bin/bash
# session-start.sh — SessionStart hook. Emits banner when roam is active,
# plus optional auto-detect nudge when the user appears to be at the desk.
# Also writes a plugin-root sentinel so skills can find our scripts without
# needing $CLAUDE_PLUGIN_ROOT (which is only available in hook commands).

set -u
BIN_DIR="$(cd "$(dirname "$0")/../bin" && pwd)"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../bin/helpers.sh
. "$BIN_DIR/helpers.sh"

# Register stable entry point so skills can invoke `~/.claude/roam/bin/roam-cli`
# regardless of where the plugin is installed. Symlink refreshes every session,
# so a plugin update or path change is picked up automatically.
mkdir -p "$HOME/.claude/roam/bin"
printf '%s\n' "$PLUGIN_ROOT" > "$HOME/.claude/roam/plugin-root"
ln -sfn "$PLUGIN_ROOT/bin/roam-cli.sh" "$HOME/.claude/roam/bin/roam-cli"

# Surface pending-revert breadcrumb from a prior watchdog auto-exit.
PENDING_REVERT="$HOME/.claude/roam/pending-revert"
if [ -f "$PENDING_REVERT" ]; then
  REVERT_INFO="$(cat "$PENDING_REVERT")"
  # Non-fatal: we just want the additionalContext below to pick it up.
  export ROAM_PENDING_REVERT="$REVERT_INFO"
fi

# No roam = silent hook, BUT surface pending-revert notice if any.
if ! roam_active; then
  if [ -n "${ROAM_PENDING_REVERT:-}" ]; then
    MSG="⚠️  Roam auto-exited while you were away (${ROAM_PENDING_REVERT}). Your Mac slept cleanly, but pmset \`disablesleep=1\` may still be set. Run: sudo pmset -a disablesleep 0 to clear it, or just reboot (macOS clears it at boot)."
    node -e '
      const s = process.argv[1] || "";
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: s }
      }));
    ' "$MSG"
    rm -f "$PENDING_REVERT"
  fi
  exit 0
fi

STATE_FILE="$(roam_state_file)"
HOTSPOT_SSID="$(roam_state_read '.config_snapshot.hotspot_ssid')"
CURRENT_SSID="$(roam_current_ssid)"
YOLO_ENABLED="$(roam_state_read '.config_snapshot.yolo_enabled')"

# Build banner
BANNER="🎒 Roam is on."
BANNER+=$'\n\n'
BANNER+="  → /remote-control   — control this session from your phone"
BANNER+=$'\n'
BANNER+="  → /roam:off         — exit roam, resume normal sleep"

if [ "$YOLO_ENABLED" = "true" ]; then
  BANNER+=$'\n\n'
  BANNER+="  ⚡ Yolo on — safe dev commands auto-approve. Universal security patterns always prompt."
fi

# SSID mismatch reminder
if [ -n "$HOTSPOT_SSID" ] && [ -n "$CURRENT_SSID" ] && [ "$HOTSPOT_SSID" != "$CURRENT_SSID" ]; then
  BANNER+=$'\n\n'
  BANNER+="  ⚠️  You're on \"$CURRENT_SSID\" — not your saved hotspot \"$HOTSPOT_SSID\"."
  BANNER+=$'\n'
  BANNER+="    Tap the hotspot in your wifi menu before closing the lid."
fi

# Auto-detect: user appears to be physically at the desk
AUTODETECT="$(roam_config_read '.autoDetectLocalUse')"
if [ "$AUTODETECT" != "false" ] && ! roam_ssh_session; then
  IDLE="$(roam_hid_idle_seconds)"
  if [ "$IDLE" -lt 30 ] && roam_lid_open; then
    # Snooze check
    LAST="$(roam_state_read '.last_auto_detect_prompt')"
    SNOOZE="$(roam_config_read '.autoDetectSnoozeMinutes')"
    SNOOZE="${SNOOZE:-15}"
    NOW=$(date +%s)
    SHOULD_PROMPT=1
    if [ -n "$LAST" ] && [ "$LAST" != "null" ]; then
      LAST_EPOCH=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$LAST" +%s 2>/dev/null || printf 0)
      AGE=$((NOW - LAST_EPOCH))
      if [ "$AGE" -lt "$((SNOOZE * 60))" ]; then
        SHOULD_PROMPT=0
      fi
    fi
    if [ "$SHOULD_PROMPT" = "1" ]; then
      BANNER+=$'\n\n'
      BANNER+="  💡 You seem to be at the desk (lid open, active typing)."
      BANNER+=$'\n'
      BANNER+="    Roam still needed? If not, run /roam:off."
      # Update state with the new prompt timestamp (best-effort via jq).
      if command -v jq >/dev/null 2>&1; then
        TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        tmp=$(mktemp)
        jq --arg ts "$TS" '.last_auto_detect_prompt = $ts' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
      fi
    fi
  fi
fi

# Emit JSON with additionalContext so Claude sees the banner.
node -e '
  const s = process.argv[1] || "";
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: s }
  }));
' "$BANNER"
