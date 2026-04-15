#!/bin/bash
# install-sudoers.sh — optional: grant passwordless sudo for the two specific
# pmset commands roam uses to toggle lid-close sleep. Makes the watchdog's
# battery auto-exit fully reliable (no silent failure if sudo cache expired).
#
# One-time sudo password prompt. Installs /etc/sudoers.d/roam-pmset.
# Reversed by /roam:uninstall-sudoers or manually with `sudo rm`.

set -u

FILE=/etc/sudoers.d/roam-pmset
USER_NAME="${SUDO_USER:-$USER}"
[ -z "$USER_NAME" ] && USER_NAME="$(id -un)"

# Validate username — sudoers files are strict about syntax.
case "$USER_NAME" in
  *[!a-zA-Z0-9._-]*|'')
    printf '❌ Refusing to write sudoers for unusual username: %s\n' "$USER_NAME" >&2
    exit 1
    ;;
esac

# Find pmset absolute path (sudoers requires an absolute path to the binary).
PMSET="$(command -v pmset || true)"
if [ -z "$PMSET" ] || [ ! -x "$PMSET" ]; then
  printf '❌ pmset not found in PATH\n' >&2
  exit 1
fi

cat <<EOF

This will grant **passwordless sudo** for exactly two commands, nothing else:

  $PMSET -a disablesleep 0
  $PMSET -a disablesleep 1

Why: roam's watchdog needs to revert your power settings when it auto-exits
at low battery. Without this rule, the revert fails silently if the sudo
credential has expired (which it will after ~5 min of being away).

File that will be written (as root):
  $FILE

One-time sudo prompt follows.

EOF

TMP="$(mktemp -t roam-sudoers.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<EOF
# Installed by claude-code-roam. Grants passwordless pmset lid-sleep toggle
# for a single user. Remove with: sudo rm $FILE
$USER_NAME ALL=(root) NOPASSWD: $PMSET -a disablesleep 0
$USER_NAME ALL=(root) NOPASSWD: $PMSET -a disablesleep 1
EOF

# visudo -c validates the file before we copy it into /etc/sudoers.d.
if ! visudo -c -f "$TMP" >/dev/null 2>&1; then
  printf '❌ visudo rejected the generated rule. Aborting.\n' >&2
  exit 1
fi

sudo install -m 0440 -o root -g wheel "$TMP" "$FILE" || {
  printf '❌ Failed to install sudoers rule. Check sudo access.\n' >&2
  exit 1
}

# Verify installed file is still valid in context.
if ! sudo visudo -c >/dev/null 2>&1; then
  printf '❌ /etc/sudoers validation failed after install. Removing rule.\n' >&2
  sudo rm -f "$FILE"
  exit 1
fi

printf '✅ Sudoers rule installed at %s\n' "$FILE"
printf '   Watchdog can now auto-revert pmset without a password prompt.\n'
printf '   Remove any time with:\n'
printf '     sudo rm %s\n' "$FILE"
