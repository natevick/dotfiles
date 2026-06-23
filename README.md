# dotfiles

Managed with [chezmoi](https://chezmoi.io). Source lives under `home/`.

## New machine

```sh
sh -c "$(curl -fsSL https://get.chezmoi.io)" -- init --apply natevick
```

## Devcontainer / Codespaces

Point your dotfiles setting at `github.com/natevick/dotfiles`; it runs
`install.sh`, which bootstraps non-interactively.

## Shell tools & aliases

Modern CLI tools are installed via [mise](https://mise.jdx.dev) (`~/.config/mise/conf.d/cli-tools.toml`):
`fzf`, `eza`, `bat`, `fd`, `ripgrep`, `zoxide`, `starship`. All shell wiring lives in
`home/dot_config/zsh/aliases.zsh` and is `command -v`-guarded, so anything missing degrades to the
native command.

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
- `chezmoi apply` — apply changes
- `chezmoi cd` — drop into the source repo

Per-machine/secret junk goes in `~/.config/zsh/local.zsh` (git-ignored, sourced last).
