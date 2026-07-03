# Chezmoi workflow & conventions

## Day-to-day

```sh
chezmoi diff          # ALWAYS first — see what apply would change, in both directions
chezmoi apply         # write source → machine
chezmoi add ~/.file   # back-port a live hotfix into the source repo
chezmoi cd            # drop into this repo
```

If bare `chezmoi` errors with `stat ~/.local/share/chezmoi: no such file`, the generated config lost its `sourceDir`. Fix: `chezmoi init --source ~/.dotfiles` (the config template records `sourceDir` from `.chezmoi.sourceDir`, so this sticks).

## File naming (chezmoi conventions)

| Prefix/suffix | Meaning |
|---|---|
| `dot_` | `.` in the target name (`dot_zshrc` → `~/.zshrc`) |
| `executable_` | target gets +x |
| `.tmpl` | Go template, rendered with `[data]` from `~/.config/chezmoi/chezmoi.toml` |
| `modify_` | script that receives the current target file on stdin, emits the new content |
| `run_once_*` | runs once per machine (state in chezmoi's boltdb; won't re-fire without `chezmoi state` reset) |
| `run_onchange_*` | re-runs when its rendered content changes — `install-tools` embeds the hash of `cli-tools.toml.tmpl`, so editing that toml triggers `mise install` |

## Templating profiles

Two auto-detected dimensions + one prompt, set at `chezmoi init` in `home/.chezmoi.toml.tmpl`:

- `.chezmoi.os` — darwin vs linux (brew paths, editor, clipboard).
- `.container` — auto-true when `/.dockerenv` or `$CODESPACES`/`$REMOTE_CONTAINERS`/`$DEVCONTAINER`. Containers get the lean toolset (`{{ if not .container }}` gates in the mise tomls) and are always headless.
- `.headless` — prompted once; forces vim, skips GUI bits.

## Traps

- **Keys in `home/dot_claude/modify_settings.json` are chezmoi-owned.** Change them in this repo, not the Claude Code UI — a UI change to one of those keys is reverted on the next apply. Everything else in `~/.claude/settings.json` is left alone by the merge.
- The Claude statusline needs `jq`; it's in the mise cli-tools list for that reason.
- `~/.gitignore_global` is the global git ignore (`core.excludesfile`). Git's default `~/.config/git/ignore` is unused here — don't add to it.
- CI (`.github/workflows/ci.yml`) runs `install.sh` in a throwaway Ubuntu container as the acceptance gate: non-interactive bootstrap must land a working shell. Keep it green.
