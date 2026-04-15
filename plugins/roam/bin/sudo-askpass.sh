#!/bin/bash
# sudo-askpass.sh — GUI password prompt for `sudo -A`. macOS only.
#
# When Claude Code invokes a Bash command, the resulting shell has no
# controlling TTY, so sudo cannot read a password interactively. Setting
# SUDO_ASKPASS to this script (and calling `sudo -A`) routes the prompt
# to a native macOS dialog via osascript. The user types the password
# into a normal GUI dialog — no terminal, no context switch away from
# Claude Code.
#
# On machines with TouchID sudo configured (pam_tid in /etc/pam.d/sudo_local),
# sudo tries TouchID first and only falls back to this dialog if declined.
#
# The prompt passed by sudo ($1, $SUDO_ASKPASS_PROMPT) is ignored — we
# always show a consistent, branded message so users recognise the source.

set -u

# Bail fast if not on macOS — no osascript available.
case "$(uname -s)" in
  Darwin) ;;
  *) exit 1 ;;
esac

# `with hidden answer` = password-field rendering. `with icon caution` = yellow
# shield so it reads as a permission prompt, not an info box.
osascript <<'APPLESCRIPT' 2>/dev/null
try
    set theResult to display dialog "Roam needs your password to toggle lid-close sleep settings." ¬
        default answer "" ¬
        with hidden answer ¬
        with title "🎒 Roam" ¬
        with icon caution ¬
        buttons {"Cancel", "OK"} ¬
        default button "OK" ¬
        cancel button "Cancel"
    return text returned of theResult
on error
    -- User clicked Cancel or dismissed the dialog.
    return ""
end try
APPLESCRIPT
