---
name: roam:yolo
description: Toggle yolo mode on the current active roam session (safe dev commands auto-approve so Claude doesn't stall while you're away). Use when user says "/roam:yolo", "enable yolo", "turn on yolo", "disable yolo", "yolo mode", "yolo this session", or similar.
---

# /roam:yolo — Toggle Yolo for This Session

Lets the user flip yolo on or off on an already-active roam session, without touching their saved config default.

## Step 1 — Check that roam is active

```sh
~/.claude/roam/bin/roam-cli yolo-status
```

Output:
- `on` (exit 0) — roam active, yolo on
- `off` (exit 0) — roam active, yolo off
- `inactive` (exit 1) — roam not running

If `inactive` → tell user: "Roam is off. Run `/roam` to enter first, then `/roam:yolo` to toggle. You can also toggle yolo via `/roam:config` even when roam is off — that changes the default for future sessions."

## Step 2 — Ask what to do (use `AskUserQuestion`)

Branch on current state.

**If current is `off`** — offer to enable:
- Header: `Yolo`
- Question: `Yolo is OFF. Enable it for this session? Safe dev commands (git, ls, cat, grep, npm …) auto-approve. Universal security patterns (eval, sudo, curl -L, rm -rf /, git push to protected branches) still require approval.`
- Options:
  - `Turn yolo on for this session` / "Affects only the current roam — config default unchanged"
  - `Keep it off` / "Normal approval prompts for all commands while roaming"

**If current is `on`** — offer to disable:
- Header: `Yolo`
- Question: `Yolo is ON. Turn it off for this session?`
- Options:
  - `Turn yolo off` / "Resume normal approval prompts for the rest of this roam"
  - `Keep it on` / "No change"

## Step 3 — Apply

If the user chose to change state:

```sh
~/.claude/roam/bin/roam-cli set-yolo true     # (or false)
```

Show the output verbatim. Confirm the new state. If the user wants their default changed too (not just this session), tell them: "To make this the permanent default, also run `/roam:config`."

## Step 4 — Don't

- Do not update `config.json` from this skill — `/roam:yolo` is session-scoped by design.
- Do not call `/roam:off` + `/roam` to apply — unnecessary churn; the PreToolUse hook re-reads state on every command.
- Do not store or reference vendor-specific tools in the question text. Yolo's behaviour is described by the universal pattern list, not by specific cloud CLIs or database shells.
