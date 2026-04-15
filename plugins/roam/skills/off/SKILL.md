---
name: roam:off
description: Exit roam — restore sleep settings and stop the keep-awake. Use when the user says "roam off", "/roam:off", "exit roam", "back at desk", "turn off mobile mode", or similar.
---

# /roam:off — Exit Mobile Mode

```sh
~/.claude/roam/bin/roam-cli off
```

Show output verbatim. Exit codes:
- `0` → success (or was already off)
- `2` → unsupported platform
- `5` → sudo declined → tell user: "Roam didn't revert — sudo was declined. State file is preserved; run `/roam:off` again when ready"

## Do not

- Do not touch the config file. `/roam:config` is for that.
- Do not remove the watchdog LaunchAgent here. `/roam:uninstall` handles full cleanup.
