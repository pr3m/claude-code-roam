#!/bin/bash
# uninstall-watchdog.sh — remove the LaunchAgent.

set -u

LABEL="com.pr3m.roam.watchdog"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

[ -f "$PLIST" ] || exit 0

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
