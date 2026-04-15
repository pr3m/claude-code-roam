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

A `0`-second timeout means "check once and exit". Parse the 3-line output (`kind=`, `ssid=`, `gateway=`).

Also independently capture the CURRENT SSID (even if not a detected hotspot) — you'll need it for the trust-override branch:

```sh
CURRENT_SSID="$(ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2; exit}')"
CURRENT_GW="$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2; exit}')"
```

### 3b — Branch on detection result

**A) Recognized phone hotspot detected (iOS / Android / Windows gateway)** — use `AskUserQuestion`:

- Header: `Hotspot`
- Question: `Detected <kind> hotspot "<ssid>" (gateway <ip>). Save as your roam hotspot?`
- Options:
  - `Save as roam default` / "Use this hotspot every time you /roam"
  - `Use a different one` / "I'll switch to the hotspot I actually want, then you detect it" → goes to scan mode (3b-C)
  - `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

**B) On a network, but NOT a recognized hotspot (regular Wi-Fi or unknown gateway)** — use `AskUserQuestion` with trust-override:

- Header: `Hotspot`
- Question: `You're on "<CURRENT_SSID>" (gateway <CURRENT_GW>). This doesn't match the usual phone-hotspot gateway ranges — it looks like regular Wi-Fi. Roam needs mobile coverage (phone hotspot / MiFi / travel router) to be useful. What do you want to do?`
- Options:
  - `Save "<CURRENT_SSID>" anyway — I know it's mobile` / "Trust override: this is a MiFi, travel router, or phone hotspot with a non-default gateway"
  - `Scan for a phone hotspot instead` / "I'll connect to my phone's hotspot now — detect when I do" → goes to scan mode (3b-C)
  - `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

The trust-override option saves `CURRENT_SSID` directly. No typing, but still one click to confirm intent.

**C) No network at all** (`kind=none`, no SSID) — use `AskUserQuestion`:

- Header: `Hotspot`
- Question: `You're not connected to any network. Connect to your roam hotspot so I can detect it.`
- Options:
  - `Start scanning` / "Connect to the hotspot in the next 2 minutes; I'll detect automatically" → goes to scan mode (3b-C)
  - `Skip` / "Don't track a hotspot for now"

### 3b-C. Scan mode (wait for user to connect to a hotspot)

Tell the user in plain chat:

> 📱 Turn on Personal Hotspot on the phone (or MiFi / travel router) you want to use with roam, and connect this Mac to it. I'll detect it automatically (waiting up to 2 minutes). Cancel any time with Ctrl-C.

Then run:

```sh
"$PLUGIN_ROOT/bin/wait-for-hotspot.sh" 120 2
```

Exit codes:
- `0` — recognized hotspot detected → parse output, confirm via `AskUserQuestion` (same options as 3b-A).
- `1` — timeout → ask: `Try again` / `Use current network anyway (trust override)` / `Skip`. If user picks trust-override, re-read `CURRENT_SSID` now and save it.
- `130` — user cancelled → proceed without a saved hotspot (`hotspot_ssid: ""`).

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
