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
5. **Tool inits that aren't mise or starship go in `_deferred_tool_inits`** (defined in `dot_zshrc.tmpl`, invoked from the `atload` of `zsh-autosuggestions` in `plugins.zsh`). fzf, zoxide and op used to run sync and cost ~8ms before the prompt for keybindings and completions nothing can reach until a prompt exists. Piggybacking on an existing turbo plugin's `atload` avoids cloning a `null` carrier just to schedule code. Note that `zsh -i -c exit` never fires turbo, so this work is invisible to the budget check — that's the point, but it also means functional changes here need verifying in a real interactive shell (`zsh/zpty`), not with `-c`.
6. **mise's precmd hook is removed on purpose** (`dot_zshrc.tmpl`, right after activation). `mise activate` installs a chpwd hook *and* a precmd hook; the precmd one forks `mise hook-env` before every prompt to notice a config file edited in place without a `cd`. That fork is ~20ms per prompt here (see below) and buys almost nothing — the chpwd hook already re-resolves on every directory change, which is the case that matters. If you edit `mise.toml` or `.ruby-version` in place, `cd .` or `mise shell` refreshes. Don't "fix" this by re-adding the hook.

## What this machine costs (measured 2026-09-01)

Every process launch on this Mac pays **6-13ms** before it runs a single instruction — `/usr/bin/true`
costs as much as `mise --version`. The cause is `io.kandji.KandjiAgent.ESF-Extension`: Kandji's
Endpoint Security extension authorizes every `exec`. It's corporate MDM; it isn't going away, and it
swings with load. Consequences:

- **The unit of cost is the exec, not the tool.** Twelve mise tools vs one changed `hook-env` by ~5ms
  (~0.45ms/tool). One extra sync fork changes it by 10-30ms. Optimize forks, not the tool list.
- **Per prompt**, after the fixes above: mise 0ms (was ~20ms, every prompt); starship ~28ms in `~`,
  **~62ms inside a git repo** because its git modules each fork `git`. That is now the whole per-prompt
  cost, and it's a starship config choice (`git_status` is the expensive module), not a dotfiles bug.
- **Shims are ruinous here**: 37ms vs 2.7ms direct for `eza --version`, because a shim is two execs.
  `mise activate` stays. Do not "optimize" to `mise activate --shims`.
- **Wall-clock startup is load-hostage.** With an unchanged config the median of five ranged 74-87ms
  in one afternoon while the min held at 66-68. Hence min-of-N below.

To see the per-prompt cost yourself: `for f in $precmd_functions; do; done` timed with `EPOCHREALTIME`
inside `zsh -i`, or just `time (starship prompt --terminal-width 120)` in and out of a repo.

## Enforcement

A pre-commit hook (`scripts/check-shell-startup.zsh`) gates commits touching `dot_zshrc.tmpl`, `dot_config/zsh/`, or `dot_config/mise/`: one warm-up run, then the **minimum of 9** `zsh -i` startups, **adjusted for the exec tax**, must stay under 80ms. Minimum because noise only adds, so it estimates what the config costs and a regression still raises it by its full cost (a median of 5 straddled the budget with an unchanged config). Adjusted because even the min of 9 read 73 and 85 for the same config ten minutes apart: the gate measures `/usr/bin/true` interleaved with the samples — the cheapest possible process, so its cost *is* the tax — and credits the excess over 2ms for exactly the two execs a startup makes (zsh, one `mise hook-env`). A third sync exec is charged in full. On a Mac without the tax the credit is zero. Limit: this credits the exec-tax share of load, not CPU contention — three back-to-back runs read raw min 67-77 and adjusted 59-67 — so it narrows the noise rather than removing it; the remaining headroom is what makes the gate reliable. It measures the *live applied* config, so `chezmoi apply` before committing shell changes (it warns on drift). Local-only — CI container timing says nothing about this budget.
