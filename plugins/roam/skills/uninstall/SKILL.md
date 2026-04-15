---
name: roam:uninstall
description: Clean removal of roam artifacts — watchdog, status-line edits, state, config. Use when user says "uninstall roam", "remove roam", "/roam:uninstall", or before running `/plugin uninstall`.
---

# /roam:uninstall

## Step 1 — Ensure roam is off

```sh
~/.claude/roam/bin/roam-cli status
```

If active → invoke `/roam:off` first.

## Step 2 — Remove the watchdog

```sh
~/.claude/roam/bin/roam-cli watchdog-uninstall
```

## Step 2b — Offer to remove the sudoers rule (if installed)

```sh
~/.claude/roam/bin/roam-cli sudoers-status
```

If exit 0 (installed), ask the user: "Remove the pmset passwordless sudo rule?" On yes:

```sh
~/.claude/roam/bin/roam-cli sudoers-uninstall
```

## Step 3 — Restore status line

Check `~/.claude/settings.json` `statusLine`:
- Points at `roam-cli indicator` (plugin-installed minimal one) → ask: remove entirely or leave empty custom slot? Apply choice.
- Points at a `roam-wrapped-statusline.sh` (wrap option) → restore the user's original `statusLine.command` from the wrapper's contents, delete the wrapper.
- User's script was patched (patch option) → restore from `.pre-roam` backup, delete the backup.

Show diff before each edit. Get approval per change.

## Step 4 — Offer to delete config / state / symlinks

Via `AskUserQuestion`: "Delete config and state? (Keep if reinstalling.)" Candidates:
- `~/.claude/roam/config.json` (or `$CLAUDE_PLUGIN_DATA/config.json`)
- `~/.claude/roam/state.json`
- `~/.claude/roam/plugin-root`
- `~/.claude/roam/bin/roam-cli` (symlink)
- `~/.claude/roam/roam.log`

## Do not

- Do not run `/plugin uninstall` yourself — user initiates.
- Do not touch `/etc/pam.d/sudo_local`.
- Do not revert `pmset disablesleep` unless roam was active.

## Step 5 — Summary

```
✅ Watchdog removed
✅ Status line restored
✅ Plugin artifacts deleted (or kept per choice)
```

"Run `/plugin uninstall roam` to remove the plugin itself."
