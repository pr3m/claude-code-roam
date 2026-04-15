---
name: roam:off
description: Exit roam — restore sleep settings and stop the keep-awake. Use when the user says "roam off", "/roam:off", "exit roam", "back at desk", "turn off mobile mode", or similar.
---

# /roam:off — Exit Mobile Mode

Revert to normal sleep behavior and clean up state.

## Step 1 — Find plugin root

```sh
PLUGIN_ROOT="$(cat ~/.claude/roam/plugin-root 2>/dev/null)"
[ -n "$PLUGIN_ROOT" ] && [ -x "$PLUGIN_ROOT/bin/roam-exit.sh" ] || {
  echo "Plugin path not registered. Restart Claude Code once."
  exit 1
}
```

## Step 2 — Invoke exit

```sh
"$PLUGIN_ROOT/bin/roam-exit.sh"
```

Show the output verbatim.

## Step 2 — Handle exit codes

- `0` → cleanly reverted (or was already off — both are success).
- `2` → unsupported platform.
- `5` → sudo declined → tell the user: "Roam didn't revert — sudo was declined. State file is preserved; run `/roam:off` again when ready."

## Do not

- Do not touch the config file (`/roam:config` is for that).
- Do not remove the LaunchAgent watchdog on plain exit — it's harmless when idle and will auto-handle crash recovery. Only `/roam:uninstall` removes it.
