---
name: roam:uninstall
description: Clean removal of roam artifacts — watchdog, status-line edits, state, config. Use when user says "uninstall roam", "remove roam", "/roam:uninstall", or before running `/plugin uninstall`.
---

# /roam:uninstall

Reverse what `/roam:install` + `/roam` left behind. Confirms at each step.

## Step 1 — Ensure roam is off

Read plugin root: `PLUGIN_ROOT="$(cat ~/.claude/roam/plugin-root 2>/dev/null)"`. If roam is currently active (`"$PLUGIN_ROOT/bin/roam-status.sh"` shows "ON"), invoke `/roam:off` first.

## Step 2 — Remove the watchdog

```sh
"$PLUGIN_ROOT/bin/uninstall-watchdog.sh"
```

## Step 3 — Restore status line

Check `~/.claude/settings.json` `statusLine`:

- If it points at `roam-indicator.sh` (plugin-installed minimal one) → ask user: "Remove the status line entirely, or leave an empty custom spot?" Apply their choice.
- If it points at a **wrapper** script created by `/roam:install` (wrap option) → restore the user's original `statusLine` command (we know it from the wrapper's contents). Delete the wrapper.
- If the user's original script was **patched** (patch option) → restore from `.pre-roam` backup. Delete the backup.

Show a diff before applying any edit. Get approval per change.

## Step 4 — Offer to delete config/state

Ask: "Delete config and state files? (You can keep them if you plan to reinstall.)"

Candidates:
- `$CLAUDE_PLUGIN_DATA/config.json` (or `~/.claude/roam/config.json`)
- `$CLAUDE_PLUGIN_DATA/state.json`
- `~/.claude/roam/roam.log`

## Step 5 — Do NOT

- Do not run `/plugin uninstall` yourself — that's Claude Code's operation, user initiates.
- Do not touch `/etc/pam.d/sudo_local` (TouchID sudo rule) — user opted into it, user removes it.
- Do not revert `pmset disablesleep` unless roam was active — we don't know what the user's real preference is outside of roam.

## Step 6 — Summary

Confirm:
- ✅ Watchdog removed
- ✅ Status line restored
- ✅ Config + state deleted (or kept per your choice)

Tell user: "Run `/plugin uninstall roam` to remove the plugin itself, or reinstall anytime via `/plugin install`."
