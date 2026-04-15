---
name: roam:config
description: Edit roam config — change the default hotspot, toggle yolo, tune thresholds, add deniedPatterns. Use when user says "/roam:config", "change hotspot", "toggle yolo", "roam settings".
---

# /roam:config

## Step 1 — Locate config

```sh
~/.claude/roam/bin/roam-cli check-config
```

- Exit 0 → prints config path, proceed.
- Exit 1 → "Run `/roam` first — it creates the config via the first-run wizard."

## Step 2 — Read and show current values

Use `Read` on the config file. Display the JSON as a compact table.

## Step 3 — Ask what to change (use `AskUserQuestion`)

Offer common options:
- Change hotspot SSID (suggest: `~/.claude/roam/bin/roam-cli detect` or `... wait 120` to re-detect)
- Toggle `yolo_enabled`
- Toggle `autoDetectLocalUse`
- Change `batteryThreshold` (5–30, default 10)
- Change `autoDetectSnoozeMinutes` (5–60, default 15)
- Toggle `statusLineVerbose`
- Add/remove `deniedPatterns` (regex strings to always prompt on during yolo)

## Step 4 — Apply

Use `Edit` on the config file — preserve other fields, never overwrite blindly.

## Step 5 — Summary

Tell the user what changed. If roam is currently active, note: "Live session keeps its snapshot — `/roam:off` + `/roam` to apply new values."

## Do not

- Do not store the hotspot password.
- Do not introduce new config keys beyond the documented schema.
