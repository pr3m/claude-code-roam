---
name: roam:install
description: One-time helper — installs the watchdog LaunchAgent, integrates the 🎒 status-line indicator, offers the TouchID-sudo tip. Use when the user says "install roam", "set up roam", "/roam:install", or after first `/plugin install`.
---

# /roam:install

Most of what this skill does could happen lazily on first `/roam`, but running it explicitly is cleaner for the user.

## Step 1 — Platform + dispatcher check

If `~/.claude/roam/bin/roam-cli` doesn't exist, the SessionStart hook hasn't fired. Tell user to restart Claude Code once and retry.

## Step 1b — Permission rule (lets roam-cli run silently)

Read `~/.claude/settings.json`. If `permissions.allow` does not already contain `Bash(~/.claude/roam/bin/roam-cli:*)`:

Ask via `AskUserQuestion`:
- Header: `Permissions`
- Question: `Add allow rule for ~/.claude/roam/bin/roam-cli:* to your Claude Code settings? This removes per-subcommand approval prompts for all roam operations.`
- Options: `Yes, add it (recommended)` / `No, skip`

If Yes, use `Edit` to append to `permissions.allow` (merge with existing). Show the diff first. Never touch other fields.

## Step 2 — Install the watchdog

```sh
~/.claude/roam/bin/roam-cli watchdog-install
```

Confirm `~/Library/LaunchAgents/com.pr3m.roam.watchdog.plist` was created.

## Step 3 — Status-line indicator

Read `~/.claude/settings.json`:

- **If no `statusLine` is set**: ask user "Add a 🎒 indicator to the Claude Code bottom bar?" Use `AskUserQuestion`. On yes, use `Edit` tool to set:
  ```json
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/roam/bin/roam-cli\" indicator",
    "refreshInterval": 30
  }
  ```
- **If a `statusLine` is already set**, offer three paths via `AskUserQuestion`:
  1. `Wrap existing` (recommended) — plugin writes `~/.claude/bin/roam-wrapped-statusline.sh` calling both the user's command and `roam-cli indicator`, then points `statusLine.command` at the wrapper. Original script untouched.
  2. `Patch existing` — append `$(~/.claude/roam/bin/roam-cli indicator)` to the user's script (with `.pre-roam` backup).
  3. `Skip` — leave everything as-is, rely on SessionStart banner.

## Step 3b — Offer passwordless pmset (optional, reliable auto-exit)

The watchdog's battery auto-exit reverts `pmset disablesleep` via `sudo`. By default that uses the cached sudo credential, which expires after ~5 minutes — so if you hit 10% battery after being away for hours, the revert silently fails (the Mac still sleeps via AppleScript fallback, but `disablesleep=1` stays set until your next interactive `/roam:off` or a reboot).

Offer via `AskUserQuestion`:
- Header: `Reliability`
- Question: `Install a sudoers rule so the watchdog can revert pmset without a password? Grants passwordless sudo for exactly two commands: pmset -a disablesleep 0 and pmset -a disablesleep 1. Nothing else.`
- Options: `Yes, install (recommended for regular roam use)` / `No, skip`

On Yes, run:
```sh
~/.claude/roam/bin/roam-cli sudoers-install
```

One sudo prompt, writes `/etc/sudoers.d/roam-pmset`. Status check later via `sudoers-status`, reversal via `sudoers-uninstall`.

On No, tell user: "Watchdog still works — it force-sleeps via AppleScript regardless. You just might need to run `sudo pmset -a disablesleep 0` once after an auto-exit, or reboot (which clears it automatically)."

## Step 4 — TouchID sudo tip (optional, never auto-applied)

```sh
grep -l pam_tid /etc/pam.d/sudo_local 2>/dev/null
```

If not found, tell the user:

> 💡 You can make `/roam` silent (no password prompt) by enabling TouchID for sudo. Run this once in a regular terminal:
>
>     echo 'auth sufficient pam_tid.so' | sudo tee /etc/pam.d/sudo_local
>
> Plugin never touches system files — your call.

## Step 5 — Summary

```
✅ roam-cli ready at ~/.claude/roam/bin/roam-cli
✅ Watchdog LaunchAgent registered
🎒 Status line: <wrap | patch | skip>
💡 TouchID sudo: <enabled | see tip above>
```

Final line: "Run `/roam` to enter mobile mode."
