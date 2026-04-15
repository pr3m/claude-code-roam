# claude-code-roam

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue) ![status](https://img.shields.io/badge/status-v0.1%20alpha-orange) ![license](https://img.shields.io/badge/license-MIT-green)

> **macOS only (v0.1).** Windows and Linux support is on the v0.2 roadmap — see [Contributing](#contributing). Installing on other platforms will fail fast with a clear message.

**Mobile mode for Claude Code.** Keep your laptop awake while you're on the road, see at a glance that roam is active in the status bar, get a macOS notification when Claude needs you, and optionally run in a constrained "yolo" mode where safe read-only dev commands auto-approve so your agents don't stall while you're away.

## The problem, in plain English

You're working with Claude Code on a long task. You want to close the lid, put the laptop in your backpack, and walk out — continuing to chat with Claude from your phone via `/remote-control`. But macOS sleeps the moment the lid closes, killing the session.

This plugin flips exactly what you need and nothing else: blocks lid-close sleep while active, shows a `🎒 roam on` indicator in the Claude Code status bar, pushes a macOS notification when Claude stops for input, and auto-reverts cleanly when you exit — or when the watchdog decides your battery is running low.

> ⚠️ **Read before using:** closing a laptop with lid closed under sustained CPU in a padded backpack heats the battery fast regardless of power source. The watchdog auto-exits at 10% battery by default (configurable), but you're responsible for thermals. If you value the machine, keep it cool — lid-open on a stand is safer than lid-closed in a bag. Plug in whenever you can.

## What it does

- **Blocks lid-close sleep** (`sudo pmset -a disablesleep 1` + `caffeinate -dimsu`). Reverted cleanly on `/roam:off`, or force-slept via AppleScript if the watchdog auto-exits at low battery.
- **Status-line indicator** — `🎒 roam on` appears in Claude Code's bottom bar. If you already have a custom status line, roam wraps it (your script stays untouched) — never replaces.
- **Push notification on Stop** — when Claude stops for input during roam and you're not actively typing, macOS sends a notification. Your phone sees it.
- **Auto-detect local use** — if roam is active but you're typing on the device directly (lid open, HID activity, not over SSH), roam softly suggests `/roam:off`. Once per 15 min, non-blocking.
- **Constrained yolo** (optional) — a small hardcoded set of read-only dev tools auto-approves (`git`, `ls`, `cat`, `grep`, `node`/`npm` build commands, …) so Claude doesn't stall on routine work. Anything outside that set still prompts. Universal security patterns (shell escapes, `eval`, `curl -L`, `rm -rf /`, `git push` to protected branches) always prompt regardless. See **[How yolo decides](#how-yolo-decides)** below.
- **Honors your own Claude Code allow rules** — yolo also respects `Bash(...)` patterns already in your `~/.claude/settings.json` allow list, so commands you've previously opted into (e.g. `Bash(npm run test:*)`) don't get re-asked during roam.
- **Battery guard** — watchdog auto-exits below 10% (configurable). Forces sleep via AppleScript so your work is preserved even if the pmset revert needs sudo.
- **Crash recovery** — LaunchAgent watchdog polls every 60s, cleans up stale state if Claude Code crashes mid-session.

## First-run experience

On a fresh machine with no prior customisation, first-run on `/roam` shows you:

1. **One Claude Code permission dialog** — "Add `Bash(~/.claude/roam/bin/roam-cli:*)` to settings?" (recommended: yes). After this, every roam subcommand runs silently for the lifetime of the install.
2. **Two setup questions** via the Claude Code dialog UI:
   - Hotspot: if you're already on a phone hotspot (gateway IP in a known range), one click to save it. If you're on regular Wi-Fi or no network, roam instructs you to connect to your hotspot and auto-detects when you do. A trust-override option lets you save any network as the roam hotspot even if detection doesn't recognise it (MiFi, travel router, custom gateway).
   - Yolo: on / off. Default off.
3. **One sudo password prompt** — native macOS dialog (no terminal) for the `pmset` call that blocks lid-close sleep. [TouchID](#touchid-for-silent-roam-optional) replaces this with a fingerprint tap on Apple Silicon.

Subsequent `/roam`: silent (or a TouchID tap). The first-run wizard is skipped forever unless you delete the config.

If you decline the permission rule in step 1, Claude Code's native per-subcommand approval dialog appears instead for each roam operation — still usable, just noisier.

## What it does *not* do

- **Does not auto-switch Wi-Fi.** Location Services prompts on Sonoma, enterprise VPN breakage, and spoofable SSIDs make this a bad idea. Roam reminds you if the saved hotspot doesn't match; you tap the hotspot in your wifi menu yourself.
- **Does not store your hotspot password.** Only the SSID name, for display and reminders.
- **Does not replace your status line.** Wrap-or-skip, never replace — your existing setup stays intact.
- **Does not auto-revert when the lid reopens.** False positives (glancing at the screen at a red light) would nuke your session. Roam shows a soft suggestion instead, with a snooze.
- **Does not support Windows / Linux** in v0.1. Coming in v0.2 — PRs welcome.

## Requirements

- macOS 14 (Sonoma) or newer, Apple Silicon or Intel
- [Node.js](https://nodejs.org) 18+ (bundled with Claude Code on most installs)
- `sudo` access for `pmset` — roam uses a native macOS password dialog, no terminal required. Three ways to make it silent, in order of recommended simplicity:
  1. **TouchID for sudo** (Apple Silicon) — one-line edit to `/etc/pam.d/sudo_local`. See [TouchID tip](#touchid-for-silent-roam-optional) below.
  2. **Sudoers rule for pmset only** — offered during `/roam:install`. Grants passwordless sudo for *exactly two* commands (`pmset -a disablesleep 0` / `1`). Nothing else.
  3. **Default** — native GUI password dialog every time. Works out of the box.

## Install

### Via Claude Code plugin marketplace

```
/plugin marketplace add pr3m/claude-code-roam
/plugin install roam@claude-code-roam
/roam:install
```

The third step runs the bundled installer — it offers to add the single Claude Code permission rule, registers the watchdog LaunchAgent, offers to wrap your status line with the `🎒 roam on` indicator, and (optionally) installs the passwordless-sudo rule for pmset. It never modifies `/etc/pam.d/` or edits your existing scripts without asking.

### TouchID for silent `/roam` (optional)

Make `/roam` prompt-free on Apple Silicon by letting TouchID stand in for sudo. One-time, in a regular terminal:

```sh
echo 'auth sufficient pam_tid.so' | sudo tee /etc/pam.d/sudo_local
```

After that, every `/roam` enter/exit is just a fingerprint tap.

## Commands

| Slash command | Natural-language triggers | What it does |
|---|---|---|
| `/roam` | "go mobile", "enter roam", "close the lid" | Enter mobile mode. Runs first-run wizard if no config yet. |
| `/roam:off` | "back at desk", "exit roam", "turn it off" | Revert sleep settings, kill caffeinate, clean state. |
| `/roam:status` | "is roam on", "roam status" | Show current state (active/off, battery, SSID match, watchdog). |
| `/roam:config` | "change hotspot", "toggle yolo", "roam settings" | Edit config interactively. |
| `/roam:install` | "set up roam", "install roam" | One-time helper: permission rule, watchdog LaunchAgent, status-line indicator, optional sudoers. |
| `/roam:uninstall` | "remove roam", "tear it down" | Reverse of install. Restores original status line from backup. |
| `/roam:test` | "test roam", "smoke test" | Non-destructive self-test — verifies scripts, platform deps, yolo-gate decisions. |

## Config

Located at `~/.claude/roam/config.json`. Edit via `/roam:config` or directly:

```json
{
  "hotspot_ssid": "My iPhone",
  "yolo_enabled": false,
  "honorClaudeAllowList": true,
  "autoDetectLocalUse": true,
  "autoDetectSnoozeMinutes": 15,
  "batteryThreshold": 10,
  "thermalThreshold": 85,
  "statusLineVerbose": false,
  "statusLineOptOut": false,
  "deniedPatterns": []
}
```

| Field | Purpose |
|---|---|
| `hotspot_ssid` | The Wi-Fi name (not password) roam reminds you to connect to. Empty = no reminder. |
| `yolo_enabled` | Auto-approve safe commands during roam. See [How yolo decides](#how-yolo-decides). |
| `honorClaudeAllowList` | Also auto-approve anything in your `~/.claude/settings.json` `permissions.allow` list during yolo. Default `true`. |
| `autoDetectLocalUse` | When you're typing on the machine while roam is active, softly suggest `/roam:off`. |
| `autoDetectSnoozeMinutes` | Minimum gap between local-use reminders so it doesn't nag. |
| `batteryThreshold` | Watchdog auto-exits at or below this battery percent (5–30, default 10). |
| `thermalThreshold` | Not yet enforced in v0.1 — reserved for v0.2 thermal guard. |
| `statusLineVerbose` | Adds low-battery warning to the `🎒 roam on` indicator when battery ≤ threshold. |
| `statusLineOptOut` | Set to `true` if you declined the status-line indicator; skipped on future offers. |
| `deniedPatterns` | Regex patterns that always prompt during yolo, even if they'd be auto-approved. |

## How yolo decides

When `yolo_enabled: true` and roam is active, roam's `PreToolUse` hook inspects every Bash command and returns one of these decisions:

1. **Hard-deny → prompts normally** (universal security patterns, never bypassable):
   - Shell interpreters with inline code: `bash -c`, `sh -c`, `zsh -c`, `sudo`, `doas`
   - `eval`, `source`, `.` (dot sourcing)
   - Pipe into shell: `… | bash`, `… | sh`
   - Inline-exec flags: `node -e`, `python -c`, `perl -e`, `ruby -e`, `php -r`
   - Recursive root/home deletion: `rm -rf /`, `rm -rf ~/`
   - Redirect-following HTTP: `curl -L`, `wget --location`
   - `git push` to `main` / `master` / `production` / `prod` / `release`
   - `git push --force`

2. **User `deniedPatterns` match → prompts normally.** Regex array in config; overrides any auto-approve below.

3. **Your Claude Code allow list match → auto-approves.** If `honorClaudeAllowList: true` (default), any `Bash(...)` rule already present in `~/.claude/settings.json` or `.claude/settings.json` (project) counts. Covers exact-match, `:*` prefix, and `*` glob forms.

4. **Built-in safe set → auto-approves.** Hardcoded list:

   ```
   ls   cat  head tail wc   file stat tree find
   grep egrep fgrep rg  sed  awk  cut  sort uniq tr  tee
   jq   yq
   echo printf true false date pwd  basename dirname
   mkdir touch readlink realpath
   cd   test
   diff patch cmp
   git                                      (except push to protected branches / --force)
   node npm npx pnpm yarn
   make
   ```

5. **Anything else → prompts normally.** Yolo treats unknown commands as unsafe. The dialog appears in Claude Code's UI and you can respond from your phone via `/remote-control`.

### Customising denies

Use `deniedPatterns` when you want to block something that the safe set or your allow list would otherwise approve. For example, prompt on `git reset --hard` even though `git` is safe-listed:

```json
{
  "deniedPatterns": [
    "git\\s+reset\\s+--hard"
  ]
}
```

## Safety rails (cannot be disabled)

- **Battery auto-exit** — watchdog force-exits below threshold (default 10%). Sends a macOS notification and forces sleep via AppleScript — works regardless of whether `pmset disablesleep` reverted. Work preserved.
- **Battery warning on entry** — if you enter roam on battery power, the banner surfaces current % and auto-exit threshold.
- **Crash recovery** — LaunchAgent watchdog detects stale state (caffeinate process dead) and cleans up on its next 60s tick.
- **Universal security hard-deny** — shell escapes, `eval`, `curl -L`, `rm -rf /`, `git push` to protected branches always prompt in yolo.

### About the battery auto-exit and pmset revert

When the watchdog triggers:

1. Kills `caffeinate` (no sudo needed).
2. Tries `sudo -n pmset -a disablesleep 0` — succeeds if your sudo cache is warm OR you opted into the sudoers rule during `/roam:install`.
3. Sends a macOS notification ("Battery at N% — exiting roam and sleeping your Mac").
4. Invokes AppleScript `tell application "System Events" to sleep` — user-initiated sleep works even when `disablesleep=1` is still set.
5. If the pmset revert in step 2 failed, a breadcrumb file is written. Your next Claude Code session surfaces a banner: "pmset may still be set — run `sudo pmset -a disablesleep 0` or reboot to clear it."

**Recommended**: accept the optional sudoers rule during `/roam:install`. Makes auto-exit 100% reliable. Grants passwordless sudo for *only* two specific pmset commands — nothing else — and is reversible via `/roam:uninstall`.

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
    │   ├── roam-cli.sh                     # single dispatcher — all skill calls go through this
    │   ├── roam-enter.sh                   # apply (caffeinate + pmset + state.json)
    │   ├── roam-exit.sh                    # revert from snapshot
    │   ├── roam-status.sh                  # inspect state
    │   ├── roam-indicator.sh               # status-line helper (<1ms)
    │   ├── roam-watchdog.sh                # LaunchAgent's polled body
    │   ├── install-watchdog.sh             # idempotent LaunchAgent setup
    │   ├── uninstall-watchdog.sh           # LaunchAgent removal
    │   ├── install-sudoers.sh              # optional passwordless sudo for pmset
    │   ├── uninstall-sudoers.sh            # remove the sudoers rule
    │   ├── sudo-askpass.sh                 # GUI password dialog for sudo -A
    │   ├── wait-for-hotspot.sh             # poll until connected to a phone hotspot
    │   ├── statusline.js                   # check/new/wrap/unwrap statusLine
    │   ├── find-plugin-root.sh             # resolve plugin install path
    │   └── smoke-test.sh                   # self-test suite (/roam:test)
    └── skills/                             # /roam, /roam:off, /roam:status, /roam:config, /roam:install, /roam:uninstall, /roam:test
```

Every hook and script is a few dozen lines — no build step, no npm dependencies.

## Contributing

v0.2 open areas:

- **Windows + Linux support.** The macOS-specific primitives are isolated in `bin/helpers.sh`, `bin/roam-enter.sh`, `bin/roam-exit.sh`, `bin/sudo-askpass.sh`, and `bin/install-watchdog.sh`. Branching by `uname -s` is the starting point.
- **Thermal guard.** The `thermalThreshold` config field is reserved but not yet enforced. macOS exposes CPU package temperature via `powermetrics` (requires sudo) — research a non-privileged path.
- **Opening the yolo safe set to user config.** Currently hardcoded on purpose. A user-defined safe set is an easy footgun; needs a careful design with explicit-intent markers.

Bug reports and PRs welcome. Please attach a reproducer — the smoke test at `/roam:test` is a good template.

## License

MIT © [Christjan Schumann](https://github.com/pr3m)
