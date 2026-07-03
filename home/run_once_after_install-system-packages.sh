#!/bin/sh
# tmux + vim are base packages (git editor is vim; tmux.conf is managed here).
# No reliable prebuilt binaries across OSes, so they come from the native
# package manager — same tier as zsh/git/mise. Never fails the apply: if no
# package manager or no sudo, it prints what to install and moves on.
set -eu

PKGS=""
command -v tmux >/dev/null 2>&1 || PKGS="tmux"
command -v vim >/dev/null 2>&1 || PKGS="$PKGS vim"
[ -z "$PKGS" ] && exit 0

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo -n"

# shellcheck disable=SC2086 # PKGS is intentionally word-split
if command -v brew >/dev/null 2>&1; then
  echo "==> Installing via brew:$PKGS"
  brew install $PKGS || echo "==> brew failed; install manually:$PKGS" >&2
elif command -v apt-get >/dev/null 2>&1; then
  echo "==> Installing via apt-get:$PKGS"
  { $SUDO apt-get update -qq && $SUDO apt-get install -y $PKGS; } \
    || echo "==> apt-get failed (no sudo?); install manually:$PKGS" >&2
elif command -v dnf >/dev/null 2>&1; then
  echo "==> Installing via dnf:$PKGS"
  $SUDO dnf install -y $PKGS || echo "==> dnf failed; install manually:$PKGS" >&2
elif command -v apk >/dev/null 2>&1; then
  echo "==> Installing via apk:$PKGS"
  $SUDO apk add $PKGS || echo "==> apk failed; install manually:$PKGS" >&2
else
  echo "==> No known package manager; install manually:$PKGS" >&2
fi
exit 0
