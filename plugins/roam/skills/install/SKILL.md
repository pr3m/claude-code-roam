---
name: roam:install
description: Install helper — runs first-time checks, integrates the status-line indicator, and sets up the watchdog LaunchAgent. Use when the user says "install roam", "set up roam", "/roam:install", or after installing the plugin for the first time.
---

# /roam:install — First-Time Helper

Most of what this skill does could happen lazily inside `/roam`, but running it explicitly gives the user a clean setup view.

## Step 1 — Platform check

```sh
uname -s
```

Must be `Darwin` for v0.1. If not, tell the user: "roam v0.1 is macOS-only. Windows/Linux coming in v0.2 — contributions welcome at https://github.com/pr3m/claude-code-roam".

## Step 2 — Verify bundled hook wiring

Confirm `$CLAUDE_PLUGIN_ROOT/plugins/roam/hooks/hooks.json` exists. If so, Claude Code has auto-loaded SessionStart + Stop + PreToolUse hooks — no manual wiring needed. Tell the user: "Hooks are wired automatically by Claude Code when the plugin is enabled."

## Step 3 — Install watchdog LaunchAgent

```sh
PLUGIN_ROOT="$(cat ~/.claude/roam/plugin-root 2>/dev/null)"
"$PLUGIN_ROOT/bin/install-watchdog.sh"
```

Confirm by checking `~/Library/LaunchAgents/com.pr3m.roam.watchdog.plist` was created. Report success.

## Step 4 — Status-line indicator

Read `~/.claude/settings.json`:

- **If no `statusLine` is set**:
  > "I can add a minimal status line showing 🎒 when roam is active. Do it?"
  On yes, use `Edit` to set:
  ```json
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/plugins/cache/claude-code-roam/.../bin/roam-indicator.sh\"",
    "refreshInterval": 30
  }
  ```
  Use `${CLAUDE_PLUGIN_ROOT}` expansion if possible, or detect the actual cached path.

- **If a `statusLine` is already set**, offer three paths:
  1. **Patch** — append roam-indicator output to existing command. Plugin edits the user's script with a backup to `<script>.pre-roam`. **Only do this with explicit approval.**
  2. **Wrap** — plugin writes a new wrapper script at `~/.claude/bin/roam-wrapped-statusline.sh` that calls the user's existing one + appends the indicator. Update `settings.json` to point at the wrapper. Original script untouched.
  3. **Skip** — leave everything as-is, rely on the SessionStart banner.

Ask the user to pick. Default suggestion: **Wrap** (safest).

## Step 5 — TouchID sudo tip (optional, non-destructive)

Check `/etc/pam.d/sudo_local` for `pam_tid.so`:

```sh
grep -l pam_tid /etc/pam.d/sudo_local 2>/dev/null
```

If not found:

> 💡 You can make `/roam` silent (no password prompt) by enabling TouchID for sudo.
> Run this once, in a regular terminal:
>
> ```
> echo 'auth sufficient pam_tid.so' | sudo tee /etc/pam.d/sudo_local
> ```
>
> Plugin won't touch system files — it's your call.

Do not run the command yourself.

## Step 6 — Summary

Report:
- ✅ Platform OK
- ✅ Hooks auto-wired
- ✅ Watchdog installed
- 🎒 Status-line: <your choice>
- 💡 TouchID sudo: <enabled | see tip above>

Final line: "Run `/roam` to enter mobile mode."
