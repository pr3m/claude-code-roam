#!/bin/bash
# wait-for-hotspot.sh — poll until the machine is connected to a phone
# hotspot (iOS / Android / Windows Mobile Hotspot), detected via the
# default gateway IP range. Prints structured output for a parent script
# to read; exits 0 on detection, 1 on timeout, 130 on Ctrl-C.
#
# Usage: wait-for-hotspot.sh [timeout_seconds] [poll_interval_seconds]
# Defaults: 120s timeout, 2s poll.
#
# Success output (3 lines to stdout):
#   kind=iphone|android|windows
#   ssid=<current SSID>
#   gateway=<default gateway IP>
#
# Timeout output: "timeout\n" to stdout, exit 1.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

TIMEOUT=${1:-120}
POLL=${2:-2}

# Validate args so we can't get stuck in a broken loop.
case "$TIMEOUT" in *[!0-9]*|'') TIMEOUT=120 ;; esac
case "$POLL"    in *[!0-9]*|'') POLL=2 ;; esac
[ "$POLL" -lt 1 ] && POLL=1

trap 'exit 130' INT TERM

end_epoch=$(( $(date +%s) + TIMEOUT ))

while [ "$(date +%s)" -lt "$end_epoch" ]; do
  kind="$(roam_hotspot_kind)"
  case "$kind" in
    iphone|android|windows)
      printf 'kind=%s\n' "$kind"
      printf 'ssid=%s\n' "$(roam_current_ssid)"
      printf 'gateway=%s\n' "$(roam_default_gateway)"
      exit 0
      ;;
  esac
  sleep "$POLL"
done

printf 'timeout\n'
exit 1
