---
name: roam:test
description: Smoke test — verify hooks, scripts, and state logic without actually entering roam. Use when user says "test roam", "smoke test roam", "/roam:test", "is roam working".
---

# /roam:test

Run a non-destructive suite of checks that verifies the plugin's components work end-to-end without modifying power/network state.

## Step 1 — Platform and dependencies

```sh
uname -s                    # expect Darwin
command -v caffeinate && caffeinate --version 2>&1 | head -1 || echo "MISSING"
command -v pmset && echo "pmset: OK" || echo "pmset: MISSING"
command -v networksetup && echo "networksetup: OK" || echo "networksetup: MISSING"
command -v ipconfig && echo "ipconfig: OK" || echo "ipconfig: MISSING"
command -v ioreg && echo "ioreg: OK" || echo "ioreg: MISSING"
command -v node && node --version
command -v osascript && echo "osascript: OK" || echo "osascript: MISSING"
```

All must be present on macOS.

## Step 2 — Plugin file sanity

```sh
test -x "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-enter.sh" && echo "enter: exec"
test -x "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-exit.sh"  && echo "exit: exec"
test -x "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-status.sh" && echo "status: exec"
test -x "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-indicator.sh" && echo "indicator: exec"
test -x "$CLAUDE_PLUGIN_ROOT/plugins/roam/hooks/yolo-gate.js" && echo "yolo-gate: exec"
```

## Step 3 — Helpers smoke test

```sh
bash -c 'source "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/helpers.sh"; echo "platform=$(roam_platform)"; echo "ssid=$(roam_current_ssid)"; echo "bat=$(roam_battery_pct)%"; echo "ac=$(roam_on_ac && echo yes || echo no)"; echo "lid=$(roam_lid_open && echo open || echo closed)"; echo "idle=$(roam_hid_idle_seconds)s"'
```

Validates platform detection, SSID read, battery read, AC detect, lid state, HID idle.

## Step 4 — Indicator output

With roam off (no state file), the indicator must print empty. Simulate active state with a fake state file:

```sh
mkdir -p /tmp/roam-test
cat > /tmp/roam-test/state.json <<'EOF'
{"version":1,"active":true,"pid":1,"caffeinate_pid":1,"started_at":"2026-01-01T00:00:00Z","snapshot":{"disablesleep":0}}
EOF
CLAUDE_PLUGIN_DATA=/tmp/roam-test bash "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-indicator.sh"
echo   # expect: 🎒
rm -rf /tmp/roam-test
```

## Step 5 — Yolo gate cases

Pipe synthetic commands into `yolo-gate.js` with a fake roam-yolo-on state. Verify decisions.

```sh
mkdir -p /tmp/roam-test
cat > /tmp/roam-test/state.json <<'EOF'
{"version":1,"active":true,"pid":1,"config_snapshot":{"hotspot_ssid":"test","yolo_enabled":true}}
EOF

run_gate() {
  echo "$2" | CLAUDE_PLUGIN_DATA=/tmp/roam-test node "$CLAUDE_PLUGIN_ROOT/plugins/roam/hooks/yolo-gate.js" \
    | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{console.log(JSON.parse(d).hookSpecificOutput.permissionDecision)}catch(e){console.log("fallthrough")}})'
  printf '  %s\n' "$1"
}

run_gate "git status       → expect allow"  '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
run_gate "ls | head        → expect allow"  '{"tool_name":"Bash","tool_input":{"command":"ls /tmp | head -5"}}'
run_gate "aws s3 ls        → expect ask"    '{"tool_name":"Bash","tool_input":{"command":"aws s3 ls"}}'
run_gate "wunda-deploy     → expect ask"    '{"tool_name":"Bash","tool_input":{"command":"wunda-deploy prod"}}'
run_gate "stripe invoices  → expect ask"    '{"tool_name":"Bash","tool_input":{"command":"stripe invoices list"}}'
run_gate "mongosh          → expect ask"    '{"tool_name":"Bash","tool_input":{"command":"mongosh \"mongodb+srv://...\""}}'
run_gate "bash -c rm -rf / → expect ask"    '{"tool_name":"Bash","tool_input":{"command":"bash -c \"rm -rf /\""}}'

rm -rf /tmp/roam-test
```

Report pass/fail for each. A mismatch on `allow` cases means safe-list drift; mismatch on `ask` cases means security hole — flag loudly.

## Step 6 — Yolo gate with roam OFF

Verify that with no state file, the gate falls through (no output, exit 0):

```sh
echo '{"tool_name":"Bash","tool_input":{"command":"aws s3 ls"}}' \
  | CLAUDE_PLUGIN_DATA=/tmp/nonexistent-path node "$CLAUDE_PLUGIN_ROOT/plugins/roam/hooks/yolo-gate.js"
echo "exit=$?"
```

Expected: empty output, `exit=0`.

## Step 7 — Summary

Render a table:

```
claude-code-roam self-test

✅ Platform & deps
✅ Plugin files
✅ Helpers (platform/ssid/battery/ac/lid/idle)
✅ Indicator (active state)
✅ Yolo gate — 7/7 cases passed
✅ Fall-through when roam off

All healthy — `/roam` is ready to use.
```

Red ❌ with specific reason on any failure. Do not modify system state during the test.
