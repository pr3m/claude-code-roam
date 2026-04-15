#!/bin/bash
# install-watchdog.sh — register (or refresh) the LaunchAgent that polls
# roam-watchdog.sh every 60s. Idempotent: safe to call on every /roam enter.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

[ "$(roam_platform)" = "darwin" ] || exit 0

LABEL="com.pr3m.roam.watchdog"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
WATCHDOG_ABS="$SELF_DIR/roam-watchdog.sh"

mkdir -p "$(dirname "$PLIST")"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${WATCHDOG_ABS}</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>StandardOutPath</key>
  <string>$(roam_data_dir)/watchdog.out</string>
  <key>StandardErrorPath</key>
  <string>$(roam_data_dir)/watchdog.err</string>
</dict>
</plist>
EOF

# Load only if not already loaded. Avoids the common case where /roam enter
# reloads the watchdog, which would fire an immediate poll (via the scheduler's
# initial tick) and race with state.json being written moments earlier.
if ! launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LABEL"; then
  launchctl load "$PLIST" 2>/dev/null || true
fi
