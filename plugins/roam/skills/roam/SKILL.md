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

### 3a. Detect current network

Run both:

```sh
ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2; exit}'
route -n get default 2>/dev/null | awk '/gateway:/ {print $2; exit}'
```

Classify the gateway:
- `172.20.10.*` → **iPhone hotspot** (roam-friendly ✅)
- `192.168.43.*` → **Android hotspot** (roam-friendly ✅)
- `192.168.137.*` → **Windows Mobile Hotspot** (roam-friendly ✅)
- Anything else → **regular Wi-Fi** (NOT roam-friendly — coverage ends at the door)

### 3b. Ask about hotspot (MUST use `AskUserQuestion`)

Always use the `AskUserQuestion` tool for these interactive prompts — not plain-text chat. Users expect a clickable dialog, not a numbered list they have to type into.

**If gateway indicates a phone/Windows hotspot** — header: "Hotspot", question: `You're on "<SSID>" — this looks like a phone hotspot (gateway <ip>). Save as your roam hotspot?`, options:
- `Yes, remember this` / "Use the current SSID as your phone's hotspot name"
- `Type a different name` / "I'll tell you my actual hotspot SSID"
- `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

**If gateway indicates regular Wi-Fi** — header: "Hotspot", question: `You're on "<SSID>" — gateway <ip> suggests this is regular Wi-Fi, not a phone hotspot. Saving it defeats the purpose of roam (you'll lose signal when you walk away). What do you want to do?`, options:
- `Type phone's hotspot name` / "Recommended — I'll tell you my iPhone/Android hotspot SSID"
- `Save "<current>" anyway` / "I know what I'm doing — save this as the roam hotspot"
- `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

If user picks "type a different name" / "type phone's hotspot name", use `AskUserQuestion` again with `multiSelect: false` and a free-text affordance — or in plain chat, say: "What's your phone's hotspot name? (Settings → Personal Hotspot on iPhone, Hotspot & tethering on Android)". No password — roam never auto-connects.

### 3c. Yolo (MUST use `AskUserQuestion`)

Header: "Yolo", question: `Enable yolo by default for future roam sessions?`, options:
- `No (recommended)` / "Normal approval prompts while roaming"
- `Yes` / "Auto-approve safe tools. Universal security patterns (shell escapes, eval, curl -L, rm -rf /, git push to protected branches) still require confirmation"

Default is `No`. Don't pre-select; let the user choose.

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
