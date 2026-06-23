# Dotfiles → chezmoi migration design

Date: 2026-06-22
Status: Approved (design)

## Problem

The dotfiles repo is dated and diverged across machines:

- **macOS** (current): thoughtbot `rcm` (`rcup`) + oh-my-zsh + `robbyrussell` theme. Multi-OS
  handled by hand-rolled `apt`/`apk`/`yum` bash in `system_install.sh`. `rcm` is effectively
  unmaintained; no templating (whole-file swaps only).
- **Linux** (`<linux-host>`, Ubuntu): already hand-migrated to **zinit + starship**, but not in
  any repo and **not tuned** — interactive `zsh` startup measured at **~760ms** (consistent across
  5 runs).

Two divergent setups, no shared source of truth, slow shell boot.

## Goals

1. **One chezmoi repo** that drives macOS and Linux identically.
2. **Blazing-fast shell boot** — target **< 80ms** for `zsh -i -c exit` (from 760ms).
3. **Off oh-my-zsh** — standardize on the already-chosen **zinit + starship** stack, tuned.
4. **Modern CLI toolset**, installed uniformly across OSes.
5. **Profiles**: per-OS differences auto-detected; identity + headless mode prompted once.
6. **Works inside any devcontainer** — non-interactive bootstrap, minimal/fast toolset, usable as
   a VS Code / Codespaces `dotfiles.repository`.

## Non-goals / dropped

- `i3/`, `Xresources`, `xprofile` — dead (Linux box is GNOME, not i3).
- `host-docker/`, `docker/` (the old rcm Docker tag/host dirs) — replaced by a first-class
  **container profile** (see Profiles).
- `system_install.sh` / `user_install.sh` apt/apk/yum bootstrap — replaced by chezmoi `run_`
  scripts + mise. (`install.sh` is **rewritten**, not dropped — it becomes the chezmoi/devcontainer
  bootstrap entrypoint.)
- 1Password secret templating via chezmoi — out of scope for v1 (future).

## Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Manager | **chezmoi** | First-class multi-OS templating + profiles, single binary, one-line bootstrap. |
| Shell framework | **zinit** (keep) | Already the chosen direction on Linux; turbo mode is the speed lever. |
| Prompt | **starship** (keep) | Cross-OS single binary, already configured on Linux. |
| Toolset install | **mise** for the CLI set | Already used on both boxes; identical binary names/versions everywhere; avoids Ubuntu's `batcat`/`fdfind` renaming and brew-on-Linux weight. Native pkg mgr only bootstraps `zsh`/`git`/`mise`. |
| Profiles | OS + container auto-detect, one init prompt | OS handles ~90%; container is auto-detected (non-interactive); a single prompt covers identity + headless. No heavyweight machine-class system. |
| Repo shape | dotfile source under `home/` + `.chezmoiroot` | Keeps repo-meta (`install.sh`, `docs/`, `LICENSE`, `.github/`) out of the target set cleanly instead of ignoring each. |

## Architecture

### The speed fix (core)

Sync work is minimized; everything non-essential loads **after** the prompt paints.

```zsh
# mise must be on PATH before tools/completions resolve (the one unavoidable sync cost, ~15ms)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# zinit bootstrap
source "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git/zinit.zsh"

# starship loads SYNC so the prompt is instant (~10ms)
command -v starship &>/dev/null && eval "$(starship init zsh)"

# everything else turbo-loads ~1ms AFTER the prompt appears
zinit wait lucid for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf \
    zsh-users/zsh-completions
zinit wait lucid for OMZP::git OMZP::docker OMZP::docker-compose OMZP::kubectl

# fzf + zoxide
command -v fzf    &>/dev/null && source <(fzf --zsh)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
```

Three changes vs. the current Linux config:
1. **starship sync, plugins async** (`zinit wait lucid`) — current config eager-loads everything.
2. **`compinit -C`** via `atinit` — uses the cached dump instead of re-scanning every boot
   (the dominant cost today).
3. **mise stays sync** — small and required; the only thing before the prompt.

Expected: ~35ms sync → prompt paints → remainder streams in behind it. Target < 80ms.

### Modern CLI toolset (via mise)

| Tool | Replaces | Wiring |
|------|----------|--------|
| fzf | — | Ctrl-R history + completion; `fd` as default source, `bat` as preview |
| eza | `ls` | `ls`/`ll`/`la`/`lt` (tree) aliases, with native fallback if absent |
| bat | `cat` | kept as `bat` (paging off); `cat` stays native |
| fd | `find` | also fzf's `FZF_DEFAULT_COMMAND` |
| ripgrep | `grep` | used directly as `rg` |
| zoxide | `cd` | `z` smart-jump; `cd` preserved |
| starship | prompt | already present |

Aliases use `command -v` guards so a machine missing a tool degrades to the native command.

### Repo layout

The dotfile source lives under `home/`; `.chezmoiroot` points chezmoi there. Repo-meta
(`install.sh`, `docs/`, `LICENSE`, `.github/`) sits outside the source and is never a target.

```
.chezmoiroot                          # contains: home
install.sh                            # bootstrap entrypoint (install chezmoi + init --apply); devcontainer-compatible
docs/ LICENSE .github/                # repo-meta, not applied
home/                                 # <-- chezmoi source root
  .chezmoi.toml.tmpl                  #   init prompts + container/OS auto-detection (see Profiles)
  .chezmoiignore                      #   per-OS + per-profile drops (e.g. GUI configs when headless)
  dot_zshrc.tmpl                      #   tuned shell, OS-templated
  dot_gitconfig.tmpl                  #   identity from init prompt; gh helper via `gh` on PATH (no abs path)
  dot_gitignore_global
  dot_tmux.conf                       #   ported as-is (prefix C-a, vi mode, h/j/k/l, tpm plugins)
  dot_config/
    starship.toml
    mise/config.toml.tmpl             #   CLI toolset + language runtimes; gated by OS + container
    zsh/
      aliases.zsh                     #   modern-tool aliases with native fallbacks
      functions/                      #   autoloaded functions (ported)
      plugins.zsh                     #   zinit turbo plugin list (sourced by zshrc)
  run_once_before_install-mise.sh.tmpl     #   install mise if missing (curl https://mise.run)
  run_once_after_install-zinit.sh          #   clone zinit; install tpm for tmux
  run_onchange_after_mise-install.sh.tmpl  #   `mise install` — re-runs only when mise config changes
```

### Profiles & templating

Two auto-detected dimensions plus a one-time prompt; they compose into three effective profiles.

- **OS auto-detected** (`.chezmoi.os`) covers ~90%: brew vs apt paths, `gh` location, clipboard
  (`pbcopy`/`pbpaste` vs `wl-copy`/`wl-paste`), editor (`cursor`/`code` vs `vim`), `libpq` PATH (macOS).
- **Container auto-detected** in `.chezmoi.toml.tmpl` — true when any of `/.dockerenv` exists or
  `$CODESPACES` / `$REMOTE_CONTAINERS` / `$DEVCONTAINER` is set. Sets `container=true`
  (which implies `headless=true`).
- **`.chezmoi.toml.tmpl` prompts once at `chezmoi init`** (via `promptStringOnce`, with defaults so
  `--promptDefaults` is fully non-interactive):
  - `name` (default `Nate Vick`), `email` (default `nate.vick@clickfunnels.com`) — git identity.
  - `headless` (bool) — server/SSH: skip GUI bits, force `vim` editor.

| Effective profile | Trigger | Behavior |
|-------------------|---------|----------|
| **workstation** | macOS/Linux desktop, interactive | full toolset, GUI editor, prompts asked |
| **headless** | `headless=true` (server/SSH) | full CLI toolset, `vim`, no GUI configs |
| **container** | auto-detected | `headless` + **minimal/fast** toolset + **non-interactive** init |

### Devcontainer integration

- **`install.sh`** (repo root) is the single bootstrap entrypoint, dual-purpose:
  - Installs the `chezmoi` binary to `~/.local/bin` if absent (no root, no package manager).
  - Runs `chezmoi init --apply --source "$(repo dir)"`. When stdin is not a TTY **or** a container
    is detected, it adds `--promptDefaults` so init never blocks.
  - `install.sh` is in the default list VS Code's dotfiles feature auto-runs, so pointing
    `dotfiles.repository` at this repo "just works"; Codespaces uses the same script.
- **Container toolset is lean for fast container creation:** `mise/config.toml.tmpl` gates the
  extra CLI tools (`eza`/`bat`/`fd`/`ripgrep`) and language runtimes behind `{{- if not .container }}`.
  Containers get the essentials — zinit + starship + fzf + zoxide + the zsh plugins — and the
  aliases fall back to native commands for anything absent. Language runtimes come from the
  devcontainer image, not mise.

### Vendor / machine-local blocks

The current zshrc has injected blocks: `op` (1Password) completion + `plugins.sh`, grok installer,
OpenClaw completion, Composio, `libpq` PATH.

- Tool integrations that are stable get `command -v` guards in the managed `dot_zshrc.tmpl`
  (no-op where the tool is absent).
- Anything machine-specific or installer-injected goes to a chezmoi-**ignored**
  `~/.config/zsh/local.zsh`, sourced last if present — keeps the managed file clean and prevents
  per-machine junk from being committed.

## Migration & safety

1. Work happens on the `chezmoi-migration` branch.
2. Old `rcm` files (`zshrc`, `gitconfig`, `tmux.conf`, etc.) remain in the repo until both machines
   are verified, enabling diff/rollback.
3. Bootstrap becomes: `sh -c "$(curl -fsSL get.chezmoi.io)" -- init --apply <repo>`, or just run
   `install.sh` (also the devcontainer path).
4. **Acceptance gates** (before any old file is deleted):
   - Re-measure `zsh -i -c exit` on the Linux box; must beat ~80ms.
   - Both macOS and Linux shells load with no errors; identity/aliases/tools resolve.
   - A throwaway devcontainer applies the repo **non-interactively** via `install.sh` and lands a
     working shell (prompt + plugins, no hang on prompts).

## Open questions

None blocking. 1Password-based secret templating deferred to a future iteration.
