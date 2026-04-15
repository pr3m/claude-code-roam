#!/bin/bash
# uninstall-sudoers.sh — remove the optional sudoers rule.

set -u

FILE=/etc/sudoers.d/roam-pmset

if [ ! -f "$FILE" ]; then
  printf 'ℹ️  No roam sudoers rule installed — nothing to remove.\n'
  exit 0
fi

printf 'Removing %s (one-time sudo prompt)…\n' "$FILE"
sudo rm -f "$FILE" && printf '✅ Removed.\n'
