#!/usr/bin/env bash
# Every record the credential wrappers write must parse as JSON. The bug this
# guards: a raw newline in `gh pr comment --body` split one record across lines.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO/home/dot_local/lib/norm-audit.sh"
GH="$REPO/home/dot_local/bin/executable_gh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; printf '        want: %q\n        got:  %q\n' "$3" "$2"; fi; }

# Every physical line in $1 must be a JSON object; prints the count or "BAD".
parses() {
  python3 - "$1" <<'PY'
import json, sys
n = 0
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.strip():
        continue
    try:
        json.loads(line)
    except Exception:
        print("BAD"); sys.exit(0)
    n += 1
print(n)
PY
}

field() { python3 -c '
import json,sys
recs=[json.loads(l) for l in open(sys.argv[1],encoding="utf-8") if l.strip()]
v=recs[int(sys.argv[2])]
for k in sys.argv[3:]:
    v = v[int(k)] if isinstance(v, list) else v.get(k, "<absent>")
sys.stdout.write(str(v))' "$@" 2>/dev/null || printf '<unparseable>'; }

BODY="$(printf 'line one\nline two')"
CTRL="$(printf 'tab\there\rcr\x01ctl')"
HOSTILE='eve" or 1=1 --'"\\"

# ── 1. The library encodes every hostile shape ──────────────────────────────
echo "1. norm-audit.sh encoding"
L="$TMP/lib.jsonl"
(
  set -euo pipefail
  NORM_GH_AUDIT="$L"; export NORM_GH_AUDIT
  # shellcheck source=/dev/null
  . "$LIB"
  norm_audit_emit gh event issued owner o token_file t -- pr comment --body "$BODY"
  norm_audit_emit gh event rejected owner "$HOSTILE" token_file "" -- api /repos/x
  norm_audit_emit gh event issued owner o token_file t -- --body "$CTRL"
  norm_audit_emit gh event issued owner o token_file t -- --body 'héllo ✅ 日本語'
  norm_audit_emit git-credential event skipped owner "" token_file "" detail 'host=evil"host'
)
check "five records, all parse"      "$(parses "$L")"        "5"
check "newline body round-trips"     "$(field "$L" 0 argv 3)" "$BODY"
check "hostile owner round-trips"    "$(field "$L" 1 owner)"  "$HOSTILE"
check "control chars round-trip"     "$(field "$L" 2 argv 1)" "$CTRL"
check "unicode round-trips"          "$(field "$L" 3 argv 1)" 'héllo ✅ 日本語'
check "quote in detail round-trips"  "$(field "$L" 4 detail)" 'host=evil"host'
check "no '--' means no argv key"    "$(field "$L" 4 argv)"   '<absent>'

# ── 2. A cwd containing a quote ─────────────────────────────────────────────
echo "2. hostile \$PWD"
W="$TMP/we\"ird"; mkdir -p "$W"; C="$TMP/cwd.jsonl"
( cd "$W" && NORM_GH_AUDIT="$C" bash -c '. "$1"; norm_audit_emit gh event issued -- status' _ "$LIB" )
check "record parses"     "$(parses "$C")"     "1"
check "cwd round-trips"   "$(field "$C" 0 cwd)" "$W"

# ── 3. Change detector: the escaper this replaced must FAIL these ───────────
# A test that cannot fail proves nothing, so run the old two-character escaper
# over the same input and require it to produce something that will not parse.
echo "3. change detector (old escaper must fail)"
O="$TMP/old.jsonl"
(
  a="$BODY"; a="${a//\\/\\\\}"; a="${a//\"/\\\"}"
  printf '{"ts":"x","tool":"gh","event":"issued","argv":["%s"],"pid":1,"cwd":"%s"}\n' "$a" "$PWD"
) >"$O"
if [ "$(parses "$O")" = "BAD" ]; then ok "old escaper produces unparseable JSON"
else bad "old escaper parsed — this test cannot detect the bug"; fi

# ── 4. End to end through the real gh wrapper ───────────────────────────────
echo "4. gh wrapper end to end"
mkdir -p "$TMP/bin" "$TMP/work" "$TMP/pats"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/gh"; chmod +x "$TMP/bin/gh"
E="$TMP/e2e.jsonl"
( cd "$TMP/work" && env -u GH_TOKEN -u GITHUB_TOKEN -u GH_REPO \
    PATH="$TMP/bin:/usr/bin:/bin" \
    HOME="$TMP" \
    GITHUB_PAT_DIR="$TMP/pats" \
    NORM_AUDIT_LIB="$LIB" \
    NORM_GH_AUDIT="$E" \
    bash "$GH" pr comment --body "$BODY" )
check "wrapper wrote one parseable record" "$(parses "$E")"        "1"
check "wrapper preserved the body"         "$(field "$E" 0 argv 3)" "$BODY"

# ── 5. Degraded paths stay loud and non-fatal ───────────────────────────────
echo "5. degraded paths"
M="$TMP/missing.jsonl"
out="$( cd "$TMP/work" && env -u GH_TOKEN -u GITHUB_TOKEN PATH="$TMP/bin:/usr/bin:/bin" \
    HOME="$TMP" GITHUB_PAT_DIR="$TMP/pats" NORM_AUDIT_LIB="$TMP/nope.sh" NORM_GH_AUDIT="$M" \
    bash "$GH" status 2>&1 )"
case "$out" in *"audit library missing"*) ok "missing library warns" ;; *) bad "missing library silent: $out" ;; esac
if [ -e "$M" ]; then bad "missing library still wrote a log"; else ok "missing library wrote nothing"; fi

out="$( PATH=/nonexistent NORM_GH_AUDIT="$TMP/nopy.jsonl" /bin/bash -c \
    '. "$1"; norm_audit_emit gh event issued -- status; echo CONTINUED' _ "$LIB" 2>&1 )"
case "$out" in *"no python3"*CONTINUED*) ok "no python3 warns and continues" ;; *) bad "no python3: $out" ;; esac

out="$( NORM_GH_AUDIT=/proc/cannot/write.jsonl bash -c \
    '. "$1"; norm_audit_emit gh event issued -- status; echo CONTINUED' _ "$LIB" 2>&1 )"
case "$out" in *"audit write failed"*CONTINUED*) ok "unwritable log warns and continues" ;; *) bad "unwritable: $out" ;; esac

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
