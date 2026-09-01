# shellcheck shell=bash

# norm-audit.sh — the single JSON-record writer for the ~/.local/bin credential
# wrappers. Sourced, never executed. json.dumps decides what a JSON string is;
# the hand-rolled printf escapers it replaces lost 228 `issued` records.

NORM_AUDIT_LOG="${NORM_GH_AUDIT:-$HOME/.local/state/norm-gh-audit.jsonl}"

# norm_audit_emit <tool> [<key> <value> ...] [-- <argv>...]
# Fail-OPEN but LOUD. Values are untrusted bytes: argv, $PWD, a remote-supplied
# host string. None of it is assumed well-formed — that is the whole point.
norm_audit_emit() {
  local tool="$1"; shift

  local -a _kv=() _argv=()
  local _have_argv=0 _seen_sep=0 _a
  for _a in "$@"; do
    if [ "$_seen_sep" -eq 0 ] && [ "$_a" = "--" ]; then
      _seen_sep=1; _have_argv=1; continue
    fi
    if [ "$_seen_sep" -eq 0 ]; then _kv+=("$_a"); else _argv+=("$_a"); fi
  done

  if ! command -v python3 >/dev/null 2>&1; then
    printf '%s: WARNING no python3 — audit record dropped (%s)\n' \
      "$tool" "$NORM_AUDIT_LOG" >&2
    return 0
  fi

  local _line
  if ! _line="$(
    NORM_AUDIT_TOOL="$tool" \
    NORM_AUDIT_NKV="${#_kv[@]}" \
    NORM_AUDIT_HAS_ARGV="$_have_argv" \
    NORM_AUDIT_PID="$$" \
    NORM_AUDIT_PWD="$PWD" \
    python3 -c '
import datetime, json, os, sys

# Undecodable argv bytes arrive as lone surrogates, which json.dumps cannot
# encode — replace them. A lossy character beats a record that will not load.
def clean(s):
    return s.encode("utf-8", "surrogateescape").decode("utf-8", "replace")

nkv = int(os.environ["NORM_AUDIT_NKV"])
args = [clean(a) for a in sys.argv[1:]]
kv, argv = args[:nkv], args[nkv:]

rec = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "tool": clean(os.environ["NORM_AUDIT_TOOL"]),
}
for i in range(0, len(kv) - 1, 2):
    rec[kv[i]] = kv[i + 1]
if os.environ["NORM_AUDIT_HAS_ARGV"] == "1":
    rec["argv"] = argv
rec["pid"] = int(os.environ["NORM_AUDIT_PID"])
rec["cwd"] = clean(os.environ["NORM_AUDIT_PWD"])

sys.stdout.write(json.dumps(rec, ensure_ascii=False) + "\n")
' "${_kv[@]}" ${_have_argv:+"${_argv[@]}"} 2>/dev/null
  )"; then
    printf '%s: WARNING audit encode failed — record dropped (%s)\n' \
      "$tool" "$NORM_AUDIT_LOG" >&2
    return 0
  fi

  # 0600 before the first append; the ambient umask left it world-readable.
  if ! { mkdir -p "$(dirname "$NORM_AUDIT_LOG")" 2>/dev/null \
         && { [ -e "$NORM_AUDIT_LOG" ] \
              || { : >"$NORM_AUDIT_LOG" && chmod 0600 "$NORM_AUDIT_LOG"; } ; } 2>/dev/null \
         && printf '%s\n' "$_line" >>"$NORM_AUDIT_LOG" 2>/dev/null; }; then
    printf '%s: WARNING audit write failed (%s) — continuing\n' \
      "$tool" "$NORM_AUDIT_LOG" >&2
  fi
  return 0
}
