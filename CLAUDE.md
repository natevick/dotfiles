# CLAUDE.md

Dotfiles managed with [chezmoi](https://chezmoi.io). Source root is `home/` (via `.chezmoiroot`); repo-root files (`install.sh`, `docs/`, `.github/`) are never applied to the machine.

## Hard rules

- **This repo is public.** No work-specific tooling, hostnames, IPs, or secrets — machine-local/secret shell config goes in `~/.config/zsh/local.zsh` (chezmoi-ignored). See commit fdd04d3 for a past leak cleanup.
- **Always `chezmoi diff` before `chezmoi apply`.** Drift here has been bidirectional; a blind apply can revert live hotfixes that were never back-ported.
- Shell startup budget: `zsh -i -c exit` < 80ms. Nothing new loads synchronously before the prompt without justification.

## Read when relevant

- `docs/chezmoi.md` — editing/apply workflow, file-naming conventions, run-script semantics, templating profiles, and the `modify_settings.json` ownership trap. Read before touching anything under `home/`.
- `docs/shell-performance.md` — the startup budget, how to measure, `_eval_cached`, and sync-vs-turbo loading rules. Read before touching `dot_zshrc.tmpl` or `plugins.zsh`.
- `docs/superpowers/specs/2026-06-22-chezmoi-migration-design.md` — original migration design and rationale.
