#!/bin/bash
# find-plugin-root.sh — skill helper. Prints the roam plugin root path.
# Reads the sentinel written by the SessionStart hook; falls back to a
# sensible search across known install locations.

SENTINEL="$HOME/.claude/roam/plugin-root"

if [ -f "$SENTINEL" ]; then
  root="$(cat "$SENTINEL" 2>/dev/null)"
  if [ -n "$root" ] && [ -x "$root/bin/roam-enter.sh" ]; then
    printf '%s\n' "$root"
    exit 0
  fi
fi

# Fallback: scan common install locations. Ordered by likelihood.
for candidate in \
  "$HOME"/.claude/plugins/cache/claude-code-roam/*/plugins/roam \
  "$HOME"/.claude/plugins/cache/*/plugins/roam \
  "$HOME"/dev/claude-code-roam/plugins/roam ; do
  if [ -x "$candidate/bin/roam-enter.sh" ]; then
    # Update sentinel so subsequent calls are fast.
    mkdir -p "$HOME/.claude/roam"
    printf '%s\n' "$candidate" > "$HOME/.claude/roam/plugin-root"
    printf '%s\n' "$candidate"
    exit 0
  fi
done

printf 'roam plugin not found — restart Claude Code, or reinstall via /plugin install\n' >&2
exit 1
