---
name: roam
description: Enter roam mode — keep the laptop awake for on-the-go Claude Code work, show a 🎒 indicator, send push notifications when Claude needs attention. Use when the user says "go mobile", "roam", "/roam", "on the road", "close the lid", "mobile mode", or similar.
---

# /roam — Enter Mobile Mode

Apply roam: block lid-close sleep, start the watchdog, point the user at `/remote-control`. Handles first-run setup inline.

## Step 1 — Platform guard

Run `bash $CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-enter.sh --dry-run 2>&1 || true` to confirm macOS. If the script prints `roam v0.1 supports macOS only` → tell the user and stop.

Actually, simpler: the enter script handles platform detection itself. Just call it and react to its exit code.

## Step 2 — Check if config exists

Read `$CLAUDE_PLUGIN_DATA/config.json` (or `~/.claude/roam/config.json` fallback).

- **Exists** → skip to Step 4.
- **Does not exist** → run first-run wizard (Step 3).

## Step 3 — First-run wizard (only if config missing)

Keep it minimal. Two questions max.

### 3a. Hotspot SSID

Detect the current Wi-Fi SSID by running:

```sh
ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2; exit}'
```

Use `AskUserQuestion` or a plain-text prompt:

- **If a hotspot-looking SSID is detected** (contains "iPhone", "hotspot", "phone", or the user's name — use judgement):
  > You're currently on **"<detected>"**. Save this as your roam hotspot?
  > - Yes, remember this
  > - No, let me type a different name
  > - Skip — I'll manage wifi myself
- **Otherwise**:
  > What's your phone's hotspot name (SSID)?
  > (iPhone: Settings → Personal Hotspot → name shown at the top.)

Store the answer. If user chose "skip", save empty string (plugin will never remind).

### 3b. Yolo default

> Enable yolo for future roam sessions? Safe tools auto-approve. Prod tools (aws/stripe/deploy/mongosh) always require confirmation, even in yolo. [y/N]

Default **N** on ambiguous answer.

### 3c. Write config

Create `$CLAUDE_PLUGIN_DATA/config.json` (or `~/.claude/roam/config.json`):

```json
{
  "hotspot_ssid": "<from 3a>",
  "yolo_enabled": <true|false>,
  "autoDetectLocalUse": true,
  "autoDetectSnoozeMinutes": 15,
  "batteryThreshold": 10,
  "thermalThreshold": 85,
  "statusLineVerbose": false
}
```

Tell the user: "Saved. Next time you run `/roam`, it's one command."

## Step 4 — Invoke enter

Run:

```sh
bash "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-enter.sh"
```

Show the script's output verbatim (the banner it produces is the user-facing summary).

Handle exit codes:
- `0` → success.
- `2` → unsupported platform.
- `3` → needs-setup → loop back to Step 3 (config is missing or corrupt).
- `4` → on battery → tell the user: "Plug in first, then try again."
- `5` → sudo declined → tell the user: "Roam needs one-time sudo to block lid-close sleep. Re-run `/roam` when ready."
- `6` → pmset failed → suggest running manually: `sudo pmset -a disablesleep 1`.

## Step 5 — Nudge toward remote-control

After the enter script succeeds, the banner already says "Run /remote-control next". Don't repeat it — the banner is visible. If the user seems new to the plugin, add one clarifying sentence: "Remote control gives you a URL you can open on your phone to keep chatting with this same session while you're away."

## Step 6 — Status line integration (first run only)

If the user has a custom `statusLine` in `~/.claude/settings.json` (read it and check), do NOT modify it. Print a one-liner:

> 💡 Tip: add a 🎒 to your Claude Code bottom bar when roam is on. Your current status line is `<path>`. Want me to show you the exact command to paste into it, or wrap it automatically? (won't touch your file without asking)

If there's no existing `statusLine`, offer to set a minimal one that just shows the indicator. Ask before editing `settings.json`.

Skip the offer if `$CLAUDE_PLUGIN_DATA/.status-line-offered` exists (mark it after first mention so we don't nag).

## Do not

- Do not store the hotspot password. Ever. Roam never auto-connects to Wi-Fi.
- Do not call `networksetup -setairportnetwork` — wifi is manual, always.
- Do not edit `~/.claude/settings.json` without explicit user approval (Step 6).
- Do not run `sudo` yourself via Bash — the enter script handles its own sudo.
