# ~/.zshrc
#
# Portable interactive-shell config: no personal data, no secrets, no
# absolute paths tied to one account. Machine-local settings belong in
# ~/.zshrc.local, which is sourced near the bottom of this file.

# ── Homebrew prefix ────────────────────────────────────────────────
# Resolved without shelling out to `brew`, which would slow every start.
for _p in "$HOMEBREW_PREFIX" /opt/homebrew /usr/local; do
  if [ -n "$_p" ] && [ -d "$_p/share" ]; then BREW_PREFIX="$_p"; break; fi
done
unset _p

# ── nvm ────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                    # loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # loads nvm completion

# ── zsh plugins ────────────────────────────────────────────────────
# Order matters: autosuggestions before syntax-highlighting,
# and syntax-highlighting must be sourced last of all.
if [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'   # Catppuccin Mocha overlay0
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── history ────────────────────────────────────────────────────────
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt AUTO_CD INTERACTIVE_COMMENTS

# Up/down arrow search history matching what is already typed
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# ── completion ─────────────────────────────────────────────────────
fpath=("$BREW_PREFIX/share/zsh/site-functions" $fpath)
autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── prompt ─────────────────────────────────────────────────────────
command -v starship >/dev/null && eval "$(starship init zsh)"

# ── machine-local overrides ────────────────────────────────────────
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ── syntax highlighting (must be last) ─────────────────────────────
if [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
