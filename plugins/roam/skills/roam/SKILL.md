---
name: roam
description: Enter roam mode — keep the laptop awake for on-the-go Claude Code work, show a 🎒 indicator, send push notifications when Claude needs attention. Use when the user says "go mobile", "roam", "/roam", "on the road", "close the lid", "mobile mode", or similar.
---

# /roam — Enter Mobile Mode

The plugin ships a single dispatcher at a stable path: `~/.claude/roam/bin/roam-cli`. Every skill uses this entry point — no plugin-root discovery logic in the skill itself. The SessionStart hook refreshes the symlink each session.

## Step 1 — Pre-flight

If `~/.claude/roam/bin/roam-cli` doesn't exist yet, tell the user:

> "The roam plugin hasn't registered itself yet — please restart Claude Code once, then retry `/roam`."

Then stop. (This only happens on the very first install, before any SessionStart has fired.)

## Step 2 — Check config

```sh
~/.claude/roam/bin/roam-cli check-config
```

- Exit `0` → config exists → skip to Step 5.
- Exit `1` → no config → run the first-run wizard (Steps 3–4).

## Step 3 — Hotspot wizard (MUST use `AskUserQuestion`)

### 3a. Detect current network

```sh
~/.claude/roam/bin/roam-cli detect
```

- **Exit `0`** — parse `kind=`, `ssid=`, `gateway=` lines. Recognized phone hotspot detected → go to **3b-A**.
- **Exit `1`** — not on a recognized hotspot. Also capture the current network info for the trust-override branch:
  ```sh
  ~/.claude/roam/bin/roam-cli current-ssid
  ~/.claude/roam/bin/roam-cli current-gateway
  ```
  If SSID is empty → go to **3b-C** (no network). Otherwise → go to **3b-B** (unrecognized network).

### 3b-A. Recognized hotspot

Use `AskUserQuestion`:
- Header: `Hotspot`
- Question: `Detected <kind> hotspot "<ssid>" (gateway <ip>). Save it as your roam hotspot?`
- Options:
  - `Save as roam default` / "Use this hotspot every time you /roam"
  - `Use a different one` / "I'll switch to the hotspot I actually want — detect it" → Step 3b-D (scan)
  - `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

### 3b-B. Unrecognized network (regular Wi-Fi, MiFi, travel router, custom gateway)

Use `AskUserQuestion`:
- Header: `Hotspot`
- Question: `You're on "<CURRENT_SSID>" (gateway <CURRENT_GW>). This doesn't match the usual phone-hotspot ranges — it could be regular Wi-Fi, or a MiFi / travel router / custom setup. Roam needs mobile coverage to be useful. What do you want to do?`
- Options:
  - `Save "<CURRENT_SSID>" anyway — I know it's mobile` / "Trust override — my network is roam-friendly even if detection doesn't recognize it"
  - `Scan for a phone hotspot instead` / "I'll connect to my phone's hotspot now — detect when I do" → Step 3b-D (scan)
  - `Skip` / "Don't track a hotspot — I'll manage Wi-Fi myself"

### 3b-C. No network connected

Use `AskUserQuestion`:
- Header: `Hotspot`
- Question: `You're not connected to any network. Connect to the hotspot you want to use with roam.`
- Options:
  - `Start scanning` / "I'll connect now; detect in the next 2 minutes" → Step 3b-D
  - `Skip` / "Don't track a hotspot for now"

### 3b-D. Scan mode

Tell the user in plain chat:

> 📱 Turn on Personal Hotspot on your phone (or MiFi / travel router) and connect your Mac to it. I'll detect it automatically (up to 2 minutes). Ctrl-C to cancel.

Run:

```sh
~/.claude/roam/bin/roam-cli wait 120 2
```

Exit codes:
- `0` — recognized hotspot detected → parse output, confirm with `AskUserQuestion` same as 3b-A.
- `1` — timeout → `AskUserQuestion`: `Try again` / `Use current network anyway (trust override)` / `Skip`. Trust-override re-reads current SSID via `current-ssid`.
- `130` — cancelled → proceed with `hotspot_ssid: ""`.

## Step 4 — Yolo (MUST use `AskUserQuestion`)

- Header: `Yolo`
- Question: `Enable yolo by default for future roam sessions?`
- Options:
  - `No (recommended)` / "Normal approval prompts while roaming"
  - `Yes` / "Auto-approve safe tools. Shell escapes, eval, curl -L, rm -rf /, git push to protected branches always require confirmation"

Then write the config:

```sh
~/.claude/roam/bin/roam-cli write-config "<chosen-ssid>" <true|false>
```

Pass an empty string for `<chosen-ssid>` if user picked Skip. Pass `true` or `false` (lowercase) for yolo.

Tell the user: "Saved. Next `/roam` is one command."

## Step 5 — Enter roam

```sh
~/.claude/roam/bin/roam-cli enter
```

Show output verbatim. Exit codes:
- `0` → success
- `2` → unsupported platform (macOS-only in v0.1)
- `3` → config missing (shouldn't happen after Step 4; loop back to Step 3)
- `4` → on battery → tell user: "Plug in first, then try again"
- `5` → sudo declined → tell user: "Roam needs one-time sudo to block lid-close sleep. Re-run `/roam` when ready"
- `6` → pmset failed

## Step 6 — Nudge toward remote-control

The enter output already prints "Run /remote-control next". If this is a first-time user, one clarifying sentence: "Remote control gives you a URL you can open on your phone to keep talking to this same session while you're away."

## Do not

- Do not store the hotspot password. Ever. Roam never auto-connects to Wi-Fi.
- Do not call `networksetup -setairportnetwork`. Wi-Fi is manual.
- Do not construct inline shell loops or path-discovery logic in your own commands — always use `~/.claude/roam/bin/roam-cli`. If a subcommand you need isn't there, say so instead of improvising.
