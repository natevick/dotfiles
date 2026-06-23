#!/bin/sh
# Bootstrap entrypoint: installs chezmoi (if needed) and applies this repo.
# Works for manual setup AND devcontainers/Codespaces (non-interactive).
set -eu

# shellcheck disable=SC1007
REPO_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"

if ! command -v chezmoi >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/chezmoi" ]; then
  echo "==> Installing chezmoi"
  sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi
CHEZMOI="$(command -v chezmoi 2>/dev/null || echo "$HOME/.local/bin/chezmoi")"

# Non-interactive when there is no TTY or we are in a container
EXTRA=""
if [ ! -t 0 ] || [ -f /.dockerenv ] || [ -n "${CODESPACES:-}" ] || [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${DEVCONTAINER:-}" ]; then
  EXTRA="--promptDefaults"
fi

echo "==> Applying dotfiles from $REPO_DIR"
# shellcheck disable=SC2086
"$CHEZMOI" init --apply --source "$REPO_DIR" $EXTRA
