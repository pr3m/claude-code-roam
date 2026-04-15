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

```sh
~/.claude/roam/bin/roam-cli statusline-check
```

- `ours-minimal` → ask user: "Remove the roam-only status line entirely?" On yes, use `Edit` to delete the `statusLine` key from `~/.claude/settings.json`.
- `integrated` (wrapped mode) → `~/.claude/roam/bin/roam-cli statusline-unwrap` restores the user's original `statusLine.command` automatically, reading the embedded original out of the wrapper script, then deletes the wrapper.
- `absent` / `other` → nothing to restore.

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
