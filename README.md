# dotfiles

Managed with [chezmoi](https://chezmoi.io). Source lives under `home/`.

## New machine

```sh
sh -c "$(curl -fsSL https://get.chezmoi.io)" -- init --apply natevick
```

## Devcontainer / Codespaces

Point your dotfiles setting at `github.com/natevick/dotfiles`; it runs
`install.sh`, which bootstraps non-interactively.

## Day-to-day

- `chezmoi edit ~/.zshrc` — edit a managed file
- `chezmoi apply` — apply changes
- `chezmoi cd` — drop into the source repo

Per-machine/secret junk goes in `~/.config/zsh/local.zsh` (git-ignored, sourced last).
