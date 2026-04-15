---
name: roam:test
description: Smoke test — verify hooks, scripts, and state logic without actually entering roam. Use when user says "test roam", "smoke test roam", "/roam:test", "is roam working".
---

# /roam:test

Run the non-destructive self-test bundled with the plugin. It verifies platform, dependencies, file permissions, helpers, indicator, yolo gate cases, and fall-through behavior — without touching power or network state.

## Step 1 — Find plugin root

```sh
PLUGIN_ROOT="$(cat ~/.claude/roam/plugin-root 2>/dev/null)"
[ -n "$PLUGIN_ROOT" ] && [ -x "$PLUGIN_ROOT/bin/smoke-test.sh" ] || {
  echo "Plugin path not registered. Restart Claude Code once."
  exit 1
}
```

## Step 2 — Run

```sh
"$PLUGIN_ROOT/bin/smoke-test.sh"
```

## Step 3 — Report

Show the output verbatim. If all checks pass, the script exits 0 and prints "✅ All checks passed". If any fail, exits 1 and shows which.

## On failure

- **Missing CLI tool** (`caffeinate`, `pmset`, `ipconfig`, etc.) → only happens on non-macOS or broken macOS; suggest reinstalling Xcode Command Line Tools
- **Script not executable** → re-run `/plugin install roam@claude-code-roam` to reset permissions
- **Yolo case mismatch** → file an issue on the repo with the failing case so we can harden the pattern
