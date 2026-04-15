---
name: roam
description: Enter roam mode — keep the laptop awake for on-the-go Claude Code work, show a 🎒 indicator, send push notifications when Claude needs attention. Use when the user says "go mobile", "roam", "/roam", "on the road", "close the lid", "mobile mode", or similar.
---

# /roam — Enter Mobile Mode

Apply roam: block lid-close sleep, start the watchdog, point the user at `/remote-control`. Handles first-run setup inline.

## Step 1 — Find plugin root

Skills cannot rely on `$CLAUDE_PLUGIN_ROOT` (that env var is only set for hook commands). Instead, read the sentinel the SessionStart hook wrote:

```sh
PLUGIN_ROOT="$(~/.claude/plugins/roam-last-resort 2>/dev/null || cat ~/.claude/roam/plugin-root 2>/dev/null)"
```

Simpler and more robust: call the bundled finder (which tries sentinel, then falls back to scanning known install locations):

```sh
PLUGIN_ROOT="$(
  for candidate in \
    "$HOME"/.claude/plugins/cache/claude-code-roam/*/plugins/roam \
    "$HOME"/.claude/plugins/cache/*/plugins/roam \
    "$HOME"/dev/claude-code-roam/plugins/roam ; do
    [ -x "$candidate/bin/roam-enter.sh" ] && { echo "$candidate"; break; }
  done
)"
```

Store the path in a shell variable. If empty → tell user: "Restart Claude Code once so the plugin registers itself, then retry `/roam`."

## Step 2 — Check if config exists

Read the config file at `$HOME/.claude/roam/config.json` (or `$CLAUDE_PLUGIN_DATA/config.json` if set).

- **Exists** → skip to Step 4.
- **Does not exist** → run first-run wizard (Step 3).

## Step 3 — First-run wizard (only if config missing)

**No manual typing of SSIDs.** The plugin detects the hotspot from the network connection. If you're already on a hotspot, it offers to save it. If you're not, it tells you to connect and auto-detects when you do.

### 3a. Detect current network

Run:

```sh
"$PLUGIN_ROOT/bin/wait-for-hotspot.sh" 0 1
```

A `0`-second timeout means "check once and exit". Parse the 3-line output (`kind=`, `ssid=`, `gateway=`). Exit `0` = detected; exit `1` = not on a hotspot right now.

### 3b-A. Already on a phone hotspot — confirm (use `AskUserQuestion`)

Header: `Hotspot`. Question: `Detected <kind> hotspot "<ssid>" (gateway <ip>). Save as your roam hotspot?`. Options:
- `Save as roam default` / "Use this hotspot every time you /roam"
- `Use a different one` / "I'll switch to the hotspot I actually want, then you detect it"
- `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

If user picks **Save** → go to Step 3c.
If user picks **Use a different one** → continue to Step 3b-B (wait loop).
If user picks **Skip** → set `hotspot_ssid: ""` in config and go to Step 3c.

### 3b-B. Not on a hotspot (or want a different one) — scan mode

Tell the user in plain chat:

> 📱 Turn on Personal Hotspot on the phone you want to use with roam, and connect this Mac to it. I'll detect it automatically (waiting up to 2 minutes). Cancel any time with Ctrl-C.

Then run:

```sh
"$PLUGIN_ROOT/bin/wait-for-hotspot.sh" 120 2
```

This polls every 2 seconds for up to 2 minutes. Exit codes:
- `0` — detected → parse output, confirm via `AskUserQuestion` (Header: `Hotspot`, Question: `Detected <kind> hotspot "<ssid>". Save it as your roam hotspot?`, Options: `Save` / `Keep waiting for a different one` (loop back) / `Skip`).
- `1` — timeout → ask (Header: `Hotspot`, Options: `Try again` / `Skip for now`).
- `130` — user cancelled → proceed without a saved hotspot.

### 3c. Yolo (use `AskUserQuestion`)

Header: `Yolo`. Question: `Enable yolo by default for future roam sessions?`. Options:
- `No (recommended)` / "Normal approval prompts while roaming"
- `Yes` / "Auto-approve safe tools. Shell escapes, eval, curl -L, rm -rf /, git push to protected branches always require confirmation"

Default is `No`. Don't pre-select.

### 3d. Write config

Write to `$HOME/.claude/roam/config.json`:

```json
{
  "hotspot_ssid": "<from 3b>",
  "yolo_enabled": <bool from 3c>,
  "autoDetectLocalUse": true,
  "autoDetectSnoozeMinutes": 15,
  "batteryThreshold": 10,
  "thermalThreshold": 85,
  "statusLineVerbose": false,
  "deniedPatterns": []
}
```

`deniedPatterns` is an empty array by default. Users who want to block their own domain-specific tools (database CLIs, cloud CLIs, deployment scripts) can add regex patterns here after install. Leave the comment in the config file pointing at this.

Tell the user: "Saved. Next `/roam` is one command."

## Step 4 — Invoke enter

```sh
"$PLUGIN_ROOT/bin/roam-enter.sh"
```

Show the script's output verbatim.

Exit codes:
- `0` → success
- `2` → unsupported platform (macOS-only in v0.1)
- `3` → needs-setup → loop back to Step 3
- `4` → on battery → tell user: "Plug in first, then try again"
- `5` → sudo declined → tell user: "Roam needs one-time sudo to block lid-close sleep. Re-run `/roam` when ready"
- `6` → pmset failed → suggest manual: `sudo pmset -a disablesleep 1`

## Step 5 — Nudge toward remote-control

The banner from the enter script already says "Run /remote-control next". If the user seems new, one clarifying sentence: "Remote control gives you a URL you can open on your phone to keep chatting with this same session while you're away."

## Do not

- Do not store the hotspot password. Ever. Roam never auto-connects to Wi-Fi.
- Do not call `networksetup -setairportnetwork` — wifi is manual, always.
- Do not edit `~/.claude/settings.json` without explicit user approval.
- Do not run `sudo` yourself via Bash — the enter script handles its own sudo.
