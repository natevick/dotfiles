# Dotfiles → chezmoi Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dated rcm + oh-my-zsh dotfiles with one chezmoi repo that drives macOS, Linux, and devcontainers identically, with a sub-80ms zsh boot.

**Architecture:** chezmoi source lives under `home/` (via `.chezmoiroot`). The zsh stack stays zinit + starship but is retuned — starship loads synchronously, every plugin loads via `zinit wait lucid` turbo after the prompt paints, and `compinit` uses the cached `-C` fast path. The modern CLI toolset (fzf/eza/bat/fd/ripgrep/zoxide/starship) is installed uniformly via mise (in `conf.d`, so it never clobbers existing language runtimes). Profiles are OS + container auto-detection plus a single identity prompt; `install.sh` bootstraps non-interactively for containers.

**Tech Stack:** chezmoi, zsh, zinit, starship, mise, tpm, Go templates (chezmoi), POSIX sh (bootstrap scripts).

## Global Constraints

- **Boot target:** `zsh -i -c exit` must measure **< 80ms** on the Linux box (baseline 760ms) before any old file is deleted.
- **Shell stack:** zinit + starship only. oh-my-zsh removed. All plugins load via `zinit wait lucid` (turbo); `compinit` runs once via `zicompinit` with `-C`.
- **Toolset install:** mise only, declared in `~/.config/mise/conf.d/cli-tools.toml` (never the main `config.toml` — do not touch existing language runtimes). Native package manager bootstraps only `zsh`/`git`/`mise`.
- **Repo shape:** dotfile source under `home/`; `.chezmoiroot` contains `home`. Repo-meta (`install.sh`, `docs/`, `LICENSE`, `.github/`) lives outside the source.
- **git credential helper:** `!gh auth git-credential` (gh resolved on PATH — never an absolute path like `/opt/homebrew/bin/gh`).
- **Non-interactive containers:** `install.sh` adds `--promptDefaults` when stdin is not a TTY or a container is detected. Init must never block on a prompt.
- **Safety:** old rcm files (`zshrc`, `gitconfig`, `tmux.conf`, `*.sh`, `config/`, `host-docker/`, `docker/`, `Xresources`, `xprofile`) stay in the repo until macOS + Linux + a throwaway container are all verified (Task 7).
- **Repo:** `github.com/natevick/dotfiles`. Remote bootstrap: `sh -c "$(curl -fsSL https://get.chezmoi.io)" -- init --apply natevick`.
- **Identity defaults:** name `Nate Vick`, email `nate.vick@clickfunnels.com`.
- Work happens on branch `chezmoi-migration`. Commit after every task.

---

### Task 1: Scaffold chezmoi source, root, and profile config

**Files:**
- Create: `.chezmoiroot`
- Create: `home/.chezmoi.toml.tmpl`

**Interfaces:**
- Produces: chezmoi `[data]` keys consumed by every later template — `.name` (string), `.email` (string), `.headless` (bool), `.container` (bool), plus chezmoi built-ins `.chezmoi.os`.

- [ ] **Step 1: Install chezmoi locally (tool needed for all verification)**

```sh
sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
chezmoi --version
```
Expected: prints a chezmoi version (e.g. `chezmoi version v2.x`).

- [ ] **Step 2: Create `.chezmoiroot`**

```
home
```
(Single line, no trailing content.)

- [ ] **Step 3: Create `home/.chezmoi.toml.tmpl`**

```
{{- /* Auto-detect container environments */ -}}
{{- $container := false -}}
{{- if or (env "CODESPACES") (env "REMOTE_CONTAINERS") (env "DEVCONTAINER") -}}
{{-   $container = true -}}
{{- end -}}
{{- if stat "/.dockerenv" -}}
{{-   $container = true -}}
{{- end -}}
{{- /* Identity prompts (defaults make --promptDefaults non-interactive) */ -}}
{{- $name := promptStringOnce . "name" "Full name for git" "Nate Vick" -}}
{{- $email := promptStringOnce . "email" "Email for git" "nate.vick@clickfunnels.com" -}}
{{- /* Containers are always headless; otherwise ask once */ -}}
{{- $headless := $container -}}
{{- if not $container -}}
{{-   $headless = promptBoolOnce . "headless" "Headless machine (server, no GUI)" false -}}
{{- end -}}

[data]
    name = {{ $name | quote }}
    email = {{ $email | quote }}
    headless = {{ $headless }}
    container = {{ $container }}
```

- [ ] **Step 4: Verify data resolves non-interactively (acts as the failing-then-passing test)**

```sh
chezmoi init --source "$PWD" --promptDefaults
chezmoi --source "$PWD" data --format json | grep -E '"(name|email|headless|container)"'
```
Expected: JSON shows `"name": "Nate Vick"`, `"email": "nate.vick@clickfunnels.com"`, `"headless": false` (on this macOS workstation), `"container": false`. No prompt blocks.

- [ ] **Step 5: Verify container detection branch**

```sh
DEVCONTAINER=1 chezmoi --source "$PWD" execute-template '{{ (stat "/.dockerenv") }}{{ if or (env "CODESPACES") (env "REMOTE_CONTAINERS") (env "DEVCONTAINER") }}container=true{{ end }}'
```
Expected: prints `container=true`.

- [ ] **Step 6: Commit**

```sh
git add .chezmoiroot home/.chezmoi.toml.tmpl
git commit -m "chezmoi: scaffold source root and profile config"
```

---

### Task 2: Port static configs (gitconfig, gitignore, tmux)

**Files:**
- Create: `home/dot_gitconfig.tmpl`
- Create: `home/dot_gitignore_global`
- Create: `home/dot_tmux.conf`

**Interfaces:**
- Consumes: `.name`, `.email`, `.headless`, `.chezmoi.os` from Task 1.
- Produces: applied `~/.gitconfig`, `~/.gitignore_global`, `~/.tmux.conf`.

- [ ] **Step 1: Create `home/dot_gitconfig.tmpl`**

```
[user]
	name = {{ .name }}
	email = {{ .email }}
[push]
	default = simple
[core]
	excludesfile = ~/.gitignore_global
	editor = {{ if .headless }}vim{{ else if eq .chezmoi.os "darwin" }}cursor --wait{{ else }}code --wait{{ end }}
[init]
	defaultBranch = main
[credential "https://github.com"]
	helper =
	helper = !gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !gh auth git-credential
[alias]
	fixup = "!fn() { _FIXUP_COMMIT=`git log -n 50 --pretty=format:'%h %s' --no-merges | fzf | cut -c -7` && git commit -m \"fixup! ${_FIXUP_COMMIT}\" && GIT_EDITOR=true git rebase --autosquash -i ${_FIXUP_COMMIT}^; }; fn"
```

- [ ] **Step 2: Create `home/dot_gitignore_global`**

```
**/.claude/settings.local.json
```

- [ ] **Step 3: Create `home/dot_tmux.conf` (verbatim port of existing `tmux.conf`)**

```
unbind C-b
set -g prefix C-a
setw -g mode-keys vi
set -g base-index 1
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind | split-window -h
bind - split-window -v

set-option -g history-limit 10000

# Plugins
# To install new plugin: add to this list and then press `prefix + I`.
# See https://github.com/tmux-plugins/tpm
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'odedlaz/tmux-onedark-theme'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
```

- [ ] **Step 4: Verify rendered gitconfig (macOS workstation)**

```sh
chezmoi --source "$PWD" cat ~/.gitconfig
```
Expected: `email = nate.vick@clickfunnels.com`, `editor = cursor --wait`, and `helper = !gh auth git-credential` (no absolute path).

- [ ] **Step 5: Verify headless + linux rendering of the editor line**

```sh
chezmoi --source "$PWD" execute-template --init --promptString name="Nate Vick",email=nate.vick@clickfunnels.com '{{ if .headless }}vim{{ else if eq .chezmoi.os "darwin" }}cursor --wait{{ else }}code --wait{{ end }}'
```
Expected on this mac: `cursor --wait`. (On the Linux box this same template yields `code --wait`; in a container, `vim`.)

- [ ] **Step 6: Verify tmux.conf applies byte-for-byte**

```sh
chezmoi --source "$PWD" cat ~/.tmux.conf | diff - tmux.conf && echo "MATCH"
```
Expected: `MATCH` (rendered target equals the old file, minus the commented `@continuum-boot` lines which were already commented out — confirm only those differ if diff is non-empty).

- [ ] **Step 7: Commit**

```sh
git add home/dot_gitconfig.tmpl home/dot_gitignore_global home/dot_tmux.conf
git commit -m "chezmoi: port gitconfig, global gitignore, tmux.conf"
```

---

### Task 3: Toolset + plugin-manager install pipeline

**Files:**
- Create: `home/dot_config/mise/conf.d/cli-tools.toml.tmpl`
- Create: `home/run_once_before_install-mise.sh.tmpl`
- Create: `home/run_once_after_install-zinit.sh`
- Create: `home/run_onchange_after_install-tools.sh.tmpl`

**Interfaces:**
- Consumes: `.container` from Task 1.
- Produces: on a machine after `chezmoi apply` — `mise` on PATH, `~/.local/share/zinit/zinit.git/zinit.zsh`, `~/.tmux/plugins/tpm`, and `fzf/zoxide/starship` (plus `eza/bat/fd/rg` when not a container) installed via mise.

- [ ] **Step 1: Create `home/dot_config/mise/conf.d/cli-tools.toml.tmpl`**

Lives in `conf.d/` so mise merges it without touching the existing `~/.config/mise/config.toml` language runtimes.

```
[tools]
fzf = "latest"
zoxide = "latest"
starship = "latest"
{{- if not .container }}
eza = "latest"
bat = "latest"
fd = "latest"
ripgrep = "latest"
{{- end }}
```

- [ ] **Step 2: Create `home/run_once_before_install-mise.sh.tmpl`**

```sh
#!/bin/sh
set -eu
if ! command -v mise >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/mise" ]; then
  echo "==> Installing mise"
  curl -fsSL https://mise.run | sh
fi
```

- [ ] **Step 3: Create `home/run_once_after_install-zinit.sh`**

```sh
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
```

- [ ] **Step 4: Create `home/run_onchange_after_install-tools.sh.tmpl`**

The `include ... | sha256sum` comment makes chezmoi re-run this only when the tools file changes.

```sh
#!/bin/sh
set -eu
# cli-tools hash: {{ include "dot_config/mise/conf.d/cli-tools.toml.tmpl" | sha256sum }}
export PATH="$HOME/.local/bin:$PATH"
echo "==> Installing CLI tools via mise"
mise install -y
```

- [ ] **Step 5: Verify script syntax + template rendering**

```sh
for f in home/run_once_before_install-mise.sh.tmpl home/run_once_after_install-zinit.sh home/run_onchange_after_install-tools.sh.tmpl; do sh -n "$f" || echo "SYNTAX FAIL: $f"; done
chezmoi --source "$PWD" cat ~/.config/mise/conf.d/cli-tools.toml
```
Expected: no `SYNTAX FAIL` lines (the `.tmpl` files are valid POSIX sh even with the template comments). The mise toml shows `eza`/`bat`/`fd`/`ripgrep` present (this mac is not a container).

> Note: `sh -n` on a `.tmpl` works here because the only template content sits in shell comments/strings. If a future edit puts template logic mid-statement, validate with `chezmoi cat` of the script instead.

- [ ] **Step 6: Dry-run the apply to confirm the script ordering**

```sh
chezmoi --source "$PWD" apply --dry-run --verbose 2>&1 | grep -E 'install-(mise|zinit|tools)'
```
Expected: `run_once_before_install-mise` is listed before file writes; `run_once_after_install-zinit` and `run_onchange_after_install-tools` after.

- [ ] **Step 7: Live install verification on the Linux box** (real end-to-end gate)

```sh
ssh <linux-box> 'cd ~/dotfiles 2>/dev/null || git clone https://github.com/natevick/dotfiles ~/dotfiles; cd ~/dotfiles && git fetch && git checkout chezmoi-migration && git pull && ~/.local/bin/chezmoi init --apply --source ~/dotfiles --promptDefaults; command -v eza bat fd zoxide starship; ls ~/.local/share/zinit/zinit.git/zinit.zsh ~/.tmux/plugins/tpm'
```
Expected: paths print for `eza bat fd zoxide starship`, and both `zinit.zsh` and the `tpm` dir exist. (chezmoi must be installed on the box first — Task 1 Step 1's installer, run there.)

- [ ] **Step 8: Commit**

```sh
git add home/dot_config/mise home/run_once_before_install-mise.sh.tmpl home/run_once_after_install-zinit.sh home/run_onchange_after_install-tools.sh.tmpl
git commit -m "chezmoi: mise toolset + zinit/tpm install pipeline"
```

---

### Task 4: The tuned zsh stack (THE speed fix)

**Files:**
- Create: `home/dot_config/starship.toml`
- Create: `home/dot_config/zsh/plugins.zsh`
- Create: `home/dot_config/zsh/aliases.zsh`
- Create: `home/dot_zshrc.tmpl`

**Interfaces:**
- Consumes: `.chezmoi.os`, `.headless` from Task 1; the tools and zinit installed in Task 3.
- Produces: the interactive shell. Sources `~/.config/zsh/plugins.zsh` and `~/.config/zsh/aliases.zsh`; sources `~/.config/zsh/local.zsh` if present (defined in Task 5).

- [ ] **Step 1: Create `home/dot_config/starship.toml`**

Copy the existing config from the Linux box verbatim (it is the source of truth and already styled):

```sh
scp <linux-box>:~/.config/starship.toml home/dot_config/starship.toml
```
Expected: file created. (If `scp` is unavailable, `ssh <linux-box> 'cat ~/.config/starship.toml' > home/dot_config/starship.toml`.)

- [ ] **Step 2: Create `home/dot_config/zsh/plugins.zsh`**

The turbo block. `compinit` runs here once via `zicompinit` with the cached `-C` fast path; everything is deferred with `wait lucid`.

```zsh
# Turbo-loaded plugins. Sourced by ~/.zshrc AFTER zinit + starship are initialized.
# Everything here loads ~1ms AFTER the prompt paints (zinit "wait lucid").

zinit wait lucid for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf \
    zsh-users/zsh-completions

# Oh-My-Zsh snippets (aliases + completions only — no omz framework load)
zinit wait lucid for \
  OMZP::git \
  OMZP::docker \
  OMZP::docker-compose \
  OMZP::kubectl
```

- [ ] **Step 3: Create `home/dot_config/zsh/aliases.zsh`**

Modern tools with native fallbacks; clipboard chosen at runtime so this file needs no templating.

```zsh
# ---- listing (eza with native fallback) ----
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --git --group-directories-first'
  alias la='eza -a'
  alias lt='eza --tree --level=2'
else
  alias ls='ls --color=auto'
  alias ll='ls -alhF'
  alias la='ls -A'
fi

alias grep='grep --color=auto'

# ---- config editors ----
alias zrc='${EDITOR} ~/.zshrc'
alias tmrc='${EDITOR} ~/.tmux.conf'

# ---- clipboard (first available wins) ----
if command -v pbcopy &>/dev/null; then
  alias xcopy='pbcopy'; alias xpaste='pbpaste'
elif command -v wl-copy &>/dev/null; then
  alias xcopy='wl-copy'; alias xpaste='wl-paste'
elif command -v xclip &>/dev/null; then
  alias xcopy='xclip -selection clipboard'; alias xpaste='xclip -selection clipboard -o'
fi
```

- [ ] **Step 4: Create `home/dot_zshrc.tmpl`**

```zsh
# ~/.zshrc — managed by chezmoi. Edit source: `chezmoi edit ~/.zshrc`

# ---- PATH ----
export PATH="$HOME/.local/bin:$PATH"
{{- if eq .chezmoi.os "darwin" }}
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
{{- end }}

# ---- History ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE INC_APPEND_HISTORY EXTENDED_HISTORY
setopt AUTO_CD INTERACTIVE_COMMENTS

# ---- Editor ----
{{- if .headless }}
export EDITOR=vim
{{- else }}
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR=vim
else
  export EDITOR={{ if eq .chezmoi.os "darwin" }}cursor{{ else }}code{{ end }}
fi
{{- end }}

# ---- Autoloaded functions ----
fpath=("$HOME/.config/zsh/functions" $fpath)
autoload -Uz "$HOME"/.config/zsh/functions/*(:t)

# ---- mise (sync: tools must be on PATH before completions/prompt) ----
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# ---- zinit ----
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[[ -f "$ZINIT_HOME/zinit.zsh" ]] && source "$ZINIT_HOME/zinit.zsh"

# ---- starship (sync: prompt paints immediately) ----
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ---- turbo plugins + aliases ----
[[ -f "$HOME/.config/zsh/plugins.zsh" ]] && source "$HOME/.config/zsh/plugins.zsh"
[[ -f "$HOME/.config/zsh/aliases.zsh" ]] && source "$HOME/.config/zsh/aliases.zsh"

# ---- fzf + zoxide ----
command -v fzf    &>/dev/null && source <(fzf --zsh)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ---- vendor integrations (guarded; no-op when tool absent) ----
command -v op &>/dev/null && { eval "$(op completion zsh)"; compdef _op op; }
[[ -f "$HOME/.config/op/plugins.sh" ]] && source "$HOME/.config/op/plugins.sh"
[[ -d "$HOME/.grok/bin" ]] && { export PATH="$HOME/.grok/bin:$PATH"; fpath=("$HOME/.grok/completions/zsh" $fpath); }
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"
[[ -d "$HOME/.composio" ]] && export PATH="$HOME/.composio:$PATH"

# ---- machine-local escape hatch (chezmoi-ignored) ----
[[ -f "$HOME/.config/zsh/local.zsh" ]] && source "$HOME/.config/zsh/local.zsh"
```

- [ ] **Step 5: Baseline the boot time (the failing test)**

```sh
ssh <linux-box> 'for i in 1 2 3; do /usr/bin/time -f "%e s" zsh -i -c exit 2>&1 | tail -1; done'
```
Expected: ~0.76s — this is the failure state we are fixing.

- [ ] **Step 6: Apply the new stack on the Linux box**

```sh
ssh <linux-box> 'cd ~/dotfiles && git pull && ~/.local/bin/chezmoi apply --source ~/dotfiles'
```
Expected: applies cleanly; `~/.zshrc`, `~/.config/starship.toml`, `~/.config/zsh/*.zsh` written.

- [ ] **Step 7: Verify boot time now passes (< 80ms) and shell is error-free**

```sh
ssh <linux-box> 'for i in 1 2 3 4 5; do /usr/bin/time -f "%e s" zsh -i -c exit 2>&1 | tail -1; done; echo "---errors---"; zsh -i -c "exit" 2>&1 | grep -iE "error|not found|command not found" || echo "no errors"'
```
Expected: each run **< 0.08s**; `no errors`. (If still slow, profile with `zsh -i -c "zmodload zsh/zprof; exit; zprof" | head` — likely a stray sync `eval`.)

- [ ] **Step 8: Verify interactive features work**

```sh
ssh -tt <linux-box> 'zsh -i -c "command -v starship; type gst; whence _zsh_autosuggest_start; echo READY"'
```
Expected: starship path prints, `gst` resolves (OMZ git alias loaded via turbo), autosuggest function exists, `READY`.

- [ ] **Step 9: Commit**

```sh
git add home/dot_config/starship.toml home/dot_config/zsh/plugins.zsh home/dot_config/zsh/aliases.zsh home/dot_zshrc.tmpl
git commit -m "chezmoi: tuned zinit-turbo + starship zsh stack (<80ms boot)"
```

---

### Task 5: Port functions, guard vendor blocks, add local escape hatch

**Files:**
- Create: `home/dot_config/zsh/functions/rails-console`
- Create: `home/.chezmoiignore`

**Interfaces:**
- Consumes: the `fpath`/`autoload` lines and the `local.zsh` source line from Task 4's `dot_zshrc.tmpl`.
- Produces: an autoloaded `rails-console` function; a chezmoi-ignored `~/.config/zsh/local.zsh` path.

- [ ] **Step 1: Port the `rails-console` function verbatim**

```sh
cp ~/.config/zsh/functions/rails-console home/dot_config/zsh/functions/rails-console
```
Expected: file copied (14KB CF2 Rails console helper).

- [ ] **Step 2: Create `home/.chezmoiignore`**

`local.zsh` must never be managed or removed by chezmoi — it is the per-machine escape hatch.

```
# Per-machine escape hatch — sourced by .zshrc if present, never managed by chezmoi
.config/zsh/local.zsh
```

- [ ] **Step 3: Verify rails-console autoloads and local.zsh is ignored**

```sh
chezmoi --source "$PWD" apply --dry-run --verbose 2>&1 | grep -q 'local.zsh' && echo "LEAK: local.zsh managed" || echo "local.zsh correctly ignored"
ssh <linux-box> 'cd ~/dotfiles && git pull && ~/.local/bin/chezmoi apply --source ~/dotfiles && zsh -i -c "whence -v rails-console"'
```
Expected: `local.zsh correctly ignored`; and `rails-console` reports as an autoloaded/defined function.

- [ ] **Step 4: Verify the local.zsh hatch actually loads when present**

```sh
ssh <linux-box> 'echo "export DOTFILES_LOCAL_OK=1" > ~/.config/zsh/local.zsh; zsh -i -c "echo \$DOTFILES_LOCAL_OK"; rm ~/.config/zsh/local.zsh'
```
Expected: prints `1`.

- [ ] **Step 5: Commit**

```sh
git add home/dot_config/zsh/functions/rails-console home/.chezmoiignore
git commit -m "chezmoi: port rails-console fn + local.zsh escape hatch"
```

---

### Task 6: `install.sh` bootstrap + devcontainer verification

**Files:**
- Create: `install.sh` (repo root — replaces the old rcm bootstrap)

**Interfaces:**
- Consumes: `.chezmoiroot` + the full `home/` source from Tasks 1–5.
- Produces: a one-shot entrypoint usable manually, by VS Code's `dotfiles.repository`, and by Codespaces.

- [ ] **Step 1: Create `install.sh`**

```sh
#!/bin/sh
# Bootstrap entrypoint: installs chezmoi (if needed) and applies this repo.
# Works for manual setup AND devcontainers/Codespaces (non-interactive).
set -eu

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
```

- [ ] **Step 2: Make it executable + lint**

```sh
chmod +x install.sh
sh -n install.sh && echo "syntax ok"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed; skipped)"
```
Expected: `syntax ok`; shellcheck reports no errors (the `SC2086` on `$EXTRA` is intentionally disabled).

- [ ] **Step 3: Verify non-interactive bootstrap in a throwaway container (the real gate)**

```sh
docker run --rm -e DEVCONTAINER=1 ubuntu:24.04 sh -c '
  set -e
  apt-get update -qq && apt-get install -yqq git curl zsh >/dev/null
  git clone --depth 1 -b chezmoi-migration https://github.com/natevick/dotfiles /root/dotfiles
  cd /root/dotfiles && sh install.sh
  echo "--- boot check ---"
  zsh -i -c "command -v starship >/dev/null && echo STARSHIP_OK; echo SHELL_OK"
'
```
Expected: install runs to completion with **no prompt hang**, then prints `STARSHIP_OK` and `SHELL_OK`. (Container profile skips eza/bat/fd/rg; aliases fall back to native — no errors.)

- [ ] **Step 4: Commit**

```sh
git add install.sh
git commit -m "chezmoi: non-interactive install.sh bootstrap (devcontainer-ready)"
```

---

### Task 7: macOS cutover, acceptance, and removal of dead files

**Files:**
- Delete: `zshrc`, `gitconfig`, `tmux.conf`, `Xresources`, `xprofile`, `install.log` (if present)
- Delete: `install.sh`-era scripts `system_install.sh`, `user_install.sh`, and the old `install.sh` content is already replaced in Task 6
- Delete: `config/` (i3, kitty), `host-docker/`, `docker/`
- Create: `README.md` (bootstrap instructions)

**Interfaces:**
- Consumes: the verified `home/` source and `install.sh` from Tasks 1–6.
- Produces: a clean repo whose only dotfile source is `home/`.

- [ ] **Step 1: Apply on macOS and verify the shell (cutover gate)**

```sh
export PATH="$HOME/.local/bin:$PATH"
chezmoi init --apply --source "$PWD"
for i in 1 2 3; do /usr/bin/time zsh -i -c exit; done 2>&1 | tail -3
zsh -i -c 'command -v starship eza bat fd zoxide; type gst; echo MAC_OK'
```
Expected: shell boots fast and error-free; `eza/bat/fd/zoxide/starship` now resolve on mac (installed via mise); `gst` resolves; `MAC_OK`. Confirm `~/.gitconfig` shows the clickfunnels email and `cursor --wait`.

- [ ] **Step 2: Re-confirm the Linux acceptance gate still holds**

```sh
ssh <linux-box> 'for i in 1 2 3; do /usr/bin/time -f "%e s" zsh -i -c exit 2>&1 | tail -1; done'
```
Expected: each run **< 0.08s**.

- [ ] **Step 3: Remove dead files now that all three environments pass**

```sh
git rm -r --quiet zshrc gitconfig tmux.conf Xresources xprofile system_install.sh user_install.sh config host-docker docker 2>/dev/null || true
rm -f install.log
git status --short
```
Expected: the listed paths are staged for deletion; `home/`, `install.sh`, `docs/`, `LICENSE`, `.github/` remain.

- [ ] **Step 4: Create `README.md`**

```markdown
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
```

- [ ] **Step 5: Commit and verify the tree is clean**

```sh
git add -A
git commit -m "chezmoi: remove dead rcm/oh-my-zsh files; add README"
ls
```
Expected: top level shows `home/ install.sh docs/ README.md LICENSE .github/` and no `zshrc`/`gitconfig`/`config`/`host-docker`/`docker`.

- [ ] **Step 6: Finalize the branch**

Use the `superpowers:finishing-a-development-branch` skill to choose merge/PR. Suggested: open a PR from `chezmoi-migration` to `main`.

---

## Self-Review

**Spec coverage:**
- One chezmoi repo, macOS+Linux → Tasks 1–4, 7. ✓
- <80ms boot → Task 4 (Steps 5/7) + Task 7 (Step 2) acceptance gates. ✓
- Off oh-my-zsh, zinit+starship tuned → Task 4. ✓
- Modern toolset via mise (conf.d, no clobber) → Task 3 + Task 4 aliases. ✓
- Profiles (OS + container auto-detect + identity/headless prompt) → Task 1. ✓
- Devcontainer non-interactive → Task 1 (detection), Task 6 (install.sh + container test). ✓
- Dropped i3/X11/old-docker/old bootstrap → Task 7. ✓
- gh helper via PATH → Task 2. ✓
- Safety: old files kept until verified → enforced by ordering (deletion only in Task 7 after gates). ✓
- Vendor blocks guarded + local.zsh hatch → Task 4 (zshrc) + Task 5. ✓

**Placeholder scan:** No TBD/TODO; every code step contains full file contents or a concrete copy command. `rails-console` and `starship.toml` are ported via explicit `cp`/`scp` of existing source-of-truth files rather than transcribed, to avoid drift.

**Type/name consistency:** Data keys `.name/.email/.headless/.container` defined in Task 1 are used identically in Tasks 2–4. `plugins.zsh`/`aliases.zsh`/`local.zsh` paths match between Task 4's `dot_zshrc.tmpl` and Tasks 4–5 that create them. `cli-tools.toml.tmpl` path matches between Task 3's create and the `run_onchange` include hash.
