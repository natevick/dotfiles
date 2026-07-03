#!/usr/bin/env zsh
# Pre-commit gate: interactive zsh startup must stay within the design budget.
# Measures the LIVE applied config — run `chezmoi apply` before committing shell
# changes or the number won't reflect your commit. See docs/shell-performance.md.
#
# One warm-up run is discarded (absorbs _eval_cached rebuilds after tool
# upgrades), then the median of $RUNS runs is compared against $BUDGET_MS.
# Local-only by design: CI container timing says nothing about this budget.
set -eu
zmodload zsh/datetime

BUDGET_MS=${BUDGET_MS:-80}
RUNS=5

if command -v chezmoi >/dev/null 2>&1; then
  if chezmoi status 2>/dev/null | grep -qE '\.zshrc|\.config/(zsh|mise)/'; then
    print -u2 "warning: live shell config has drifted from source (chezmoi status) — measurement may not reflect this commit"
  fi
fi

zsh -i -c 'exit 0' >/dev/null 2>&1 || { print -u2 "error: zsh -i failed to start"; exit 1; }

typeset -a ms
for _ in {1..$RUNS}; do
  t0=$EPOCHREALTIME
  zsh -i -c 'exit 0' >/dev/null 2>&1
  ms+=( $(( (EPOCHREALTIME - t0) * 1000 )) )
done

sorted=( ${(on)ms} )
median=${sorted[(( (RUNS + 1) / 2 ))]}

printf 'zsh -i startup: median %.0fms over %d runs (budget %dms) [' "$median" "$RUNS" "$BUDGET_MS"
printf ' %.0f' "${ms[@]}"; printf ' ]\n'

if (( median > BUDGET_MS )); then
  print -u2 "FAIL: startup budget exceeded. Suspects: new sync work in dot_zshrc.tmpl (use _eval_cached"
  print -u2 "or zinit 'wait lucid'), or a stale cache — try 'rm -rf ~/.cache/zsh' and re-run."
  exit 1
fi
