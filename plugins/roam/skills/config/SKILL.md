---
name: roam:config
description: Edit roam config — change the default hotspot SSID, toggle yolo, tune thresholds. Use when the user says "/roam:config", "change hotspot", "toggle roam yolo", "roam settings", or similar.
---

# /roam:config

Edit the roam config file interactively.

## Step 1 — Locate config

Path: `$CLAUDE_PLUGIN_DATA/config.json` (or `~/.claude/roam/config.json` fallback).

If it doesn't exist → tell user to run `/roam` first (which creates it via first-run wizard).

## Step 2 — Read and display current values

Read with jq or direct parse. Show a compact table:

```
Current roam config:

  hotspot_ssid:             "Christjan's iPhone"
  yolo_enabled:             false
  autoDetectLocalUse:       true
  autoDetectSnoozeMinutes:  15
  batteryThreshold:         10
  thermalThreshold:         85
  statusLineVerbose:        false
```

## Step 3 — Ask what to change

Offer the common options via `AskUserQuestion`:

- Change hotspot SSID
- Toggle yolo (safer: if enabling yolo, remind user of the hard-deny list)
- Toggle auto-detect-local-use
- Change battery threshold (5–30, default 10)
- Change snooze minutes (5–60, default 15)
- Toggle statusLineVerbose (adds elapsed time + low-battery warning)

## Step 4 — Apply

Use `Edit` on the config file. Preserve other fields — never overwrite blindly.

## Step 5 — Summary

Tell the user what changed. Note: changes take effect on next `/roam` enter. If roam is currently active, config changes to yolo/thresholds won't apply to the live session — suggest `/roam:off` + `/roam` to pick up the new values.

## Do not

- Do not store the hotspot password.
- Do not add new config keys beyond the ones listed — schema is fixed for v0.1.
