# Emits a normalized manifest of the shell "contract" — everything that must be
# identical across OSes. Run inside an interactive shell so the full config is
# loaded: zsh -i -c 'source scripts/shell-manifest.zsh'
#
# Deliberately excluded (differ per-OS by design): EDITOR (cursor/code/vim),
# clipboard aliases xcopy/xpaste (pbcopy vs wl-copy vs xclip), PATH.
zmodload zsh/parameter

for t in mise starship fzf zoxide jq eza bat fd rg tmux vim; do
  if command -v "$t" >/dev/null 2>&1; then echo "tool:$t=present"; else echo "tool:$t=MISSING"; fi
done

for a in ls ll la lt cat grep zrc tmrc; do
  echo "alias:$a=${aliases[$a]:-MISSING}"
done

echo "env:FZF_DEFAULT_COMMAND=${FZF_DEFAULT_COMMAND:-MISSING}"
echo "env:FZF_CTRL_T_COMMAND=${FZF_CTRL_T_COMMAND:-MISSING}"
echo "env:FZF_CTRL_T_OPTS=${${FZF_CTRL_T_OPTS:+set}:-MISSING}"
echo "env:FZF_ALT_C_OPTS=${${FZF_ALT_C_OPTS:+set}:-MISSING}"

for o in sharehistory histignoredups histignorespace incappendhistory extendedhistory autocd interactivecomments; do
  echo "opt:$o=${options[$o]}"
done

echo "widget:up-line-or-beginning-search=${${widgets[up-line-or-beginning-search]:+set}:-MISSING}"
echo "widget:down-line-or-beginning-search=${${widgets[down-line-or-beginning-search]:+set}:-MISSING}"
