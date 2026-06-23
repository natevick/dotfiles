# ---- listing (eza with native fallback) ----
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --git --group-directories-first'
  alias la='eza -a'
  alias lt='eza --tree --level=2'
else
  alias ls='ls --color=auto'
  alias ll='ls -alhF'
  alias la='ls -A'
fi

alias grep='grep --color=auto'

# ---- config editors ----
alias zrc='${EDITOR} ~/.zshrc'
alias tmrc='${EDITOR} ~/.tmux.conf'

# ---- clipboard (first available wins) ----
if command -v pbcopy &>/dev/null; then
  alias xcopy='pbcopy'; alias xpaste='pbpaste'
elif command -v wl-copy &>/dev/null; then
  alias xcopy='wl-copy'; alias xpaste='wl-paste'
elif command -v xclip &>/dev/null; then
  alias xcopy='xclip -selection clipboard'; alias xpaste='xclip -selection clipboard -o'
fi

# ---- bat as cat (syntax highlighting; auto-plain when piped) ----
# Aliases are interactive-only, so scripts still get the real `cat`.
command -v bat &>/dev/null && alias cat='bat --paging=never'

# ---- fzf: use fd as the source (fast, .gitignore-aware) with bat/eza previews ----
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --hidden --strip-cwd-prefix --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type=d --hidden --strip-cwd-prefix --exclude .git'
fi
# Ctrl-T preview: tree for dirs, syntax-highlighted head for files.
command -v bat &>/dev/null && \
  export FZF_CTRL_T_OPTS="--preview '([ -d {} ] && eza --tree --level=2 --color=always {} || bat --color=always --style=numbers --line-range :300 {}) 2>/dev/null'"
# Alt-C preview: tree of the candidate directory.
command -v eza &>/dev/null && \
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
