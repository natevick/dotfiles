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
