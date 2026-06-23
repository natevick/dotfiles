#!/bin/sh
set -eu

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  echo "==> Installing zinit"
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

TPM="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM" ]; then
  echo "==> Installing tpm (tmux plugin manager)"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"
fi
