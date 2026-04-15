---
name: roam:status
description: Show roam state and config. Use when the user says "roam status", "is roam on", "/roam:status", "what's roam doing", or similar.
---

# /roam:status

```sh
~/.claude/roam/bin/roam-cli status
```

Show the output verbatim.

## Context-aware hint

After printing status, add a one-line hint:
- "Roam: off" → suggest `/roam`
- "Roam: ON" with dead PID → suggest `/roam:off` to clean up stale state
- SSID doesn't match saved hotspot → "Tap your hotspot in the wifi menu before closing the lid"
- Battery < 20% → "Plug in, or roam will auto-exit at 10%"
