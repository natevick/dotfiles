#!/usr/bin/env zsh
# Pre-commit gate: interactive zsh startup must stay within the design budget.
# Measures the LIVE applied config — run `chezmoi apply` before committing shell
# changes or the number won't reflect your commit. See docs/shell-performance.md.
#
# One warm-up run is discarded (absorbs _eval_cached rebuilds after tool
# upgrades), then the MINIMUM of $RUNS runs, adjusted for the machine's exec tax,
# is compared against $BUDGET_MS.
#
# Why not median: noise only ever adds, so the min is the estimate of what the
# config itself costs, and a regression (a new sync fork, new sync work) raises
# the min by its full cost. A median of five straddled the budget +-7ms with an
# unchanged config.
#
# Why adjust: on this Mac every exec pays a 6-13ms endpoint-security tax (Kandji
# ESF extension) that swings with load — enough that even the min of 9 read 73
# and 85 for the same config ten minutes apart. The tax is measurable directly:
# /usr/bin/true is the cheapest process that can exist, so its cost IS the tax.
# A steady-state interactive startup makes exactly EXECS_PER_STARTUP execs (zsh
# itself, then one `mise hook-env`), so the gate credits the tax above a normal
# NORMAL_EXEC_MS for exactly those two and nothing else. A third sync exec is
# charged in full — that is the regression this gate exists to catch. On a Mac
# without the tax the credit is zero and the budget means what it says.
# Local-only by design: CI container timing says nothing about this budget.
set -eu
zmodload zsh/datetime

BUDGET_MS=${BUDGET_MS:-80}
RUNS=9

if command -v chezmoi >/dev/null 2>&1; then
  if chezmoi status 2>/dev/null | grep -qE '\.zshrc|\.config/(zsh|mise)/'; then
    print -u2 "warning: live shell config has drifted from source (chezmoi status) — measurement may not reflect this commit"
  fi
fi

EXECS_PER_STARTUP=2   # zsh itself + one `mise hook-env`. Do NOT bump this to make a new fork pass.
NORMAL_EXEC_MS=2      # what /usr/bin/true costs on a Mac with no exec-auth extension

zsh -i -c 'exit 0' >/dev/null 2>&1 || { print -u2 "error: zsh -i failed to start"; exit 1; }

# Interleave the tax probe with the samples so both see the same load.
typeset -a ms tax
for _ in {1..$RUNS}; do
  t0=$EPOCHREALTIME
  zsh -i -c 'exit 0' >/dev/null 2>&1
  ms+=( $(( (EPOCHREALTIME - t0) * 1000 )) )
  t0=$EPOCHREALTIME
  /usr/bin/true
  tax+=( $(( (EPOCHREALTIME - t0) * 1000 )) )
done

sorted=( ${(on)ms} )
best=${sorted[1]}
median=${sorted[(( (RUNS + 1) / 2 ))]}
tax_min=${${(on)tax}[1]}
credit=$(( tax_min > NORMAL_EXEC_MS ? EXECS_PER_STARTUP * (tax_min - NORMAL_EXEC_MS) : 0 ))
adjusted=$(( best - credit ))

printf 'zsh -i startup: min %.0fms (median %.0f) over %d runs; exec tax %.1fms x%d -> adjusted %.0fms (budget %dms) [' \
  "$best" "$median" "$RUNS" "$tax_min" "$EXECS_PER_STARTUP" "$adjusted" "$BUDGET_MS"
printf ' %.0f' "${ms[@]}"; printf ' ]\n'

if (( adjusted > BUDGET_MS )); then
  print -u2 "FAIL: startup budget exceeded at the fastest of $RUNS runs, after crediting this machine's"
  print -u2 "exec tax for the $EXECS_PER_STARTUP execs a startup makes. That leaves the config. Suspects: a new"
  print -u2 "sync fork or sync work in dot_zshrc.tmpl (use _eval_cached or zinit 'wait lucid'; see"
  print -u2 "docs/shell-performance.md), or a stale cache — try 'rm -rf ~/.cache/zsh' and re-run."
  exit 1
fi
