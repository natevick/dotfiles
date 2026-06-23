#!/usr/bin/env bash
# Claude Code status line. Receives session JSON on stdin; prints one line.
input=$(cat)

# --- fields (graceful defaults for older Claude versions) ---
model=$(jq -r '.model.display_name // "Claude"'        <<<"$input")
cwd=$(jq -r   '.workspace.current_dir // .cwd // ""'    <<<"$input")
style=$(jq -r '.output_style.name // ""'               <<<"$input")
cost=$(jq -r  '.cost.total_cost_usd // 0'              <<<"$input")
added=$(jq -r '.cost.total_lines_added // 0'           <<<"$input")
removed=$(jq -r '.cost.total_lines_removed // 0'       <<<"$input")
ctx_used=$(jq -r  '.context_window.total_input_tokens // 0'    <<<"$input")
ctx_left=$(jq -r  '.context_window.remaining_percentage // empty' <<<"$input")
ctx_pct=$(jq -r   '.context_window.used_percentage // empty'   <<<"$input")
rl_5h=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
rl_7d=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")

# --- catppuccin mocha truecolor ---
mauve=$'\033[38;2;203;166;247m'
blue=$'\033[38;2;137;180;250m'
green=$'\033[38;2;166;227;161m'
peach=$'\033[38;2;250;179;135m'
red=$'\033[38;2;243;139;168m'
dim=$'\033[38;2;108;112;134m'
rst=$'\033[0m'
sep="  ${dim}·${rst}  "

# --- progress bar: $1=percent-used $2=width (filled ▰ / empty ▱) ---
ctxbar() {
  local p=${1:-0} w=${2:-8} i f out=""
  f=$(( (p * w + 50) / 100 )); [ "$f" -gt "$w" ] && f=$w; [ "$f" -lt 0 ] && f=0
  for ((i = 0; i < w; i++)); do [ "$i" -lt "$f" ] && out+="▰" || out+="▱"; done
  printf '%s' "$out"
}

# --- path: ~ for home, keep last two segments ---
disp="${cwd/#$HOME/~}"
short=$(awk -F/ '{n=NF; if(n>2) printf "…/%s/%s",$(n-1),$n; else print}' <<<"$disp")

# --- git: branch + dirty marker ---
git_seg=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if git -C "$cwd" diff --quiet 2>/dev/null && git -C "$cwd" diff --cached --quiet 2>/dev/null; then
    git_seg="${sep}${peach} ${branch}${rst}"
  else
    git_seg="${sep}${peach} ${branch}${rst} ${red}✗${rst}"
  fi
fi

# --- context window (Claude-provided): tokens in context / % left ---
# Uses native fields (Claude Code v2.1.132+); window size is auto-detected
# (200k or 1M extended), so nothing to hardcode. Hidden early in a session / after
# /compact, when these are null.
ctx_seg=""
if [ "${ctx_used:-0}" -gt 0 ] 2>/dev/null && [ -n "$ctx_left" ]; then
  pct_left=${ctx_left%.*}                       # strip any decimal
  pct_used=${ctx_pct%.*}; [ -z "$pct_used" ] && pct_used=$(( 100 - pct_left ))
  if   [ "$pct_left" -gt 50 ]; then ctxc=$green
  elif [ "$pct_left" -gt 20 ]; then ctxc=$peach
  else ctxc=$red; fi
  if [ "$ctx_used" -ge 1000 ]; then used_disp="$(( ctx_used / 1000 ))k"; else used_disp="$ctx_used"; fi
  ctx_seg="${sep}${ctxc} $(ctxbar "$pct_used" 8)  ${used_disp} · ${pct_left}% left${rst}"
fi

# --- lines changed this session ---
diff_seg=""
if [ "${added:-0}" -gt 0 ] 2>/dev/null || [ "${removed:-0}" -gt 0 ] 2>/dev/null; then
  diff_seg="${sep}${green}+${added}${rst}/${red}-${removed}${rst}"
fi

# --- session cost (only when > $0) ---
cost_seg=""
if awk "BEGIN{exit !($cost>0)}" 2>/dev/null; then
  cost_seg=$(printf "%s${green}\$%.2f${rst}" "$sep" "$cost")
fi

# --- rate limits (Pro/Max, after first API response): 5h / 7d budget used ---
rl_seg=""
if [ -n "$rl_5h" ] || [ -n "$rl_7d" ]; then
  h5=${rl_5h%.*}; d7=${rl_7d%.*}
  hi=${h5:-0}; [ -n "$d7" ] && [ "$d7" -gt "$hi" ] 2>/dev/null && hi=$d7
  if   [ "$hi" -lt 50 ]; then rlc=$green
  elif [ "$hi" -lt 80 ]; then rlc=$peach
  else rlc=$red; fi
  rl_txt=""
  [ -n "$h5" ] && rl_txt="5h ${h5}%"
  [ -n "$d7" ] && rl_txt="${rl_txt:+$rl_txt }7d ${d7}%"
  rl_seg="${sep}${rlc}${rl_txt}${rst}"
fi

# --- output style (only when non-default) ---
style_seg=""
if [ -n "$style" ] && [ "$style" != "default" ] && [ "$style" != "null" ]; then
  style_seg="${sep}${dim}${style}${rst}"
fi

printf "%s%s%s%s%s%s%s%s%s" \
  "${mauve}${model}${rst}" "${sep}" "${blue}${short}${rst}" \
  "$git_seg" "$ctx_seg" "$diff_seg" "$cost_seg" "$rl_seg" "$style_seg"
