# dotfiles

Managed with [chezmoi](https://chezmoi.io). Source lives under `home/`.

## New machine

```sh
sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply natevick
```

`-b` is not optional. The installer defaults to `BINDIR=bin`, which is *relative* — without
it chezmoi lands in `$PWD/bin/chezmoi`, wherever you happened to run the command. The apply
still succeeds (the installer `exec`s the binary it just placed), so the breakage only shows
up afterwards as `chezmoi: command not found`. `~/.local/bin` is what `dot_zshenv` puts on
PATH. Don't substitute `get.chezmoi.io/lb` either — it hardcodes a relative `.local/bin` and
so only lands correctly when run from `$HOME`.

## Devcontainer / Codespaces

Point your dotfiles setting at `github.com/natevick/dotfiles`; it runs
`install.sh`, which bootstraps non-interactively.

## Shell tools & aliases

Modern CLI tools are installed via [mise](https://mise.jdx.dev) (`~/.config/mise/conf.d/cli-tools.toml`):
`fzf`, `eza`, `bat`, `fd`, `ripgrep`, `zoxide`, `starship`. `tmux` and `vim` (the git editor) are
installed by the bootstrap via the native package manager (brew/apt/dnf/apk) when missing —
the only true prerequisites are `zsh`, `git`, and `curl`. All shell wiring lives in
`home/dot_config/zsh/aliases.zsh` and is `command -v`-guarded, so anything missing degrades to the
native command.

On macOS (non-headless), the bootstrap also installs [AeroSpace](https://nikitabobko.github.io/AeroSpace),
an i3-like tiling WM, and manages `~/.aerospace.toml`. It is the repo's only Homebrew **cask** and its
only **tap** (`nikitabobko/tap`, the upstream author's own) — everything else brew installs is
homebrew-core.

### Aliases

| Alias | Expands to | Notes |
|-------|------------|-------|
| `ls`  | `eza --group-directories-first` | dirs first, colorized |
| `ll`  | `eza -lah --git --group-directories-first` | long view, human sizes, git status column |
| `la`  | `eza -a` | include dotfiles |
| `lt`  | `eza --tree --level=2` | tree, 2 levels |
| `cat` | `bat --paging=never` | syntax highlighting; auto-plain when piped; scripts still get real `cat` |
| `grep`| `grep --color=auto` | original grep, colorized |
| `zrc` / `tmrc` | `$EDITOR ~/.zshrc` / `~/.tmux.conf` | quick-edit configs |
| `xcopy` / `xpaste` | `pbcopy`/`pbpaste` (macOS), else `wl-copy`/`wl-paste`, else `xclip` | clipboard |

### Called directly (no alias — originals left intact)

| Command | Replaces | Notes |
|---------|----------|-------|
| `bat <file>` | `cat` | pager + highlighting |
| `fd <pattern>` | `find` | fast, `.gitignore`-aware; `-H` includes hidden, `-e rb` by extension |
| `rg <pattern>` | `grep -r` | fast recursive content search, `.gitignore`-aware |
| `z <name>` / `zi` | `cd` | zoxide: jump to a visited dir by frecency / interactive picker |

`find` and `grep` are intentionally **not** aliased — `fd`/`rg` use different argument syntax.

### fzf keybindings

| Key | Action |
|-----|--------|
| `Ctrl-R` | fuzzy shell-history search |
| `Ctrl-T` | fuzzy file/dir picker (powered by `fd`) with `bat`/`eza` preview pane; pastes the path |
| `Alt-C`  | fuzzy `cd` (powered by `fd`) with an `eza` tree preview |

`fd` is fzf's default source (`FZF_DEFAULT_COMMAND`), so it's fast and `.gitignore`-aware everywhere.
On macOS, `Alt-C` needs the terminal set to treat Option as Meta (Esc+); `Ctrl-T`/`Ctrl-R` work regardless.

## Day-to-day

- `chezmoi edit ~/.zshrc` — edit a managed file
- `chezmoi diff` — preview what apply would change (always run first)
- `chezmoi apply` — apply changes **from the local source only; this never pulls**
- `chezmoi update` — `git pull` the source, then apply. Use this on a second machine
- `chezmoi cd` — drop into the source repo

If a machine is missing something you know you merged, check the source is current before
suspecting the templates — a stale clone looks exactly like a gating bug:

```sh
git -C "$(chezmoi execute-template '{{ .chezmoi.workingTree }}')" log --oneline -1
```

Per-machine/secret junk goes in `~/.config/zsh/local.zsh` (git-ignored, sourced last).
Work machines additionally clone the private `dotfiles-work` overlay and run its `install.sh`.
