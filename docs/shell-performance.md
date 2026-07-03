# Shell startup performance

Budget: **`zsh -i -c exit` < 80ms** (migration goal; was 760ms pre-migration on Linux).

## Measure

```sh
for i in 1 2 3; do /usr/bin/time zsh -i -c exit; done      # wall clock
zsh -c 'zmodload zsh/zprof; source ~/.zshrc >/dev/null 2>&1; zprof | head -15'  # per-function
```

## Rules

1. **Sync before the prompt is a scarce resource.** Only mise activation (tools must be on PATH) and starship (prompt must paint) run sync. Everything else goes through zinit turbo (`wait lucid` in `plugins.zsh`) and loads ~1ms after the prompt paints.
2. **Never `eval "$(tool init zsh)"` directly** — that forks a subprocess every startup (e.g. `op completion zsh` cost ~50ms). Use `_eval_cached <name> <bin> <cmd...>` from `dot_zshrc.tmpl`: it caches the init script and regenerates only when the binary's mtime changes.
   - Caveat: `-nt` doesn't detect a tool *downgrade* — `rm -rf ~/.cache/zsh` forces a rebuild.
   - Don't add `emulate -L zsh` inside `_eval_cached` — `LOCAL_OPTIONS` would revert `setopt`s made by the sourced init (this broke starship once).
3. **compinit is deferred.** `compdef` doesn't exist at rc-load time; the stub in `dot_zshrc.tmpl` queues calls and the zinit turbo block flushes them after `zicompinit` (`-C` flag: trusts the cached dump). Anything that emits `compdef` at rc time (like `op completion`) just works via the queue.
4. New plugins go in `plugins.zsh` under the existing `zinit wait lucid for` blocks, never eager-loaded in `.zshrc`.

## Enforcement

A pre-commit hook (`scripts/check-shell-startup.zsh`) gates commits touching `dot_zshrc.tmpl`, `dot_config/zsh/`, or `dot_config/mise/`: one warm-up run, then the **median of 5** `zsh -i` startups must stay under 80ms. It measures the *live applied* config, so `chezmoi apply` before committing shell changes (it warns on drift). Local-only — CI container timing says nothing about this budget.
