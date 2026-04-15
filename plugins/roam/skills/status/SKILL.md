---
name: roam:status
description: Show roam state and config. Use when the user says "roam status", "is roam on", "/roam:status", "what's roam doing", or similar.
---

# /roam:status

Print the current roam state + config.

## Step 1

```sh
bash "$CLAUDE_PLUGIN_ROOT/plugins/roam/bin/roam-status.sh"
```

Show the output verbatim.

## Step 2 — Context-aware hint

- If state shows "Roam: off" → suggest `/roam` to enter.
- If "Roam: ON" with dead PID → suggest `/roam:off` to clean up stale state.
- If SSID doesn't match the saved hotspot → remind: "Tap your hotspot in the wifi menu before closing the lid."
- If battery < 20% → remind: "Plug in, or roam will auto-exit at 10%."
