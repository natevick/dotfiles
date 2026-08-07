# Turbo-loaded plugins. Sourced by ~/.zshrc AFTER zinit + starship are initialized.
# Everything here loads ~1ms AFTER the prompt paints (zinit "wait lucid").

zinit wait lucid for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay; _flush_deferred_compdefs" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"_zsh_autosuggest_start; _deferred_tool_inits" \
    zsh-users/zsh-autosuggestions \
  blockf \
    zsh-users/zsh-completions

# Oh-My-Zsh snippets (aliases + completions only — no omz framework load)
# OMZL::git.zsh supplies git_current_branch & friends that the git aliases call
zinit wait lucid for \
  OMZL::git.zsh \
  OMZP::git \
  OMZP::docker \
  OMZP::docker-compose \
  OMZP::kubectl
