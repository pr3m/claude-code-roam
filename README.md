# claude-code-roam

**Mobile mode for Claude Code.** Keep your laptop awake while you're on the road, get a push notification when Claude needs you, and optionally run in a constrained "yolo" mode where safe commands auto-approve but prod-capable tools (`aws`, `stripe`, `deploy`, ...) stay gated.

## The problem, in plain English

You're working with Claude Code on a long task. You want to close the lid, throw the laptop in your backpack, and walk out — continuing to chat with Claude from your phone via `/remote-control`. But macOS sleeps the moment the lid closes, killing the session.

This plugin flips exactly the two things you need (and nothing else): blocks lid-close sleep while active, and shows a 🎒 indicator so you always know it's on. When Claude stops for input, your phone gets a notification. When you're back at the desk and typing, roam quietly suggests you turn it off.

> ⚠️ **Read before using**: closing a laptop with lid closed under sustained CPU in a padded backpack can cook your battery and warp the chassis. Roam requires AC power and auto-exits below 10% battery. If you value the machine, keep it cool — lid-open on a stand is safer than lid-closed in a bag.

## What it does

- **Blocks lid-close sleep** (`sudo pmset -a disablesleep 1` + `caffeinate -dimsu`) — reverted on `/roam:off`, or auto-reverted by the watchdog if Claude Code crashes.
- **Status-line indicator** — 🎒 appears in Claude Code's bottom bar when roam is on. Integrates with your existing status line (patch or wrap), or installs a minimal one.
- **Push notification on Stop** — when Claude stops for input during roam and you're not actively typing, macOS sends a notification.
- **Auto-detect local use** — if you're typing on the device directly (lid open, active HID input, not over SSH), roam reminds you it might not be needed. Once per 15 min, non-blocking.
- **Constrained yolo** (optional) — safe commands auto-approve so Claude doesn't stall while you're away. Hard-denies universal security patterns (shell escapes, `eval`, `curl -L`, `rm -rf /`, `git push` to protected branches). You can extend the deny list with your own domain-specific tools via `deniedPatterns` in the config.
- **Battery guard** — auto-exits below 10% (configurable), sends notification.
- **Watchdog LaunchAgent** — polls every 60s, cleans up if Claude Code crashes mid-session.

## What it does *not* do

- **Does not auto-switch Wi-Fi.** Security + Location Services prompt on Sonoma + enterprise VPN breakage + spoofable SSIDs make this a bad idea. Roam only *reminds* you to tap the hotspot in your wifi menu.
- **Does not store your hotspot password.** Only the SSID name, for display + reminders.
- **Does not auto-revert when lid reopens.** False positives (briefly checking something at a traffic light) would nuke your session. Roam shows a soft suggestion instead.
- **Does not support Windows / Linux** in v0.1. Coming in v0.2 — PRs welcome.

## Requirements

- macOS 14 (Sonoma) or newer, Apple Silicon or Intel
- [Node.js](https://nodejs.org) 18+ (bundled with Claude Code on most installs)
- `sudo` access for `pmset` (one-time password prompt per session; can be replaced with TouchID — see below)

## Install

### Via Claude Code plugin marketplace

```
/plugin marketplace add pr3m/claude-code-roam
/plugin install roam@claude-code-roam
/roam:install
```

The third step runs the bundled installer — it integrates with your status line (with approval) and registers the watchdog LaunchAgent. It never modifies `/etc/pam.d/` or touches `sudo` config.

### TouchID for silent `/roam` (optional)

Make `/roam` prompt-free by letting TouchID stand in for sudo. One time, in a regular terminal:

```sh
echo 'auth sufficient pam_tid.so' | sudo tee /etc/pam.d/sudo_local
```

After that, every `/roam` enter/exit is just a fingerprint tap.

## Commands

| Slash command | Natural-language triggers |
|---|---|
| `/roam` | "go mobile", "enter roam", "close the lid" |
| `/roam:off` | "back at desk", "exit roam", "turn it off" |
| `/roam:status` | "is roam on", "roam status" |
| `/roam:config` | "change hotspot", "toggle yolo", "roam settings" |
| `/roam:install` | "set up roam", "install roam" |
| `/roam:uninstall` | "remove roam", "tear it down" |
| `/roam:test` | "test roam", "smoke test" |

## First-run flow

First time you say `/roam`, you get two questions:

```
🎒 First-time roam setup.

You're currently on: "Christjan's iPhone"

  1. Yes, remember this as my roam hotspot
  2. No, let me type a different name
  3. Skip — I'll manage wifi myself

> 1

Enable yolo for future roam sessions? [y/N]: N

Done. Enabling roam now…

🎒 Roam is on.
  → /remote-control   — control this session from your phone
  → /roam:off          — exit roam, resume normal sleep
```

If you're on a non-hotspot network, it asks you to type the SSID name (no password — roam never auto-connects).

Every subsequent `/roam` is one command, zero prompts.

## Config

`$CLAUDE_PLUGIN_DATA/config.json` (or `~/.claude/roam/config.json` fallback):

```json
{
  "hotspot_ssid": "My iPhone",
  "yolo_enabled": false,
  "autoDetectLocalUse": true,
  "autoDetectSnoozeMinutes": 15,
  "batteryThreshold": 10,
  "thermalThreshold": 85,
  "statusLineVerbose": false,
  "deniedPatterns": []
}
```

- **`yolo_enabled`** — if true, safe-binary Bash commands auto-approve during roam. Read the hard-deny list below before enabling.
- **`autoDetectLocalUse`** — suggest `/roam:off` when you're typing on the device directly.
- **`statusLineVerbose`** — adds low-battery warning to the 🎒 indicator.

Edit via `/roam:config` or directly. Kill switch: set `"enabled": false` (not shipped in the default schema; add the field if you want a persistent disable), or just don't run `/roam`.

## Yolo hard-deny list (universal security patterns)

Even with yolo on, these **always** require manual approval. This list is deliberately generic — anything tool-specific (your cloud CLI, database shell, deployment script) belongs in the `deniedPatterns` field of *your* config, not in the plugin.

- Shell interpreters with inline code: `bash -c`, `sh -c`, `zsh -c`, `sudo`, `doas`
- `eval`, `source`, `.` (dot sourcing)
- Pipe into shell: `… | bash`, `… | sh`
- Inline-exec flags: `node -e`, `python -c`, `perl -e`, `ruby -e`, `php -r`, etc.
- Recursive root/home deletion: `rm -rf /`, `rm -rf ~/`
- Redirect-following HTTP: `curl -L`, `wget --location` (bypasses domain allowlists)
- `git push` to `main` / `master` / `production` / `prod` / `release`
- `git push --force`

### Adding your own denies

The config has a `deniedPatterns` array for regex strings you want to always prompt on:

```json
{
  "deniedPatterns": [
    "(^|\\s)aws\\s",
    "(^|\\s)kubectl\\s",
    "(^|\\s)(mongosh|psql|mysql)\\s"
  ]
}
```

Anything matching → prompted, even in yolo.

## Safety rails (cannot be disabled)

- **AC power required** — `/roam` refuses to enter if on battery
- **Battery auto-exit** — watchdog force-exits below the threshold (default 10%)
- **Crash recovery** — LaunchAgent watchdog cleans up stale state if Claude Code dies
- **Hard-deny list** — prod-capable tools always prompt even in yolo

## Architecture

```
claude-code-roam/
├── .claude-plugin/marketplace.json        # marketplace manifest
└── plugins/roam/
    ├── .claude-plugin/plugin.json          # plugin manifest
    ├── hooks/
    │   ├── hooks.json                      # SessionStart + Stop + PreToolUse wiring
    │   ├── session-start.sh                # banner, SSID reminder, auto-detect nudge
    │   ├── notify-stop.sh                  # osascript notification on Claude stop
    │   └── yolo-gate.js                    # constrained yolo PreToolUse hook
    ├── bin/
    │   ├── helpers.sh                      # shared state/platform helpers
    │   ├── roam-enter.sh                   # apply (caffeinate + pmset + watchdog)
    │   ├── roam-exit.sh                    # revert from snapshot
    │   ├── roam-status.sh                  # inspect
    │   ├── roam-indicator.sh               # status-line helper (<1ms)
    │   ├── roam-watchdog.sh                # LaunchAgent's polled body
    │   ├── install-watchdog.sh             # idempotent LaunchAgent setup
    │   └── uninstall-watchdog.sh           # LaunchAgent removal
    └── skills/                             # /roam, /roam:off, /roam:status, /roam:config, /roam:install, /roam:uninstall, /roam:test
```

Every hook / script is a few dozen lines — no build step, no npm deps.

## Contributing

v0.2 Windows + Linux support is the biggest open area. The macOS-specific primitives in `bin/helpers.sh` and `bin/roam-enter.sh` / `bin/roam-exit.sh` are the places to branch. See the design notes in `hooks/yolo-gate.js` for the hard-deny philosophy.

## License

MIT © [Christjan Schumann](https://github.com/pr3m)
