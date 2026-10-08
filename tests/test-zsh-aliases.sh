#!/usr/bin/env bash

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIASES="$REPO/home/dot_config/zsh/aliases.zsh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; printf '        want: %q\n        got:  %q\n' "$3" "$2"; fi; }

mkdir -p "$TMP/bin" "$TMP/work/subdir"
printf 'line one\nline two\n' > "$TMP/work/file.txt"

cat > "$TMP/bin/eza" <<'SH'
#!/usr/bin/env bash
paths=0
for a in "$@"; do case "$a" in -*) ;; *) paths=$((paths+1)) ;; esac; done
if [ "$paths" -eq 0 ] && [ ! -t 0 ]; then
  names=$(cat)
  [ -n "$names" ] && echo "EZA-STDIN $names"
  exit 0
fi
echo "EZA $*"
SH
cat > "$TMP/bin/bat" <<'SH'
#!/usr/bin/env bash
echo "BAT $*"
SH
chmod +x "$TMP/bin/eza" "$TMP/bin/bat"

in_zsh() {
  (cd "$TMP/work" && PATH="$TMP/bin:$PATH" zsh -f -c "source '$ALIASES'; eval '$1'")
}

for fn in ls ll la; do
  out=$(in_zsh "$fn" </dev/null)
  check "$fn with no args and /dev/null stdin lists the directory" "$(grep -c file.txt <<<"$out")" 1
done
out=$(in_zsh lt </dev/null)
check "lt with no args and /dev/null stdin lists the directory" "$out" "EZA --tree --level=2 ."

mkfifo "$TMP/silent"
for fn in ls ll la lt; do
  sleep 300 > "$TMP/silent" & writer=$!
  timeout 5 bash -c "$(declare -f in_zsh); TMP='$TMP' ALIASES='$ALIASES' in_zsh $fn" < "$TMP/silent" >/dev/null
  rc=$?
  kill "$writer" 2>/dev/null; wait "$writer" 2>/dev/null
  check "$fn with no args and a silent open stdin pipe does not hang" "$rc" 0
done

out=$(in_zsh 'ls | head -1' </dev/null)
check "piped ls | head returns plain ls output" "$out" "file.txt"

out=$(in_zsh 'ls /nonexistent-path' </dev/null 2>/dev/null); rc=$?
check "ls keeps a nonzero exit status for a missing path" "$((rc != 0))" 1

in_zsh 'cat file.txt' </dev/null > "$TMP/cat.out"
if cmp -s "$TMP/cat.out" "$TMP/work/file.txt"; then ok "cat to a non-terminal returns the file bytes"; else bad "cat to a non-terminal returns the file bytes"; fi

out=$(printf 'from stdin\n' | in_zsh 'cat')
check "cat with no args still reads stdin" "$out" "from stdin"

if command -v script >/dev/null 2>&1; then
  tty_run() { script -qec "cd '$TMP/work' && PATH='$TMP/bin:$PATH' zsh -f -c \"source '$ALIASES'; eval '$1'\"" /dev/null | tr -d '\r'; }
  check "ls on a terminal still runs eza" "$(tty_run ls)" "EZA --group-directories-first"
  check "cat on a terminal still runs bat" "$(tty_run 'cat file.txt')" "BAT --paging=never file.txt"
  check "piped ls on a terminal still runs eza" "$(tty_run 'ls | head -1')" "EZA --group-directories-first"
  # shellcheck disable=SC2016
  check "ls inside a while-read loop does not eat the loop input" \
    "$(tty_run 'printf \"a\nb\n\" | while read l; do ls >/dev/null; echo \$l; done' | tr '\n' ' ')" "a b "
else
  bad "script(1) is required for the terminal checks"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
