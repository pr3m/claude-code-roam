# claude-code-roam

**Mobile mode for Claude Code.** Keep your laptop awake while you're on the road, get a push notification when Claude needs you, and optionally run in a constrained "yolo" mode where a small set of read-only dev commands auto-approve so your agents don't stall while you're away.

## The problem, in plain English

You're working with Claude Code on a long task. You want to close the lid, throw the laptop in your backpack, and walk out — continuing to chat with Claude from your phone via `/remote-control`. But macOS sleeps the moment the lid closes, killing the session.

This plugin flips exactly the two things you need (and nothing else): blocks lid-close sleep while active, and shows a 🎒 indicator so you always know it's on. When Claude stops for input, your phone gets a notification. When you're back at the desk and typing, roam quietly suggests you turn it off.

> ⚠️ **Read before using**: closing a laptop with lid closed under sustained CPU in a padded backpack heats the battery fast, regardless of power source. The watchdog auto-exits at 10% battery by default (configurable), but you're responsible for the thermals. If you value the machine, keep it cool — lid-open on a stand is safer than lid-closed in a bag. Plug in whenever you can.

## What it does

- **Blocks lid-close sleep** (`sudo pmset -a disablesleep 1` + `caffeinate -dimsu`) — reverted on `/roam:off`, or auto-reverted by the watchdog if Claude Code crashes.
- **Status-line indicator** — 🎒 appears in Claude Code's bottom bar when roam is on. Integrates with your existing status line (patch or wrap), or installs a minimal one.
- **Push notification on Stop** — when Claude stops for input during roam and you're not actively typing, macOS sends a notification.
- **Auto-detect local use** — if you're typing on the device directly (lid open, active HID input, not over SSH), roam reminds you it might not be needed. Once per 15 min, non-blocking.
- **Constrained yolo** (optional) — a small hardcoded set of read-only dev tools auto-approves (git, ls, cat, grep, node/npm build commands, etc.) so Claude doesn't stall on routine work. Anything outside that set still prompts. Universal security patterns (shell escapes, `eval`, `curl -L`, `rm -rf /`, `git push` to protected branches) always prompt regardless. See **How yolo decides** below for the full lists.
- **Battery guard** — auto-exits below 10% (configurable), sends notification.
- **Watchdog LaunchAgent** — polls every 60s, cleans up if Claude Code crashes mid-session.

## First-run experience

On a fresh machine with no prior customisation, first-run on `/roam` shows you:

1. **One permission dialog** — "Add `Bash(~/.claude/roam/bin/roam-cli:*)` to settings?" (recommended: yes). After this, every roam subcommand runs silently for the life of the install.
2. **One sudo password prompt** — for the `pmset` call that blocks lid-close sleep. A one-liner (see TouchID tip below) replaces this with a fingerprint tap on Apple Silicon.

That's it. Subsequent `/roam` invocations: silent (or a TouchID tap, if configured).

If you say *no* to the permission rule, you'll see Claude Code's per-subcommand approval dialog each time — still usable, just noisier.

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

The third step runs the bundled installer — it offers to add a single permission rule (`Bash(~/.claude/roam/bin/roam-cli:*)`) to your Claude Code settings, registers the watchdog LaunchAgent, and integrates with your status line. After approving that one rule, all roam subcommands run silently — no per-subcommand prompts. The only remaining interaction is a one-time `sudo` password (or TouchID tap, see below) when you actually enter roam. It never modifies `/etc/pam.d/` or touches `sudo` config.

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

## How yolo decides

When `yolo_enabled: true` and roam is active, the `PreToolUse` hook inspects every Bash command before Claude runs it and returns one of three decisions:

1. **Hard-deny (always prompts)** — the command matches a universal security pattern. Yolo never silently approves these, regardless of config:

   - Shell interpreters with inline code: `bash -c`, `sh -c`, `zsh -c`, `sudo`, `doas`
   - `eval`, `source`, `.` (dot sourcing)
   - Pipe into shell: `… | bash`, `… | sh`
   - Inline-exec flags: `node -e`, `python -c`, `perl -e`, `ruby -e`, `php -r`
   - Recursive root/home deletion: `rm -rf /`, `rm -rf ~/`
   - Redirect-following HTTP: `curl -L`, `wget --location`
   - `git push` to `main` / `master` / `production` / `prod` / `release`
   - `git push --force`

2. **Auto-approve** — the first invoked binary is in the hardcoded safe set:

   ```
   ls   cat  head tail wc   file stat tree find
   grep egrep fgrep rg  sed  awk  cut  sort uniq tr  tee
   jq   yq
   echo printf true false date pwd  basename dirname
   mkdir touch readlink realpath
   cd   test
   diff patch cmp
   git          (everything except push to protected branches / --force)
   node npm npx pnpm yarn
   make
   ```

   This set is **hardcoded** and deliberately minimal — dev-loop tools that read files, query state, or build code. Adding to it in v0.1 requires forking the plugin; opening it up to user config is a v0.2 consideration because a user-defined safe set is an easy footgun.

3. **Prompt** — anything else. This includes every binary not listed above (cloud CLIs, database shells, deployment tools, your own scripts, etc.). Yolo treats "unknown" the same as "unsafe" — it doesn't pre-approve tools it hasn't vetted. Claude's execution pauses on the normal permission dialog until you respond from your phone or desk.

### Customising denies

Use `deniedPatterns` (regex array in the config) when you want to block something that the safe set *would* approve. For example, auto-approve `git` generally but prompt on `git reset --hard`:

```json
{
  "deniedPatterns": [
    "git\\s+reset\\s+--hard"
  ]
}
```

A `deniedPatterns` match overrides the safe-set auto-approve → prompts normally.

## Safety rails (cannot be disabled)

- **Battery auto-exit** — watchdog force-exits below the threshold (default 10%, configurable 5–30)
- **Battery warning on entry** — if you enter roam on battery power, the banner surfaces the current % and the auto-exit threshold
- **Crash recovery** — LaunchAgent watchdog cleans up stale state if Claude Code dies
- **Universal security hard-deny** — shell escapes, `eval`, `curl -L`, `rm -rf /`, `git push` to protected branches always prompt in yolo

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
