#!/bin/bash
# roam-cli.sh — single entry point for all roam operations.
# Invoked via a symlink at ~/.claude/roam/bin/roam-cli that SessionStart
# refreshes on every Claude session, so skills always have a stable short
# path to call regardless of plugin install location.

set -u
# Resolve $0 through any symlinks (macOS readlink lacks -f, so walk manually).
SELF="$0"
while [ -L "$SELF" ]; do
  LINK="$(readlink "$SELF")"
  case "$LINK" in
    /*) SELF="$LINK" ;;
    *)  SELF="$(dirname "$SELF")/$LINK" ;;
  esac
done
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"

CMD="${1:-help}"
shift || true

case "$CMD" in
  enter)
    exec "$SELF_DIR/roam-enter.sh" "$@"
    ;;
  off|exit)
    exec "$SELF_DIR/roam-exit.sh" "$@"
    ;;
  status)
    exec "$SELF_DIR/roam-status.sh" "$@"
    ;;
  test)
    exec "$SELF_DIR/smoke-test.sh" "$@"
    ;;
  indicator)
    exec "$SELF_DIR/roam-indicator.sh" "$@"
    ;;
  watchdog-install)
    exec "$SELF_DIR/install-watchdog.sh" "$@"
    ;;
  watchdog-uninstall)
    exec "$SELF_DIR/uninstall-watchdog.sh" "$@"
    ;;
  sudoers-install)
    exec "$SELF_DIR/install-sudoers.sh" "$@"
    ;;
  sudoers-uninstall)
    exec "$SELF_DIR/uninstall-sudoers.sh" "$@"
    ;;
  sudoers-status)
    if [ -f /etc/sudoers.d/roam-pmset ]; then
      echo "installed"
      exit 0
    fi
    echo "absent"
    exit 1
    ;;
  statusline-check|statusline-new|statusline-wrap|statusline-unwrap)
    sub="${CMD#statusline-}"
    exec node "$SELF_DIR/statusline.js" "$sub" "$@"
    ;;
  detect)
    # One-shot detection: exit 0 + kind/ssid/gateway if on a known hotspot,
    # exit 1 if not. No polling.
    exec "$SELF_DIR/wait-for-hotspot.sh" 0 1
    ;;
  wait)
    # Poll for a hotspot connection. Args: timeout_s (default 120), poll_s (default 2)
    exec "$SELF_DIR/wait-for-hotspot.sh" "${1:-120}" "${2:-2}"
    ;;
  current-ssid)
    # shellcheck source=./helpers.sh
    . "$SELF_DIR/helpers.sh"
    printf '%s\n' "$(roam_current_ssid)"
    ;;
  current-gateway)
    # shellcheck source=./helpers.sh
    . "$SELF_DIR/helpers.sh"
    printf '%s\n' "$(roam_default_gateway)"
    ;;
  check-config)
    # Exits 0 if config.json exists under the plugin's data dir, 1 otherwise.
    # Outputs the resolved config path on success.
    data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/roam}"
    cfg="$data_dir/config.json"
    if [ -f "$cfg" ]; then
      printf '%s\n' "$cfg"
      exit 0
    fi
    exit 1
    ;;
  write-config)
    # write-config <ssid> <yolo-bool>
    data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/roam}"
    mkdir -p "$data_dir"
    ssid_json="$(printf '%s' "${1:-}" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>process.stdout.write(JSON.stringify(d)))')"
    yolo="${2:-false}"
    [ "$yolo" != "true" ] && [ "$yolo" != "false" ] && yolo=false
    cat > "$data_dir/config.json" <<EOF
{
  "hotspot_ssid": $ssid_json,
  "yolo_enabled": $yolo,
  "honorClaudeAllowList": true,
  "autoDetectLocalUse": true,
  "autoDetectSnoozeMinutes": 15,
  "batteryThreshold": 10,
  "thermalThreshold": 85,
  "statusLineVerbose": false,
  "deniedPatterns": []
}
EOF
    printf '%s\n' "$data_dir/config.json"
    ;;
  help|--help|-h|'')
    cat <<EOF
roam-cli — Claude Code roam plugin

  roam-cli enter                 Enter mobile mode
  roam-cli off                   Exit mobile mode (alias: exit)
  roam-cli status                Show current state and config
  roam-cli detect                Detect current hotspot, one-shot
  roam-cli wait [sec] [poll]     Poll for hotspot connection (default 120s, every 2s)
  roam-cli current-ssid          Print the current Wi-Fi SSID
  roam-cli current-gateway       Print the current default gateway
  roam-cli check-config          Exit 0 if config.json exists, 1 otherwise
  roam-cli write-config <ssid> <yolo>
                                 Create config.json (yolo = true|false)
  roam-cli test                  Run the smoke test
  roam-cli watchdog-install      Register the LaunchAgent watchdog
  roam-cli watchdog-uninstall    Remove the LaunchAgent watchdog
  roam-cli indicator             Status-line helper (prints 🎒 when active)
EOF
    ;;
  *)
    printf 'Unknown roam-cli command: %s\n' "$CMD" >&2
    printf 'Try: roam-cli help\n' >&2
    exit 64
    ;;
esac
